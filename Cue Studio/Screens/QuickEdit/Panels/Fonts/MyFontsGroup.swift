//
//  MyFontsGroup.swift
//  Cue Studio
//

import SwiftUI

/// "My fonts" in the pickers that offer the creator's imported families (Text style, Captions, the cover's Title; owner,
/// canvas 2 F12): the families as chips, each in its own face, with **Edit** on the right. Edit puts a minus on each chip and a
/// tap then removes it (Done ends it); touching and holding a chip offers Remove too. Removing takes the family out of the
/// pickers with Undo; whatever uses it keeps drawing in it, and the chip of the one in use stays (it can't be removed twice).
struct MyFontsGroup: View {
    /// `TextOverlayFont.myFonts(offered:including:)`.
    let fonts: [TextOverlayFont]
    /// The families that can be removed: the ones offered.
    let removable: Set<String>
    let selection: TextOverlayFont?
    /// The picker's: chips are `<identifier>.<font>`, Edit `<identifier>.myFonts.edit`.
    let identifier: String
    let onSelect: (TextOverlayFont) -> Void
    let onRemove: (String) -> Void

    @State private var isEditing = false
    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 15

    var body: some View {
        if !fonts.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("My fonts")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 8)
                    if !removable.isEmpty {
                        Button(isEditing ? String(localized: "Done") : String(localized: "Edit")) {
                            Haptics.selection()
                            isEditing.toggle()
                        }
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Palette.accText)
                        .frame(minHeight: Metrics.hitTarget)
                        .accessibilityIdentifier("\(identifier).myFonts.edit")
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(fonts) { chip($0) }
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -16)
            }
            .onChange(of: removable.isEmpty) { _, none in
                if none { isEditing = false }
            }
        }
    }

    private func chip(_ font: TextOverlayFont) -> some View {
        let family = font.customFamily ?? font.label
        let canRemove = removable.contains(family)
        let removes = isEditing && canRemove
        let isOn = font == selection && !removes
        return Button {
            if removes {
                onRemove(family)
            } else {
                Haptics.selection()
                onSelect(font)
            }
        } label: {
            HStack(spacing: 6) {
                if removes {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: textSize, weight: .semibold))
                        .foregroundStyle(Palette.warnText)
                }
                Text(font.label)
                    .font(CueStudioFont.chip(font, size: textSize))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 38)
            .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePress)
        .contextMenu {
            if canRemove {
                Button(String(localized: "Remove"), systemImage: "minus.circle", role: .destructive) { onRemove(family) }
            }
        }
        .accessibilityLabel(removes ? Text("Remove \(family)") : Text(font.label))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityActions {
            if canRemove && !removes {
                Button(String(localized: "Remove")) { onRemove(family) }
            }
        }
        .accessibilityIdentifier(removes ? "\(identifier).remove.\(font.rawValue)" : "\(identifier).\(font.rawValue)")
    }
}
