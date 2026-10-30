//
//  IdeaTransitionService.swift
//  Cue Studio
//

import CoreGraphics
import Foundation
import os

/// The star that is the transition from an idea to its script (v30 · 09 §8, `motion/README.md`). The idea's star is born on the arrow and
/// rises to the middle of the screen (1.32 s), Scripts dims behind it, and while Apple Intelligence writes it says what is happening —
/// "Drafting in your voice", the idea and a phrase that changes every 1.6 s. It lasts at least 3.0 s from the tap (longer if the AI needs
/// it); when the script is ready the cover goes solid (0.3 s), the ring opens onto the page (0.8 s) and the star lands as the caret, where
/// the words begin. Cancel, or an error, leaves the way it came: the star falls 40 pt (0.3 s), the overlay fades (0.22 s), and the idea is
/// still in the field. While the star covers the app, the app is a still picture of the moment of the tap (`showsBackdrop`), so the page
/// opened under it is never seen arriving. This is the clock and the state; `StarTransitionOverlay` draws it.
@MainActor
@Observable
final class IdeaTransitionService {
    enum Phase: Equatable {
        case idle
        /// The star is born on the arrow and rises to the middle (`riseDuration`).
        case rising
        /// The AI is writing: halo, particles, the phrases and Cancel.
        case waiting
        /// The script is ready: the finish phrase, the ring and the crossfade into the page.
        case revealing
        /// Cancel or an error: the star falls and the overlay fades.
        case leaving
    }

    // MARK: - Timings (09 §8)

    /// The star is born on the arrow before it leaves: a beat the eye catches (anticipation), long enough for the page to open under the
    /// still picture before anything moves.
    static let launchDelay: TimeInterval = 0.12
    /// The flight from the arrow to the middle. Slower than the board's 0.6 s (the owner's calls, 20/10 and 25/10/2026: the idea's stream of
    /// light and the star's rise are meant to be seen, and the script is being written all the while).
    static let flightDuration: TimeInterval = 1.2
    /// From the tap to the star resting in the middle.
    static var riseDuration: TimeInterval { launchDelay + flightDuration }
    /// When the star catches light where it stops (the flash, the ring and the takeoff haptic's last tap), from the tap: just before the
    /// flight's long ease-out ends.
    static var ignitionTime: TimeInterval { launchDelay + flightDuration * 0.935 }
    /// The shortest the transition lasts from the tap, even when the AI answers sooner.
    static let minimumDuration: TimeInterval = 3.0
    /// Seconds each phrase stays.
    static let phraseInterval: TimeInterval = 1.6
    /// The overlay darkens to cover the screen before the ring opens.
    static let coverDuration: TimeInterval = 0.3
    /// Ultra AI's finish is longer than the cover (the owner's call, 30/10/2026): its moons and its dust spiral into the star
    /// (`UltraWaitScene`), which flashes at `ultraFlashTime`, a wave of light runs out, and then the ring opens. 0.8 s more than Apple
    /// Intelligence's.
    static let ultraFinishDuration: TimeInterval = 1.1
    static let ultraFlashTime: TimeInterval = 0.8
    static let ringDuration: TimeInterval = 0.8
    /// The star flying to the caret, and the caret blinking for a moment.
    static let landingDuration: TimeInterval = 0.9
    static let caretHold: TimeInterval = 0.5
    /// Cancel's exit: the star falls (0.3 s), then the overlay fades (0.22 s).
    static let fallDuration: TimeInterval = 0.3
    static let leaveFadeDuration: TimeInterval = 0.22

    /// How long the finish takes before the page may start writing: the cover, then the ring.
    static var revealLead: TimeInterval { coverDuration + ringDuration }

    /// The finish before the ring opens: the cover, or Ultra AI's longer one.
    var coverTime: TimeInterval { engine == .ultra ? Self.ultraFinishDuration : Self.coverDuration }

    // MARK: - State

    private(set) var phase: Phase = .idle {
        didSet { markMotion(leaving: oldValue) }
    }
    /// Where the star left from (the arrow), in screen coordinates.
    private(set) var origin: CGPoint = .zero
    private(set) var idea = ""
    private(set) var platformName = ""
    /// Who is writing: the star says "Drafting with Ultra" for Google's Gemini, never Apple Intelligence's words.
    private(set) var engine: ScriptEngine = .apple
    /// Whether the exit is because of an error (the toast says so) and not a Cancel.
    private(set) var leftBecauseOfError = false
    /// How much of the script is written, for the percentage under the phrase; nil until the page starts writing.
    private(set) var progress: WritingProgressMeter?
    /// The app behind the star is held still as it was at the tap (`TransitionBackdrop`): from the tap until the cover is solid on the
    /// finish (the ring then opens onto the live page) or until Cancel or an error starts the exit (the live app, back on Scripts, comes up
    /// under the cover).
    private(set) var showsBackdrop = false
    /// A factor on every timing (1 plays the board's own; UI tests shorten it): the transitions keep their order. Low Power Mode does not change it.
    var speed: Double = 1

    var isActive: Bool { phase != .idle }
    /// Goes up with each star: one that starts while the last is still finishing (or falling) is a new run, which the overlay starts afresh
    /// and the last one's finish never ends.
    private(set) var run = 0

    /// Called once when the transition ends for any reason but success: the page and its script are taken away.
    private var onAbort: (() -> Void)?
    /// Called when the ring opens: the idea has become a script, so it is a star in the sky.
    private var onArrive: (() -> Void)?
    private var startedAt: TimeInterval?
    private var timer: Task<Void, Never>?

