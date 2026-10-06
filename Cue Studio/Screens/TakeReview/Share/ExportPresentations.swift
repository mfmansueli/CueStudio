//
//  ExportPresentations.swift
//  Cue Studio
//

import SwiftUI

/// What an export can bring up: the system share sheet, "Your video is ready" (no free exports left) and the calm Pro. Attached to the
/// review and to Share to; only the frontmost one is active, since a view can't present while it
/// is covered by a sheet.
struct ExportPresentations: ViewModifier {
    @Bindable var viewModel: TakeReviewViewModel
    let isActive: Bool

    @Environment(\.fakesShareSheet) private var fakesShareSheet

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { isActive && viewModel.activity != nil },
                set: { if !$0 { viewModel.activity = nil } }
            )) {
                if let share = viewModel.activity {
                    shareSheet(for: share)
                }
            }
            .sheet(isPresented: Binding(
                get: { isActive && viewModel.showsExportReady },
                set: { if !$0 { viewModel.declineExport() } }
            )) {
                if let take = viewModel.take {
                    ExportReadySheet(
                        take: take, onTrial: { Task { await viewModel.openProFromExportReady() } },
                        onSeePro: { Task { await viewModel.openProFromExportReady() } },
                        onDecline: { viewModel.declineExport() }
                    )
                }
            }
            .fullScreenCover(item: Binding(
                get: { isActive ? viewModel.paywall : nil },
                set: { viewModel.paywall = $0 }
            )) { context in
                PaywallView(context: context) { Task { await viewModel.continueAfterPurchase() } }
            }
    }

    @ViewBuilder
    private func shareSheet(for share: ActivityShare) -> some View {
        #if DEBUG
        if fakesShareSheet {
            DebugShareSheet { viewModel.activityFinished($0, for: share) }
        } else {
            ActivityView(items: [share.url]) { viewModel.activityFinished($0, for: share) }
                .presentationDetents([.medium, .large])
        }
        #else
        ActivityView(items: [share.url]) { viewModel.activityFinished($0, for: share) }
            .presentationDetents([.medium, .large])
        #endif
    }
}
