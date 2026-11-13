#!/bin/zsh
# Release link: the frontend (scratch/ra-vk, tracing removed) from zero
# objects, then one NRO per core. N64 is not part of the release.
R=/Volumes/switch/recomps
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH
V=$R/scratch/ra-vk
O=$R/cores/out
OUT=$V/out/release
LOG=$R/scratch/link_release.log
: > $LOG
mkdir -p $OUT
say() { echo "$(date +%H:%M:%S) $@" | tee -a $LOG; }
cp $R/cores/libretro-pcsx_rearmed/pcsx_rearmed_libretro_libnx.a $O/pcsx_rearmed.a

cd $V
find . -name '*.o' -delete; find . -name '*.d' -delete
rm -f retroarch_switch.elf retroarch_switch.nro libretro_libnx.a
if make -f Makefile.libounce HAVE_STATIC_DUMMY=1 -j10 > $OUT/build_frontend.log 2>&1 && [ -f retroarch_switch.nro ]; then
  cp retroarch_switch.nro $OUT/retroarch_switch.nro; say "FRONTEND OK $(stat -f %z retroarch_switch.nro)"
else say "FRONTEND FAIL"; exit 1; fi

for name in snes9x snes9x2010 nestopia quicknes mesen gearboy sameboy vba_next genesis_plus_gx \
  gearsystem mednafen_pce_fast mednafen_supergrafx handy prosystem gambatte stella mgba picodrive \
  fceumm pcsx_rearmed flycast; do
  lib=$O/$name.a
  [ $name = flycast ] && lib=$O/flycast_jit.a
  cp $lib libretro_libnx.a
  rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
  if make -f Makefile.libounce -j10 > $OUT/build_$name.log 2>&1 && [ -f retroarch_switch.nro ]; then
    cp retroarch_switch.nro $OUT/${name}_libretro_libnx.nro; say "NRO OK $name $(stat -f %z retroarch_switch.nro)"
  else say "NRO FAIL $name"; fi
done
n=0; for f in $OUT/*.nro; do s=$(strings $f | grep -cE "sw2_trace|retroarch-trace|menuwatch|swapgap|^fc: |^psx: |vk: ctx"); [ $s -ne 0 ] && { say "TRACE STRINGS $s in $f"; n=1; }; done
[ $n -eq 0 ] && say "no trace strings in any NRO"
say "ALL DONE"
