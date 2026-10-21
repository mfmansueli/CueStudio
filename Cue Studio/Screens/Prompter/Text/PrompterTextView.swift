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
    /// Over the camera, a soft shadow keeps the text readable on bright backgrounds.
    var castsShadow = false
    /// Where the reading line crosses the text, from the top. Selfie places it under the lens;
    /// Studio (nil) uses the Display setting.
    var guideOffset: CGFloat?
    /// Selfie draws the reading line as a layer of its own, over the camera.
    var drawsGuide = true
    /// Studio: how far the reading line stays from the edges of the screen (`ReadingLayout.lineInset`).
    var guideInset: CGFloat = 0
    /// Selfie: what was already read fades above the line.
    var fadesReadText = false
    var onTap: (() -> Void)?

    @State private var lastTranslation: CGFloat = 0

    private var guideY: CGFloat { guideOffset ?? viewportHeight * settings.guidePosition }

    private var maskStops: [Gradient.Stop] {
        guard fadesReadText, viewportHeight > 0 else {
            return [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1),
            ]
        }
        let fadeEnd = max(0, guideY - viewModel.lineHeight * 0.9) / viewportHeight
        return [
            .init(color: .black.opacity(0.3), location: 0),
            .init(color: .black, location: min(0.8, fadeEnd)),
            .init(color: .black, location: 0.84),
            .init(color: .clear, location: 1),
        ]
    }

    var body: some View {
        let lineHeight = viewModel.lineHeight
        PrompterParagraphs(
            paragraphs: viewModel.paragraphs,
            settings: settings,
            fontSize: viewModel.fontSize,
            onParagraphFrame: { viewModel.updateParagraphFrame($1, at: $0) }
        )
            .equatable()
            .shadow(color: castsShadow ? Palette.textShadow : .clear, radius: 1.5, x: 0, y: 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                viewModel.updateLayout(contentHeight: height)
            }
            .offset(y: guideY - lineHeight / 2 - viewModel.engine.offset)
            .frame(maxWidth: .infinity)
            .frame(height: viewportHeight, alignment: .top)
            .scaleEffect(x: settings.isMirrored ? -1 : 1, y: settings.isFlippedVertically ? -1 : 1)
            .clipped()
            .mask {
                LinearGradient(stops: maskStops, startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .top) {
                if drawsGuide && settings.showsGuide {
                    ReadingGuide(
                        level: viewModel.followsSpeech ? viewModel.voiceLevel : nil, showsParticles: viewModel.isPlaying,
                        isCalm: viewModel.isRecording
                    )
                        .padding(.horizontal, guideInset)
                        .offset(y: guideY - ReadingGuide.height / 2)
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
            // The script reads in its own language's direction, not the interface's.
            .environment(\.layoutDirection, LayoutDirection(rightToLeft: viewModel.readsRightToLeft))
    }
}
