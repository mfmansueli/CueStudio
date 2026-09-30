//
//  ClipSource.swift
//  Cue Studio
//

import Foundation

/// Another recording in a montage: a take from the library or a video brought in from Photos. Its
/// file is kept with the edit's media (`EditMediaFiles`), linked to the take's own file rather than
/// copied, so it costs no space and stays when the take is deleted from the library.
nonisolated struct ClipSource: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    /// The file's name in `EditMediaFiles`.
    var fileName: String
    /// Its length, in seconds.
    var duration: TimeInterval
    /// What the creator knows it by: "3 morning habits · Take 2", or "Video".
    var title: String
    /// The take it came from, when it came from the library.
    var takeID: UUID?
    var scriptReference: Script?

    init(fileName: String, duration: TimeInterval, title: String, takeID: UUID? = nil) {
        self.fileName = fileName
        self.duration = duration
        self.title = title
        self.takeID = takeID
    }
}
