cmake_minimum_required(VERSION 3.22.1)

project("pr19security")

add_library(
        pr19security
        SHARED
        native-lib.cpp)

find_library(
        log-lib
        log)

target_link_libraries(
        pr19security
        ${log-lib})