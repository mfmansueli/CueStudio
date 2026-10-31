//
//  UltraConsentSheet.swift
//  Cue Studio
//

import SwiftUI

/// Asked before Ultra sends anything, as an invitation (owner, 31/10/2026: short, inviting, the free scripts first): Ultra AI's ✦ in its galaxy
/// (`UltraConsentHero`), the free scripts it may write, three lines on what it does, and one line that says the request goes to Google and where
/// to turn it off (Settings › Privacy & AI data has the rest). Allowing it is separate from the Apple Intelligence switch, and saying no
/// changes nothing else in Cue.
struct UltraConsentSheet: View {
    /// Allowing it writes the script at once (Find inspiration's idea), and the button says so; elsewhere it only picks Ultra AI.
    var writesNow = false
    /// The permission is given by the caller (`UltraConsentService.grant`), which then goes on.
    let onAllow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UltraScriptService.self) private var ultra

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    UltraConsentHero()
                    header
                    benefits
                }
                .padding(EdgeInsets(top: 28, leading: Metrics.gutter, bottom: 16, trailing: Metrics.gutter))
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ultra.consent")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Meet Ultra AI")
                .cueFont(.title, weight: .bold)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            // The scripts it may write: the free ones to try it, or this month's with Cue Pro.
            if let allowance = ultra.allowance?.allowance {
                Text(verbatim: UltraAllowanceLabels.consent(allowance))
                    .cueFont(.title3, weight: .semibold)
                    .foregroundStyle(Palette.aiText)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("ultra.consent.allowance")
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 16) {
            benefit("Goes further with every idea", systemImage: "sparkles")
            benefit("Checks its claims as it writes", systemImage: "checkmark.seal")
            benefit("Polished in your voice", systemImage: "waveform")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .cueFont(.body, weight: .semibold)
                .foregroundStyle(Palette.aiText)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(title)
                .cueFont(.body, weight: .medium)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// What goes, in one line, over the two buttons.
    private var footer: some View {
        VStack(spacing: 12) {
            Text("Your idea, your choices and your My Cue Voice preferences go to Google, which writes it. Turn it off any time in Settings.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("ultra.consent.disclosure")
            Button {
                onAllow()
                dismiss()
            } label: { Text(allowTitle) }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("ultra.consent.allow")
            Button { dismiss() } label: { Text("Not now") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("ultra.consent.decline")
        }
        .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 12, trailing: Metrics.gutter))
    }

    /// The free scripts lead: "Try it free" while the first ones are still there.
    private var allowTitle: LocalizedStringKey {
        let free = (ultra.allowance?.allowance).map { $0.membership != .paid && $0.freeLeft > 0 } ?? false
        switch (free, writesNow) {
        case (true, true): return "Write it free with Ultra AI"
        case (true, false): return "Try it free"
        case (false, true): return "Allow and write with Ultra AI"
        case (false, false): return "Allow Ultra AI"
        }
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        UltraConsentSheet(onAllow: {})
    }
    .previewEnvironment()
}
#endif
