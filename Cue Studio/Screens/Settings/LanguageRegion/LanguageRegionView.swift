//
//  LanguageRegionView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Language & Region: the three languages Cue keeps apart. The app language
/// is the interface; the Voice Following language is what Cue listens for; the script language is
/// what new scripts are written in. Changing one never changes another or translates anything.
struct LanguageRegionView: View {
    @Environment(LanguageService.self) private var languages

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LanguagePickerView(
                        title: "App Language",
                        automatic: .init(
                            title: String(localized: "iPhone Language"),
                            detail: languages.systemInterfaceLanguage.nativeName
                        ),
                        selection: languages.appLanguage,
                        onPick: { languages.setAppLanguage($0) }
                    )
                } label: {
                    row(title: "App Language", value: languages.appLanguage?.nativeName ?? String(localized: "iPhone Language"))
                }
                .accessibilityIdentifier("languageRegion.appLanguageButton")
            } footer: {
                Text("Controls the language of Cue’s interface.")
            }

            Section {
                NavigationLink {
                    LanguagePickerView(
                        title: "Voice Following Language",
                        automatic: .init(
                            title: String(localized: "Same as Script"),
                            detail: String(localized: "Listens in each script’s language")
                        ),
                        selection: languages.voiceFollowingLanguage,
                        showsVoiceFollowingAvailability: true,
                        onPick: { languages.voiceFollowingLanguage = $0 }
                    )
                } label: {
                    row(
                        title: "Voice Following Language",
                        value: languages.voiceFollowingLanguage?.nativeName ?? String(localized: "Same as Script")
                    )
                }
                .accessibilityIdentifier("languageRegion.voiceFollowingLanguageButton")
            } footer: {
                Text("Controls the language Cue listens for while you speak.")
            }

            Section {
                NavigationLink {
                    LanguagePickerView(
                        title: "Script Language",
                        automatic: .init(
                            title: String(localized: "Auto-detect"),
                            detail: String(localized: "Cue reads the language from what you write")
                        ),
                        selection: languages.scriptLanguage,
                        onPick: { languages.scriptLanguage = $0 }
                    )
                } label: {
                    row(title: "Script Language", value: languages.scriptLanguage?.nativeName ?? String(localized: "Auto-detect"))
                }
                .accessibilityIdentifier("languageRegion.scriptLanguageButton")
            } footer: {
                Text("Controls the language of your scripts. New scripts start in it, and each script can have its own in its ••• menu. Scripts are never translated.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle("Language & Region")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(title: LocalizedStringKey, value: String) -> some View {
        // Long names (German, Portuguese) wrap under the title instead of clipping.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(title).foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text(value).foregroundStyle(Palette.ink2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(Palette.ink)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .lineLimit(1)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack { LanguageRegionView() }
        .previewEnvironment()
}
#endif
