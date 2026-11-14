# A plain CMake toolchain for libounce. The release builds mgba with the
# devkit's own $DEVKITPRO/libounce/cmake/Switch2.cmake instead; this one is
# kept for projects that need a bare toolchain. devkitPro is taken from
# $DEVKITPRO, or /opt/devkitpro when it is not set.
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
if(DEFINED ENV{DEVKITPRO})
  set(DKP $ENV{DEVKITPRO})
else()
  set(DKP /opt/devkitpro)
endif()
set(CMAKE_C_COMPILER ${DKP}/devkitA64/bin/aarch64-none-elf-gcc)
set(CMAKE_CXX_COMPILER ${DKP}/devkitA64/bin/aarch64-none-elf-g++)
set(CMAKE_AR ${DKP}/devkitA64/bin/aarch64-none-elf-gcc-ar CACHE FILEPATH "")
set(CMAKE_RANLIB ${DKP}/devkitA64/bin/aarch64-none-elf-gcc-ranlib CACHE FILEPATH "")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH ${DKP}/portlibs/switch2 ${DKP}/portlibs/switch ${DKP}/libounce)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(FLAGS "-mcpu=cortex-a78c+crypto -mtp=soft -fPIE -ffunction-sections -fdata-sections -ftls-model=local-exec -D__SWITCH__ -D__SWITCH2__ -DHAVE_LIBNX -I${DKP}/libounce/include -I${DKP}/portlibs/switch/include -specs=${DKP}/libounce/switch.specs")
set(CMAKE_C_FLAGS_INIT "${FLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${FLAGS}")
