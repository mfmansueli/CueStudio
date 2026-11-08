//
//  PasteLookSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Paste look": which parts of the copied look go (Adjust, Skin, Filter, Background, Zoom) and where: the picked clip, or every clip.
/// Opened by a paste's Change, it says that what it pastes takes the place of that paste.
struct PasteLookSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(
                title: String(localized: "Paste look"),
                subtitle: viewModel.look.correctsLastPaste
                    ? String(localized: "Pick again. It replaces the paste you just made.")
                    : String(localized: "Pick what goes. The words, sound and timing stay.")
            )
            VStack(spacing: 2) {
                ForEach(ClipLookPart.allCases) { part in
                    PanelToggleRow(
                        label: part.label, isOn: viewModel.look.pastesLookParts.contains(part), identifier: "edit.pasteLook.\(part.rawValue)"
                    ) { viewModel.look.togglePasteLookPart(part) }
                }
            }
            HStack(spacing: 10) {
                PanelButton(
                    label: String(localized: "Every clip"), isEnabled: !viewModel.look.pastesLookParts.isEmpty, identifier: "edit.pasteLook.all"
                ) { viewModel.look.pasteLook(on: true) }
                PanelButton(
                    label: String(localized: "This clip"), isPrimary: true,
                    isEnabled: !viewModel.look.pastesLookParts.isEmpty && viewModel.look.pasteLookClipID != nil, identifier: "edit.pasteLook.clip"
                ) { viewModel.look.pasteLook(on: false) }
            }
            // A dimmed button always says why.
            if viewModel.look.pastesLookParts.isEmpty {
                PanelNote(text: String(localized: "Turn on a part to paste it."))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .bigTextSheetDetents(.height(470))
        .presentationDragIndicator(.visible)
    }
}
