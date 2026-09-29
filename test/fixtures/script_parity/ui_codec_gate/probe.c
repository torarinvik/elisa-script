/* Independent compiler/run oracle, never a real compiler or shell wrapper.
 * Build two separately qualified artifacts; UI_GATE_RUN_PROBE selects the
 * read-only run payload. Nothing is built or launched by this source itself. */
#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 700
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum { PATH_BYTES = 4096, TEXT_BYTES = 65536, INPUT_BYTES = 65536,
       PAYLOAD_BYTES = 1048576, ARGUMENTS = 11, FAILURE = 125 };
struct field { const unsigned char *data; size_t size; int present; };

static int fail(void) {
    (void)fputs("ui codec probe: invalid fixture or host I/O failure\n", stderr);
    return FAILURE;
}

static int field(const char *text, struct field *out, size_t *budget) {
    out->data = (const unsigned char *)text;
    out->size = 0;
    out->present = text != NULL;
    if (text == NULL) return 1;
    while (text[out->size] != '\0') {
        if (out->size >= *budget) return 0;
        ++out->size;
    }
    *budget -= out->size;
    return 1;
}

static int status_value(const char *name, int *status) {
    const char *text = getenv(name);
    *status = 0;
    if (text == NULL) return 1;
    if (*text == '\0') return 0;
    for (size_t i = 0; text[i] != '\0'; ++i) {
        if (i >= 3 || text[i] < '0' || text[i] > '9') return 0;
        *status = *status * 10 + text[i] - '0';
    }
    return *status <= 255;
}

static int join(char *out, const char *root, const char *suffix) {
    int count = snprintf(out, PATH_BYTES, "%s%s", root, suffix);
    return count > 0 && count < PATH_BYTES;
}

static int private_directory(const struct stat *value) {
    return S_ISDIR(value->st_mode) && value->st_uid == geteuid() &&
           (value->st_mode & 0077) == 0;
}

static int root_stat(const char *root, struct stat *value) {
    char canonical[PATH_BYTES];
    return root[0] == '/' && strcmp(root, "/") != 0 &&
           realpath(root, canonical) != NULL && strcmp(root, canonical) == 0 &&
           lstat(root, value) == 0 && private_directory(value);
}

static int bytes(const unsigned char *data, size_t count) {
    return count == 0 || fwrite(data, 1, count, stdout) == count;
}

static int u32(size_t value) {
    const unsigned char data[4] = {(unsigned char)(value >> 24),
        (unsigned char)(value >> 16), (unsigned char)(value >> 8),
        (unsigned char)value};
    return bytes(data, sizeof data);
}

static int packet_field(struct field value) {
    return u32(value.size) && bytes(value.data, value.size);
}

static int packet(unsigned char role, int status, const struct field *arguments,
                  size_t count, struct field cwd, const struct field *env,
                  const unsigned char *input, size_t input_size) {
    static const unsigned char magic[] = "ESUIGATE1";
    const unsigned char selected = (unsigned char)status;
    const unsigned char tail[] = {0, 255};
    if (!bytes(magic, sizeof magic - 1) || !bytes(&role, 1) ||
        !bytes(&selected, 1) || !u32(count)) return 0;
    for (size_t i = 0; i < count; ++i)
        if (!packet_field(arguments[i])) return 0;
    if (!packet_field(cwd)) return 0;
    for (size_t i = 0; i < 3; ++i) {
        unsigned char present = (unsigned char)env[i].present;
        if (!bytes(&present, 1) || (present && !packet_field(env[i]))) return 0;
    }
    if (!u32(input_size) || !bytes(input, input_size) ||
        !bytes(tail, sizeof tail) || fflush(stdout) != 0) return 0;
    const char *diagnostic = role == 'C' ? "ui-compile-stderr" : "ui-run-stderr";
    size_t length = strlen(diagnostic);
    return fwrite(diagnostic, 1, length, stderr) == length &&
           fwrite(tail, 1, sizeof tail, stderr) == sizeof tail && fflush(stderr) == 0;
}

