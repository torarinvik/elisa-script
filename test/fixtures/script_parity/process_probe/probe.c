/* Independent native oracle for wrapper parity, not an automation script.
 * No subprocesses or filesystem writes. Stdin must reach EOF; the external
 * qualification harness supplies process-tree memory and time containment. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

enum {
    MAX_ARGUMENTS = 256,
    MAX_TEXT_BYTES = 65536,
    MAX_STDIN_BYTES = 65536,
    CWD_CAPACITY = 4096,
    ENVIRONMENT_FIELDS = 5,
    FAILURE_STATUS = 125
};

struct field {
    const unsigned char *data;
    size_t length;
    int present;
};

static int failure(void) {
    fputs("process probe: invalid input or host I/O failure\n", stderr);
    return FAILURE_STATUS;
}

static int take_field(const char *text, struct field *result, size_t *budget) {
    result->data = (const unsigned char *)text;
    result->length = 0;
    result->present = text != NULL;
    if (text == NULL) return 1;
    while (text[result->length] != '\0') {
        if (result->length >= *budget) return 0;
        ++result->length;
    }
    *budget -= result->length;
    return 1;
}

static int put_bytes(const unsigned char *data, size_t length) {
    return length == 0 || fwrite(data, 1, length, stdout) == length;
}

static int put_u32(uint32_t value) {
    const unsigned char bytes[4] = {
        (unsigned char)(value >> 24), (unsigned char)(value >> 16),
        (unsigned char)(value >> 8), (unsigned char)value
    };
    return put_bytes(bytes, sizeof bytes);
}

static int put_field(struct field value) {
    return put_u32((uint32_t)value.length) && put_bytes(value.data, value.length);
}

static int selected_status(int *status) {
    const char *text = getenv("ELISASCRIPT_PARITY_PROBE_EXIT_STATUS");
    *status = 0;
    if (text == NULL) return 1;
    if (*text == '\0') return 0;
    for (size_t index = 0; text[index] != '\0'; ++index) {
        if (index >= 3 || text[index] < '0' || text[index] > '9') return 0;
        *status = *status * 10 + (text[index] - '0');
    }
    return *status <= 255;
}

int main(int argc, char **argv) {
    static const unsigned char magic[] = {'E', 'S', 'P', 'R', 'O', 'B', 'E', '2'};
    static const unsigned char tail[] = {0, 255};
    static const unsigned char stderr_bytes[] = {
        'p', 'r', 'o', 'b', 'e', '-', 's', 't', 'd', 'e', 'r', 'r', 0, 255
    };
    static const char *const environment_names[ENVIRONMENT_FIELDS] = {
        "PYTHON_BIN", "RUFF_BIN", "ELISASCRIPT_PARITY_PROBE_MARKER", "PWD", "OLDPWD"
    };
    struct field arguments[MAX_ARGUMENTS];
    struct field environment[ENVIRONMENT_FIELDS];
    struct field cwd_field;
    char cwd[CWD_CAPACITY];
    unsigned char input[MAX_STDIN_BYTES + 1];
    size_t input_size = 0;
    size_t text_budget = MAX_TEXT_BYTES;
    int status;

    if (argc < 1 || argc - 1 > MAX_ARGUMENTS || !selected_status(&status))
        return failure();
    for (int index = 1; index < argc; ++index)
        if (!take_field(argv[index], &arguments[index - 1], &text_budget))
            return failure();
    if (getcwd(cwd, sizeof cwd) == NULL ||
        !take_field(cwd, &cwd_field, &text_budget)) return failure();
    for (size_t index = 0; index < ENVIRONMENT_FIELDS; ++index)
        if (!take_field(getenv(environment_names[index]), &environment[index],
                        &text_budget)) return failure();

    /* Read one byte beyond the admitted size to distinguish EOF from overflow.
     * Preflight all inputs before emitting any stdout frame. */
    for (;;) {
        size_t amount = fread(input + input_size, 1, sizeof input - input_size, stdin);
        input_size += amount;
        if (input_size > MAX_STDIN_BYTES || ferror(stdin)) return failure();
        if (amount == 0) break;
    }

    if (!put_bytes(magic, sizeof magic) || !put_u32((uint32_t)(argc - 1)))
        return failure();
    for (int index = 0; index < argc - 1; ++index)
        if (!put_field(arguments[index])) return failure();
    if (!put_field(cwd_field)) return failure();
    for (size_t index = 0; index < ENVIRONMENT_FIELDS; ++index) {
        unsigned char present = (unsigned char)environment[index].present;
        if (!put_bytes(&present, 1)) return failure();
        if (present && !put_field(environment[index])) return failure();
    }
    if (!put_u32((uint32_t)input_size) || !put_bytes(input, input_size) ||
        !put_bytes(tail, sizeof tail) || fflush(stdout) != 0) return failure();
    if (fwrite(stderr_bytes, 1, sizeof stderr_bytes, stderr) != sizeof stderr_bytes ||
        fflush(stderr) != 0) return FAILURE_STATUS;
    return status;
}
