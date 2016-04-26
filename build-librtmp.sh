#!/bin/sh

#  build-librtmp.sh
#  Automated librtmp build script for iPhoneOS and iPhoneSimulator
#
#  Created by wuqiong.
#  Copyright (c) 2016 Diveinedu.com. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#					                                                        #
SDKVERSION=`xcrun -sdk iphoneos  --show-sdk-version`						#
#					                                                        #
###########################################################################

###########################################################################
#																		    #
# Don't change anything under this line!								    #
#																		    #
###########################################################################

CURRENTPATH=`pwd`
ARCHS="i386 x86_64 armv7 armv7s arm64"
LIBRTMPREPO="git://git.ffmpeg.org/rtmpdump"
OPENSSLREPO="https://github.com/x2on/OpenSSL-for-iPhone.git"
BUILDPATH="${CURRENTPATH}/build"
OPENSSLPATH="$PWD/../OpenSSL-for-iPhone/"
LIBPATH="${CURRENTPATH}/lib"
INCLUDEPATH="${CURRENTPATH}/include"
OPENSSL_LIBPATH="${OPENSSLPATH}/lib"
OPENSSL_INCLUDEPATH="${OPENSSLPATH}/include"
SRCPATH="${CURRENTPATH}/src"
LIBRTMP="librtmp.a"
DEVELOPER=`xcode-select -print-path`

if [ ! -d "$DEVELOPER" ]; then
    echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
    echo "run"
    echo "sudo xcode-select -switch <xcode path>"
    echo "for default installation:"
    echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
    exit 1
fi


if [ ! -d "$OPENSSLPATH" ]; then
    git clone "$OPENSSLREPO" $OPENSSLPATH
fi


# Check whether openssl has already installed on the machine or not.
# libcrypt.a / libssl.a

set -e
echo 'Check openssl library'
if [ -f "${OPENSSLPATH}/lib/libcrypto.a" ] && [ -f "${OPENSSLPATH}/lib/libssl.a" ] && [ -d "${OPENSSLPATH}/include/openssl" ]; then
    echo 'Openssl library for iOS has already compiled, no need to compile openssl'
else
    echo 'Openssl lubrary for iOS not found, will compile openssl for iOS'
    pushd $OPENSSLPATH
    ./build-libssl.sh
    echo 'Succeeded to compile openssl'
    popd
fi

# Download librtmp source code from git repository
# We assuem the user already installed git client.

if [ ! -d "${SRCPATH}/rtmpdump" ]; 
then
    echo 'Clone librtmp git repository'
    git clone ${LIBRTMPREPO} src/rtmpdump
fi

cd "${SRCPATH}/rtmpdump/librtmp"
LIBRTMP_REPO=""

for ARCH in ${ARCHS}
do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
    then
        PLATFORM="iPhoneSimulator"
    else  
        PLATFORM="iPhoneOS"
    fi

    export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
    export CROSS_SDK="${PLATFORM}${SDKVERSION}.sdk"
    export BUILD_TOOLS="${DEVELOPER}"

    echo "Building librtmp for ${PLATFORM} ${SDKVERSION} ${ARCH}"
    echo "Please wait..."

    # add arch to CC=
    sed -ie "s!AR=\$(CROSS_COMPILE)ar!AR=/usr/bin/ar!" "Makefile"
    sed -ie "/CC=\$(CROSS_COMPILE)gcc/d" "Makefile"
    echo "CC=\$(CROSS_COMPILE)gcc -arch ${ARCH}" >> "Makefile"

    export CROSS_COMPILE="${DEVELOPER}/usr/bin/"  
    export XCFLAGS="-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0 -I${OPENSSL_INCLUDEPATH} -arch ${ARCH}"

    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
    then
        export XLDFLAGS="-L${OPENSSL_LIBPATH} -arch ${ARCH}"
    else
        export XLDFLAGS="-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -miphoneos-version-min=7.0 -L${OPENSSL_LIBPATH} -arch ${ARCH}"
    fi

    OUTPATH="${BUILDPATH}/librtmp-${PLATFORM}${SDKVERSION}-${ARCH}.sdk"
    mkdir -p "${OUTPATH}"
    LOG="${OUTPATH}/build-librtmp.log"

    make SYS=darwin #>> "${LOG}" 2>&1  
    make SYS=darwin prefix="${OUTPATH}" install  #>> "${LOG}" 2>&1
    make clean >> "${LOG}" 2>&1

    LIBRTMP_REPO+="${OUTPATH}/lib/${LIBRTMP} "
done

echo "Build universal library..."
lipo -create ${LIBRTMP_REPO}-output ${LIBPATH}/${LIBRTMP}

mkdir -p ${INCLUDEPATH}
cp -R ${BUILDPATH}/librtmp-iPhoneSimulator${SDKVERSION}-i386.sdk/include/ ${INCLUDEPATH}/
cp -R ${BUILDPATH}/librtmp-iPhoneSimulator${SDKVERSION}-i386.sdk/lib/pkgconfig ${LIBPATH}/

sed -i -n "1 s:^.*$:prefix=$CURRENTPATH:" ${LIBPATH}/pkgconfig/librtmp.pc
sed -i -n "3 s:^.*$:libdir=$LIBPATH:" ${LIBPATH}/pkgconfig/librtmp.pc
echo "Building done."
echo "Cleaning up..."

echo "Done."
