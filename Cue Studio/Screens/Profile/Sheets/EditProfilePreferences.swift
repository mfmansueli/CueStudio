//
//  EditProfilePreferences.swift
//  Cue Studio
//

import SwiftUI

/// Edit Profile › When you create: the platform new scripts are made for, as the platforms' own galaxies to tap (each its colour, the
/// chosen one ringed in yellow, the ring gliding to the next), and the monetization goals with what they change. Like the rest of the
/// sheet they are kept when Done is tapped.
struct EditProfilePreferences: View {
    @Binding var draft: ProfileDraft

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var ring

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New scripts are made for")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 16)
                .padding(.top, 14)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Platform.allCases) { platform in
                        tile(platform)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.4, dampingFraction: 0.75), value: draft.defaultPlatform)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profile.defaultPlatformPicker")
            Rectangle().fill(Palette.separator).frame(height: 0.5).padding(.leading, 16)
            Toggle(isOn: $draft.monetizationGoals) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monetization goals").foregroundStyle(Palette.ink)
                    Text(draft.monetizationGoals
                         ? String(localized: "Script lengths aim at what earns on \(draft.defaultPlatform.label)")
                         : String(localized: "Script lengths aim at what holds attention"))
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .contentTransition(.opacity)
                }
            }
            .tint(Palette.success)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .accessibilityIdentifier("profile.monetizationGoalsToggle")
        }
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
    }

    /// A platform as its galaxy: a glowing core of its colour on a tile of the same, its name under it.
    private func tile(_ platform: Platform) -> some View {
        let isOn = draft.defaultPlatform == platform
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            guard !isOn else { return }
            Haptics.selection()
            draft.defaultPlatform = platform
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    shape.fill(platform.tint.opacity(0.16))
                    Circle()
                        .fill(RadialGradient(colors: [Palette.ink, platform.tint, platform.tint.opacity(0)], center: .center, startRadius: 0, endRadius: 15))
                        .frame(width: 30, height: 30)
                    if isOn {
                        shape.strokeBorder(Palette.acc, lineWidth: 2)
                            .padding(-4)
                            .matchedGeometryEffect(id: "ring", in: ring)
                    }
                }
                .frame(width: 50, height: 50)
                Text(platform.label)
                    .font(.caption)
                    .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 62)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cuePress)
        .accessibilityLabel(Text(platform.destinationName))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("profile.platform.\(platform.rawValue)")
    }
}
