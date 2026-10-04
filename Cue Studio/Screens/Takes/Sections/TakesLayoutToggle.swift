//
//  TakesLayoutToggle.swift
//  Cue Studio
//

import SwiftUI

/// List | Grid, as two icons in a small track: the chosen one on `segmentOn`.
struct TakesLayoutToggle: View {
    @Binding var layout: TakeLayout

    var body: some View {
        HStack(spacing: 2) {
            ForEach([TakeLayout.list, .grid]) { option in
                let isOn = layout == option
                Button { layout = option } label: {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                        .frame(width: 40, height: 30)
                        .background(isOn ? Palette.segmentOn : .clear, in: Capsule())
                        .shadow(color: isOn ? Palette.segmentShadow : .clear, radius: 1.5, y: 1)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(option.label))
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("takes.layout.\(option.rawValue)")
            }
        }
        .padding(2)
        .background(Palette.fill, in: Capsule())
        .frame(minHeight: Metrics.hitTarget)
    }
}

/// The platform filter as a menu: "All ⌄", or the platform's dot and name.
struct TakesPlatformMenu: View {
    @Binding var platform: Platform?
    let options: [Platform?]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    platform = option
                } label: {
                    if platform == option {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
                .accessibilityIdentifier("takes.platform.\(option?.rawValue ?? "all")")
            }
        } label: {
            HStack(spacing: 6) {
                if let platform { ColorDot(color: platform.tint, size: 7) }
                Text(platform?.label ?? String(localized: "All"))
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Palette.fill, in: Capsule())
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Capsule())
        }
        .accessibilityLabel(Text("Platform"))
        .accessibilityValue(Text(platform?.label ?? String(localized: "All")))
        .accessibilityIdentifier("takes.platformMenu")
    }

    private func title(_ option: Platform?) -> String {
        option?.label ?? String(localized: "All platforms")
    }
}
