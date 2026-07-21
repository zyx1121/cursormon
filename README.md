# Cursormon

> Your cursor picks up a conga line of tiny Pokémon and never has to ask permission for it.

`swift` · `macos` · `menu-bar-app` · `pokemon` · `desktop-pet`

[![CI](https://github.com/zyx1121/cursormon/actions/workflows/ci.yml/badge.svg)](https://github.com/zyx1121/cursormon/actions) &nbsp;[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)

![Cursormon demo](cursormon.gif)

<sub>A pixel Pokémon trails the cursor across the desktop; with more than one active they form a conga line, closest to the cursor drawn on top.</sub>

Desktop pets usually mean a chunky always-on-top window or an app that quietly asks for Accessibility access. Cursormon skips both: pick a few favorites from the Pokédex from the menu bar, and they follow your cursor around the screen forever, built on nothing but a transparent click-through window and the cursor position the OS already hands out for free.

| | |
|---|---|
| Platform | macOS 14+ |
| Language | Swift 6, AppKit + Core Animation |
| Build | SwiftPM + a Makefile bundle, ad-hoc codesign, no Xcode |
| Sprites | PokeAPI Gen5 BW animated sprites, fetched at runtime |

## Getting started

```bash
git clone https://github.com/zyx1121/cursormon.git && cd cursormon
make run   # build, bundle, codesign, launch
```

First launch downloads the sprites it needs from PokeAPI (needs network); after that they're cached locally, so it runs offline. A 🐾 icon appears in the menu bar: click it to pick creatures, size, follow distance, and toggle launch-at-login, or quit.

## What it gives you

- **Follows** your cursor with one or more animated pixel Pokémon, each easing toward the one ahead of it, so several form a trailing conga line
- **Costs zero permissions**: reads only `NSEvent.mouseLocation` from a click-through `NSPanel`, no Accessibility / TCC prompt
- **Fetches sprites at runtime**: PokeAPI Gen5 BW animated GIFs, decoded and cropped on first use, cached under `~/Library/Application Support/Cursormon/`, never bundled
- **Plays it straight**: walk-cycle while moving, breathes slowly while idle, flips to face its heading
- **Runs at login**: menu bar toggle registers it via `SMAppService`, no hand-written LaunchAgent

## How it works

Each pet is its own transparent, click-through `NSPanel` floating over everything. `pet[0]` trails the cursor and `pet[i]` trails `pet[i-1]`, so several pets form a wake behind the pointer, with the one nearest the cursor stacked on top. Sprites come from PokeAPI at runtime (animated GIF decoded via ImageIO, cropped to a tight bounding box) and are cached as raw `.gif` files, so nothing Pokémon-related ships inside the app itself.

`make install` copies the built app to `/Applications`, which `SMAppService` needs for the launch-at-login toggle to stick across reboots.

## Adding creatures

Add the National Dex number and a name to `SPECIES` in `Sources/Cursormon/main.swift`, then `make run`. The sprite is fetched from PokeAPI the next time that creature is shown.

## Contributing

A personal project, but issues and PRs are welcome: ground rules in [CONTRIBUTING.md](https://github.com/zyx1121/.github/blob/main/CONTRIBUTING.md).

## License

[MIT](LICENSE) · code only, gotta trail 'em all

Pokémon and all sprites/names are trademarks and © Nintendo / Game Freak / The Pokémon Company. Cursormon fetches them at runtime and never redistributes them: a non-commercial fan project, not affiliated with any of the above.
