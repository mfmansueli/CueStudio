//
//  InviteCodeCard.swift
//  Cue Studio
//

import SwiftUI

/// The creator's code, large and spaced so a friend can read it aloud ("K7M 2QX"); the whole card copies it, and its Copy turns into Copied for a
/// moment, with a tap. While the server answers, a quiet wait; when it can't be reached, Try again.
struct InviteCodeCard: View {
    let place: ReferralTelemetryEvent.Place

    @Environment(ReferralService.self) private var referral
    @State private var copied = false
    @State private var copyReset: Task<Void, Never>?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        Group {
            if let status = referral.status {
                Button { copy(status.code) } label: { codeRow(status.code) }
                    .buttonStyle(.cuePressCard)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("invite.copyButton")
            } else if referral.loading == .failed {
                VStack(spacing: 12) {
                    Text("Couldn’t reach Cue. Check your connection and try again.")
                        .cueFont(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { Task { await referral.refresh() } } label: { Text("Try again") }
                        .buttonStyle(.cueSecondary(expands: false))
                        .accessibilityIdentifier("invite.retryButton")
                }
                .padding(18)
                .frame(maxWidth: .infinity)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .accessibilityLabel(Text("Getting your code"))
            }
        }
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(.smooth, value: referral.status)
    }

    private func codeRow(_ code: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR CODE")
                    .hudFont()
                    .interfaceTracking(1)
                    .foregroundStyle(Palette.ink2)
                Text(verbatim: Self.spaced(code))
                    .monoFont(size: 34, weight: .heavy)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel(Text(verbatim: code).speechSpellsOutCharacters())
            }
            Spacer(minLength: 8)
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .cueFont(15, weight: .semibold)
                .foregroundStyle(copied ? Palette.successText : Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: Metrics.hitTarget)
                .background(Palette.fill, in: Capsule())
                .contentTransition(.symbolEffect(.replace))
                .fixedSize()
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 14))
        .contentShape(Rectangle())
    }

    private func copy(_ code: String) {
        UIPasteboard.general.string = code
        referral.note(.copied, at: place)
        Haptics.success()
        withAnimation(.snappy) { copied = true }
        AccessibilityNotification.Announcement(String(localized: "Copied")).post()
        copyReset?.cancel()
        copyReset = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { copied = false }
        }
    }

    /// "K7M 2QX": two groups of three, the way it is read aloud.
    nonisolated static func spaced(_ code: String) -> String {
        guard code.count == ReferralCode.length else { return code }
        return String(code.prefix(3)) + "\u{2009}" + String(code.suffix(3))
    }
}
