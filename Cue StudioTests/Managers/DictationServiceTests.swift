//
//  DictationServiceTests.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// Speaking an idea: the microphone and the recognizer behind the idea card's microphone button.
/// The permission is asked only on the tap, the words reach the field as they are said, a stop
/// keeps the last of them, and every way out (a stop, a cancel, an interruption) lets the microphone go.
@MainActor
@Suite("Dictation")
struct DictationServiceTests {
    /// What the microphone permission says, moved by the test.
    @MainActor
    private final class Permission {
        var denied = false
        /// What the system prompt answers when it is asked.
        var allowsOnPrompt = true
        private(set) var requests = 0

        var access: MicrophoneAccess {
            MicrophoneAccess(
                isDenied: { self.denied },
                request: {
                    self.requests += 1
                    return self.allowsOnPrompt
                }
            )
        }
    }

    /// The words the field received.
    private final class Heard {
        var texts: [String] = []
    }

    @MainActor
    private struct Rig {
        let service: DictationService
        let audio = FakeAudioMeter()
        let speech = FakeSpeechTranscriber()
        let permission = Permission()
        let heard = Heard()
        let notificationCenter = NotificationCenter()

        /// The microphone watch and the finishing run on real time. Tests that aren't about them keep
        /// them far away, so a busy test run (the whole suite in parallel) can't fire them midway.
        init(silenceTimeout: Duration = .seconds(600), watchInterval: Duration = .seconds(1), finishTimeout: Duration = .seconds(600)) {
            service = DictationService(
                audio: audio, speech: speech, microphone: permission.access,
                finishTimeout: finishTimeout, silenceTimeout: silenceTimeout, watchInterval: watchInterval,
                notificationCenter: notificationCenter
            )
        }

        func start(language: SpeechLanguageRequest = .language(.english)) async {
            await service.start(language: language) { heard.texts.append($0) }
        }
    }

    private func settle(_ yields: Int = 30) async {
        for _ in 0..<yields { await Task.yield() }
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() {
            await Task.yield()
        }
        await waitUntilSlow(condition)
    }

    /// For a wait that depends on a real timer: up to a deadline far beyond any timeout under test,
    /// so a busy machine only makes it slower, never wrong.
    private func waitUntilSlow(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now + .seconds(10)
        while !condition(), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Listening

    @Test func tappingTheMicrophoneListensInTheRequestedLanguageAndAsksForNothingElse() async {
        let rig = Rig()
        await rig.start(language: .language(.portugueseBrazil))
        #expect(rig.service.state == .listening)
        #expect(rig.audio.isMetering)
        #expect(rig.speech.requests == [.language(.portugueseBrazil)])
        #expect(rig.permission.requests == 1)
        #expect(rig.service.notice == nil)
    }

    @Test func wordsReachTheFieldAsTheyGrowAndNothingRepeats() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("a video")
        await settle()
        rig.speech.say("a video about coffee")
        await settle()
        // The same transcript again (a partial result that didn't change) is not delivered twice.
        rig.speech.say("a video about coffee")
        await settle()
        #expect(rig.heard.texts == ["a video", "a video about coffee"])
    }

