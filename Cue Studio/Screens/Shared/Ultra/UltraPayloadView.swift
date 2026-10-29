//
//  UltraPayloadView.swift
//  Cue Studio
//

import SwiftUI

/// "What Cue sends" for Ultra: the three calls exactly as they go out (`UltraPayload`, `UltraFlow.checked`), the system instructions and the
/// request of each, in mono. The check carries the draft Gemini wrote in the first call, and the polish the checked draft and what the check
/// corrected, shown here as placeholders.
struct UltraPayloadView: View {
    let payload: UltraPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stage(
                title: "1 · Draft", detail: "Your request and who you are, for a developed draft.", request: payload.draft, identifier: "ultra.payload.draft"
            )
            stage(
                title: "2 · Check", detail: "The same request and who you are, with the draft from step 1, for its claims to be checked.",
                request: payload.check(of: String(localized: "[the draft written in step 1]")), identifier: "ultra.payload.check"
            )
            stage(
                title: "3 · Polish", detail: "The same request, how you speak, the draft checked in step 2 and what it corrected.",
                request: payload.review(
                    of: String(localized: "[the draft checked in step 2]"), corrections: [String(localized: "[what step 2 corrected]")]
                ),
                identifier: "ultra.payload.review"
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
