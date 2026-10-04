//
//  ScriptTipsView.swift
//  Cue Studio
//

import SwiftUI

/// Advice under the words: a hook that runs long and a sentence that is hard to read aloud (each with its fix and ✕), and a
/// closing with no call to action ("Suggest one"). Plain advice from reading the words, not the AI: neutral, never violet.
struct ScriptTipsView: View {
    let viewModel: ScriptDetailViewModel

    var body: some View {
        let shape = viewModel.shaped
        let hook = viewModel.visibleTip(shape.hookTip)
        let body = viewModel.visibleTip(shape.bodyTip)
        let needsCTA = shape.sections.last?.isMissingCTA == true
        if hook != nil || body != nil || needsCTA {
            VStack(alignment: .leading, spacing: 8) {
                if let hook { row(hook) }
                if let body { row(body) }
                if needsCTA { ctaRow }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("page.tips")
        }
    }

    private func row(_ tip: ScriptShape.Tip) -> some View {
        ScriptTipRow(tip: tip, onFix: { viewModel.apply(tip) }, onDismiss: { viewModel.dismiss(tip) })
    }

    private var ctaRow: some View {
        HStack(spacing: 8) {
            Text("No CTA yet")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { viewModel.suggestCTA() } label: {
                Text("Suggest one")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("page.suggestCTA")
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
