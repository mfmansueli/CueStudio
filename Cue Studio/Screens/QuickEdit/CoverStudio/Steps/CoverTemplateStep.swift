//
//  CoverTemplateStep.swift
//  Cue Studio
//

import SwiftUI

/// Template: the creator's saved cover styles first, then each template, all drawn with this cover's own picture and title, so
/// the choice is the real result. Picking one keeps what was made (the words, the highlighted words, the framing, the graphics
/// added). The one the cover wears is ringed and checked; favorites have a star, the style new covers start in says "Default";
/// held (or with VoiceOver's actions), a tile favors, starts new covers, saves a copy, and for the creator's own renames,
/// updates and deletes.
struct CoverTemplateStep: View {
    let viewModel: CoverStudioViewModel
    @Binding var naming: StyleNameRequest?

    @ScaledMetric(relativeTo: .caption2) private var badgeSize: CGFloat = 20

    var body: some View {
        let library = viewModel.coverStyles
        ScrollView(.horizontal) {
            // At the top: a name on two lines doesn't move its picture down.
            HStack(alignment: .top, spacing: 10) {
                ForEach(library.styles) { style in
                    tile(
                        name: style.name, image: viewModel.savedThumbnails[style.id],
                        marks: Marks(isOn: viewModel.wornCoverStyleID == style.id, isFavorite: library.isFavorite(style.key),
                                     isDefault: library.isDefault(style.key)),
                        identifier: "cover.style.saved.\(style.id.uuidString)", action: { viewModel.applySavedCoverStyle(style.id) },
                        menu: {
                        StyleCardMenu(
                            isFavorite: library.isFavorite(style.key), isDefault: library.isDefault(style.key),
                            defaultLabel: String(localized: "Use for new covers"),
                            onFavorite: { viewModel.toggleFavoriteCoverStyle(style.key) },
                            onDefault: { viewModel.toggleDefaultCoverStyle(style.key, name: style.name) },
                            onDuplicate: { viewModel.duplicateCoverStyle(style.id) },
                            onRename: { naming = StyleNameRequest(purpose: .rename(style.id), name: style.name) },
                            onUpdate: { viewModel.updateCoverStyle(style.id) },
                            onDelete: { viewModel.deleteCoverStyle(style.id) }
                        )
                        }
                    )
                }
                ForEach(CoverTemplate.allCases) { template in
                    let key = StyleKey.builtIn(template.rawValue)
                    tile(
                        name: template.label, image: viewModel.thumbnails[template],
                        marks: Marks(isOn: viewModel.wornCoverStyleID == nil && viewModel.composition.template == template,
                                     isFavorite: library.isFavorite(key), isDefault: library.isDefault(key)),
                        identifier: "cover.template.\(template.rawValue)", action: { viewModel.applyTemplate(template) },
                        menu: {
                        StyleCardMenu(
                            isFavorite: library.isFavorite(key), isDefault: library.isDefault(key),
                            defaultLabel: String(localized: "Use for new covers"),
                            onFavorite: { viewModel.toggleFavoriteCoverStyle(key) },
                            onDefault: { viewModel.toggleDefaultCoverStyle(key, name: template.label) },
                            onDuplicate: { viewModel.duplicateCoverTemplate(template) }
                        )
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    /// How a tile stands: worn by this cover, a favorite, where new covers start.
    private struct Marks {
        let isOn: Bool
        let isFavorite: Bool
        let isDefault: Bool
    }

    private func tile(
        name: String, image: UIImage?, marks: Marks, identifier: String, action: @escaping () -> Void, @ViewBuilder menu: () -> some View
    ) -> some View {
        let isOn = marks.isOn, isFavorite = marks.isFavorite, isDefault = marks.isDefault
        let width: CGFloat = 92
        let height = width / CGFloat(viewModel.aspect)
        let menu = menu()
        return Button(action: action) {
            VStack(spacing: 6) {
                Group {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Palette.surface2.overlay(ProgressView().tint(Palette.ink2))
                    }
                }
                .frame(width: width, height: min(height, 164))
                .clipShape(RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous)
                        .strokeBorder(isOn ? Palette.acc : Palette.separator, lineWidth: isOn ? 2.5 : 1)
                }
                .overlay(alignment: .topTrailing) {
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(.caption2, weight: .heavy))
                            .foregroundStyle(Palette.accInk)
                            .frame(width: badgeSize, height: badgeSize)
                            .background(Palette.acc, in: Circle())
                            .overlay(Circle().strokeBorder(Palette.Editor.presetCardBadge, lineWidth: 1.5))
                            .padding(4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(.caption2, weight: .bold))
                            .foregroundStyle(Palette.chipOn)
                            .frame(width: badgeSize, height: badgeSize)
                            .background(Palette.Editor.presetCardBadge, in: Circle())
                            .padding(4)
                    }
                }
                // Whole on two lines between words ("Mang tính / giáo dục"), smaller only past that (owner, 02/11/2026: no label
                // is ever cut).
                WholeWordsLabel(text: name, minimumScale: 0.8)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(isOn ? Palette.accText : Palette.ink)
                if isDefault {
                    Text("Default", comment: "A style card's mark: new work starts in this style")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(Palette.accText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePressCard)
        .contextMenu { menu }
        .accessibilityActions { menu }
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text([isFavorite ? String(localized: "Favorite") : nil, isDefault ? String(localized: "Default for new videos") : nil]
            .compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityIdentifier(identifier)
        // ••• beside the card's button (never picks the look), on the picture's bottom corner, clear of the ★ and the check.
        .overlay(alignment: .topTrailing) {
            ItemMoreMenu(identifier: "\(identifier).more") { menu }
                .padding(.top, min(height, 164) - 40)
        }
    }
}
