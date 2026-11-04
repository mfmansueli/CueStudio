//
//  UltraPayloadView.swift
//  Cue Studio
//

import SwiftUI

/// "What Cue sends" for Ultra: the two calls exactly as they go out (`UltraPayload`, `UltraFlow.standard`), the system instructions and the
/// request of each, in mono. The polish carries the draft the first call wrote, shown here as a placeholder; then the call that fits a script
/// that came back well past the platform's length (`UltraFitRequest`).
struct UltraPayloadView: View {
    let payload: UltraPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stage(
                title: "1 · Draft", detail: "Your request and who you are, for a developed draft.", request: payload.draft, identifier: "ultra.payload.draft"
            )
            stage(
                title: "2 · Polish", detail: "The same request, how you speak and the draft from step 1.",
                request: payload.review(of: String(localized: "[the draft written in step 1]")), identifier: "ultra.payload.review"
            )
            stage(
                title: "3 · Fit to time",
                detail: "Only when the script from step 2 runs well past the platform’s length: that script, the length and how you speak.",
                request: UltraFitRequest(
                    script: String(localized: "[the script polished in step 2]"), platform: payload.request.platform,
                    range: payload.request.targetRange, voice: payload.request.voice, brand: payload.request.brand,
                    countShown: String(localized: "[its word count]")
                ).stage,
                identifier: "ultra.payload.fit"
            )
        }
    }

    private func stage(title: LocalizedStringKey, detail: LocalizedStringKey, request: UltraStageRequest, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).cueFont(.subheadline, weight: .semibold).foregroundStyle(Palette.ink)
            Text(detail).cueFont(.footnote).foregroundStyle(Palette.ink2)
            DisclosureGroup {
                card(request.instructions)
            } label: {
                Text("Instructions to the model").cueFont(.footnote, weight: .semibold).foregroundStyle(Palette.ink)
            }
            .tint(Palette.ink2)
            card(request.prompt)
                .accessibilityIdentifier(identifier)
        }
    }

    private func card(_ text: String) -> some View {
        Text(verbatim: text)
            .monoFont(size: 11.5)
            .lineSpacing(3)
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .background(Palette.sheetNight.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.aiBorder, lineWidth: 0.5))
            .textSelection(.enabled)
    }
}
