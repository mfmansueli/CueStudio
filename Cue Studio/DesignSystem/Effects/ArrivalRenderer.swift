//
//  ArrivalRenderer.swift
//  Cue Studio
//

import SwiftUI

/// Draws the words of `ArrivingText` arriving: each run marked with its word's `ArrivalIndex` rises from blur with a fading violet glow,
/// a run marked with a `TextChip` gets its chip drawn behind it (arriving with its word, so a cue looks as it will in the editor), and
/// a violet caret blinks after the last word to have started.
struct ArrivalRenderer: TextRenderer {
    var now: Double
    var arrivals: [Double]
    var reduceMotion: Bool
    var chipMetrics: TextChipMetrics

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // The caret follows the last word that has started to arrive, and sits at the start of the page until one does.
        var caretAt: CGRect?
        var chipsStarted: Set<Int> = []
        for line in layout {
            drawChips(on: line, in: context, started: &chipsStarted)
            for run in line {
                guard let mark = run[ArrivalIndex.self] else { context.draw(run); continue }
                let state = arrival(of: mark.index)
                let bounds = run.typographicBounds.rect
                if caretAt == nil { caretAt = CGRect(x: bounds.minX, y: bounds.minY, width: 0, height: bounds.height) }
                if state.progress > 0 { caretAt = CGRect(x: bounds.maxX, y: bounds.minY, width: 0, height: bounds.height) }
                var copy = arriving(context, progress: state.progress)
                if state.glow > 0, state.progress > 0 {
                    copy.addFilter(.shadow(color: Color(hex: 0xC4B8FF, opacity: 0.95 * state.glow), radius: 14 * state.glow))
                }
                copy.draw(run)
            }
        }
        guard let caretAt else { return }
        // `blink 1s`: lit for the first half of every second, in the AI's violet.
        let lit = reduceMotion || now.truncatingRemainder(dividingBy: 1) < 0.5
        var caret = context
        caret.opacity = lit ? 1 : 0
        caret.addFilter(.shadow(color: Palette.aiText.opacity(0.9), radius: 6))
        caret.fill(Path(CGRect(x: caretAt.minX + 1, y: caretAt.minY + 2, width: 2, height: caretAt.height - 4)), with: .color(Color(hex: 0xB4A7FF)))
    }

    /// How far a word has arrived (0…1) and how much of its glow is left.
    private func arrival(of index: Int) -> (progress: Double, glow: Double) {
        let age = index < arrivals.count ? now - arrivals[index] : 0
        let progress = reduceMotion ? min(1, max(0, age / 0.2)) : Self.ease(min(1, max(0, age / ArrivingText.arrive)))
        let glow = reduceMotion ? 0 : max(0, 1 - max(0, age - ArrivingText.arrive) / ArrivingText.glowFade)
        return (progress, glow)
    }

    /// The context a word is drawn in while it arrives: faded in, and (with motion) rising 5 pt out of a 7 pt blur.
    private func arriving(_ context: GraphicsContext, progress: Double) -> GraphicsContext {
        var copy = context
        copy.opacity = progress
        if !reduceMotion {
            copy.translateBy(x: 0, y: 5 * (1 - progress))
            copy.addFilter(.blur(radius: 7 * (1 - progress)))
        }
        return copy
    }

    /// The chips on a line, behind their words: one per chip, from its first run to its last (a cue's brackets, name and kern are
    /// separate runs), with its symbol on the line where it starts (`started`: the chips already drawn on a line above).
    private func drawChips(on line: Text.Layout.Line, in context: GraphicsContext, started: inout Set<Int>) {
        var chips: [(chip: TextChip, index: Int?, minX: CGFloat, maxX: CGFloat)] = []
        for run in line {
            guard let chip = run[TextChip.self] else { continue }
            let bounds = run.typographicBounds.rect
            if let last = chips.indices.last, chips[last].chip == chip {
                chips[last].maxX = max(chips[last].maxX, bounds.maxX)
            } else {
                chips.append((chip, run[ArrivalIndex.self]?.index, bounds.minX, bounds.maxX))
            }
        }
        let baseline = line.typographicBounds.origin.y
        for chip in chips {
            let progress = chip.index.map { arrival(of: $0).progress } ?? 1
            guard progress > 0 else { continue }
            let rect = chipMetrics.chipRect(from: chip.minX, to: chip.maxX, baseline: baseline)
            let isStart = started.insert(chip.chip.id).inserted
            drawChip(chip.chip, in: rect, context: arriving(context, progress: progress), withSymbol: isStart)
        }
    }

    private func drawChip(_ chip: TextChip, in rect: CGRect, context: GraphicsContext, withSymbol: Bool) {
        let radius = chipMetrics.cornerRadius
        let rim = TextChipMetrics.rimWidth
        context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(Palette.Cues.chipFill))
        context.stroke(
            Path(roundedRect: rect.insetBy(dx: rim / 2, dy: rim / 2), cornerRadius: radius - rim / 2),
            with: .color(Palette.Cues.chipRim),
            lineWidth: rim
        )
        guard withSymbol, let symbol = chip.symbol else { return }
        let image = Text(Image(systemName: symbol))
            .font(.system(size: chipMetrics.symbolPointSize, weight: .semibold))
            .foregroundStyle(Palette.Cues.chipInk)
        context.draw(context.resolve(image), at: chipMetrics.symbolCentre(symbol, in: rect), anchor: .center)
    }

    /// `cubic-bezier(.16, 1, .3, 1)`, close enough as an ease-out.
    private static func ease(_ t: Double) -> Double {
        1 - pow(1 - t, 3.4)
    }
}
