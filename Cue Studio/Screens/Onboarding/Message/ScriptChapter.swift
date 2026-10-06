//
//  ScriptChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 3, 1.4: "Your first message to new worlds." The first script is written in the topic the creator picked, for the galaxy they
/// chose, and arrives in a transmission console (`MessageCard`); a capsule says it is ready for launch and one button loads it in the
/// teleprompter (09 §16). When the model is slow the card shows a skeleton and says so (1.4b); the way out is a built-in message, offered after
/// 15 s and used by itself after 25 s. Without a model the built-in message is shown from the start.
struct ScriptChapter: View {
    let model: OnboardingViewModel
    /// The opening plays (it does not in UI tests that don't ask for it, nor with Reduce Motion).
    var plays = true
    /// A second of the chapter to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    let onUse: () -> Void

    @Environment(ToastService.self) private var toast
    @State private var appearedAt = Date.now

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        MotionScreen(hold: 12, loops: true, frozenAt: frozenAt, plays: plays) { time in
            content(time)
        }
        .onAppear { if model.scriptState == .idle { model.writeScript() } }
        .onDisappear { model.cancelWriting() }
        .onChange(of: model.fellBackByItself) { _, fell in
            if fell { toast.show(String(localized: "Message ready")) }
        }
    }

    // MARK: - Time

    /// The second of the board, which waits for the message (`MessageTimeline`); a still chapter shows the last one.
    private func boardSecond(_ time: MotionTime) -> Double {
        if time.isStill, frozenAt == nil { return MessageTimeline.end }
        let arrived: Double? = model.script == nil ? nil : (frozenAt != nil ? 0 : model.readyAt.map { $0.timeIntervalSince(appearedAt) })
        return MessageTimeline.boardSecond(seconds: time.ambient, arrivedAt: arrived)
    }

    // MARK: - The chapter

    private func content(_ time: MotionTime) -> some View {
        let board = boardSecond(time)
        let waited = time.ambient
        let waiting = model.script == nil
        let isSlow = waiting && waited > MessageTimeline.slowAfter
        return VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.script.chapterLabel, title: String(localized: "Your first message to new worlds."),
                subtitle: String(localized: "You will read it on the teleprompter."), poses: [MotionPose(), MotionPose(), MotionPose()]
            )
            .padding(.horizontal, 20)
            Spacer(minLength: 0).frame(height: 24)
            MessageCard(
                script: model.script, platform: model.onboarding.platform, topic: model.onboarding.mainTopic, isSlow: isSlow,
                board: board, ambient: time.ambient
            )
            .padding(.horizontal, 16)
            ZStack {
                MessageCapsule(board: board, ambient: time.ambient, label: String(localized: "MESSAGE READY FOR LAUNCH"))
                    .opacity(waiting ? 0 : 1)
                slowNote(isSlow: isSlow)
            }
            .padding(.horizontal, 16)
            .padding(.top, 23)
            Text("Written on this iPhone. Nothing leaves it.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.inkHint)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .opacity(Self.clip.pose(of: "L54", at: board).opacity)
            readyMade(isOffered: waiting && waited > MessageTimeline.readyMadeAfter)
            Spacer(minLength: 0)
            OnboardingPrimaryButton(
                title: String(localized: "Load in teleprompter"), disabledTitle: String(localized: "Load in teleprompter"),
                isEnabled: !waiting, shines: !waiting, identifier: "onboarding.useScript", action: onUse
            )
            .padding(.horizontal, 16)
            // The button comes in at 5.9 s; when the model is slow it is already there, dimmed, with the rest of the wait.
            .motion(isSlow ? MotionPose() : Self.clip.pose(of: "L55", at: board))
        }
        .animation(.easeOut(duration: 0.25), value: isSlow)
    }

    /// "Taking a little longer…" and "Your message is on its way." in the capsule's place while the skeleton stands in for the message.
    private func slowNote(isSlow: Bool) -> some View {
        VStack(spacing: 2) {
            Text("Taking a little longer…")
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(Palette.flightInk.opacity(0.82))
                .frame(height: 22)
            Text("Your message is on its way.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.inkHint)
        }
        .opacity(isSlow ? 1 : 0)
        .accessibilityHidden(!isSlow)
    }

    /// After 15 s: a yellow text button that loads the built-in message for the topic.
    @ViewBuilder
    private func readyMade(isOffered: Bool) -> some View {
        Button(String(localized: "Use a ready-made message")) { model.useReadyMade() }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.starGold)
            .frame(maxWidth: .infinity, minHeight: 40)
            .buttonStyle(.plain)
            .opacity(isOffered ? 1 : 0)
            .offset(y: isOffered ? 0 : 8)
            .allowsHitTesting(isOffered)
            .accessibilityHidden(!isOffered)
            .accessibilityIdentifier("onboarding.readyMade")
    }
}
