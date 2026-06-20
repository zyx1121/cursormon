```
 ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗ ██████╗ ███╗   ██╗
██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗████╗ ████║██╔═══██╗████╗  ██║
██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝██╔████╔██║██║   ██║██╔██╗ ██║
██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗██║╚██╔╝██║██║   ██║██║╚██╗██║
╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
 ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
```

# Cursormon

A pixel desktop pet for macOS — animated Pokémon trail behind your cursor in a little conga line, the one nearest the cursor drawn on top.

## Tech Stack

- **Language**: Swift 6 — AppKit + Core Animation
- **Build**: SwiftPM + a Makefile bundle, ad-hoc codesign — no Xcode
- **Sprites**: PokeAPI Gen5 BW *animated* sprites, fetched at build time (never bundled)
- **Platform**: macOS 14+

## Getting Started

```bash
make sprites   # fetch sprites from PokeAPI into Resources/ (needs `uv`)
make run       # build, bundle, codesign, launch
```

A 🐾 icon appears in the menu bar — click it to pick creatures, size, follow distance, and toggle launch-at-login. Quit from there too.

## How it works

- One transparent, click-through `NSPanel` per pet, floating over everything. **Zero permissions** — it only reads `NSEvent.mouseLocation`, no Accessibility / TCC prompt.
- Each pet eases toward a point *behind* its leader: `pet[0]` trails the cursor, `pet[i]` trails `pet[i-1]` — so several pets form a conga line / wake. The one nearest the cursor is stacked on top.
- Sprites decode to RGBA `CGImage` and play frame-by-frame; they walk-cycle while moving, breathe slowly while idle, and flip to face their heading.

## Adding creatures

Add the National Dex number to `DEX` in `scripts/build_sprites.py` **and** to `SPECIES` in `Sources/Cursormon/main.swift`, then re-run `make sprites && make run`.

## License

[MIT](LICENSE) — **code only**. Pokémon and all sprites/names are trademarks and © Nintendo / Game Freak / The Pokémon Company; this project fetches them at build time and never redistributes them. Non-commercial fan project, not affiliated. Gotta trail 'em all.
