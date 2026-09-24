#ifndef ELISASCRIPT_TARGET_USAGE_CORE_H
#define ELISASCRIPT_TARGET_USAGE_CORE_H

#include "api/feature.h"

#ifndef CORE_ABI
#error CORE_ABI must propagate from the public core interface
#endif
#if CORE_ABI != 5
#error unexpected CORE_ABI
#endif
#ifndef CORE_PUBLIC_OPTION
#error CORE_PUBLIC_OPTION must propagate to consumers
#endif

int core_value(void);

#endif
