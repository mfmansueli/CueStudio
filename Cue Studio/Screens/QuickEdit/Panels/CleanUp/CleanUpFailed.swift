//
//  CleanUpFailed.swift
//  Cue Studio
//

import SwiftUI

/// Clean up couldn't listen to the take: Try again.
struct CleanUpFailed: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Couldn't listen to this take").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            Text("Nothing was changed.").cueFont(.footnote).foregroundStyle(Palette.ink2)
            Button(String(localized: "Try again"), action: onRetry)
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.accText)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("edit.pauses.retry")
        }
        .frame(maxWidth: .infinity, minHeight: 92)
        .editorCard()
    }
}
