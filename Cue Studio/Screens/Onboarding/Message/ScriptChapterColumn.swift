//
//  ScriptChapterColumn.swift
//  Cue Studio
//

import SwiftUI

/// What 1.4 shows above its button: the heading, the transmission console with the practice script (`MessageCard`), the capsule that says
/// it is ready and the line that says nothing is recorded. The chapter draws it at the second of the board, and measures it, standing still,
/// at each of the words' sizes to pick the largest that fits (`MessageWordFit`).
struct ScriptChapterColumn: View {
    let script: OnboardingScript?
    let platform: Platform
    /// The second of the board (`MessageTimeline`) and the time since the chapter appeared (for what runs on its own).
    let board: Double
    let ambient: Double
    /// The script's words' size (`MessageWordFit`).
    let wordSize: CGFloat

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.script.chapterLabel, title: String(localized: "Your first script. Ready to read."),
                subtitle: String(localized: "Read it out loud on the teleprompter."), poses: [MotionPose(), MotionPose(), MotionPose()]
            )
            .padding(.horizontal, 20)
            Spacer(minLength: 0).frame(height: 20)
            MessageCard(script: script, platform: platform, board: board, ambient: ambient, wordSize: wordSize)
                .padding(.horizontal, 16)
            MessageCapsule(board: board, ambient: ambient, label: String(localized: "SCRIPT READY · LET’S TRY IT"))
                .opacity(script == nil ? 0 : 1)
                .padding(.horizontal, 16)
                .padding(.top, 20)
            Text("It’s just practice. Nothing is recorded.")
                .cueFont(12.5)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .opacity(Self.clip.pose(of: "L54", at: board).opacity)
                .accessibilityIdentifier("onboarding.scriptNote")
        }
        .padding(.bottom, 12)
    }
}
