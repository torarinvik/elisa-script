#include "core_internal.h"
#include "core.h"

#ifndef CORE_PRIVATE
#error core private compile definition is missing
#endif
#ifndef CORE_PRIVATE_OPTION
#error core private compile option is missing
#endif

int core_value(void) {
    return helper_value() + API_LEVEL + CORE_ABI;
}
