#ifndef ELISASCRIPT_NATIVE_LIBRARIES_ANSWER_H
#define ELISASCRIPT_NATIVE_LIBRARIES_ANSWER_H

#if defined(__GNUC__)
#define ANSWER_PUBLIC __attribute__((visibility("default")))
#else
#define ANSWER_PUBLIC
#endif

ANSWER_PUBLIC int answer(void);

#endif
