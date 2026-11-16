#!/bin/zsh
# Full clean release build with the installed devkit: every core (Flycast,
# Mupen64Plus-Next and bsnes included) from zero objects, the frontend (this checkout)
# from zero objects, one NRO per core, then a scan for trace strings.
# Paths come from switch2/env.sh. NROs and logs go to out/release.
. "${0:A:h}/env.sh" || exit 1
V=$SW2_REPO
O=$SW2_OUT
OUT=$V/out/release
L=$OUT/logs
LOG=$OUT/rebuild.log
STAMP=$OUT/.rebuild.stamp
mkdir -p $OUT $L $O
: > $LOG
touch $STAMP
export SW2_LOGS=$L
say() { echo "$(date +%H:%M:%S) $@" | tee -a $LOG; }
size() { wc -c < "$1" | tr -d ' '; }
say "devkit: $(head -1 $DEVKITPRO/ounce-devkit-version.txt) ($(sed -n 2p $DEVKITPRO/ounce-devkit-version.txt))"

clean_make() { # dir makefile
  (cd "$1" && make -f "$2" platform=libounce clean >/dev/null 2>&1)
  find "$1" -name '*_libretro_libnx.a' -delete 2>/dev/null
}

# 1. makefile cores (build_core.py copies to $SW2_OUT/<name>.a)
for spec in \
  "snes9x libretro-snes9x/libretro Makefile" \
  "snes9x2010 libretro-snes9x2010 Makefile.libretro" \
  "nestopia libretro-nestopia/libretro Makefile" \
  "quicknes libretro-quicknes Makefile" \
  "mesen libretro-mesen/Libretro Makefile" \
  "gearboy libretro-gearboy/platforms/libretro Makefile" \
  "sameboy libretro-sameboy/libretro Makefile" \
  "vba_next libretro-vba_next Makefile.libretro" \
  "genesis_plus_gx libretro-genesis_plus_gx Makefile.libretro" \
  "gearsystem libretro-gearsystem/platforms/libretro Makefile" \
  "mednafen_pce_fast libretro-beetle_pce_fast Makefile" \
  "mednafen_supergrafx libretro-beetle_supergrafx Makefile" \
  "handy libretro-handy Makefile" \
  "prosystem libretro-prosystem Makefile" \
  "gambatte libretro-gambatte Makefile" \
  "stella libretro-stella/src/os/libretro Makefile src/os/libretro"; do
  set -- ${=spec}
  clean_make $SW2_CORES/$2 $3
  if python3 $V/switch2/build_core.py $1 $4 >> $LOG 2>&1; then say "OK $1"; else say "FAIL $1"; fi
done
for spec in "picodrive $SW2_WORK/picodrive" "fceumm $SW2_WORK/libretro-fceumm" \
  "pcsx_rearmed $SW2_CORES/libretro-pcsx_rearmed"; do
  set -- ${=spec}
  clean_make $2 Makefile.libretro
  if (cd $2 && make -f Makefile.libretro platform=libounce -j10 > $L/$1.log 2>&1) && [ -f $2/${1}_libretro_libnx.a ]; then
    cp $2/${1}_libretro_libnx.a $O/$1.a; say "OK $1"
  else say "FAIL $1"; fi
done

