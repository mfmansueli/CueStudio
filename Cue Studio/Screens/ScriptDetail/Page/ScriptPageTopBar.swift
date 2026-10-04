//
//  ScriptPageTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Back, the platform ("● TikTok", opens Create for), Draft | Shaped, ••• and the yellow Rec.
struct ScriptPageTopBar<MenuContent: View>: View {
    let platform: Platform
    @Binding var mode: ScriptPageMode
    let isModeLocked: Bool
    let onBack: () -> Void
    let onPlatform: () -> Void
    let onRecord: () -> Void
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: 34, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Back"))
            .accessibilityIdentifier("page.backButton")
            Button(action: onPlatform) {
                HStack(spacing: 6) {
                    ColorDot(color: platform.tint, size: 7)
                    Text(platform.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background(Palette.overlayFill, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Create for"))
            .accessibilityValue(Text(platform.label))
            .accessibilityIdentifier("page.platformChip")
            Spacer(minLength: 0)
            modePicker
            Menu(content: menu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 34, height: 34)
                    .background(Palette.editorBarButton, in: Circle())
                    .frame(width: 38, height: Metrics.hitTarget)
                    .contentShape(Circle())
            }
            .accessibilityLabel(Text("More"))
            .accessibilityIdentifier("page.menuButton")
            Button(action: onRecord) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.record).frame(width: 9, height: 9)
                    Text("Rec").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Palette.accInk)
                .padding(.horizontal, 11)
                .frame(height: 34)
                .background(Palette.acc, in: Capsule())
                .frame(minHeight: Metrics.hitTarget)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Record"))
            .accessibilityIdentifier("detail.recordButton")
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        // Navigation chrome: five controls on one line don't survive the biggest text sizes (the whole
        // page ended up wider than the screen), so the bar stays at the default size.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    /// The two faces, as the recorder's Voice | Steady: a track with the chosen one raised.
    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(ScriptPageMode.allCases) { face in
                Button { mode = face } label: {
                    Text(face.label)
                        .font(.footnote.weight(mode == face ? .semibold : .regular))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8)
                        .frame(height: 28)
                        .background {
                            if mode == face { RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.segmentOn) }
                        }
                        .frame(minHeight: Metrics.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == face ? .isSelected : [])
                .accessibilityIdentifier("page.mode.\(face.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .disabled(isModeLocked)
    }
}
