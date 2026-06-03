#!/usr/bin/env python3
"""make_icon.py — Summon.icns. Matches Wolfgar's carved-metal aesthetic.

Design language (same as Wolfgar):
  - Near-black flat background
  - Rune = extrusion illusion: pale-gold FACE flat on top, dark-amber WALL
    visible as a sliver around the lower-right edge, thin bright RIDGE along
    the upper-left edge.  NOT a rounded tube — flat planes, sharp corners.
  - Sowilo rune (ᛋ) rotated 10° CW for a more upright, dynamic stance.

Usage: python3 make_icon.py [output_dir]
Output: {output_dir}/summon.icns
"""

import math, os, subprocess, sys, tempfile

try:
    from PIL import Image, ImageDraw
except ImportError:
    subprocess.run([sys.executable, "-m", "pip", "install", "Pillow",
                    "--quiet", "--break-system-packages"], capture_output=True)
    from PIL import Image, ImageDraw

SIZES  = [16, 32, 64, 128, 256, 512, 1024]
BG     = (12, 11, 16)
WALL   = (72, 46,  4)
FACE   = (210, 183, 112)
RIDGE  = (245, 232, 190)
CORNER = 0.22
ROTATION_DEG = 10   # CW tilt matching Louis's approved angle


# ── Geometry ──────────────────────────────────────────────────────────────────

def rotate_pt(x, y, cx, cy, rad):
    dx, dy = x - cx, y - cy
    return (dx*math.cos(rad) - dy*math.sin(rad) + cx,
            dx*math.sin(rad) + dy*math.cos(rad) + cy)


def unit_perp(p1, p2):
    dx, dy = p2[0]-p1[0], p2[1]-p1[1]
    mag = math.hypot(dx, dy)
    return dy/mag, -dx/mag


def draw_thick_stroke(draw, pts, hw, color, ox=0, oy=0):
    shifted = [(x+ox, y+oy) for x, y in pts]

    for i in range(len(shifted)-1):
        nx, ny = unit_perp(shifted[i], shifted[i+1])
        quad = [
            (shifted[i][0]+nx*hw,   shifted[i][1]+ny*hw),
            (shifted[i+1][0]+nx*hw, shifted[i+1][1]+ny*hw),
            (shifted[i+1][0]-nx*hw, shifted[i+1][1]-ny*hw),
            (shifted[i][0]-nx*hw,   shifted[i][1]-ny*hw),
        ]
        draw.polygon(quad, fill=(*color, 255))

    for i in range(1, len(shifted)-1):
        p = shifted[i]
        r = hw * 1.05
        draw.ellipse([p[0]-r, p[1]-r, p[0]+r, p[1]+r], fill=(*color, 255))

    for endpoint, seg_idx in [(shifted[0], 0), (shifted[-1], -2)]:
        seg = (shifted[seg_idx], shifted[seg_idx+1])
        dx = seg[1][0]-seg[0][0]; dy = seg[1][1]-seg[0][1]
        if seg_idx == 0:
            dx, dy = -dx, -dy
        mag = math.hypot(dx, dy)
        nx, ny = dy/mag, -dx/mag
        cap = [
            (endpoint[0]+nx*hw, endpoint[1]+ny*hw),
            (endpoint[0]+nx*hw+dx/mag*hw*0.45, endpoint[1]+ny*hw+dy/mag*hw*0.45),
            (endpoint[0]-nx*hw+dx/mag*hw*0.45, endpoint[1]-ny*hw+dy/mag*hw*0.45),
            (endpoint[0]-nx*hw, endpoint[1]-ny*hw),
        ]
        draw.polygon(cap, fill=(*color, 255))


def sowilo_pts(size):
    """Sowilo ᛋ waypoints, rotated 10° CW."""
    cx = size * 0.50
    rw = size * 0.22
    t  = size * 0.19
    b  = size * 0.81
    m1 = t + (b-t)*0.38
    m2 = t + (b-t)*0.62

    raw = [
        (cx+rw, t),
        (cx-rw, m1),
        (cx+rw, m2),
        (cx-rw, b),
    ]

    rad = math.radians(ROTATION_DEG)
    return [rotate_pt(x, y, cx, size*0.50, rad) for x, y in raw]


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    radius = int(size * CORNER)
    bg = Image.new("RGBA", (size, size), (*BG, 255))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size-1, size-1], radius=radius, fill=255)
    img.paste(bg, mask=mask)

    draw = ImageDraw.Draw(img)
    pts = sowilo_pts(size)
    hw  = size * 0.062
    bev = size * 0.030

    draw_thick_stroke(draw, pts, hw, WALL, ox=bev, oy=bev)
    draw_thick_stroke(draw, pts, hw, FACE)
    if size >= 48:
        draw_thick_stroke(draw, pts, max(1, hw*0.22), RIDGE,
                          ox=-bev*0.35, oy=-bev*0.35)
    return img


def build_iconset(out_dir):
    iconset = os.path.join(out_dir, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    for fname, sz in [
        ("icon_16x16.png",16),("icon_16x16@2x.png",32),
        ("icon_32x32.png",32),("icon_32x32@2x.png",64),
        ("icon_128x128.png",128),("icon_128x128@2x.png",256),
        ("icon_256x256.png",256),("icon_256x256@2x.png",512),
        ("icon_512x512.png",512),("icon_512x512@2x.png",1024),
    ]:
        draw_icon(sz).save(os.path.join(iconset, fname))
    return iconset


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "/tmp/summon_icon_build"
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        iconset = build_iconset(tmp)
        icns_out = os.path.join(out_dir, "summon.icns")
        r = subprocess.run(["iconutil","-c","icns",iconset,"-o",icns_out],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print(f"iconutil failed: {r.stderr}", file=sys.stderr); sys.exit(1)
    print(f"✅  {icns_out}")


if __name__ == "__main__":
    main()
