//
//  CleanUpRemovedList.swift
//  Cue Studio
//

import SwiftUI

/// "Removed": what Clean up took out, one row per place it can come back, each with Put back; a row that can't says why.
struct CleanUpRemovedList: View {
    @Bindable var viewModel: QuickEditViewModel
    let items: [CleanUpRemovedItem]
    /// "pause" or "word": the rows are `edit.removed.<kind>.<index>`.
    let kind: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Removed")
                .cueFont(.subheadline, weight: .semibold)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item, identifier: "edit.removed.\(kind).\(index)")
            }
        }
        .padding(.top, 8)
    }

    private func row(_ item: CleanUpRemovedItem, identifier: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.clips.removedTitle(item))
                    .cueFont(.subheadline, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Text(viewModel.clips.removedDetail(item))
                    .cueFont(.caption)
                    .monospacedDigit()
                    .foregroundStyle(item.place == nil ? Palette.warnText : Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            if item.place != nil {
                PanelButton(
                    label: String(localized: "Put back"), systemImage: "arrow.uturn.backward", isCompact: true,
                    identifier: "\(identifier).putBack"
                ) { viewModel.clips.putBack(item) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .editorCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
