//
//  CleanUpWordsTab.swift
//  Cue Studio
//

import SwiftUI

/// Clean up › Words: one line on what it finds, the hesitations and repeats as cards, the script lines said more than once
/// (listen to each try, keep one), why something may be missing (no words heard, a language without known hesitations, no
/// script), and what was removed.
struct CleanUpWordsTab: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clips = viewModel.clips
        VStack(alignment: .leading, spacing: 8) {
            PanelNote(text: String(localized: "Ums, uhs and words said twice. Tap one to keep it."))
            switch clips.analysis {
            case .idle, .running: CleanUpListening()
            case .failed: CleanUpFailed { clips.listenForCleanUp() }
            case .done: found
            }
        }
    }

    @ViewBuilder private var found: some View {
        let clips = viewModel.clips
        if let note = clips.wordsNote {
            PanelNote(text: note, tint: Palette.warnText).accessibilityIdentifier("edit.words.note")
        }
        let words = clips.hesitationCandidates
        let groups = clips.retakeGroups
        if words.isEmpty, groups.isEmpty {
            Text("No hesitations or repeats")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 64)
                .editorCard()
                .accessibilityIdentifier("edit.words.empty")
        }
        if !words.isEmpty { CleanUpCardRow(viewModel: viewModel, suggestions: words, kind: "word") }
        ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
            CleanUpRetakeCard(viewModel: viewModel, group: group, identifier: "edit.retake.\(index)")
        }
        if let note = clips.scriptRetakesNote, clips.edit.cleanUpHearing?.heardWords ?? false {
            PanelNote(text: note)
        }
        let removed = clips.removedWords
        if !removed.isEmpty { CleanUpRemovedList(viewModel: viewModel, items: removed, kind: "word") }
    }
}
