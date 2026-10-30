//
//  UltraConsentSheet.swift
//  Cue Studio
//

import SwiftUI

/// Asked before Ultra sends anything: that Google's Gemini writes the script (through Firebase), what goes (the request, the voice preferences, the
/// draft for the polish, technical data), what never goes, what Google may keep, and where to turn it off. "What Cue sends" shows the calls'
/// real text (`UltraPayload`). Allowing it is separate from the Apple Intelligence switch, and saying no changes nothing else in Cue.
struct UltraConsentSheet: View {
    /// What the calls would carry now (the dock's idea and choices, or a placeholder for the idea).
    let payload: UltraPayload
    /// Allowing it writes the script at once (Find inspiration's idea), and the button says so; elsewhere it only picks Ultra AI.
    var writesNow = false
    /// The permission is given by the caller (`UltraConsentService.grant`), which then goes on.
    let onAllow: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UltraScriptService.self) private var ultra
    @State private var showsPayload = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    point(
                        title: "Your request goes to Google",
                        detail: "Ultra AI sends your idea, the platform, format and length you picked, and your My Cue Voice preferences (who you are, who you speak to, how you sound) to Google, which runs the model behind it.",
                        systemImage: "paperplane"
                    )
                    point(
                        title: "Three steps",
                        detail: "Ultra AI writes a draft, checks its claims, then polishes it in your voice: the draft goes back to Google for each step. It can still get facts wrong, so check them before you record.",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                    point(
                        title: "What stays on this iPhone",
                        detail: "Your writing examples, imported excerpts, approved scripts, other scripts, videos and audio are never sent. Fit to time on a script Ultra AI wrote sends that script back, with your edits.",
                        systemImage: "iphone"
                    )
                    point(
                        title: "What Google may keep",
                        detail: "Google doesn’t train its models on it without permission, but may cache it for up to 24 hours and keep it to watch for abuse. It can be processed in any region. Your IP address, this app’s identity and an App Check token go with each request.",
                        systemImage: "building.columns"
                    )
                    point(
                        title: "Turn it off any time",
                        detail: "Settings › Privacy & AI data. Apple Intelligence keeps working either way.",
                        systemImage: "switch.2"
                    )
                    DisclosureGroup(isExpanded: $showsPayload) {
                        UltraPayloadView(payload: payload).padding(.top, 10)
                    } label: {
                        Text("What Cue sends").cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                    }
                    .tint(Palette.ink2)
                    .accessibilityIdentifier("ultra.consent.sends")
                    buttons
                }
                .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 32, trailing: Metrics.gutter))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .accessibilityIdentifier("ultra.consent.close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .cueSheetSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ultra.consent")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ultra AI · Experiment")
                .textCase(.uppercase)
                .monoFont(size: 10.5, weight: .bold)
                .interfaceTracking(1)
                .foregroundStyle(Palette.aiText)
            Text("Write with Ultra AI?")
                .cueFont(.title2, weight: .bold)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // The scripts it may write: the free ones to try it, or this month's with Cue Pro.
            if let allowance = ultra.allowance?.allowance {
                Text(verbatim: UltraAllowanceLabels.consent(allowance))
                    .cueFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Palette.aiText)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityIdentifier("ultra.consent.allowance")
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                onAllow()
                dismiss()
            } label: { Text(allowTitle) }
                .buttonStyle(.cuePrimary(.large))
                .accessibilityIdentifier("ultra.consent.allow")
            Button { dismiss() } label: { Text("Keep Apple Intelligence") }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("ultra.consent.decline")
        }
        .padding(.top, 4)
    }

    private var allowTitle: LocalizedStringKey { writesNow ? "Allow and write with Ultra AI" : "Allow Ultra AI" }

    private func point(title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: systemImage)
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.aiText)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
                Text(detail).cueFont(.footnote).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        UltraConsentSheet(payload: AppServices.preview.starter.ultraPreview(), onAllow: {})
    }
    .previewEnvironment()
}
#endif
