//
//  UniverseChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 1: "This is your universe." The creator picks what they talk about (up to three) and each topic
/// is born as a world in orbit around them ("YOU"): a ripple, a spark to the orbit, the orbit drawing,
/// the planet popping, its name.
struct UniverseChapter: View {
    let onboarding: OnboardingService
    let onContinue: () -> Void

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
    /// The topics typed with "+ Your own", kept in the list as chips (picked or not) so they can be picked again.
    @State private var customTopics: [OnboardingTopic] = []

    private var topicChoices: [OnboardingTopic] { Niche.allCases.map(OnboardingTopic.niche) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingHeading(
                label: OnboardingStep.universe.chapterLabel, title: String(localized: "This is your universe."),
                subtitle: String(localized: "Pick what you talk about. Each topic becomes a world around you.")
            )
            .padding(.horizontal, 20)
            UniverseCanvas(topics: onboarding.topics, born: born)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120, maxHeight: 280)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Your universe"))
                .accessibilityValue(Text(onboarding.topics.map(\.label).joined(separator: ", ")))
            VStack(alignment: .leading, spacing: 10) {
                OnboardingCaption(text: countLabel)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(topicChoices) { topic in chip(topic) }
                    ForEach(customTopics) { topic in chip(topic) }
                    yourOwnChip
                }
                if let customFeedback { feedbackView(customFeedback) }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Continue"), isEnabled: onboarding.canContinueFromTopics,
                identifier: "onboarding.continue", action: onContinue
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .alert("Your own topic", isPresented: $isNamingTopic) {
            TextField("Budget travel", text: $customName)
            Button("Add") { addCustom() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var countLabel: String {
        let count = onboarding.topics.count
        return count >= OnboardingTopic.limit
            ? String(localized: "\(count) OF \(OnboardingTopic.limit) · TAP TO CHANGE")
            : String(localized: "\(count) OF \(OnboardingTopic.limit) · TAP TO ADD")
    }

    private func chip(_ topic: OnboardingTopic) -> some View {
        let index = onboarding.topics.firstIndex(of: topic)
        let isPicked = index != nil
        return Button {
            pick(topic)
        } label: {
            HStack(spacing: 8) {
                if let index { Circle().fill(OnboardingTopic.color(at: index)).frame(width: 10, height: 10) }
                Text(topic.label)
            }
            .font(.system(size: 17, weight: isPicked ? .semibold : .medium))
            .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.ink)
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(isPicked ? Palette.chipOn : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(topic.label))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("onboarding.topic.\(topic.id)")
    }

    private var yourOwnChip: some View {
        Button {
            customName = ""
            customFeedback = nil
            isNamingTopic = true
        } label: {
            Text("+ Your own")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .overlay(Capsule().strokeBorder(Palette.ink3, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding.topic.own")
    }

    private func pick(_ topic: OnboardingTopic) {
        let wasPicked = onboarding.isPicked(topic)
        Haptics.selection()
        onboarding.toggle(topic)
        if !wasPicked {
            born[topic.id] = .now
            Task {
                try? await Task.sleep(for: .milliseconds(1300))
                Haptics.success()
            }
        }
    }

    private func addCustom(keepingTyped: Bool = false) {
        let existing = onboarding.topics.map(\.label)
        let vocabulary = keepingTyped ? [] : topicChoices.map(\.label)
        switch VoiceTextValidator.check(customName, existing: existing, vocabulary: vocabulary) {
        case .accepted(let name):
            customFeedback = nil
            let before = Set(onboarding.topics.map(\.id))
            onboarding.addCustom(name)
            for topic in onboarding.topics where !before.contains(topic.id) { born[topic.id] = .now }
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

/// The creator as a white star ("YOU") with rays, and a world on its own tilted orbit for each topic.
struct UniverseCanvas: View {
    let topics: [OnboardingTopic]
    let born: [String: Date]
    /// When the first video's star was lit, if it was: a yellow star above the orbits with a line to the creator.
    var star: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate, now: context.date)
            }
        }
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval, now: Date) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // The halo and the rays of the star.
        canvas.fill(
            Path(ellipseIn: CGRect(x: center.x - 70, y: center.y - 70, width: 140, height: 140)),
            with: .radialGradient(Gradient(colors: [Color(hex: 0x9D8CFF).opacity(0.45), .clear]), center: center, startRadius: 0, endRadius: 70)
        )
        for ray in 0..<12 {
            let angle = Double(ray) * .pi / 6 + time * 0.05
            var line = Path()
            line.move(to: CGPoint(x: center.x + cos(angle) * 20, y: center.y + sin(angle) * 20))
            line.addLine(to: CGPoint(x: center.x + cos(angle) * 46, y: center.y + sin(angle) * 46))
            canvas.stroke(line, with: .color(.white.opacity(0.22)), lineWidth: 1)
        }
        canvas.fill(Path(ellipseIn: CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)), with: .color(.white))
        canvas.draw(
            Text("YOU").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.inkHint),
            at: CGPoint(x: center.x, y: center.y + 30)
        )
        if let star { drawStar(from: star, in: &canvas, center: center, size: size, now: now) }
        // A world per topic.
        for (index, topic) in topics.enumerated() {
            let age = born[topic.id].map { now.timeIntervalSince($0) } ?? 5
            drawWorld(topic, index: index, age: age, in: &canvas, center: center, size: size, time: time)
        }
    }

    /// The first video, shared or saved: a four-point yellow star joined to "YOU" by a thin line that draws itself.
    private func drawStar(from lit: Date, in canvas: inout GraphicsContext, center: CGPoint, size: CGSize, now: Date) {
        let age = now.timeIntervalSince(lit)
        guard age > 0 else { return }
        let place = CGPoint(x: center.x + size.width * 0.16, y: center.y - size.height * 0.38)
        var link = Path()
        link.move(to: center)
        link.addLine(to: place)
        canvas.stroke(link.trimmedPath(from: 0, to: min(1, age / 0.8)), with: .color(Palette.acc.opacity(0.5)), lineWidth: 1)
        let pop = min(1, age / 0.5)
        let radius = 11 * (pop < 0.6 ? pop / 0.6 * 1.5 : 1.5 - (pop - 0.6) / 0.4 * 0.5)
        var star = Path()
        for step in 0..<8 {
            let length = step.isMultiple(of: 2) ? radius : radius * 0.26
            let angle = Double(step) * .pi / 4 - .pi / 2
            let corner = CGPoint(x: place.x + length * cos(angle), y: place.y + length * sin(angle))
            if step == 0 { star.move(to: corner) } else { star.addLine(to: corner) }
        }
        star.closeSubpath()
        var glow = canvas
        glow.addFilter(.shadow(color: Palette.acc.opacity(0.9), radius: 8))
        glow.fill(star, with: .color(Palette.acc))
        if age > 0.6 {
            canvas.draw(
                Text(String(localized: "FIRST TAKE · TODAY")).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.accText),
                at: CGPoint(x: place.x, y: place.y - 22)
            )
        }
    }

