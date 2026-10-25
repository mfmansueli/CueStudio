//
//  BrandKitApplySheet.swift
//  Cue Studio
//

import SwiftUI

/// Putting a kit on the video, said before it happens: each part the kit has (with its style's name), with what it would change
/// here ("On 4 texts · words, timing and place stay"), all on at first; one that can't (no cover yet, the logo's file gone) says why.
/// "Apply to this video" is one undo step.
struct BrandKitApplySheet: View {
    let viewModel: QuickEditViewModel
    let kit: BrandKit

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: Set<BrandKitPart> = []

    private var brand: BrandViewModel { viewModel.brand }

    var body: some View {
        let changes = brand.changes(for: kit)
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: String(localized: "Apply \(kit.name)"), subtitle: String(localized: "Choose what changes in this video"))
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(changes) { change in row(change) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            PanelButton(
                label: String(localized: "Apply to this video"), isPrimary: true, isEnabled: !chosen.isEmpty, identifier: "edit.brand.apply"
            ) {
                brand.apply(kit, parts: chosen)
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { chosen = Set(changes.filter(\.isAvailable).map(\.part)) }
        .onDisappear { brand.kitToApply = nil }
    }

    private func row(_ change: BrandViewModel.KitChange) -> some View {
        let isOn = chosen.contains(change.part)
        return Button {
            guard change.isAvailable else { return }
            Haptics.selection()
            if isOn { chosen.remove(change.part) } else { chosen.insert(change.part) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: change.part.systemImage)
                    .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(change.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(change.detail).font(.footnote).foregroundStyle(Palette.ink2).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.editorGlyph(EditorGlyph.large))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: Metrics.hitTarget)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(.editorCard)
            .opacity(change.isAvailable ? 1 : Metrics.disabledOpacity)
        }
        .buttonStyle(.cuePressCard)
        .disabled(!change.isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.brand.part.\(change.part.rawValue)")
    }
}
