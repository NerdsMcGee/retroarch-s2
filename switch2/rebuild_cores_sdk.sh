#!/bin/zsh
# Rebuild the 20 non-flycast, non-N64 cores against the updated libounce SDK,
# with the SDK's practices: $(SWITCH2_CPU) from switch2_rules in the makefile
# cores, the SDK's Switch2.cmake toolchain for mgba. Each core is linked into
# its NRO in scratch/ra-a78c (no rsync from retroarch/: ra-a78c has the GLES3,
# N64 and deinit changes). Flycast is not touched.
R=/Volumes/switch/recomps
export DEVKITPRO=/opt/devkitpro DEVKITA64=/opt/devkitpro/devkitA64
export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH:/opt/local/bin
CMAKE=$R/tools/pycmake/cmake/data/bin/cmake
LOG=$R/scratch/rebuild_sdk.log
BAK=$R/scratch/bak-sdk
: > $LOG
STAMP=$R/scratch/rebuild_sdk.stamp
touch $STAMP
mkdir -p $BAK
say() { echo "$@" | tee -a $LOG; }

# 1. makefiles: the CPU flag from the SDK (same value, one source)
for f in \
  cores/libretro-snes9x/libretro/Makefile cores/libretro-snes9x2010/Makefile.libretro \
  cores/libretro-nestopia/libretro/Makefile cores/libretro-quicknes/Makefile \
  cores/libretro-mesen/Libretro/Makefile cores/libretro-gearboy/platforms/libretro/Makefile \
  cores/libretro-sameboy/libretro/Makefile cores/libretro-vba_next/Makefile.libretro \
  cores/libretro-genesis_plus_gx/Makefile.libretro cores/libretro-gearsystem/platforms/libretro/Makefile \
  cores/libretro-beetle_pce_fast/Makefile cores/libretro-beetle_supergrafx/Makefile \
  cores/libretro-handy/Makefile cores/libretro-prosystem/Makefile \
  cores/libretro-gambatte/Makefile.libretro cores/libretro-stella/src/os/libretro/Makefile \
  picodrive/Makefile.libretro libretro-fceumm/Makefile.libretro; do
  b=$BAK/${f//\//_}
  [ -f $b ] || cp $R/$f $b
  sed -i '' 's/-mcpu=cortex-a78c+crypto/$(SWITCH2_CPU)/g' $R/$f
  n=$(grep -c 'SWITCH2_CPU' $R/$f)
  say "flags $f: SWITCH2_CPU x$n"
done

clean_make() { # dir makefile
  (cd "$1" && make -f "$2" platform=libounce clean >/dev/null 2>&1)
  find "$1" -name '*_libretro_libnx.a' -delete 2>/dev/null
}

# 2. makefile cores
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
  if (cd $R/$2 && make -f Makefile.libretro platform=libounce -j8 > $R/scratch/$1_sdk.log 2>&1) && [ -f $R/$2/${1}_libretro_libnx.a ]; then say "OK $1"; else say "FAIL $1"; fi
done

# 3. mgba with the SDK's toolchain, in a fresh build directory, same options
B=$R/cores/libretro-mgba/build-sw2sdk
rm -rf $B
if $CMAKE -S $R/cores/libretro-mgba -B $B \
    -DCMAKE_TOOLCHAIN_FILE=$DEVKITPRO/libounce/cmake/Switch2.cmake \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-DHAVE_LIBNX" -DCMAKE_CXX_FLAGS="-DHAVE_LIBNX" \
    -DBUILD_LIBRETRO=ON -DBUILD_STATIC=ON -DBUILD_SHARED=OFF -DBUILD_LTO=ON \
    -DBUILD_SDL=OFF -DBUILD_QT=OFF -DBUILD_TEST=OFF -DBUILD_SUITE=OFF -DBUILD_EXAMPLE=OFF \
    -DBUILD_CINEMA=OFF -DBUILD_HEADLESS=OFF -DBUILD_PERF=OFF -DBUILD_PYTHON=OFF -DBUILD_DOCGEN=OFF \
    -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF -DUSE_EPOXY=OFF \
    -DDISABLE_DEPS=ON -DUSE_DEBUGGERS=OFF -DUSE_GDB_STUB=OFF -DENABLE_SCRIPTING=OFF \
    -DUSE_FFMPEG=OFF -DUSE_ZLIB=OFF -DUSE_PNG=OFF -DUSE_LIBZIP=OFF -DUSE_MINIZIP=OFF -DUSE_LZMA=OFF \
    -DUSE_SQLITE3=OFF -DUSE_ELF=OFF -DUSE_EDITLINE=OFF -DUSE_JSON_C=OFF -DUSE_DISCORD_RPC=OFF \
    -DM_CORE_GB=ON -DM_CORE_GBA=ON > $R/scratch/mgba_sdk.log 2>&1 \
  && (cd $B && make mgba_libretro -j8 >> $R/scratch/mgba_sdk.log 2>&1) && [ -f $B/mgba_libretro.a ]; then
  cp $B/mgba_libretro.a $R/cores/out/mgba.a; say "OK mgba"
else say "FAIL mgba"; fi

# 4. NROs in ra-a78c (only cores built above, each must be newer than this run)
O=$R/cores/out
W=$R/scratch/ra-a78c
cd $W
for spec in snes9x=$O/snes9x.a snes9x2010=$O/snes9x2010.a nestopia=$O/nestopia.a quicknes=$O/quicknes.a \
  mesen=$O/mesen.a gearboy=$O/gearboy.a sameboy=$O/sameboy.a vba_next=$O/vba_next.a \
  genesis_plus_gx=$O/genesis_plus_gx.a gearsystem=$O/gearsystem.a mednafen_pce_fast=$O/mednafen_pce_fast.a \
  mednafen_supergrafx=$O/mednafen_supergrafx.a handy=$O/handy.a prosystem=$O/prosystem.a gambatte=$O/gambatte.a \
  stella=$O/stella.a mgba=$O/mgba.a picodrive=$R/picodrive/picodrive_libretro_libnx.a \
  fceumm=$R/libretro-fceumm/fceumm_libretro_libnx.a; do
  name=${spec%%=*}; lib=${spec#*=}
  if [ ! -f $lib ] || [ $lib -ot $STAMP ]; then say "NRO SKIP $name (no fresh .a)"; continue; fi
  cp $lib libretro_libnx.a
  rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
  if make -f Makefile.libounce -j10 > out/gles3/build_$name.log 2>&1 && [ -f retroarch_switch.nro ]; then
    cp retroarch_switch.nro out/gles3/${name}_libretro_libnx.nro; say "NRO OK $name $(stat -f %z retroarch_switch.nro)"
  else say "NRO FAIL $name"; fi
done
say "ALL DONE"
