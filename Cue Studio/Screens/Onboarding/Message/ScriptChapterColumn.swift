//
//  ScriptChapterColumn.swift
//  Cue Studio
//

import SwiftUI

/// What 1.4 scrolls, when it must, above its note and button: the heading and the card with the practice script (`MessageCard`). The
/// chapter draws it at the second of the board, and measures it, standing still, at each of the words' sizes to pick the largest that fits
/// (`MessageWordFit`).
struct ScriptChapterColumn: View {
    let script: OnboardingScript?
    let platform: Platform
    /// The second of the board (`MessageTimeline`) and the time since the chapter appeared (for what runs on its own).
    let board: Double
    let ambient: Double
    /// The script's words' size (`MessageWordFit`).
    let wordSize: CGFloat

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
        }
        .padding(.bottom, 12)
    }
}
