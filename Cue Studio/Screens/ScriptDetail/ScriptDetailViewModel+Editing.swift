//
//  ScriptDetailViewModel+Editing.swift
//  Cue Studio
//

import Foundation

/// Writing: the paragraphs the editor edits, where the caret is, the panels that take the
/// keyboard's place and what the header says.
extension ScriptDetailViewModel {
    // MARK: - Paragraphs

    /// A paragraph typed in (no line break in it).
    func setParagraph(_ index: Int, to text: String) {
        guard draftParagraphs.indices.contains(index), draftParagraphs[index] != text else { return }
        draftParagraphs[index] = text
    }

    /// Return, or a paste with line breaks: each line becomes a paragraph and the caret follows.
    func replaceParagraph(_ index: Int, with newText: String, caret: Int) {
        apply(ScriptParagraphs.replacing(paragraphAt: index, with: newText, caret: caret, in: draftParagraphs))
    }

    /// Backspace at the start of a paragraph: it joins the one before.
    func mergeWithPrevious(_ index: Int) {
        guard let edit = ScriptParagraphs.mergingWithPrevious(index, in: draftParagraphs) else { return }
        apply(edit)
    }

    /// The caret moved inside a paragraph (the text view says so).
    func noteCaret(paragraph: Int, offset: Int) {
        caret = ScriptParagraphs.Caret(index: paragraph, offset: offset)
    }

    /// A paragraph took the keyboard: a panel stands down.
    func noteFocus(paragraph: Int) {
        activeParagraph = paragraph
        if tool != nil { tool = nil }
    }

    func noteBlur(paragraph: Int) {
        if activeParagraph == paragraph { activeParagraph = nil }
    }

    /// Up from the first line, or down from the last: the neighbor paragraph (a hardware keyboard).
    func moveCaret(from index: Int, by step: Int) {
        let target = index + step
        guard draftParagraphs.indices.contains(target) else { return }
        focus = .at(target, offset: step < 0 ? draftParagraphs[target].utf16.count : 0)
    }

    private func apply(_ edit: ScriptParagraphs.Edit, focusing: Bool = true) {
        draftParagraphs = edit.paragraphs
        caret = edit.caret
        if focusing { focus = .at(edit.caret.index, offset: edit.caret.offset) }
    }

    // MARK: - Cues and sections

    /// A cue at the caret. The keyboard stays away: the panel stays open for the next one.
    func insertCue(_ cue: ScriptCue) {
        let index = min(max(0, caret.index), draftParagraphs.count - 1)
        apply(ScriptParagraphs.cue(cue.name, atOffset: caret.offset, inParagraph: index, of: draftParagraphs), focusing: false)
    }

    /// "New section at cursor": the paragraph splits where the caret was.
    func addSectionAtCaret() {
        let index = min(max(0, caret.index), draftParagraphs.count - 1)
        tool = nil
        apply(ScriptParagraphs.splitting(paragraphAt: index, atOffset: caret.offset, in: draftParagraphs))
    }

    /// A row of the Sections panel: the caret goes to the start of its first paragraph.
    func goToSection(_ summary: BlockSummary) {
        tool = nil
        let index = min(summary.firstParagraph, draftParagraphs.count - 1)
        caret = ScriptParagraphs.Caret(index: index, offset: 0)
        focus = .at(index, offset: 0)
    }

    /// The block (as `summaries` lists them) the caret is in.
    var activeSummary: BlockSummary? {
        editorSummaries.last { $0.firstParagraph <= caret.index }
    }

    // MARK: - Labels

    /// Each paragraph's block, with the seconds of the whole block on its first paragraph.
    var editorLabels: [EditorBlockLabel] {
        ScriptBlocks.editorLabels(for: draftParagraphs, structure: structure, speed: preferences.prompter.speed)
    }

    /// The blocks as chips and rows, empty paragraphs included.
    var editorSummaries: [BlockSummary] {
        let labels = editorLabels
        var summaries: [BlockSummary] = []
        for (index, label) in labels.enumerated() where label.showsLabel {
            summaries.append(BlockSummary(
                label: label.label, seconds: label.groupSeconds ?? 0, isOpening: index == 0, firstParagraph: index
            ))
        }
        return summaries
    }

    // MARK: - Panels and keyboard

    /// Something is taking input: a paragraph or the title has the keyboard, or a panel stands in
    /// for it.
    var isInputVisible: Bool {
        tool != nil || activeParagraph != nil || isTitleFocused
    }

    /// A tool's button: its panel opens in the keyboard's place; tapped again, it closes and the
    /// keyboard comes back where the caret was.
    func toggle(_ tool: EditorTool) {
        if self.tool == tool {
            self.tool = nil
            focus = .at(caret.index, offset: caret.offset)
        } else {
            self.tool = tool
            focus = .keyboardAway
        }
    }

    /// The keyboard button: puts the keyboard and any panel away, or brings the keyboard back.
    func toggleKeyboard() {
        if isInputVisible {
            tool = nil
            focus = .keyboardAway
        } else {
            focus = .at(caret.index, offset: caret.offset)
        }
    }

    // MARK: - Header

    /// "~49s · 123 words" under the title, in the length's color.
    var statusLine: String {
        String(localized: "\(zone.words) words · \(zone.durationLabel)")
    }

    var statusIsInRange: Bool { zone.isInIdealRange || zone.words == 0 }

    /// "Discard changes": the draft goes, the script stays as it was.
    func discardChanges() {
        cancelEditing()
        toast.show(String(localized: "Changes discarded"))
    }

    // MARK: - Options

    /// "Show cues while recording": AI Coach in the prompter.
    var showsCues: Bool {
        get { preferences.prompter.showsCues }
        set { preferences.prompter.showsCues = newValue }
    }

    // MARK: - Details

    /// "Script type": the sections and the AI suggestions follow it.
    func setType(_ type: ScriptType?) {
        library.update(scriptID) { $0.type = type }
        sheet = nil
        let blocks = (type?.structure ?? .generic).blocks.joined(separator: " · ")
        toast.show(String(localized: "Sections: \(blocks)"))
    }

    /// A block of the Details sheet: the sheet closes and the read view scrolls to it.
    func showBlock(_ summary: BlockSummary) {
        sheet = nil
        readScrollTarget = summary.firstParagraph
    }
}
