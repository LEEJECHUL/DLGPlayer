#!/bin/sh

BUILD_FFMPEG_FILE="build-ffmpeg.sh"
FFMPEG_IOS_BUILD_FILE_URL="https://github.com/kewlbear/FFmpeg-iOS-build-script/raw/master/$BUILD_FFMPEG_FILE"
FFMPEG_OUTPUT_FOLDER="ffmpeg"

function MakeFFmpegDir() {
  if [ ! -d "$FFMPEG_OUTPUT_FOLDER" ]
  then
    mkdir $FFMPEG_OUTPUT_FOLDER
  fi
  cd $FFMPEG_OUTPUT_FOLDER
}
function DownloadFFmpegBuildScript() {
  if [ -f "$BUILD_FFMPEG_FILE" ]
  then
  	echo "Already exist file $BUILD_FFMPEG_FILE."
  else
    (curl --verbose -L "$FFMPEG_IOS_BUILD_FILE_URL" \
        -o ./$BUILD_FFMPEG_FILE \
        && chmod +x ./$BUILD_FFMPEG_FILE) \
        || exit 1
  fi
}

function CompileFFmpeg() {
  if [ -d "./FFmpeg-iOS" ]
  then
  	echo "Already compiled ffmpeg-ios."
  else
    ./$BUILD_FFMPEG_FILE
  fi
}

MakeFFmpegDir
DownloadFFmpegBuildScript
CompileFFmpeg
