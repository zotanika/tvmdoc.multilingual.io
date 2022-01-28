#!/bin/bash

CURR_PATH=$PWD
TVM_PATH=$CURR_PATH/desk
TVM_BUILD_PATH=$TVM_PATH/build
TVMDOC_BUILD_PATH=$TVM_PATH/docs

export TVM_HOME=$TVM_PATH
export PYTHONPATH=$TVM_HOME/python

echo "Preparing TVM working desk..."

git submodule update --init --recursive

echo "Building TVM project..."
if [ ! -d $TVM_BUILD_PATH ]; then
    mkdir $TVM_BUILD_PATH
    cp $TVM_PATH/cmake/config.cmake $TVM_BUILD_PATH
    sed -i "s/set(USE_MICRO OFF)/set(USE_MICRO ON)/" $TVM_BUILD_PATH/config.cmake
    sed -i "s/set(USE_LLVM OFF)/set(USE_LLVM ON)/" $TVM_BUILD_PATH/config.cmake
fi
cd $TVM_BUILD_PATH
cmake ..
make -j8
cd $CURR_PATH

if [ ! -d $TVMDOC_BUILD_PATH/locale ]; then
    ln -sf $CURR_PATH/locale $TVMDOC_BUILD_PATH/locale
fi

echo "Finishing to prepare TVM working desk!"
