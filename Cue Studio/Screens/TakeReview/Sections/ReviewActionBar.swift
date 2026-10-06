//
//  ReviewActionBar.swift
//  Cue Studio
//

import SwiftUI

/// Edit (or Continue, when an edit is open) · Retake · Save · Script as four glass tiles (icon over name, 54 pt high), and below, the screen's one yellow
/// action: **Share to universe**.
struct ReviewActionBar: View {
    let runningAction: TakeReviewViewModel.ExportAction?
    /// Share glows for a moment after "Ready, I'll post later": it is the next step.
    var glowsShare = false
    /// "Continue" when an edit is waiting, "Edit" otherwise.
    let editTitle: String
    var onEdit: (() -> Void)?
    let onRetake: () -> Void
    let onSave: () -> Void
    /// The take's script, when it has one.
    var onScript: (() -> Void)?
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                tile(editTitle, systemImage: "scissors", identifier: "review.editButton", isEnabled: onEdit != nil, action: onEdit ?? {})
                tile("Retake", systemImage: "arrow.clockwise", identifier: "review.retakeButton", action: onRetake)
                tile("Save", systemImage: "arrow.down.to.line", identifier: "review.saveButton", isRunning: runningAction == .save, action: onSave)
                tile("Script", systemImage: "doc.text", identifier: "review.scriptButton", isEnabled: onScript != nil, action: onScript ?? {})
            }
            Button(action: onShare) {
                HStack(spacing: 8) {
                    if runningAction == .render {
                        ProgressView().tint(Palette.accInk)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Share to universe")
                }
            }
            .buttonStyle(.cuePrimary(.large))
            .shadow(color: Palette.acc.opacity(glowsShare ? 0.7 : 0.3), radius: glowsShare ? 22 : 18)
            .animation(.easeInOut(duration: 0.4), value: glowsShare)
            .accessibilityIdentifier("review.shareButton")
        }
        .disabled(runningAction != nil)
    }

    private func tile(
        _ title: String, systemImage: String, identifier: String, isRunning: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if isRunning { ProgressView().tint(Palette.ink) } else { Image(systemName: systemImage).font(.system(size: 17, weight: .semibold)) }
                }
                .frame(height: 20)
                Text(title).font(.system(size: 12.5, weight: .semibold))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier(identifier)
    }
}
