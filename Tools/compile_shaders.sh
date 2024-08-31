#!/bin/bash
START_DIR=$(pwd)

SRC_DIR="../Talos3D/Shaders"
OUT_DIR="${HOME}/Library/Containers/Talos3D/Data/tmp/shaders"

if [ ! -d $OUT_DIR ]; then
    mkdir -p $OUT_DIR
fi

cd $SRC_DIR

mkdir -p bin
cd bin

xcrun metal -gline-tables-only -frecord-sources -c ../*.metal 
xcrun metallib -o recompiled.metallib *.air

cp recompiled.metallib $OUT_DIR

cd ..

#cd $START_DIR
