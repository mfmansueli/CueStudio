//
//  ScriptChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 3, 1.4: "Your first script. Ready to read." The practice script (`OnboardingScript.practice`, the same for everyone) arrives in its
/// card (`MessageCard`) with the board's timing, a soft tap for each part and a success when it is all there; a quiet line says it is just
/// practice, and the button, glass while the words arrive, lights up then and takes it to the teleprompter for a practice run (09 §16). A
/// tap anywhere jumps to the end. Nothing is written here and nothing waits for Apple Intelligence: the script is there when the chapter
/// opens.
struct ScriptChapter: View {
    let model: OnboardingViewModel
    /// The opening plays (it does not in UI tests that don't ask for it, nor with Reduce Motion).
    var plays = true
    /// A second of the chapter to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    let onUse: () -> Void

    @State private var appearedAt = Date.now
    /// The height of the column above the button at each of the words' sizes, measured on the whole script, standing still
    /// (`MessageWordFit`), and the height there is for it.
    @State private var columnHeights: [CGFloat: CGFloat] = [:]
    @State private var available: CGFloat = 0

    private static let hold = 12.0
    /// The board's seconds at which HOOK, BODY and CTA come in and the check closes the script (`1.4_first-message` L25, L29, L41, L23).
    private static let arrivals = [1.45, 2.4, 4.6, 5.5]

    var body: some View {
        let fit = MessageWordFit.choice(heights: columnHeights, available: available)
        MotionScreen(hold: Self.hold, loops: true, skippable: true, frozenAt: frozenAt, plays: plays) { time in
            content(time, fit: fit)
        }
        // Measured outside the clock, so the page that redraws every frame never measures the script again; the size is chosen from the
        // whole script (not the words typed so far), so it never changes while the words arrive.
        .background { measurement }
        .onAppear(perform: model.prepareScript)
    }

    /// The column at each size, laid out at the chapter's width and its own height, never drawn.
    private var measurement: some View {
        let script = model.script ?? .practice()
        return ZStack(alignment: .top) {
            ForEach(MessageWordFit.sizes, id: \.self) { size in
                ScriptChapterColumn(script: script, platform: model.onboarding.platform, board: MessageTimeline.end, ambient: 0, wordSize: size)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeights[size] = $0 }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Time

    /// The second of the board (`MessageTimeline`); a still chapter shows the last one.
    private func boardSecond(_ time: MotionTime) -> Double {
        // Still, or a tap skipped to the end (the clock is at `hold` long before the board would be).
        if time.isStill && frozenAt == nil || time.clock >= Self.hold { return MessageTimeline.end }
        let arrived: Double? = model.script == nil ? nil : (frozenAt != nil ? 0 : model.readyAt.map { $0.timeIntervalSince(appearedAt) })
        return MessageTimeline.boardSecond(seconds: time.ambient, arrivedAt: arrived)
    }

    // MARK: - The chapter

    private func content(_ time: MotionTime, fit: MessageWordFit.Choice) -> some View {
        let board = boardSecond(time)
        let arrived = Self.arrivals.filter { board >= $0 }.count
        let ready = model.script != nil && arrived == Self.arrivals.count
        return VStack(spacing: 0) {
            // The page fits above the button at the largest size of the words that lets it (`MessageWordFit`); only when even the smallest
            // doesn't (an iPhone SE, a large text size) do the words scroll, and the button stays at the bottom.
            ScrollView {
                ScriptChapterColumn(script: model.script, platform: model.onboarding.platform, board: board, ambient: time.ambient, wordSize: fit.size)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDisabled(!fit.scrolls)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { available = $0 }
            .accessibilityIdentifier("onboarding.scriptPage")
            Text("It’s just practice. Nothing is recorded.")
                .cueFont(12.5)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .accessibilityIdentifier("onboarding.scriptNote")
            OnboardingPrimaryButton(
                title: String(localized: "Try the teleprompter"), disabledStyle: .glass, isEnabled: ready, shines: ready,
                identifier: "onboarding.useScript", action: onUse
            )
            .padding(.horizontal, 16)
        }
        .onChange(of: arrived) { before, now in
            guard now > before else { return }
            if now == Self.arrivals.count { Haptics.success() } else { Haptics.soft() }
        }
    }
}
