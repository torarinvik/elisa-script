cmake_minimum_required(VERSION 3.22)
project(ElisascriptTargetUsage LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

function(configure_native_target target)
    if(CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
        target_compile_options(${target} PRIVATE -pedantic -Wall -Wextra -Werror)
    endif()
endfunction()

add_library(api INTERFACE)
target_include_directories(api INTERFACE include/api)
target_compile_definitions(api INTERFACE API_LEVEL=3)
target_compile_options(api INTERFACE -DAPI_OPTION=1)
target_link_libraries(api INTERFACE m)
target_link_options(api INTERFACE -Wl,-dead_strip)

add_library(helper STATIC src/helper.c)
target_include_directories(helper PRIVATE include/helper)
target_compile_definitions(helper PRIVATE HELPER_PRIVATE=1)
target_compile_options(helper PRIVATE -DHELPER_PRIVATE_OPTION=1)
configure_native_target(helper)

add_library(core STATIC src/core.c)
target_include_directories(core PRIVATE include/internal PUBLIC include/core)
target_compile_definitions(core PRIVATE CORE_PRIVATE=1 PUBLIC CORE_ABI=5)
target_compile_options(core PRIVATE -DCORE_PRIVATE_OPTION=1 PUBLIC -DCORE_PUBLIC_OPTION=1)
target_link_libraries(core PUBLIC api PRIVATE helper)
configure_native_target(core)

add_executable(app src/main.c)
target_link_libraries(app PRIVATE core)
configure_native_target(app)

include(CTest)
if(BUILD_TESTING)
    add_test(NAME target-usage-output COMMAND app)
    set_tests_properties(target-usage-output PROPERTIES
        PASS_REGULAR_EXPRESSION "usage=32"
        TIMEOUT 10
    )
endif()
