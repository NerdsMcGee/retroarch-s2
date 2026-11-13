# RetroArch for Nintendo Switch 2 (libounce)

Port of RetroArch to the Switch 2 using libounce (libnx-compatible) instead of libnx.

## Build

```
./build_switch2.sh HAVE_STATIC_DUMMY=1     # frontend with a dummy core
./build_cores_switch2.sh name=/path/core.a ...   # one NRO per core + frontend, output in out/
```

`Makefile.libounce` is `Makefile.libnx` with the libounce rules and specs, `-D__SWITCH2__`,
and OpenGL ES 2 (`HAVE_OPENGLES2`). Desktop GL goes through Zink and hard-crashes the console.

## Layout on the SD card

- `/switch/retroarch/retroarch_switch.nro`: the frontend (dummy core), the only entry in hbmenu.
- `/retroarch/cores/<core>_libretro_libnx.nro`: RetroArch with one static core, chain-loaded by the frontend.
- `/retroarch/info/`: the usual core info files.

## Switch 2 changes

- GLES2 context in `gfx/drivers_context/switch_ctx.c`.
- GL function pointers in `nx_glsym.h` are renamed (`rsw2_` prefix) so they do not collide with libounce's real GL symbols.
- CPU and GPU profile menu entries are hidden and no CPU clocks are written (`__SWITCH2__`).
- `sw2_trace()` breadcrumbs write `/retroarch-trace.txt`. `RARCH_LOG` goes to `/retroarch-log.txt`
  (set `log_to_file = "true"` in `/retroarch/retroarch.cfg`).

## Cores

`switch2/patches/` holds one patch per core adding a `libounce` platform to its Makefile
(`git apply` inside the core checkout). `switch2/build_core.py <name>` clones a core from the
libretro-super libnx recipe, patches it and builds the static archive. mgba is CMake-only: use
`switch2/libounce.cmake` as the toolchain file with `-DBUILD_LIBRETRO=ON -DLIBRETRO_STATIC=ON`.

Tested on hardware: picodrive, fceumm, mgba.

### N64 (Mupen64Plus-Next): in testing

Tested on hardware with Paper Mario. On Switch 2 the core defaults to ParaLLEl-RDP on Vulkan
with the ParaLLEl-RSP JIT, and synchronous RDP off (waiting on the GPU every frame drops audio).
GLideN64 is still in the core options; it needs `video_driver = "gl"` for this core, in
`/retroarch/config/Mupen64Plus-Next/Mupen64Plus-Next.cfg`.

- The N64 dynarec and ParaLLEl-RSP's Lightning JIT write code to the staging view of a libounce
  JIT and publish it to the executable view.
- volk's function pointers are renamed (`volk_sw2_rename.h`) so they do not collide with the
  Vulkan entry points libounce links into the frontend.
