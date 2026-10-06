//
//  ScriptTextEditor.swift
//  Cue Studio
//

import SwiftUI

/// The script's words as one editable page (v29 · 4.1 and 4.2). The words are the `text` the page keeps (cues are written in
/// square brackets); the editor draws them: cues as small yellow tags, and the words the AI has just written in place of a
/// selection in violet, until the creator keeps them. Typing, the selection and the caret go both ways between the editor and
/// the page, in characters from the start of the text.
struct ScriptTextEditor: View {
    @Binding var text: String
    @Binding var selection: Range<Int>?
    /// Where the AI's words sit (violet), if it has just written some.
    let passage: Range<Int>?
    let textSize: ScriptTextSize
    let isLocked: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onEdit: () -> Void

    @State private var attributed = AttributedString()
    @State private var attributedSelection = AttributedTextSelection()
    /// What the editor last told the page, so the page's own echo isn't taken for a change from outside.
    @State private var lastReported = ""
    @State private var lastReportedSelection: Range<Int>?

    @ScaledMetric(relativeTo: .body) private var minimumHeight = 300.0

    /// Where the editor's words sit inside it: the text view's 8 pt above and below, and 5 pt of line padding at each side. The page's
    /// placeholder and the words the AI writes in (`ArrivingText`) sit there too.
    static let textInsets = EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)

    var body: some View {
        TextEditor(text: $attributed, selection: $attributedSelection)
            .font(.system(size: textSize.points))
            .lineSpacing(6)
            .foregroundStyle(Palette.ink)
            .tint(Palette.accText)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .focused(focus, equals: .text)
            .allowsHitTesting(!isLocked)
            .frame(minHeight: minimumHeight, alignment: .top)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Just start talking…")
                        .font(.system(size: textSize.points))
                        .foregroundStyle(Palette.ink2)
                        .padding(.top, Self.textInsets.top)
                        .padding(.leading, Self.textInsets.leading)
                        .allowsHitTesting(false)
                }
            }
            .writingToolsBehavior(.limited)
            .onAppear { reload() }
            .onChange(of: text) { _, new in
                // A change from outside (the AI writing, a tool, a cue from the bar): the editor follows.
                if new != lastReported { reload() }
            }
            .onChange(of: passage) { _, _ in restyle() }
            .onChange(of: textSize) { _, _ in reload() }
            .onChange(of: attributed) { _, new in report(new) }
            .onChange(of: attributedSelection) { _, _ in reportSelection() }
            .onChange(of: selection) { _, new in
                if new != lastReportedSelection { pushSelection(new) }
            }
            .accessibilityLabel(Text("Script text"))
            .accessibilityIdentifier("page.editor")
    }

    // MARK: - Words

    private func reload() {
        attributed = Self.styled(text, passage: passage, size: textSize.points)
        lastReported = text
    }

    private func restyle() {
        let styled = Self.styled(String(attributed.characters), passage: passage, size: textSize.points)
        if styled != attributed { attributed = styled }
    }

    /// The creator typed: the page gets the words, and the cues in them get their tags.
    private func report(_ new: AttributedString) {
        let plain = String(new.characters)
        if plain != lastReported {
            lastReported = plain
            text = plain
            onEdit()
        }
        let styled = Self.styled(plain, passage: passage, size: textSize.points)
        if styled != new { attributed = styled }
    }

    /// The text with its cues tagged and the AI's passage in violet.
    static func styled(_ text: String, passage: Range<Int>?, size: Double) -> AttributedString {
        var result = AttributedString(text)
        result.font = .system(size: size)
        result.foregroundColor = Palette.ink
        let characters = result.characters
        for match in text.matches(of: /\[[^\]\n]+\]/) {
            let lower = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: match.range.upperBound)
            let start = characters.index(characters.startIndex, offsetBy: lower)
            let end = characters.index(characters.startIndex, offsetBy: upper)
            result[start..<end].font = .system(size: size * 0.72, weight: .bold, design: .monospaced)
            result[start..<end].foregroundColor = Palette.accText
            result[start..<end].backgroundColor = Palette.accSoft
        }
        if let passage, passage.upperBound <= text.count, !passage.isEmpty {
            let start = characters.index(characters.startIndex, offsetBy: passage.lowerBound)
            let end = characters.index(characters.startIndex, offsetBy: passage.upperBound)
            result[start..<end].foregroundColor = Palette.Page.aiReplacedInk
            result[start..<end].backgroundColor = Palette.Page.aiReplacedFill
        }
        return result
    }

    // MARK: - Selection

    private func reportSelection() {
        let range = Self.offsets(of: attributedSelection, in: attributed)
        lastReportedSelection = range
        if selection != range { selection = range }
    }

    private func pushSelection(_ range: Range<Int>?) {
        guard let range, range.upperBound <= attributed.characters.count else { return }
        let characters = attributed.characters
        let lower = characters.index(characters.startIndex, offsetBy: range.lowerBound)
        let upper = characters.index(characters.startIndex, offsetBy: range.upperBound)
        attributedSelection = AttributedTextSelection(range: lower..<upper)
        lastReportedSelection = range
    }

    /// The selection as characters from the start (a caret is an empty range).
    static func offsets(of selection: AttributedTextSelection, in text: AttributedString) -> Range<Int>? {
        let characters = text.characters
        switch selection.indices(in: text) {
        case .insertionPoint(let index):
            let offset = characters.distance(from: characters.startIndex, to: index)
            return offset..<offset
        case .ranges(let ranges):
            guard let first = ranges.ranges.first else { return nil }
            return characters.distance(from: characters.startIndex, to: first.lowerBound)
                ..< characters.distance(from: characters.startIndex, to: first.upperBound)
        @unknown default:
            return nil
        }
    }
}
