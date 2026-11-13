# RetroArch for Nintendo Switch 2 (libounce)

A port of RetroArch to the Switch 2. It uses libounce, a libnx-compatible library from ounce-devkit, in place of libnx. Releases are drop-in zips for the SD card: see the GitHub releases.

## Devkit

Build with **ounce-devkit 20261113f** or later:
- libounce, plus OunceVK (Vulkan, EGL and OpenGL ES on Zink);
- kaiHEN, the loader. In earlier SDKs it was called OunceHEN.

`$DEVKITPRO/ounce-devkit-version.txt` shows the installed version.

- Makefiles include `$(DEVKITPRO)/libounce/switch2_rules`, which defines `__SWITCH2__` and `$(SWITCH2_CPU)` (`-mcpu=cortex-a78c+crypto`). Use it with `-mtp=soft -fPIE`.
- CMake projects use `$DEVKITPRO/libounce/cmake/Switch2.cmake`.
- JIT code links `-lkaihen` and includes `<kaihen.h>`.

## Build

```
switch2/rebuild_release.sh     # every core and the frontend from zero objects, one NRO per core
switch2/link_release.sh        # the frontend and the NROs only, from existing core archives
```

`Makefile.libounce` is `Makefile.libnx` with the libounce rules. It builds OpenGL ES 3 (`HAVE_OPENGLES3`) and Vulkan (`HAVE_VULKAN`, with `HAVE_SLANG` and `HAVE_RSLC`). Vulkan is the default driver. Desktop GL goes through Zink and hard-crashes the console.

## Layout on the SD card

- `/switch/retroarch/retroarch_switch.nro`: the frontend (dummy core), the only entry in hbmenu.
- `/retroarch/cores/<core>_libretro_libnx.nro`: RetroArch with one static core, chain-loaded by the frontend.
- `/retroarch/assets`, `/retroarch/info`, `/retroarch/database/rdb`: the usual RetroArch support files.
- `RARCH_LOG` goes to `/retroarch-log.txt` with `log_to_file = "true"`. The release has no debug tracing.

## Switch 2 changes in the frontend

- **Vulkan:** the `vk_switch` context (`gfx/drivers_context/switch_vk_ctx.c`) on the default `NWindow` through `VK_NN_vi_surface`.
  - OunceVK allows one vi surface per process, so the surface and its swapchain are kept across a video driver restart (`gfx/common/vulkan_common.c`).
- **OpenGL ES 3:** the EGL context in `switch_ctx.c`, with GLES2 as a fallback.
  - GL function pointers in `nx_glsym.h` are renamed (`rsw2_` prefix) so they don't collide with libounce's GL symbols.
- **Threaded video:** a GL context hand-off between the core's thread and the video thread (`gfx/video_thread_wrapper.c`). The take-back is deferred until the core next uses GL, and the core holds the context around `retro_deinit`.
- **Timing:** the perf counter reads `CLOCK_MONOTONIC`, because `mrs cntvct_el0` faults. The system tick is 31.25 MHz.
- **Clocks:** CPU and GPU profile menu entries are hidden, and no CPU clocks are written.

## JIT cores

Generated code is written to a libounce `Jit`'s staging view and made runnable with `kaihenJitPublishRanges`, which copies it to the executable view.
- Publish whole 64-byte lines, and publish every change, single-word patches included.
- Only the publishing thread's instruction cache is invalidated. Another thread that runs the code must invalidate the range itself first.
- The executable view is far from the program's code, so calls from generated code to C go through a register when they're out of `B`/`BL` reach.

| Core | Notes |
|---|---|
| PCSX ReARMed | Dynarec with a compile thread. Stores through `sp` are checked for code written over (Gran Turismo runs its loader from the stack). |
| PicoDrive | SH2 (32X) dynarec on the JIT, with far calls through x16. |
| Flycast | SH4, ARM7 and DSP code in one JIT. Self-modifying code is tracked in software, because Horizon gives no write faults. Vulkan renderer. |
| Mupen64Plus-Next | N64 dynarec and ParaLLEl-RSP's Lightning JIT on the JIT. ParaLLEl-RDP on Vulkan by default, with synchronous RDP off. volk's function pointers are renamed (`volk_sw2_rename.h`). GLideN64 needs `video_driver = "gl"` for this core, in `/retroarch/config/Mupen64Plus-Next/Mupen64Plus-Next.cfg`. |

## Cores

`switch2/patches/` holds one patch per core (`git apply` inside the core checkout). Each adds a `libounce` platform, and adds Switch 2 code where needed. Flycast's patch is for libretro/flycast at 6db95c1.

- `switch2/build_core.py <name>` builds a core's static archive.
- mgba is CMake-only: build it with the devkit's `Switch2.cmake`.

Tested on hardware:
- FCEUmm, Mesen, Snes9x 2010, Genesis Plus GX, PicoDrive (with 32X)
- PCSX ReARMed, Flycast, Mupen64Plus-Next, Beetle PCE Fast
- mGBA, VBA Next and Beetle SuperGrafx boot.