# 2. mgba: the devkit's CMake toolchain, fresh build directory
B=$SW2_CORES/libretro-mgba/build-sw2sdk
rm -rf $B
if $CMAKE -S $SW2_CORES/libretro-mgba -B $B \
    -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/libounce/cmake/Switch2.cmake \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
    -DBUILD_LIBRETRO=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF -DBUILD_LTO=ON \
    -DBUILD_SDL=OFF -DBUILD_QT=OFF -DBUILD_TEST=OFF -DBUILD_SUITE=OFF -DBUILD_EXAMPLE=OFF \
    -DBUILD_CINEMA=OFF -DBUILD_HEADLESS=OFF -DBUILD_PERF=OFF -DBUILD_PYTHON=OFF -DBUILD_DOCGEN=OFF \
    -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF -DUSE_EPOXY=OFF \
    -DDISABLE_DEPS=ON -DUSE_DEBUGGERS=OFF -DUSE_GDB_STUB=OFF -DENABLE_SCRIPTING=OFF \
    -DUSE_FFMPEG=OFF -DUSE_ZLIB=OFF -DUSE_PNG=OFF -DUSE_LIBZIP=OFF -DUSE_MINIZIP=OFF -DUSE_LZMA=OFF \
    -DUSE_SQLITE3=OFF -DUSE_ELF=OFF -DUSE_EDITLINE=OFF -DUSE_JSON_C=OFF -DUSE_DISCORD_RPC=OFF \
    -DM_CORE_GB=ON -DM_CORE_GBA=ON > $L/mgba.log 2>&1 \
  && (cd $B && make mgba_libretro -j10 >> $L/mgba.log 2>&1) && [ -f $B/mgba_libretro.a ]; then
  cp $B/mgba_libretro.a $O/mgba.a; say "OK mgba"
else say "FAIL mgba"; fi

# 3. Flycast: its own clean build script (writes $SW2_OUT/flycast_jit.a)
if bash $V/switch2/flycast/buildjit.sh > $L/flycast_build.log 2>&1 && grep -q "^copied" $L/flycast_build.log; then
  say "OK flycast"; else say "FAIL flycast"; fi

# 4. Mupen64Plus-Next (ParaLLEl-RDP/RSP on, per its libounce block)
M=$SW2_CORES/libretro-mupen64plus_next
(cd $M && make platform=libounce clean >/dev/null 2>&1)
find $M -name '*.o' -delete; rm -f $M/mupen64plus_next_libretro_libnx.a
if (cd $M && make platform=libounce -j10 > $L/mupen64plus_next.log 2>&1) && [ -f $M/mupen64plus_next_libretro_libnx.a ]; then
  cp $M/mupen64plus_next_libretro_libnx.a $O/mupen64plus_next.a; say "OK mupen64plus_next"
else say "FAIL mupen64plus_next"; fi

# 5. bsnes: the nall build that libretro-super's recipe uses. local=false
# keeps bsnes from adding -march=native.
BS=$SW2_CORES/libretro-bsnes/bsnes
find $BS/obj -name '*.o' -delete 2>/dev/null; find $BS/obj -name '*.d' -delete 2>/dev/null
rm -f $BS/out/bsnes_libretro_libnx.a
if (cd $BS && make -f GNUmakefile target=libretro binary=library local=false platform=libounce -j10 > $L/bsnes.log 2>&1) \
    && [ -f $BS/out/bsnes_libretro_libnx.a ]; then
  cp $BS/out/bsnes_libretro_libnx.a $O/bsnes.a; say "OK bsnes"
else say "FAIL bsnes"; fi

# 6. frontend from zero objects, then one NRO per core
cd $V
find . -name '*.o' -delete; find . -name '*.d' -delete
rm -f retroarch_switch.elf retroarch_switch.nro libretro_libnx.a $OUT/*.nro(N)
if make -f Makefile.libounce HAVE_STATIC_DUMMY=1 -j10 > $L/frontend.log 2>&1 && [ -f retroarch_switch.nro ]; then
  cp retroarch_switch.nro $OUT/retroarch_switch.nro; say "FRONTEND OK $(size retroarch_switch.nro)"
else say "FRONTEND FAIL"; exit 1; fi
for name in snes9x snes9x2010 bsnes nestopia quicknes mesen gearboy sameboy vba_next genesis_plus_gx \
  gearsystem mednafen_pce_fast mednafen_supergrafx handy prosystem gambatte stella mgba picodrive \
  fceumm pcsx_rearmed flycast mupen64plus_next; do
  lib=$O/$name.a
  [ $name = flycast ] && lib=$O/flycast_jit.a
  if [ ! -f $lib ] || [ $lib -ot $STAMP ]; then say "NRO SKIP $name (no fresh .a)"; continue; fi
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
