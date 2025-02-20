#!/bin/bash

## $1: target
## $2: build dir (prefix)
## $3: destination directory where ffmpeg binary will copy to

## ERRORS: 
## ERROR: shine not found using pkg-config (full) sudo apt-get install libshine-dev


## Standalone Toolchain
## ~/Android/Sdk/ndk-bundle/build/tools$ 
## ./make-standalone-toolchain.sh --arch=arm64 --install-dir=/tmp/toolchain-arm64-21

set -e
set -x

NDK="/home/deamon/Android/Sdk/ndk-bundle"

export FFMPEG_VERSION="4.0"		#3.3.2
export TARGET="arm64-v8a"		#armv7-a, arm64-v8a
export FLAVOR="full"			#full, lite
export PREFIX=$(pwd)/build_dir
export DESTINATION_FOLDER=$(pwd)/final/$FFMPEG_VERSION/$TARGET

NATIVE_SYSROOT=/

ARM_SYSROOT="/tmp/toolchain-arm-21/sysroot"
ARM_PREBUILT="/tmp/toolchain-arm-21"

ARM64_SYSROOT="/tmp/toolchain-arm64-21/sysroot"
ARM64_PREBUILT="/tmp/toolchain-arm64-21"




## No longer support MIPS MIPS64

# MIPS_SYSROOT=$NDK/platforms/android-16/arch-mips/
# MIPS_PREBUILT=$NDK/toolchains/mipsel-linux-android-4.9/prebuilt/darwin-x86_64
# MIPS_CROSS_PREFIX=$MIPS_PREBUILT/bin/$HOST-

# MIPS64_SYSROOT=$NDK/platforms/android-21/arch-mips64/
# MIPS64_PREBUILT=$NDK/toolchains/mips64el-linux-android-4.9/prebuilt/darwin-x86_64
# MIPS64_CROSS_PREFIX=$MIPS64_PREBUILT/bin/$HOST-

if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
    echo "Downloading ffmpeg-${FFMPEG_VERSION}.tar.bz2"
    curl -LO http://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2
    echo "extracting ffmpeg-${FFMPEG_VERSION}.tar.bz2"
    tar -xf ffmpeg-${FFMPEG_VERSION}.tar.bz2
else
    echo "Using existing `pwd`/ffmpeg-${FFMPEG_VERSION}"
fi

LIBX264_VERSION="snapshot-20171130-2245"
if [ ! -d "x264-$LIBX264_VERSION" ]; then
    echo "Downloading x264-$LIBX264_VERSION"
    curl -O "ftp://ftp.videolan.org/pub/videolan/x264/snapshots/x264-$LIBX264_VERSION.tar.bz2"
    tar -xf "x264-$LIBX264_VERSION.tar.bz2"
else
    echo "Using existing `pwd`/x264-$LIBX264_VERSION"
fi

OPUS_VERSION="1.1.5"
if [ ! -d "opus-${OPUS_VERSION}" ]; then
   echo "Downloading opus-${OPUS_VERSION}"
   curl -LO https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz
   tar -xzf opus-${OPUS_VERSION}.tar.gz
else
   echo "Using existing `pwd`/opus-${OPUS_VERSION}"
fi

FDK_AAC_VERSION="0.1.5"
if [ ! -d "fdk-aac-${FDK_AAC_VERSION}" ]; then
    echo "Downloading fdk-aac-${FDK_AAC_VERSION}"
    curl -LO http://downloads.sourceforge.net/opencore-amr/fdk-aac-${FDK_AAC_VERSION}.tar.gz
    tar -xzf fdk-aac-${FDK_AAC_VERSION}.tar.gz
else
    echo "Using existing `pwd`/fdk-aac-${FDK_AAC_VERSION}"
fi

LAME_MAJOR="3.99"
LAME_VERSION="3.99.5"
if [ ! -d "lame-${LAME_VERSION}" ]; then
    echo "Downloading lame-${LAME_VERSION}"
    curl -LO http://downloads.sourceforge.net/project/lame/lame/${LAME_MAJOR}/lame-${LAME_VERSION}.tar.gz
    tar -xzf lame-${LAME_VERSION}.tar.gz
    curl -L -o lame-${LAME_VERSION}/config.guess "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD"
    curl -L -o lame-${LAME_VERSION}/config.sub "http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD"
else
    echo "Using existing `pwd`/lame-${LAME_VERSION}"
fi

