cmake_minimum_required(VERSION 3.5.0)
project(qwentts)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

add_definitions(-DOHOS_PLATFORM)

# qwen3-tts native 模块
add_library(qwentts SHARED qwentts/qwentts_napi.cpp)

target_link_libraries(qwentts PUBLIC libace_napi.z.so libhilog_ndk.z.so)
