//
//  WritingFindingRow.swift
//  Cue Studio
//

import SwiftUI

/// One thing Cue heard in the creator's writing: what it is, what it found, where it came from, and a switch to keep it or not. A finding that
/// would replace an answer of theirs says so under it, with what they have now.
struct WritingFindingRow: View {
    let finding: WritingFinding
    /// What the creator has now for this, when the finding would replace it.
    let current: String?
    let onToggle: () -> Void

    var body: some View {
        Toggle(isOn: Binding(get: { finding.isOn }, set: { _ in onToggle() })) {
            VStack(alignment: .leading, spacing: 3) {
                Text(finding.id.title.uppercased())
                    .font(CueStudioFont.hud)
                    .tracking(0.6)
                    .foregroundStyle(Palette.inkHint)
                Text(finding.value.display)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let support = finding.support {
                    Text("Texts with it: \(support.found) of \(support.of)")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                if finding.replaces, let current, !current.isEmpty {
                    Text("Replaces: \(current)")
                        .font(.footnote)
                        .foregroundStyle(Palette.warnText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Palette.successText)
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("import.finding.\(finding.id.rawValue)")
    }
}