if [ ! -d "shine" ]; then
    echo "Cloning https://github.com/toots/shine"
    git clone --depth=1 https://github.com/toots/shine.git
else
    echo "Using existing `pwd`/shine"
fi

LIBOGG_VERSION="1.3.2"
if [ ! -d "libogg-${LIBOGG_VERSION}" ]; then
    echo "Downloading libogg-${LIBOGG_VERSION}"
    curl -LO http://downloads.xiph.org/releases/ogg/libogg-${LIBOGG_VERSION}.tar.gz
    tar -xzf libogg-${LIBOGG_VERSION}.tar.gz
else
    echo "Using existing `pwd`/libogg-${LIBOGG_VERSION}"
fi

LIBVORBIS_VERSION="1.3.4"
if [ ! -d "libvorbis-${LIBVORBIS_VERSION}" ]; then
    echo "Downloading libvorbis-${LIBVORBIS_VERSION}"
    curl -LO http://downloads.xiph.org/releases/vorbis/libvorbis-${LIBVORBIS_VERSION}.tar.gz
    tar -xzf libvorbis-${LIBVORBIS_VERSION}.tar.gz
else
    echo "Using existing `pwd`/libvorbis-${LIBVORBIS_VERSION}"
fi

# LIBVPX_VERSION="1.6.1"
# if [ ! -d "libvpx-${LIBVPX_VERSION}" ]; then
#     echo "Downloading libvpx-${LIBVPX_VERSION}"
#     curl -LO http://storage.googleapis.com/downloads.webmproject.org/releases/webm/libvpx-${LIBVPX_VERSION}.tar.bz2
#     tar -xf libvpx-${LIBVPX_VERSION}.tar.bz2
# else
#     echo "Using existing `pwd`/libvpx-${LIBVPX_VERSION}"
# fi

# Download lib openssl prebuilt
OPENSSL_PREBUILT_FOLDER="$(pwd)/openssl-prebuilt"
if [ ! -d $OPENSSL_PREBUILT_FOLDER/android ]; then
    curl -LO "https://github.com/leenjewel/openssl_for_ios_and_android/releases/download/openssl-1.0.2k/openssl.1.0.2k_for_android_ios.zip"
    mkdir -p $OPENSSL_PREBUILT_FOLDER && unzip -q "openssl.1.0.2k_for_android_ios.zip" -d $OPENSSL_PREBUILT_FOLDER
fi


