#!/bin/sh

TARGETS=$1
LIBS=`pwd`"/build/universal"

function buildLib() {
  if [ -d "${LIBS}/include/$1" ] && [ -f "${LIBS}/lib/lib$1.a" ]
  then
    echo "Already compiled $1."
  else
    sh pull-$1.sh "all"
    sh build-$1.sh "all"
  fi
}

function buildFFmpeg() {
  if [ -d "${LIBS}/include/libavcodec" ] &&
      [ -d "${LIBS}/include/libavdevice" ] &&
      [ -d "${LIBS}/include/libavfilter" ] &&
      [ -d "${LIBS}/include/libavformat" ] &&
      [ -d "${LIBS}/include/libavutil" ] &&
      [ -d "${LIBS}/include/libswresample" ] &&
      [ -d "${LIBS}/include/libswscale" ] &&
      [ -f "${LIBS}/lib/libavcodec.a" ] &&
      [ -f "${LIBS}/lib/libavdevice.a" ] &&
      [ -f "${LIBS}/lib/libavfilter.a" ] &&
      [ -f "${LIBS}/lib/libavformat.a" ] &&
      [ -f "${LIBS}/lib/libavutil.a" ] &&
      [ -f "${LIBS}/lib/libswresample.a" ] &&
      [ -f "${LIBS}/lib/libswscale.a" ]
  then
  	echo "Already compiled ffmpeg."
  else
    sh build-ffmpeg.sh
  fi
}

function buildTargets() {
  for TARGET in $1
  do
    if [ $TARGET = "ffmpeg" ]; then
      buildFFmpeg
    elif [ $TARGET = "ogg" ]; then
      buildLib $TARGET
    else
      buildLib $TARGET
    fi
  done
}

if [ ! $TARGETS ]
then
  buildTargets "speex ffmpeg"
else
  buildTargets $TARGETS
fi
