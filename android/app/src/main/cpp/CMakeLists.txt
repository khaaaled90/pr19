cmake_minimum_required(VERSION 3.22.1)

project("cardpaysecurity")

add_library(
        cardpaysecurity
        SHARED
        native-lib.cpp)

find_library(
        log-lib
        log)

target_link_libraries(
        cardpaysecurity
        ${log-lib})