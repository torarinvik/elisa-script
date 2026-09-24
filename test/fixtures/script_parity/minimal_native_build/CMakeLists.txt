cmake_minimum_required(VERSION 3.22)
project(ElisascriptMinimalNativeBuild LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

configure_file(
    include/generated_build_config.h.in
    generated_build_config.h
    COPYONLY
)

add_library(minimal-answer STATIC src/answer.c)
target_include_directories(minimal-answer PRIVATE include)

add_executable(minimal-native src/main.c)
target_include_directories(minimal-native PRIVATE include "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(minimal-native PRIVATE minimal-answer)

if(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(minimal-answer PRIVATE -pedantic -Wall -Wextra -Werror)
    target_compile_options(minimal-native PRIVATE -pedantic -Wall -Wextra -Werror)
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME minimal-native-output COMMAND minimal-native)
    set_tests_properties(minimal-native-output PROPERTIES
        PASS_REGULAR_EXPRESSION "answer=42"
        TIMEOUT 10
    )
endif()
