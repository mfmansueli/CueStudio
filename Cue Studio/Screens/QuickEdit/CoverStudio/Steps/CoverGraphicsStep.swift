//
//  CoverGraphicsStep.swift
//  Cue Studio
//

import SwiftUI

/// Graphics: the picked one's controls first (its words for a tag or the handle, color, size and turn, also with fingers on the
/// cover, Copy, In front / Behind and Delete), then a small row to add an arrow, a circle, a tag or the @handle.
struct CoverGraphicsStep: View {
    let viewModel: CoverStudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let item = viewModel.selectedItem {
                selected(item)
                addRow
            } else {
                addRow
                PanelNote(text: String(localized: "Tap a graphic on the cover to change it. Drag to move, pinch or use the corner to resize and turn."), teaches: true)
            }
        }
    }

    /// One 44 pt row of chips. Equal while every name fits one; else each as wide as its name and the rest shared
    /// ("@gebruikersnaam" takes more than "Pijl"): a name is never cut (owner, 02/11/2026: no label is ever cut).
    private var addRow: some View {
        FairShareLayout(spacing: 6) {
            ForEach(CoverItemKind.allCases) { kind in
                Button { viewModel.addItem(kind) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: kind.systemImage).font(.editorGlyph(EditorGlyph.chip, weight: .semibold))
                        Text(kind.label).font(.system(.caption, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    .background(Palette.fill, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.cuePress)
                .accessibilityLabel(Text("Add \(kind.label)"))
                .accessibilityIdentifier("cover.add.\(kind.rawValue)")
            }
        }
        // The chips' own height, not the panel's.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func selected(_ item: CoverItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.kind.hasText {
                TextField(item.kind == .handle ? String(localized: "yourname") : String(localized: "Tag"), text: Binding(
                    get: { item.text }, set: { text in viewModel.updateItem(item.id, key: "cover.item.\(item.id)") { $0.text = String(text.prefix(28)) } }
                ))
                .font(.system(.callout, weight: .semibold))
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: Metrics.hitTarget)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .accessibilityIdentifier("cover.itemText")
            }
            PanelSwatches(
                label: String(localized: "Color"), colors: OverlayColor.palette, selection: item.color,
                identifier: "cover.itemColor"
            ) { color in viewModel.updateItem(item.id) { $0.color = color } }
            PanelSlider(
                label: String(localized: "Size"), value: item.scale * 100,
                range: CoverItem.scaleRange.lowerBound * 100...CoverItem.scaleRange.upperBound * 100, step: 5, defaultValue: 100,
                format: .percent, identifier: "cover.itemSize",
                onChange: { value in viewModel.updateItem(item.id) { $0.scale = value / 100 } }, onEditingChanged: gesture
            )
            PanelSlider(
                label: String(localized: "Turn"), value: item.rotation * 180 / .pi, range: -180...180, step: 1, defaultValue: 0,
                bipolar: true, format: .degrees, identifier: "cover.itemTurn",
                onChange: { value in viewModel.updateItem(item.id) { $0.rotation = value * .pi / 180 } }, onEditingChanged: gesture
            )
            HStack(spacing: 8) {
                action(String(localized: "Duplicate"), "plus.square.on.square", id: "cover.itemDuplicate") { viewModel.duplicateItem(item.id) }
                action(String(localized: "In front"), "square.2.layers.3d.top.filled", id: "cover.itemForward",
                       isEnabled: viewModel.canRestack(item.id, forward: true)) { viewModel.restackItem(item.id, forward: true) }
                action(String(localized: "Behind"), "square.2.layers.3d.bottom.filled", id: "cover.itemBackward",
                       isEnabled: viewModel.canRestack(item.id, forward: false)) { viewModel.restackItem(item.id, forward: false) }
                action(String(localized: "Delete"), "trash", id: "cover.itemDeleteButton", isDestructive: true) { viewModel.deleteItem(item.id) }
            }
        }
    }

    private func action(
        _ title: String, _ symbol: String, id: String, isEnabled: Bool = true, isDestructive: Bool = false, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.editorGlyph(EditorGlyph.tile, weight: .semibold))
                Text(title).font(.system(.caption2, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(isDestructive ? Palette.dangerText : Palette.ink)
            .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier(id)
    }

    private func gesture(_ editing: Bool) {
        if editing { viewModel.beginGesture() } else { viewModel.endGesture() }
    }
}
