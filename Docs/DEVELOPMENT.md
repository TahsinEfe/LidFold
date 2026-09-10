# Development

## Requirements

- macOS 13 or newer, Apple silicon
- Xcode 15 or newer, or the Command Line Tools with a Swift 5.9 toolchain

No third-party dependencies.

## Commands

| Command | What it does |
| --- | --- |
| `./Scripts/build.sh [debug\|release]` | Builds the package and assembles `dist/LidFold.app`. |
| `./Scripts/run.sh` | Builds, stops any running instance and launches the app. |
| `./Scripts/check.sh` | Runs the unit tests, then the shader checks offscreen. |
| `./Scripts/probe.sh` | Reports whether this Mac has a readable lid angle sensor. |
| `./Scripts/capture-check.sh` | Asks whether Screen Recording is granted for the bundle. |
| `./Scripts/package.sh` | Release build, versioned ZIP and checksum in `dist/`. |

`swift build` and `swift test` work directly as well. `Scripts/check.sh` is what CI runs.

## Signing and Screen Recording

`build.sh` leaves the bundle alone when the executable, `Info.plist` and signing identity
are all unchanged. If you do end up with a stale entry, remove **LidFold** under System
Settings → Privacy & Security → Screen & System Audio Recording and approve the rebuilt
app again.

Building into a folder synced by iCloud is workable but noisy: the file provider keeps
re-stamping Finder metadata on the bundle, which is why the build clears extended
attributes before signing and does not verify with `--strict`.

macOS ties the Screen Recording approval to the app's signing identity, so an identity
that changes between builds costs a permission prompt on every launch. An ad-hoc
signature does exactly that. `build.sh` therefore picks the first real codesigning
identity it finds, remembers the choice in `.build/bundle-stamp/identity`, and reuses it
until you ask for a different one. List what you have with
`security find-identity -v -p codesigning`.

Override the choice with `LIDFOLD_SIGN_IDENTITY`:

```bash
LIDFOLD_SIGN_IDENTITY="Developer ID Application: …" ./Scripts/build.sh release
```

## Checking work without hardware

Most of the app can be verified on any Mac:

- `swift test` covers the anchor state machine, the angle validation, the report decoding
  and the settings, with time injected rather than waited on.
- `LidFold --preview` renders the reference stills into `dist/previews/` and runs the
  shader checks against a generated white source, so it needs neither the desktop nor a
  permission grant.
- `LidFold --capture-check` reports whether Screen Recording is granted for the bundle,
  which is the quickest way to tell a permission problem from a broken build. It must run
  through `open` so macOS attributes the request to the app rather than to the terminal.
- `LidFold --probe` is the only part that needs the real sensor.

## Adding an option

1. Add the field to `EffectSettings` in `LidFoldCore`, and to `projection` or
   `producesVisibleEffect` if it changes what is drawn.
2. Persist it in `UserDefaultsSettingsStore`.
3. Add the menu item in `FoldMenuController`, which reads it straight off the snapshot.

`FoldEffectController` usually needs no change: it copies the settings into
`FoldEffectParameters` on every tick.

## Version numbers

The version lives in `Info.plist` only. `package.sh` reads it from there for the archive
name, so bump `CFBundleShortVersionString` and `CFBundleVersion` together.
