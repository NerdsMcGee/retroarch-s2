#!/bin/bash
# Release link without rebuilding the cores: the frontend (this checkout)
# from zero objects, then one NRO per core from the archives already in
# $SW2_OUT (switch2/rebuild_release.sh builds them), 23 cores. Paths come from
# switch2/env.sh. NROs and logs go to out/release.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/env.sh" || exit 1
shopt -s nullglob
V=$SW2_REPO
O=$SW2_OUT
OUT=$V/out/release
L=$OUT/logs
LOG=$OUT/link.log
mkdir -p $OUT $L
: > $LOG
say() { echo "$(date +%H:%M:%S) $@" | tee -a $LOG; }
size() { wc -c < "$1" | tr -d ' '; }

cd $V
find . -name '*.o' -delete; find . -name '*.d' -delete
rm -f retroarch_switch.elf retroarch_switch.nro libretro_libnx.a
if make -f Makefile.libounce HAVE_STATIC_DUMMY=1 -j10 > $L/frontend.log 2>&1 && [ -f retroarch_switch.nro ]; then
  cp retroarch_switch.nro $OUT/retroarch_switch.nro; say "FRONTEND OK $(size retroarch_switch.nro)"
else say "FRONTEND FAIL"; exit 1; fi

for name in snes9x snes9x2010 bsnes nestopia quicknes mesen gearboy sameboy vba_next genesis_plus_gx \
  gearsystem mednafen_pce_fast mednafen_supergrafx handy prosystem gambatte stella mgba picodrive \
  fceumm pcsx_rearmed flycast mupen64plus_next; do
  lib=$O/$name.a
  [ $name = flycast ] && lib=$O/flycast_jit.a
  if [ ! -f $lib ]; then say "NRO SKIP $name (no $lib)"; continue; fi
  cp $lib libretro_libnx.a
  rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
  if make -f Makefile.libounce -j10 > $L/nro_$name.log 2>&1 && [ -f retroarch_switch.nro ]; then
    cp retroarch_switch.nro $OUT/${name}_libretro_libnx.nro; say "NRO OK $name $(size retroarch_switch.nro)"
  else say "NRO FAIL $name"; fi
done
rm -f libretro_libnx.a retroarch_switch.elf retroarch_switch.nro
n=0; for f in $OUT/*.nro; do s=$(strings $f | grep -cE "sw2_trace|retroarch-trace|menuwatch|swapgap|^fc: |^psx: |^n64[a-z]*: |vk: ctx|ouncehen"); [ $s -ne 0 ] && { say "TRACE STRINGS $s in $(basename $f)"; n=1; }; done
[ $n -eq 0 ] && say "no trace strings in any NRO"
say "ALL DONE"
