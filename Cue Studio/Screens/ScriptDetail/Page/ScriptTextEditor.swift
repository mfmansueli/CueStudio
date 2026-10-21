//
//  ScriptTextEditor.swift
//  Cue Studio
//

import SwiftUI

/// The script's words as one editable page (v29 · 4.1 and 4.2). The words are the `text` the page keeps (cues are written in
/// square brackets); the editor draws them: cues as small yellow chips with their symbol (the brackets hidden, the words still the
/// text), and the words the AI has just written in place of a selection in violet, until the creator keeps them. Typing, the
/// selection and the caret go both ways between the editor and the page, in characters from the start of the text.
///
/// A TextKit 2 text view (`ScriptTextView`): SwiftUI's `TextEditor` can't draw a chip behind a run of its text, and it clears its undo
/// history whenever the page restyles the words.
struct ScriptTextEditor: View {
    @Binding var text: String
    @Binding var selection: Range<Int>?
    /// Where the AI's words sit (violet), if it has just written some.
    let passage: Range<Int>?
    let textSize: ScriptTextSize
    /// The Cues switch: off, the cue tags are kept in the words but not drawn.
    var showsCues = true
    let isLocked: Bool
    var focus: FocusState<ScriptPageFocus?>.Binding
    let onEdit: () -> Void
    /// Undo and Redo on the cues bar act on this editor's history when the page hands the bar the same one.
    var undo: ScriptEditorUndo?

    @ScaledMetric(relativeTo: .body) private var minimumHeight = 300.0

    /// Where the editor's words sit inside it: the text view's 8 pt above and below, and 5 pt of line padding at each side. The page's
    /// placeholder and the words the AI writes in (`ArrivingText`) sit there too.
    static let textInsets = EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)

    var body: some View {
        ScriptTextViewRepresentable(
            text: $text,
            selection: $selection,
            style: ScriptTextStyle(size: textSize.points, passage: passage, showsCues: showsCues),
            minimumHeight: minimumHeight,
            focus: focus,
            undo: undo,
            onEdit: onEdit
        )
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
    }

    // MARK: - Words

    /// The text as the editor draws it, for SwiftUI (`ArrivingText` hands the AI's words in this way, so they arrive looking as they
    /// will stay): each cue a `TextChip` (its name semibold in yellow, the brackets clear and given the chip's insets as kern), or,
    /// with the Cues switch off, kept but not drawn (clear and a point high, so the words close up around them); the AI's passage in
    /// violet. `ScriptTextStyle` is the same for the text view.
    static func styled(_ text: String, passage: Range<Int>?, size: Double, showsCues: Bool = true) -> AttributedString {
        var result = AttributedString(text)
        result.font = .system(size: size)
        result.foregroundColor = Palette.ink
        let characters = result.characters
        if let passage, passage.upperBound <= text.count, !passage.isEmpty {
            let start = characters.index(characters.startIndex, offsetBy: passage.lowerBound)
            let end = characters.index(characters.startIndex, offsetBy: passage.upperBound)
            result[start..<end].foregroundColor = Palette.Page.aiReplacedInk
            result[start..<end].backgroundColor = Palette.Page.aiReplacedFill
        }
        let metrics = TextChipMetrics(textSize: size)
        for match in text.matches(of: ScriptTextStyle.cuePattern) {
            let lower = text.distance(from: text.startIndex, to: match.range.lowerBound)
            let upper = text.distance(from: text.startIndex, to: match.range.upperBound)
            let start = characters.index(characters.startIndex, offsetBy: lower)
            let end = characters.index(characters.startIndex, offsetBy: upper)
            result[start..<end].backgroundColor = nil
            guard showsCues else {
                result[start..<end].font = .system(size: 1)
                result[start..<end].foregroundColor = .clear
                continue
            }
            let symbol = ScriptCueSymbol.name(forCue: String(match.output.dropFirst().dropLast()))
            result[start..<end].font = .system(size: metrics.fontSize, weight: .semibold)
            result[start..<end].foregroundColor = Palette.Cues.chipInk
            result[start..<end].baselineOffset = metrics.baselineOffset
            result[start..<end][TextChipAttribute.self] = TextChip(id: lower, symbol: symbol)
            let opening = start..<characters.index(after: start)
            let closing = characters.index(before: end)..<end
            result[opening].foregroundColor = .clear
            result[opening].kern = metrics.leadingKern(after: "[", symbol: symbol)
            result[closing].foregroundColor = .clear
            result[closing].kern = metrics.trailingKern(after: "]")
        }
        return result
    }
}
