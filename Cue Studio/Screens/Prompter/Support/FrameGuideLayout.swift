//
//  FrameGuideLayout.swift
//  Cue Studio
//

import CoreGraphics

/// Letterbox bars that show the chosen frame over a full-screen portrait preview.
nonisolated enum FrameGuideLayout {
    /// Height of each bar (top and bottom). The preview fills the screen with the 9:16 sensor image,
    /// so the frame is measured against the sensor width as it appears on screen, not the screen width.
    static func barHeight(for aspect: AspectRatio, in size: CGSize) -> CGFloat {
        guard aspect != .portrait, size.width > 0, size.height > 0 else { return 0 }
        let sensorWidthOnScreen = max(size.width, size.height * 9 / 16)
        let frameHeight = sensorWidthOnScreen / aspect.widthOverHeight
        return max(0, (size.height - frameHeight) / 2)
    }
}
