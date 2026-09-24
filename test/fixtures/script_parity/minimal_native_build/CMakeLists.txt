cmake_minimum_required(VERSION 3.22)
project(ElisascriptMinimalNativeBuild LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

add_executable(minimal-native
    src/main.c
    src/answer.c
)
target_include_directories(minimal-native PRIVATE include)
