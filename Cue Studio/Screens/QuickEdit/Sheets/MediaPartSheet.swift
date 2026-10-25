//
//  MediaPartSheet.swift
//  Cue Studio
//

import SwiftUI

/// Replace, with a video longer than the place it takes: which part of it fills the place (CapCut's slot). The place keeps its
/// length and everything set on it; only the picture changes. Closed, nothing is replaced.
struct MediaPartSheet: View {
    let viewModel: QuickEditViewModel
    @State var choice: MediaPartChoice

    @Environment(\.dismiss) private var dismiss
    @State private var isDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: String(localized: "Pick the part"), subtitle: subtitle)
            MediaPartStep(
                pick: $choice.pick, longest: choice.length, isFixedLength: true,
                note: String(localized: "Fills the \(DurationText.tenths(choice.length)) of the one it replaces · place and settings stay"),
                action: String(localized: "Replace"), back: String(localized: "Cancel"),
                onBack: { dismiss() },
                onConfirm: {
                    isDone = true
                    viewModel.confirmPart(choice)
                    dismiss()
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear { if !isDone { viewModel.cancelPart(choice) } }
    }

    private var subtitle: String {
        switch choice.purpose {
        case .replaceClip: String(localized: "Replace clip")
        case .replaceMedia: String(localized: "Replace")
        }
    }
}
