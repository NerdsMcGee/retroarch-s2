# RetroArch for Nintendo Switch 2 (libounce)

A port of RetroArch to the Switch 2. It uses libounce, a libnx-compatible library from ounce-devkit, in place of libnx. Releases are drop-in zips for the SD card: see the GitHub releases.

## Devkit

Build with **ounce-devkit 20261115b** or later:
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
./build_switch2.sh             # the frontend NRO only (arguments go to make)
```

The NROs and build logs go to `out/release` in this checkout.

The scripts take their paths from `switch2/env.sh`. Set any of these in the environment to override the default:

| Variable | Default | What it is |
|---|---|---|
| `SW2_REPO` | this checkout, found with git | the RetroArch tree that is built |
| `SW2_WORK` | the folder the checkout is in | the folder holding the core checkouts |
| `SW2_CORES` | `$SW2_WORK/cores` | the core checkouts |
| `SW2_OUT` | `$SW2_CORES/out` | the static core archives |
| `DEVKITPRO` | `/opt/devkitpro` | devkitPro with ounce-devkit installed |
| `CMAKE` | `cmake` | CMake 3.13 or later, for mgba |

`SW2_WORK` is expected to hold:
- `cores/` with the makefile cores, `libretro-pcsx_rearmed`, `libretro-mgba`, `libretro-flycast-jit` and `libretro-mupen64plus_next`;
- `picodrive/` and `libretro-fceumm/`;
- `libretro-super/`, whose recipes `switch2/build_core.py` uses to clone a core.

Each checkout gets its patch from `switch2/patches/` first (see Cores below).

`Makefile.libounce` is `Makefile.libnx` with the libounce rules. It builds OpenGL ES 3 (`HAVE_OPENGLES3`) and Vulkan (`HAVE_VULKAN`, with `HAVE_SLANG` and `HAVE_RSLC`). Vulkan is the default driver. Desktop GL goes through Zink and hard-crashes the console.

## Layout on the SD card

The release layout:

- `/switch/retroarch/retroarch_switch.nro`: the frontend (dummy core), the only entry in hbmenu.
- `/retroarch/cores/<core>_libretro_libnx.nro`: RetroArch with one static core, chain-loaded by the frontend. `cores/savefiles`, `cores/savestates` and `cores/system` are next to them.
- `/retroarch/assets`, `/retroarch/info`, `/retroarch/database/rdb`: the usual RetroArch support files; `retroarch.cfg`, `config`, `playlists` and the other RetroArch folders are created in `/retroarch`.
- `RARCH_LOG` goes to `/retroarch-log.txt` with `log_to_file = "true"`. The release has no debug tracing.

RetroArch can also run from a single folder anywhere on the card, for example `/switch/apps/retroarch`: put `retroarch_switch.nro` and the contents of `/retroarch` (`cores`, `assets`, `info`, `database`, ...) together in that folder. Everything is then created there, and the log is `retroarch-log.txt` in that folder.

Each NRO finds its root folder from its own path (`argv[0]`): a core uses the parent of its `cores` folder; the frontend uses its own folder when that contains `cores`, and `/retroarch` otherwise (also when it has no path). Paths saved in `retroarch.cfg` and the playlists use RetroArch's `:/` notation for the root, so an install can be moved. Paths under `/retroarch` in an older config or playlist are read as paths under the root.

## Switch 2 changes in the frontend

- **Install folder:** `frontend/drivers/platform_switch.c` derives the root folder from `argv[0]` (the release layout's `/retroarch`, or a single-folder install's own folder) and falls back to `/retroarch` without one. `fill_pathname_application_path` returns `<root>/retroarch_switch.nro` on Switch 2, and the `:` path helpers (`libretro-common/file/file_path.c`, `config_file.c`, `playlist.c`) are enabled there.

- **Vulkan:** the `vk_switch` context (`gfx/drivers_context/switch_vk_ctx.c`) on the default `NWindow` through `VK_NN_vi_surface`.
  - OunceVK allows one vi surface per process, so the surface and its swapchain are kept across a video driver restart (`gfx/common/vulkan_common.c`). After a core has used Vulkan, RetroArch stays on Vulkan until it restarts, even when the config asks for `gl` (`gfx/video_driver.c`), because GL can't get a surface in that process any more.
- **Output size:** 1920x1080 docked and in handheld mode. The window is the same size in both modes (`nwindowSetModeDimensions`). The display reports no DPI, so the menu scales from the 1080p size.
- **Dock and undock:** the default window's VI2 layer is attached to one display. When the operation mode changes, both contexts move the layer to the new display: detach, clear the selection, attach, select (`switch_ctx_reattach_layer` in `switch_ctx.c`). Without this the TV or the handheld screen stays black.
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
| PCSX ReARMed | Dynarec with a compile thread. Stores through `sp` are checked for code written over (Gran Turismo runs its loader from the stack), and so are stores in a branch delay slot. With the HLE BIOS, `ReturnFromException` stops the dynarec while an exception handler runs nested, so the handler's loop sees it ended. Without this, Gran Turismo froze loading a race when there was no BIOS file. |
| PicoDrive | SH2 (32X) dynarec on the JIT, with far calls through x16. |
| Flycast | SH4, ARM7 and DSP code in one JIT. Self-modifying code is tracked in software, because Horizon gives no write faults. Vulkan renderer. |
| Mupen64Plus-Next | N64 dynarec and ParaLLEl-RSP's Lightning JIT on the JIT. ParaLLEl-RDP on Vulkan by default, with synchronous RDP off. volk's function pointers are renamed (`volk_sw2_rename.h`). GLideN64 needs `video_driver = "gl"` for this core, in `/retroarch/config/Mupen64Plus-Next/Mupen64Plus-Next.cfg`. The RDP command ring's worker spins for 250 µs before it sleeps, so the RSP doesn't pay a wake-up per command. ParaLLEl-RSP's vector loads and stores have halfword and NEON fast paths, and its operand shuffle and multiply-accumulates use native NEON on AArch64. The SP and DP interrupts come after an RSP task's length (ParaLLEl-RSP counts its cycles) instead of a fixed 1000 counts, so games pace themselves like real hardware; a yield request brings a pending task's interrupt forward. |

## Cores

The release builds 24 cores. Each one is its own NRO, `/retroarch/cores/<name>_libretro_libnx.nro`.

`switch2/patches/` holds one patch per core (`git apply` inside the core checkout). Each adds a `libounce` platform, and adds Switch 2 code where needed. Flycast's patch is for libretro/flycast at 6db95c1, FinalBurn Neo's for libretro/FBNeo at 12ec3ca.

- `switch2/build_core.py <name>` builds a core's static archive.
- mgba is CMake-only: build it with the devkit's `Switch2.cmake`.
- `switch2/rebuild_release.sh` builds all 24 and the frontend.
- bsnes builds with its own nall makefile: `make -f GNUmakefile target=libretro binary=library local=false platform=libounce` in `bsnes/`. Without `local=false` it adds `-march=native`.

### Built cores and hardware testing

**Played** means a game was played on a Switch 2. **Boots** means a game started but wasn't played. **Not tested** means the core is built but hasn't been run yet.

- **NES**
  - FCEUmm (`fceumm`): played. Super Mario Bros. 3
  - Mesen (`mesen`): played. Super Mario Bros. 3
  - Nestopia (`nestopia`): not tested
  - QuickNES (`quicknes`): not tested
- **SNES**
  - Snes9x 2010 (`snes9x2010`): played. Star Fox, Yoshi's Island, Super Mario RPG
  - bsnes (`bsnes`, with MSU-1): played. An MSU-1 game with its soundtrack
  - Snes9x (`snes9x`): not tested
- **Game Boy / Game Boy Color**
  - Gambatte (`gambatte`): not tested
  - Gearboy (`gearboy`): not tested
  - SameBoy (`sameboy`): not tested
- **Game Boy Advance**
  - mGBA (`mgba`, also GB/GBC): played. The Legend of Zelda: The Minish Cap, from a fresh install
  - VBA Next (`vba_next`): boots. The Minish Cap
- **Mega Drive / Genesis, 32X, Master System, Game Gear**
  - Genesis Plus GX (`genesis_plus_gx`): played. Vectorman, OutRun, Golden Axe, Dragon Crystal
  - PicoDrive (`picodrive`, with the SH2 dynarec for 32X): played. Vectorman; Metal Head on 32X at full speed
  - Gearsystem (`gearsystem`, Master System / Game Gear / SG-1000): not tested
- **PC Engine / TurboGrafx-16**
  - Beetle PCE Fast (`mednafen_pce_fast`): played. Knight Rider Special
  - Beetle SuperGrafx (`mednafen_supergrafx`): boots. Knight Rider Special
- **Atari**
  - Stella (`stella`, 2600): not tested
  - ProSystem (`prosystem`, 7800): not tested
  - Handy (`handy`, Lynx): not tested
- **PlayStation**
  - PCSX ReARMed (`pcsx_rearmed`, dynarec): played. Gran Turismo with races; Metal Gear Solid
- **Nintendo 64**
  - Mupen64Plus-Next (`mupen64plus_next`, ParaLLEl-RDP on Vulkan): played. Paper Mario, Ocarina of Time, Mario Party, Animal Forest, Conker's Bad Fur Day
- **Dreamcast**
  - Flycast (`flycast`, JIT, Vulkan renderer): played. Sonic Adventure, Phantasy Star Online Ver. 2
- **Arcade**
  - FinalBurn Neo (`fbneo`, Neo Geo, CPS1-3 and other boards): played. Metal Slug 3. ROM sets must match FBNeo's own DAT; Neo Geo games also need `neogeo.zip`, next to the ROMs or in `/retroarch/cores/system/fbneo/`.

So far 12 cores are played, 2 boot, and 10 are not tested.

MSU-1 with bsnes: keep the ROM and its MSU-1 files loose in one folder, with the ROM's base name: `Game.sfc`, `Game.msu`, `Game-1.pcm`, `Game-2.pcm` and so on. A zipped ROM does not work, because RetroArch unpacks it to a temporary folder where bsnes cannot find the MSU-1 files.

Fixed during testing:
- PCSX ReARMed: Gran Turismo froze while loading a race. Code it ran from the stack went stale.
- PCSX ReARMed: without a BIOS file, Gran Turismo froze or went black loading a race, every time with the compile thread off and sometimes with it on. Fixed in v0.4.1.
- Frontend: after docking or undocking, the new screen stayed black. Handheld mode ran at 720p with an oversized menu. Returning from a Vulkan core to a GL menu froze. Fixed in v0.4.1.
- PicoDrive: 32X games crashed. The SH2 dynarec now runs on the JIT.
- Mupen64Plus-Next: Paper Mario's textures were wrong.
- Mupen64Plus-Next: Conker's Bad Fur Day ran at about half speed in its heaviest scenes. Full speed since v0.3.1.
- All cores: the first game started after any download (on a fresh install, RetroArch's offer to download controller profiles) crashed before the core ran. Fixed in v0.2.1.
