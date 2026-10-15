//
//  ScriptChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 3, 1.4: "Your first script. Ready to read." The practice script (`OnboardingScript.practice`, the same for everyone) arrives in the
/// transmission console (`MessageCard`) with the board's timing, a capsule says it is ready and one button takes it to the teleprompter for a
/// practice run (09 §16). Nothing is written here and nothing waits for Apple Intelligence: the script is there when the chapter opens.
struct ScriptChapter: View {
    let model: OnboardingViewModel
    /// The opening plays (it does not in UI tests that don't ask for it, nor with Reduce Motion).
    var plays = true
    /// A second of the chapter to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    let onUse: () -> Void

    @State private var appearedAt = Date.now

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        MotionScreen(hold: 12, loops: true, frozenAt: frozenAt, plays: plays) { time in
            content(time)
        }
        .onAppear(perform: model.prepareScript)
    }

    // MARK: - Time

    /// The second of the board (`MessageTimeline`); a still chapter shows the last one.
    private func boardSecond(_ time: MotionTime) -> Double {
        if time.isStill, frozenAt == nil { return MessageTimeline.end }
        let arrived: Double? = model.script == nil ? nil : (frozenAt != nil ? 0 : model.readyAt.map { $0.timeIntervalSince(appearedAt) })
        return MessageTimeline.boardSecond(seconds: time.ambient, arrivedAt: arrived)
    }

    // MARK: - The chapter

    private func content(_ time: MotionTime) -> some View {
        let board = boardSecond(time)
        let waiting = model.script == nil
        return VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.script.chapterLabel, title: String(localized: "Your first script. Ready to read."),
                subtitle: String(localized: "Read it out loud on the teleprompter."), poses: [MotionPose(), MotionPose(), MotionPose()]
            )
            .padding(.horizontal, 20)
            Spacer(minLength: 0).frame(height: 20)
            MessageCard(script: model.script, platform: model.onboarding.platform, board: board, ambient: time.ambient)
                .padding(.horizontal, 16)
            MessageCapsule(board: board, ambient: time.ambient, label: String(localized: "SCRIPT READY · LET’S TRY IT"))
                .opacity(waiting ? 0 : 1)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            Text("It’s just practice. Nothing is recorded.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.inkHint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .opacity(Self.clip.pose(of: "L54", at: board).opacity)
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Try the teleprompter"), isEnabled: !waiting, shines: !waiting, identifier: "onboarding.useScript",
                action: onUse
            )
            .padding(.horizontal, 16)
            // The button comes in at 5.9 s.
            .motion(Self.clip.pose(of: "L55", at: board))
        }
    }
}
