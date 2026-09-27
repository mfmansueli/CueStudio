//
//  DestinationSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Where will this go?" Picking a destination sets the frame, quality and length goals.
struct DestinationSheet: View {
    let current: Platform
    let onPick: (Platform) -> Void

    @Environment(CreatorProfileService.self) private var profile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var profile = profile
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SheetHeader(
                    title: String(localized: "Where will this go?"),
                    subtitle: String(localized: "Cue sets the frame, quality and length goals. You can still change any of it in camera settings."),
                    onClose: { dismiss() }
                )
                .padding(.bottom, 4)
                GroupedCard(background: Palette.surface2, radius: 22, dividerInset: 38) {
                    ForEach(Platform.allCases) { platform in
                        Button { onPick(platform) } label: {
                            HStack(spacing: 12) {
                                ColorDot(color: platform.tint, size: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(platform.destinationName).font(.body.weight(.semibold))
                                    Text(PlatformPreset.preset(for: platform, monetizationGoals: profile.profile.monetizationGoals).summary)
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(Palette.ink2)
                                }
                                Spacer()
                                if platform == current {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Palette.acc)
                                }
                            }
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(platform == current ? .isSelected : [])
                    }
                }
                Toggle(isOn: $profile.profile.monetizationGoals) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monetization goals").font(.body.weight(.semibold))
                        Text("Aim for lengths that earn: TikTok 1:00+, YouTube 8:00+ for mid-roll ads")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .tint(Palette.success)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Platform rules change — Cue updates these presets with the app.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surface)
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
