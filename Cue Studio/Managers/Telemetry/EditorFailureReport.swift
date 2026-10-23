//
//  EditorFailureReport.swift
//  Cue Studio
//

import Foundation
import os

/// One editor or export failure the creator saw ("Couldn't export", "Can't add this file", a preview that wouldn't play…), as
/// the log and the crash reports keep it: what was being done, the error by its type and case (Cue's) or its domain and code
/// (the system's) with the error under it (where AVFoundation says why), how big the edit was, and the iPhone then
/// (`DeviceFacts`). Never the creator's words, names, files or pictures.
///
/// In Console: subsystem `studio.cue`, category `Editor`. Also a non-fatal report in Crashlytics (`TelemetryManager.record(_:)`),
/// one issue per operation and reason.
nonisolated struct EditorFailureReport: Equatable, Sendable {
    /// What was being done: "export", "save", "draft", "preview", "importMedia", "freezeFrame"…
    var operation: String
    /// "VideoExportError.tooWarm", or "AVFoundationErrorDomain -11800".
    var reason: String
    /// The error under it, by domain and code; nil when there is none.
    var underlying: String?
    /// How big the edit was; nil outside the editor.
    var size: EditSize?
    var device: String
    var system: String
    var thermal: String
    var lowPower: Bool
    var freeMemoryMB: Int
    /// Storage left, in MB; nil when it couldn't be read.
    var freeStorageMB: Int?
    var appState: String

    /// How big an edit is, in counts only.
    nonisolated struct EditSize: Equatable, Sendable {
        var clips: Int
        /// Texts, photos and videos, music, voice-overs and caption lines.
        var layers: Int
        /// Its length, to the second.
        var seconds: Int

        init(_ edit: TakeEdit) {
            clips = edit.timeline.segments.count
            layers = edit.texts.count + edit.media.count + edit.music.count + edit.voiceOvers.count + edit.captions.count
            seconds = Int(edit.editedDuration.rounded())
        }
    }

    /// A failure to write down, with the iPhone as it is now; nil for a cancellation (not a failure).
    @MainActor
    static func make(_ error: any Error, operation: String, edit: TakeEdit? = nil) -> EditorFailureReport? {
        if error is CancellationError { return nil }
        let (reason, underlying) = reason(of: error)
        return EditorFailureReport(
            operation: operation, reason: reason, underlying: underlying, size: edit.map(EditSize.init), device: DeviceFacts.model,
            system: DeviceFacts.system, thermal: DeviceFacts.thermal, lowPower: DeviceFacts.lowPower, freeMemoryMB: DeviceFacts.freeMemoryMB,
            freeStorageMB: StorageSpace.available().map { Int($0 / 1_048_576) }, appState: DeviceFacts.appState
        )
    }

    /// Cue's own errors by type and case, without what a case carries (it could be the creator's); the system's by domain and
    /// code, with the error under it.
    static func reason(of error: any Error) -> (reason: String, underlying: String?) {
        let bridged = error as NSError
        let underlying = (bridged.userInfo[NSUnderlyingErrorKey] as? NSError).map { "\($0.domain) \($0.code)" }
        if String(reflecting: type(of: error)).hasPrefix("Cue_Studio.") {
            let caseName = Mirror(reflecting: error).children.first?.label ?? "\(error)"
            return ("\(type(of: error)).\(caseName)", underlying)
        }
        return ("\(bridged.domain) \(bridged.code)", underlying)
    }

    /// The report's issue: one per operation and reason.
    var issue: String { "Editor.\(operation).\(reason)" }

    /// The one line in Console.
    var line: String {
        var line = "\(operation) failed: \(reason)"
        if let underlying { line += " (under it: \(underlying))" }
        if let size { line += " · clips=\(size.clips) layers=\(size.layers) seconds=\(size.seconds)" }
        line += " · thermal=\(thermal) lowPower=\(lowPower) freeMemory=\(freeMemoryMB)MB freeStorage=\(freeStorageMB.map { "\($0)MB" } ?? "?")"
        line += " app=\(appState) device=\(device) iOS \(system)"
        return line
    }

    /// The same, as the keys of a crash report.
    var keys: [String: String] {
        var keys = [
            "operation": operation, "reason": reason, "underlying": underlying ?? "none", "thermal": thermal, "lowPower": "\(lowPower)",
            "freeMemoryMB": "\(freeMemoryMB)", "freeStorageMB": freeStorageMB.map { "\($0)" } ?? "unknown", "appState": appState,
            "device": device, "system": system,
        ]
        if let size {
            keys["clips"] = "\(size.clips)"
            keys["layers"] = "\(size.layers)"
            keys["seconds"] = "\(size.seconds)"
        }
        return keys
    }

    private static let logger = Logger(subsystem: "studio.cue", category: "Editor")

    /// Into Console, and into Crashlytics with the next launch (nothing while Firebase isn't running: tests, previews).
    @MainActor
    func send() {
        Self.logger.error("\(line, privacy: .public)")
        TelemetryManager.record(self)
    }
}
