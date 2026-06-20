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
- **Sprites**: PokeAPI Gen5 BW *animated* sprites, fetched at **runtime** on first use and cached under Application Support — never bundled
- **Platform**: macOS 14+

## Getting Started

```bash
make run   # build, bundle, codesign, launch
```

On first launch it downloads the sprites it needs from PokeAPI (needs network); they're cached locally after that, so it's offline from then on.

A 🐾 icon appears in the menu bar — click it to pick creatures, size, follow distance, and toggle launch-at-login. Quit from there too.

## How it works

- One transparent, click-through `NSPanel` per pet, floating over everything. **Zero permissions** — it only reads `NSEvent.mouseLocation`, no Accessibility / TCC prompt.
- Each pet eases toward a point *behind* its leader: `pet[0]` trails the cursor, `pet[i]` trails `pet[i-1]` — so several pets form a conga line / wake. The one nearest the cursor is stacked on top.
- Sprites are fetched from PokeAPI at runtime (animated GIF decoded via ImageIO, cropped to a tight bbox), cached as raw `.gif` under `~/Library/Application Support/Cursormon/` — never shipped inside the app. They play frame-by-frame, walk-cycle while moving, breathe slowly while idle, and flip to face their heading.

## Adding creatures

Add the National Dex number + a name to `SPECIES` in `Sources/Cursormon/main.swift`, then `make run`. The sprite is fetched from PokeAPI the next time that creature is shown.

## License

[MIT](LICENSE) — **code only**. Pokémon and all sprites/names are trademarks and © Nintendo / Game Freak / The Pokémon Company; this app fetches them at runtime and never redistributes them. Non-commercial fan project, not affiliated. Gotta trail 'em all.
