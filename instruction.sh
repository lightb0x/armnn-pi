#!/bin/bash
# takes about 2 hours total

# Before you begin
sudo apt update && sudo apt upgrade
sudo apt install vim gcc g++ git scons gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf curl autoconf libtool cmake

# Downloading the repositories and bundles
mkdir armnn-pi
cd armnn-pi
export BASEDIR=`pwd`

git clone https://github.com/Arm-software/ComputeLibrary.git 
git clone https://github.com/Arm-software/armnn
cd $BASEDIR/armnn
git checkout ba163f93c8a0e858c9fb1ea85e4ac34c966ef38a
cd $BASEDIR

wget https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.bz2
tar xf boost_1_64_0.tar.bz2
git clone -b v3.5.2 https://github.com/google/protobuf.git
cd $BASEDIR/protobuf
git checkout b5fbb742af122b565925987e65c08957739976a7
cd $BASEDIR

git clone https://github.com/tensorflow/tensorflow.git
cd tensorflow/
git checkout 590d6eef7e91a6a7392c8ffffb7b58f2e0c8bc6b
cd $BASEDIR
git clone https://github.com/onnx/onnx.git 
cd onnx       
git fetch https://github.com/onnx/onnx.git f612532843bd8e24efeab2815e45b436479cc9ab && git checkout FETCH_HEAD
cd $BASEDIR
git clone https://github.com/google/flatbuffers.git

# Building the Compute Library
cd $BASEDIR/ComputeLibrary
scons extra_cxx_flags="-fPIC" Werror=0 debug=0 asserts=0 neon=1 opencl=0 os=linux arch=armv7a examples=1

# Building the Boost library for your Raspberry Pi
cd $BASEDIR/boost_1_64_0/tools/build
./bootstrap.sh
./b2 install --prefix=$BASEDIR/boost.build
export PATH=$BASEDIR/boost.build/bin:$PATH

cp $BASEDIR/boost_1_64_0/tools/build/example/user-config.jam $BASEDIR/boost_1_64_0/project-config.jam

cd $BASEDIR/boost_1_64_0

echo "using gcc : arm : arm-linux-gnueabihf-g++ ;" >> project-config.jam

b2 --build-dir=$BASEDIR/boost_1_64_0/build toolset=gcc-arm link=static cxxflags=-fPIC --with-filesystem --with-test --with-log --with-program_options install --prefix=$BASEDIR/boost

# Building the Google Protobuf library
## Building the Google Protobuf library for your virtual machine
cd $BASEDIR/protobuf
git submodule update --init --recursive
./autogen.sh
./configure --prefix=$BASEDIR/protobuf-host
make
make install
make clean

## Building the Google Protobuf library for your Raspberry Pi
./configure --prefix=$BASEDIR/protobuf-arm --host=arm-linux CC=arm-linux-gnueabihf-gcc CXX=arm-linux-gnueabihf-g++ --with-protoc=$BASEDIR/protobuf-host/bin/protoc
make
make install

# Generating the TensorFlow Protobuf library
cd $BASEDIR/tensorflow
../armnn/scripts/generate_tensorflow_protobuf.sh ../tensorflow-protobuf ../protobuf-host

# Building ONNX
cd $BASEDIR/onnx

export LD_LIBRARY_PATH=$BASEDIR/protobuf-host/lib:$LD_LIBRARY_PATH
$BASEDIR/protobuf-host/bin/protoc onnx/onnx.proto --proto_path=. --proto_path=$BASEDIR/protobuf-host/include --cpp_out $BASEDIR/onnx

# Building FlatBuffers
cd $BASEDIR/flatbuffers
git checkout 5d3cf440e50186bf6a1e841038ac887c2da06141
rm -f CMakeCache.txt
rm -rf build
mkdir build
cd build
CXXFLAGS="-fPIC" cmake .. -DFLATBUFFERS_BUILD_FLATC=1 -DCMAKE_INSTALL_PREFIX:PATH=$BASEDIR/flatbuffers-x86
make all install

