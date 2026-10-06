//
//  YearInReviewView.swift
//  Cue Studio
//

import SwiftUI

/// 9.2 · Your {year} in review: a full-screen story of up to 5 slides, 3.2 s each, with 3 pt bars on top. A tap on the right half goes on, on the left
/// half goes back, the ✕ closes; the last slide has **Share my {year}**. Reduce Motion: the bars don't fill and nothing advances by itself.
struct YearInReviewView: View {
    let stats: YearStats
    let isSealed: Bool
    let onShare: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var slideStart = Date.now
    @State private var slideShown = false
    /// The whole story fades in over 0.3 s (9.2 · "Year in review · open") and out over 0.2 s.
    @State private var visible = false

    /// How long a slide stays (the board's 3.2 s).
    static let slideDuration: TimeInterval = 3.2

    private var slides: [YearStats.Slide] { stats.slides }
    private var isLast: Bool { index >= slides.count - 1 }

    var body: some View {
        ZStack {
            background
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
                let progress = reduceMotion ? 1 : min(1, context.date.timeIntervalSince(slideStart) / Self.slideDuration)
                VStack(spacing: 0) {
                    YearInReviewBars(count: slides.count, index: index, progress: progress)
                        .padding(.horizontal, 12)
                        .padding(.top, 7)
                    Spacer()
                }
                .onChange(of: progress >= 1) { _, done in
                    if done, !reduceMotion { advance() }
                }
            }
            if slides.indices.contains(index) {
                YearInReviewSlideView(slide: slides[index], stats: stats, isSealed: isSealed)
                    .id(index)
                    .opacity(slideShown ? 1 : 0)
                    .scaleEffect(slideShown ? 1 : 0.94)
            }
            taps
            VStack {
                HStack {
                    Spacer()
                    Button(action: close) { Image(systemName: "xmark") }
                        .buttonStyle(.cueIcon(.glass, diameter: 44))
                        .accessibilityLabel(Text("Close"))
                        .accessibilityIdentifier("yearInReview.close")
                }
                .padding(.horizontal, 16)
                .padding(.top, 19)
                Spacer()
                footer
            }
        }
        .preferredColorScheme(.dark)
        .opacity(visible ? 1 : 0)
        .presentationBackground(.clear)
        .onAppear {
            show()
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 0.3)) { visible = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("yearInReview.screen")
    }

    // MARK: - Pieces

    private var background: some View {
        ZStack {
            Palette.Universe.nightDeep
            RadialGradient(colors: [Palette.Universe.nightViolet.opacity(0.32), .clear], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 360)
        }
        .ignoresSafeArea()
    }

    /// The left half goes back and the right half goes on, under the ✕ and the button.
    private var taps: some View {
        HStack(spacing: 0) {
            Color.clear.contentShape(Rectangle()).onTapGesture { back() }.accessibilityHidden(true)
            Color.clear.contentShape(Rectangle()).onTapGesture { advance() }
                .accessibilityLabel(Text("Next"))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("yearInReview.next")
        }
        .padding(.top, 80)
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private var footer: some View {
        if isLast {
            Button { onShare(); close() } label: { Text("Share my \(String(stats.year))").frame(maxWidth: .infinity) }
                .buttonStyle(.cuePrimary(.large))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .accessibilityIdentifier("yearInReview.share")
        } else {
            Text("TAP TO CONTINUE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.inkHint)
                .padding(.bottom, 24)
        }
    }

    /// Fades out (0.2 s) and then lets the screen go.
    private func close() {
        withAnimation(.easeOut(duration: 0.2)) { visible = false }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 200))
            onClose()
        }
    }

    // MARK: - Moving between slides

    private func show() {
        slideShown = false
        slideStart = .now
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.4)) { slideShown = true }
    }

    private func advance() {
        guard !isLast else { return }
        index += 1
        show()
    }

    private func back() {
        guard index > 0 else { return }
        index -= 1
        show()
    }
}
