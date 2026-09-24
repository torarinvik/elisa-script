#include "answer.h"

int answer_component(void) {
    return 40;
}

int answer(void) {
    return answer_component() + 2;
}
