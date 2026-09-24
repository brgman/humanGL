cmake_minimum_required(VERSION 3.16)
project(humanGL CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# GLAD — обычный C-файл, компилируется как часть проекта
add_library(glad STATIC vendor/glad/src/glad.c)
target_include_directories(glad PUBLIC vendor/glad/include)

# Ищем SDL3, установленную в системе
find_package(SDL3 REQUIRED)

add_executable(humanGL src/main.cpp)

target_link_libraries(humanGL PRIVATE glad SDL3::SDL3)