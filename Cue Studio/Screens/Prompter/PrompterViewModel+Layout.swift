//
//  PrompterViewModel+Layout.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The Selfie screen's geometry — recorded frame, safe zone, reading line and text window — worked
/// out from what the screen measured and the creator's settings, plus the Display › Layout actions.
extension PrompterViewModel {
    // MARK: - Geometry

    /// The recorded frame on screen. Follows the real preview layer once the camera runs.
    var frameGeometry: FrameGeometry {
        let camera = session.camera
        return FrameGeometry(
            sensorRect: screenMetrics.videoRect ?? FrameGeometry.sensorRect(in: screenMetrics.screen),
            aspect: camera.aspect,
            resolution: camera.resolution
        )
    }

    var readingLayout: ReadingLayout {
        let prompter = session.prompter
        return ReadingLayout(
            metrics: screenMetrics,
            isFrontCamera: session.camera.lens.isFront,
            frameRect: frameGeometry.frameRect,
            lineOffset: prompter.readingLineOffset,
            windowHeight: prompter.textWindowHeight,
            readingWidth: prompter.readingWidth
        )
    }

    /// Bottom of the Selfie text window, when there is one.
    var textWindowBottom: CGFloat? {
        hasScript && mode == .selfie ? readingLayout.windowRect.maxY : nil
    }

    // MARK: - Safe zone

    /// Chips in Display › Layout for the current frame.
    var safeZoneOptions: [SafeZoneChoice] {
        SafeZoneChoice.options(for: session.camera.aspect, rules: rules.rules)
    }

    /// The zone for this frame: the pick, else the script's platform, else Reels (9:16) or
    /// LinkedIn (4:5). None for horizontal video.
    var safeZone: SafeZoneChoice? {
        SafeZoneChoice.resolve(pick: safeZonePick, scriptPlatform: script?.platform, aspect: session.camera.aspect, rules: rules.rules)
    }

    /// The part of the frame the zone leaves clear, on screen.
    var safeZoneContentRect: CGRect? {
        guard let safeZone else { return nil }
        let geometry = frameGeometry
        switch safeZone {
        case .platform(let platform):
            guard let preset = rules.rules.safeZone(for: platform) else { return nil }
            return geometry.toScreen(preset.recommendedContentRect, in: preset.videoSize)
        case .custom:
            return geometry.toScreen(session.prompter.customSafeZone.unitContentRect, in: CGSize(width: 1, height: 1))
        }
    }

    /// Shown unless turned off.
    var showsSafeZone: Bool {
        session.camera.showsSafeZones && safeZone != nil
    }

    // MARK: - Recording bar

    /// Recording with the compact bar: the whole one is back for a few seconds after a tap.
    var showsCompactBar: Bool { isRecording && !bar.isExpanded }

    // MARK: - Layout actions

    /// Dragging the handle: the line goes to `y` (in screen points), within reach.
    func moveReadingLine(toY y: CGFloat) {
        session.prompter.readingLineOffset = readingLayout.offset(forLineAt: y)
    }

    /// ↑ / ↓ in Display: a few points at a time.
    func nudgeReadingLine(by delta: CGFloat) {
        let layout = readingLayout
        session.prompter.readingLineOffset = layout.offset(forLineAt: layout.lineY + delta)
    }

    /// Line, window, speed and safe zone back to what Cue recommends for this script. Line, speed and
    /// safe zone change for this session only; Creator Setup keeps the creator's defaults.
    func resetLayout() {
        var prompter = session.prompter
        prompter.readingLineOffset = nil
        prompter.textWindowHeight = PrompterSettings.defaultTextWindowHeight
        prompter.readingWidth = PrompterSettings.defaultReadingWidth
        prompter.speed = ReadTime.naturalSpeed
        session.prompter = prompter
        session.camera.showsSafeZones = true
        forgetSafeZonePick()
        toast.show(String(localized: "Back to recommended layout"))
    }

    /// The preview layer reports where it drew the camera image.
    func cameraImageMoved(to rect: CGRect) {
        measured { $0.videoRect = rect }
    }
}
