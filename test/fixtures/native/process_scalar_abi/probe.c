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
