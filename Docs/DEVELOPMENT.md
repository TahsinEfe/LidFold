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
| `./Scripts/package.sh` | Release build, versioned ZIP and checksum in `dist/`. |

`swift build` and `swift test` work directly as well. `Scripts/check.sh` is what CI runs.

## Signing and Screen Recording

`build.sh` signs the bundle ad-hoc and leaves it alone when neither the executable nor
`Info.plist` changed. This matters: re-signing gives the app a new code identity, and
macOS then treats it as a different app and forgets the Screen Recording approval. If you
do end up with a stale entry, remove **LidFold** under System Settings → Privacy &
Security → Screen & System Audio Recording and approve the rebuilt app again.

Set `LIDFOLD_SIGN_IDENTITY` to sign with a real identity instead:

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
