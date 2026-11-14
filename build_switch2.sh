#!/bin/zsh
# Builds retroarch_switch.nro in this checkout with Makefile.libounce;
# arguments go to make. Paths come from switch2/env.sh.
. "${0:A:h}/switch2/env.sh" || exit 1
cd "$SW2_REPO" || exit 1
make -f Makefile.libounce -j8 "$@"