# Building FlatBuffers for your Raspberry Pi
cd $BASEDIR/flatbuffers
mkdir build-arm32
cd build-arm32
CXXFLAGS="-fPIC" cmake .. -DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++ -DFLATBUFFERS_BUILD_FLATC=1 -DCMAKE_INSTALL_PREFIX:PATH=$BASEDIR/flatbuffers-arm32 -DFLATBUFFERS_BUILD_TESTS=0
make all install

# Building FlatBuffers for your Raspberry Pi
cd $BASEDIR
mkdir tflite
cd tflite
cp $BASEDIR/tensorflow/tensorflow/lite/schema/schema.fbs .
$BASEDIR/flatbuffers/build/flatc -c --gen-object-api --reflect-types --reflect-names schema.fbs

# Building Arm NN
cd $BASEDIR/armnn
mkdir build
cd build

sed -i '350d' $BASEDIR/armnn/cmake/GlobalConfig.cmake
sed -i '350iadd_definitions(-DDYNAMIC_BACKEND_BUILD_DIR="/home/pi/armnn-dist")' $BASEDIR/armnn/cmake/GlobalConfig.cmake

cmake .. -DCMAKE_LINKER=/usr/bin/arm-linux-gnueabihf-ld -DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++ -DCMAKE_C_COMPILER_FLAGS=-fPIC -DCMAKE_CXX_FLAGS=-mfpu=neon -DARMCOMPUTE_ROOT=$BASEDIR/ComputeLibrary -DARMCOMPUTE_BUILD_DIR=$BASEDIR/ComputeLibrary/build -DBOOST_ROOT=$BASEDIR/boost -DTF_GENERATED_SOURCES=$BASEDIR/tensorflow-protobuf -DBUILD_TF_PARSER=1 -DBUILD_ONNX_PARSER=1 -DONNX_GENERATED_SOURCES=$BASEDIR/onnx -DBUILD_TF_LITE_PARSER=1 -DTF_LITE_GENERATED_PATH=$BASEDIR/tflite -DFLATBUFFERS_ROOT=$BASEDIR/flatbuffers-arm32 -DFLATC_DIR=$BASEDIR/flatbuffers/build -DPROTOBUF_ROOT=$BASEDIR/protobuf-arm -DARMCOMPUTENEON=1 -DARMNNREF=1 -DSAMPLE_DYNAMIC_BACKEND=1 -DDYNAMIC_BACKEND_PATHS=/home/pi/armnn-dist/src/dynamic/sample
make

# Extracting Arm NN on your Raspberry Pi and running a sample program
#Set the versions based on /armnn/include/armnn/Version.hpp
# fixed armnn commit -> 22.0.0
ARMNN_MAJOR_VERSION=22
ARMNN_MINOR_VERSION=0
ARMNN_PATCH_VERSION=0

cd $BASEDIR/armnn/src/dynamic/sample
mkdir build
cd build
cmake -DCMAKE_LINKER=/usr/bin/arm-linux-gnueabihf-ld -DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++ -DCMAKE_CXX_FLAGS=--std=c++14 -DCMAKE_C_COMPILER_FLAGS=-fPIC -DBOOST_ROOT=$BASEDIR/boost -DBoost_SYSTEM_LIBRARY=$BASEDIR/boost/lib/libboost_system.a -DBoost_FILESYSTEM_LIBRARY=$BASEDIR/boost/lib/libboost_filesystem.a -DARMNN_PATH=$BASEDIR/armnn/build/libarmnn.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION ..
make

cd $BASEDIR
mkdir armnn-dist
mkdir armnn-dist/armnn
mkdir armnn-dist/armnn/lib
cp $BASEDIR/armnn/build/libarmnn.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libarmnn.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnn.so.$ARMNN_MAJOR_VERSION
ln -s libarmnn.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnn.so
cp $BASEDIR/armnn/build/libarmnnTfParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libarmnnTfParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnTfParser.so.$ARMNN_MAJOR_VERSION
ln -s libarmnnTfParser.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnTfParser.so
cp $BASEDIR/protobuf-arm/lib/libprotobuf.so.15.0.1 $BASEDIR/armnn-dist/armnn/lib/libprotobuf.so
cp $BASEDIR/protobuf-arm/lib/libprotobuf.so.15.0.1 $BASEDIR/armnn-dist/armnn/lib/libprotobuf.so.15
cp -r $BASEDIR/armnn/include $BASEDIR/armnn-dist/armnn/include
cp -r $BASEDIR/boost $BASEDIR/armnn-dist/boost

