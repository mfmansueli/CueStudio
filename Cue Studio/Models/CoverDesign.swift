//
//  CoverDesign.swift
//  Cue Studio
//

import Foundation

/// How a cover's words are laid out (v26 Cover › Text).
nonisolated enum CoverLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Big words with one highlighted.
    case hook
    /// A big number from the title, then the rest (a listicle).
    case number
    /// A small "PART 3 · WORD" tag above the title (a series).
    case kicker
    /// The title as a question, in a dark box.
    case question
    /// No title: BEFORE and AFTER labels on a split picture (a result).
    case beforeAfter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hook: String(localized: "Hook")
        case .number: String(localized: "Number")
        case .kicker: String(localized: "Kicker")
        case .question: String(localized: "Question")
        case .beforeAfter: String(localized: "Before/After")
        }
    }

    /// What it is for, in the tile's mono caption.
    var purpose: String {
        switch self {
        case .hook: String(localized: "Big + highlight")
        case .number: String(localized: "Listicle")
        case .kicker: String(localized: "Series")
        case .question: String(localized: "Curiosity")
        case .beforeAfter: String(localized: "Result")
        }
    }

    /// The glyph on the tile.
    var glyph: String {
        switch self {
        case .hook: "AA"
        case .number: "3"
        case .kicker: "D12"
        case .question: "?"
        case .beforeAfter: "B|A"
        }
    }

    /// Where the words start, as a share of the cover's height from the top.
    var textTop: Double {
        switch self {
        case .number: 0.18
        case .kicker: 0.26
        case .hook, .question, .beforeAfter: 0.30
        }
    }

    /// The size of the words, as a share of the cover's width.
    var wordSize: Double {
        switch self {
        case .number, .question: 0.105
        case .hook, .kicker, .beforeAfter: 0.135
        }
    }

    var showsTitle: Bool { self != .beforeAfter }
}

/// The typeface of a cover's words: a tall condensed one, or the editor's families.
nonisolated enum CoverFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case anton, grotesk, serif, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anton: "Anton"
        case .grotesk: "Grotesk"
        case .serif: "Serif"
        case .system: "SF Pro"
        }
    }
}

/// What is done to the picture behind the words (Cover › Look).
nonisolated enum CoverEffect: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The words sit on top of the picture.
    case clean
    /// "Text behind me": the person is cut out and drawn over the words.
    case lift
    /// "Outline me": the cut-out person gets a white stroke.
    case outline
    /// The picture is dimmed so the words pop.
    case dim
    /// The picture is blurred so the words pop.
    case blur

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clean: String(localized: "Clean")
        case .lift: String(localized: "Text behind me")
        case .outline: String(localized: "Outline me")
        case .dim: String(localized: "Dim back")
        case .blur: String(localized: "Blur back")
        }
    }

    var purpose: String {
        switch self {
        case .clean: String(localized: "Text on top")
        case .lift: String(localized: "Subject lift")
        case .outline: String(localized: "White stroke")
        case .dim: String(localized: "Text pops")
        case .blur: String(localized: "Focus on you")
        }
    }

    var glyph: String {
        switch self {
        case .clean: "—"
        case .lift: "T|ME"
        case .outline: "◌"
        case .dim: "◐"
        case .blur: "≈"
        }
    }

    /// Needs the person cut out of the frame.
    var needsPersonMask: Bool { self == .lift || self == .outline }
}

/// The little extras drawn on a cover (Cover › Elements).
nonisolated enum CoverElement: String, Codable, CaseIterable, Identifiable, Sendable {
    case arrow, circle, series, badge, handle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrow: String(localized: "Arrow")
        case .circle: String(localized: "Circle")
        case .series: String(localized: "Series tag")
        case .badge: String(localized: "Badge")
        case .handle: String(localized: "@handle")
        }
    }

    var glyph: String {
        switch self {
        case .arrow: "↘"
        case .circle: "◯"
        case .series: "EP"
        case .badge: "NEW"
        case .handle: "@"
        }
    }
}

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

/// The part of a cover design that is a style: kept by "Save as my style" and given to new covers.
nonisolated struct CoverLook: Codable, Hashable, Sendable {
    var layout: CoverLayout
    var font: CoverFont
    var effect: CoverEffect
    var series: Bool
}
