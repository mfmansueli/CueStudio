//
//  FrameGeometry.swift
//  Cue Studio
//

import CoreGraphics

/// The recorded frame on screen, and the one converter from VideoSpace (pixels of the exported
/// frame) to ScreenSpace (points on this screen). Every overlay on the camera — the frame mask and
/// the safe zone — goes through it, never through numbers drawn for one iPhone.
///
/// The camera records the whole portrait sensor (9:16); 4:5, 1:1 and 16:9 are a centered crop of it
/// on export (`CropMath`). So the preview shows the sensor image as it is, and the frame is that
/// image cropped the same way. Nothing drawn on screen is ever part of the video.
nonisolated struct FrameGeometry: Equatable, Sendable {
    /// The sensor's aspect (width / height) in portrait.
    static let sensorAspect: CGFloat = 9.0 / 16.0
    /// The sensor image sits a little above the middle of the screen, as in the design (centered at
    /// 401 of 874 pt), so the toolbar at the bottom covers less of it.
    static let sensorCenter: CGFloat = 401.0 / 874.0

    /// Where the sensor image sits on screen: what the preview layer shows.
    let sensorRect: CGRect
    /// The part of it that ends up in the exported file.
    let frameRect: CGRect
    /// Pixel size of the exported frame (1080 × 1920 for 9:16 at 1080p, 1080 × 1350 for 4:5).
    let videoSize: CGSize

    init(sensorRect: CGRect, aspect: AspectRatio, resolution: VideoResolution) {
        self.sensorRect = sensorRect
        frameRect = Self.centeredCrop(of: sensorRect, aspect: aspect.widthOverHeight)
        let sensorPixels = CGSize(width: resolution.landscapeHeight, height: resolution.landscapeWidth)
        videoSize = CropMath.centeredCrop(in: sensorPixels, aspect: aspect.widthOverHeight).size
    }

    /// Where the preview goes on a screen: as wide as the screen and 16:9 tall (on wider screens,
    /// as tall as the screen), a little above the middle and never past an edge. The real preview
    /// layer then reports where the image actually landed (`SelfieScreenMetrics.videoRect`).
    static func sensorRect(in screen: CGSize) -> CGRect {
        guard screen.width > 0, screen.height > 0 else { return .zero }
        var size = CGSize(width: screen.width, height: screen.width / sensorAspect)
        if size.height > screen.height {
            size = CGSize(width: screen.height * sensorAspect, height: screen.height)
        }
        let top = min(max(0, screen.height * sensorCenter - size.height / 2), screen.height - size.height)
        return CGRect(x: (screen.width - size.width) / 2, y: top, width: size.width, height: size.height)
    }

    /// A rect in VideoSpace on screen. `space` is the frame size the rect was measured on (a
    /// preset's 1080 × 1920, say); by default, the exported frame.
    func toScreen(_ rect: CGRect, in space: CGSize? = nil) -> CGRect {
        let space = space ?? videoSize
        guard space.width > 0, space.height > 0 else { return .zero }
        let sx = frameRect.width / space.width
        let sy = frameRect.height / space.height
        return CGRect(
            x: frameRect.minX + rect.minX * sx,
            y: frameRect.minY + rect.minY * sy,
            width: rect.width * sx,
            height: rect.height * sy
        )
    }

    /// Largest centered rect with `aspect` (width / height) inside `rect`, like the export crop.
    private static func centeredCrop(of rect: CGRect, aspect: CGFloat) -> CGRect {
        guard rect.width > 0, rect.height > 0, aspect > 0 else { return rect }
        if rect.width / rect.height > aspect {
            let width = rect.height * aspect
            return CGRect(x: rect.midX - width / 2, y: rect.minY, width: width, height: rect.height)
        }
        let height = rect.width / aspect
        return CGRect(x: rect.minX, y: rect.midY - height / 2, width: rect.width, height: height)
    }
}
