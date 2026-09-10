# Contributing

Bug reports and pull requests are welcome.

## Before opening a pull request

```bash
./Scripts/check.sh
```

Both the unit tests and the shader checks must pass. If the change touches the sensor
path, say which MacBook model you tested it on, since sensor support varies.

## What to keep in mind

- Dependencies point inwards. `LidFoldCore` must not import AppKit, Metal, IOKit or
  ScreenCaptureKit; see [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md).
- Anything with logic worth arguing about belongs in `LidFoldCore` with a test, not in a
  view controller.
- No third-party dependencies.
- Comments explain why, not what.

## Reporting a sensor problem

Include the output of `./Scripts/probe.sh`, your macOS version and the exact MacBook
model. A "no readable angle" result is useful too: it tells us which models to list as
unsupported.
