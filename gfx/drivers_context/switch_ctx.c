/*  RetroArch - A frontend for libretro.
 *  Copyright (C) 2010-2014 - Hans-Kristian Arntzen
 *  Copyright (C) 2018      - M4xw
 *
 *  RetroArch is free software: you can redistribute it and/or modify it under the terms
 *  of the GNU General Public License as published by the Free Software Found-
 *  ation, either version 3 of the License, or (at your option) any later version.
 *
 *  RetroArch is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 *  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
 *  PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with RetroArch.
 *  If not, see <http://www.gnu.org/licenses/>.
 */

#include <features/features_cpu.h>
#include <stdlib.h>

#include <string/stdstring.h>

#ifdef HAVE_CONFIG_H
#include "../../config.h"
#endif

#include <switch.h>

#include "../common/switch_defines.h"
#include "../../frontend/frontend_driver.h"

/* TODO/FIXME - global referenced */
extern bool platform_switch_has_focus;

extern void sw2_trace(const char *m);

void switch_ctx_destroy(void *data)
{
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    sw2_trace("ctx_destroy");

    if (ctx_nx)
    {
#ifdef HAVE_EGL
        egl_destroy(&ctx_nx->egl);
        sw2_trace("egl_destroyed");
#endif
        free(ctx_nx);
    }
}

static void switch_ctx_get_video_size(void *data,
      unsigned *dims)
{
   switch (appletGetOperationMode())
   {
      default:
      case AppletOperationMode_Handheld:
         *dims = VIDEO_SCALE_PACK(1280, 720);
         break;
      case AppletOperationMode_Console:
         *dims = VIDEO_SCALE_PACK(1920, 1080);
         break;
   }
}

extern void sw2_trace(const char *m);
static void *switch_ctx_init(void *video_driver)
{
#ifdef HAVE_EGL
    EGLint n;
    EGLint major, minor;
    static const EGLint attribs[] = {
        EGL_BLUE_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_RED_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
#if defined(HAVE_OPENGLES3)
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
#elif defined(HAVE_OPENGLES)
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
#endif
        EGL_NONE};
#endif

    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)calloc(1, sizeof(*ctx_nx));

    if (!ctx_nx)
        return NULL;

    /* Comment below to enable error checking */
    setenv("MESA_NO_ERROR", "1", 1);

#if 0
    /* Uncomment below to enable Mesa logging: */
    setenv("EGL_LOG_LEVEL", "debug", 1);
    setenv("MESA_VERBOSE", "all", 1);
    setenv("NOUVEAU_MESA_DEBUG", "1", 1);

    /* Uncomment below to enable shader debugging in Nouveau: */
    setenv("NV50_PROG_OPTIMIZE", "0", 1);
    setenv("NV50_PROG_DEBUG", "1", 1);
    setenv("NV50_PROG_CHIPSET", "0x120", 1);
#endif

    sw2_trace("ctx_init");
    /* Needs to be here */
    ctx_nx->win = nwindowGetDefault();
    nwindowSetDimensions(ctx_nx->win, 1920, 1080);

    sw2_trace("pre-egl_init");
#ifdef HAVE_EGL
    if (!egl_init_context(&ctx_nx->egl, EGL_NONE, EGL_DEFAULT_DISPLAY,
                          &major, &minor, &n, attribs, NULL))
    {
        egl_report_error();
        goto error;
    }
#endif

    sw2_trace("egl_init ok");
    return ctx_nx;

error:
    switch_ctx_destroy(video_driver);
    return NULL;
}

static void switch_ctx_check_window(void *data, bool *quit,
      bool *resize, unsigned *dims)
{
    unsigned new_dims;
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    switch_ctx_get_video_size(data, &new_dims);

    if (new_dims != *dims)
    {
        *dims = new_dims;
        *resize = true;
        nwindowSetCrop(ctx_nx->win, 0, 1080 - VIDEO_SCALE_H(new_dims),
              VIDEO_SCALE_W(new_dims), 1080);
    }

    *quit = (bool)false;
}

