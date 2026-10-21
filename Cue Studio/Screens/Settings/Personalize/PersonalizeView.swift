//
//  PersonalizeView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Personalize (owner's redesign, 21/10/2026): "your Cue" on top as the creator has made it, live (`PersonalizeHero`), then
/// what makes it: the app icon (a collection to complete, `AppIconPicker`), the starry sky (each shown live, `SkyPicker`), the light at the
/// centre of their universe (the swatches of Profile's core sheet), how the app feels (celebrations and haptics, each answering when
/// switched on), their topics in their colours, and, until the first video is shared, the first video guide. Everything here stays on this
/// iPhone.
struct PersonalizeView: View {
    let bindings: SettingsBindings

    @Environment(PersonalizationService.self) private var personalization
    @Environment(AppIconService.self) private var appIcon
    @Environment(FirstVoyageService.self) private var voyage

    var body: some View {
        @Bindable var personalization = personalization
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PersonalizeHero(icon: appIcon.current, sky: personalization.sky, light: personalization.coreColor)
                    .padding(.top, 4)
                section("App icon", footer: "Aurora opens with your first shared video. The others open as you share more, with Pro.") {
                    AppIconPicker()
                }
                section("Starry sky") {
                    SkyPicker(selection: $personalization.sky)
                }
                section("Your universe’s light", footer: "The light at the centre of your universe, in Profile.") {
                    CoreColorSwatches(selection: $personalization.coreColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
                }
                section("Feel", footer: "With Reduce Motion on, the sky and the celebrations rest.") {
                    feel
                }
                section("Your topics", footer: "Each topic keeps its colour in Scripts and in your universe.") {
                    PersonalizeTopics()
                }
                if voyage.canBeTurnedOn {
                    section("Getting started") {
                        SettingsEntryRow(entry: .firstVoyage, bindings: bindings)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .skyBackground()
        .navigationTitle("Personalize")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.personalizePage")
    }

    private func section(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CueSectionHeader(title)
                .padding(.horizontal, Metrics.textGutter)
            content()
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(.horizontal, Metrics.textGutter)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 28)
    }

    /// Celebrations and haptics, each answering as it is switched on: the celebration's sparkles felt, the haptics' first tap.
    private var feel: some View {
        @Bindable var personalization = personalization
        return VStack(spacing: 0) {
            PersonalizeFeelRow(
                isOn: $personalization.celebrations, symbol: "sparkles", isAI: true,
                title: "Celebrations", detail: "A moment of light at each milestone"
            ) { HapticPatterns.playSparkles() }
            .accessibilityIdentifier("settings.celebrations")
            Divider().overlay(Palette.separator).padding(.leading, 61)
            PersonalizeFeelRow(
                isOn: $personalization.haptics, symbol: "hand.tap.fill", isAI: false,
                title: "Haptics", detail: "Taps in time with what moves"
            ) { Haptics.success() }
            .accessibilityIdentifier("settings.haptics")
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metrics.groupedListRadius, style: .continuous))
    }
}
