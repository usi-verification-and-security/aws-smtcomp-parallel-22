#!/bin/bash

if [ -d build ]; then rm -rf build; fi
mkdir -p build
cd build

cmake -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
      -DUSE_READLINE:BOOL=${USE_READLINE} \
      -DENABLE_LINE_EDITING:BOOL=${ENABLE_LINE_EDITING} \
      ..

make -j4
