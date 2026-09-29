//
//  TextOverlaySheet.swift
//  Cue Studio
//

import SwiftUI

/// Writes and styles one text: what it says, a quick style, then font, weight, size, alignment,
/// color, background, shadow and outline. The preview above updates as it changes; everything
/// done here is one undo step.
struct TextOverlaySheet: View {
    let viewModel: QuickEditViewModel
    let textID: UUID

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isWriting: Bool

    var body: some View {
        if let text = viewModel.edit.texts.first(where: { $0.id == textID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SheetHeader(title: text.role.label, subtitle: nil) { dismiss() }
                    TextField(text.role.placeholder, text: binding(\.text), axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1...4)
                        .focused($isWriting)
                        .padding(14)
                        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                        .accessibilityIdentifier("textSheet.field")
                    styles(text)
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        picker(String(localized: "Font"), selection: binding(\.font, field: .font), options: TextOverlayFont.allCases) { $0.label }
                        picker(String(localized: "Weight"), selection: binding(\.weight, field: .weight), options: TextOverlayWeight.allCases) { $0.label }
                        ValueSlider(
                            title: String(localized: "Size"),
                            valueText: "\(Int(text.size.rounded()))",
                            value: binding(\.size, field: .size),
                            range: TextOverlay.sizeRange, step: 1,
                            identifier: "textSheet.size"
                        )
                        .padding(.horizontal, 16)
                        ValueSlider(
                            title: String(localized: "Letter spacing"),
                            valueText: text.tracking.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                            value: binding(\.tracking, field: .tracking),
                            range: TextLook.trackingRange, step: 0.01,
                            identifier: "textSheet.tracking"
                        )
                        .padding(.horizontal, 16)
                        alignment
                    }
                    colors(String(localized: "Color"), selection: binding(\.color, field: .color))
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        picker(String(localized: "Background"), selection: binding(\.background, field: .background), options: TextOverlayBackground.allCases) { $0.label }
                        SettingToggleRow(title: String(localized: "Shadow"), isOn: binding(\.hasShadow, field: .shadow), minHeight: 50)
                        SettingToggleRow(title: String(localized: "Outline"), isOn: binding(\.hasOutline, field: .outline), minHeight: 50)
                        SettingToggleRow(title: String(localized: "All caps"), isOn: binding(\.isUppercase, field: .letterCase), minHeight: 50)
                    }
                    if text.background != .none {
                        colors(String(localized: "Background color"), selection: binding(\.backgroundColor, field: .background))
                        ValueSlider(
                            title: String(localized: "Background opacity"),
                            valueText: text.backgroundOpacity.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                            value: binding(\.backgroundOpacity, field: .background),
                            range: 0.2...1, step: 0.05,
                            identifier: "textSheet.backgroundOpacity"
                        )
                    }
                    HStack(spacing: 10) {
                        Button {
                            viewModel.deleteText(textID)
                            dismiss()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.cueDestructiveTinted(.regular))
                        .accessibilityIdentifier("textSheet.delete")
                        Button("Done") { dismiss() }
                            .buttonStyle(.cuePrimary(.regular))
                            .accessibilityIdentifier("textSheet.done")
                    }
                }
                .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.surface)
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .onAppear {
                viewModel.beginChange()
                if text.text == text.role.placeholder { isWriting = true }
            }
            .onDisappear { viewModel.endChange() }
        }
    }

    // MARK: - Sections

    private func styles(_ text: TextOverlay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if viewModel.myStyle != nil {
                        Button { viewModel.applyMyStyle(to: .selected) } label: {
                            FilterChip(label: String(localized: "My style"), isSelected: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("textSheet.style.mine")
                    }
                    ForEach(TypePreset.allCases) { preset in
                        Button { viewModel.applyPreset(preset, to: .selected) } label: {
                            FilterChip(label: preset.label, isSelected: text.preset == preset)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(text.preset == preset ? .isSelected : [])
                        .accessibilityIdentifier("textSheet.style.\(preset.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            Button {
                viewModel.saveMyStyle()
            } label: {
                Label("Save as My style", systemImage: "bookmark")
            }
            .buttonStyle(.cueSecondary(.compact))
            .accessibilityIdentifier("textSheet.saveMyStyle")
        }
    }

    private var alignment: some View {
        HStack {
            Text("Alignment")
            Spacer()
            Picker("Alignment", selection: binding(\.alignment, field: .alignment)) {
                ForEach(TextOverlayAlignment.allCases) { alignment in
                    Image(systemName: alignment.systemImage)
                        .accessibilityLabel(Text(alignment.label))
                        .tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private func picker<Option: Hashable & Identifiable>(
        _ title: String, selection: Binding<Option>, options: [Option], label: @escaping (Option) -> String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private func colors(_ title: String, selection: Binding<OverlayColor>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
            HStack(spacing: 0) {
                ForEach(OverlayColor.allCases) { color in
                    SwatchButton(color: color.color, isSelected: selection.wrappedValue == color, accessibilityName: color.label) {
                        selection.wrappedValue = color
                    }
                }
            }
        }
    }

    /// A field of the text, read from the edit and written through the view model. A part of the
    /// look (`field`) changed here is remembered as the creator's own.
    private func binding<Value>(_ keyPath: WritableKeyPath<TextOverlay, Value>, field: TextLookField? = nil) -> Binding<Value> {
        let fallback = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 0, end: 1))
        return Binding(
            get: {
                // The sheet only shows while the text exists.
                (viewModel.edit.texts.first { $0.id == textID } ?? fallback)[keyPath: keyPath]
            },
            set: { value in
                if let field {
                    viewModel.customizeText(textID, field) { $0[keyPath: keyPath] = value }
                } else {
                    viewModel.updateText(textID) { $0[keyPath: keyPath] = value }
                }
            }
        )
    }
}