    /// Waits `seconds`, and tells the time in seconds: the real ones by default; tests hand in a clock they move by hand.
    private let sleeper: (TimeInterval) async -> Void
    private let clock: () -> TimeInterval

    /// The rise and the finish are animation intervals (`studio.cue` / Motion, "Star rise" and "Star reveal"): Instruments and
    /// `PerformanceDeviceUITests` count their hitches.
    private static let signposter = OSSignposter(subsystem: "studio.cue", category: "Motion")
    @ObservationIgnored private var motion: OSSignpostIntervalState?

    init(
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        sleeper = sleep
        clock = now
    }

    // MARK: - Starting

    /// The arrow was tapped: the star rises. `abort` removes the script that was opened for it (Cancel or an error).
    func begin(
        from origin: CGPoint, idea: String, platformName: String, engine: ScriptEngine = .apple, abort: @escaping () -> Void,
        arrive: @escaping () -> Void
    ) {
        timer?.cancel()
        run += 1
        self.origin = origin
        self.idea = idea
        self.platformName = platformName
        self.engine = engine
        leftBecauseOfError = false
        progress = nil
        onAbort = abort
        onArrive = arrive
        showsBackdrop = true
        phase = .rising
        startedAt = clock()
        timer = Task { [weak self] in
            await self?.sleeper(Self.riseDuration * (self?.speed ?? 1))
            guard !Task.isCancelled else { return }
            if self?.phase == .rising { self?.phase = .waiting }
        }
    }

    // MARK: - Finishing

    /// The AI has the script: waits for the minimum, runs the finish and returns when the page may start writing. Returns at once when
    /// there is no transition (a script opened any other way).
    func contentReady() async {
        guard phase == .rising || phase == .waiting, let startedAt else { return }
        // Each wait may see another star start (an idea sent while this one finishes): that one is never touched from here.
        let run = run
        let remaining = Self.minimumDuration * speed - (clock() - startedAt)
        if remaining > 0 { await sleeper(remaining) }
        guard self.run == run, phase == .rising || phase == .waiting else { return }
        phase = .revealing
        onArrive?()
        onArrive = nil
        onAbort = nil
        await sleeper(coverTime * speed)
        guard self.run == run else { return }
        // The cover is solid: the ring opens onto the live page, never onto the picture.
        showsBackdrop = false
        await sleeper(Self.ringDuration * speed)
        guard self.run == run else { return }
        timer = Task { [weak self] in
            await self?.sleeper((Self.landingDuration + Self.caretHold) * (self?.speed ?? 1))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }

    /// The page started writing the star's script: the star says how much of it is written. Nothing when there is no star (a script written
    /// again from the page has its own pill).
    func track(_ meter: WritingProgressMeter) {
        guard phase == .rising || phase == .waiting else { return }
        progress = meter
    }

    // MARK: - Leaving

    /// "Cancel": the request stops, the script goes, the idea stays in the field. No toast.
    func cancel() {
        leave(becauseOfError: false)
    }

    /// The AI failed: the same exit as Cancel; the caller says why in a toast.
    func fail() {
        leave(becauseOfError: true)
    }

    private func leave(becauseOfError: Bool) {
        guard phase == .rising || phase == .waiting else { return }
        timer?.cancel()
        leftBecauseOfError = becauseOfError
        Haptics.light()
        showsBackdrop = false
        phase = .leaving
        onArrive = nil
        let abort = onAbort
        onAbort = nil
        abort?()
        timer = Task { [weak self] in
            await self?.sleeper((Self.fallDuration + Self.leaveFadeDuration) * (self?.speed ?? 1))
            guard !Task.isCancelled else { return }
            self?.end()
        }
    }

    private func end() {
        phase = .idle
        progress = nil
        showsBackdrop = false
    }

    private func markMotion(leaving old: Phase) {
        guard phase != old else { return }
        if let motion {
            switch old {
            case .rising: Self.signposter.endInterval("Star rise", motion)
            case .revealing: Self.signposter.endInterval("Star reveal", motion)
            default: break
            }
        }
        switch phase {
        case .rising: motion = Self.signposter.beginAnimationInterval("Star rise", id: Self.signposter.makeSignpostID())
        case .revealing: motion = Self.signposter.beginAnimationInterval("Star reveal", id: Self.signposter.makeSignpostID())
        default: motion = nil
        }
    }

    // MARK: - Phrases

    /// The phrases while the AI writes, in order; the last is always the one shown at the end. `platform` fills "Shaping it for …".
    static func phrases(platform: String) -> [String] {
        [
            String(localized: "Drafting a hook…"),
            String(localized: "Lining up the stars"),
            String(localized: "Shaping it your way"),
            String(localized: "Saving room for your pause"),
            String(localized: "Trimming the extra words"),
            String(localized: "Warming up the prompter"),
            String(localized: "Shaping it for \(platform)"),
        ]
    }

    static var finishPhrase: String { String(localized: "Draft almost ready") }

    /// Seconds after which the AI is said to be taking longer than usual (a request is given up on by itself a little later: `GenerationDeadlines`).
    static let longWait: TimeInterval = 22
    /// The same for Ultra AI, whose three passes take 25 to 70 s (36 s usually, measured on an iPhone 15 Pro, 29/10/2026).
    static let ultraLongWait: TimeInterval = 45

    /// What the star says once the wait is long.
    static var longWaitPhrase: String { String(localized: "Still drafting · taking a little longer") }
}
