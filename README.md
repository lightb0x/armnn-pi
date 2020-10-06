# ARMNN compiled for Raspberry Pi 2 Model B V1.1 (Cortex-A7)

## Description
While trying [this](https://www.codeproject.com/Articles/5254336/Automatic-Trash-Classification-with-Raspberry-Pi-a), I needed to setup Arm NN for Raspberry Pi.

There are 2 introduced ways + 1 additional way to do this.

1. [ARM reference guide](https://developer.arm.com/solutions/machine-learning-on-arm/developer-material/how-to-guides/cross-compiling-arm-nn-for-the-raspberry-pi-and-tensorflow/single-page) which isn't managed properly
2. [ARM official build script](https://github.com/ARM-software/Tool-Solutions/tree/master/ml-tool-examples/build-armnn) which generates 'armnn-devenv', not tarball file
3. [ARM officiai github guide](https://github.com/ARM-software/armnn/blob/branches/armnn_20_08/BuildGuideCrossCompilation.md) which is based on arm64

Mostly, these guides assume AArch64(or ARMv8 ISA), while Raspberry Pi 2 has 32-bit processor(ARMv7 ISA).
Moreover, some of them doesn't even work and are wrong!

So I made my way out of it.

## Tested Environment
macOS 10.15.7 (19H2)
vmware fusion player version 12.0.0 (16880131)
ubuntu 18.04.5

## File description
* armnn-dist.tar.gz
	compiled and compressed tarball
	copy this file to `/home/pi` of Raspberry Pi and follow instruction of [ARM reference guide](https://developer.arm.com/solutions/machine-learning-on-arm/developer-material/how-to-guides/cross-compiling-arm-nn-for-the-raspberry-pi-and-tensorflow/extracting-arm-nn-on-your-raspberry-pi-and-running-a-sample-program)'s "Extract the libraries, binaries, and directories to your Raspberry Pi" section to move along & test

* instruction.sh
	source instruction script
	took about 2 hours on my machine (allocated 4GB of RAM on VM)

