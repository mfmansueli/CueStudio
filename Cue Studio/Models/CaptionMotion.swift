//
//  CaptionMotion.swift
//  Cue Studio
//

import Foundation

/// How a caption moves, in three choices that never hide in one another (Caption style › Animation): how it comes in and goes
/// out, whether it shows whole or word by word, and how the word being said stands out. Every combination works, and every one
/// reads with no motion at all: the still frame is the caption.
///
/// Nil in `CaptionSettings`: an edit saved before it, drawn as it was made (`CaptionAnimation` and the preset's own entry).
nonisolated struct CaptionMotion: Codable, Hashable, Sendable {
    var entry: CaptionEntry
    var reveal: CaptionReveal
    var spoken: CaptionSpokenHighlight

    init(entry: CaptionEntry = .none, reveal: CaptionReveal = .line, spoken: CaptionSpokenHighlight = .none) {
        self.entry = entry
        self.reveal = reveal
        self.spoken = spoken
    }

    /// Needs each word's own time.
    var followsWords: Bool { reveal == .words || spoken != .none }

    /// What an edit made before it plays (`animation`, as `CaptionCollectionRenderer.effectiveAnimation` reads it), in the three
    /// choices, so Animation shows it and a change starts from it.
    init(playing animation: CaptionAnimation, spec: CaptionStyleSpec) {
        let entry: CaptionEntry = if spec.entry.popScale < 1 { .pop } else if spec.entry.fade > 0 { .fade } else { .none }
        switch animation {
        case .line: self.init(entry: entry)
        case .fade: self.init(entry: .fade)
        case .groups: self.init(entry: entry, reveal: .words)
        case .highlight: self.init(entry: entry, spoken: spec.highlightsWithBox ? .box : .color)
        case .box: self.init(entry: entry, spoken: .box)
        }
    }

    /// The nearest of the ways an earlier Cue shows lines, written beside it (`TakeEdit.captionAnimation`) so a build that
    /// doesn't know motion still plays something close.
    var nearestAnimation: CaptionAnimation {
        if reveal == .words { return .groups }
        switch spoken {
        case .color, .pop: return .highlight
        case .box, .glide: return .box
        case .none: return entry == .none ? .line : .fade
        }
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case entry, reveal, spoken
    }

    /// A part this version doesn't know reads as its fallback, never as a broken caption.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entry = (try? container.decodeIfPresent(CaptionEntry.self, forKey: .entry)) ?? CaptionEntry.none
        reveal = (try? container.decodeIfPresent(CaptionReveal.self, forKey: .reveal)) ?? .line
        spoken = (try? container.decodeIfPresent(CaptionSpokenHighlight.self, forKey: .spoken)) ?? CaptionSpokenHighlight.none
    }
}
