//
//  PrompterViewModel+Setup.swift
//  Cue Studio
//

import Foundation

/// The recording setup on the Selfie screen — the platform recommendation card, the setup pill and
/// its sheet — and the remote: commands from another device and what the teleprompter reports back.
extension PrompterViewModel {
    // MARK: - Recommendation

    /// The card asking "Recommended for TikTok · Use 1080p / Keep 4K", before the take starts.
    var showsRecommendation: Bool {
        mode == .selfie && reviewingTake == nil && !isRecording && countdown == nil && session.needsDecision
    }

    /// "Use Recommended": this session only; Creator Setup stays as it is.
    func useRecommendedSetup() {
        guard let recommendation = session.recommendation else { return }
        session.useRecommended()
        toast.show(String(localized: "Using \(recommendation.setupName)"))
    }

    /// "Keep My Setup".
    func keepCreatorSetup() {
        session.keepCreatorSetup()
        toast.show(String(localized: "Keeping your setup"))
    }

    /// Drops this take's changes and the accepted recommendation.
    func backToCreatorSetup() {
        session.backToCreatorSetup()
        toast.show(String(localized: "Back to your setup"))
    }

    // MARK: - Setup pill

    /// "4K · 9:16", next to the microphone on the recording screen.
    var captureSummary: String { session.current.captureSummary }

    /// Nothing to change while a take runs or counts down.
    var canChangeSetup: Bool { !isRecording && countdown == nil }

    func openRecordingSetup() {
        guard canChangeSetup else { return }
        sheet = .recordingSetup
    }

    // MARK: - Remote

    var isRemoteConnected: Bool { remote.isConnected }

    func openRemoteControl() {
        sheet = .remote
    }

    /// A command from the remote. The take's recording stays in the creator's hands; the remote
    /// drives the text.
    func handle(_ command: RemoteCommand) {
        guard reviewingTake == nil, hasScript else {
            remote.publish(remoteStatus)
            return
        }
        switch command {
        case .togglePlay: togglePlay()
        case .play: play()
        case .pause: pause()
        case .faster: setSpeed(session.prompter.speed + RemoteCommand.speedStep)
        case .slower: setSpeed(session.prompter.speed - RemoteCommand.speedStep)
        case .forward: jump(lines: RemoteCommand.jumpLines)
        case .backward: jump(lines: -RemoteCommand.jumpLines)
        case .restart: rewind()
        }
        publishRemoteStatus()
    }

    /// What the remote shows.
    var remoteStatus: RemoteStatus {
        guard reviewingTake == nil, let script else { return .idle }
        let settings = session.prompter
        return RemoteStatus(
            scriptTitle: script.displayTitle,
            isPlaying: isPlaying,
            speed: settings.speed,
            followsVoice: settings.scrollMode == .voice,
            progress: engine.progress,
            isRecording: isRecording
        )
    }

    func publishRemoteStatus() {
        remote.publish(remoteStatus)
    }

    // MARK: - Camera controls

    /// Frame, lens and the rest change for this take; Creator Setup keeps the defaults.
    func cycleAspect() {
        session.camera.aspect = session.camera.aspect.next
    }

    func flipCamera() {
        session.camera.lens = session.camera.lens.isFront ? .wide : .front
    }

    /// The microphone pill: the input can't change mid-take (or while the countdown runs into one).
    var canChangeAudioInput: Bool { !isRecording && countdown == nil }

    func openAudioInput() {
        guard canChangeAudioInput else { return }
        sheet = .audioInput
    }

    func cycleCountdown() {
        session.camera.countdown = session.camera.countdown.next
    }
}
