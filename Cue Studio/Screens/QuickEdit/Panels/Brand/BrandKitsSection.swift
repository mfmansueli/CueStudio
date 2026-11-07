//
//  BrandKitsSection.swift
//  Cue Studio
//

import SwiftUI

/// Templates › Brand: the creator's brand kits, one card each (its colors, fonts and logo, what it holds; the one this video
/// wears is checked). A tap asks which parts go on (`BrandKitApplySheet`); holding a card edits, copies or deletes it (Undo).
/// "New kit from this video" starts one from what the video wears. Under them, the fonts the creator imported.
struct BrandKitsSection: View {
    let viewModel: QuickEditViewModel

    private var brand: BrandViewModel { viewModel.brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if brand.kits.kits.isEmpty {
                PanelNote(text: String(localized: "A brand kit keeps your colors, fonts, logo and styles together, to put on any video in one step."), teaches: true)
            }
            ForEach(brand.kits.kits) { kit in card(kit) }
            PanelButton(label: String(localized: "New kit from this video"), systemImage: "plus", identifier: "edit.brand.newKit") {
                brand.edit(brand.kitFromThisVideo())
            }
            Text("Videos keep what a kit put on them · changing a kit never changes a video")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            BrandFontsList(viewModel: viewModel)
                .padding(.top, 8)
        }
        .padding(.top, 4)
    }

    private func card(_ kit: BrandKit) -> some View {
        let isOn = brand.appliedKitID == kit.id
        return Button {
            Haptics.selection()
            brand.askToApply(kit)
        } label: {
            HStack(spacing: 12) {
                BrandKitBadge(kit: kit, logoURL: kit.logo.map(brand.kits.url(of:)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(kit.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                    Text(kit.parts.map(\.label).joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !kit.colors.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(kit.colors) { color in
                                Circle().fill(color.color).frame(width: 14, height: 14)
                                    .overlay(Circle().strokeBorder(Palette.ink3, lineWidth: 1))
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isOn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.editorGlyph(EditorGlyph.large))
                        .foregroundStyle(Palette.accText)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 12)
            // Room for •••, which sits over the card beside its button (owner, 07/11/2026: it never applies the kit).
            .padding(.trailing, 4 + Metrics.hitTarget)
            .padding(.vertical, 10)
            .frame(minHeight: Metrics.hitTarget)
            .editorCard(isOn ? .picked : .plain)
            .contentShape(.editorCard)
        }
        .buttonStyle(.cuePressCard)
        .contextMenu { kitMenu(kit) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(Text("Choose which parts go on this video. Undo puts it back."))
        .accessibilityAction(named: Text("Edit kit")) { brand.edit(kit) }
        .accessibilityAction(named: Text("Delete kit")) { brand.deleteKit(kit.id) }
        .accessibilityIdentifier("edit.brand.kit.\(kit.name)")
        .overlay(alignment: .trailing) {
            ItemMoreMenu(look: .onCard, identifier: "edit.brand.kit.\(kit.name).more") { kitMenu(kit) }
                .padding(.trailing, 4)
        }
    }

    @ViewBuilder
    private func kitMenu(_ kit: BrandKit) -> some View {
        Button { brand.edit(kit) } label: { Label("Edit kit", systemImage: "pencil") }
        Button { brand.kits.duplicate(kit.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
        Button(role: .destructive) { brand.deleteKit(kit.id) } label: { Label("Delete kit", systemImage: "trash") }
    }
}

/// A kit's mark: its logo on a checkerboard-free tile, or its first color with its initial.
struct BrandKitBadge: View {
    let kit: BrandKit
    let logoURL: URL?

    @State private var logo: UIImage?

    var body: some View {
        ZStack {
            if let logo {
                Image(uiImage: logo).resizable().scaledToFit().padding(5)
            } else {
                let color = kit.colors.first ?? .yellow
                Circle().fill(color.color)
                Text(verbatim: String(kit.name.prefix(1)).uppercased())
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(color.readableInk.color)
            }
        }
        .frame(width: 44, height: 44)
        .background(Palette.Editor.accTile, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .task(id: logoURL) {
            guard let logoURL else { return }
            logo = await LibraryThumbnails.image(for: logoURL, isVideo: false, side: 120)
        }
        .accessibilityHidden(true)
    }
}
