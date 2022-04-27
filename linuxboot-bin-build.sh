#!/bin/bash

# @file
#
# Copyright (c) 2020, Ampere Computing LLC.
#
# SPDX-License-Identifier: ISC
#
# LinuxBoot Binary Build
#
GOLANG_VER=1.18.4
TOOLS_DIR="`dirname $0`"
TOOLS_DIR="`readlink -f \"$TOOLS_DIR\"`"
if [ $TOOLS_DIR == /usr/bin ]; then
    TOOLS_DIR=$PWD
fi
export TOOLS_DIR

. "$TOOLS_DIR"/common-functions

OPATH=$PATH
PLATFORM_LOWER="jade"
#
# install generic cross compiler, ampere compiler will cause system hang during boot
# 
sudo apt install -y gcc-aarch64-linux-gnu

if uname -m | grep -q "x86_64"; then
    CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
fi

check_golang ${GOLANG_VER}
export GOPATH=${TOOLS_DIR}/toolchain/gosource
export GOFLAGS=-modcacherw
export GO111MODULE=off
mkdir -p ${GOPATH}
export PATH=${GOPATH}/bin:${TOOLS_DIR}/toolchain/go/bin:$PATH

LINUBOOT_DIR="`readlink -f $PWD/linuxboot`"
if [ ! -d "$LINUBOOT_DIR" ]; then
    git clone --recurse-submodules --single-branch --branch main https://github.com/linuxboot/linuxboot.git
fi
check_lzma_tool ${TOOLS_DIR}
RESULT=$?
if [ $RESULT -ne 0 ]; then
    exit 1
fi
echo "Clean up LinuxBoot binaries..."
rm -rf ${LINUBOOT_DIR}/mainboards/ampere/${PLATFORM_LOWER}/{flashkernel,flashinitramfs.*}
if [ -d ${LINUBOOT_DIR}/mainboards/ampere/${PLATFORM_LOWER}/linux ]; then
    make -C ${LINUBOOT_DIR}/mainboards/ampere/${PLATFORM_LOWER}/linux distclean
fi
LINUBOOT_MAKEFILE=${LINUBOOT_DIR}/mainboards/ampere/${PLATFORM_LOWER}/Makefile
if ! grep -q "uroot-source" "${LINUBOOT_MAKEFILE}"; then
    sed -i "s;uinitcmd=systemboot;uinitcmd=systemboot -uroot-source \$\{GOPATH\}/src/github.com/u-root/u-root;" ${LINUBOOT_MAKEFILE}
fi
make -C $LINUBOOT_DIR/mainboards/ampere/${PLATFORM_LOWER} fetch flashkernel ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILE}
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "ERROR: compile LinuxBoot binaries issue" >&2
else    
    echo "Results: $MAINBOARDS_DIR/ampere/${PLATFORM_LOWER}/flashkernel"
  	date +%T
    cp $MAINBOARDS_DIR/ampere/${PLATFORM_LOWER}/flashkernel ../
fi
echo "Results: $LINUBOOT_DIR/mainboards/ampere/${PLATFORM_LOWER}/flashkernel"
ls -l $LINUBOOT_DIR/mainboards/ampere/${PLATFORM_LOWER}/flashkernel
