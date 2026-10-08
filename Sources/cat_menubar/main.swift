import AppKit
import Darwin

let app = NSApplication.shared
// Rebuilds send SIGTERM. Use the same cleanup path as Quit.
signal(SIGTERM, SIG_IGN)
let terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
terminationSignal.setEventHandler { app.terminate(nil) }
terminationSignal.resume()
let delegate = AppDelegate()
app.delegate = delegate
app.run()
