import AppKit
import LidFoldApp

/// The executable is only an entry point: it either answers a diagnostic command and
/// exits, or hands control to AppKit.
let arguments = Set(CommandLine.arguments.dropFirst())

if arguments.contains("--help") {
    print("""
    LidFold — hold the desktop at a fixed angle while the lid moves.

      --probe     Report whether this Mac has a readable lid angle sensor.
      --preview   Render the reference stills and run the shader checks offscreen.
      --capture-check
                  Ask ScreenCaptureKit whether Screen Recording is granted for this
                  bundle, and write the answer to dist/capture-check.txt.
      --help      Show this message.

    With no arguments LidFold runs as a menu bar app.
    """)
    exit(0)
}

if arguments.contains("--probe") {
    let result = DiagnosticCommands.probeSensor()
    print(result.message)
    exit(result.exitCode)
}

if arguments.contains("--preview") {
    let directory = URL(fileURLWithPath: "dist/previews", isDirectory: true)
    let result = DiagnosticCommands.renderPreviews(into: directory)
    print(result.message)
    exit(result.exitCode)
}

if arguments.contains("--capture-check") {
    _ = NSApplication.shared
    var outcome: DiagnosticCommands.Result?
    Task { outcome = await DiagnosticCommands.checkCapture() }

    // Launched through `open`, so stdout goes nowhere: the run loop is pumped until the
    // answer arrives and the report is written next to the bundle instead.
    let deadline = Date().addingTimeInterval(20)
    while outcome == nil, Date() < deadline {
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    let result = outcome ?? .failure("ScreenCaptureKit did not answer within 20 seconds.")
    let report = "\(result.exitCode == 0 ? "PASS" : "FAIL"): \(result.message)\n"
    let destination = Bundle.main.bundleURL.deletingLastPathComponent()
        .appendingPathComponent("capture-check.txt")
    try? report.write(to: destination, atomically: true, encoding: .utf8)
    print(report)
    exit(result.exitCode)
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
