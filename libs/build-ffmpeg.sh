#!/bin/sh

# directories
FF_VERSION="4.1"
#FF_VERSION="snapshot-git"
if [[ $FFMPEG_VERSION != "" ]]; then
  FF_VERSION=$FFMPEG_VERSION
fi
SOURCE=`pwd`/"build/src/ffmpeg"
FAT=`pwd`/"build/universal"
THIN=`pwd`/"build/thin"
FFMPEG=$THIN/ffmpeg

CONFIGURE_FLAGS="--enable-cross-compile --enable-static --disable-shared --disable-debug --disable-programs \
                 --disable-doc --enable-pic --enable-neon --enable-optimizations --enable-small"

ARCHS="armv7 armv7s arm64 i386 x86_64"

COMPILE="y"
LIPO="y"

DEPLOYMENT_TARGET="8.0"

if [ -f "${FAT}/lib/libspeex.a" ]; then
  brew install speex
fi

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	if [ ! `which yasm` ]
	then
		echo 'Yasm not found'
		if [ ! `which brew` ]
		then
			echo 'Homebrew not found. Trying to install...'
                        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" \
				|| exit 1
		fi
		echo 'Trying to install Yasm...'
		brew install yasm || exit 1
	fi
	if [ ! `which gas-preprocessor.pl` ]
	then
		echo 'gas-preprocessor.pl not found. Trying to install...'
		(curl -L https://github.com/libav/gas-preprocessor/raw/master/gas-preprocessor.pl \
			-o /usr/local/bin/gas-preprocessor.pl \
			&& chmod +x /usr/local/bin/gas-preprocessor.pl) \
			|| exit 1
	fi

	if [ ! -r $SOURCE ]
	then
    mkdir -p "$SOURCE"
    cd $SOURCE
		echo 'FFmpeg source not found. Trying to download...'
		curl http://www.ffmpeg.org/releases/ffmpeg-$FF_VERSION.tar.bz2 | tar xj \
			|| exit 1
    cd -
	fi

	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SOURCE/$ARCH"
		cd "$SOURCE/$ARCH"

		CFLAGS="-arch $ARCH"
		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CFLAGS="$CFLAGS -mios-simulator-version-min=$DEPLOYMENT_TARGET"
		else
		    PLATFORM="iPhoneOS"
		    CFLAGS="$CFLAGS -mios-version-min=$DEPLOYMENT_TARGET -fembed-bitcode"
		    if [ "$ARCH" = "arm64" ]
		    then
		        EXPORT="GASPP_FIX_XCODE5=1"
		    fi
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"

		# force "configure" to use "gas-preprocessor.pl" (FFmpeg 3.3)
		if [ "$ARCH" = "arm64" ]
		then
		    AS="gas-preprocessor.pl -arch aarch64 -- $CC"
		else
		    AS="gas-preprocessor.pl -- $CC"
		fi

		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"
    SPEEX=$THIN/speex/$ARCH

    if [ -f "${SPEEX}/lib/libspeex.a" ]; then
      CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-libspeex"
			CFLAGS="$CFLAGS -I$SPEEX/include"
			LDFLAGS="$LDFLAGS -L$SPEEX/lib -lspeex"
		fi

    echo "configure $ARCH -> $SOURCE/ffmpeg-$FF_VERSION"

		TMPDIR=${TMPDIR/%\/} $SOURCE/ffmpeg-$FF_VERSION/configure \
		    --target-os=darwin \
		    --arch=$ARCH \
		    --cc="$CC" \
		    --as="$AS" \
		    $CONFIGURE_FLAGS \
		    --extra-cflags="$CFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$FFMPEG/$ARCH" \
		|| exit 1

		make -j3 install $EXPORT || exit 1
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $FFMPEG/$1/lib
	for LIB in *.a
	do
		cd $CWD
		echo lipo -create `find $FFMPEG -name $LIB` -output $FAT/lib/$LIB 1>&2
		lipo -create `find $FFMPEG -name $LIB` -output $FAT/lib/$LIB || exit 1
	done

	cd $CWD
	cp -rf $FFMPEG/$1/include $FAT
fi

echo Done
