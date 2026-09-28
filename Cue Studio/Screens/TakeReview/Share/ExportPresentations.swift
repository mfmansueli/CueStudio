//
//  ExportPresentations.swift
//  Cue Studio
//

import SwiftUI

/// What an export can bring up: the system share sheet and the export paywall. Attached to the
/// review and to Share to; only the frontmost one is active, since a view can't present while it
/// is covered by a sheet.
struct ExportPresentations: ViewModifier {
    @Bindable var viewModel: TakeReviewViewModel
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { isActive && viewModel.shareURL != nil },
                set: { if !$0 { viewModel.shareURL = nil } }
            )) {
                if let url = viewModel.shareURL {
                    ActivityView(items: [url])
                        .presentationDetents([.medium, .large])
                }
            }
            .fullScreenCover(item: Binding(
                get: { isActive ? viewModel.paywall : nil },
                set: { viewModel.paywall = $0 }
            )) { context in
                PaywallView(
                    context: context,
                    onWatermarkInstead: { Task { await viewModel.exportWithWatermark() } },
                    onPurchased: { Task { await viewModel.continueAfterPurchase() } }
                )
            }
    }
}
