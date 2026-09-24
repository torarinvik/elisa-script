#include "answer.h"

#include <stdio.h>

int main(void) {
    const int value = answer();
    if (value != 42) {
        return 1;
    }
    printf("answer=%d\n", value);
    return 0;
}
