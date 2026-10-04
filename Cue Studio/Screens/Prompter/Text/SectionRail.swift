//
//  SectionRail.swift
//  Cue Studio
//

import SwiftUI

/// A 2 pt rail on the right edge of the text with a star for each section (Hook · Body · CTA). The rail fills
/// with the reading; entering a section pops its star (1.7 → 1 in 0.55 s, a selection haptic) and the label under
/// the text changes with it.
struct SectionRail: View {
    let sections: PrompterSections
    /// The section being read, and how far through the whole script (0...1).
    let current: Int
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var popped: Int?

    private static let width: CGFloat = 2
    private static let star: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            ZStack(alignment: .top) {
                Capsule().fill(Color.white.opacity(0.18)).frame(width: Self.width)
                Capsule()
                    .fill(Palette.acc)
                    .frame(width: Self.width, height: max(0, height * min(1, max(0, progress))))
                    .shadow(color: Palette.acc.opacity(0.6), radius: 3)
                ForEach(Array(sections.markers.enumerated()), id: \.offset) { index, _ in
                    star(index: index, at: height * Self.position(of: index, of: sections.markers.count))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: Self.star + 4)
        .onChange(of: current) { old, new in
            guard new > old else { return }
            Haptics.selection()
            guard !reduceMotion else { return }
            popped = new
            Task {
                try? await Task.sleep(for: .milliseconds(550))
                if popped == new { popped = nil }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.55), value: popped)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text("Section"))
        .accessibilityValue(Text(sections.title(at: current)))
        .accessibilityIdentifier("prompter.sectionRail")
    }

    /// Where a star sits along the rail, from the top (0) to the bottom (1): evenly, the first at the start.
    static func position(of index: Int, of count: Int) -> Double {
        count > 1 ? Double(index) / Double(count - 1) : 0
    }

    private func star(index: Int, at y: CGFloat) -> some View {
        let reached = index <= current
        return Circle()
            .fill(reached ? Palette.acc : Color.white.opacity(0.3))
            .frame(width: Self.star, height: Self.star)
            .shadow(color: reached ? Palette.acc.opacity(0.8) : .clear, radius: 4)
            .scaleEffect(popped == index ? 1.7 : 1)
            .offset(y: y - Self.star / 2)
            .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// "HOOK · 1 OF 3" under the text, changing with a crossfade as the reading moves on.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(CueStudioFont.hud)
            .tracking(1.2)
            .foregroundStyle(Palette.accText)
            .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: title)
            .accessibilityHidden(true)
    }
}
