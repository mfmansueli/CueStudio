//
//  PrompterViewModel+Watch.swift
//  Cue Studio
//

import Foundation

/// The Apple Watch companion (v31): it records, ends, rehearses and drives the text from the wrist, and its screen shows what
/// this recorder says, never what was only asked. Each command is named as answered (`watchAnswer`) once its effect has
/// happened: a countdown or a take started, a take saved, or why not.
extension PrompterViewModel {
    func attachWatch() {
        watch?.attach(
            onCommand: { [weak self] command in self?.handle(watchCommand: command) },
            state: { [weak self] in self?.watchState ?? .noSession }
        )
    }

    /// What the watch is told.
    var watchState: WatchPhoneState {
        WatchPhoneState(
            phase: watchPhase,
            scriptTitle: script?.displayTitle,
            followsVoice: session.prompter.scrollMode == .voice,
            speedMultiple: SpeedScale.stops[SpeedScale.nearestStop(toSpeed: session.prompter.speed)],
            isPlaying: isPlaying,
            recordingStartedAt: isRecording ? recordingStartedAt : nil,
            answering: watchAnswer
        )
    }

    private var watchPhase: WatchPhase {
        // Studio is the teleprompter for another camera, and the first flight's practice records nothing.
        if isPractice || (mode == .studio && reviewingTake == nil) { return .unavailable }
        if let countdown { return .countdown(remaining: countdown) }
        if isSavingTake { return .saving }
        if isRecording { return .recording }
        switch watchOutcome {
        case .saved(let take, let seconds): return .saved(take: take, seconds: seconds)
        case .failedStart: return .failedStart
        case .failedSave: return .failedSave
        case nil: break
        }
        return watchRehearsing && hasScript ? .rehearsal : .ready
    }

    func handle(watchCommand command: WatchCommand) {
        switch command.action {
        case .refresh:
            watchAnswer = command.id
        case .record:
            Task { await recordFromWatch(command.id) }
            return
        case .stop:
            Task { await stopFromWatch(command.id) }
            return
        case .cancelCountdown:
            cancelCountdown()
            watchAnswer = command.id
        case .rehearse:
            watchOutcome = nil
            if hasScript, !isRecording, countdown == nil {
                watchRehearsing = true
                play()
            }
            watchAnswer = command.id
        case .endRehearsal:
            watchRehearsing = false
            pause()
            watchAnswer = command.id
        case .togglePlay:
            if hasScript, countdown == nil {
                if isPlaying { pause() } else { play() }
            }
            watchAnswer = command.id
        case .backward:
            if hasScript { jump(lines: -RemoteCommand.jumpLines) }
            watchAnswer = command.id
        case .faster, .slower:
            let steps = command.action == .faster ? RemoteCommand.speedStops : -RemoteCommand.speedStops
            setSpeed(SpeedScale.speed(steppedBy: steps, fromSpeed: session.prompter.speed))
            watchAnswer = command.id
        case .setSpeed(let multiple):
            setSpeed(SpeedScale.speed(forMultiple: multiple))
            watchAnswer = command.id
        case .done:
            watchOutcome = nil
            watchAnswer = command.id
        }
        publishRemoteStatus()
    }

    /// Record from the wrist: from a saved take, the take again ("Record another"), then the countdown or the take, as the
    /// red button does. Answered once it has started, or with why not.
    private func recordFromWatch(_ id: UUID) async {
        defer {
            watchAnswer = id
            watch?.publishCurrent()
        }
        guard watchPhase != .unavailable else { return }
        watchOutcome = nil
        watchRehearsing = false
        if reviewingTake != nil {
            await retake()
            // The camera starts again for the new take: a moment, never long.
            for _ in 0..<30 where camera.status != .running { try? await Task.sleep(for: .milliseconds(100)) }
        }
        guard countdown == nil, !isRecording else { return }
        if isPlaying { pause() }
        await recordButtonTapped()
        if countdown == nil, !isRecording, watchOutcome == nil { watchOutcome = .failedStart }
    }

    /// End from the wrist: no monetization warning (the creator chose on the watch); answered once the take is saved, or
    /// with why it wasn't.
    private func stopFromWatch(_ id: UUID) async {
        defer {
            watchAnswer = id
            watch?.publishCurrent()
        }
        guard isRecording else { return }
        await stopRecording()
    }
}
