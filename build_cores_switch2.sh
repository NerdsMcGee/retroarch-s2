#!/bin/bash
# Usage: build_cores_switch2.sh <core>=<path to core .a> ...
# Builds one NRO per core (out/cores/<core>_libretro_libnx.nro) plus the
# frontend NRO with a dummy core (out/retroarch_switch.nro), in this checkout.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)" || exit 1
mkdir -p out/cores
for spec in "$@"; do
  name=${spec%%=*}; lib=${spec#*=}
  cp "$lib" libretro_libnx.a || exit 1
  rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
  ./build_switch2.sh > build_$name.log 2>&1 || { echo "build failed: $name"; exit 1; }
  cp retroarch_switch.nro out/cores/${name}_libretro_libnx.nro
  echo "built core $name"
done
rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
./build_switch2.sh HAVE_STATIC_DUMMY=1 > build_frontend.log 2>&1 || { echo "build failed: frontend"; exit 1; }
cp retroarch_switch.nro out/retroarch_switch.nro
rm -f cores/dynamic_dummy.o retroarch_switch.elf retroarch_switch.nro
echo "built frontend"
ls -la out out/cores