static bool switch_ctx_set_video_mode(void *data,
      unsigned dims,
      bool fullscreen)
{
    /* Create an EGL rendering context */
    static const EGLint contextAttributeList[] =
        {
#ifdef HAVE_OPENGLES3
            EGL_CONTEXT_MAJOR_VERSION, 3,
#else
            EGL_CONTEXT_CLIENT_VERSION, 2,
#endif
            EGL_NONE};
#ifdef HAVE_OPENGLES3
    static const EGLint contextAttributeListES2[] =
        {
            EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL_NONE};
#endif

    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    unsigned win_dims         = 0;

    sw2_trace("set_video_mode");
    switch_ctx_get_video_size(data, &win_dims);

    ctx_nx->refresh_rate = 60;

    sw2_trace("pre-create_context");
#ifdef HAVE_EGL
    if (!egl_create_context(&ctx_nx->egl, contextAttributeList))
    {
        egl_report_error();
#ifdef HAVE_OPENGLES3
        /* no ES 3 context: fall back to ES 2 */
        sw2_trace("ctx: GLES3 context failed, trying GLES2");
        if (!egl_create_context(&ctx_nx->egl, contextAttributeListES2))
        {
            egl_report_error();
            goto error;
        }
#else
        goto error;
#endif
    }
#ifdef HAVE_OPENGLES3
    else
        sw2_trace("ctx: GLES3 context created");
#endif
#endif

    sw2_trace("pre-create_surface");
#ifdef HAVE_EGL
    if (!egl_create_surface(&ctx_nx->egl, ctx_nx->win))
        goto error;
#endif

    sw2_trace("surface ok");
    nwindowSetCrop(ctx_nx->win, 0, 1080 - VIDEO_SCALE_H(win_dims),
          VIDEO_SCALE_W(win_dims), 1080);

    return true;

error:
    switch_ctx_destroy(data);
    return false;
}

static void switch_ctx_input_driver(void *data,
      const char *name)
{
}

#ifdef HAVE_OPENGLES
static enum gfx_ctx_api switch_ctx_get_api(void *data) { return GFX_CTX_OPENGL_ES_API; }
#else
static enum gfx_ctx_api switch_ctx_get_api(void *data) { return GFX_CTX_OPENGL_API; }
#endif

static bool switch_ctx_bind_api(void *data,
      enum gfx_ctx_api api, unsigned major, unsigned minor)
{
    sw2_trace("bind_api");
    if (api == GFX_CTX_OPENGL_API)
        if (egl_bind_api(EGL_OPENGL_API))
            return true;
#ifdef HAVE_OPENGLES
    if (api == GFX_CTX_OPENGL_ES_API)
        if (egl_bind_api(EGL_OPENGL_ES_API))
            return true;
#endif
    return false;
}

static bool switch_ctx_has_focus(void *data) { return platform_switch_has_focus; }
static bool switch_ctx_suppress_screensaver(void *data, bool enable) { return false; }

static void switch_ctx_set_swap_interval(void *data, int swap_interval)
{
#ifdef HAVE_EGL
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    egl_set_swap_interval(&ctx_nx->egl, swap_interval);
#endif
}

#ifdef __SWITCH2__
/* Read by the Dreamcast core's timing report: time in eglSwapBuffers on the video thread */
unsigned long long sw2_swap_us;
unsigned sw2_swap_n;
#endif
static void switch_ctx_swap_buffers(void *data)
{
#ifdef HAVE_EGL
    static int n;
    if (n < 3) { n++; sw2_trace("swap_buffers"); }
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t*)data;
#ifdef __SWITCH2__
    {
       retro_time_t t0 = cpu_features_get_time_usec();
       egl_swap_buffers(&ctx_nx->egl);
       sw2_swap_us += (unsigned long long)(cpu_features_get_time_usec() - t0);
       sw2_swap_n++;
    }
#else
    egl_swap_buffers(&ctx_nx->egl);
#endif
#endif
}

static void switch_ctx_bind_hw_render(void *data, bool enable)
{
#ifdef HAVE_EGL
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    egl_bind_hw_render(&ctx_nx->egl, enable);
#endif
}

static uint32_t switch_ctx_get_flags(void *data)
{
   uint32_t flags = 0;

   if (string_is_equal(video_driver_get_ident(), "glcore"))
   {
#if defined(HAVE_SLANG) && (defined(HAVE_SPIRV_CROSS) || defined(HAVE_RSLC))
      BIT32_SET(flags, GFX_CTX_FLAGS_SHADERS_SLANG);
#endif
   }
   else
   {
#ifdef HAVE_GLSL
      BIT32_SET(flags, GFX_CTX_FLAGS_SHADERS_GLSL);
#endif
   }

   /* nvservices gives a process one GL context: a second one, shared
    * or not, is not usable. The threaded wrapper's ring hands this one
    * between the threads instead. */
   BIT32_SET(flags, GFX_CTX_FLAGS_NO_SHARED_CONTEXT);

    return flags;
}