function build_one
{

if [ "$(uname)" == "Darwin" ]; then
    brew install yasm nasm
else
    # Install nasm >= 2.13 for libx264
    if [ ! -d "nasm-2.13.03" ]; then
        curl -LO 'http://www.nasm.us/pub/nasm/releasebuilds/2.13.03/nasm-2.13.03.tar.xz'
        tar -xf nasm-2.13.03.tar.xz
    fi
    pushd nasm-2.13.03
        ./configure --prefix=/usr
        make
        sudo make install
    popd
fi

if [ $ARCH == "native" ]
then
    SYSROOT=$NATIVE_SYSROOT
    HOST=
    CROSS_PREFIX=
    if [ "$(uname)" == "Darwin" ]; then
        brew install openssl
    else 
        sudo apt-get install -y libssl-dev
    fi
elif [ $ARCH == "arm" ]
then
    SYSROOT=$ARM_SYSROOT
    HOST=arm-linux-androideabi
    CROSS_PREFIX=$ARM_PREBUILT/bin/$HOST-
    OPTIMIZE_CFLAGS="$OPTIMIZE_CFLAGS "
    echo $SYSROOT
    echo $HOST
    echo $CROSS_PREFIX
    echo OPTIMIZE_CFLAGS
elif [ $ARCH == "arm64" ]
then
    SYSROOT=$ARM64_SYSROOT
    HOST=aarch64-linux-android
    CROSS_PREFIX=$ARM64_PREBUILT/bin/$HOST-
fi

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
export CPP="${CROSS_PREFIX}cpp"
export CXX="${CROSS_PREFIX}clang++"		#g++
export CC="${CROSS_PREFIX}clang"	#gcc
echo $CC
export LD="${CROSS_PREFIX}ld"
echo $LD
export AR="${CROSS_PREFIX}ar"
export NM="${CROSS_PREFIX}nm"
export RANLIB="${CROSS_PREFIX}ranlib"
export LDFLAGS="-L$PREFIX/lib -L/ -fPIE -pie -fuse-ld=gold -Wl,-V"
export CFLAGS="$OPTIMIZE_CFLAGS --sysroot=$SYSROOT -fPIE -D__ANDROID_API__=21"
export CXXFLAGS="$CFLAGS "
export CPPFLAGS="--sysroot=$SYSROOT "
export STRIP=${CROSS_PREFIX}strip
export PATH="$PATH:$PREFIX/bin/"

if [ "$FLAVOR" = "full" ]; then 
    pushd x264-$LIBX264_VERSION
        ./configure \
            --cross-prefix=$CROSS_PREFIX \
            --sysroot=$SYSROOT \
            --host=$HOST \
            --enable-pic \
            --enable-static \
            --disable-shared \
            --disable-cli \
            --disable-opencl \
            --prefix=$PREFIX \
            $LIBX264_FLAGS

        make clean
        make -j8
        make install
    popd

    # Non-free
    pushd fdk-aac-${FDK_AAC_VERSION}
        ./configure \
            --prefix=$PREFIX \
            --host=$HOST \
            --enable-static \
            --disable-shared \
            --with-sysroot=$SYSROOT

        make clean
        make -j8
        make install
    popd
fi;


pushd opus-${OPUS_VERSION}
./configure \
   --prefix=$PREFIX \
   --host=$HOST \
   --enable-static \
   --disable-shared \
   --disable-doc \
   --disable-extra-programs

make clean
make -j8
make install V=1
popd

pushd lame-${LAME_VERSION}
./configure \
    --prefix=$PREFIX \
    --host=$HOST \
    --enable-static \
    --disable-shared 

make clean
make -j8
make install
popd

pushd shine
./bootstrap
./configure \
    --prefix=$PREFIX \
    --host=$HOST \
    --enable-static \
    --disable-shared

make clean
make -j8
make install
popd

pushd libogg-${LIBOGG_VERSION}
./configure \
    --prefix=$PREFIX \
    --host=$HOST \
    --enable-static \
    --disable-shared \
    --with-sysroot=$SYSROOT

make clean
make -j8
make install
popd

pushd libvorbis-${LIBVORBIS_VERSION}
./configure \
    --prefix=$PREFIX \
    --host=$HOST \
    --enable-static \
    --disable-shared \
    --with-sysroot=$SYSROOT \
    --with-ogg=$PREFIX

make clean
make -j8
make install
popd

# (wget --no-check-certificate https://raw.githubusercontent.com/FFmpeg/gas-preprocessor/master/gas-preprocessor.pl && \
#     chmod +x gas-preprocessor.pl && \
#     sudo mv gas-preprocessor.pl /usr/bin) || exit 1
pushd ffmpeg-$FFMPEG_VERSION

if [ $ARCH == "native" ] 
then
    CROSS_COMPILE_FLAGS=
else 
    CROSS_COMPILE_FLAGS="--target-os=linux \
        --arch=$ARCH \
        --cross-prefix=$CROSS_PREFIX \
        --enable-cross-compile \
        --sysroot=$SYSROOT"
fi

if [ "$FLAVOR" = "full" ]; then
    # Build - FULL version
    #--disable-ffserver \
    #--disable-shared \
    #--enable-libshine \
    #--enable-openssl \

    ./configure --prefix=$PREFIX \
        $CROSS_COMPILE_FLAGS \
        --pkg-config=$(which pkg-config) \
        --pkg-config-flags="--static" \
        --enable-pic \
        --enable-small \
        --enable-gpl \
        --enable-nonfree \
        --enable-static \
        --disable-shared \
        --enable-ffmpeg \
        --disable-ffplay \
        --disable-ffprobe \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvorbis \
        --enable-libx264 \
        --enable-libfdk-aac \
        --disable-linux-perf \
        --enable-bsf=aac_adtstoasc \
        --disable-doc \
        $ADDITIONAL_CONFIGURE_FLAG
else 
    # Build - LITE version
    # --disable-ffserver \
    # --enable-libshine \
    ./configure --prefix=$PREFIX \
        $CROSS_COMPILE_FLAGS \
        --pkg-config=$(which pkg-config) \
        --pkg-config-flags="--static" \
        --enable-pic \
        --enable-small \
        --enable-gpl \
        \
        --disable-shared \
        --enable-static \
        \
        --enable-ffmpeg \
        --disable-ffplay \
        --disable-ffprobe \
        \
        --disable-protocols \
        --enable-protocol='file,pipe' \
        \
        --disable-demuxers \
        --disable-muxers \
        --enable-demuxer='aac,avi,dnxhd,flac,flv,gif,h261,h263,h264,image2,matroska,webm,mov,mp3,mp4,mpeg,ogg,srt,wav,webvtt,gif,image2,image2pipe,mjpeg' \
        --enable-muxer='3gp,dnxhd,flac,flv,gif,image2,matroska,webm,mov,mp3,mp4,mpeg,ogg,opus,srt,wav,webvtt,ipod,gif,image2,image2pipe,mjpeg' \
        \
        --disable-encoders \
        --disable-decoders \
        --enable-encoder='aac,dnxhd,flac,flv,gif,libmp3lame,libopus,libshine,libvorbis,mpeg4,png,mjpeg,gif,srt,subrip,webvtt' \
        --enable-decoder='aac,aac_at,aac_fixed,aac_latm,dnxhd,flac,flv,h261,h263,h263i,h263p,h264,vp8,vp9,libopus,libvorbis,mp3,mpeg4,wavpack,png,mjpeg,gif,pcm_s16le,pcm_s16be,rawvideo,srt,webvtt' \
        \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvorbis \
        --enable-bsf=aac_adtstoasc \
        \
        --disable-doc \
        $ADDITIONAL_CONFIGURE_FLAG
fi;

make clean
make -j8
make install V=1

mkdir -p $DESTINATION_FOLDER/$FLAVOR/
cp $PREFIX/bin/ffmpeg $DESTINATION_FOLDER/$FLAVOR/

popd
}

