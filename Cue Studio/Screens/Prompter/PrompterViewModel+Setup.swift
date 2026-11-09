//
//  PrompterViewModel+Setup.swift
//  Cue Studio
//

import Foundation

/// The recording setup on the Selfie screen — the platform recommendation card, the setup pill and
/// its sheet — and the remote: commands from another device and what the teleprompter reports back.
extension PrompterViewModel {
    // MARK: - Recommendation

    /// The card asking "Recommended for Shorts · Frame rate 30 fps → 60 fps", before the take starts, while something would change.
    var showsRecommendation: Bool {
        mode == .selfie && reviewingTake == nil && !isRecording && countdown == nil && session.choice == .undecided
            && !recommendationChanges.isEmpty
    }

    /// What "Use Recommended" would change against what is on screen now: the setup's fields, then the safe zone when it would move
    /// (the creator's Custom one, or another network's on this frame). Empty when the screen already matches.
    var recommendationChanges: [SetupChange] {
        guard let recommendation = session.recommendation else { return [] }
        var changes = session.changes
        if let zone = safeZoneChange(for: recommendation) { changes.append(zone) }
        return changes
    }

    /// The safe zone line: shown while the zone is on and the network's would replace the one on screen.
    private func safeZoneChange(for recommendation: SetupRecommendation) -> SetupChange? {
        guard recommendation.hasSafeZone, session.camera.showsSafeZones, let now = safeZone else { return nil }
        let aspect = recommendation.values.aspect ?? session.camera.aspect
        guard let after = SafeZoneChoice.resolve(pick: nil, network: recommendation.platform, aspect: aspect, rules: rules.rules),
              after != now else { return nil }
        return SetupChange(item: .safeZone, current: now.label, recommended: after.label, isManual: now == .custom)
    }

    /// A new recommendation for this recording (a script, another network): asked only when something on screen would change;
    /// otherwise it is settled at once, so a later change of frame never brings the card up by itself.
    func offerRecommendation() {
        session.recommend(recommendation)
        if session.choice == .undecided, session.recommendation != nil, recommendationChanges.isEmpty { session.keepAsIs() }
    }

    /// "Use Recommended": exactly the lines the card lists, safe zone included, for this session only; Creator Setup stays as it is.
    func useRecommendedSetup() {
        guard let recommendation = session.recommendation else { return }
        let movesZone = recommendationChanges.contains { $0.item == .safeZone }
        session.useRecommended(includingSafeZone: movesZone)
        toast.show(String(localized: "Using \(recommendation.setupName)"))
    }

    /// "Keep as is": nothing changes.
    func keepAsIs() {
        session.keepAsIs()
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

    /// A command from the remote (another iPhone or iPad, a keyboard, a pedal): Record and Stop start and end a take the way the Apple
    /// Watch does (`recordFromAnotherDevice`); the rest drives the text.
    func handle(_ command: RemoteCommand) {
        switch command {
        case .record:
            Task {
                await recordFromAnotherDevice()
                publishRemoteStatus()
            }
            return
        case .stop:
            Task {
                await stopFromAnotherDevice()
                publishRemoteStatus()
            }
            return
        default:
            break
        }
        guard reviewingTake == nil, hasScript else {
            remote.publish(remoteStatus)
            return
        }
        switch command {
        case .togglePlay: togglePlay()
        case .play: play()
        case .pause: pause()
        case .faster: setSpeed(SpeedScale.speed(steppedBy: RemoteCommand.speedStops, fromSpeed: session.prompter.speed))
        case .slower: setSpeed(SpeedScale.speed(steppedBy: -RemoteCommand.speedStops, fromSpeed: session.prompter.speed))
        case .forward: jump(lines: RemoteCommand.jumpLines)
        case .backward: jump(lines: -RemoteCommand.jumpLines)
        case .restart: rewind()
        case .record, .stop: break
        }
        publishRemoteStatus()
    }

    /// What the remote shows: the script being read (none while a take is reviewed), and whether it can record, the take's number and
    /// how long it has recorded.
    var remoteStatus: RemoteStatus {
        let settings = session.prompter
        let reading = reviewingTake == nil ? script : nil
        return RemoteStatus(
            scriptTitle: reading?.displayTitle,
            isPlaying: reading != nil && isPlaying,
            speed: settings.speed,
            followsVoice: settings.scrollMode == .voice,
            progress: reading == nil ? 0 : engine.progress,
            isRecording: isRecording,
            canRecord: recordsFromAnotherDevice,
            takeNumber: takes.nextNumber(for: scriptID),
            recordingElapsed: isRecording ? recordingStartedAt.map { Date.now.timeIntervalSince($0) } : nil,
            isCountingDown: countdown != nil
        )
    }

    /// Tells the remote and the Apple Watch what changed.
    func publishRemoteStatus() {
        remote.publish(remoteStatus)
        watch?.publishCurrent()
    }

    // MARK: - Camera controls

    /// Lens and the rest change for this take; Creator Setup keeps the defaults.
    func flipCamera() {
        session.camera.lens = session.camera.lens.isFront ? .wide : .front
    }

    /// The microphone pill: the input can't change mid-take (or while the countdown runs into one).
    var canChangeAudioInput: Bool { !isRecording && countdown == nil }

    func openAudioInput() {
        guard canChangeAudioInput else { return }
        sheet = .audioInput
    }
}
