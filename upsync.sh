#!/bin/bash

CURR_PATH=$PWD
TVM_PATH=$CURR_PATH/tvm-reference
TVM_BUILD_PATH=$TVM_PATH/build
TVMDOC_BUILD_PATH=$TVM_PATH/docs

export TVM_HOME=$TVM_PATH
export PYTHONPATH=$TVM_HOME/python:$PYTHONPATH

echo "Starting upsync of TVM documentation.."

git submodule add https://github.com/apache/tvm tvm-reference --recursive
git submodule update --init --recursive

echo "Building TVM project..."
if [ ! -d $TVM_BUILD_PATH ]; then
    mkdir $TVM_BUILD_PATH
    cd $TVM_BUILD_PATH
    cp $TVM_PATH/cmake/config.cmake $TVM_BUILD_PATH
    cmake ..
fi
cd $TVM_BUILD_PATH
make -j8
cd $TVM_PATH
make jvmpkg
make jvminstall
cd $TVMDOC_BUILD_PATH

git checkout -- $TVMDOC_BUILD_PATH/conf.py
sed -i "s/language = None/locale_dirs = [\"locale\"]\ngettext_compact = False/" $TVMDOC_BUILD_PATH/conf.py

echo "Building pootle for Korean and Japanese translation..."
make gettext
sphinx-intl update -p $TVMDOC_BUILD_PATH/_build/locale -l kr -l ja

echo "Generating HTML artifacts for translator's reference..."
make -e SPHINXOPS="-D language='kr' -D language='ja'" html

# TODO: automatic upmerge
#echo "Starting upmerge .po files generated from TVM docs with .po files in working directory..."
#echo "Finished upmerge..."

git checkout -- $TVMDOC_BUILD_PATH/conf.py
cd $CURR_PATH
echo "Finishing upsync of TVM documentations.."