if [ $TARGET == 'arm-v7n' ]; then
    #arm v7n
    CPU=armv7-a
    ARCH=arm
    OPTIMIZE_CFLAGS="-mfloat-abi=softfp -mfpu=neon -marm -mtune=cortex-a8 -march=$CPU -Os -O3"
    ADDITIONAL_CONFIGURE_FLAG="--enable-neon "
    LIBX264_FLAGS=
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-armeabi-v7a/. $PREFIX
    build_one
elif [ $TARGET == 'arm64-v8a' ]; then
    #arm64-v8a
    CPU=armv8-a
    ARCH=arm64
    OPTIMIZE_CFLAGS="-march=$CPU -Os -O3"
    ADDITIONAL_CONFIGURE_FLAG=
    LIBX264_FLAGS=
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-arm64-v8a/. $PREFIX
    build_one
elif [ $TARGET == 'x86_64' ]; then
    #x86_64
    CPU=x86-64
    ARCH=x86_64
    OPTIMIZE_CFLAGS="-fomit-frame-pointer -march=$CPU -Os -O3"
    ADDITIONAL_CONFIGURE_FLAG=
    LIBX264_FLAGS=
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-x86_64/. $PREFIX
    build_one
elif [ $TARGET == 'i686' ]; then
    #x86
    CPU=i686
    ARCH=i686
    OPTIMIZE_CFLAGS="-fomit-frame-pointer -march=$CPU -Os -O3"
    # disable asm to fix 
    ADDITIONAL_CONFIGURE_FLAG='--disable-asm' 
    LIBX264_FLAGS="--disable-asm"
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-x86/. $PREFIX
    build_one
elif [ $TARGET == 'armv7-a' ]; then
    # armv7-a
    CPU=armv7-a
    ARCH=arm
    OPTIMIZE_CFLAGS="-mfloat-abi=softfp -marm -march=$CPU -Os -O3 "
    ADDITIONAL_CONFIGURE_FLAG=
    LIBX264_FLAGS=
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-armeabi-v7a/. $PREFIX
    build_one
elif [ $TARGET == 'arm' ]; then
    #arm
    CPU=armv5te
    ARCH=arm
    OPTIMIZE_CFLAGS="-march=$CPU -Os -O3 "
    ADDITIONAL_CONFIGURE_FLAG=
    LIBX264_FLAGS="--disable-asm"
    cp -a $OPENSSL_PREBUILT_FOLDER/android/openssl-armeabi/. $PREFIX
    build_one
elif [ $TARGET == 'native' ]; then
    # host = current machine
    CPU=x86-64
    ARCH=native
    OPTIMIZE_CFLAGS="-O2 -pipe -march=native"
    ADDITIONAL_CONFIGURE_FLAG=
    LIBX264_FLAGS=
    build_one
else
    echo "Unknown target: $TARGET"
    exit 1
fi

