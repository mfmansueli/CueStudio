//
//  DestinationSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Create for": picking a platform sets the frame, safe zones, prompter position and length goals.
struct DestinationSheet: View {
    let current: Platform
    let onPick: (Platform) -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(PlatformRulesService.self) private var rules
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var profile = profile
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SheetHeader(
                    title: String(localized: "Create for"),
                    subtitle: String(localized: "Cue sets the frame, safe zones, teleprompter position and length goals. Fine-tune anytime."),
                    onClose: { dismiss() }
                )
                .padding(.bottom, 4)
                GroupedCard(background: Palette.surface2, radius: 22, dividerInset: 38) {
                    ForEach(Platform.allCases) { platform in
                        row(platform)
                    }
                }
                Toggle(isOn: $profile.profile.monetizationGoals) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monetization goals").font(.body.weight(.semibold))
                        Text("Longer videos earn: TikTok 1:00+, YouTube 8:00+")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .tint(Palette.successText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityIdentifier("destination.monetizationToggle")
                Text("Presets update as platforms change.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .presentationCornerRadius(Metrics.sheetRadius)
    }

    private func row(_ platform: Platform) -> some View {
        Button { onPick(platform) } label: {
            HStack(spacing: 12) {
                ColorDot(color: platform.tint, size: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.destinationName).font(.body.weight(.semibold))
                    Text(rules.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).summary)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                if platform == current {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Palette.accText)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(platform == current ? .isSelected : [])
        .accessibilityIdentifier("destination.\(platform.rawValue)")
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        DestinationSheet(current: .tiktok, onPick: { _ in })
    }
    .previewEnvironment()
}
#endif
