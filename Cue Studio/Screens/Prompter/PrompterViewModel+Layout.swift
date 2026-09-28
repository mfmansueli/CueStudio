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
        let camera = preferences.camera
        return FrameGeometry(
            sensorRect: screenMetrics.videoRect ?? FrameGeometry.sensorRect(in: screenMetrics.screen),
            aspect: camera.aspect,
            resolution: camera.resolution
        )
    }

    var readingLayout: ReadingLayout {
        let prompter = preferences.prompter
        return ReadingLayout(
            metrics: screenMetrics,
            isFrontCamera: preferences.camera.lens.isFront,
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
        SafeZoneChoice.options(for: preferences.camera.aspect, rules: rules.rules)
    }

    /// The zone for this frame: the pick, else the script's platform, else Reels (9:16) or
    /// LinkedIn (4:5). None for horizontal video.
    var safeZone: SafeZoneChoice? {
        SafeZoneChoice.resolve(pick: safeZonePick, scriptPlatform: script?.platform, aspect: preferences.camera.aspect, rules: rules.rules)
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
            return geometry.toScreen(preferences.prompter.customSafeZone.unitContentRect, in: CGSize(width: 1, height: 1))
        }
    }

    /// Shown unless turned off or the controls are hidden while recording.
    var showsSafeZone: Bool {
        preferences.camera.showsSafeZones && !hidesControls && safeZone != nil
    }

    // MARK: - Controls and tip

    /// Recording with only the text, the reading line, the clock and a stop button.
    var hidesControls: Bool { isRecording && controlsHidden }

    /// "Don't read the text. Talk to the line." — once, until tapped, played or moved.
    var showsReadingLineTip: Bool {
        !preferences.hasSeenReadingLineTip && hasScript && mode == .selfie && reviewingTake == nil
            && !isPlaying && !isRecording && sheet == nil && countdown == nil
    }

    func dismissReadingLineTip() {
        guard !preferences.hasSeenReadingLineTip else { return }
        preferences.hasSeenReadingLineTip = true
    }

    // MARK: - Layout actions

    /// Dragging the handle: the line goes to `y` (in screen points), within reach.
    func moveReadingLine(toY y: CGFloat) {
        preferences.prompter.readingLineOffset = readingLayout.offset(forLineAt: y)
        dismissReadingLineTip()
    }

    /// ↑ / ↓ in Display: a few points at a time.
    func nudgeReadingLine(by delta: CGFloat) {
        let layout = readingLayout
        preferences.prompter.readingLineOffset = layout.offset(forLineAt: layout.lineY + delta)
    }

    /// Line, window, speed and safe zone back to what Cue recommends for this script.
    func resetLayout() {
        var prompter = preferences.prompter
        prompter.readingLineOffset = nil
        prompter.textWindowHeight = PrompterSettings.defaultTextWindowHeight
        prompter.readingWidth = preset?.readingWidth ?? PrompterSettings().readingWidth
        prompter.speed = ReadTime.naturalSpeed
        prompter.hidesControlsWhileRecording = false
        preferences.prompter = prompter
        preferences.camera.showsSafeZones = true
        forgetSafeZonePick()
        toast.show(String(localized: "Back to recommended layout"))
    }

    /// The preview layer reports where it drew the camera image.
    func cameraImageMoved(to rect: CGRect) {
        measured { $0.videoRect = rect }
    }
}
