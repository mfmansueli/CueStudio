//
//  SplitScreen.swift
//  Cue Studio
//

import Foundation

/// An edit's split screen: its layouts (one for the whole video for now; each support names its own, so a section can get
/// another later), how each recording of the main video sits in its area, and whether the photos and videos laid over the
/// take play their sound ("Mute all supports"). A support is a photo or video with the split layout (`MediaLayout.split`).
nonisolated struct SplitScreen: Codable, Hashable, Sendable {
    var layouts: [SplitLayout] = []
    var framings: [RecordingFraming] = []
    /// Silences every photo and video laid over the take, keeping each one's own volume for when it's turned back on.
    var mutesMedia = false
    /// "On the seam": while a support shows (one over the other), the captions sit centered on the seam; the rest of the
    /// video, where the creator put them.
    var captionsOnSeam = false

    init(layouts: [SplitLayout] = [], framings: [RecordingFraming] = [], mutesMedia: Bool = false, captionsOnSeam: Bool = false) {
        self.layouts = layouts
        self.framings = framings
        self.mutesMedia = mutesMedia
        self.captionsOnSeam = captionsOnSeam
    }

    /// The layout a support names, else the video's (the first), else the starting one: support on top, main below, 50/50.
    func layout(id: UUID?) -> SplitLayout {
        layouts.first { $0.id == id } ?? layouts.first ?? SplitLayout()
    }

    /// How the recording `sourceID` (nil: the take) sits in its area; centered and filling until set.
    func framing(for sourceID: UUID?) -> AreaFraming {
        framings.first { $0.sourceID == sourceID }?.framing ?? AreaFraming()
    }

    /// Whether the recording has a framing of its own (set by hand, or found on its face when the split was made).
    func hasFraming(for sourceID: UUID?) -> Bool {
        framings.contains { $0.sourceID == sourceID }
    }

    mutating func setFraming(_ framing: AreaFraming, for sourceID: UUID?) {
        framings.removeAll { $0.sourceID == sourceID }
        framings.append(RecordingFraming(sourceID: sourceID, framing: framing))
    }

    /// Sets the video's layout (the one every support uses for now), keeping its identity.
    mutating func setLayout(_ layout: SplitLayout) {
        if let index = layouts.firstIndex(where: { $0.id == layout.id }) {
            layouts[index] = layout
        } else if layouts.isEmpty {
            layouts = [layout]
        } else {
            var shared = layout
            shared.id = layouts[0].id
            layouts[0] = shared
        }
    }

    private enum CodingKeys: String, CodingKey {
        case layouts, framings, mutesMedia, captionsOnSeam
    }

    /// One layout or framing that can't be read never takes the others with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layouts = container.decodeLossy([SplitLayout].self, forKey: .layouts)
        framings = container.decodeLossy([RecordingFraming].self, forKey: .framings)
        mutesMedia = (try? container.decodeIfPresent(Bool.self, forKey: .mutesMedia)) ?? false
        captionsOnSeam = (try? container.decodeIfPresent(Bool.self, forKey: .captionsOnSeam)) ?? false
    }
}