    private func drawWorld(
        _ topic: OnboardingTopic, index: Int, age: TimeInterval, in canvas: inout GraphicsContext,
        center: CGPoint, size: CGSize, time: TimeInterval
    ) {
        let color = OnboardingTopic.color(at: index)
        let radiusX = min(size.width * 0.28, 70 + CGFloat(index) * 44)
        let radiusY = radiusX * 0.42
        let tilt = Angle.degrees(-14 + Double(index) * 11)
        // The orbit draws between 0.45 s and 1.45 s after the pick.
        let drawn = min(1, max(0, (age - 0.45) / 1.0))
        var orbit = Path(ellipseIn: CGRect(x: -radiusX, y: -radiusY, width: radiusX * 2, height: radiusY * 2))
        orbit = orbit.applying(CGAffineTransform(rotationAngle: tilt.radians).concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        canvas.stroke(orbit.trimmedPath(from: 0, to: drawn), with: .color(color.opacity(0.4)), lineWidth: 1)
        // The planet pops at 1.2 s: 0 → 1.4 → 1.
        let pop = min(1, max(0, (age - 1.2) / 0.5))
        guard pop > 0 else {
            // The spark that flies to the orbit.
            let flight = min(1, max(0, (age - 0.1) / 0.6))
            if flight > 0 {
                let target = CGPoint(x: center.x + radiusX * cos(tilt.radians), y: center.y + radiusX * sin(tilt.radians))
                let point = CGPoint(x: size.width * 0.5 + (target.x - size.width * 0.5) * flight, y: size.height + (target.y - size.height) * flight)
                canvas.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(color))
            }
            return
        }
        let speed = 0.25 + Double(index) * 0.08
        let angle = Double(index) * 2.1 + time * speed
        let local = CGPoint(x: radiusX * cos(angle), y: radiusY * sin(angle))
        let cosT = cos(tilt.radians), sinT = sin(tilt.radians)
        let point = CGPoint(x: center.x + local.x * cosT - local.y * sinT, y: center.y + local.x * sinT + local.y * cosT)
        let scale = pop < 1 ? (pop < 0.6 ? pop / 0.6 * 1.4 : 1.4 - (pop - 0.6) / 0.4 * 0.4) : 1
        let diameter = 18 * scale
        canvas.fill(
            Path(ellipseIn: CGRect(x: point.x - diameter / 2, y: point.y - diameter / 2, width: diameter, height: diameter)),
            with: .radialGradient(
                Gradient(colors: [.white.opacity(0.9), color, color.opacity(0.6)]),
                center: CGPoint(x: point.x - diameter * 0.2, y: point.y - diameter * 0.2), startRadius: 0, endRadius: diameter
            )
        )
        // Its name, just after.
        if age > 1.7 {
            canvas.draw(
                Text(topic.label.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color),
                at: CGPoint(x: point.x, y: point.y + diameter / 2 + 9)
            )
        }
    }
}
