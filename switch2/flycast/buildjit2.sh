#!/bin/bash
# Incremental build of the Flycast JIT core, then its NRO through
# build_cores_switch2.sh: out/cores/flycast_libretro_libnx.nro in this
# checkout. Paths come from switch2/env.sh.
. "$(dirname "$0")/../env.sh" || exit 1
LOGD=${SW2_LOGS:-$SW2_CORES}
cd "$SW2_CORES/libretro-flycast-jit" || exit 1
make -f Makefile platform=libounce -j8 > "$LOGD/flycast_jit.log" 2>&1
rc=$?
echo rc=$rc
grep -m8 "error" "$LOGD/flycast_jit.log"
if [ $rc -eq 0 ]; then
  mkdir -p "$SW2_OUT"
  cp parallel_dc_libretro_libnx.a "$SW2_OUT/flycast_jit.a"
  cd "$SW2_REPO" || exit 1
  ./build_cores_switch2.sh flycast="$SW2_OUT/flycast_jit.a" > "$LOGD/flycast_nro.log" 2>&1
  echo nro rc=$? fail=$(grep -c "build failed" "$LOGD/flycast_nro.log")
  ls -l out/cores/flycast_libretro_libnx.nro
fi
