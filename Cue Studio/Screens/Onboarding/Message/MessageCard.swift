//
//  MessageCard.swift
//  Cue Studio
//

import SwiftUI

/// The card of 1.4 (09 §16, made quieter with the owner 02/11/2026): a clean glass card with a thin edge, the platform on top with a ring of
/// progress and the reading time counting up as the script arrives word by word under HOOK, BODY and CTA, all in the same ink; when it is
/// all there a soft line of light runs down it once. No brackets, turning ring, rising specks or "PRACTICE SCRIPT · READY" header (the
/// script is fixed, no AI: no ✦).
struct MessageCard: View {
    let script: OnboardingScript?
    let platform: Platform
    /// The second of the board (`MessageTimeline`) and the time since the chapter appeared (for what runs on its own).
    let board: Double
    let ambient: Double
    /// The words' size: the chapter picks the largest that lets the page fit above its button (`MessageWordFit`).
    var wordSize: CGFloat = MessageWordFit.sizes[0]

    private static let clip = MotionLibrary.clip("1.4_first-message")

    var body: some View {
        let outer = Self.clip.pose(of: "L1", at: board)
        content
            // Its lines are typed into rows of the board's height: past the largest standard size they would run into each other.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.glassBorder, lineWidth: 0.75) }
            .shadow(color: Palette.Flight.cardShadow.opacity(0.45), radius: 25, y: 20)
            .motion(outer)
    }

    // MARK: - The card

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            destination
            messageBody.padding(.top, 18)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background { AuroraCardBackground(base: Palette.Universe.nightIndigo, cornerRadius: 22, isActive: false) }
        .overlay { scanLine }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - The destination

    private var destination: some View {
        HStack(spacing: 8) {
            Circle().fill(platform.tint).frame(width: 7, height: 7).shadow(color: platform.tint, radius: 4)
            Text("VIDEO FOR · \(platform.label.uppercased())")
                .monoFont(size: 10, weight: .semibold)
                .interfaceTracking(1)
                .foregroundStyle(Palette.Flight.quietInk)
                .lineLimit(1)
            Spacer(minLength: 0)
            progressRing
            Text(durationLabel)
                .monoFont(size: 10, weight: .semibold)
                .interfaceTracking(1)
                .monospacedDigit()
                .foregroundStyle(Palette.ink2)
        }
        .frame(height: 18)
        .motion(Self.clip.pose(of: "L21", at: board))
    }

    /// How long the script takes to read out loud at a natural pace (`OnboardingScript.readingSeconds`), "24 SEC", counting up with the ring
    /// as the words arrive.
    private var durationLabel: String {
        guard let script else { return "-- SEC" }
        let arrived = Self.clip.pose(of: "L22", at: board).drawn
        return String(localized: "\(Int((Double(script.readingSeconds) * arrived).rounded())) SEC")
    }

    /// 16 pt, in the platform's colour: it fills as the words arrive and ends in a check; before the script is there it is a spinner.
    private var progressRing: some View {
        let fill = Self.clip.pose(of: "L22", at: board).drawn
        let check = Self.clip.pose(of: "L23", at: board).opacity
        let waiting = script == nil
        return ZStack {
            Circle().stroke(Palette.ink3, lineWidth: 2)
            Circle()
                .trim(from: 0, to: waiting ? 0.14 : fill)
                .stroke(platform.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90 + (waiting ? ambient / 0.9 * 360 : 0)))
                .shadow(color: platform.tint.opacity(0.6), radius: 2)
            Image(systemName: "checkmark")
                .font(.fixed(7, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .opacity(check)
        }
        .frame(width: 12, height: 12)
        .padding(2)
    }

    // MARK: - The message

    /// The script at the size the chapter picked (`MessageWordFit`): the board's 21 pt when the page fits with it, smaller for a longer
    /// language or a shorter iPhone.
    @ViewBuilder
    private var messageBody: some View {
        if let script {
            parts(of: script, size: wordSize)
        }
    }

    private func parts(of script: OnboardingScript, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: size * 0.6) {
            // The same ink for every part (violet means AI in the app; this script is fixed), the same quiet label over each.
            part("HOOK", text: script.hook, part: .hook, labelLayer: "L25", size: size)
            if !script.body.isEmpty {
                part("BODY", text: script.body, part: .body, labelLayer: "L29", size: size)
            }
            part("CTA", text: script.cta, part: .cta, labelLayer: "L41", caret: Palette.ink2, size: size)
        }
    }

    private func part(
        _ label: LocalizedStringKey, text: String, part: MessageWords.Part, labelLayer: String, caret: Color? = nil, size: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .monoFont(size: 10, weight: .semibold)
                .interfaceTracking(1)
                .foregroundStyle(Palette.Flight.quietInk)
                .motion(Self.clip.pose(of: labelLayer, at: board))
            MessageWords(text: text, part: part, color: Palette.ink, board: board, caret: caret, ambient: ambient, size: size)
        }
    }

    // MARK: - Light on the card

    /// When the message is complete a soft line of light runs down the card once, 6.1–7.35 s.
    private var scanLine: some View {
        let pose = Self.clip.pose(of: "L14", at: board)
        return GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: Palette.Universe.starCream.opacity(0), location: 0), .init(color: Palette.Universe.starCream.opacity(0.4), location: 0.3),
                    .init(color: Palette.Universe.starCream.opacity(0.4), location: 0.7), .init(color: Palette.Universe.starCream.opacity(0), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 1)
            .shadow(color: Palette.Universe.starCream.opacity(0.4), radius: 8)
            .opacity(pose.opacity)
            .offset(y: proxy.size.height * (pose.topPct ?? 4) / 100)
        }
        .allowsHitTesting(false)
    }
}
