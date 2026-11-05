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
    @Environment(ReferralService.self) private var referral

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
                        take: take, limit: viewModel.freeExportLimit, onPro: { Task { await viewModel.openProFromExportReady() } },
                        onDecline: { viewModel.declineExport() }, invite: inviteLink
                    )
                    .onAppear { if inviteLink != nil { referral.note(.offered, at: .exportReady) } }
                }
            }
            .sheet(isPresented: Binding(
                get: { isActive && viewModel.showsInvites },
                set: { viewModel.showsInvites = $0 }
            )) {
                InviteFriendsSheet(place: .exportReady)
            }
            .fullScreenCover(item: Binding(
                get: { isActive ? viewModel.paywall : nil },
                set: { viewModel.paywall = $0 }
            )) { context in
                PaywallView(context: context) { Task { await viewModel.continueAfterPurchase() } }
            }
    }

    /// "Or invite friends · +3 exports for each friend" under Cue Pro (the free plan's, so always exports), while invites are offered and a
    /// friend can still earn one.
    private var inviteLink: (label: String, action: () -> Void)? {
        guard referral.isOffered, referral.status?.hasReachedLimit != true else { return nil }
        let label = String(localized: "Or invite friends · +\(ReferralRewards.exportsPerFriend) exports for each friend")
        return (label, { Task { await viewModel.openInvitesFromExportReady() } })
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
