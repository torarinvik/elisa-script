#ifndef ELISASCRIPT_TARGET_USAGE_FEATURE_H
#define ELISASCRIPT_TARGET_USAGE_FEATURE_H

#ifndef API_LEVEL
#error API_LEVEL must propagate from the interface target
#endif
#if API_LEVEL != 3
#error unexpected API_LEVEL
#endif
#ifndef API_OPTION
#error API_OPTION must propagate as an interface compile option
#endif

#endif
