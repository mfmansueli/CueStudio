//
//  EditorSheet.swift
//  Cue Studio
//

import Foundation

/// A sheet over the editor.
enum EditorSheet: String, Identifiable {
    /// Resolution, frame rate and the free exports left, then the export itself.
    case export
    /// A sound file from Files, under the voice.
    case music
    /// A photo or video from Photos, on top of the video or as a clip.
    case media

    var id: String { rawValue }
}
