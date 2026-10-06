//
//  PrompterViewModel+Practice.swift
//  Cue Studio
//

import AVFAudio
import Foundation

extension PrompterViewModel {
    /// The tap on the practice's play button (1.6, 09 §17): Cue counts the creator in, then the text moves in the mode they use (following
    /// their voice from the first word, or at the set speed). Without the microphone Voice Following can't listen, so the run flows at a
    /// steady pace. From the top, also when it is run again after the text was read.
    func beginPracticeReading() {
        guard isPractice, hasScript else { return }
        switch practiceStage {
        case .idle, .done: break
        case .counting, .reading: return
        }
        practiceTask?.cancel()
        if AVAudioApplication.shared.recordPermission == .denied { setScrollMode(.steady) }
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
            // at 3.75 s and the text moves.
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

    /// "Record it for real": the practice ends and the text goes back to the top.
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
