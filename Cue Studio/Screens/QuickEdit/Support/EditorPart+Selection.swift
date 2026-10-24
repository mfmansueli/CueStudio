//
//  EditorPart+Selection.swift
//  Cue Studio
//

import Foundation

/// What is picked, by kind: each id reads the one selection (`EditorSelection`); setting an id picks that item, and setting nil
/// lets go only when the selection is of that kind.
extension EditorPart {
    /// The clip tapped on the timeline. Separate from the playhead: scrubbing doesn't change it.
    var selectedSegmentID: UUID? {
        get { selection?.clipID }
        set { select(newValue.map(EditorSelection.clip), replacing: \.clipID) }
    }

    /// The cut tapped on the timeline, named by the section that starts there: its transition can
    /// be picked (`EditorSelection.join`).
    var selectedJoinID: UUID? {
        get { selection?.joinID }
        set { select(newValue.map(EditorSelection.join), replacing: \.joinID) }
    }

    /// The text picked on the preview or its track.
    var selectedTextID: UUID? {
        get { selection?.textID }
        set { select(newValue.map(EditorSelection.text), replacing: \.textID) }
    }

    /// The photo or video picked on the preview or its track.
    var selectedMediaID: UUID? {
        get { selection?.mediaID }
        set { select(newValue.map(EditorSelection.media), replacing: \.mediaID) }
    }

    /// The caption line picked on the timeline or in the Captions list.
    var selectedCaptionID: UUID? {
        get { selection?.captionID }
        set { select(newValue.map(EditorSelection.caption), replacing: \.captionID) }
    }

    /// The voice-over picked on its track (or just recorded).
    var reviewedVoiceOverID: UUID? {
        get { selection?.voiceOverID }
        set { select(newValue.map(EditorSelection.voiceOver), replacing: \.voiceOverID) }
    }

    /// The music clip picked on its track.
    var selectedMusicID: UUID? {
        get { selection?.musicID }
        set { select(newValue.map(EditorSelection.music), replacing: \.musicID) }
    }

    /// The picked text.
    var selectedText: TextOverlay? {
        selectedTextID.flatMap { id in edit.texts.first { $0.id == id } }
    }

    /// The picked photo or video.
    var selectedMedia: MediaOverlay? {
        selectedMediaID.flatMap { id in edit.media.first { $0.id == id } }
    }

    /// Where the picked clip is.
    var selectedSegmentIndex: Int? {
        selectedSegmentID.flatMap { edit.timeline.index(ofSegment: $0) }
    }

    /// Where the selected cut is: the index of the section that starts there (never the first).
    var selectedJoinIndex: Int? {
        guard let index = selectedJoinID.flatMap({ edit.timeline.index(ofSegment: $0) }), index > 0 else { return nil }
        return index
    }

    /// The selected cut's transition, or nil when no cut is selected.
    var selectedTransition: EditTransition? {
        selectedJoinIndex.map { edit.timeline.transition(atJoin: $0) }
    }

    private func select(_ new: EditorSelection?, replacing id: KeyPath<EditorSelection, UUID?>) {
        if let new {
            selection = new
        } else if selection?[keyPath: id] != nil {
            selection = nil
        }
    }
}
