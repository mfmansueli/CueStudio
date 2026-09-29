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
                    styles
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        picker(String(localized: "Font"), selection: binding(\.font), options: TextOverlayFont.allCases) { $0.label }
                        picker(String(localized: "Weight"), selection: binding(\.weight), options: TextOverlayWeight.allCases) { $0.label }
                        ValueSlider(
                            title: String(localized: "Size"),
                            valueText: "\(Int(text.size.rounded()))",
                            value: binding(\.size),
                            range: TextOverlay.sizeRange, step: 1,
                            identifier: "textSheet.size"
                        )
                        .padding(.horizontal, 16)
                        alignment
                    }
                    colors(String(localized: "Color"), selection: binding(\.color))
                    GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius) {
                        picker(String(localized: "Background"), selection: binding(\.background), options: TextOverlayBackground.allCases) { $0.label }
                        SettingToggleRow(title: String(localized: "Shadow"), isOn: binding(\.hasShadow), minHeight: 50)
                        SettingToggleRow(title: String(localized: "Outline"), isOn: binding(\.hasOutline), minHeight: 50)
                        SettingToggleRow(title: String(localized: "All caps"), isOn: binding(\.isUppercase), minHeight: 50)
                    }
                    if text.background != .none {
                        colors(String(localized: "Background color"), selection: binding(\.backgroundColor))
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

    private var styles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick styles").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink2)
            HStack(spacing: 8) {
                ForEach(CreatorStyle.allCases) { style in
                    Button { viewModel.applyStyle(style, toText: textID) } label: {
                        FilterChip(label: style.label, isSelected: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("textSheet.style.\(style.rawValue)")
                }
            }
        }
    }

    private var alignment: some View {
        HStack {
            Text("Alignment")
            Spacer()
            Picker("Alignment", selection: binding(\.alignment)) {
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

    /// A field of the text, read from the edit and written through the view model.
    private func binding<Value>(_ keyPath: WritableKeyPath<TextOverlay, Value>) -> Binding<Value> {
        let fallback = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 0, end: 1))
        return Binding(
            get: {
                // The sheet only shows while the text exists.
                (viewModel.edit.texts.first { $0.id == textID } ?? fallback)[keyPath: keyPath]
            },
            set: { value in
                viewModel.updateText(textID) { $0[keyPath: keyPath] = value }
            }
        )
    }
}
