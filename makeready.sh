#!/bin/bash

CURR_PATH=$PWD
TVM_PATH=$CURR_PATH/desk
TVM_BUILD_PATH=$TVM_PATH/build
TVMDOC_BUILD_PATH=$TVM_PATH/docs

export TVM_HOME=$TVM_PATH
export PYTHONPATH=$TVM_HOME/python:$PYTHONPATH

echo "Preparing TVM working desk..."

git submodule update --init --recursive

echo "Building TVM project..."
if [ ! -d $TVM_BUILD_PATH ]; then
    mkdir $TVM_BUILD_PATH
else
    rm -rf $TVM_BUILD_PATH
    mkdir $TVM_BUILD_PATH
fi
cd $TVM_BUILD_PATH
cp $TVM_PATH/cmake/config.cmake $TVM_BUILD_PATH
sed -i "s/set(USE_MICRO OFF)/set(USE_MICRO ON)/" $TVM_PATH/cmake/config.cmake
cmake ..
make -j8
cd $TVMDOC_BUILD_PATH
ln -s $CURR_PATH/locale $TVMDOC_BUILD_PATH/locale

cd $CURR_PATH
echo "Finishing to prepare TVM working desk!"
