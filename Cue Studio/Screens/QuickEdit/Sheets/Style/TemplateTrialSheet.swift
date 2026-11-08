//
//  TemplateTrialSheet.swift
//  Cue Studio
//

import SwiftUI

/// A template tried on (`TemplateTrial`): low, so the video above shows how it really looks (with the creator's kit, if the
/// video wears one); each thing it changes, and what it keeps; what was styled by hand stays, with switches to replace it too
/// (`ManualChangesOptions`). Apply keeps it as one undo step; Cancel, or swiping the sheet away, leaves the video as it was.
struct TemplateTrialSheet: View {
    let viewModel: QuickEditViewModel
    let trial: TemplateTrial

    @Environment(\.dismiss) private var dismiss
    /// Apply ended it: closing doesn't take the template off.
    @State private var isKept = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: trial.template.label, subtitle: String(localized: "On the video now · Apply to keep it")) {
                dismiss()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(trial.lines) { line in row(line) }
                    ManualChangesOptions(
                        changes: trial.manual,
                        replacing: Binding(get: { trial.replacing }, set: { viewModel.setTemplateReplacing($0) })
                    )
                    .padding(.top, 4)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PanelButton(label: String(localized: "Apply"), isPrimary: true, identifier: "edit.template.apply") {
                isKept = true
                viewModel.keepVideoTemplate()
                dismiss()
            }
            Text("One step: Undo puts it all back")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .cueSheetChrome()
        .presentationDetents([.fraction(0.5), .large])
        .presentationDragIndicator(.visible)
        .onDisappear { if !isKept { viewModel.dropVideoTemplate() } }
        .accessibilityIdentifier("edit.template.sheet")
    }

    private func row(_ line: TemplateTrial.Line) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: line.systemImage)
                .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Text(line.detail).font(.footnote).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .editorCard(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.template.change.\(line.id)")
    }
}
