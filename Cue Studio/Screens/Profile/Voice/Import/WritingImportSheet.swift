//
//  WritingImportSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Import my writing" (My Cue Voice · Proof): the creator brings what they wrote in other places (scripts, captions, notes), Cue reads it on this
/// iPhone and says what it heard, and they keep what they want. Three steps in one sheet: bring texts, wait, review.
struct WritingImportSheet: View {
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ToastService.self) private var toast
    @Environment(\.styleReader) private var styleReader
    @Environment(\.dismiss) private var dismiss
    @State private var model: WritingImportViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let model {
                    VStack(alignment: .leading, spacing: 20) {
                        header(model)
                        switch model.step {
                        case .collect: WritingImportCollectView(model: model, onRead: { model.read(against: profile.profile) })
                        case .reading: WritingImportReadingView(model: model)
                        case .review: WritingImportReviewView(model: model, onAccept: { accept(model) })
                        }
                    }
                    .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("sheet.closeButton")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import.sheet")
        .task {
            if model == nil { model = WritingImportViewModel(reader: styleReader ?? NoStyleReader()) }
        }
    }

    private func header(_ model: WritingImportViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Only said when Apple Intelligence is the one that reads: without it the numbers are all there is, still on this iPhone.
            Text((model.canUseModel ? String(localized: "Apple Intelligence · on this iPhone") : String(localized: "On this iPhone")).uppercased())
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(Palette.aiText)
            Text(model.step == .review ? String(localized: "Here’s what Cue heard") : String(localized: "Import my writing"))
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.56)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func accept(_ model: WritingImportViewModel) {
        let applied = profile.apply(model.proposal)
        toast.show(applied > 0 ? String(localized: "Added to My Cue Voice") : String(localized: "Excerpts saved"))
        dismiss()
    }
}
