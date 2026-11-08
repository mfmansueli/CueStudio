//
//  PasteLookChoice.swift
//  Cue Studio
//

import Foundation

/// How the creator last pasted a copied look in this project (`TakeEdit.pasteLookChoice`): which parts, and whether on every
/// clip. The first Paste look of a project asks in its sheet; after that Paste look repeats the choice where it fits
/// (`repeated(on:of:in:)`), and the sheet opens on it where it doesn't.
nonisolated struct PasteLookChoice: Codable, Hashable, Sendable {
    var parts: Set<ClipLookPart>
    var everyClip: Bool

    init(parts: Set<ClipLookPart>, everyClip: Bool) {
        self.parts = parts
        self.everyClip = everyClip
    }

    /// The paste to make without asking, with `clipID` picked (nil when no clip is), or nil when this choice doesn't fit there and
    /// the sheet opens again. The rule:
    /// - With a clip picked, it goes on that clip with these parts, also when the choice was every clip: one tap never changes clips
    ///   out of sight without the sheet (the toast's Change reaches every clip).
    /// - With no clip picked, only a choice of every clip is repeated, on every clip.
    /// - It fits only when one of its parts changes something there. Parts the target already has (the clip the look came from, a
    ///   clip pasted on before) would make a tap that does nothing, so the sheet opens to pick others.
    ///
    /// No part depends on the kind of clip (`CopiedClipLook.pasted` takes all five on a freeze frame, a reversed clip, a video from
    /// Photos or a short clip), so nothing else makes a choice not fit.
    func repeated(on clipID: UUID?, of copied: CopiedClipLook, in edit: TakeEdit) -> PasteLookChoice? {
        guard !parts.isEmpty, clipID != nil || everyClip else { return nil }
        if let clipID, edit.timeline.segment(id: clipID) == nil { return nil }
        let repeated = PasteLookChoice(parts: parts, everyClip: clipID == nil)
        let pasted = copied.pasted(parts, everyClip: repeated.everyClip, on: clipID, in: edit)
        return pasted == edit ? nil : repeated
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case parts, everyClip
    }

    /// A part a newer version of Cue added is left out, rather than the whole choice.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let names = try container.decode([String].self, forKey: .parts)
        parts = Set(names.compactMap(ClipLookPart.init(rawValue:)))
        everyClip = try container.decodeIfPresent(Bool.self, forKey: .everyClip) ?? false
    }

    /// The parts in a fixed order, so a saved edit reads the same each time it's written.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ClipLookPart.allCases.filter(parts.contains).map(\.rawValue), forKey: .parts)
        try container.encode(everyClip, forKey: .everyClip)
    }
}
