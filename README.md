<div align="center">

<h1>Cursormon</h1>

<p><strong>A conga line of tiny pixel Pokémon that follows your cursor on macOS.</strong></p>

[![CI](https://img.shields.io/github/actions/workflow/status/zyx1121/cursormon/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/zyx1121/cursormon/actions)
[![Release](https://img.shields.io/github/v/release/zyx1121/cursormon?style=flat-square&sort=semver)](https://github.com/zyx1121/cursormon/releases)
[![macOS](https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple)](Package.swift)
[![License](https://img.shields.io/github/license/zyx1121/cursormon?style=flat-square)](LICENSE)

**English** | [繁體中文](README.zh-TW.md) | [简体中文](README.zh-CN.md)

</div>

Desktop pets often mean a large always-on-top window, or an app that asks for Accessibility access. Cursormon needs neither. Pick a few Pokémon from the menu bar, and they follow your cursor around the screen.

## Features

- **Follows your cursor**: each pet eases toward the one in front of it, so several pets form a trailing line.
- **Needs no permissions**: it reads only `NSEvent.mouseLocation` from a click-through panel, so macOS never asks for Accessibility access.
- **Fetches sprites at runtime**: animated Gen 5 sprites from PokeAPI, cached on first use and never bundled.
- **Moves naturally**: a walk cycle while moving, slow breathing while idle, and a flip to face the direction of travel.
- **Starts at login**: a menu bar switch registers it with `SMAppService`.

## Quick start

Download `Cursormon-v0.1.0-macos.zip` from the [latest release](https://github.com/zyx1121/cursormon/releases/latest), or build it:

```sh
git clone https://github.com/zyx1121/cursormon && cd cursormon
make run
```

A 🐾 icon appears in the menu bar. The first start downloads the sprites that it needs, so it needs the network once. After that, it runs offline.

## Usage

- Click 🐾 to pick creatures, the size and the follow distance, to turn start at login on or off, or to quit.
- Run `make install` to copy the app to `/Applications`. Start at login needs the app there to survive a reboot.
- To add a creature, add its National Dex number and name to `SPECIES` in `Sources/Cursormon/main.swift`, then run `make run`.

## How it works

Each pet is its own transparent, click-through `NSPanel` above every window. `pet[0]` follows the cursor and `pet[i]` follows `pet[i-1]`, with the pet nearest the cursor on top. ImageIO decodes each animated GIF from PokeAPI and crops it to a tight box. The app caches the raw `.gif` files in `~/Library/Application Support/Cursormon/`.

## Limits

- macOS 14 or later.
- The first view of each creature needs the network.

## For AI agents

Facts for coding agents and LLM tools. The rules for changing the code are in [AGENTS.md](AGENTS.md).

- **Summary**: Swift 6 macOS menu bar app that shows animated pixel Pokémon following the cursor, with sprites from PokeAPI at runtime.
- **Type**: app
- **Interfaces**: menu bar UI only. No CLI, MCP or HTTP.
- **Install**: download `Cursormon-v0.1.0-macos.zip` from https://github.com/zyx1121/cursormon/releases/latest
- **Run**: `make run`
- **Verify**: `make bundle` builds `Cursormon.app` without errors
- **Config**: none, the menu bar holds the settings
- **Secrets**: none
- **Limits**: macOS 14 or later. The app needs the network once per creature.

## Development

```sh
make bundle    # swift build, bundle and ad-hoc codesign, no Xcode project
make run
```

CI runs `make bundle` on every push.

## Disclaimer

Pokémon names and sprites are trademarks of Nintendo, Game Freak and The Pokémon Company. Cursormon fetches them at runtime and never redistributes them. It is a non-commercial fan project with no affiliation to any of them.

## License

[MIT](LICENSE), for the code only.
