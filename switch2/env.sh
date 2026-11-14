# Paths for the Switch 2 build scripts; each script sources this file.
# Any value set in the environment beforehand is kept.
#
#   SW2_REPO   this RetroArch checkout. Found with git from the script's
#              location; set it when the checkout is not a git repository.
#   SW2_WORK   the folder that holds the core checkouts. Defaults to the
#              folder SW2_REPO is in. Expected layout:
#                cores/<checkout>       makefile cores, libretro-pcsx_rearmed,
#                                       libretro-mgba, libretro-flycast-jit,
#                                       libretro-mupen64plus_next
#                cores/out/<core>.a     static core archives (SW2_OUT)
#                picodrive/, libretro-fceumm/
#                libretro-super/        recipes for switch2/build_core.py
#   SW2_CORES  default $SW2_WORK/cores
#   SW2_OUT    default $SW2_CORES/out
#   DEVKITPRO  devkitPro with ounce-devkit installed, default /opt/devkitpro
#   DEVKITA64  default $DEVKITPRO/devkitA64
#   CMAKE      CMake 3.13 or later, for mgba; default cmake from PATH

if [ -z "$SW2_REPO" ]; then
  SW2_REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null)
  if [ -z "$SW2_REPO" ]; then
    echo "switch2/env.sh: set SW2_REPO to the RetroArch checkout" >&2
    return 1 2>/dev/null || exit 1
  fi
fi
: "${SW2_WORK:=$(dirname "$SW2_REPO")}"
: "${SW2_CORES:=$SW2_WORK/cores}"
: "${SW2_OUT:=$SW2_CORES/out}"
: "${DEVKITPRO:=/opt/devkitpro}"
: "${DEVKITA64:=$DEVKITPRO/devkitA64}"
: "${CMAKE:=cmake}"
PATH=$DEVKITPRO/tools/bin:$DEVKITA64/bin:$PATH
export SW2_REPO SW2_WORK SW2_CORES SW2_OUT DEVKITPRO DEVKITA64 CMAKE PATH
