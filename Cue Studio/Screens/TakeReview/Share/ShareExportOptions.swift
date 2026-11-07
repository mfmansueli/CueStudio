//
//  ShareExportOptions.swift
//  Cue Studio
//

import SwiftUI

/// Export options as a sheet of their own, where the creator saves or shares from the review: Ready to travel's "Options · 1080p" and the
/// review's quiet line under Share (for Save). The options themselves are `ExportOptionsForm`, the same the editor's Done shows as its
/// second page (D11: one component and one state for every way out).
struct ShareExportOptions: View {
    @Bindable var review: TakeReviewViewModel
    /// The version the options are about: the saved edit.
    let edit: TakeEdit?

    var body: some View {
        VStack(spacing: 14) {
            Text("Export options").cueFont(.headline, weight: .semibold)
            ExportOptionsForm(review: review, edit: edit)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 22, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
        .cueSheetChrome()
    }
}
