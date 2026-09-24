#include "answer.h"
#include "generated_build_config.h"

#include <stdio.h>

int main(void) {
    const int value = answer();
    if (value != MINIMAL_BUILD_ANSWER) {
        return 1;
    }
    printf("answer=%d\n", value);
    return 0;
}
