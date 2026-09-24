cmake_minimum_required(VERSION 3.22)
project(ElisascriptNativeLibraries LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

function(configure_native_target target)
    if(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(${target} PRIVATE
            -pedantic -Wall -Wextra -Werror -fvisibility=hidden
        )
    endif()
endfunction()

add_library(answer_static STATIC src/answer.c)
target_include_directories(answer_static PUBLIC include)
configure_native_target(answer_static)

add_library(answer_shared SHARED src/answer.c)
target_include_directories(answer_shared PUBLIC include)
configure_native_target(answer_shared)
set_target_properties(answer_shared PROPERTIES C_VISIBILITY_PRESET hidden)
if(APPLE)
    set_target_properties(answer_shared PROPERTIES
        MACOSX_RPATH TRUE
        INSTALL_NAME_DIR "@rpath"
    )
endif()

add_executable(static-client src/main.c)
target_link_libraries(static-client PRIVATE answer_static)
configure_native_target(static-client)

add_executable(shared-client src/main.c)
target_link_libraries(shared-client PRIVATE answer_shared)
configure_native_target(shared-client)
if(APPLE)
    set_target_properties(shared-client PROPERTIES BUILD_RPATH "@loader_path")
else()
    set_target_properties(shared-client PROPERTIES BUILD_RPATH "$ORIGIN")
endif()

include(CTest)
if(BUILD_TESTING)
    add_test(NAME static-library-client COMMAND static-client)
    set_tests_properties(static-library-client PROPERTIES
        PASS_REGULAR_EXPRESSION "answer=42"
        TIMEOUT 10
    )
    add_test(NAME shared-library-client COMMAND shared-client)
    set_tests_properties(shared-library-client PROPERTIES
        PASS_REGULAR_EXPRESSION "answer=42"
        TIMEOUT 10
    )
endif()
