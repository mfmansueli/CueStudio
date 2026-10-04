//
//  ReviewActionBar.swift
//  Cue Studio
//

import SwiftUI

/// Edit (or Continue, when an edit is open) · Retake · Save as three round glass buttons with their
/// names under them, and below, the screen's one yellow action: Share to the take's platform.
struct ReviewActionBar: View {
    let runningAction: TakeReviewViewModel.ExportAction?
    /// Share glows for a moment after "Ready, I'll post later": it is the next step.
    var glowsShare = false
    /// "Share to TikTok", or just "Share" for a freestyle take.
    let shareTitle: String
    /// "Continue" when an edit is waiting, "Edit" otherwise.
    let editTitle: String
    var onEdit: (() -> Void)?
    let onRetake: () -> Void
    let onSave: () -> Void
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 28) {
                if let onEdit {
                    round(editTitle, systemImage: "pencil", identifier: "review.editButton", action: onEdit)
                }
                round("Retake", systemImage: "arrow.counterclockwise", identifier: "review.retakeButton", action: onRetake)
                round(
                    "Save", systemImage: "arrow.down.to.line", identifier: "review.saveButton",
                    isRunning: runningAction == .save, action: onSave
                )
            }
            Button(action: onShare) {
                HStack(spacing: 8) {
                    if isSharing {
                        ProgressView().tint(Palette.accInk)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(shareTitle)
                }
            }
            .buttonStyle(.cuePrimary(.large))
            .shadow(color: Palette.acc.opacity(glowsShare ? 0.6 : 0), radius: 16)
            .animation(.easeInOut(duration: 0.4), value: glowsShare)
            .accessibilityIdentifier("review.shareButton")
        }
        .disabled(runningAction != nil)
    }

    private var isSharing: Bool {
        if case .share = runningAction { true } else { false }
    }

    private func round(
        _ title: String, systemImage: String, identifier: String, isRunning: Bool = false, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if isRunning {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
                    }
                }
                .foregroundStyle(Palette.ink)
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive(), in: Circle())
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink)
            }
            .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }
}