#ifndef UI_GATE_RUN_PROBE
static int open_private_at(int parent, const char *name) {
    int fd = openat(parent, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    struct stat value;
    if (fd >= 0 && fstat(fd, &value) == 0 && private_directory(&value)) return fd;
    if (fd >= 0) (void)close(fd);
    return -1;
}

static int native_header(const unsigned char *p) {
    return (p[0] == 127 && p[1] == 'E' && p[2] == 'L' && p[3] == 'F') ||
           (p[0] == 207 && p[1] == 250 && p[2] == 237 && p[3] == 254) ||
           (p[0] == 254 && p[1] == 237 && p[2] == 250 && p[3] == 207) ||
           (p[0] == 202 && p[1] == 254 && p[2] == 186 && (p[3] == 190 || p[3] == 191)) ||
           ((p[0] == 190 || p[0] == 191) && p[1] == 186 && p[2] == 254 && p[3] == 202);
}

static int payload_unchanged(const struct stat *before, const struct stat *after) {
    if (before->st_dev != after->st_dev || before->st_ino != after->st_ino ||
        before->st_size != after->st_size || before->st_mode != after->st_mode ||
        before->st_uid != after->st_uid) return 0;
#ifdef __APPLE__
    return before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
           before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
           before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
           before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
#else
    return before->st_mtim.tv_sec == after->st_mtim.tv_sec &&
           before->st_mtim.tv_nsec == after->st_mtim.tv_nsec &&
           before->st_ctim.tv_sec == after->st_ctim.tv_sec &&
           before->st_ctim.tv_nsec == after->st_ctim.tv_nsec;
#endif
}

static int materialize(const char *root, const struct stat *named_root,
                       const char *leaf, int status) {
    int root_fd = -1, tmp_fd = -1, directory = -1, tools = -1;
    int payload = -1, output = -1, ok = 0;
    struct stat opened_root, source, after, named_source;
    unsigned char buffer[16384];
    root_fd = open(root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (root_fd < 0 || fstat(root_fd, &opened_root) != 0 ||
        !private_directory(&opened_root) || opened_root.st_dev != named_root->st_dev ||
        opened_root.st_ino != named_root->st_ino) goto done;
    tmp_fd = open_private_at(root_fd, "tmp");
    if (tmp_fd < 0) goto done;
    directory = open_private_at(tmp_fd, leaf);
    if (directory < 0) goto done;
    if (status != 0) { ok = 1; goto done; } /* Skip output on compiler failure. */
    tools = open_private_at(root_fd, "tools");
    if (tools < 0) goto done;
    payload = openat(tools, "ui-codec-run-probe", O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
    if (payload < 0 || fstat(payload, &source) != 0 || !S_ISREG(source.st_mode) ||
        source.st_uid != geteuid() || (source.st_mode & 0022) != 0 ||
        source.st_size < 4 || source.st_size > PAYLOAD_BYTES ||
        (source.st_mode & 0111) == 0) goto done;
    if (pread(payload, buffer, 4, 0) != 4 || !native_header(buffer)) goto done;
    output = openat(directory, "utf8_utf16_codec_test",
                    O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0700);
    if (output < 0) goto done;
    size_t total = 0;
    while (total < (size_t)source.st_size) {
        size_t capacity = (size_t)source.st_size - total;
        if (capacity > sizeof buffer) capacity = sizeof buffer;
        ssize_t count = read(payload, buffer, capacity);
        if (count <= 0 || (size_t)count > capacity) goto done;
        size_t written = 0;
        while (written < (size_t)count) {
            ssize_t amount = write(output, buffer + written, (size_t)count - written);
            if (amount <= 0 || (size_t)amount > (size_t)count - written) goto done;
            written += (size_t)amount;
        }
        total += (size_t)count;
    }
    if (read(payload, buffer, 1) != 0 || fstat(payload, &after) != 0 ||
        !payload_unchanged(&source, &after) ||
        fstatat(tools, "ui-codec-run-probe", &named_source, AT_SYMLINK_NOFOLLOW) != 0 ||
        !payload_unchanged(&source, &named_source) || fchmod(output, 0700) != 0) goto done;
    ok = 1;
done:
    /* Close every acquired descriptor. Leave a partial owned output on error;
     * the outer receipt-based fixture cleanup must handle it, never a broad rm. */
    if (output >= 0 && close(output) != 0) ok = 0;
    if (payload >= 0 && close(payload) != 0) ok = 0;
    if (tools >= 0 && close(tools) != 0) ok = 0;
    if (directory >= 0 && close(directory) != 0) ok = 0;
    if (tmp_fd >= 0 && close(tmp_fd) != 0) ok = 0;
    if (root_fd >= 0 && close(root_fd) != 0) ok = 0;
    return ok;
}

static int compile_arguments(const char *root, const struct field *args,
                             char *leaf) {
    static const char *const flags[] = {"-std=c11", "-O2", "-Wall", "-Wextra",
        "-Werror", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"};
    char expected[PATH_BYTES];
    for (size_t i = 0; i < 7; ++i)
        if (strcmp((const char *)args[i].data, flags[i]) != 0) return 0;
    if (!join(expected, root, "/elisa-ui/src/platform/common")) return 0;
    char include[PATH_BYTES];
    int size = snprintf(include, sizeof include, "-I%s", expected);
    if (size < 0 || (size_t)size >= sizeof include ||
        strcmp((const char *)args[7].data, include) != 0) return 0;
    if (!join(expected, root, "/elisa-ui/test/utf8_utf16_codec_test.c") ||
        strcmp((const char *)args[8].data, expected) != 0 ||
        strcmp((const char *)args[9].data, "-o") != 0 ||
        !join(expected, root, "/tmp/")) return 0;
    size_t prefix = strlen(expected);
    const char *output = (const char *)args[10].data;
    if (args[10].size <= prefix || args[10].size >= PATH_BYTES ||
        memcmp(output, expected, prefix) != 0) return 0;
    const char *name = output + prefix;
    size_t length = 0;
    while (name[length] != '\0' && name[length] != '/') {
        unsigned char byte = (unsigned char)name[length];
        if (length >= 255 || !((byte >= 'a' && byte <= 'z') ||
            (byte >= 'A' && byte <= 'Z') || (byte >= '0' && byte <= '9') ||
            byte == '-' || byte == '_' || byte == '.')) return 0;
        ++length;
    }
    if (length == 0 || (length == 1 && name[0] == '.') ||
        (length == 2 && name[0] == '.' && name[1] == '.') ||
        strcmp(name + length, "/utf8_utf16_codec_test") != 0) return 0;
    memcpy(leaf, name, length);
    leaf[length] = '\0';
    return 1;
}
#endif

int main(int argc, char **argv) {
    struct field arguments[ARGUMENTS] = {{0}}, environment[3], cwd_field, root_field;
    const char *const names[] = {"CC", "TMPDIR", "ELISASCRIPT_UI_PROBE_MARKER"};
    char cwd[PATH_BYTES], expected[PATH_BYTES];
    struct stat named_root;
    size_t budget = TEXT_BYTES;
    unsigned char input[INPUT_BYTES + 1];
    const char *authorized = getenv("ELISASCRIPT_UI_PROBE_AUTHORIZED");
    int status;
    (void)argv;
    if (authorized == NULL || strcmp(authorized, "1") != 0 ||
        !field(getenv("ELISASCRIPT_UI_PROBE_ROOT"), &root_field, &budget) ||
        !root_field.present || root_field.size == 0 || root_field.size >= PATH_BYTES)
        return fail();
    const char *root = (const char *)root_field.data;
    if (!root_stat(root, &named_root) || !join(expected, root, "/work") ||
        getcwd(cwd, sizeof cwd) == NULL || strcmp(cwd, expected) != 0 ||
        !field(cwd, &cwd_field, &budget)) return fail();
    for (size_t i = 0; i < 3; ++i)
        if (!field(getenv(names[i]), &environment[i], &budget)) return fail();
    if (!join(expected, root, "/tmp") || !environment[1].present ||
        strcmp((const char *)environment[1].data, expected) != 0) return fail();
#ifdef UI_GATE_RUN_PROBE
    size_t input_size = 0;
    if (argc != 1 || !status_value("ELISASCRIPT_UI_RUN_STATUS", &status)) return fail();
    for (;;) {
        size_t amount = fread(input + input_size, 1, sizeof input - input_size, stdin);
        input_size += amount;
        if (input_size > INPUT_BYTES || ferror(stdin)) return fail();
        if (amount == 0) break;
    }
    if (!packet('R', status, arguments, 0, cwd_field, environment, input, input_size))
        return FAILURE;
#else
    char leaf[256];
    if (argc != ARGUMENTS + 1 || !status_value("ELISASCRIPT_UI_COMPILE_STATUS", &status))
        return fail();
    for (size_t i = 0; i < ARGUMENTS; ++i)
        if (!field(argv[i + 1], &arguments[i], &budget)) return fail();
    if (!compile_arguments(root, arguments, leaf) ||
        !materialize(root, &named_root, leaf, status)) return fail();
    /* The random directory spelling is admitted above, not compared across
     * two allocators. All other argv bytes remain exact independent data. */
    static const unsigned char normalized[] = "<owned-temp>/utf8_utf16_codec_test";
    arguments[10].data = normalized;
    arguments[10].size = sizeof normalized - 1;
    if (!packet('C', status, arguments, ARGUMENTS, cwd_field, environment, input, 0))
        return FAILURE;
#endif
    return status;
}
