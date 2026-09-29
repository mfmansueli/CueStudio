//
//  StyleToolView.swift
//  Cue Studio
//

import SwiftUI

/// Type presets and "My style" for one text, every text or the captions. Each card shows the
/// preset drawn exactly as the export draws it. Only the type changes: filters and the cover stay
/// as they are.
struct StyleToolView: View {
    let viewModel: QuickEditViewModel

    @State private var scope: TextStyleScope = .allTexts
    @State private var keepsChanges = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            scopes
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                if let mine = viewModel.myStyle {
                    card(
                        look: mine, title: String(localized: "My style"), detail: String(localized: "Saved from your text"),
                        isSelected: false, identifier: "edit.style.mine"
                    ) {
                        viewModel.applyMyStyle(to: scope, keepingCustomizations: keepsChanges)
                    }
                }
                ForEach(TypePreset.allCases) { preset in
                    card(
                        look: preset.look(for: scope.use), title: preset.label, detail: preset.detail,
                        isSelected: viewModel.currentPreset(for: scope) == preset, identifier: "edit.style.\(preset.rawValue)"
                    ) {
                        viewModel.applyPreset(preset, to: scope, keepingCustomizations: keepsChanges)
                    }
                }
            }
            if scope == .allTexts, viewModel.edit.texts.contains(where: { !$0.customized.isEmpty }) {
                Toggle(isOn: $keepsChanges) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep my changes")
                        Text("Colors and sizes you set by hand stay")
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .tint(Palette.success)
                .accessibilityIdentifier("edit.style.keepChanges")
            }
            if viewModel.styledTextID != nil {
                Button {
                    viewModel.saveMyStyle()
                } label: {
                    Label("Save this text as My style", systemImage: "bookmark")
                }
                .buttonStyle(.cueSecondary(.compact))
                .accessibilityIdentifier("edit.style.saveMine")
            }
            Text("Only the type changes. Filters and the cover stay as they are.")
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
        }
        .onAppear {
            if viewModel.styledTextID != nil { scope = .selected }
        }
        .onChange(of: viewModel.styledTextID) { _, id in
            if id == nil, scope == .selected { scope = .allTexts }
        }
    }

    // MARK: - Sections

    private var scopes: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(availableScopes) { option in
                    Button { scope = option } label: {
                        FilterChip(label: option.label, isSelected: scope == option, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(scope == option ? .isSelected : [])
                    .accessibilityIdentifier("edit.styleScope.\(option.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// "This text" only while one is picked.
    private var availableScopes: [TextStyleScope] {
        TextStyleScope.allCases.filter { $0 != .selected || viewModel.styledTextID != nil }
    }

    private func card(
        look: TextLook, title: String, detail: String, isSelected: Bool, identifier: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SelectableCard(isSelected: isSelected) {
                VStack(alignment: .leading, spacing: 6) {
                    sample(look)
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(identifier)
    }

    /// The preset on a dark tile, as the video will show it.
    private func sample(_ look: TextLook) -> some View {
        let text = scope.use == .caption ? String(localized: "Captions read like this") : String(localized: "Big idea")
        return ZStack {
            // A stand-in for a frame of video: light and dark type both have to read on it.
            LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .top, endPoint: .bottom)
            if let image = TypeLookPreview.image(look, use: scope.use, sample: text) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
    }
}
