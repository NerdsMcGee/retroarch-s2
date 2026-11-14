#!/bin/bash
# Clean build of the Flycast JIT core: $SW2_CORES/libretro-flycast-jit, a
# libretro/flycast checkout with switch2/patches/libretro-flycast-jit.patch
# applied. Writes $SW2_OUT/flycast_jit.a. Paths come from switch2/env.sh.
. "$(dirname "$0")/../env.sh" || exit 1
LOGF=${SW2_LOGS:-$SW2_CORES}/flycast_jit.log
cd "$SW2_CORES/libretro-flycast-jit" || exit 1
find . -name "*.o" -delete; rm -f *_libretro_libnx.a
make -f Makefile platform=libounce -j8 > "$LOGF" 2>&1
rc=$?
echo rc=$rc
ls -l *_libretro_libnx.a 2>/dev/null
grep -m8 "error" "$LOGF"
mkdir -p "$SW2_OUT"
[ $rc -eq 0 ] && cp parallel_dc_libretro_libnx.a "$SW2_OUT/flycast_jit.a" && echo copied
