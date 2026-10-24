//
//  SplitLayout.swift
//  Cue Studio
//

import Foundation

/// Where the two contents of a split screen go: one over the other or side by side, evenly or 60/40, which content is first
/// (top, or left), which gets the larger share, and whether a thin line marks the seam. Supports name the layout they use
/// (`MediaOverlay.splitLayoutID`): the editor keeps one for the whole video for now, and a section can get its own later.
nonisolated struct SplitLayout: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var arrangement: SplitArrangement = .stacked
    var ratio: SplitRatio = .even
    /// The content in the first area: top when stacked, left side by side (it stays left in right-to-left languages, like
    /// the video itself). The support starts there.
    var first: SplitArea = .support
    /// The content with the larger share at 60/40.
    var larger: SplitArea = .main
    var showsDivider = false

    init(
        id: UUID = UUID(), arrangement: SplitArrangement = .stacked, ratio: SplitRatio = .even, first: SplitArea = .support,
        larger: SplitArea = .main, showsDivider: Bool = false
    ) {
        self.id = id
        self.arrangement = arrangement
        self.ratio = ratio
        self.first = first
        self.larger = larger
        self.showsDivider = showsDivider
    }

    /// The same layout with the two contents' places exchanged; sizes stay with the contents.
    var swapped: SplitLayout {
        var layout = self
        layout.first = first.other
        return layout
    }

    /// The first area's share of the frame.
    var firstShare: Double {
        ratio == .even ? 0.5 : (larger == first ? ratio.largerShare : 1 - ratio.largerShare)
    }

    private enum CodingKeys: String, CodingKey {
        case id, arrangement, ratio, first, larger, showsDivider
    }

    /// Lenient: what's missing or unknown reads as the default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        arrangement = (try? container.decodeIfPresent(SplitArrangement.self, forKey: .arrangement)) ?? .stacked
        ratio = (try? container.decodeIfPresent(SplitRatio.self, forKey: .ratio)) ?? .even
        first = (try? container.decodeIfPresent(SplitArea.self, forKey: .first)) ?? .support
        larger = (try? container.decodeIfPresent(SplitArea.self, forKey: .larger)) ?? .main
        showsDivider = (try? container.decodeIfPresent(Bool.self, forKey: .showsDivider)) ?? false
    }
}
