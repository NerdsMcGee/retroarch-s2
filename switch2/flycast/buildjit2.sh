#!/bin/bash
# Incremental build of the flycast JIT core, then link the per-core NRO -> retroarch/out/flycast_jit2.nro
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH
cd /Volumes/switch/recomps/cores/libretro-flycast-jit
make -f Makefile platform=libounce -j8 > /Volumes/switch/recomps/cores/flycast_jit.log 2>&1
rc=$?
echo rc=$rc
grep -m8 "error" /Volumes/switch/recomps/cores/flycast_jit.log
if [ $rc -eq 0 ]; then
  cp parallel_dc_libretro_libnx.a /Volumes/switch/recomps/cores/out/flycast_jit.a
  cd /Volumes/switch/recomps/retroarch
  ./build_cores_switch2.sh flycast=/Volumes/switch/recomps/cores/out/flycast_jit.a > /Volumes/switch/recomps/scratch/nro.log 2>&1
  echo nro rc=$? fail=$(grep -c "build failed" /Volumes/switch/recomps/scratch/nro.log)
  cp out/cores/flycast_libretro_libnx.nro out/flycast_jit2.nro
  ls -l out/flycast_jit2.nro
fi
