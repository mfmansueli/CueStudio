//
//  RewriteCandidateCard.swift
//  Cue Studio
//

import SwiftUI

/// What the AI wrote for the selection: the old words struck through, the new ones in bold, and the
/// choice: "Use" (yellow) or "Keep mine".
struct RewriteCandidateCard: View {
    let candidate: RewriteCandidate
    let onUse: () -> Void
    let onKeep: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("✦ \(candidate.action.title)")
                .font(CueStudioFont.hud)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Palette.recommendationIcon)
            Text(candidate.original)
                .font(.footnote)
                .strikethrough()
                .foregroundStyle(Palette.recommendationIcon.opacity(0.6))
                .lineLimit(4)
                .accessibilityLabel(Text("Your words: \(candidate.original)"))
            ScrollView {
                Text(candidate.rewritten)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("page.candidate.text")
            HStack(spacing: 8) {
                Button(action: onUse) { Text("Use") }
                    .buttonStyle(.cuePrimary())
                    .accessibilityIdentifier("page.candidate.use")
                Button(action: onKeep) { Text("Keep mine") }
                    .buttonStyle(.cueGlass())
                    .accessibilityIdentifier("page.candidate.keep")
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Palette.recommendationTop, Palette.recommendationBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.recommendationRim, lineWidth: 0.5))
        .shadow(color: Palette.recommendationShadow, radius: 24, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("page.candidate")
    }
}
