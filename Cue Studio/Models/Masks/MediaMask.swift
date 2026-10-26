//
//  MediaMask.swift
//  Cue Studio
//

import Foundation

/// A mask on a photo or video over the take: only the part inside its shape shows (with Invert, the part outside), and the
/// video under it shows through the rest. It lives on the media's own place (its window, or the whole frame), so moving,
/// resizing, keyframing, tracking or animating the media takes the mask along; moving the mask never moves the picture.
/// Not the person cutout (Background › Cutout): a mask is a shape the creator draws.
nonisolated struct MediaMask: Codable, Hashable, Sendable {
    var shape: MaskShape
    var placement: MaskPlacement
    /// Shows what's outside the shape instead.
    var inverted = false

    init(shape: MaskShape, placement: MaskPlacement = MaskPlacement(), inverted: Bool = false) {
        self.shape = shape
        self.placement = placement
        self.inverted = inverted
    }

    /// A new mask of `shape` on media whose place is `aspect` (width over height) wide: a circle round on screen, a
    /// rectangle a little inside the media, a line across the middle, a band a third of it.
    static func starting(_ shape: MaskShape, onPlaceOfAspect aspect: Double) -> MediaMask {
        let ratio = aspect.isFinite && aspect > 0 ? aspect : 1
        switch shape {
        case .circle:
            // As wide as 60% of the shorter side, the same on both axes on screen.
            let side = 0.6
            return MediaMask(shape: shape, placement: MaskPlacement(
                width: ratio >= 1 ? side / ratio : side, height: ratio >= 1 ? side : side * ratio
            ))
        case .rectangle:
            return MediaMask(shape: shape, placement: MaskPlacement(width: 0.7, height: 0.7))
        case .line:
            return MediaMask(shape: shape, placement: MaskPlacement(width: 1, height: 1))
        case .band:
            return MediaMask(shape: shape, placement: MaskPlacement(width: 1, height: 0.34))
        }
    }

    /// The same mask as another shape, keeping where it is and how soft.
    func reshaped(_ next: MaskShape, onPlaceOfAspect aspect: Double) -> MediaMask {
        guard next != shape else { return self }
        var result = Self.starting(next, onPlaceOfAspect: aspect)
        result.placement.center = placement.center
        result.placement.rotation = placement.rotation
        result.placement.feather = placement.feather
        result.inverted = inverted
        if next.hasSize, shape.hasSize {
            result.placement.width = placement.width
            result.placement.height = placement.height
        }
        return result
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case shape, placement, inverted
    }

    /// Lenient: a shape from a newer version reads as a rectangle, a missing placement as the default one.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = (try? container.decodeIfPresent(MaskShape.self, forKey: .shape)) ?? .rectangle
        placement = (try? container.decodeIfPresent(MaskPlacement.self, forKey: .placement)) ?? MaskPlacement()
        inverted = (try? container.decodeIfPresent(Bool.self, forKey: .inverted)) ?? false
    }
}