static void switch_ctx_set_flags(void *data, uint32_t flags) { }

static void switch_ctx_release_current(void *data)
{
#ifdef HAVE_EGL
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    if (ctx_nx)
        egl_release_current(&ctx_nx->egl);
#endif
}

static float switch_ctx_get_refresh_rate(void *data)
{
    switch_ctx_data_t *ctx_nx = (switch_ctx_data_t *)data;
    return ctx_nx->refresh_rate;
}

bool switch_ctx_get_metrics(void *data,
   enum display_metric_types type, float *value)
{
   switch (type)
   {
      case DISPLAY_METRIC_DPI:
         /* FIXME: DPI values should be obtained by querying
          * the hardware - these hard-coded values are a kludge */
         switch (appletGetOperationMode())
         {
            case AppletOperationMode_Console:
               /* Docked mode
                * > Resolution:  1920x1080
                * > Screen Size: 39 inch
                *   - Have to make an assumption here. We select
                *     a 'default' screen size of 39 inches which
                *     corresponds to the optimal diagonal screen
                *     size for HD television as reported in:
                *       "HDTV displays: subjective effects of scanning
                *       standards and domestic picture sizes,"
                *       N. E. Tanton and M. A. Stone,
                *       BBC Research Department Report 1989/09,
                *       January 1989
                *     This agrees with the median recorded TV
                *     size in:
                *       "A Survey of UK Television Viewing Conditions,"
                *       Katy C. Noland and Louise H. Truong,
                *       BBC R&D White Paper WHP 287 January 2015
                * > DPI:         sqrt((1920 * 1920) + (1080 * 1080)) / 39
                */
               *value = 56.48480f;
               break;
            case AppletOperationMode_Handheld:
            default:
               /* Handheld mode
                * > Resolution:  1280x720
                * > Screen size: 6.2 inch
                * > DPI:         sqrt((1280 * 1280) + (720 * 720)) / 6.2
                */
               *value = 236.8717f;
               break;
         }
         return true;
      default:
         break;
   }

   return false;
}

static bool switch_ctx_create_surface(void *data)
{
#ifdef HAVE_EGL
   switch_ctx_data_t *ctx_nx = (switch_ctx_data_t*)data;
   return egl_create_surface(&ctx_nx->egl, ctx_nx->win);
#else
   return false;
#endif
}

static bool switch_ctx_destroy_surface(void *data)
{
#ifdef HAVE_EGL
   switch_ctx_data_t *ctx_nx = (switch_ctx_data_t*)data;
   return egl_destroy_surface(&ctx_nx->egl);
#else
   return false;
#endif
}

const gfx_ctx_driver_t switch_ctx = {
    switch_ctx_init,
    switch_ctx_destroy,
    switch_ctx_get_api,
    switch_ctx_bind_api,
    switch_ctx_set_swap_interval,
    switch_ctx_set_video_mode,
    switch_ctx_get_video_size,
    switch_ctx_get_refresh_rate,
    NULL, /* get_video_output_size */
    NULL, /* get_video_output_prev */
    NULL, /* get_video_output_next */
    switch_ctx_get_metrics,
    NULL,
    NULL, /* update_title */
    switch_ctx_check_window,
    NULL, /* set_resize */
    switch_ctx_has_focus,
    switch_ctx_suppress_screensaver,
    false, /* has_windowed */
    switch_ctx_swap_buffers,
    switch_ctx_input_driver,
#ifdef HAVE_EGL
    egl_get_proc_address,
#else
    NULL,
#endif
    NULL,
    NULL,
    NULL,
    "egl_switch",
    switch_ctx_get_flags,
    switch_ctx_set_flags,
    switch_ctx_bind_hw_render,
    NULL,
    NULL,
    switch_ctx_create_surface,
    switch_ctx_destroy_surface,
    NULL, /* presentable */
    NULL, /* last_present_time */
    switch_ctx_release_current
};
