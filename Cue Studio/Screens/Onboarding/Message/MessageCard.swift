//
//  MessageCard.swift
//  Cue Studio
//

import SwiftUI

/// The transmission console of 1.4 (09 §16): the card the first message is written in. A ring of light turns round its edge while it writes
/// (2.8 s a turn), four brackets close on it, specks of light rise, the destination and a ring of progress sit under the header, and the
/// message arrives word by word under HOOK, BODY and CTA; when it is written a line of light sweeps down it. The model's slowness shows
/// as a skeleton in place of the words (1.4b).
struct MessageCard: View {
    let script: OnboardingScript?
    let platform: Platform
    let topic: OnboardingTopic?
    /// The model has kept the creator waiting past 6 s: grey bars stand for the message.
    let isSlow: Bool
    /// The second of the board (`MessageTimeline`) and the time since the chapter appeared (for what runs on its own).
    let board: Double
    let ambient: Double

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        let outer = Self.clip.pose(of: "L1", at: board)
        content
            .padding(2)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.Universe.nightViolet.mix(with: Palette.Flight.lilac, by: 0.5).opacity(0.32))
            }
            .overlay { ring }
            .shadow(color: Palette.Flight.cardShadow.opacity(0.45), radius: 25, y: 20)
            .shadow(color: Palette.Universe.nightViolet.opacity(0.22), radius: 17)
            .motion(outer)
    }

    // MARK: - The card

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            destination.padding(.top, 12)
            messageBody.padding(.top, 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, minHeight: 327, alignment: .topLeading)
        .background { AuroraCardBackground(base: Palette.Universe.nightIndigo, cornerRadius: 22, isActive: false) }
        .overlay { brackets }
        .overlay { risingSpecks }
        .overlay { scanLine }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// The ring of light that turns round the edge while the message is written: a comet of violet, yellow and white on the card's border.
    private var ring: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    stops: [
                        .init(color: Palette.Flight.lilac.opacity(0), location: 0), .init(color: Palette.Flight.lilac.opacity(0), location: 190 / 360),
                        .init(color: Palette.Flight.lilac, location: 270 / 360), .init(color: Palette.acc, location: 318 / 360),
                        .init(color: Palette.Universe.starCream, location: 332 / 360), .init(color: Palette.Universe.starLilac, location: 345 / 360),
                        .init(color: Palette.Flight.lilac.opacity(0), location: 1),
                    ],
                    center: .center, angle: .degrees(ambient / 2.8 * 360)
                ),
                lineWidth: 2
            )
            .opacity(Self.clip.pose(of: "L2", at: board).opacity)
            .allowsHitTesting(false)
    }

    // MARK: - Header and destination

    private var header: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                writingLabel
                    .opacity(Self.clip.pose(of: "L15", at: board).opacity)
                Text(readyLabel)
                    .foregroundStyle(Palette.Universe.starLilac)
                    .motion(Self.clip.pose(of: "L20", at: board))
            }
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .tracking(1.05)
            .frame(maxWidth: .infinity, alignment: .leading)
            topicPill
        }
        .frame(height: 22)
    }

    /// "✦ WRITING YOUR MESSAGE" with the light crossing it and three dots that bob.
    private var writingLabel: some View {
        HStack(spacing: 0) {
            Text("✦ WRITING YOUR MESSAGE")
                .foregroundStyle(Palette.aiText)
                .overlay { shimmer }
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let dot = Self.clip.pose(of: "L\(17 + index)", at: ambient, loops: true)
                    Circle().fill(Palette.aiText).frame(width: 2.5, height: 2.5).motion(dot)
                }
            }
            .padding(.leading, 4)
            .padding(.top, 4)
        }
    }

    private var shimmer: some View {
        let position = Self.clip.pose(of: "L16", at: ambient, loops: true).bgX ?? 100
        return GeometryReader { proxy in
            let center = proxy.size.width * (1 - (position + 140) / 240)
            LinearGradient(colors: [.clear, .white, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: proxy.size.width * 0.5)
                .offset(x: center - proxy.size.width * 0.25)
        }
        .mask { Text("✦ WRITING YOUR MESSAGE") }
        .allowsHitTesting(false)
    }

    private var readyLabel: String {
        if script?.isCurated == true { return String(localized: "✦ READY · BUILT-IN") }
        return String(localized: "✦ READY FOR \(platform.label.uppercased()) · 15S")
    }

    private var topicPill: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(OnboardingTopic.color(at: 0))
                .frame(width: 3, height: 14)
                .shadow(color: OnboardingTopic.color(at: 0).opacity(0.6), radius: 4)
            Text(topic?.label ?? "")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Palette.Universe.nightDeep.opacity(0.45), in: Capsule())
        .opacity(topic == nil ? 0 : 1)
    }

    private var destination: some View {
        HStack(spacing: 8) {
            Circle().fill(platform.tint).frame(width: 7, height: 7).shadow(color: platform.tint, radius: 4)
            Text("DESTINATION · \(platform.label.uppercased())")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.Flight.ink.opacity(0.72))
                .lineLimit(1)
            Spacer(minLength: 0)
            progressRing
            Text(durationLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.Universe.starGold)
        }
        .frame(height: 18)
        .motion(Self.clip.pose(of: "L21", at: board))
    }

    private var durationLabel: String {
        guard let script else { return "-- S" }
        let seconds = max(1, Int((Double(MessageWords.displayed(script.text).split(whereSeparator: \.isWhitespace).count) / 2.5).rounded()))
        return String(localized: "\(seconds) S")
    }

    /// 16 pt: it fills as the words arrive and ends in a check; while the model hasn't answered it is a spinner.
    private var progressRing: some View {
        let fill = Self.clip.pose(of: "L22", at: board).drawn
        let check = Self.clip.pose(of: "L23", at: board).opacity
        let waiting = script == nil
        return ZStack {
            Circle().stroke(Palette.Flight.ink.opacity(0.22), lineWidth: 2)
            Circle()
                .trim(from: 0, to: waiting ? 0.14 : fill)
                .stroke(Palette.Universe.starGold, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90 + (waiting ? ambient / 0.9 * 360 : 0)))
                .shadow(color: Palette.acc.opacity(0.7), radius: 2)
            Image(systemName: "checkmark")
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(Palette.Universe.starGold)
                .opacity(check)
        }
        .frame(width: 12, height: 12)
        .padding(2)
    }

    // MARK: - The message

    @ViewBuilder
    private var messageBody: some View {
        if let script {
            VStack(alignment: .leading, spacing: 14) {
                part("HOOK", text: script.hook, part: .hook, tint: Palette.accText, color: .white, labelLayer: "L25")
                if !script.body.isEmpty {
                    part("BODY", text: script.body, part: .body, tint: Palette.Flight.ink.opacity(0.6), color: .white, labelLayer: "L29")
                }
                part(
                    "CTA", text: script.cta, part: .cta, tint: Palette.Flight.ink.opacity(0.6),
                    color: script.isCurated ? .white : Palette.Flight.lilac, labelLayer: "L41", caret: Palette.Flight.lilac
                )
            }
        } else if isSlow {
            MessageSkeleton().transition(.opacity)
        }
    }

    private func part(_ label: String, text: String, part: MessageWords.Part, tint: Color, color: Color, labelLayer: String, caret: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(tint)
                .motion(Self.clip.pose(of: labelLayer, at: board))
            MessageWords(text: text, part: part, color: color, board: board, caret: caret, ambient: ambient)
        }
    }

    // MARK: - Light on the card

    /// Four brackets close on the card (×1.5 → ×1, 0.8–1.4 s).
    private var brackets: some View {
        let pose = Self.clip.pose(of: "L3", at: board)
        return GeometryReader { proxy in
            ForEach(0..<4, id: \.self) { corner in
                Bracket()
                    .stroke(Palette.Universe.starGold.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .scaleEffect(x: corner % 2 == 0 ? 1 : -1, y: corner < 2 ? 1 : -1)
                    .motion(pose)
                    .position(
                        x: corner % 2 == 0 ? 8 + 7 : proxy.size.width - 8 - 7,
                        y: corner < 2 ? 8 + 7 : proxy.size.height - 8 - 7
                    )
            }
        }
        .allowsHitTesting(false)
    }

    private nonisolated struct Bracket: Shape {
        nonisolated func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0.75, y: 14))
            path.addLine(to: CGPoint(x: 0.75, y: 6))
            path.addQuadCurve(to: CGPoint(x: 6, y: 0.75), control: CGPoint(x: 0.75, y: 0.75))
            path.addLine(to: CGPoint(x: 14, y: 0.75))
            return path
        }
    }

    /// Specks of light that rise from the bottom of the card while it writes (about 34 pt each, on their own cycles).
    private var risingSpecks: some View {
        let specks = Self.specks
        let visible = Self.clip.pose(of: "L7", at: board).opacity
        return GeometryReader { proxy in
            ForEach(Array(specks.enumerated()), id: \.offset) { _, speck in
                let phase = max(0, ambient - speck.delay).truncatingRemainder(dividingBy: speck.cycle) / speck.cycle
                let eased = UnitCurve.easeOut.value(at: phase)
                let opacity = phase < 0.2 ? phase / 0.2 * 0.95 : 0.95 * (1 - (phase - 0.2) / 0.8)
                Circle()
                    .fill(speck.color)
                    .frame(width: speck.size, height: speck.size)
                    .shadow(color: speck.color, radius: 3)
                    .opacity(ambient > speck.delay ? opacity * visible : 0)
                    .position(x: speck.left + speck.dx * eased, y: proxy.size.height - speck.bottom - 34 * eased)
            }
        }
        .allowsHitTesting(false)
    }

    /// A speck of light that rises from the card's bottom: where (from the left, from the bottom), how big, its colour, how far it drifts
    /// sideways, its cycle and when its first one starts.
    private struct Speck {
        let left: Double
        let bottom: Double
        let size: Double
        let color: Color
        let dx: Double
        let cycle: Double
        let delay: Double
    }

    private static let specks = [
        Speck(left: 40, bottom: 30, size: 2, color: Palette.Universe.starLilac, dx: -4, cycle: 2.2, delay: 0),
        Speck(left: 120, bottom: 50, size: 2.5, color: Palette.Universe.starGold, dx: 6, cycle: 2.6, delay: 0.5),
        Speck(left: 200, bottom: 20, size: 2, color: Palette.Universe.starLilac, dx: -6, cycle: 2.0, delay: 1.0),
        Speck(left: 260, bottom: 60, size: 1.6, color: .white, dx: 4, cycle: 2.8, delay: 0.3),
        Speck(left: 300, bottom: 26, size: 2.2, color: Palette.Flight.lilac, dx: -3, cycle: 2.4, delay: 1.4),
        Speck(left: 80, bottom: 90, size: 1.6, color: .white, dx: 5, cycle: 2.1, delay: 0.8),
    ]

    /// When the message is complete a line of light sweeps down the card, 6.1–7.35 s.
    private var scanLine: some View {
        let pose = Self.clip.pose(of: "L14", at: board)
        return GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: Palette.acc.opacity(0), location: 0), .init(color: Palette.acc.opacity(0.75), location: 0.3),
                    .init(color: Palette.acc.opacity(0.75), location: 0.7), .init(color: Palette.acc.opacity(0), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1.5)
            .shadow(color: Palette.acc.opacity(0.55), radius: 6)
            .opacity(pose.opacity)
            .offset(y: proxy.size.height * (pose.topPct ?? 4) / 100)
        }
        .allowsHitTesting(false)
    }
}
