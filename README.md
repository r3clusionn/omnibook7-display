# omnibook7-display

The best picture the HP OmniBook 7's OLED can show on Linux with X11 and an AMD GPU: 10 bits per channel from programs to the panel, accurate colours on its wide gamut done by the display hardware, mpv set up for quality, and the fixes for programs that break when X runs at 10 bits. It is two small C tools (`colormode` and `grab`), a few config files, and what was measured along the way. Most of it applies to any wide-gamut panel on an AMD GPU under Xorg.

**Status:** in daily use on an HP OmniBook 7 14-kh0xxx (Ryzen AI 9 HX 475, Radeon 890M, Samsung 2880x1800 120 Hz OLED) with Gentoo, Xorg 21.1, xf86-video-amdgpu 25.0, Mesa 26.1, mpv 0.41 and dwm. HDR for fullscreen video is in [x11-amdgpu-hdr](https://github.com/r3clusionn/x11-amdgpu-hdr) (a patch for the X driver; `colormode` here includes its HDR modes).

![Terminal output on a dark background, three commands. "colormode status" prints "eDP: srgb" and the panel's primaries from its EDID: "R 0.683,0.316  G 0.245,0.714  B 0.140,0.044  white 0.3135,0.3291". "doas cat /sys/kernel/debug/dri/1/eDP-1/output_bpc" prints "Maximum: 10". "mpv -v video.mkv 2>&1 | grep -E "Picked surface|Dithering to"" prints "[vo/gpu-next/libplacebo] Picked surface configuration 0: VK_FORMAT_A2R10G10B10_UNORM_PACK32 + VK_COLOR_SPACE_SRGB_NONLINEAR_KHR" and "[vo/gpu-next/libplacebo] Dithering to 10 bit depth"](docs/images/terminal.png)

## Features

- **10 bits per channel end to end.** The panel and its eDP link already run at 10 bits (HBR3 x4, no compression); X runs at depth 30 so programs draw in 10 bits too. Gradients and dark scenes don't band.
- **Accurate colours (`colormode`).** The panel's gamut is about DCI-P3 with a wider green, so ordinary sRGB content (the desktop, browsers, video) looks oversaturated on it. `colormode srgb` converts every pixel in the GPU's display engine, from the primaries in the panel's EDID: no GPU time, no power, no banding. `colormode native` gives the full gamut back.
- **Screenshots at depth 30 (`grab`).** shotgun only reads 8-bit screens and writes empty files at depth 30. `grab` reads any depth and writes a PNG; it takes 13 ms for a region.
- **mpv at its best.** `gpu-next` on Vulkan with a 10-bit swapchain, mpv's high-quality scaling, 10-bit dithering, and frames timed to the panel's 120 Hz.
- **Shader advice from a measured test.** ArtCNN with chroma-from-luma prediction reconstructs anime closest to the source and runs in real time on the Radeon 890M (see Measurements).
- **HDR for fullscreen video.** With the patched X driver from [x11-amdgpu-hdr](https://github.com/r3clusionn/x11-amdgpu-hdr), `colormode watch` puts the panel in HDR mode while an HDR video is fullscreen and on screen, and `colormode auto on|off` switches that on or off.
- **Fixes for depth 30.** Chromium-based browsers and CEF apps (tested: Thorium and a CEF program) play video as a white rectangle or paint nothing until they use ANGLE over EGL.

## How to install

Requires Xorg with the amdgpu driver (xf86-video-amdgpu: it exposes the colour pipeline that `colormode` uses), a C compiler, libX11, libXrandr and zlib. mpv with Vulkan for the mpv settings; hacksaw and xclip for the screenshot key.

```sh
git clone https://github.com/r3clusionn/omnibook7-display
cd omnibook7-display
doas sh install.sh            # colormode and grab into /usr/local/bin (or sudo)
```

Then, from `config/`:

- **Depth 30:** with xinit, the lines in `config/bash_profile` start X at depth 30 and fall back to depth 24 if that fails. With a display manager or startx, put `config/xorg-depth30.conf` in `/etc/X11/xorg.conf.d/` instead (no fallback there, and not tested on this laptop, which uses the xinit lines; keep a text console ready to remove it). Log out and back in.
- **Colours at login:** add the line in `config/xinitrc` to `~/.xinitrc` (or your session's autostart).
- **mpv:** copy `config/mpv.conf` to `~/.config/mpv/mpv.conf`. Its `dither-depth=10` assumes X at depth 30; at depth 24 set it back to `auto`.
- **Chromium, Thorium, Chrome and CEF apps:** start them with `--use-angle=gl-egl` (in their launcher or desktop file).
- **Screenshots:** bind `grab` instead of shotgun; `config/dwm-screenshot.h` is the dwm line.

## How to use

```sh
colormode status      # srgb or native, and the panel's primaries
colormode srgb        # accurate colours (what xinitrc runs at login)
colormode native      # the panel's full gamut (to compare)
colormode auto on|off # HDR for fullscreen HDR video (needs x11-amdgpu-hdr's driver patch)

grab shot.png                         # the whole screen
grab -g 800x400+100+100 - | xclip -selection clipboard -t image/png
```

For anime in mpv, the shaders from [ArtCNN](https://github.com/Artoriuz/ArtCNN) and [chroma-from-luma prediction](https://github.com/Artoriuz/glsl-chroma-from-luma-prediction):

```
glsl-shaders=~~/shaders/CfL_Prediction.glsl:~~/shaders/ArtCNN_C4F16.glsl
```

`ArtCNN_C4F16_DN.glsl` (denoise) suits compressed web releases, `ArtCNN_C4F16_DS.glsl` (denoise and sharpen) soft older sources. Anime4K's Mode A gives a bolder, smoother look if that is what you prefer.

## How it works

- **The panel** (from its EDID): Samsung SDC 0x4215, 10 bits per channel, gamma 2.2, primaries R 0.683/0.316, G 0.245/0.714, B 0.140/0.044, white D65; 500 nits full screen, 1100 nits peak, VRR 30–120 Hz. The kernel's debugfs reports a maximum of 10 bpc on the link.
- **`colormode`** sets three CRTC properties that the amdgpu X driver exposes through RandR: `DEGAMMA_LUT` (undo the sRGB curve), `CTM` (a 3x3 matrix from sRGB primaries to the panel's, built from the EDID with the white point kept at D65, so greys pass through unchanged) and `GAMMA_LUT` (the sRGB curve again). The display engine applies them after the framebuffer at more than 10 bits. The EDID is read from sysfs, matched through the output's `CONNECTOR_ID`, because the driver doesn't publish it in RandR.
- **sRGB curves, not a pure 2.2 power.** The kernel turns `GAMMA_LUT` (4096 points spaced evenly in linear light) into the hardware's curve by straight-line interpolation. A pure power curve is steepest at black, so the interpolation lost the darkest shades: 10-bit codes 1–4 came out black in a simulation of the round trip. sRGB's curve has a straight segment near black that survives the interpolation exactly; every grey comes back within 0.1 code.
- **The legacy gamma ramp.** At depth 24 the X driver composes `GAMMA_LUT` with X's 1024-entry gamma ramp, whose default stops short of full scale (65472), so every lookup lands one entry low and the darkest shade turns black. `colormode` sets a ramp rounded up to full scale. At depth 30 the ramp isn't used.
- **Depth 30** has no 24-bit visuals. Programs that ask for one fail: shotgun (8-bit only), and Chromium's GPU process over GLX, which can't bind its 8-bit video frames and page buffers (white video in Thorium; a black page in CEF apps). ANGLE over EGL imports them as dmabufs at any depth. GTK, st, dwm, mpv and Xft programs work unchanged.
- **mpv** picks a 10-bit Vulkan swapchain (`A2R10G10B10`) at depth 30, but its `dither-depth=auto` assumes 8 bits for Vulkan, hence the explicit 10. OpenGL output detects 10 bits on its own but is slower.
- **Embedding mpv in a program:** libmpv's render API only runs mpv's older `gpu` renderer, which can't load `gpu-next` shaders such as ArtCNN and chroma-from-luma, and runs Anime4K 20–35% slower (Anime4K A+A Fast: 18.1–20.0 ms against 14.9 ms). An embedded mpv with `vo=gpu-next` can draw into a child window redirected off-screen with X Composite, imported as an EGLImage and drawn under the program's own UI. On AMD, setting `AMD_PRIORITY=-512` after the UI's GL context exists runs mpv's later Vulkan context at low GPU priority, so the UI stays responsive under heavy shaders. mpv 0.41 fills `mpv_render_frame_info.target_time` in nanoseconds, not the microseconds its header says.

## Measurements

On the laptop plugged in, GPU at full clock.

**Quality of 2x upscalers.** Three 1080p frames of an anime episode (Frieren, a web release), halved to 960x540 with Lanczos, doubled back to 1920x1080 by each method in mpv `gpu-next`, and compared with the original (higher is closer):

| Method | PSNR | SSIM |
|---|---|---|
| ArtCNN C4F16 + chroma-from-luma | **37.08 dB** | **0.9700** |
| ArtCNN C4F16 DN + chroma-from-luma | 37.01 dB | 0.9631 |
| Anime4K C (HQ) | 36.92 dB | 0.9663 |
| Lanczos (mpv's default) | 36.70 dB | 0.9663 |
| `ewa_lanczossharp` + chroma-from-luma | 36.41 dB | 0.9652 |
| `ewa_lanczossharp` | 36.40 dB | 0.9647 |
| ArtCNN C4F16 DS + chroma-from-luma | 35.51 dB | 0.9615 |
| Anime4K A (HQ) | 33.15 dB | 0.9414 |
| Anime4K A (Fast) | 32.56 dB | 0.9396 |
| Anime4K A+A (Fast) | 29.99 dB | 0.9197 |

Side by side, ArtCNN keeps the painted texture of backgrounds and gives crisp lines; Anime4K A and A+A draw bolder lines but smooth the background art flat. The test favours faithful reconstruction, which is what ArtCNN is trained for.

**GPU time per frame**, 1080p to 2880x1800, mpv `gpu-next` on Vulkan (`vo-passes`), Radeon 890M; a 24 fps frame lasts 41.7 ms:

| Shaders | ms per frame |
|---|---|
| none, `profile=high-quality` | 2.3 |
| chroma-from-luma | +0.9 |
| ArtCNN C4F16 | 14.0 |
| Anime4K A+A (Fast) | 14.9 |
| Anime4K A (HQ) | 26.9 |
| ArtCNN C4F32 | 38.3 (too close to the limit; it dropped frames with a UI on top) |
| Anime4K A+A (HQ) | 41.9 (drops frames) |

**`colormode`'s LUTs**, simulated round trip of every 10-bit grey through the degamma and regamma LUTs as the kernel interpolates them: pure gamma 2.2 is up to 7.1 codes off and turns codes 1–4 black; the sRGB curve is at most 0.1 code off.

**Decoding:** VA-API on the 890M decodes 2880x1800 120 fps 10-bit HEVC and AV1 at about 500 fps.

## Verification

- **Depth 30**, in the real session: X reports 30-bit visuals and a 10-bit root window; mpv's swapchain is `A2R10G10B10` and it dithers to 10 bits (screenshot above); Thorium, st, dwm, mpv and GTK 3 programs render correctly; a Chromium-based browser plays AV1 video white without `--use-angle=gl-egl` and correctly with it, still decoding on the GPU (its GPU process loads Mesa's driver and libva); a CEF program paints nothing without it and normally with it.
- **`colormode`:** the CTM read back from the kernel has rows summing to 1.000 (greys unchanged) and only positive entries (sRGB lies inside the panel's gamut, nothing is clipped); at depth 30 all 4096 `GAMMA_LUT` entries match the sRGB curve within 1/65535; the setting survives the screen turning off and on.
- **`grab`:** an 800x400 region and the whole 2880x1800 screen at depth 30 come out as correct 8-bit RGB PNGs.
- The quality test and the GPU times in Measurements were run on the laptop with mpv 0.41 and libplacebo 7.360.

## Limits

- X11 with the amdgpu X driver only: the modesetting driver doesn't expose `CTM` and the LUTs through RandR, and Wayland compositors have their own colour management.
- The colours come from the panel's EDID, which is the factory's description, not a measurement of this panel. A colorimeter would do better.
- `colormode srgb` shows wide-gamut content (rare outside HDR) clipped to sRGB; HDR video gets the full gamut in HDR mode (x11-amdgpu-hdr).
- At depth 30, any program that needs a 24-bit visual fails until it is fixed or configured (as with Chromium above). X's legacy gamma ramp (xgamma, redshift-style tools) has no effect at depth 30.
- HDR is fullscreen only and needs a patched X driver: see [x11-amdgpu-hdr](https://github.com/r3clusionn/x11-amdgpu-hdr).

## License

MIT (see `LICENSE`). ArtCNN and chroma-from-luma prediction are by João Chrisóstomo under MIT; Anime4K is by bloc97 under MIT.
