//
//  CoverComposition+Templates.swift
//  Cue Studio
//

import Foundation

/// The templates as compositions. What a template sets is a style; what the creator wrote (the title, the kicker they typed,
/// the before/after's second picture and labels, their graphics' words) is carried over when another template is picked
/// (`applying(_:)`), so trying templates never loses work.
nonisolated extension CoverComposition {
    /// A new cover in `template` for a title, with the creator's handle for the series and the key word highlighted.
    static func make(_ template: CoverTemplate, title: String, handle: String = "", episode: Int = 1) -> CoverComposition {
        var composition = CoverComposition(template: template)
        var style = CoverTitleStyle()
        let key = CoverWords.keyWord(in: title).map { Set([$0]) } ?? []
        switch template {
        case .educational:
            style.font = .grotesk
            style.size = 0.085
            style.alignment = .leading
            style.center = OverlayPoint(x: 0.5, y: 0.78)
            style.width = 0.86
            style.uppercase = false
            style.highlightStyle = .box
            style.highlights = key
            style.background = .shadow
            composition.effect = .clean
        case .opinion:
            style.font = .anton
            style.size = 0.16
            style.center = OverlayPoint(x: 0.5, y: 0.28)
            style.width = 0.9
            style.highlightStyle = .color
            style.highlights = key
            style.background = .outline
            composition.effect = .dim
            composition.effectAmount = 0.35
        case .list:
            style.font = .anton
            style.size = 0.12
            style.center = OverlayPoint(x: 0.5, y: 0.34)
            style.width = 0.88
            style.showsNumber = true
            style.highlightStyle = .color
            style.background = .shadow
            composition.effect = .clean
        case .demo:
            style.font = .system
            style.size = 0.075
            style.center = OverlayPoint(x: 0.5, y: 0.14)
            style.width = 0.88
            style.background = .box
            style.boxColor = .offBlack
            style.highlightStyle = .color
            style.highlights = key
            composition.items = [
                CoverItem(kind: .circle, center: OverlayPoint(x: 0.56, y: 0.56), rotation: -0.14, isFromTemplate: true),
                CoverItem(kind: .arrow, center: OverlayPoint(x: 0.24, y: 0.72), rotation: -0.35, isFromTemplate: true),
            ]
        case .beforeAfter:
            style.font = .anton
            style.size = 0.075
            style.center = OverlayPoint(x: 0.5, y: 0.1)
            style.width = 0.9
            style.background = .box
            style.boxColor = .offBlack
            style.highlightStyle = .color
            composition.split = CoverSplit()
        case .series:
            style.font = .anton
            style.size = 0.13
            style.center = OverlayPoint(x: 0.5, y: 0.66)
            style.width = 0.88
            style.highlightStyle = .box
            style.highlights = key
            style.background = .shadow
            style.kicker = Self.episodeKicker(episode)
            if !handle.isEmpty {
                composition.items = [CoverItem(kind: .handle, center: OverlayPoint(x: 0.5, y: 0.9), scale: 0.8, text: handle, isFromTemplate: true)]
            }
        }
        composition.title = style
        return composition
    }

    /// "EP 03".
    static func episodeKicker(_ episode: Int) -> String {
        String(localized: "EP \(String(format: "%02d", max(0, episode)))", comment: "Episode tag on a series cover")
    }

    /// This cover in `template`: the template's look, with what the creator made kept (where it applies): the highlighted
    /// words, a kicker they wrote, the picture's framing, the before/after's second picture and labels, and their graphics
    /// (the template's own replace only the ones the previous template put there and nobody changed).
    func applying(_ template: CoverTemplate, title: String, handle: String = "", episode: Int = 1) -> CoverComposition {
        var next = Self.make(template, title: title, handle: handle, episode: episode)
        next.framing = framing
        if !title.isEmpty, !self.title.highlights.isEmpty, template != .list { next.title.highlights = self.title.highlights }
        if !self.title.kicker.isEmpty, template == .series || self.template != .series { next.title.kicker = self.title.kicker }
        if let split { next.split = split }
        let kept = items.filter { !$0.isFromTemplate }
        next.items += kept
        return next
    }

    /// The cover's look without what it says or shows: what "Save as my style" keeps.
    var style: CoverStyle {
        CoverStyle(composition: self)
    }
}
