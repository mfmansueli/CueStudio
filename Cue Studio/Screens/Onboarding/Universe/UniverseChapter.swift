//
//  UniverseChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 1: "This is your universe." The creator picks what they talk about (up to three) and each topic is born as a world in orbit
/// around them ("YOU"): the chip lights, a light travels from it to its orbit and lands in sparks and rings, the planet pops, the orbit draws
/// and its name arrives (`TopicBirth`). The yellow ring that opens round the core on entry carries on from the star of 1.1.
struct UniverseChapter: View {
    let onboarding: OnboardingService
    /// The opening plays (it does not in UI tests that don't ask for it, nor with Reduce Motion).
    var plays = true
    /// A second of the opening to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    /// UI tests: three topics are picked and the last one's birth stands still at this age (seconds after the pick).
    var birthFrozenAge: Double?
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isNamingTopic = false
    @State private var customName = ""
    /// What the typed topic got wrong (04 · F9, 1.2): a refused word, or a "did you mean".
    @State private var customFeedback: CustomFeedback?

    private enum CustomFeedback: Equatable {
        case message(String)
        case typo(suggestion: String, original: String)
    }
    /// When each topic was picked, to play its birth.
    @State private var born: [String: Date] = [:]
    /// The births playing now: where each light leaves from and lands, in this chapter's space.
    @State private var births: [TopicBirth] = []
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var canvasFrame = CGRect.zero
    /// The universe's place on the screen, where the opening's star lands.
    @State private var canvasOnScreen = CGRect.zero
    /// The topics typed with "+ Your own", kept in the list as chips (picked or not) so they can be picked again.
    @State private var customTopics: [OnboardingTopic] = []

    private nonisolated static let space = "universeChapter"
    private static let clip = MotionLibrary.clip("1.2_topics")
    /// The opening is over (Continue has landed at 2.5 s); the star lands on the core at 1.25 s.
    private static let openingEnd = 2.6
    private static let landing = 1.25
    /// Where the board's star lands in its 390 × 844 frame, and where it comes from: the flight is bent toward the real core.
    private static let boardCore = CGPoint(x: 195, y: 366)
    private var topicChoices: [OnboardingTopic] { Niche.offered.map(OnboardingTopic.niche) }

    var body: some View {
        MotionScreen(hold: Self.openingEnd, skippable: true, frozenAt: frozenAt, plays: plays) { time in
            content(time)
        }
        .task(id: plays) { await landingHaptic() }
        .task(id: birthFrozenAge) { await pickForPictures() }
    }

