#!/bin/sh
# Assembles doc/demo.gif from build/demo_frames (see generate_demo_test.dart).
set -e
cd "$(dirname "$0")/.."
FPS=12
FILTER="fps=$FPS,crop=400:470:0:56,scale=360:-1:flags=lanczos"
ffmpeg -y -loglevel error -framerate $FPS -i build/demo_frames/f%03d.png \
  -vf "$FILTER,palettegen=max_colors=96:stats_mode=diff" build/palette.png
ffmpeg -y -loglevel error -framerate $FPS -i build/demo_frames/f%03d.png -i build/palette.png \
  -lavfi "$FILTER [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  -loop 0 doc/demo.gif
ls -l doc/demo.gif
