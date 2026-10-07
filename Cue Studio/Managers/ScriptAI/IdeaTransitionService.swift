//
//  IdeaTransitionService.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The star that is the transition from an idea to its script (v30 · 09 §8, `motion/README.md`). The idea's star rises from the arrow
/// to the middle of the screen (0.6 s), Scripts dims behind it, and while Apple Intelligence writes it says what is happening — "Writing in
/// your voice", the idea and a phrase that changes every 1.6 s. It lasts at least 3.0 s from the tap (longer if the AI needs it); when the
/// script is ready the ring opens (0.42 s), the screen crossfades into the page (0.22 s) and the star lands as the caret, where the words
/// begin. Cancel, or an error, leaves the way it came: the star falls 40 pt (0.3 s), the overlay fades (0.22 s), and the idea is still in the
/// field. This is the clock and the state; `StarTransitionOverlay` draws it.
@MainActor
@Observable
final class IdeaTransitionService {
    enum Phase: Equatable {
        case idle
        /// The star is rising to the middle (0.6 s).
        case rising
        /// The AI is writing: halo, particles, the phrases and Cancel.
        case waiting
        /// The script is ready: the finish phrase, the ring and the crossfade into the page.
        case revealing
        /// Cancel or an error: the star falls and the overlay fades.
        case leaving
    }

    // MARK: - Timings (09 §8)

    static let riseDuration: TimeInterval = 0.6
    /// The shortest the transition lasts from the tap, even when the AI answers sooner.
    static let minimumDuration: TimeInterval = 3.0
    /// Seconds each phrase stays.
    static let phraseInterval: TimeInterval = 1.6
    /// The overlay darkens to cover the screen (0.22 s) before the ring opens.
    static let coverDuration: TimeInterval = 0.22
    static let ringDuration: TimeInterval = 0.42
    static let crossfadeDuration: TimeInterval = 0.22
    /// The star flying to the caret, and the caret blinking for a moment.
    static let landingDuration: TimeInterval = 0.44
    static let caretHold: TimeInterval = 0.4
    /// Cancel's exit: the star falls (0.3 s), then the overlay fades (0.22 s).
    static let fallDuration: TimeInterval = 0.3
    static let leaveFadeDuration: TimeInterval = 0.22

    /// How long the finish takes before the page may start writing: the cover, then the ring.
    static var revealLead: TimeInterval { coverDuration + ringDuration }

    // MARK: - State

    private(set) var phase: Phase = .idle
    /// Where the star left from (the arrow), in screen coordinates.
    private(set) var origin: CGPoint = .zero
    private(set) var idea = ""
    private(set) var platformName = ""
    /// Whether the exit is because of an error (the toast says so) and not a Cancel.
    private(set) var leftBecauseOfError = false
    /// How much of the script is written, for the percentage under the phrase; nil until the page starts writing.
    private(set) var progress: WritingProgressMeter?
    /// A factor on every timing (1 plays the board's own; UI tests shorten it): the transitions keep their order. Low Power Mode does not change it.
    var speed: Double = 1

    var isActive: Bool { phase != .idle }

    /// Called once when the transition ends for any reason but success: the page and its script are taken away.
    private var onAbort: (() -> Void)?
    /// Called when the ring opens: the idea has become a script, so it is a star in the sky.
    private var onArrive: (() -> Void)?
    private var startedAt: TimeInterval?
    private var timer: Task<Void, Never>?

    /// Waits `seconds`, and tells the time in seconds: the real ones by default; tests hand in a clock they move by hand.
    private let sleeper: (TimeInterval) async -> Void
    private let clock: () -> TimeInterval

    init(
        sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) },
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        sleeper = sleep
        clock = now
    }

    // MARK: - Starting

    /// The arrow was tapped: the star rises. `abort` removes the script that was opened for it (Cancel or an error).
    func begin(from origin: CGPoint, idea: String, platformName: String, abort: @escaping () -> Void, arrive: @escaping () -> Void) {
        timer?.cancel()
        self.origin = origin
        self.idea = idea
        self.platformName = platformName
        leftBecauseOfError = false
        progress = nil
        onAbort = abort
        onArrive = arrive
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
        let remaining = Self.minimumDuration * speed - (clock() - startedAt)
        if remaining > 0 { await sleeper(remaining) }
        guard phase == .rising || phase == .waiting else { return }
        phase = .revealing
        Haptics.success()
        onArrive?()
        onArrive = nil
        onAbort = nil
        await sleeper(Self.revealLead * speed)
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
    }

    // MARK: - Phrases

    /// The phrases while the AI writes, in order; the last is always the one shown at the end. `platform` fills "Shaping it for …".
    static func phrases(platform: String) -> [String] {
        [
            String(localized: "Finding your hook…"),
            String(localized: "Lining up the stars"),
            String(localized: "Making it sound like you"),
            String(localized: "Saving room for your pause"),
            String(localized: "Trimming the extra words"),
            String(localized: "Warming up the prompter"),
            String(localized: "Shaping it for \(platform)"),
        ]
    }

    static var finishPhrase: String { String(localized: "Almost camera-ready") }

    /// Seconds after which the AI is said to be taking longer than usual (a request is given up on by itself a little later: `GenerationDeadlines`).
    static let longWait: TimeInterval = 22

    /// What the star says once the wait is long.
    static var longWaitPhrase: String { String(localized: "Still writing · this one is taking a little longer") }
}
