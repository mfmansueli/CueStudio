//
//  WritingImportReviewView.swift
//  Cue Studio
//

import SwiftUI

/// The last step: what Cue heard, one switch for each thing, and the excerpts it would keep. Nothing is saved until "Add to My Cue Voice".
struct WritingImportReviewView: View {
    let model: WritingImportViewModel
    let onAccept: () -> Void
    @Environment(CreatorProfileService.self) private var profile

    private var proposal: WritingImportProposal { model.proposal }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summary
            if proposal.hasAnything || !proposal.findings.isEmpty {
                ForEach(proposal.findings) { finding in
                    WritingFindingRow(finding: finding, current: finding.id.current(in: profile.profile)) { model.toggle(finding.id) }
                }
                if !proposal.excerpts.isEmpty { kept }
                Button(action: onAccept) { Text("Add to My Cue Voice") }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("import.accept")
            } else {
                Text("Nothing found yet. Add more texts and try again.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("import.nothing")
            }
            Button("Back to my texts") { model.backToTexts() }
                .buttonStyle(.cueSecondary(.large))
                .accessibilityIdentifier("import.back")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("import.review")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Texts: \(proposal.pieceCount) · Words: \(proposal.wordCount)")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("import.summary")
            if proposal.isMixedLanguage {
                Text("Only the main language was read.")
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
            }
            if proposal.blockedPieces > 0 {
                Text("Some texts were left out of the excerpts: words Apple Intelligence won’t learn from.")
                    .font(.footnote)
                    .foregroundStyle(Palette.warnText)
            }
        }
    }

    private var kept: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup {
                VStack(spacing: 8) {
                    ForEach(proposal.excerpts) { excerpt in
                        ExcerptRow(excerpt: excerpt) { model.removeExcerpt(excerpt.id) }
                    }
                }
                .padding(.top, 8)
            } label: {
                VoiceFieldLabel(String(localized: "Kept to learn from"), detail: String(localized: "Excerpts: \(proposal.excerpts.count)"))
            }
            .tint(Palette.ink2)
            .accessibilityIdentifier("import.kept")
            Text("Teaches how you talk — never reused for stories, opinions or results. Stays on this iPhone.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 4)
        }
    }
}
