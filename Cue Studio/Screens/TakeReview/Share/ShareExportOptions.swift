//
//  ShareExportOptions.swift
//  Cue Studio
//

import SwiftUI

/// Export options, where the creator saves or shares from the review: a step of Share to universe ("Options · 1080p", with ‹ Back to the networks:
/// never a sheet over the sheet) and a sheet of its own from the review's quiet line under Share (for Save). The options themselves are
/// `ExportOptionsForm`, the same the editor's Done shows as its second page (D11: one component and one state for every way out).
struct ShareExportOptions: View {
    @Bindable var review: TakeReviewViewModel
    /// The version the options are about: the saved edit.
    let edit: TakeEdit?
    /// As a step of a sheet: ‹ Back to the step before. Nil as a sheet of its own.
    var onBack: (() -> Void)?

    var body: some View {
        if onBack == nil {
            content.cueSheetChrome()
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 14) {
            ZStack {
                Text("Export options").cueFont(.headline, weight: .semibold)
                if let onBack {
                    HStack {
                        Button(action: onBack) {
                            Label("Back", systemImage: "chevron.backward").labelStyle(.iconOnly)
                                .font(.fixed(16, weight: .bold))
                                .foregroundStyle(Palette.ink)
                                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                                .contentShape(Rectangle())
                        }
                        .accessibilityIdentifier("exportOptions.back")
                        Spacer(minLength: 0)
                    }
                }
            }
            ExportOptionsForm(review: review, edit: edit)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: onBack == nil ? 22 : 8, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
    }
}
