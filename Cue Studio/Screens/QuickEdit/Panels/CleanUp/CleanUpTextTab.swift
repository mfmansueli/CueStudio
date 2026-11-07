//
//  CleanUpTextTab.swift
//  Cue Studio
//

import SwiftUI

/// Clean up › Text (Edit by text): what was said, word by word, in the order it plays. Hesitations are underlined and pauses
/// are a small mark between words, yellow when marked to go: tap one to switch it. Tap a word to hear it, another to take
/// every word between them (the actions are at the bottom: `CleanUpTextActions`). Cut words stay listed, crossed out, and can
/// be put back. Without a transcript yet, it offers to listen to the video.
struct CleanUpTextTab: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.clips.hasTranscript {
                words
            } else {
                listen
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("edit.transcript")
    }

    private var words: some View {
        let clips = viewModel.clips
        let list = clips.transcriptWords
        let picked = clips.transcriptSelection
        let marks = clips.transcriptMarks(in: list)
        return FlowLayout(spacing: 4, lineSpacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, word in
                wordButton(word, index: index, picked: picked, filler: marks.fillers[index])
                if let pause = marks.pauses[index] { pauseMark(pause) }
            }
        }
        .padding(.vertical, 4)
    }

    private func wordButton(_ word: TranscriptWord, index: Int, picked: ClosedRange<Int>?, filler: CleanUpSuggestion?) -> some View {
        let isPicked = picked?.contains(index) ?? false
        // The two ends of the pick carry a mark: where the cut starts, and (once tapped) where it ends.
        let isStart = picked?.lowerBound == index
        let isEnd = picked.map { $0.upperBound == index && $0.lowerBound != index } ?? false
        let fillerMarked = filler.map(viewModel.clips.isMarked) ?? false
        return Button { viewModel.clips.tapTranscriptWord(at: index) } label: {
            HStack(spacing: 3) {
                if isStart { Image(systemName: "arrow.right.to.line").font(.editorGlyph(EditorGlyph.small, weight: .bold)) }
                Text(word.text)
                if isEnd { Image(systemName: "arrow.left.to.line").font(.editorGlyph(EditorGlyph.small, weight: .bold)) }
            }
            .font(.system(.body, weight: isPicked ? .semibold : .regular))
            .strikethrough(word.isRemoved, color: Palette.ink2)
            .underline(filler != nil, pattern: fillerMarked ? .solid : .dot, color: fillerMarked ? Palette.acc : Palette.ink2)
            .foregroundStyle(isPicked ? Palette.accInk : (word.isRemoved ? Palette.ink2 : (fillerMarked ? Palette.accText : Palette.ink)))
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                isPicked ? Palette.acc : Color.clear,
                in: RoundedRectangle(cornerRadius: Metrics.editorThumbnailRadius, style: .continuous)
            )
            // Each word is a 44 pt target (HIG), rows touching.
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(word.isRemoved ? Text("\(word.text), cut") : Text(verbatim: word.text))
        .accessibilityValue(accessibilityValue(isStart: isStart, isEnd: isEnd, filler: filler, marked: fillerMarked))
        .accessibilityAddTraits(isPicked ? .isSelected : [])
        .accessibilityIdentifier("edit.transcript.word.\(index)")
    }

    private func accessibilityValue(isStart: Bool, isEnd: Bool, filler: CleanUpSuggestion?, marked: Bool) -> Text {
        if isStart { return Text("Start of the pick") }
        if isEnd { return Text("End of the pick") }
        if filler != nil { return marked ? Text("Hesitation, remove") : Text("Hesitation, keep") }
        return Text(verbatim: "")
    }

    /// A pause between two words: its length, yellow when marked to go; tap to switch.
    private func pauseMark(_ pause: CleanUpSuggestion) -> some View {
        let isMarked = viewModel.clips.isMarked(pause)
        return Button { viewModel.clips.toggleMark(pause.id) } label: {
            Text(viewModel.clips.cardLength(pause))
                .font(.system(.caption, weight: .bold).monospacedDigit())
                .foregroundStyle(isMarked ? Palette.accInk : Palette.ink)
                .padding(.horizontal, 6)
                .frame(minHeight: 22)
                .background(isMarked ? Palette.acc : Palette.fill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Pause, \(viewModel.clips.cardLength(pause))"))
        .accessibilityValue(isMarked ? Text("Remove") : Text("Keep"))
        .accessibilityIdentifier("edit.transcript.pause.\(pause.id.uuidString)")
    }

    @ViewBuilder
    private var listen: some View {
        Text("Cue listens to the video on your iPhone to write down every word. Then you cut by text.")
            .cueFont(.subheadline)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
        let state = viewModel.captions.captionState
        if state.isWorking {
            HStack(spacing: 10) {
                ProgressView().tint(Palette.ink)
                Text(state.message ?? String(localized: "Listening…")).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
        } else {
            // Listening ended without words: why, and a second try only when one can help (never a button that loops).
            if state != .idle, let message = state.message {
                PanelNote(text: message, tint: Palette.warnText)
                    .accessibilityIdentifier("edit.transcript.problem")
            }
            if state == .idle || state.canRetry {
                PanelButton(
                    label: state == .idle ? String(localized: "Listen to the video") : String(localized: "Try again"),
                    systemImage: "waveform", isPrimary: true, identifier: "edit.transcript.listen"
                ) { viewModel.listenForTranscript() }
            }
        }
    }
}
