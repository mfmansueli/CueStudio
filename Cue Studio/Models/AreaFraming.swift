//
//  AreaFraming.swift
//  Cue Studio
//

import Foundation

/// How a picture sits in its area of a split screen (`SplitPlacement.place`): Fill or Fit, zoomed in from there, and moved so
/// `center` (a point of the picture, as fractions of it from the top left) is in the middle of the area as far as the picture
/// reaches. It doesn't depend on the area's shape, so it carries over when the layout changes; and it is apart from how the
/// main video fills the whole frame (Format), so going back to full screen never takes the split's zoom along.
nonisolated struct AreaFraming: Codable, Hashable, Sendable {
    /// Zoom over Fill or Fit: never smaller than the fit chosen, at most four times it.
    static let zoomRange: ClosedRange<Double> = 1...4

    var fit: AreaFit = .fill
    var zoom: Double = 1
    var center: OverlayPoint = .center

    init(fit: AreaFit = .fill, zoom: Double = 1, center: OverlayPoint = .center) {
        self.fit = fit
        self.zoom = zoom
        self.center = center
    }

    /// `zoom` inside its range.
    var clampedZoom: Double {
        min(max(zoom.isFinite ? zoom : 1, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
    }

    /// `center` inside the picture.
    var clampedCenter: OverlayPoint {
        OverlayPoint(x: min(max(center.x.isFinite ? center.x : 0.5, 0), 1), y: min(max(center.y.isFinite ? center.y : 0.5, 0), 1))
    }

    private enum CodingKeys: String, CodingKey {
        case fit, zoom, center
    }

    /// Lenient: a value from a newer version reads as the default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fit = (try? container.decodeIfPresent(AreaFit.self, forKey: .fit)) ?? .fill
        zoom = (try? container.decodeIfPresent(Double.self, forKey: .zoom)) ?? 1
        center = (try? container.decodeIfPresent(OverlayPoint.self, forKey: .center)) ?? .center
    }
}
