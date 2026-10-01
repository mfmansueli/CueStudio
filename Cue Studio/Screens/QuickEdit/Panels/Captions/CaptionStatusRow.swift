//
//  CaptionStatusRow.swift
//  Cue Studio
//

import SwiftUI

/// Where listening is ("Listening to your take… 35%") with Stop, or why there are no captions
/// ("No speech found in this take.") with Try again when it may work next time.
struct CaptionStatusRow: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        if let message = viewModel.captionState.message {
            HStack(spacing: 10) {
                if viewModel.captionState.isWorking {
                    ProgressView().controlSize(.small).tint(Palette.ink)
                }
                Text(message)
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("edit.captionsStatus")
                if viewModel.captionState.isWorking {
                    button(String(localized: "Stop"), identifier: "edit.captionsStopButton", action: viewModel.cancelCaptions)
                } else if viewModel.captionState.canRetry {
                    button(String(localized: "Try again"), identifier: "edit.captionsRetryButton") { viewModel.makeCaptions() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func button(_ label: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(.footnote, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Palette.fill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
