//
//  ExportFailedCard.swift
//  Cue Studio
//

import SwiftUI

/// The last export failed (04 · F6): "Couldn't export", why, and **Try again**, in the place the export was asked for. It stays until it is
/// closed or an export starts, so a failure right after a purchase (the paywall still leaving) isn't missed as a toast was.
struct ExportFailedCard: View {
    let failure: ExportFailure
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        NoticeCard(
            title: String(localized: "Couldn’t export"), line: failure.line, systemImage: "exclamationmark",
            actionTitle: String(localized: "Try again"), actionIdentifier: "review.exportFailed.retry", onAction: onRetry,
            onClose: onClose
        )
        .accessibilityIdentifier("review.exportFailed")
    }
}

#if DEBUG
#Preview {
    ExportFailedCard(failure: ExportFailure(error: CancellationError(), action: .save), onRetry: {}, onClose: {})
        .padding()
        .background(Palette.bg)
}
#endif
