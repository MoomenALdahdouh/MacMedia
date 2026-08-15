# Third-party licenses

MacMedia bundles multimedia libraries. Those components remain under their own licenses. MacMedia itself is GPL-3.0-or-later because this distribution includes GPL-configured FFmpeg (x264/x265) and libmpv.

Do not remove these notices.

## libmpv / mpv

- Project: https://mpv.io
- Source: https://github.com/mpv-player/mpv
- License: GPL-2.0-or-later AND LGPL-2.1-or-later
- This build disables lua, javascript, vapoursynth, and the mpv CLI. `load-scripts` and `ytdl` are disabled at runtime.

## FFmpeg (libavcodec, libavformat, libavutil, libavfilter, libswscale, libswresample)

- Project: https://ffmpeg.org
- License: GPL-3.0-or-later for this Homebrew configuration (`--enable-gpl`, libx264, libx265)

## libass

- Project: https://github.com/libass/libass
- License: ISC

## libplacebo

- Project: https://code.videolan.org/videolan/libplacebo
- License: LGPL-2.1-or-later

## Additional runtime dylibs

Depending on the vendored closure, the app may also include libraries such as:

- x264 (GPL-2.0)
- x265 (GPL-2.0)
- dav1d (BSD-2-Clause)
- libvpx (BSD-3-Clause)
- opus (BSD-3-Clause)
- lame / libmp3lame (LGPL)
- harfbuzz (MIT)
- freetype (FTL / GPL)
- libarchive (BSD-2-Clause)
- uchardet (MPL-1.1 / GPL / LGPL)
- zimg (WTFPL)
- little-cms2 (MIT)
- jpeg-turbo (IJG / BSD / zlib)
- vulkan-loader / shaderc (Apache-2.0)

Exact files shipped in a given build are those copied into `MacMedia.app/Contents/Frameworks`. License texts collected at vendor time live in `Resources/Licenses/` when present.

MacMedia does not claim ownership of third-party code.
