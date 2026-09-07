#!/usr/bin/env python3

import sys
import math

W = 200
H = 200

cx = W / 2
cy = H / 2
r = 70

pixels = [[False] * W for _ in range(H)]

# Rasterize circle outline
for y in range(H):
    for x in range(W):
        d = math.sqrt((x - cx)**2 + (y - cy)**2)

        if abs(d - r) < 1.0:
            pixels[y][x] = True


# Start Sixel
sys.stdout.write("\x1bPq")

# Raster attributes: 1:1 pixel aspect, W × H
sys.stdout.write(f'"1;1;{W};{H}')

# Encode bands of six vertical pixels
for y0 in range(0, H, 6):

    for x in range(W):
        value = 0

        for bit in range(6):
            y = y0 + bit

            if y < H and pixels[y][x]:
                value |= 1 << bit

        sys.stdout.write(chr(63 + value))

    if y0 + 6 < H:
        sys.stdout.write("-")

# End DCS
sys.stdout.write("\x1b\\")
sys.stdout.flush()