cp $BASEDIR/armnn/build/libtimelineDecoder.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libtimelineDecoder.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libtimelineDecoder.so.$ARMNN_MAJOR_VERSION
ln -s libtimelineDecoder.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libtimelineDecoder
cp $BASEDIR/armnn/build/libtimelineDecoderJson.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libtimelineDecoderJson.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libtimelineDecoderJson.so.$ARMNN_MAJOR_VERSION
ln -s libtimelineDecoderJson.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libtimelineDecoderJson
cp $BASEDIR/armnn/build/libarmnnBasePipeServer.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libarmnnBasePipeServer.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnBasePipeServer.so.$ARMNN_MAJOR_VERSION
ln -s libarmnnBasePipeServer.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnBasePipeServer

cp $BASEDIR/armnn/build/libarmnnOnnxParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libarmnnOnnxParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnOnnxParser.so.$ARMNN_MAJOR_VERSION
ln -s libarmnnOnnxParser.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnOnnxParser
cp $BASEDIR/armnn/build/libarmnnTfLiteParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib
ln -s libarmnnTfLiteParser.so.$ARMNN_MAJOR_VERSION.$ARMNN_MINOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnTfLiteParser.so.$ARMNN_MAJOR_VERSION
ln -s libarmnnTfLiteParser.so.$ARMNN_MAJOR_VERSION $BASEDIR/armnn-dist/armnn/lib/libarmnnTfLiteParser

mkdir -p $BASEDIR/armnn-dist/src/backends/backendsCommon/test/
cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/testSharedObject $BASEDIR/armnn-dist/src/backends/backendsCommon/test/testSharedObject/

cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/testDynamicBackend/ $BASEDIR/armnn-dist/src/backends/backendsCommon/test/testDynamicBackend/
cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath1/ $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath1/

mkdir -p $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2
cp $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath2/Arm_CpuAcc_backend.so $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/

ln -s Arm_CpuAcc_backend.so $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/Arm_CpuAcc_backend.so.1
ln -s Arm_CpuAcc_backend.so.1 $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/Arm_CpuAcc_backend.so.1.2
ln -s Arm_CpuAcc_backend.so.1.2 $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/Arm_CpuAcc_backend.so.1.2.3
cp $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath2/Arm_GpuAcc_backend.so $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/
ln -s nothing $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath2/Arm_no_backend.so

mkdir -p $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath3

cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath5/ $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath5
cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath6/ $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath6

mkdir -p $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath7

cp -r $BASEDIR/armnn/build/src/backends/backendsCommon/test/backendsTestPath9/ $BASEDIR/armnn-dist/src/backends/backendsCommon/test/backendsTestPath9

mkdir -p $BASEDIR/armnn-dist/src/backends/dynamic/reference
cp $BASEDIR/armnn/build/src/backends/dynamic/reference/Arm_CpuRef_backend.so $BASEDIR/armnn-dist/src/backends/dynamic/reference/

mkdir -p $BASEDIR/armnn-dist/src/dynamic/sample
cp $BASEDIR/armnn/src/dynamic/sample/build/libArm_SampleDynamic_backend.so $BASEDIR/armnn-dist/src/dynamic/sample/
cp $BASEDIR/armnn/samples/DynamicSample.cpp $BASEDIR/armnn-dist

cp $BASEDIR/armnn/build/UnitTests $BASEDIR/armnn-dist
cp $BASEDIR/armnn/samples/SimpleSample.cpp $BASEDIR/armnn-dist

tar -czf $BASEDIR/armnn-dist.tar.gz armnn-dist

