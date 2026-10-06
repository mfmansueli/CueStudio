//
//  ReadingLineLayer.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie reading line: a layer of its own that stays put while the text scrolls past it. A
/// slim grip at its right end moves it (the text window follows); the grip hides while the text
/// plays or the camera records, so only the line is left.
struct ReadingLineLayer: View {
    let layout: ReadingLayout
    /// "READING LINE" above the line, while Display is open.
    let showsTag: Bool
    let showsHandle: Bool
    /// The voice level while recognition follows it (the horizon's glow flickers with it).
    var level: Double?
    /// Specks rise from the line while the text moves.
    var showsParticles = false
    /// The line's new position while dragging, in screen points.
    let onMove: (CGFloat) -> Void
    /// ↑ / ↓ from VoiceOver.
    let onNudge: (CGFloat) -> Void

    @State private var dragStart: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let handleTarget: CGFloat = 44
    private static let gripSize = CGSize(width: 14, height: 34)

    var body: some View {
        let span = layout.lineSpan
        ZStack(alignment: .topLeading) {
            ReadingGuide(level: level, showsParticles: showsParticles)
                .frame(width: span.upperBound - span.lowerBound)
                .position(x: (span.lowerBound + span.upperBound) / 2, y: layout.lineY)
            if showsTag || dragStart != nil {
                tag.position(x: span.lowerBound + 2, y: layout.lineY - 16)
            }
            if showsHandle || dragStart != nil {
                handle.position(x: handleX(span), y: layout.lineY)
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .animation(dragStart == nil ? .smooth(duration: 0.3) : nil, value: layout.lineY)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: showsHandle)
    }

    // MARK: - Parts

    private var tag: some View {
        let text = dragStart != nil
            ? String(localized: "READING LINE · \(Int(layout.lineOffset)) PT BELOW CAMERA")
            : String(localized: "READING LINE")
        return Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .kerning(0.7)
            .foregroundStyle(Palette.accText)
            .shadow(color: Palette.textShadow, radius: 1.5, y: 1)
            .fixedSize()
            // `position` centers its view: a zero-wide frame makes the tag start at the line's end.
            .frame(width: 0, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var handle: some View {
        let dragging = dragStart != nil
        let grip = RoundedRectangle(cornerRadius: Self.gripSize.width / 2, style: .continuous)
        return Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: Self.gripSize.width, height: Self.gripSize.height)
            .background(.ultraThinMaterial, in: grip)
            .background(dragging ? Palette.Camera.readingLineHandleActive : Palette.Camera.readingLineHandle, in: grip)
            .overlay(grip.strokeBorder(Palette.Camera.readingLineHandleBorder, lineWidth: 0.5))
            // A slim grip to look at, a full 44 pt to catch.
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

    /// Just past the line's right end, but never off screen.
    private func handleX(_ span: ClosedRange<CGFloat>) -> CGFloat {
        min(span.upperBound + 2 + Self.handleTarget / 2, layout.screenWidth - Self.handleTarget / 2)
    }
}
