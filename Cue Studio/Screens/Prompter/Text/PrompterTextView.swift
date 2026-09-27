//
//  PrompterTextView.swift
//  Cue Studio
//

import SwiftUI

/// The scrolling script. Only this view reads the scroll offset, so the rest of the screen doesn't
/// redraw every frame. Drag to scroll by hand; tap to play or pause when `onTap` is set.
struct PrompterTextView: View {
    let viewModel: PrompterViewModel
    let settings: PrompterSettings
    let viewportHeight: CGFloat
    var guideArrowSize: CGFloat = 9
    var onTap: (() -> Void)?

    @State private var lastTranslation: CGFloat = 0

    private var guideY: CGFloat { viewportHeight * settings.guidePosition }

    var body: some View {
        let lineHeight = viewModel.lineHeight
        Paragraphs(
            paragraphs: viewModel.paragraphs,
            settings: settings,
            fontSize: viewModel.fontSize,
            onParagraphFrame: { viewModel.updateParagraphFrame($1, at: $0) }
        )
            .equatable()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                viewModel.updateLayout(contentHeight: height)
            }
            .offset(y: guideY - lineHeight / 2 - viewModel.engine.offset)
            .frame(maxWidth: .infinity)
            .frame(height: viewportHeight, alignment: .top)
            .scaleEffect(x: settings.isMirrored ? -1 : 1, y: 1)
            .clipped()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .overlay(alignment: .top) {
                if settings.showsGuide {
                    ReadingGuide(arrowSize: guideArrowSize)
                        .offset(y: guideY - guideArrowSize * 0.66)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        viewModel.drag(by: value.translation.height - lastTranslation)
                        lastTranslation = value.translation.height
                    }
                    .onEnded { _ in lastTranslation = 0 }
            )
            .onTapGesture { onTap?() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Script"))
            .accessibilityValue(Text(viewModel.engine.progress, format: .percent.precision(.fractionLength(0))))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.jump(lines: 3)
                case .decrement: viewModel.jump(lines: -3)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("prompter.text")
    }

    /// The text itself. Equatable so scrolling never re-lays it out.
    private struct Paragraphs: View, Equatable {
        let paragraphs: [String]
        let settings: PrompterSettings
        let fontSize: Double
        /// Where each paragraph sits (index, top..<bottom), so Voice follow can put a word on the guide.
        let onParagraphFrame: (Int, Range<Double>) -> Void

        private nonisolated static let space = "prompter.paragraphs"

        var body: some View {
            VStack(alignment: settings.alignment.horizontalAlignment, spacing: fontSize * settings.lineSpacing * 0.75) {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                    Text(CueAttributedText.make(
                        paragraph,
                        showsCues: settings.showsCues,
                        cueFont: settings.font.font(size: fontSize * 0.5).weight(.bold)
                    ))
                    .font(settings.font.font(size: fontSize))
                    .fontWeight(.medium)
                    .lineSpacing(max(0, fontSize * (settings.lineSpacing - 1.2)))
                    .multilineTextAlignment(settings.alignment.textAlignment)
                    .frame(maxWidth: .infinity, alignment: settings.alignment.frameAlignment)
                    .onGeometryChange(for: Range<Double>.self) { proxy in
                        let frame = proxy.frame(in: .named(Self.space))
                        return Double(frame.minY)..<Double(max(frame.minY, frame.maxY))
                    } action: { frame in
                        onParagraphFrame(index, frame)
                    }
                }
            }
            .coordinateSpace(.named(Self.space))
            .foregroundStyle(settings.textColor.color)
            .padding(.horizontal, settings.margin)
            .fixedSize(horizontal: false, vertical: true)
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.paragraphs == rhs.paragraphs && lhs.settings == rhs.settings && lhs.fontSize == rhs.fontSize
        }
    }
}
