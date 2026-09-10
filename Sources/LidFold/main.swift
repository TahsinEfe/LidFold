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

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
