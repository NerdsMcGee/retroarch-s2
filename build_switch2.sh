#!/bin/zsh
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=$DEVKITPRO/tools/bin:$DEVKITA64/bin:$PATH
cd /Volumes/switch/recomps/retroarch
make -f Makefile.libounce -j8 "$@"
