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
    /// Whether Apple Intelligence drafts in each language, for the Script Language menu.
    @State private var aiWriting: [CueLanguage: FeatureSupport] = [:]

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .appLanguage:
            Button {
                openURL.openAppSettings()
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
                selection: languages.voiceFollowingLanguage, automatic: String(localized: "Same as script"),
                subtitle: { availability[$0]?.label }, onPick: { languages.voiceFollowingLanguage = $0 }
            )
                .task { await loadAvailability() }
        case .scriptLanguage:
            menu(
                selection: languages.scriptLanguage, automatic: String(localized: "Auto-detect"),
                subtitle: { Self.draftingNote(aiWriting[$0]) }, onPick: { languages.scriptLanguage = $0 }
            )
                .task { await loadAIWriting() }
        default:
            EmptyView()
        }
    }

    /// "Same as script" (or "Auto-detect"), then Cue's languages by their own name, each with `subtitle` under it: Voice Following says
    /// whether this iPhone can listen in it, Script Language whether Apple Intelligence can't draft in it.
    private func menu(
        selection: CueLanguage?, automatic: String, subtitle: @escaping (CueLanguage) -> String?, onPick: @escaping (CueLanguage?) -> Void
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
                    if let note = subtitle(language) { Text(note) }
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

    private func loadAIWriting() async {
        for language in CueLanguage.allCases {
            aiWriting[language] = await capabilities.support(.aiWriting, for: language)
        }
    }

    /// Only a language the model doesn't write is marked: without Apple Intelligence at all every language would say the same, and the
    /// dock already says that.
    static func draftingNote(_ support: FeatureSupport?) -> String? {
        guard case .unavailable(.languageNotSupported)? = support else { return nil }
        return String(localized: "Apple Intelligence can’t draft in it yet")
    }
}
