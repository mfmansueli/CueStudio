//
//  PersonalizeEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Personalize: the app icon, the topics, and how alive the app feels.
struct PersonalizeEntryRow: View {
    let entry: SettingsEntry

    @Environment(PersonalizationService.self) private var personalization
    @Environment(AppIconService.self) private var appIcon
    @Environment(CreatorProfileService.self) private var profile

    @State private var showsTopics = false

    var body: some View {
        @Bindable var personalization = personalization
        content(personalization: $personalization)
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private func content(personalization: Bindable<PersonalizationService>) -> some View {
        switch entry {
        case .appIcon:
            NavigationLink(value: SettingsRoute.appIcon) {
                SettingsValueLabel(title: entry.title, detail: entry.detail, value: appIcon.current.title)
            }
        case .topics:
            Button { showsTopics = true } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title).foregroundStyle(Palette.ink)
                        if let detail = entry.detail { Text(detail).font(.footnote).foregroundStyle(Palette.ink2) }
                    }
                    Spacer(minLength: 8)
                    Text("\(topicCount)").foregroundStyle(Palette.ink2)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
                }
                .frame(minHeight: Metrics.listRowContent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showsTopics) {
                VoiceEditorSheet(field: .topics)
            }
        case .autoTag:
            SettingsListToggle(title: entry.title, detail: entry.detail, isOn: personalization.autoTagsTopics)
        case .starrySky:
            Picker(entry.title, selection: personalization.sky) {
                ForEach(SkyDensity.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Palette.ink2)
            .frame(minHeight: Metrics.listRowContent)
            .accessibilityValue(Text(personalization.sky.wrappedValue.label))
        case .celebrations:
            SettingsListToggle(title: entry.title, isOn: personalization.celebrations)
        case .haptics:
            SettingsListToggle(title: entry.title, isOn: personalization.haptics)
        default:
            EmptyView()
        }
    }

    private var topicCount: Int {
        profile.profile.topicCount
    }
}
