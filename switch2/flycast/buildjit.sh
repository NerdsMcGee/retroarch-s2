#!/bin/bash
# Clean build of the flycast JIT core (needed after Makefile/flag changes)
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH
cd /Volumes/switch/recomps/cores/libretro-flycast-jit
find . -name "*.o" -delete; rm -f *_libretro_libnx.a
make -f Makefile platform=libounce -j8 > /Volumes/switch/recomps/cores/flycast_jit.log 2>&1
rc=$?
echo rc=$rc
ls -l *_libretro_libnx.a 2>/dev/null
grep -m8 "error" /Volumes/switch/recomps/cores/flycast_jit.log
[ $rc -eq 0 ] && cp parallel_dc_libretro_libnx.a /Volumes/switch/recomps/cores/out/flycast_jit.a && echo copied
