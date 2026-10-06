//
//  SettingsDestination.swift
//  Cue Studio
//

import SwiftUI

/// The page a `SettingsRoute` opens.
struct SettingsDestination: View {
    let route: SettingsRoute
    let bindings: SettingsBindings

    var body: some View {
        switch route {
        case .recording: SettingsRecordingView(bindings: bindings)
        case .microphone: SettingsMicrophoneView()
        case .prompter: SettingsPrompterView(bindings: bindings)
        case .font: SettingsFontView(bindings: bindings)
        case .safeZone: SettingsSafeZoneView(bindings: bindings)
        case .remote: SettingsRemoteView(bindings: bindings)
        case .myCueVoice: MyCueVoicePage()
        case .personalize: PersonalizeView(bindings: bindings)
        case .appIcon: AppIconView()
        case .languageRegion: LanguageRegionView(bindings: bindings)
        case .privacy: PrivacyView(bindings: bindings)
        case .permissions: PermissionsView()
        case .acknowledgements: AcknowledgementsView()
        }
    }
}
