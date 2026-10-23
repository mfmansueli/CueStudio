//
//  CoverItem.swift
//  Cue Studio
//

import Foundation

/// One graphic on a cover, as the creator placed it: where its center is, how big and how turned, its color and, for a tag
/// or the handle, its words. A cover's items are kept in drawing order, the first under the others.
nonisolated struct CoverItem: Codable, Hashable, Identifiable, Sendable {
    static let scaleRange: ClosedRange<Double> = 0.3...3

    var id = UUID()
    var kind: CoverItemKind
    /// Fractions of the cover from the top left.
    var center: OverlayPoint
    /// Times its base size (`CoverItemKind.baseWidth`).
    var scale: Double = 1
    /// Radians, clockwise.
    var rotation: Double = 0
    var color: OverlayColor
    /// A tag's words, or the handle (without the "@").
    var text = ""
    /// Put there by the template and not changed since: picking another template replaces it.
    var isFromTemplate = false

    init(
        kind: CoverItemKind, center: OverlayPoint, scale: Double = 1, rotation: Double = 0, color: OverlayColor? = nil, text: String = "",
        isFromTemplate: Bool = false
    ) {
        self.isFromTemplate = isFromTemplate
        self.kind = kind
        self.center = center
        self.scale = scale
        self.rotation = rotation
        self.color = color ?? kind.defaultColor
        self.text = text
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, center, scale, rotation, color, text, isFromTemplate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(CoverItemKind.self, forKey: .kind)
        center = try container.decode(OverlayPoint.self, forKey: .center)
        scale = (try? container.decodeIfPresent(Double.self, forKey: .scale)) ?? 1
        rotation = (try? container.decodeIfPresent(Double.self, forKey: .rotation)) ?? 0
        color = container.decodeChoice(OverlayColor.self, forKey: .color, unknown: kind.defaultColor, report: decoder.decodingReport)
            ?? kind.defaultColor
        text = (try? container.decodeIfPresent(String.self, forKey: .text)) ?? ""
        isFromTemplate = (try? container.decodeIfPresent(Bool.self, forKey: .isFromTemplate)) ?? false
    }

    /// Kept on the cover and in its ranges.
    var clamped: CoverItem {
        var item = self
        item.center = center.clamped
        item.scale = min(max(scale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
        item.rotation = rotation.isFinite ? remainder(rotation, 2 * .pi) : 0
        return item
    }
}
