//
//  LanguageSettingsDestination.swift
//  Cue Studio
//

import SwiftUI

/// The screens pushed on the Profile stack.
struct LanguageSettingsDestination: View {
    let route: ProfileRoute

    var body: some View {
        switch route {
        case .languageAndRegion: LanguageSettingsView()
        case .appLanguage: AppLanguagePickerView()
        case .voiceFollowingLanguage: VoiceFollowingLanguagePickerView()
        case .scriptLanguage: ScriptLanguagePickerView()
        }
    }
}
