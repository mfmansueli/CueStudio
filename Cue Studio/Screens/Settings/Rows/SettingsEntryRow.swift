//
//  SettingsEntryRow.swift
//  Cue Studio
//

import SwiftUI

/// The row of one `SettingsEntry`, the same on its page and in the search results. `position` is where it sits in its section's card
/// (a row alone is the whole card; `SettingsEntryRows` sets it for a section's rows).
struct SettingsEntryRow: View {
    let entry: SettingsEntry
    let bindings: SettingsBindings
    var position: CardRowPosition = .only

    var body: some View {
        content
            .cardRowBackground(position: position)
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .recording, .prompter, .remote, .myCueVoice, .personalize, .languageRegion, .notifications, .privacy, .cuePro, .restorePurchases,
             .privacyPolicy, .termsOfUse, .acknowledgements, .version:
            SettingsRootRow(entry: entry, bindings: bindings)
        case .startsWith, .resolution, .frameRate, .defaultFormat, .microphone, .countdown, .countdownBeforePlay, .grid:
            RecordingEntryRow(entry: entry, camera: bindings.camera)
        case .followVoice, .speed, .aiCoach, .textSize, .font, .lineSpacing, .alignment, .textColor, .showReadingLine,
             .readingLinePosition, .resetReadingLine, .windowHeight, .windowWidth, .sideMargins, .backgroundOpacity,
             .cameraBlur, .socialSafeZone, .studioBackground, .mirrorText, .flipVertically:
            PrompterEntryRow(entry: entry, bindings: bindings)
        case .connectDevice, .enterCode, .scanCode:
            RemoteEntryRow(entry: entry)
        case .appIcon, .topics, .autoTag, .starrySky, .celebrations, .haptics:
            PersonalizeEntryRow(entry: entry)
        case .appLanguage, .voiceFollowingLanguage, .scriptLanguage:
            LanguageEntryRow(entry: entry)
        case .onDeviceAI, .helpImprove, .permissions, .deleteData:
            PrivacyEntryRow(entry: entry)
        }
    }
}
