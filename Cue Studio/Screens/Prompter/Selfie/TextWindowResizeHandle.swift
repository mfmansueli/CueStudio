//
//  TextWindowResizeHandle.swift
//  Cue Studio
//

import SwiftUI

/// The corner of the Selfie text window: drag it to make the window wider, narrower, taller or
/// shorter (it stays centered), double-tap to put the original size back. While the finger is
/// down the window gets a yellow outline and a label says the width and the lines.
struct TextWindowResizeHandle: View {
    let viewModel: PrompterViewModel
    let layout: ReadingLayout
    @Binding var isResizing: Bool

    @State private var start: (width: Double, height: Double)?
    @State private var resize: TextWindowResize?

    private static let target: CGFloat = 44
    private static let glyph: CGFloat = 14
    /// Keeps the corner mark inside the window's rounded corner.
    private static let cornerInset: CGFloat = 10

    var body: some View {
        let rect = layout.windowRect
        ZStack {
            if let resize {
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
                Text(resize.label)
                    .font(CueStudioFont.hud)
                    .foregroundStyle(Palette.accText)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Palette.posterPill, in: Capsule())
                    .position(x: rect.midX, y: max(60, rect.minY - 20))
                    .allowsHitTesting(false)
            }
            handle.position(x: rect.maxX - Self.cornerInset - Self.glyph / 2, y: rect.maxY - Self.cornerInset - Self.glyph / 2)
        }
        .ignoresSafeArea()
    }

    private var handle: some View {
        CornerMark()
            .stroke(Palette.acc, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .frame(width: Self.glyph, height: Self.glyph)
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .frame(width: Self.target, height: Self.target)
            .contentShape(Rectangle())
            .gesture(drag)
            .simultaneousGesture(TapGesture(count: 2).onEnded { viewModel.resetTextWindow() })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Resize text window"))
            .accessibilityValue(Text(accessibilityValue))
            .accessibilityHint(Text("Drag to resize. Double-tap to reset."))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.nudgeTextWindowHeight(byLines: 1)
                case .decrement: viewModel.nudgeTextWindowHeight(byLines: -1)
                @unknown default: break
                }
            }
            .accessibilityAction(named: Text("Reset text window")) { viewModel.resetTextWindow() }
            .accessibilityIdentifier("prompter.textWindowResizeHandle")
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                let from = start ?? (viewModel.session.prompter.readingWidth, viewModel.session.prompter.textWindowHeight)
                if start == nil {
                    start = from
                    isResizing = true
                }
                resize = viewModel.resizeTextWindow(from: from, by: value.translation)
            }
            .onEnded { _ in
                start = nil
                resize = nil
                isResizing = false
            }
    }

    private var accessibilityValue: String {
        let prompter = viewModel.session.prompter
        let lines = max(1, Int((prompter.textWindowHeight / (prompter.size * prompter.lineSpacing)).rounded()))
        return String(localized: "\(Int((prompter.readingWidth * 100).rounded())) percent wide, \(lines) lines")
    }
}

/// The "L" in the window's bottom-right corner: a right edge and a bottom edge joined by a rounded corner.
private nonisolated struct CornerMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 6
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}
