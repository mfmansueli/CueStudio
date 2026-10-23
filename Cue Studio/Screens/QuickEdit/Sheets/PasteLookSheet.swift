//
//  PasteLookSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Paste look": which parts of the copied look go (Adjust, Filter, Background, Zoom) and where: the picked clip, or every clip.
struct PasteLookSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "Paste look"), subtitle: String(localized: "Pick what goes. The words, sound and timing stay."))
            VStack(spacing: 2) {
                ForEach(ClipLookPart.allCases) { part in
                    PanelToggleRow(
                        label: part.label, isOn: viewModel.pastesLookParts.contains(part), identifier: "edit.pasteLook.\(part.rawValue)"
                    ) { viewModel.togglePasteLookPart(part) }
                }
            }
            HStack(spacing: 10) {
                PanelButton(
                    label: String(localized: "Every clip"), isEnabled: !viewModel.pastesLookParts.isEmpty, identifier: "edit.pasteLook.all"
                ) { viewModel.pasteLook(on: true) }
                PanelButton(
                    label: String(localized: "This clip"), isPrimary: true, isEnabled: !viewModel.pastesLookParts.isEmpty && viewModel.selection?.clipID != nil,
                    identifier: "edit.pasteLook.clip"
                ) { viewModel.pasteLook(on: false) }
            }
            // A dimmed button always says why.
            if viewModel.pastesLookParts.isEmpty {
                PanelNote(text: String(localized: "Turn on a part to paste it."))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
    }
}
