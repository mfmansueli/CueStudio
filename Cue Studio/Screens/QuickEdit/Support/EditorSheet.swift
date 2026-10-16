//
//  EditorSheet.swift
//  Cue Studio
//

import Foundation

/// A sheet over the editor.
enum EditorSheet: String, Identifiable {
    /// A sound file from Files, under the voice.
    case music
    /// A photo or video from Photos, on top of the video or as a clip.
    case media
    /// Done's question: "Is it ready to post?".
    case done
    /// Edit by text: cut words out of the video.
    case transcript
    /// Reorder: the clips in play order, to drag.
    case clipOrder
    /// Find and replace in the caption lines.
    case findInCaptions

    var id: String { rawValue }
}
