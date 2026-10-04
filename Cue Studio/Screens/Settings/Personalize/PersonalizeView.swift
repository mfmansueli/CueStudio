//
//  PersonalizeView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize: the app icon, the topics and their colours, and how alive the app feels (the sky, the story
/// moments, haptics). Everything here stays on this iPhone, and the motion turns off with Reduce Motion.
struct PersonalizeView: View {
    @Environment(PersonalizationService.self) private var personalization
    @Environment(MilestoneService.self) private var milestones
    @Environment(AppIconService.self) private var appIcon
    @Environment(CreatorProfileService.self) private var profile
    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast

    @State private var showsTopics = false
    @State private var paywall: PaywallContext?

    var body: some View {
        @Bindable var personalization = personalization
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                heading(String(localized: "App icon"))
                iconCard
                Text("Unlocked by milestones in your universe. First Light, Deep Space and Constellation come with Pro.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)

                heading(String(localized: "Topics & colors")).padding(.top, 10)
                GroupedCard(dividerInset: 16) {
                    Button { showsTopics = true } label: { topicsRow }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("personalize.topicsRow")
                    SettingToggleRow(
                        title: String(localized: "Tag new scripts automatically"),
                        detail: String(localized: "Cue picks the topic on this iPhone"), isOn: $personalization.autoTagsTopics, minHeight: 64
                    )
                    .accessibilityIdentifier("personalize.autoTag")
                }

                heading(String(localized: "Motion")).padding(.top, 10)
                GroupedCard(dividerInset: 16) {
                    OrbSlider(
                        value: Binding(
                            get: { Double(personalization.sky.step) },
                            set: { personalization.sky = SkyDensity.allCases[max(0, min(2, Int($0.rounded())))] }
                        ),
                        range: 0...2, step: 1, defaultValue: 1, style: .row, label: String(localized: "Starry sky"),
                        valueText: personalization.sky.label, systemIcon: .starrySky, accessibilityIdentifier: "personalize.sky"
                    )
                    .padding(.horizontal, 16)
                    .frame(minHeight: 64)
                    SettingToggleRow(title: String(localized: "Celebrations"), isOn: $personalization.celebrations)
                        .accessibilityIdentifier("personalize.celebrations")
                    SettingToggleRow(title: String(localized: "Haptics"), isOn: $personalization.haptics)
                        .accessibilityIdentifier("personalize.haptics")
                }
                Text("The sky shows only while you browse, never over your face or your edit. Everything turns off when Reduce Motion is on.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, 4)
            }
            .padding(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 40, trailing: Metrics.gutter))
        }
        .skyBackground()
        .navigationTitle("Personalize")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $showsTopics) {
            VoiceSetupSheet(mode: .edit, profile: profile.profile, startAt: .niche)
        }
        .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
    }

    // MARK: - App icon

    private var iconCard: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return HStack(alignment: .top, spacing: 8) {
            ForEach(AppIconChoice.allCases) { icon in
                iconTile(icon)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
    }

    private func iconTile(_ icon: AppIconChoice) -> some View {
        let isUnlocked = milestones.isUnlocked(icon)
        let isCurrent = appIcon.current == icon
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { choose(icon, isUnlocked: isUnlocked) } label: {
            VStack(spacing: 6) {
                tilePicture(icon, isUnlocked: isUnlocked)
                    .frame(width: 52, height: 52)
                    .clipShape(shape)
                    .overlay(shape.strokeBorder(isCurrent ? Palette.acc : .clear, lineWidth: 3))
                    .padding(3)
                if isUnlocked {
                    Text(icon.title)
                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                        .foregroundStyle(isCurrent ? Palette.ink : Palette.ink2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                } else {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("\(icon.milestone)").font(.system(size: 13))
                    }
                    .foregroundStyle(Palette.ink2)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(icon.title))
        .accessibilityValue(Text(isUnlocked ? "" : String(localized: "Unlocks at \(icon.milestone) videos shared")))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("personalize.icon.\(icon.rawValue)")
    }

    @ViewBuilder
    private func tilePicture(_ icon: AppIconChoice, isUnlocked: Bool) -> some View {
        if let name = icon.previewName {
            Image(name)
                .resizable()
                .scaledToFill()
                .saturation(isUnlocked ? 1 : 0.2)
                .opacity(isUnlocked ? 1 : 0.5)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.inkHint, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .overlay { Text("Cue").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.ink2) }
        }
    }

    private func choose(_ icon: AppIconChoice, isUnlocked: Bool) {
        guard isUnlocked else {
            toast.show(String(localized: "Unlocks at \(icon.milestone) videos shared"))
            return
        }
        if icon.needsPro, !store.tier.isPro {
            paywall = .profile
            return
        }
        Task {
            if await appIcon.choose(icon) { Haptics.selection() }
        }
    }

    // MARK: - Topics

    private var topicsRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: -10) {
                ForEach(Array(topicColors.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 26, height: 26).overlay(Circle().strokeBorder(Palette.surface, lineWidth: 2))
                }
            }
            .frame(minWidth: 40, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your topics").font(.body).foregroundStyle(Palette.ink)
                Text("Edit them in My Cue Voice").font(.footnote).foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private var topicColors: [Color] {
        let count = max(1, min(OnboardingTopic.limit, profile.profile.niches.count + profile.profile.customTopics.count))
        return (0..<count).map { OnboardingTopic.color(at: $0) }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(CueStudioFont.hud)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 4)
    }
}
