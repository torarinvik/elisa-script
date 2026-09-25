#include "answer.h"
#include "generated_build_config.h"

#include <stdio.h>

#if MINIMAL_MAIN_VARIANT == 0
#define MINIMAL_MAIN_ADJUSTMENT 21 - 21
#else
#define MINIMAL_MAIN_ADJUSTMENT 42 - 42
#endif

int main(void) {
    const int value = answer() + MINIMAL_MAIN_ADJUSTMENT;
    if (value != MINIMAL_BUILD_ANSWER) {
        return 1;
    }
    (void)puts("answer=42");
    return 0;
}
