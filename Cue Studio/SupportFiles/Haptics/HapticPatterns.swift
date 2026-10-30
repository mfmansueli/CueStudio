//
//  HapticPatterns.swift
//  Cue Studio
//

import CoreHaptics

/// The haptics drawn in time with something on screen (Core Haptics), where one tap of `Haptics` can't follow the motion: the sparkles
/// of a new idea, an idea taking off as a star and landing as a script, an idea taken into the composer, a remote pairing and
/// connecting. Each falls back to the nearest `Haptics` tap where the iPhone has no Taptic Engine for patterns (and in the Simulator);
/// Settings › Personalize › Haptics turns them off too (`Haptics.isEnabled`).
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
    /// Whether `engine` runs now: it stops by itself when idle, and the system may stop or reset it.
    private static var isRunning = false
    /// The engine is being made off the main thread (`prewarm`).
    private static var isPreparing = false

    // MARK: - The patterns

    /// A new idea in Find inspiration: a light tick as each group of sparkles lights around the card, fading with them (`InspirationStarBurst`).
    static let sparkles: [Beat] = [
        Beat(time: 0, intensity: 0.55, sharpness: 0.9),
        Beat(time: 0.055, intensity: 0.45, sharpness: 0.95),
        Beat(time: 0.11, intensity: 0.38, sharpness: 1),
        Beat(time: 0.165, intensity: 0.3, sharpness: 1),
        Beat(time: 0.22, intensity: 0.22, sharpness: 1),
    ]

    /// An idea sent as a star (`IdeaTransitionService.riseDuration`): a firm press as it is born on the arrow, a hum that swells as it
    /// flies, and a tap as it stops and ignites (`IdeaTransitionService.ignitionTime`).
    static let takeoff: [Beat] = [
        Beat(time: 0, intensity: 0.8, sharpness: 0.5),
        Beat(time: 0.12, intensity: 0.1, sharpness: 0.25, duration: 1.1, endIntensity: 0.55),
        Beat(time: 1.24, intensity: 0.5, sharpness: 0.9),
    ]

    /// The star landing as the script's page: a soft, heavy thump and two small glints after it.
    static let landing: [Beat] = [
        Beat(time: 0, intensity: 0.7, sharpness: 0.15),
        Beat(time: 0.09, intensity: 0.3, sharpness: 0.85),
        Beat(time: 0.17, intensity: 0.18, sharpness: 0.95),
    ]

    /// The microphone starts listening: two quick light taps, as Siri does.
    static let listen: [Beat] = [
        Beat(time: 0, intensity: 0.5, sharpness: 0.7),
        Beat(time: 0.09, intensity: 0.5, sharpness: 0.7),
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

    /// Settings › Remote, "Connect a device": a firm press, then a glint as the first ring leaves the teleprompter.
    static let remoteSend: [Beat] = [
        Beat(time: 0, intensity: 0.7, sharpness: 0.5),
        Beat(time: 0.32, intensity: 0.3, sharpness: 0.9),
    ]

    /// Each of the next rings the teleprompter sends while it waits: the faintest tick, so the signal is felt and then left alone.
    static let remoteWave: [Beat] = [Beat(time: 0, intensity: 0.22, sharpness: 0.95)]

    /// A remote connected, in time with the ✓ popping on the link: a crisp tick, the click of the two meeting, and a soft settle.
    static let remoteConnect: [Beat] = [
        Beat(time: 0, intensity: 0.55, sharpness: 0.9),
        Beat(time: 0.09, intensity: 0.8, sharpness: 0.5),
        Beat(time: 0.22, intensity: 0.25, sharpness: 0.2),
    ]

    /// The remote let go: a dull drop as the link pulls back, and its echo.
    static let remoteDisconnect: [Beat] = [
        Beat(time: 0, intensity: 0.6, sharpness: 0.25),
        Beat(time: 0.12, intensity: 0.2, sharpness: 0.15),
    ]

    /// Notifications allowed in Settings › Notifications (`NotificationsSettingsView.cascade`): the bell's ring fading out as it swings,
    /// then a soft tick as each switch of From Cue lights, in time with it.
    static let notificationsOn: [Beat] = [
        Beat(time: 0, intensity: 0.6, sharpness: 0.85),
        Beat(time: 0.1, intensity: 0.34, sharpness: 0.95),
        Beat(time: 0.2, intensity: 0.16, sharpness: 1),
        Beat(time: NotificationsCascade.firstSwitch, intensity: 0.4, sharpness: 0.6),
        Beat(time: NotificationsCascade.firstSwitch + NotificationsCascade.step, intensity: 0.4, sharpness: 0.6),
        Beat(time: NotificationsCascade.firstSwitch + NotificationsCascade.step * 2, intensity: 0.4, sharpness: 0.6),
    ]

    /// One switch of Settings › Notifications turned on: a small chime, a tap and its echo.
    static let chime: [Beat] = [
        Beat(time: 0, intensity: 0.45, sharpness: 0.8),
        Beat(time: 0.08, intensity: 0.18, sharpness: 0.95),
    ]

    /// A take made the best one: a crisp tap as the star jumps and a lighter one as its sparks fly (`BestTakeSparkles`).
    static let bestTake: [Beat] = [
        Beat(time: 0, intensity: 0.55, sharpness: 0.75),
        Beat(time: 0.09, intensity: 0.3, sharpness: 0.95),
    ]

    /// Ultra AI taken from the dock's invitation (`UltraMotion`): a glint as the ✦ leaves the line, a faint hum as it flies, a crisp tap as the
    /// writer chip lights where it lands, and a soft settle as the ring goes out.
    static let ultraOn: [Beat] = [
        Beat(time: 0, intensity: 0.4, sharpness: 0.9),
        Beat(time: 0.05, intensity: 0.06, sharpness: 0.4, duration: UltraMotion.hop - 0.08, endIntensity: 0.28),
        Beat(time: UltraMotion.hop, intensity: 0.65, sharpness: 0.75),
        Beat(time: UltraMotion.hop + 0.1, intensity: 0.22, sharpness: 0.25),
    ]

    /// Ultra AI picked straight on the chip, or allowed from My Cue Voice: a crisp tap as the ✦ pops, a glint for each spark it sends out
    /// (`UltraChipSparks`), a swell while Cue's light goes round the chip (`DockChipLight`) and a soft settle as it fades.
    static let ultraIgnite: [Beat] = [
        Beat(time: 0, intensity: 0.65, sharpness: 0.75),
        Beat(time: 0.06, intensity: 0.32, sharpness: 1),
        Beat(time: 0.12, intensity: 0.24, sharpness: 1),
        Beat(time: 0.18, intensity: 0.16, sharpness: 1),
        Beat(time: 0.22, intensity: 0.05, sharpness: 0.3, duration: DockChipLight.duration - 0.55, endIntensity: 0.2),
        Beat(time: DockChipLight.duration - 0.3, intensity: 0.22, sharpness: 0.25),
    ]

    /// Apple Intelligence picked back on the writer chip (`DockChipLight`): a light tap as its symbol bounces, a soft swell while its light goes
    /// round the chip, and a faint settle as the light fades.
    static let appleOn: [Beat] = [
        Beat(time: 0, intensity: 0.35, sharpness: 0.5),
        Beat(time: 0.04, intensity: 0.06, sharpness: 0.2, duration: DockChipLight.duration - 0.4, endIntensity: 0.22),
        Beat(time: DockChipLight.duration - 0.3, intensity: 0.2, sharpness: 0.2),
    ]

    // MARK: - Playing

    static func playSparkles() { play(sparkles, fallback: Haptics.selection) }
    static func playTakeoff() { play(takeoff, fallback: Haptics.medium) }
    static func playLanding() { play(landing, fallback: Haptics.success) }
    static func playCommit() { play(commit, fallback: Haptics.light) }
    static func playFinish() { play(finish, fallback: Haptics.soft) }
    static func playListen() { play(listen, fallback: Haptics.selection) }
    static func playRemoteSend() { play(remoteSend, fallback: Haptics.medium) }
    static func playRemoteWave() { play(remoteWave, fallback: Haptics.selection) }
    static func playRemoteConnect() { play(remoteConnect, fallback: Haptics.success) }
    static func playRemoteDisconnect() { play(remoteDisconnect, fallback: Haptics.medium) }
    static func playNotificationsOn() { play(notificationsOn, fallback: Haptics.success) }
    static func playChime() { play(chime, fallback: Haptics.light) }
    static func playBestTake() { play(bestTake, fallback: Haptics.light) }
    static func playUltraOn() { play(ultraOn, fallback: Haptics.success) }
    static func playUltraIgnite() { play(ultraIgnite, fallback: Haptics.light) }
    static func playAppleOn() { play(appleOn, fallback: Haptics.soft) }

    /// The writer chip's ✦ landing on the send arrow, which turns Ultra AI's: a crisp tap as it lands and a short glow fading under the pop.
    static let ultraSendCharged: [Beat] = [
        Beat(time: 0, intensity: 0.55, sharpness: 0.8),
        Beat(time: 0.05, intensity: 0.2, sharpness: 0.3, duration: 0.25, endIntensity: 0),
    ]

    static func playUltraSendCharged() { play(ultraSendCharged, fallback: Haptics.rigid) }

    /// Ultra AI's script there (`UltraWaitScene`'s finish): a hum that swells as the moons and the dust spiral into the star, a firm tap as it
    /// flashes, and a soft settle as the wave of light runs out.
    static let ultraFinish: [Beat] = [
        Beat(time: 0, intensity: 0.06, sharpness: 0.3, duration: IdeaTransitionService.ultraFlashTime - 0.02, endIntensity: 0.6),
        Beat(time: IdeaTransitionService.ultraFlashTime, intensity: 0.85, sharpness: 0.6),
        Beat(time: IdeaTransitionService.ultraFlashTime + 0.12, intensity: 0.28, sharpness: 0.2),
    ]

    static func playUltraFinish() { play(ultraFinish, fallback: Haptics.medium) }

    /// A network picked on the platform chip (its logo flips once round, `IdeaCardChip.logoFlip`): a firm tap as it leaves, a light tick as it
    /// turns edge-on, and a soft landing as it pops back, while the network's light goes round the chip.
    static let platformOn: [Beat] = [
        Beat(time: 0, intensity: 0.5, sharpness: 0.6),
        Beat(time: 0.14, intensity: 0.18, sharpness: 0.9),
        Beat(time: 0.42, intensity: 0.32, sharpness: 0.35),
    ]

    static func playPlatformOn() { play(platformOn, fallback: Haptics.soft) }

    /// Makes the engine and starts it off the main thread, ahead of the first pattern: made and started on the spot, the takeoff held the
    /// first idea's star back by ~50 ms after each launch (measured on an iPhone 15 Pro, 26/10/2026). Haptics only (no audio), so it never
    /// touches the microphone's session, and it stops by itself when idle.
    static func prewarm() {
        guard engine == nil, !isPreparing, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        isPreparing = true
        Task.detached(priority: .utility) {
            let made = try? CHHapticEngine()
            made?.playsHapticsOnly = true
            made?.isAutoShutdownEnabled = true
            let isStarted = (try? await made?.start()) != nil
            let prepared = PreparedEngine(engine: made)
            await MainActor.run { adopt(prepared.engine, isStarted: isStarted) }
        }
    }

    /// An engine made off the main thread, handed to it: nothing else touches it on the way.
    private nonisolated struct PreparedEngine: @unchecked Sendable {
        let engine: CHHapticEngine?
    }

    private static func adopt(_ made: CHHapticEngine?, isStarted: Bool) {
        isPreparing = false
        guard engine == nil, let made else { return }
        made.stoppedHandler = { _ in Task { @MainActor in isRunning = false } }
        made.resetHandler = { Task { @MainActor in isRunning = false } }
        engine = made
        isRunning = isStarted
    }

    /// Plays `beats` now when the engine runs. Never waits for it on the main thread: one stopped (idle, or by the system) starts again off
    /// it and the pattern plays as soon as it runs; before the first one is made, the nearest tap plays instead.
    private static func play(_ beats: [Beat], fallback: @escaping @MainActor @Sendable () -> Void) {
        guard Haptics.isEnabled else { return }
        guard let engine else {
            fallback()
            prewarm()
            return
        }
        guard isRunning else {
            engine.start { error in
                Task { @MainActor in
                    guard error == nil else { return fallback() }
                    isRunning = true
                    playNow(beats, fallback: fallback)
                }
            }
            return
        }
        playNow(beats, fallback: fallback)
    }

    private static func playNow(_ beats: [Beat], fallback: @MainActor () -> Void) {
        guard let engine, let pattern = try? CHHapticPattern(events: beats.map(event), parameterCurves: curves(for: beats)),
              let player = try? engine.makePlayer(with: pattern) else {
            fallback()
            return
        }
        do {
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // It had stopped without saying so: the next pattern starts it again first.
            isRunning = false
            fallback()
        }
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
