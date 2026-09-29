/* Dormant scalar ABI oracle. No allocation, I/O, process or signal operation. */
#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

_Static_assert(CHAR_BIT == 8, "fixture requires eight-bit bytes");
_Static_assert(sizeof(int) == 4, "fixture requires 32-bit C int");
_Static_assert(sizeof(pid_t) == 4, "fixture requires 32-bit pid_t");
_Static_assert((pid_t)-1 < 0, "fixture requires signed pid_t");
_Static_assert(sizeof(uintptr_t) == 8, "fixture selects Darwin64");
_Static_assert(sizeof(void *) == 8, "fixture requires eight-byte opaque pointers");
_Static_assert(sizeof(const unsigned char *) == 8, "fixture requires eight-byte entries");
_Static_assert(INT_MIN == (-2147483647 - 1), "fixture requires signed int32");
_Static_assert(INT_MAX == 2147483647, "fixture requires signed int32");

struct scalar_guard {
    uint32_t before;
    int status;
    uint32_t after;
};

_Static_assert(offsetof(struct scalar_guard, status) == 4, "status offset");
_Static_assert(offsetof(struct scalar_guard, after) == 8, "trailing guard offset");
_Static_assert(sizeof(struct scalar_guard) == 12, "guard size");

/* Deliberately not named fork/waitpid/kill: do not interpose on libc. */
int elisascript_fixture_scalar_result(int request, int *status, int option)
{
    if (status == NULL)
        return -7778;
    if (option != 0x13579bdf)
        return -7777;
    switch (request) {
    case 0:
        *status = 0x00007f00;
        return -1;
    case 1:
        *status = 0x12345678;
        return INT_MIN;
    case 2:
        *status = -123456789;
        return INT_MAX;
    default:
        return -7777;
    }
}

/* Independent C-to-C control; nonzero identifies a failed known answer. */
int elisascript_fixture_scalar_c_control(void)
{
    struct scalar_guard slot = {0xa1b2c3d4u, 0x11223344, 0x55667788u};
    int result = elisascript_fixture_scalar_result(0, &slot.status, 0x13579bdf);
    if (result != -1 || slot.status != 0x7f00)
        return 1;
    if (slot.before != 0xa1b2c3d4u || slot.after != 0x55667788u)
        return 2;
    result = elisascript_fixture_scalar_result(1, &slot.status, 0x13579bdf);
    if (result != INT_MIN || slot.status != 0x12345678)
        return 3;
    result = elisascript_fixture_scalar_result(2, &slot.status, 0x13579bdf);
    if (result != INT_MAX || slot.status != -123456789)
        return 4;
    if (slot.before != 0xa1b2c3d4u || slot.after != 0x55667788u)
        return 5;
    result = elisascript_fixture_scalar_result(9, &slot.status, 0x13579bdf);
    if (result != -7777 || slot.status != -123456789)
        return 6;
    result = elisascript_fixture_scalar_result(0, &slot.status, 0);
    if (result != -7777 || slot.status != -123456789)
        return 7;
    if (elisascript_fixture_scalar_result(0, NULL, 0x13579bdf) != -7778)
        return 8;
    return 0;
}

/* Fixed, bounded read-only C view of the real builder's three pointer tables.
 * Compare entry identities before dereferencing any string through the table.
 * Caller owns three/two/two slots and the four terminated byte buffers. */
int elisascript_fixture_pointer_tables(
    const unsigned char *const *argv,
    const unsigned char *const *environment,
    const unsigned char *const *candidates,
    const unsigned char *tool, const unsigned char *empty,
    const unsigned char *entry, const unsigned char *candidate)
{
    if (argv == NULL || environment == NULL || candidates == NULL ||
        tool == NULL || empty == NULL || entry == NULL || candidate == NULL)
        return 1;
    if (argv[0] != tool || argv[1] != empty || argv[2] != NULL)
        return 2;
    if (environment[0] != entry || environment[1] != NULL)
        return 3;
    if (candidates[0] != candidate || candidates[1] != NULL || candidate == tool)
        return 4;
    if (tool[0] != '.' || tool[1] != '/' || tool[2] != 't' ||
        tool[3] != 'o' || tool[4] != 'o' || tool[5] != 'l' || tool[6] != 0)
        return 5;
    if (empty[0] != 0 || entry[0] != 'X' || entry[1] != '=' || entry[2] != 0)
        return 6;
    if (candidate[0] != '.' || candidate[1] != '/' || candidate[2] != 't' ||
        candidate[3] != 'o' || candidate[4] != 'o' || candidate[5] != 'l' ||
        candidate[6] != 0)
        return 7;
    return 0;
}

int elisascript_fixture_pointer_c_control(void)
{
    const unsigned char tool[] = "./tool";
    const unsigned char empty[] = "";
    const unsigned char entry[] = "X=";
    const unsigned char candidate[] = "./tool";
    const unsigned char *argv[] = {tool, empty, NULL};
    const unsigned char *environment[] = {entry, NULL};
    const unsigned char *candidates[] = {candidate, NULL};
    if (elisascript_fixture_pointer_tables(argv, environment, candidates,
            tool, empty, entry, candidate) != 0)
        return 1;
    argv[1] = NULL;
    if (elisascript_fixture_pointer_tables(argv, environment, candidates,
            tool, empty, entry, candidate) != 2)
        return 2;
    argv[1] = empty;
    environment[1] = entry;
    if (elisascript_fixture_pointer_tables(argv, environment, candidates,
            tool, empty, entry, candidate) != 3)
        return 3;
    environment[1] = NULL;
    candidates[0] = tool;
    if (elisascript_fixture_pointer_tables(argv, environment, candidates,
            tool, empty, entry, candidate) != 4)
        return 4;
    return 0;
}
