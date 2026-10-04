//
//  ScriptShapedView.swift
//  Cue Studio
//

import SwiftUI

/// "Shaped": the words as sections with the length against the platform's range, and advice. It
/// reads the text and never rewrites it; to change a word, go back to Draft.
struct ScriptShapedView: View {
    let viewModel: ScriptDetailViewModel
    let onHook: () -> Void

    var body: some View {
        let shape = viewModel.shaped
        VStack(alignment: .leading, spacing: 0) {
            ScriptLengthBar(zone: viewModel.zone)
                .padding(.top, 12)
            if viewModel.needsFactCheck {
                FactCheckBanner(onChecked: viewModel.markFactChecked)
                    .padding(.top, 12)
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(shape.sections) { section in
                    ScriptSectionView(
                        section: section,
                        tip: tip(for: section, in: shape),
                        textSize: viewModel.page.textSize,
                        onFix: viewModel.apply,
                        onDismiss: viewModel.dismiss,
                        onSuggestCTA: viewModel.suggestCTA,
                        onHook: onHook
                    )
                }
                if shape.sections.isEmpty {
                    Text("Nothing to shape yet. Write in Draft.")
                        .font(.body)
                        .foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("page.emptyShaped")
                }
            }
            .padding(.top, 16)
            Button { viewModel.setMode(.draft) } label: {
                Text("Edit in Draft · Shaping never rewrites.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .multilineTextAlignment(.leading)
                    .frame(minHeight: Metrics.hitTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .accessibilityIdentifier("page.toDraft")
        }
    }

    private func tip(for section: ScriptShape.Section, in shape: ScriptShape) -> ScriptShape.Tip? {
        if section.isHook { return viewModel.visibleTip(shape.hookTip) }
        if section.firstParagraph == shape.sections.first(where: { !$0.isHook && !$0.isMissingCTA })?.firstParagraph {
            return viewModel.visibleTip(shape.bodyTip)
        }
        return nil
    }
}
