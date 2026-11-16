#!/bin/bash
# Builds retroarch_switch.nro in this checkout with Makefile.libounce;
# arguments go to make. Paths come from switch2/env.sh.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/switch2/env.sh" || exit 1
cd "$SW2_REPO" || exit 1
make -f Makefile.libounce -j8 "$@"
