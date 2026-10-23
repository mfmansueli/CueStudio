//
//  NarrationScriptOverlay.swift
//  Cue Studio
//

import SwiftUI

/// Voice-over's "Show script": the take's script over the top of the preview area (its whole width, not only the video's), drawn by the teleprompter's own text
/// (`PrompterParagraphs`: the creator's font, colour, spacing and alignment) on a dark scrim, under the "● REC" badge. Before
/// recording it shows the start; from the recording's start it scrolls at a steady pace (`NarrationScriptPace`), and a tap holds
/// it or lets it go on. With Reduce Motion it moves a line at a time. It is drawn on the screen only: never in the video.
struct NarrationScriptOverlay: View {
    let viewModel: QuickEditViewModel
    /// The preview area's size (the video is centred in it).
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How tall the script is, laid out at this size.
    @State private var contentHeight: CGFloat = 0

    /// The "● REC" badge takes the video's top 42 points (12 above it, 30 tall; the video sits 3 points into the area): the script
    /// starts under it.
    private static let topClearance: CGFloat = 50
    /// Between the scrim's edge and the first line.
    private static let inset: CGFloat = 10

    var body: some View {
        let look = viewModel.narrationLook
        let paragraphs = CueParser.paragraphs(in: viewModel.narrationScriptText ?? "")
        let wordCount = ReadTime.wordCount(in: viewModel.narrationScriptText ?? "")
        let fontSize = NarrationScriptPace.fontSize(forPreview: size, prompterSize: look.size)
        let lineHeight = fontSize * look.lineSpacing
        let pace = viewModel.narrationPace
        let isRecording = viewModel.isRecordingVoiceOver
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.2 : nil, paused: !pace.isReading)) { context in
            let offset = NarrationScriptPace.offset(
                wordsRead: pace.wordsRead(at: context.date), wordCount: wordCount, contentHeight: contentHeight,
                lineHeight: lineHeight, stepsByLine: reduceMotion
            )
            PrompterParagraphs(paragraphs: paragraphs, settings: look, fontSize: fontSize)
                .equatable()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .offset(y: Self.inset - offset)
                .frame(maxWidth: .infinity)
                .frame(height: boxHeight(lineHeight: lineHeight), alignment: .top)
                .clipped()
                .mask {
                    // What comes next fades under the scrim's lower edge, so it reads as more to come.
                    LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom)
                }
        }
        .environment(\.layoutDirection, viewModel.narrationReadsRightToLeft ? .rightToLeft : .leftToRight)
        .overlay(alignment: .bottomTrailing) {
            if pace.isPaused { pausedBadge }
        }
        .background(Palette.Editor.narrationScrim, in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        .onTapGesture { viewModel.toggleNarrationPause() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Script"))
        .accessibilityValue(pace.isPaused ? Text("Paused") : Text(""))
        .accessibilityHint(isRecording ? (pace.isPaused ? Text("Tap to go on with the script") : Text("Tap to pause the script")) : Text(""))
        .accessibilityAddTraits(isRecording ? .isButton : [])
        .accessibilityIdentifier("edit.narrationScript")
        // Before recording it only shows where the script starts; the preview's own handles stay under the finger.
        .allowsHitTesting(isRecording)
        .padding(.horizontal, 16)
        .padding(.top, Self.topClearance)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// About half the preview, under the badge, and never less than three lines.
    private func boxHeight(lineHeight: Double) -> CGFloat {
        let available = max(0, size.height - Self.topClearance - 8)
        return min(available, max(CGFloat(lineHeight) * 3 + Self.inset * 2, size.height * 0.5 - Self.topClearance))
    }

    private var pausedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "pause.fill").font(.editorGlyph(EditorGlyph.mark, weight: .bold))
            Text("Paused").font(.caption.weight(.semibold))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Palette.Editor.narrationScrim, in: Capsule())
        .padding(8)
        .accessibilityHidden(true)
    }
}
