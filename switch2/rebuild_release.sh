#!/bin/zsh
# Clean rebuild for the Vulkan test release (SDK ounce-sdk 20261113).
# - Frontend: scratch/ra-vk (ra-a78c's GLES3, GL hand-off and deinit fixes,
#   plus the Vulkan driver, vk_switch context, slang/rslc, perf-counter fix
#   from retroarch/). Built from zero objects.
# - Cores: every core cleaned and rebuilt with switch2_rules / Switch2.cmake.
# - N64 (mupen64plus_next) is held back: not built, not linked.
# - Flycast: not rebuilt here (its tree belongs to the Flycast session); its
#   clean HAVE_VULKAN archive cores/out/flycast_jit.a is linked as is.
R=/Volumes/switch/recomps
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH:/opt/local/bin
CMAKE=$R/tools/pycmake/cmake/data/bin/cmake
V=$R/scratch/ra-vk
O=$R/cores/out
LOG=$R/scratch/rebuild_vk.log
STAMP=$R/scratch/rebuild_vk.stamp
: > $LOG
touch $STAMP
say() { echo "$(date +%H:%M:%S) $@" | tee -a $LOG; }
say "SDK: $(head -1 $DEVKITPRO/ounce-sdk-version.txt)"

# 1. frontend (dummy core), from zero objects
cd $V
find . -name '*.o' -delete; find . -name '*.d' -delete
rm -f retroarch_switch.elf retroarch_switch.nro libretro_libnx.a
if make -f Makefile.libounce HAVE_STATIC_DUMMY=1 -j10 > out/vk/build_frontend.log 2>&1 && [ -f retroarch_switch.nro ]; then
  cp retroarch_switch.nro out/vk/retroarch_switch.nro; say "FRONTEND OK $(stat -f %z retroarch_switch.nro)"
else say "FRONTEND FAIL"; exit 1; fi

clean_make() { # dir makefile
  (cd "$1" && make -f "$2" platform=libounce clean >/dev/null 2>&1)
  find "$1" -name '*_libretro_libnx.a' -delete 2>/dev/null
}

# 2. makefile cores (build_core.py copies to cores/out/<name>.a)
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
  clean_make $R/cores/$2 $3
  if python3 $R/cores/build_core.py $1 $4 >> $LOG 2>&1; then say "OK $1"; else say "FAIL $1"; fi
done
for spec in "picodrive picodrive" "fceumm libretro-fceumm"; do
  set -- ${=spec}
  clean_make $R/$2 Makefile.libretro
  if (cd $R/$2 && make -f Makefile.libretro platform=libounce -j10 > $R/scratch/${1}_vk.log 2>&1) && [ -f $R/$2/${1}_libretro_libnx.a ]; then
    cp $R/$2/${1}_libretro_libnx.a $O/$1.a; say "OK $1"
  else say "FAIL $1"; fi
done
P=$R/cores/libretro-pcsx_rearmed
clean_make $P Makefile.libretro
if (cd $P && make -f Makefile.libretro platform=libounce -j10 > $R/scratch/pcsx_rearmed_vk.log 2>&1) && [ -f $P/pcsx_rearmed_libretro_libnx.a ]; then
  cp $P/pcsx_rearmed_libretro_libnx.a $O/pcsx_rearmed.a; say "OK pcsx_rearmed"
else say "FAIL pcsx_rearmed"; fi

# 3. mgba: the SDK toolchain's flags kept (no CMAKE_C_FLAGS override), -O3
B=$R/cores/libretro-mgba/build-sw2sdk
rm -rf $B
if $CMAKE -S $R/cores/libretro-mgba -B $B \
    -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/libounce/cmake/Switch2.cmake \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG" -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG" \
    -DBUILD_LIBRETRO=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF -DBUILD_LTO=ON \
    -DBUILD_SDL=OFF -DBUILD_QT=OFF -DBUILD_TEST=OFF -DBUILD_SUITE=OFF -DBUILD_EXAMPLE=OFF \
    -DBUILD_CINEMA=OFF -DBUILD_HEADLESS=OFF -DBUILD_PERF=OFF -DBUILD_PYTHON=OFF -DBUILD_DOCGEN=OFF \
    -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF -DUSE_EPOXY=OFF \
    -DDISABLE_DEPS=ON -DUSE_DEBUGGERS=OFF -DUSE_GDB_STUB=OFF -DENABLE_SCRIPTING=OFF \
    -DUSE_FFMPEG=OFF -DUSE_ZLIB=OFF -DUSE_PNG=OFF -DUSE_LIBZIP=OFF -DUSE_MINIZIP=OFF -DUSE_LZMA=OFF \
    -DUSE_SQLITE3=OFF -DUSE_ELF=OFF -DUSE_EDITLINE=OFF -DUSE_JSON_C=OFF -DUSE_DISCORD_RPC=OFF \
    -DM_CORE_GB=ON -DM_CORE_GBA=ON > $R/scratch/mgba_vk.log 2>&1 \
  && (cd $B && make mgba_libretro -j10 >> $R/scratch/mgba_vk.log 2>&1) && [ -f $B/mgba_libretro.a ]; then
  cp $B/mgba_libretro.a $O/mgba.a; say "OK mgba"
else say "FAIL mgba"; fi

# 4. NROs in ra-vk: each core freshly built in this run, plus flycast's archive
cd $V
for name in snes9x snes9x2010 nestopia quicknes mesen gearboy sameboy vba_next genesis_plus_gx \
  gearsystem mednafen_pce_fast mednafen_supergrafx handy prosystem gambatte stella mgba picodrive \
  fceumm pcsx_rearmed flycast; do
  lib=$O/$name.a
  if [ $name = flycast ]; then lib=$O/flycast_jit.a
  elif [ ! -f $lib ] || [ $lib -ot $STAMP ]; then say "NRO SKIP $name (no fresh .a)"; continue; fi
  cp $lib libretro_libnx.a
  rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
  if make -f Makefile.libounce -j10 > out/vk/build_$name.log 2>&1 && [ -f retroarch_switch.nro ]; then
    cp retroarch_switch.nro out/vk/${name}_libretro_libnx.nro; say "NRO OK $name $(stat -f %z retroarch_switch.nro)"
  else say "NRO FAIL $name"; fi
done
say "ALL DONE"
