//
//  VoyageChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 2, 1.3: "Every video is a voyage." The camera pulls back from the creator's galaxy and the platforms' five galaxies are born
/// (`VoyageScene`); the creator picks one destination, a light crosses from "YOU" to it, and Cue sets the format, the length and the safe zones
/// for that galaxy (09 §15). Nothing is picked beforehand: the button says "Choose a galaxy" until a chip or a galaxy is tapped, and then
/// "Head to {platform}". Everything runs on one clock (`MotionScreen`); a tap anywhere jumps the opening to its end.
struct VoyageChapter: View {
    let onboarding: OnboardingService
    /// The opening plays (it does not in UI tests that don't ask for it, nor with Reduce Motion).
    var plays = true
    /// A second of the opening to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    /// UI tests: TikTok is picked and its light stands still at this age (seconds after the pick).
    var frozenPickAge: Double?
    let onContinue: () -> Void

    @Environment(PlatformRulesService.self) private var rules
    @Environment(SkyDirector.self) private var sky
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picked: Platform?
    @State private var pickedAt = Date.now
    @State private var firstPickedAt: Date?

    private static let clip = MotionLibrary.clip("1.3_voyage")
    /// Everything of the opening is in place (the button has landed at 3.3 s).
    private static let openingEnd = 3.4
    private static let births: [(second: Double, isLast: Bool)] = [(1.1, false), (1.4, false), (1.7, false), (2.0, false), (2.3, true)]

    var body: some View {
        MotionScreen(hold: Self.openingEnd, loops: true, skippable: true, frozenAt: frozenAt, plays: plays) { time in
            content(time)
        }
        .task(id: plays) { await openingHaptics() }
        .task(id: frozenPickAge) {
            if frozenPickAge != nil, picked == nil { picked = .tiktok }
        }
        .onDisappear { sky.pose = MotionPose() }
    }

    // MARK: - Time

    /// Seconds since the pick, or nil while nothing is picked.
    private func pickAge(_ time: MotionTime) -> Double? {
        guard picked != nil else { return nil }
        return frozenPickAge ?? time.now.timeIntervalSince(pickedAt)
    }

    private func pose(_ layer: String, _ second: Double) -> MotionPose { Self.clip.pose(of: layer, at: second) }

    // MARK: - The chapter

    private func content(_ time: MotionTime) -> some View {
        let clock = time.clock
        let age = pickAge(time)
        // The sky pulls back less than the foreground, and drifts once, with the first light that crosses it.
        let skyClock = firstPickedAt.map { 3.4 + (frozenPickAge ?? time.now.timeIntervalSince($0)) } ?? clock
        return ZStack {
            VoyageScene(time: time, picked: picked, pickAge: age, onTapGalaxy: choose)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeading(
                    label: OnboardingStep.voyage.chapterLabel, title: String(localized: "Every video is a voyage."),
                    subtitle: String(localized: "Where is it headed? Cue sets format, length and safe zones."),
                    poses: ["L2", "L3", "L4"].map { pose($0, clock) }
                )
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
                destination(time, age: age)
                Spacer(minLength: 0).frame(height: 74)
                OnboardingPrimaryButton(
                    title: String(localized: "Head to \(picked?.label ?? onboarding.platform.label)"),
                    disabledTitle: String(localized: "Choose a galaxy"), isEnabled: picked != nil,
                    identifier: "onboarding.continue", action: onContinue
                )
                .padding(.horizontal, 16)
                .motion(pose("L83", clock))
            }
        }
        .onChange(of: skyClock) { _, second in sky.pose = Self.clip.pose(of: "L1", at: second) }
        .onAppear { sky.pose = Self.clip.pose(of: "L1", at: skyClock) }
    }

    /// The line, the chips and the hint under them (a mono line saying what to do, five chips, the format for the choice).
    private func destination(_ time: MotionTime, age: Double?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            line(time)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            FlowLayout(spacing: 8, lineSpacing: 2) {
                ForEach(Platform.primary) { platform in
                    VoyageChip(platform: platform, isPicked: picked == platform, pickAge: picked == platform ? age : nil) { choose(platform) }
                }
            }
            .padding(.horizontal, 20)
            .motion(pose("L79", time.clock))
            hint(age: age)
                .padding(.horizontal, 20)
                .padding(.top, 5)
        }
    }

    /// "PICK ONE DESTINATION" until a pick, then "TIKTOK · TAP ANOTHER TO SWITCH" in yellow.
    private func line(_ time: MotionTime) -> some View {
        let arrived = pose("L77", min(time.clock, 3)).opacity
        return ZStack(alignment: .leading) {
            Text("PICK ONE DESTINATION")
                .foregroundStyle(Color.white.opacity(0.82))
                .opacity(picked == nil ? 1 : 0)
                .accessibilityHidden(picked != nil)
            Text("\((picked ?? onboarding.platform).label.uppercased()) · TAP ANOTHER TO SWITCH")
                .foregroundStyle(Palette.Universe.starGold)
                .opacity(picked == nil ? 0 : 1)
                .accessibilityHidden(picked == nil)
        }
        // One line for VoiceOver: the one that shows.
        .accessibilityElement(children: .combine)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .tracking(1.2)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(height: 18)
        .opacity(arrived)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: picked)
        .accessibilityIdentifier("onboarding.formatLine")
    }

    /// "9:16 · IDEAL 1:00–1:30 · SAFE ZONES ON", typed in 34 steps once the light has landed (the board's `clip-path` reveal).
    private func hint(age: Double?) -> some View {
        let text = hintText
        let revealed = age.map { 1 - (pose("L82", $0 + VoyageScene.pickClock).clipRight ?? 1) } ?? 0
        return Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1)
            .foregroundStyle(Palette.Flight.ink.opacity(0.6))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .mask(alignment: .leading) { GeometryReader { Rectangle().frame(width: $0.size.width * revealed) } }
            .frame(minHeight: 14)
            .accessibilityHidden(picked == nil)
            .accessibilityIdentifier("onboarding.formatHint")
    }

    private var hintText: String {
        guard let picked else { return "" }
        let preset = rules.preset(for: picked, monetizationGoals: true)
        let range = "\(DurationText.clock(preset.idealRange.lowerBound))–\(DurationText.clock(preset.idealRange.upperBound))"
        return "\(preset.aspect.label) · \(String(localized: "IDEAL")) \(range) · \(String(localized: "SAFE ZONES ON"))"
    }

    // MARK: - Picking

    /// A chip or a galaxy was tapped: it is the destination (one at a time), the light starts, the hand answers.
    private func choose(_ platform: Platform) {
        guard picked != platform else { return }
        Haptics.soft()
        onboarding.platform = platform
        picked = platform
        pickedAt = .now
        if firstPickedAt == nil { firstPickedAt = .now }
        Task {
            // The light lands 2.4 s after the tap (it leaves 0.4 s later and takes 2 s).
            try? await Task.sleep(for: .seconds(2.4))
            if picked == platform, !Task.isCancelled { Haptics.success() }
        }
    }

    /// The hand feels each galaxy being born: a soft tap each, the last a lighter one (09 §15).
    private func openingHaptics() async {
        guard plays, frozenAt == nil, !reduceMotion else { return }
        let start = Date.now
        for birth in Self.births {
            let wait = birth.second - Date.now.timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled { return }
            if birth.isLast { Haptics.light() } else { Haptics.soft() }
        }
    }
}
