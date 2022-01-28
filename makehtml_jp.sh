#!/bin/bash

CURR_PATH=$PWD
TVM_PATH=$CURR_PATH/desk
TVMDOC_BUILD_PATH=$TVM_PATH/docs

cd $TVMDOC_BUILD_PATH

git checkout -- $TVMDOC_BUILD_PATH/conf.py
sed -i "s/language = None/language = \"ja\"\nlocale_dirs = [\"locale\"]\ngettext_compact = False\ntls_verify = False/" $TVMDOC_BUILD_PATH/conf.py
sed -i "s/\"find_mayavi_figures\": False,//" $TVMDOC_BUILD_PATH/conf.py

echo "Generating HTML artifacts in Japanese..."
make -e SPHINXOPS="-D language='ja'" html
git checkout -- $TVMDOC_BUILD_PATH/conf.py

echo "Dumping HTML artifacts to docs for github pages hosting..."
if [ ! -d $CURR_PATH/docs ]; then
    mkdir $CURR_PATH/docs
fi
cp -rf $TVMDOC_BUILD_PATH/_build/html/* $CURR_PATH/docs

cd $CURR_PATH
echo "Done!"
