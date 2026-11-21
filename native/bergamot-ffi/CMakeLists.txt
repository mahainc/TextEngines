cmake_minimum_required(VERSION 3.16)
project(bergamot_ffi C CXX)

set(ENGINE_DIR "" CACHE PATH "mozilla/translations inference/ directory")
if(NOT EXISTS "${ENGINE_DIR}/CMakeLists.txt")
  message(FATAL_ERROR "set ENGINE_DIR to the engine's inference/ directory")
endif()

add_subdirectory("${ENGINE_DIR}" engine)

add_library(bergamot_ffi STATIC bergamot_ffi.cpp)
target_link_libraries(bergamot_ffi PRIVATE bergamot-translator-source)
set_target_properties(bergamot_ffi PROPERTIES CXX_STANDARD 17 CXX_STANDARD_REQUIRED ON)
