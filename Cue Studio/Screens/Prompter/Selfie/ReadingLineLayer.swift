//
//  ReadingLineLayer.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie reading line: a layer of its own that stays put while the text scrolls past it. A
/// handle at its right end moves it (the text window follows); the first time, a tip explains it.
struct ReadingLineLayer: View {
    let layout: ReadingLayout
    /// "READING LINE" above the line, while Display is open.
    let showsTag: Bool
    let showsTip: Bool
    /// The line's new position while dragging, in screen points.
    let onMove: (CGFloat) -> Void
    /// ↑ / ↓ from VoiceOver.
    let onNudge: (CGFloat) -> Void
    let onDismissTip: () -> Void

    @State private var dragStart: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let arrowSize: CGFloat = 10
    private static let handleTarget: CGFloat = 44

    var body: some View {
        let span = layout.lineSpan
        ZStack(alignment: .topLeading) {
            ReadingGuide(arrowSize: Self.arrowSize, lineOpacity: 0.7, lineWidth: 2, glows: true)
                .frame(width: span.upperBound - span.lowerBound)
                .position(x: (span.lowerBound + span.upperBound) / 2, y: layout.lineY)
            if showsTag || dragStart != nil {
                tag.position(x: span.lowerBound + 2, y: layout.lineY - 16)
            }
            handle.position(x: handleX(span), y: layout.lineY)
            if showsTip {
                tip.position(x: layout.screenWidth / 2, y: layout.lineY + 16 + 38)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .animation(dragStart == nil ? .smooth(duration: 0.3) : nil, value: layout.lineY)
        .animation(.spring(duration: 0.3), value: showsTip)
    }

    // MARK: - Parts

    private var tag: some View {
        let text = dragStart != nil
            ? String(localized: "READING LINE · \(Int(layout.lineOffset)) PT BELOW CAMERA")
            : String(localized: "READING LINE")
        return Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .kerning(0.7)
            .foregroundStyle(Palette.acc)
            .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
            .fixedSize()
            // `position` centers its view: a zero-wide frame makes the tag start at the line's end.
            .frame(width: 0, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var handle: some View {
        let dragging = dragStart != nil
        return Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(dragging ? Palette.readingLineHandleActive : Palette.readingLineHandle, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.readingLineHandleBorder, lineWidth: 0.5))
            .frame(width: Self.handleTarget, height: Self.handleTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let start = dragStart ?? layout.lineY
                        if dragStart == nil { dragStart = start }
                        onMove(start + value.translation.height)
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Reading line"))
            .accessibilityValue(Text("\(Int(layout.lineOffset)) points below the camera"))
            .accessibilityHint(Text("Drag to move where you read"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onNudge(-ReadingLayout.nudge)
                case .decrement: onNudge(ReadingLayout.nudge)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("prompter.readingLineHandle")
    }

    private var tip: some View {
        Button(action: onDismissTip) {
            VStack(spacing: 4) {
                Text("Don’t read the text. Talk to the line.")
                    .font(.subheadline.weight(.bold))
                Text("It sits just under your camera, so your eyes stay on your viewer. Drag the handle to move it.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
            .frame(width: 228)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(Palette.tipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.accBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Dismisses the tip"))
        .accessibilityIdentifier("prompter.readingLineTip")
    }

    /// Just past the line's right end, but never off screen.
    private func handleX(_ span: ClosedRange<CGFloat>) -> CGFloat {
        min(span.upperBound + 2 + Self.handleTarget / 2, layout.screenWidth - Self.handleTarget / 2)
    }
}
