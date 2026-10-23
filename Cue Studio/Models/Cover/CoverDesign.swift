//
//  CoverDesign.swift
//  Cue Studio
//

import Foundation

/// The v26 cover: a layout, a typeface, which word is highlighted, what is done to the picture and
/// the elements on top. Optional on `VideoCover`: covers made before it keep their own look.
nonisolated struct CoverDesign: Codable, Hashable, Sendable {
    var layout: CoverLayout = .hook
    var font: CoverFont = .anton
    /// The word (by position, after the number is taken out) shown in black on yellow.
    var highlightIndex = 1
    var effect: CoverEffect = .clean
    var elements: Set<CoverElement> = []
    /// "EP 03" and "PART 3": the number in the series.
    var episode = 3
    /// "@maya": the creator's handle, drawn when the handle element is on.
    var handle = ""

    init() {}

    private enum CodingKeys: String, CodingKey {
        case layout, font, highlightIndex, effect, elements, episode, handle
    }

    /// A part that can't be read keeps where a new design starts, and an element a newer version added is left out.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layout = (try? container.decodeIfPresent(CoverLayout.self, forKey: .layout)) ?? .hook
        font = (try? container.decodeIfPresent(CoverFont.self, forKey: .font)) ?? .anton
        highlightIndex = (try? container.decodeIfPresent(Int.self, forKey: .highlightIndex)) ?? 1
        effect = (try? container.decodeIfPresent(CoverEffect.self, forKey: .effect)) ?? .clean
        elements = Set(container.decodeLossy([CoverElement].self, forKey: .elements))
        episode = (try? container.decodeIfPresent(Int.self, forKey: .episode)) ?? 3
        handle = (try? container.decodeIfPresent(String.self, forKey: .handle)) ?? ""
    }

    /// What Save as my style keeps: how it looks, not what it says.
    var look: CoverLook {
        CoverLook(layout: layout, font: font, effect: effect, series: elements.contains(.series))
    }

    /// Takes a saved look (the words, the number and the handle stay).
    mutating func apply(_ look: CoverLook) {
        layout = look.layout
        font = look.font
        effect = look.effect
        if look.series { elements.insert(.series) } else { elements.remove(.series) }
    }

    // MARK: - The words

    /// The title split into words, ready to draw: with the Number layout the first number is taken
    /// out (it is drawn big), and with Question the last word ends in "?". With no title there is
    /// nothing to draw.
    func words(of title: String) -> (number: String?, words: [String]) {
        var words = title.split(whereSeparator: \.isWhitespace).map(String.init)
        var number: String?
        if layout == .number {
            let index = words.firstIndex { $0.allSatisfy(\.isNumber) }
            if let index {
                number = words[index]
                words.remove(at: index)
            } else {
                number = "3"
            }
        }
        if layout == .question, let last = words.last, !last.hasSuffix("?") {
            words[words.count - 1] = last + "?"
        }
        return (number, words)
    }

    /// The highlighted word's position, held inside `count` words (the last one when too far).
    func highlight(in count: Int) -> Int? {
        guard count > 0 else { return nil }
        return min(max(0, highlightIndex), count - 1)
    }

    /// "PART 3 · FIVE": the tag over the Kicker layout.
    func kicker(firstWord: String?) -> String {
        String(localized: "Part \(episode)") + " · " + (firstWord ?? "")
    }

    /// "EP 03": the series tag.
    var episodeLabel: String {
        "EP " + String(format: "%02d", episode)
    }
}
