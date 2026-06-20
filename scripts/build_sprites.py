# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Fetch Gen5 BW *animated* sprites from PokeAPI into Resources/<dex>.json.

Each output is {w, h, frames:[[row...]...]} where every pixel is a packed
0xRRGGBB Int and -1 means transparent. Frames are cropped to a shared (union)
bbox so they don't jitter; native sprite size is kept (no rescaling).

Sprites are © Nintendo / Game Freak / The Pokémon Company. They are fetched at
build time and never committed (see .gitignore); PokeAPI's packaging is CC0.

Usage:  uv run scripts/build_sprites.py Resources
To add a creature: add its dex number to DEX below AND to SPECIES in the app
(Sources/Cursormon/main.swift), then re-run.
"""
import json, io, sys, urllib.request
from PIL import Image, ImageSequence

ANIM = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/{}.gif"
STAT = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/{}.png"
DEX = [1, 4, 7, 25, 39, 54, 79, 129, 132, 133, 143, 151, 778]

def fetch(url):
    return urllib.request.urlopen(url, timeout=30).read()

def frames_for(dex):
    try:
        im = Image.open(io.BytesIO(fetch(ANIM.format(dex))))
        fr = [f.convert("RGBA").copy() for f in ImageSequence.Iterator(im)]
        if len(fr) >= 2:
            return fr, "animated"
    except Exception:
        pass
    return [Image.open(io.BytesIO(fetch(STAT.format(dex)))).convert("RGBA")], "static"

def build(dex, outdir):
    frames, src = frames_for(dex)
    W, H = frames[0].size
    ux0, uy0, ux1, uy1 = W, H, 0, 0
    for f in frames:
        bb = f.getbbox()
        if bb:
            ux0, uy0 = min(ux0, bb[0]), min(uy0, bb[1])
            ux1, uy1 = max(ux1, bb[2]), max(uy1, bb[3])
    crop = [f.crop((ux0, uy0, ux1, uy1)) for f in frames]
    w, h = crop[0].size

    def pack(img):
        px = img.load()
        return [[(-1 if px[x, y][3] == 0 else (px[x, y][0] << 16) | (px[x, y][1] << 8) | px[x, y][2])
                 for x in range(w)] for y in range(h)]

    json.dump({"w": w, "h": h, "frames": [pack(c) for c in crop]},
              open(f"{outdir}/{dex}.json", "w"))
    print(f"#{dex}: {src}, {len(crop)} frames, {w}x{h}")

def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "Resources"
    for d in DEX:
        build(d, outdir)

if __name__ == "__main__":
    main()
