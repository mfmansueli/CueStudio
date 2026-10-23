//
//  CoverComposition.swift
//  Cue Studio
//

import Foundation

/// A cover made in Cover Studio: the template it started from, how its picture is framed, how its title is set, the graphics
/// on it (in drawing order), what is done to the picture (and how strongly), and for a before/after the second picture.
/// Optional on `VideoCover`: covers made before it keep their v26 design (`CoverDesign`) or their plain title until they're
/// opened in Cover Studio (`CoverComposition(legacy:)`).
nonisolated struct CoverComposition: Codable, Hashable, Sendable {
    var template: CoverTemplate
    var framing = CoverFraming()
    var title = CoverTitleStyle()
    var items: [CoverItem] = []
    var effect: CoverEffect = .clean
    /// How strong Dim or Blur is, 0 to 1.
    var effectAmount = 0.5
    /// The before/after's second half. Kept when another template is tried (so coming back finds it), drawn only by the
    /// before/after (`activeSplit`).
    var split: CoverSplit?

    /// The second half as drawn: the before/after's; nil for every other template.
    var activeSplit: CoverSplit? { template == .beforeAfter ? split : nil }

    init(template: CoverTemplate) {
        self.template = template
    }

    private enum CodingKeys: String, CodingKey {
        case template, framing, title, items, effect, effectAmount, split
    }

    /// A part that can't be read keeps where a new cover starts, and a graphic a newer version added is left out (`LossyList`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let report = decoder.decodingReport
        template = (try? container.decodeIfPresent(CoverTemplate.self, forKey: .template)) ?? .educational
        framing = container.decodeLenient(CoverFraming.self, forKey: .framing, report: report) ?? CoverFraming()
        title = container.decodeLenient(CoverTitleStyle.self, forKey: .title, report: report) ?? CoverTitleStyle()
        items = container.decodeLossy([CoverItem].self, forKey: .items)
        effect = (try? container.decodeIfPresent(CoverEffect.self, forKey: .effect)) ?? .clean
        effectAmount = (try? container.decodeIfPresent(Double.self, forKey: .effectAmount)) ?? 0.5
        split = container.decodeLenient(CoverSplit.self, forKey: .split, report: report)
    }

    /// The item with `id`.
    func item(_ id: UUID) -> CoverItem? {
        items.first { $0.id == id }
    }
}
