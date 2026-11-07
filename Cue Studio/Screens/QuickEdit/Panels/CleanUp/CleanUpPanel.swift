//
//  CleanUpPanel.swift
//  Cue Studio
//

import SwiftUI

/// Clean up (`ClipsViewModel+CleanUpPanel`): its tabs Pauses · Words · Text, and at the bottom the time saved with Remove (or,
/// on Text with words picked, what to do with them). The panel grows in place (its expand button; Text opens it tall) and keeps
/// its tab, marks and pick; ✓ closes it without removing anything.
struct CleanUpPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        let clips = viewModel.clips
        let tab = clips.cleanUpTab
        PanelFrame(viewModel: viewModel, panel: .pauses) {
            PanelTabs(tabs: EditorPanelTab.cleanUp, selection: tab) { clips.showCleanUpTab($0) }
        } content: {
            switch tab {
            case .words: CleanUpWordsTab(viewModel: viewModel)
            case .transcript: CleanUpTextTab(viewModel: viewModel)
            default: CleanUpPausesTab(viewModel: viewModel)
            }
        } footer: {
            footer(tab)
        }
    }

    @ViewBuilder private func footer(_ tab: EditorPanelTab) -> some View {
        let clips = viewModel.clips
        if tab == .transcript, clips.hasTranscript, clips.transcriptSelection != nil || clips.markedCleanUp.isEmpty {
            CleanUpTextActions(viewModel: viewModel)
        } else if clips.analysis == .done, !(clips.pauseCandidates + clips.wordCandidates).isEmpty {
            CleanUpFooter(viewModel: viewModel)
        }
    }
}
