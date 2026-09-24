#include "core.h"

#include <math.h>
#include <stdio.h>

#ifdef CORE_PRIVATE
#error core private definition leaked into the consumer
#endif
#ifdef CORE_PRIVATE_OPTION
#error core private compile option leaked into the consumer
#endif
#ifdef HELPER_PRIVATE
#error private helper usage leaked into the consumer
#endif
#ifdef HELPER_PRIVATE_OPTION
#error private helper compile option leaked into the consumer
#endif

int main(void) {
    const int result = core_value() + (int)sqrt(16.0);
    if (result != 32) {
        return 1;
    }
    printf("usage=%d\n", result);
    return 0;
}
