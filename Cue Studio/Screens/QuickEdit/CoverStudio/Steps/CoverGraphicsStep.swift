//
//  CoverGraphicsStep.swift
//  Cue Studio
//

import SwiftUI

/// Graphics: add an arrow, a circle, a tag or the @handle; the picked one gets its color, its words (a tag, the handle), size
/// and turn (also with fingers on the cover), Copy, In front / Behind and Delete.
struct CoverGraphicsStep: View {
    let viewModel: CoverStudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ForEach(CoverItemKind.allCases) { kind in
                    Button { viewModel.addItem(kind) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.systemImage).font(.system(size: 18, weight: .semibold))
                            Text(kind.label).font(.system(.caption, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.cuePressCard)
                    .accessibilityLabel(Text("Add \(kind.label)"))
                    .accessibilityIdentifier("cover.add.\(kind.rawValue)")
                }
            }
            if let item = viewModel.selectedItem {
                selected(item)
            } else {
                PanelNote(text: String(localized: "Tap a graphic on the cover to change it. Drag to move, pinch or use the corner to resize and turn."))
            }
        }
    }

    private func selected(_ item: CoverItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.kind.hasText {
                TextField(item.kind == .handle ? String(localized: "yourname") : String(localized: "Tag"), text: Binding(
                    get: { item.text }, set: { text in viewModel.updateItem(item.id) { $0.text = String(text.prefix(28)) } }
                ))
                .font(.system(.callout, weight: .semibold))
                .submitLabel(.done)
                .padding(.horizontal, 12)
                .frame(height: Metrics.hitTarget)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                .accessibilityIdentifier("cover.itemText")
            }
            PanelSwatches(
                label: String(localized: "Color"), colors: [.yellow, .red, .white, .black, .cyan, .mint, .blush], selection: item.color,
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
                action(String(localized: "Copy"), "plus.square.on.square", id: "cover.itemDuplicate") { viewModel.duplicateItem(item.id) }
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
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold))
                Text(title).font(.system(.caption2, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(isDestructive ? Palette.dangerText : Palette.ink)
            .opacity(isEnabled ? 1 : Metrics.disabledOpacity)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
