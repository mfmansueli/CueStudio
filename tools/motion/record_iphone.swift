// Films a cable-connected iPhone's screen from the Mac, as QuickTime does (the screen's own frames, ~60 fps, full resolution), until it is
// sent SIGINT or SIGTERM, or after <max seconds>. Prints "RECORDING-STARTED <Unix time>" when the first frame is written; with no frame in
// 10 s (the screen asleep, or still held by a test run that just ended) it says so and exits 2, for the caller to try again.
//   record_iphone <part of the iPhone's name> <max seconds> <out.mov>
// Built and run by tools/motion/film.sh. Needs camera access for the Terminal (macOS asks once) and the iPhone unlocked.
import AVFoundation
import CoreMediaIO

setvbuf(stdout, nil, _IONBF, 0)
let arguments = CommandLine.arguments
guard arguments.count == 4, let maximum = Double(arguments[2]) else {
    print("usage: record_iphone <name> <max seconds> <out.mov>")
    exit(64)
}
let name = arguments[1]
let out = URL(fileURLWithPath: arguments[3])

// The Mac shows iPhones' screens as capture devices only once asked to.
var allowAddress = CMIOObjectPropertyAddress(
    mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
    mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
    mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
)
var allow: UInt32 = 1
CMIOObjectSetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &allowAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allow)

if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
    let asked = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .video) { _ in asked.signal() }
    asked.wait()
}

// The screen is a muxed device (picture and sound), not the phone's camera; it shows up a moment after being allowed.
var found: AVCaptureDevice?
for _ in 0..<40 {
    found = AVCaptureDevice.DiscoverySession(deviceTypes: [.external], mediaType: .muxed, position: .unspecified).devices
        .first { $0.localizedName.localizedCaseInsensitiveContains(name) }
    if found != nil { break }
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
}
guard let device = found else {
    print("No iPhone screen named like “\(name)”: is it connected by cable and unlocked?")
    exit(1)
}

final class Recording: NSObject, AVCaptureFileOutputRecordingDelegate {
    var started = false
    var finished = false
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        started = true
        print(String(format: "RECORDING-STARTED %.3f", Date().timeIntervalSince1970))
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL, from connections: [AVCaptureConnection], error: Error?) {
        print(error.map { "Recording failed: \($0.localizedDescription)" } ?? "Recording saved: \(url.path)")
        finished = true
    }
}

let session = AVCaptureSession()
session.addInput(try AVCaptureDeviceInput(device: device))
let output = AVCaptureMovieFileOutput()
session.addOutput(output)
session.startRunning()
// The phone takes a moment to start sending its screen.
RunLoop.current.run(until: Date().addingTimeInterval(3))
let recording = Recording()
try? FileManager.default.removeItem(at: out)
output.startRecording(to: out, recordingDelegate: recording)

var stopRequested = false
for signalNumber in [SIGINT, SIGTERM] {
    signal(signalNumber, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
    source.setEventHandler { stopRequested = true }
    source.resume()
    _ = Unmanaged.passRetained(source)
}
let firstFrame = Date().addingTimeInterval(10)
while !recording.started, Date() < firstFrame {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
guard recording.started else {
    print("NO-FRAMES: the iPhone sent nothing in 10 s (is its screen on?)")
    exit(2)
}
let deadline = Date().addingTimeInterval(maximum)
while !stopRequested, Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
output.stopRecording()
while !recording.finished {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
session.stopRunning()
