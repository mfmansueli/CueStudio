//
//  CoverComposition+Legacy.swift
//  Cue Studio
//

import Foundation

/// A cover made before Cover Studio, as a composition, when it's opened there: the nearest template, with its highlighted word,
/// effect, place and graphics where they were. Until then it keeps drawing its own way; nothing changes by opening Cue.
nonisolated extension CoverComposition {
    init(legacy cover: VideoCover) {
        guard let design = cover.design else {
            // A plain title (before the v26 design): white words where the title was.
            self = .make(.opinion, title: cover.title)
            effect = .clean
            title.center = OverlayPoint(x: 0.5, y: cover.titleY).clamped
            title.highlights = []
            return
        }
        let template: CoverTemplate = switch design.layout {
        case .hook: .opinion
        case .number: .list
        case .kicker: .series
        case .question: .educational
        case .beforeAfter: .beforeAfter
        }
        self = .make(template, title: cover.title, handle: design.handle, episode: design.episode)
        title.font = design.font
        title.alignment = .center
        title.center = OverlayPoint(x: 0.5, y: design.layout.textTop + 0.08 + (cover.titleY - 0.2)).clamped
        let count = CoverWords.words(in: cover.title).count
        title.highlights = design.layout == .number ? [] : design.highlight(in: count).map { [$0] } ?? []
        title.highlightStyle = .box
        title.background = design.layout == .question ? .box : .shadow
        title.kicker = design.layout == .kicker ? design.kicker(firstWord: nil).trimmingCharacters(in: CharacterSet(charactersIn: " ·")) : ""
        effect = design.effect
        effectAmount = design.effect == .dim ? 0.38 : 0.5
        items = design.elements.sorted { $0.rawValue < $1.rawValue }.compactMap { element in
            switch element {
            case .arrow: CoverItem(kind: .arrow, center: OverlayPoint(x: 0.23, y: 0.65))
            case .circle: CoverItem(kind: .circle, center: OverlayPoint(x: 0.66, y: 0.65), rotation: -8 * .pi / 180)
            case .series: CoverItem(kind: .tag, center: OverlayPoint(x: 0.16, y: 0.06), scale: 0.7, color: .yellow, text: design.episodeLabel)
            case .badge: CoverItem(kind: .tag, center: OverlayPoint(x: 0.85, y: 0.06), scale: 0.7, color: .red, text: "NEW")
            case .handle: design.handle.isEmpty ? nil : CoverItem(kind: .handle, center: OverlayPoint(x: 0.5, y: 0.75), text: design.handle)
            }
        }
    }
}