    @Test func theSpacesAroundWhatWasHeardAreLeftOut() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("  hello there ")
        await settle()
        #expect(rig.heard.texts == ["hello there"])
    }

    // MARK: - Permission and availability

    @Test func aMicrophoneTurnedOffExplainsItAndNeverStartsTheRecognizer() async {
        let rig = Rig()
        rig.permission.denied = true
        await rig.start()
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .microphoneDenied)
        #expect(rig.service.notice?.offersSettings == true)
        #expect(rig.speech.startCount == 0)
        #expect(!rig.audio.isMetering)
        // It doesn't ask again: Settings is where that changes.
        #expect(rig.permission.requests == 0)
    }

    @Test func refusingTheSystemPromptLeavesTheCreatorTypingWithAnExplanation() async {
        let rig = Rig()
        rig.permission.allowsOnPrompt = false
        await rig.start()
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .microphoneDenied)
        #expect(rig.permission.requests == 1)
        #expect(rig.speech.startCount == 0)
        #expect(!rig.audio.isMetering)
    }

    @Test func aLanguageThisIPhoneCantRecognizeIsSaidAndNeverSwappedForAnother() async {
        let rig = Rig()
        rig.speech.unavailable = .unsupported(.thai)
        await rig.start(language: .language(.thai))
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .unavailable(.unsupported(.thai)))
        #expect(rig.speech.requests == [.language(.thai)])
        #expect(rig.service.notice?.offersSettings == false)
        #expect(!rig.audio.isMetering)
        #expect(rig.heard.texts.isEmpty)
    }

    @Test func eachReasonSaysWhatToDoNext() {
        let reasons: [SpeechUnavailableReason] = [
            .unsupported(.thai), .unsupportedDetected("Welsh"), .unknownLanguage, .needsDownload(.german),
            .needsDownload(nil), .noRecognition, .couldNotStart,
        ]
        for reason in reasons {
            let message = reason.dictationMessage
            #expect(!message.isEmpty)
            #expect(message.contains("type your idea") || message.contains("try again"), "\(reason) → \(message)")
            // It's about dictation, not Voice Following or captions.
            #expect(!message.contains("Voice Following") && !message.contains("Captions"))
        }
        #expect(SpeechUnavailableReason.unsupported(.thai).dictationMessage.contains(CueLanguage.thai.localizedName))
    }

    @Test func aMicrophoneThatCannotStartReleasesTheRecognizerAndCanBeRetried() async {
        let rig = Rig()
        rig.audio.canStart = false
        await rig.start()
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .unavailable(.couldNotStart))
        #expect(rig.speech.stopCount == 1)
        #expect(rig.audio.audioHandler == nil && rig.audio.levelHandler == nil)
        rig.speech.say("words after the failure")
        await settle()
        #expect(rig.heard.texts.isEmpty)

        rig.audio.canStart = true
        await rig.start()
        #expect(rig.service.state == .listening)
        #expect(rig.service.notice == nil)
        rig.service.cancel()
    }

    @Test func gettingReadyAndDownloadingShowWhileThePreparationRuns() async {
        let rig = Rig()
        rig.speech.preparationSteps = [.preparing, .downloading(.german, progress: 0.4)]
        rig.speech.holdsStart = true
        let task = Task { await rig.start(language: .language(.german)) }
        await waitUntil { rig.service.state == .preparing(.downloading(.german, progress: 0.4)) }
        #expect(rig.service.state == .preparing(.downloading(.german, progress: 0.4)))
        // Nothing is heard, and the microphone isn't on, while the model comes in.
        #expect(!rig.audio.isMetering)
        rig.speech.finishPreparing()
        await task.value
        #expect(rig.service.state == .listening)
    }

    // MARK: - Stopping

    @Test func stoppingClosesTheMicrophoneAtOnceAndKeepsTheLastWordsTheRecognizerFinalizes() async {
        let rig = Rig()
        rig.speech.finalWords = "a video about coffee and focus"
        await rig.start()
        rig.speech.say("a video about coffee")
        await settle()
        rig.service.stop()
        #expect(rig.service.state == .finishing)
        #expect(!rig.audio.isMetering)
        await waitUntil { rig.service.state == .idle }
        #expect(rig.service.state == .idle)
        #expect(rig.heard.texts.last == "a video about coffee and focus")
        #expect(rig.speech.finishCount == 1)
        #expect(rig.service.notice == nil)
    }

    @Test func stoppingWhenNothingWasSaidSaysSoAndKeepsNothingBehind() async {
        let rig = Rig()
        await rig.start()
        rig.service.stop()
        await waitUntil { rig.service.state == .idle }
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .nothingHeard)
        #expect(rig.heard.texts.isEmpty)
        #expect(!rig.audio.isMetering)
    }

    @Test func aRecognizerThatNeverFinishesIsClosedAsItIsAfterTheTimeout() async {
        let rig = Rig(finishTimeout: .milliseconds(50))
        rig.speech.holdsFinish = true
        await rig.start()
        rig.speech.say("something I said")
        await settle()
        rig.service.stop()
        #expect(rig.service.state == .finishing)
        await waitUntilSlow { rig.service.state == .idle }
        // The dictation ends anyway, and what was heard stays.
        #expect(rig.service.state == .idle)
        #expect(rig.heard.texts == ["something I said"])
        #expect(rig.speech.stopCount >= 1)
        #expect(!rig.audio.isMetering)
    }

    @Test func stoppingWhileItOnlyPreparesCancelsWithNoNote() async {
        let rig = Rig()
        rig.speech.holdsStart = true
        let task = Task { await rig.start() }
        await waitUntil { rig.service.state == .preparing(nil) || rig.speech.startCount == 1 }
        rig.service.stop()
        rig.speech.finishPreparing()
        await task.value
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == nil)
        #expect(!rig.audio.isMetering)
        #expect(rig.heard.texts.isEmpty)
    }

    @Test func twoDictationsInARowEachStartClean() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("first idea")
        await settle()
        rig.service.stop()
        await waitUntil { rig.service.state == .idle }
        await rig.start()
        #expect(rig.service.state == .listening)
        rig.speech.say("second idea")
        await settle()
        #expect(rig.heard.texts == ["first idea", "second idea"])
        #expect(rig.speech.startCount == 2)
    }

    @Test func aNoteFromTheLastTimeGoesWhenANewOneStarts() async {
        let rig = Rig()
        rig.permission.allowsOnPrompt = false
        await rig.start()
        #expect(rig.service.notice == .microphoneDenied)
        rig.permission.allowsOnPrompt = true
        await rig.start()
        #expect(rig.service.notice == nil)
        #expect(rig.service.state == .listening)
    }

    // MARK: - Letting go

    @Test func leavingTheScreenLetsGoOfTheMicrophoneAndTheRecognizerWithoutANote() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("an idea in progress")
        await settle()
        rig.service.cancel()
        #expect(rig.service.state == .idle)
        #expect(!rig.audio.isMetering)
        #expect(rig.speech.stopCount >= 1)
        #expect(rig.audio.audioHandler == nil && rig.audio.levelHandler == nil)
        #expect(rig.service.notice == nil)
        // What was heard stays with the field; a late result is not delivered.
        rig.speech.say("a late result")
        await settle()
        #expect(rig.heard.texts == ["an idea in progress"])
    }

    @Test func cancellingWhileItPreparesStopsTheStartAndNothingLeaksAfterItFinishes() async {
        let rig = Rig()
        rig.speech.holdsStart = true
        let task = Task { await rig.start() }
        await waitUntil { rig.speech.startCount == 1 }
        rig.service.cancel()
        rig.speech.finishPreparing()
        await task.value
        #expect(rig.service.state == .idle)
        #expect(!rig.audio.isMetering)
        #expect(rig.audio.audioHandler == nil)
    }

    @Test func anInterruptionLetsGoKeepsTheWordsAndTellsTheCreatorOnce() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("what I said so far")
        await settle()
        rig.service.interrupt()
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .interrupted)
        #expect(!rig.audio.isMetering)
        rig.speech.say("after the call")
        await settle()
        #expect(rig.heard.texts == ["what I said so far"])
        rig.service.dismissNotice()
        #expect(rig.service.notice == nil)
    }

    @Test func interruptingAnIdleDictationChangesNothing() {
        let rig = Rig()
        rig.service.interrupt()
        #expect(rig.service.state == .idle && rig.service.notice == nil)
    }

    @Test(arguments: [AVAudioSession.didBecomeInactiveNotification, AVAudioSession.mediaServicesWereResetNotification])
    func losingTheAudioSessionStopsDictation(_ notification: Notification.Name) async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("words before the interruption")
        await settle()
        rig.notificationCenter.post(name: notification, object: nil)
        await waitUntil { rig.service.state == .idle }
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .interrupted)
        #expect(!rig.audio.isMetering)
        #expect(rig.audio.audioHandler == nil && rig.audio.levelHandler == nil)
        #expect(rig.heard.texts == ["words before the interruption"])
    }

    @Test func aRecognizerThatEndsOnItsOwnWhileListeningIsAnInterruption() async {
        let rig = Rig()
        await rig.start()
        rig.speech.say("some words")
        await settle()
        rig.speech.endOnItsOwn()
        await waitUntil { rig.service.state == .idle }
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .interrupted)
        #expect(!rig.audio.isMetering)
        #expect(rig.heard.texts == ["some words"])
    }

    @Test func aMicrophoneThatGoesSilentIsTakenAsGone() async {
        let rig = Rig(silenceTimeout: .milliseconds(80), watchInterval: .milliseconds(20))
        await rig.start()
        #expect(rig.service.state == .listening)
        // No buffers arrive (an unplugged mic, a call): it lets go by itself.
        await waitUntilSlow { rig.service.state == .idle }
        #expect(rig.service.state == .idle)
        #expect(rig.service.notice == .interrupted)
        #expect(!rig.audio.isMetering)
    }

    // MARK: - The voice

    @Test func theLevelFollowsTheVoiceAndRestsWhenItStops() async {
        let rig = Rig()
        await rig.start()
        rig.audio.hear(level: -25, at: 1.0)
        await settle()
        #expect(abs(rig.service.level - 0.75) < 0.001)
        rig.service.stop()
        #expect(rig.service.level == 0)
    }

    @Test func theLevelScaleRunsFromAQuietRoomToCloseSpeech() {
        #expect(DictationService.normalized(-160) == 0)
        #expect(DictationService.normalized(-55) == 0)
        #expect(abs(DictationService.normalized(-35) - 0.5) < 0.001)
        #expect(DictationService.normalized(-15) == 1)
        #expect(DictationService.normalized(0) == 1)
    }

    // MARK: - Messages

    @Test func onlyAMicrophoneTurnedOffSendsTheCreatorToSettings() {
        #expect(DictationNotice.microphoneDenied.offersSettings)
        #expect(!DictationNotice.interrupted.offersSettings)
        #expect(!DictationNotice.nothingHeard.offersSettings)
        #expect(!DictationNotice.unavailable(.noRecognition).offersSettings)
        for notice in [DictationNotice.microphoneDenied, .interrupted, .nothingHeard, .unavailable(.couldNotStart)] {
            #expect(!notice.message.isEmpty)
        }
    }

    @Test func theStateKnowsWhenItIsBusy() {
        #expect(!DictationState.idle.isActive)
        #expect(DictationState.preparing(nil).isActive && DictationState.listening.isActive && DictationState.finishing.isActive)
    }
}
