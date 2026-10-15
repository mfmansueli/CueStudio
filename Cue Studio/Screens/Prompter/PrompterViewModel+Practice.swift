//
//  PrompterViewModel+Practice.swift
//  Cue Studio
//

import Foundation

extension PrompterViewModel {
    /// The practice opens (1.6): it reads with Voice Following when the microphone can be used, so the creator's words move the text, and at
    /// a steady pace when it can't. The mode is for this session only: unless the creator picks one, the saved mode is what the next session
    /// opens with (`practiceChoseScrollMode`). The script then says what this practice really does.
    func preparePractice() {
        guard isPractice else { return }
        let wanted: ScrollMode = microphone.isDenied() ? .steady : .voice
        if session.prompter.scrollMode != wanted {
            session.prompter.scrollMode = wanted
            practiceChoseScrollMode = true
        }
        matchPracticeScript()
    }

    /// Back from Settings, where the microphone may have been turned on (or off): the practice picks its mode again.
    func refreshPracticeMicrophone() {
        guard isPractice, practiceStage.isWaiting else { return }
        let before = session.prompter.scrollMode
        preparePractice()
        if session.prompter.scrollMode != before { updateVoiceMonitoring() }
    }

    /// What moves the practice's text, for the line under the box and the card.
    var practiceVoice: PracticeVoice {
        guard session.prompter.scrollMode == .voice else { return .steady }
        if followsSpeech { return .following }
        switch speechPreparation {
        case .preparing?: return .preparing
        case .downloading(_, let progress)?: return .downloading(progress: progress)
        case nil: return speechUnavailable == nil ? .preparing : .scrollsWhileTalking
        }
    }

    /// The practice script claims the teleprompter follows the voice only while it does or is getting ready to: without the microphone, or
    /// when this iPhone can't follow the words, the practice reads the version without that claim. Only before the text starts to move
    /// (it is still dimmed and blurred), and only on the practice script.
    func matchPracticeScript() {
        guard isPractice, practiceStage.isWaiting, let script else { return }
        let follows = OnboardingScript.practice(followsVoice: true).text
        let plain = OnboardingScript.practice(followsVoice: false).text
        let wanted = practiceVoice.followsWords ? follows : plain
        guard script.text == follows || script.text == plain, script.text != wanted else { return }
        library.update(script.id) { $0.text = wanted }
    }

    /// The tap on the practice's play button (1.6, 09 §17): Cue counts the creator in, then the text waits for them: it moves with their
    /// words from the first one recognized (or, when the words can't be followed, from when their voice really starts). Without the
    /// microphone it can't hear them, so it scrolls at the set speed after the count. From the top, also when it is run again after the
    /// text was read.
    func beginPracticeReading() {
        guard isPractice, hasScript else { return }
        switch practiceStage {
        case .idle, .done: break
        case .counting, .reading: return
        }
        practiceTask?.cancel()
        // `.done` is past the reading: the script may change again before this run starts.
        practiceStage = .idle
        matchPracticeScript()
        rewindText()
        Haptics.medium()
        let start = Date.now
        practiceStage = .counting(since: start)
        practiceTask = Task { [weak self] in
            func wait(until second: Double) async -> Bool {
                try? await Task.sleep(for: .seconds(max(0, second - Date.now.timeIntervalSince(start))))
                return !Task.isCancelled
            }
            // 3, 2 and 1 come in at 0.6, 1.6 and 2.6 s after the tap (a stiff tap for each), READ! at 3.6 s with a success; the dim lifts
            // at 3.75 s and the text starts, standing still until the creator speaks.
            for second in [0.6, 1.6, 2.6] {
                guard await wait(until: second) else { return }
                Haptics.rigid()
            }
            guard await wait(until: 3.6) else { return }
            Haptics.success()
            guard await wait(until: PracticeStage.countInDuration), let self else { return }
            practiceStage = .reading
            play()
        }
    }

    /// "Record my first video": the practice ends and the text goes back to the top.
    func leavePractice() {
        guard isPractice else { return }
        practiceTask?.cancel()
        pause()
        isPractice = false
        rewindText()
    }

    /// The whole text has been read: a card says so, half a second later (the board: 0.5 s after the last line).
    func practiceTextEnded() {
        guard isPractice, practiceStage == .reading else { return }
        practiceTask?.cancel()
        practiceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled, let self else { return }
            practiceStage = .done
        }
    }
}
