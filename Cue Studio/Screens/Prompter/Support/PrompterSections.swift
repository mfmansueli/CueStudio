//
//  PrompterSections.swift
//  Cue Studio
//

import Foundation

/// The script as the sections the creator moves through while reading (Hook, Body, CTA… as its format has them),
/// for the rail beside the text and the label under it. The same split as the script page's Shaped view.
nonisolated struct PrompterSections: Equatable, Sendable {
    struct Marker: Equatable, Sendable {
        let label: String
        /// Index of the section's first paragraph.
        let firstParagraph: Int
    }

    let markers: [Marker]

    /// A rail needs at least two stars to say anything.
    var isMeaningful: Bool { markers.count >= 2 }

    init(markers: [Marker]) {
        self.markers = markers
    }

    init(text: String, structure: ScriptStructure, speed: Double) {
        let shape = ScriptShape(text: text, structure: structure, speed: speed, suggestsCTA: false)
        markers = shape.sections.filter { !$0.isMissingCTA }.map { Marker(label: $0.label, firstParagraph: $0.firstParagraph) }
    }

    /// The section that holds `paragraph`.
    func index(atParagraph paragraph: Int) -> Int {
        markers.lastIndex { $0.firstParagraph <= paragraph } ?? 0
    }

    /// "HOOK · 1 OF 3".
    func title(at index: Int) -> String {
        guard markers.indices.contains(index) else { return "" }
        return String(localized: "\(markers[index].label.uppercased()) · \(index + 1) OF \(markers.count)")
    }
}

extension PrompterViewModel {
    /// The paragraph on the reading line now, from where the text has scrolled to.
    var readingParagraph: Int {
        let offset = engine.offset + lineHeight * 0.5
        return paragraphFrames.lastIndex { $0.lowerBound <= offset } ?? 0
    }

    /// The script's sections, for the rail.
    func makeSections() -> PrompterSections {
        guard let script else { return PrompterSections(markers: []) }
        return PrompterSections(text: script.text, structure: script.structure, speed: session.prompter.speed)
    }
}
