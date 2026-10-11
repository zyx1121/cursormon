# Cursormon

Swift 6 macOS menu bar app (AppKit and Core Animation), built with SwiftPM and a Makefile, no Xcode project. Read [README.md](README.md) first.

## Rules

- Never ask for Accessibility or any other TCC permission. Read the cursor with `NSEvent.mouseLocation` only.
- Never bundle Pokémon sprites or names beyond the `SPECIES` list. Fetch sprites from PokeAPI at runtime and cache them.
- Keep each pet panel click-through, so it never blocks the user.
- Repository documents and code comments are English.

## Verify

```sh
make bundle
make run
```

The build runs on macOS, so it is an exception to the sandbox rule. Watch the pets follow the cursor, and open the menu bar to try each setting.

## Release

Push a `v*` tag. `release.yml` builds the app and attaches the zipped app to the GitHub release.
