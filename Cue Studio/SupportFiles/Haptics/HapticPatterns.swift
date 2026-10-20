//
//  HapticPatterns.swift
//  Cue Studio
//

import CoreHaptics

/// The haptics drawn in time with something on screen (Core Haptics), where one tap of `Haptics` can't follow the motion: the sparkles
/// of a new idea, an idea taking off as a star and landing as a script, an idea taken into the composer. Each falls back to the nearest
/// `Haptics` tap where the iPhone has no Taptic Engine for patterns (and in the Simulator); Settings › Personalize › Haptics turns them off
/// too (`Haptics.isEnabled`).
@MainActor
enum HapticPatterns {
    /// One moment of a pattern: a tap (`duration` nil) or a hum, at `time` seconds, `intensity` and `sharpness` from 0 to 1. A hum may
    /// swell from `intensity` to `endIntensity` over its duration.
    struct Beat: Equatable {
        var time: TimeInterval
        var intensity: Float
        var sharpness: Float
        var duration: TimeInterval?
        var endIntensity: Float?
    }

    private static var engine: CHHapticEngine?

    // MARK: - The patterns

    /// A new idea in Find inspiration: a light tick as each group of sparkles lights around the card, fading with them (`InspirationStarBurst`).
    static let sparkles: [Beat] = [
        Beat(time: 0, intensity: 0.55, sharpness: 0.9),
        Beat(time: 0.055, intensity: 0.45, sharpness: 0.95),
        Beat(time: 0.11, intensity: 0.38, sharpness: 1),
        Beat(time: 0.165, intensity: 0.3, sharpness: 1),
        Beat(time: 0.22, intensity: 0.22, sharpness: 1),
    ]

    /// An idea sent as a star (`IdeaTransitionService.riseDuration`): a firm press, a hum that swells as the star rises, and a tap as it
    /// stops and ignites.
    static let takeoff: [Beat] = [
        Beat(time: 0, intensity: 0.8, sharpness: 0.5),
        Beat(time: 0.05, intensity: 0.1, sharpness: 0.25, duration: 0.97, endIntensity: 0.55),
        Beat(time: 1.04, intensity: 0.5, sharpness: 0.9),
    ]

    /// The star landing as the script's page: a soft, heavy thump and two small glints after it.
    static let landing: [Beat] = [
        Beat(time: 0, intensity: 0.7, sharpness: 0.15),
        Beat(time: 0.09, intensity: 0.3, sharpness: 0.85),
        Beat(time: 0.17, intensity: 0.18, sharpness: 0.95),
    ]

    /// A script written into its page: two soft taps, the second lighter, as the words settle.
    static let finish: [Beat] = [
        Beat(time: 0, intensity: 0.45, sharpness: 0.3),
        Beat(time: 0.13, intensity: 0.28, sharpness: 0.5),
    ]

    /// "Start with it": a firm press, then a soft one as the sheet goes and the idea drops into the composer.
    static let commit: [Beat] = [
        Beat(time: 0, intensity: 0.75, sharpness: 0.45),
        Beat(time: 0.3, intensity: 0.35, sharpness: 0.2),
    ]

    // MARK: - Playing

    static func playSparkles() { play(sparkles, fallback: Haptics.selection) }
    static func playTakeoff() { play(takeoff, fallback: Haptics.medium) }
    static func playLanding() { play(landing, fallback: Haptics.success) }
    static func playCommit() { play(commit, fallback: Haptics.light) }
    static func playFinish() { play(finish, fallback: Haptics.soft) }

    private static func play(_ beats: [Beat], fallback: () -> Void) {
        guard Haptics.isEnabled else { return }
        guard let engine = readyEngine(), let pattern = try? CHHapticPattern(events: beats.map(event), parameterCurves: curves(for: beats)),
              let player = try? engine.makePlayer(with: pattern) else {
            fallback()
            return
        }
        do {
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            fallback()
        }
    }

    /// The engine, started; nil where the hardware can't play patterns. Haptics only (no audio), so it never touches the microphone's
    /// session, and it stops by itself when idle.
    private static func readyEngine() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if engine == nil {
            guard let created = try? CHHapticEngine() else { return nil }
            created.playsHapticsOnly = true
            created.isAutoShutdownEnabled = true
            created.resetHandler = { [weak created] in try? created?.start() }
            engine = created
        }
        guard let engine else { return nil }
        do {
            try engine.start()
        } catch {
            return nil
        }
        return engine
    }

    private static func event(_ beat: Beat) -> CHHapticEvent {
        let parameters = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: beat.intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.sharpness),
        ]
        if let duration = beat.duration {
            return CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: beat.time, duration: duration)
        }
        return CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: beat.time)
    }

    /// A hum that swells: its intensity scaled from 1 to `endIntensity / intensity` over its length.
    private static func curves(for beats: [Beat]) -> [CHHapticParameterCurve] {
        beats.compactMap { beat in
            guard let duration = beat.duration, let end = beat.endIntensity, beat.intensity > 0 else { return nil }
            return CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 1),
                    CHHapticParameterCurve.ControlPoint(relativeTime: duration, value: min(1, end / beat.intensity)),
                ],
                relativeTime: beat.time
            )
        }
    }
}
