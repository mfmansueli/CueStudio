//
//  WordTimingStrip.swift
//  Cue Studio
//

import SwiftUI

/// Caption line › More › Word timing: the line's words side by side, each as wide as the time it is said, with a yellow handle
/// between two words that moves where one ends and the next starts (`CaptionsViewModel.setWordBoundary`). Times the voice
/// measured or the creator set are solid; estimated ones are dashed, never shown as if they were measured. VoiceOver adjusts
/// each handle a tenth at a time.
struct WordTimingStrip: View {
    let viewModel: QuickEditViewModel
    let cueID: UUID

    /// Seconds a VoiceOver step moves a handle.
    private static let step: TimeInterval = 0.1

    /// The handle being dragged and where it was when the finger took it (the words move under the finger as it drags).
    @State private var drag: (index: Int, origin: TimeInterval)?

    private var line: CaptionCue? { viewModel.edit.captions.first { $0.id == cueID } }

    var body: some View {
        if let line, line.lineWords.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                PanelRowLabel(label: String(localized: "Word timing"), detail: nil)
                GeometryReader { proxy in
                    let words = line.lineWords
                    let span = max(0.001, line.end - line.start)
                    let x = { (time: TimeInterval) in CGFloat((time - line.start) / span) * proxy.size.width }
                    ZStack(alignment: .leading) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            wordCell(word)
                                .frame(width: max(2, x(word.end) - x(word.start) - 2), height: proxy.size.height)
                                .offset(x: x(word.start) + 1)
                        }
                        ForEach(0..<(words.count - 1), id: \.self) { index in
                            handle(after: index, words: words, line: line, width: proxy.size.width)
                                .offset(x: x(boundary(after: index, in: words)) - Metrics.hitTarget / 2)
                        }
                    }
                }
                .frame(height: 36)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("edit.captionWordTiming")
                Text("Drag between two words to move where one ends and the next starts. Dashed words have estimated times.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func boundary(after index: Int, in words: [CaptionWord]) -> TimeInterval {
        (words[index].end + words[index + 1].start) / 2
    }

    private func wordCell(_ word: CaptionWord) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous)
        return Text(word.text)
            .font(.system(.caption, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(word.isEstimated ? Palette.ink2 : Palette.ink)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(word.isEstimated ? Color.clear : Palette.segmentOn, in: shape)
            .overlay {
                if word.isEstimated { shape.strokeBorder(Palette.ink2, style: StrokeStyle(lineWidth: 1, dash: [3, 3])) }
            }
            .accessibilityHidden(true)
    }

    /// The yellow handle between word `index` and the next, 44 pt wide to catch the finger.
    private func handle(after index: Int, words: [CaptionWord], line: CaptionCue, width: CGFloat) -> some View {
        let span = max(0.001, line.end - line.start)
        let current = boundary(after: index, in: words)
        return Capsule()
            .fill(Palette.acc)
            .frame(width: 3, height: 30)
            .frame(width: Metrics.hitTarget, height: 36)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if drag?.index != index {
                            // The whole drag is one undo step.
                            viewModel.beginChange()
                            drag = (index, current)
                        }
                        let origin = drag?.origin ?? current
                        viewModel.captions.setWordBoundary(cueID, after: index, at: origin + Double(value.translation.width / max(1, width)) * span)
                    }
                    .onEnded { _ in
                        drag = nil
                        viewModel.endChange()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Between “\(words[index].text)” and “\(words[index + 1].text)”"))
            .accessibilityValue(Text(DurationText.editor(current)))
            .accessibilityAdjustableAction { direction in
                let delta = direction == .increment ? Self.step : -Self.step
                viewModel.captions.setWordBoundary(cueID, after: index, at: current + delta)
                viewModel.endChange()
            }
            .accessibilityIdentifier("edit.captionWordBoundary.\(index)")
    }
}
