//
//  StarTransitionWords.swift
//  Cue Studio
//

import SwiftUI

/// The words under the star while the AI writes (09 §8; the owner's refinement, 03/11/2026), in two groups. What is written: who writes
/// it, in small spaced capitals ("✦ ULTRA AI", "IN YOUR VOICE", or "APPLE INTELLIGENCE" when the script isn't in the creator's voice), and
/// the idea, the largest words on the screen, whole up to three lines (two on a short screen), smaller before it is cut. How far it is:
/// the phrase, which arrives word by word out of the AI's light and leaves upward, blurring; under it the number, which counts through
/// every value up to where the writing is and brightens with each quarter's tick (Ultra AI's with each step, which it says: "STEP 2 OF 3").
///
/// The idea's words ran into the star as it left the dock; they come back here one by one, after the cover, plainly (they are the
/// creator's, so without the AI's glow). Reduce Motion: the words are simply there, and the number changes in place.
struct StarTransitionWords: View {
    let isUltra: Bool
    /// The script is written in the creator's voice; otherwise the eyebrow names Apple Intelligence (as the page's pill says "Drafting…").
    var inYourVoice = true
    let idea: String
    let ideaLines: Int
    let phrase: String
    let phraseShown: Bool
    /// The first phrase: it waits for the idea's first words before it arrives.
    let phraseWaits: Bool
    /// Changes when the words come up, so the idea's words and the first phrase arrive then.
    let arrival: Int
    let meter: WritingProgressMeter?
    /// Ultra AI's pass the phrase says (from 0) and how many there are.
    let step: Int
    let steps: Int
    /// Changes with each quarter's tick, or each Ultra AI step: the number brightens with it.
    let pulse: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            eyebrow
            ideaWords
                .padding(.top, 8)
            phraseLine
                .padding(.top, 18)
            meterLine
                .padding(.top, 6)
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - What is written

    private var eyebrow: some View {
        HStack(spacing: 5) {
            if isUltra { Image(systemName: "sparkle") }
            Text(isUltra ? "ULTRA AI" : inYourVoice ? "in your voice" : "Apple Intelligence")
                .textCase(.uppercase)
        }
        .monoFont(size: 11.5, weight: .semibold)
        .tracking(1.4)
        .foregroundStyle(Palette.Scripts.transitionPhrase)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isUltra ? "Drafting with Ultra AI" : inYourVoice ? "Drafting in your voice" : "Drafting…"))
        .accessibilityAddTraits(.isHeader)
    }

    private var ideaWords: some View {
        WordsFromLight(
            text: String(localized: "“\(idea)”"), font: .cue(20, weight: .semibold, for: dynamicTypeSize), color: Palette.ink,
            stagger: Self.ideaStagger, trigger: arrival, glows: false
        )
        .tracking(-0.3)
        .lineSpacing(2)
        .lineLimit(ideaLines)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: 320)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - How far it is

    /// One line, kept while the phrase changes, so nothing under it moves.
    private var phraseLine: some View {
        let font = Font.cue(15.5, weight: .medium, for: dynamicTypeSize).italic()
        return ZStack {
            Text(verbatim: " ").font(font).hidden()
            WordsFromLight(
                text: phrase, font: font, color: Palette.Scripts.transitionPhrase, stagger: Self.phraseStagger, trigger: arrival,
                delay: phraseWaits ? Self.phraseDelay : 0
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .opacity(phraseShown ? 1 : 0)
            .offset(y: phraseShown || reduceMotion ? 0 : -5)
            .blur(radius: phraseShown || reduceMotion ? 0 : 3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// The number (and Ultra AI's step); its room is kept before the page starts writing, so nothing moves when it comes.
    private var meterLine: some View {
        ZStack {
            Text(verbatim: " ").hidden()
            HStack(spacing: 7) {
                if isUltra, steps > 1 {
                    Text("Step \(step + 1) of \(steps)")
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.ink2)
                        .contentTransition(reduceMotion ? .identity : .numericText(value: Double(step)))
                        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: step)
                    if meter != nil {
                        Text(verbatim: "·")
                            .foregroundStyle(Palette.ink2)
                            .accessibilityHidden(true)
                    }
                }
                if let meter { percent(meter) }
            }
        }
        .monoFont(size: 12, weight: .semibold)
    }

    private func percent(_ meter: WritingProgressMeter) -> some View {
        let calm = Palette.Scripts.transitionInk
        let lit = Palette.ink
        let grows: CGFloat = reduceMotion ? 0 : 0.08
        // A few looks a second: the words arriving update it as they come; the clock only matters while the model reads.
        return TimelineView(.animation(minimumInterval: 0.25, paused: meter.isFinished)) { _ in
            let fraction = meter.fraction
            CountingPercent(value: fraction)
                .animation(reduceMotion ? nil : .smooth(duration: Self.countDuration), value: fraction)
        }
        .keyframeAnimator(initialValue: 0.0, trigger: pulse) { content, glow in
            content
                .foregroundStyle(calm.mix(with: lit, by: glow))
                .scaleEffect(1 + grows * glow)
        } keyframes: { _ in
            CubicKeyframe(1, duration: 0.12)
            CubicKeyframe(0, duration: 0.55)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Written so far"))
        .accessibilityValue(Text(meter.fraction, format: WritingProgressLabel.format))
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("transition.progress")
    }

    /// Seconds between the idea's words, and the phrase's (the AI's, a little slower, as in the dock).
    private static let ideaStagger = 0.035
    private static let phraseStagger = 0.05
    /// The first phrase waits for the idea's first words before it arrives.
    private static let phraseDelay = 0.3
    /// Seconds the number takes to count to a new value.
    private static let countDuration = 0.6
}
