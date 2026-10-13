#!/bin/sh
# Compiles colormode and grab into /usr/local/bin (needs root).
# Run: doas sh install.sh   (or sudo)
set -eu
[ "$(id -u)" = 0 ] || { echo "run with: doas sh $0" >&2; exit 1; }
cd "$(dirname "$(readlink -f "$0")")"
cc -O2 -o /usr/local/bin/colormode bin/colormode.c -lX11 -lXrandr -lm
cc -O2 -o /usr/local/bin/grab bin/grab.c -lX11 -lz
echo "installed /usr/local/bin/colormode and /usr/local/bin/grab"