    /// UI tests taking pictures of a birth: two topics are already worlds and the third was just picked (its birth stands still).
    private func pickForPictures() async {
        guard birthFrozenAge != nil, onboarding.topics.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(600))
        for niche in [Niche.lifestyle, .finance, .travel] {
            let topic = OnboardingTopic.niche(niche)
            onboarding.toggle(topic)
            if let index = onboarding.topics.firstIndex(of: topic) {
                born[topic.id] = niche == .travel ? .now : .distantPast
                if niche == .travel { beginBirth(of: topic, at: index, now: .now) }
            }
        }
    }

    private func content(_ time: MotionTime) -> some View {
        let clock = time.clock
        return VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.universe.chapterLabel, title: String(localized: "This is your universe."),
                subtitle: String(localized: "Pick your topics. Each one becomes a world."),
                poses: ["L1", "L2", "L3"].map { Self.clip.pose(of: $0, at: clock) }
            )
            .padding(.horizontal, 20)
            OnboardingUniverseCanvas(topics: onboarding.topics, born: born, opening: time, frozenBirthAge: birthFrozenAge)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120, maxHeight: 300)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { canvasFrame = $0 }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { canvasOnScreen = $0 }
                .motion(Self.clip.pose(of: "L4", at: clock))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Your universe"))
                .accessibilityValue(Text(onboarding.topics.map(\.label).joined(separator: ", ")))
            VStack(alignment: .leading, spacing: 8) {
                TopicCounter(colors: onboarding.topics.indices.map(OnboardingTopic.color(at:)))
                FlowLayout(spacing: 6, lineSpacing: -6) {
                    ForEach(topicChoices) { topic in chip(topic) }
                    ForEach(customTopics) { topic in chip(topic) }
                    yourOwnChip
                }
                if let customFeedback { feedbackView(customFeedback) }
            }
            .padding(.horizontal, 20)
            .motion(Self.clip.pose(of: "L74", at: clock))
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Continue"), disabledTitle: String(localized: "Pick a topic"), disabledStyle: .grey,
                isEnabled: onboarding.canContinueFromTopics, identifier: "onboarding.continue", action: onContinue
            )
            .overlay { TopicContinuePulse(since: births.last?.tap).padding(.horizontal, -1) }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .motion(Self.clip.pose(of: "L91", at: clock))
        }
        .coordinateSpace(name: Self.space)
        .overlay { TopicBirthOverlay(births: births, frozenAge: birthFrozenAge) }
        .overlay { openingStar(at: clock) }
        .alert("Your own topic", isPresented: $isNamingTopic) {
            TextField("Budget travel", text: $customName)
            Button("Add") { addCustom() }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// The star of 1.1 comes in from the top right, crosses the title and lands on the core with a soft tap of the hand (09 §14b). The board's
    /// path ends at (195, 366); here its last stretch bends toward the core wherever this screen put it.
    private func openingStar(at clock: Double) -> some View {
        let toCore = CGPoint(x: canvasOnScreen.midX - Self.boardCore.x, y: canvasOnScreen.midY - Self.boardCore.y)
        let poses = ["L73", "L72", "L71", "L70"].map { id -> MotionPose in
            var pose = Self.clip.pose(of: id, at: clock)
            let weight = min(max((430 - pose.tx) / (430 - Self.boardCore.x), 0), 1)
            pose.tx += toCore.x * weight
            pose.ty += toCore.y * weight
            return pose
        }
        // The poses are from the screen's top left; this overlay starts where the chapter does, below the progress bar.
        return GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            StarTrail(poses: poses).offset(x: -origin.x, y: -origin.y)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// The hand feels the star land on the core.
    private func landingHaptic() async {
        guard plays, frozenAt == nil, !reduceMotion else { return }
        try? await Task.sleep(for: .seconds(Self.landing))
        if !Task.isCancelled { Haptics.soft() }
    }

    private func chip(_ topic: OnboardingTopic) -> some View {
        let index = onboarding.topics.firstIndex(of: topic)
        return OnboardingTopicChip(
            title: topic.label, color: index.map(OnboardingTopic.color(at:)), tap: born[topic.id],
            isDimmed: onboarding.isFull && index == nil, identifier: "onboarding.topic.\(topic.id)"
        ) {
            pick(topic)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { chipFrames[topic.id] = $0 }
    }

    private var yourOwnChip: some View {
        Button {
            customName = ""
            customFeedback = nil
            isNamingTopic = true
        } label: {
            Text("+ Your own")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 11)
                .frame(height: 32)
                .overlay(Capsule().strokeBorder(Palette.ink3, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .opacity(onboarding.isFull ? 0.4 : 1)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.topic.own")
    }

    private func pick(_ topic: OnboardingTopic) {
        let wasPicked = onboarding.isPicked(topic)
        // Three are picked: another can't be, and the hand says so (a picked one is let go first).
        if onboarding.isFull, !wasPicked {
            Haptics.light()
            return
        }
        Haptics.apply()
        onboarding.toggle(topic)
        guard !wasPicked, let index = onboarding.topics.firstIndex(of: topic) else { return }
        let now = Date.now
        born[topic.id] = now
        beginBirth(of: topic, at: index, now: now)
    }

    /// The light leaves the chip's centre and lands on the planet's orbit, where the planet will be 1.4 s from now.
    private func beginBirth(of topic: OnboardingTopic, at index: Int, now: Date) {
        guard !reduceMotion, let chip = chipFrames[topic.id], canvasFrame != .zero else { return }
        let landing = OnboardingUniverseCanvas.worldPoint(
            index: index, in: canvasFrame.size, time: now.timeIntervalSinceReferenceDate + TopicBirth.landing
        )
        let target = CGPoint(x: canvasFrame.minX + landing.x, y: canvasFrame.minY + landing.y)
        let birth = TopicBirth(
            color: OnboardingTopic.color(at: index), tap: now, from: CGPoint(x: chip.midX, y: chip.midY), to: target,
            core: CGPoint(x: canvasFrame.midX, y: canvasFrame.midY)
        )
        births = births.filter { now.timeIntervalSince($0.tap) < TopicBirth.duration } + [birth]
    }

    private func addCustom(keepingTyped: Bool = false) {
        let existing = onboarding.topics.map(\.label)
        let vocabulary = keepingTyped ? [] : topicChoices.map(\.label)
        switch VoiceTextValidator.check(customName, existing: existing, vocabulary: vocabulary) {
        case .accepted(let name):
            customFeedback = nil
            let before = Set(onboarding.topics.map(\.id))
            onboarding.addCustom(name)
            for (index, topic) in onboarding.topics.enumerated() where !before.contains(topic.id) {
                born[topic.id] = .now
                beginBirth(of: topic, at: index, now: .now)
            }
            // The topic joins the list as a chip, even if it is let go of later.
            for topic in onboarding.topics {
                if case .custom = topic, !customTopics.contains(topic) { customTopics.append(topic) }
            }
            customName = ""
        case .typo(let suggestion, let original):
            customFeedback = .typo(suggestion: suggestion, original: original)
        case .duplicate:
            customFeedback = .message(String(localized: "Already added."))
        case let other:
            customFeedback = other.message.map(CustomFeedback.message)
        }
    }

    @ViewBuilder
    private func feedbackView(_ feedback: CustomFeedback) -> some View {
        switch feedback {
        case .message(let text):
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.warnText)
                .accessibilityIdentifier("onboarding.topic.feedback")
        case .typo(let suggestion, let original):
            HStack(spacing: 10) {
                Text("Did you mean “\(suggestion)”?")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink)
                Button("Use") {
                    customName = suggestion
                    addCustom()
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.accText)
                Button("Keep mine") {
                    customName = original
                    addCustom(keepingTyped: true)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("onboarding.topic.feedback")
        }
    }
}
