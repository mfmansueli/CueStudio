//
//  LanguageEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of Settings › Language & Region. The app's language is the iPhone's to change (Settings › Cue › Language); the
/// Voice Following and script languages are menus.
struct LanguageEntryRow: View {
    let entry: SettingsEntry

    @Environment(LanguageService.self) private var languages
    @Environment(LanguageCapabilityService.self) private var capabilities
    @Environment(\.openURL) private var openURL

    @State private var availability: [CueLanguage: VoiceFollowingAvailability] = [:]

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .appLanguage:
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                HStack(spacing: 12) {
                    Text(entry.title).foregroundStyle(Palette.ink)
                    Spacer(minLength: 8)
                    Text(languages.appLanguage?.nativeName ?? String(localized: "iPhone Language")).foregroundStyle(Palette.ink2)
                    Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
                }
                .frame(minHeight: Metrics.listRowContent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .voiceFollowingLanguage:
            menu(
                selection: languages.voiceFollowingLanguage, automatic: String(localized: "Same as script"), showsAvailability: true
            ) { languages.voiceFollowingLanguage = $0 }
                .task { await loadAvailability() }
        case .scriptLanguage:
            menu(
                selection: languages.scriptLanguage, automatic: String(localized: "Auto-detect"), showsAvailability: false
            ) { languages.scriptLanguage = $0 }
        default:
            EmptyView()
        }
    }

    /// "Same as script", then Cue's languages by their own name; Voice Following says under each whether this iPhone can listen in it.
    private func menu(
        selection: CueLanguage?, automatic: String, showsAvailability: Bool, onPick: @escaping (CueLanguage?) -> Void
    ) -> some View {
        Menu {
            Button { onPick(nil) } label: {
                if selection == nil { Label(automatic, systemImage: "checkmark") } else { Text(automatic) }
            }
            ForEach(CueLanguage.allCases) { language in
                Button { onPick(language) } label: {
                    if selection == language {
                        Label(language.nativeName, systemImage: "checkmark")
                    } else {
                        Text(verbatim: language.nativeName)
                    }
                    if showsAvailability, let status = availability[language] { Text(status.label) }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(entry.title).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(verbatim: selection?.nativeName ?? automatic).foregroundStyle(Palette.ink2)
                Image(systemName: "chevron.up.chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(Palette.ink3)
            }
            .frame(minHeight: Metrics.listRowContent)
            .contentShape(Rectangle())
        }
        .tint(Palette.ink)
    }

    private func loadAvailability() async {
        for language in CueLanguage.allCases {
            availability[language] = VoiceFollowingAvailability(await capabilities.support(.voiceFollowing, for: language))
        }
    }
}
