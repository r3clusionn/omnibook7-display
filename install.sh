#!/bin/sh
# Compiles colormode and grab into /usr/local/bin and the colormode-hdr mpv
# plugin into /usr/local/lib (needs root).
# Run: doas sh install.sh   (or sudo)
set -eu
[ "$(id -u)" = 0 ] || { echo "run with: doas sh $0" >&2; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"
cc -O2 -o /usr/local/bin/colormode bin/colormode.c -lX11 -lXrandr -lm
mkdir -p /usr/local/lib
cc -O2 -shared -fPIC -o /usr/local/lib/colormode-hdr.so bin/colormode-hdr.c -lX11
cc -O2 -o /usr/local/bin/grab bin/grab.c -lX11 -lz
echo "installed /usr/local/bin/colormode, /usr/local/bin/grab and /usr/local/lib/colormode-hdr.so"
