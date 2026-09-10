# Architecture

LidFold is a Swift package of six targets. Dependencies only ever point inwards, towards
`LidFoldCore`.

```
LidFold                     executable, entry point and command line
  └── LidFoldApp            AppKit: menu bar, overlay panel, orchestration
        ├── LidFoldRender   Metal: shader, blur pyramid, offscreen checks
        ├── LidFoldCapture  ScreenCaptureKit: the display stream
        ├── LidFoldSensing  IOKit HID: the lid angle sensor
        └── LidFoldCore     value types and state machines, no frameworks
```

## LidFoldCore

Knows nothing about AppKit, Metal, IOKit or ScreenCaptureKit, so all of it runs in a unit
test without a display, a GPU or a hinge.

| Type | Responsibility |
| --- | --- |
| `LidAngle` | A validated hinge angle. Readings are checked once, here, rather than in every layer that touches them. |
| `LidAngleReport` | Decodes the sensor's raw feature report bytes. |
| `AnchorEngine` | Holds the angle the image is pinned to and eases it back once the lid stops moving. Time is injected. |
| `ExponentialSmoother` | Frame-rate independent low-pass filter for the raw readings. |
| `EffectSettings` | The user's options, plus the derived `ProjectionMode`. |
| `FoldEffectParameters` | The per-frame input to the renderer. |
| `EffectStatus` | What the menu bar reports. |
| `LidAngleSource`, `DisplayFrameSource`, `SettingsStore` | The three seams the outer layers plug into. |

## The seams

Each protocol in `LidFoldCore` exists because there is more than one thing behind it:

- `LidAngleSource` is either `HIDLidAngleSource` or `SimulatedLidAngleSource`, which backs
  both the demo mode and the tests.
- `DisplayFrameSource` keeps ScreenCaptureKit and its permission prompt out of the
  orchestration code.
- `SettingsStore` is `UserDefaultsSettingsStore` in the app and `InMemorySettingsStore` in
  tests.

## LidFoldApp

`FoldEffectController` is the only object that knows the whole story. It polls the sensor,
advances the `AnchorEngine`, feeds `FoldRenderer` and decides whether the overlay is worth
showing at all. Everything it depends on arrives through its initialiser, including the
clock.

The rest of the layer is deliberately dumb:

- `OverlayWindowController` owns the click-through panel and its `MTKView`, and keeps both
  matched to the display's size and backing scale.
- `StatusItemController` owns the menu bar item and turns clicks into two callbacks.
- `FoldMenuController` builds the options menu from a `MenuSnapshot` and holds no state of
  its own, so the menu and the running effect cannot drift apart.
- `AppDelegate` is a composition root: it builds the graph once and wires the callbacks.

## Rendering

`FoldRenderer` owns GPU state and nothing else. It is told what to draw through
`parameters` and `present(_:)`.

- The Metal source lives in a Swift string and is compiled at launch. A `.metallib` would
  have to travel in a resource bundle that the hand-assembled `.app` would then need to
  carry and look up.
- `BlurPyramid` keeps four Gaussian copies of the current frame. The shader blends between
  them per pixel, which is far cheaper than varying a real blur radius across the surface
  every frame, and it avoids the speckling that sparse disc sampling produces.
- `FrameTextureCache` wraps a capture frame as a texture without copying it, and holds both
  the wrapper and the pixel buffer alive until the GPU has finished reading them.
- `RenderDiagnostics` renders a flat white source offscreen and asserts that the blur
  crosses the projected border, softens inward, tightens near the hinge and disappears
  entirely when blur is switched off. It never touches the real desktop.

## Why the overlay hides itself

While the reference angle and the lid agree there is nothing for the effect to add, so the
panel is ordered out and the real desktop shows through. That avoids the capture latency,
the downscaled frame and the click confusion that a permanently visible overlay would
bring. An independent timer keeps polling the sensor while the panel is hidden.
