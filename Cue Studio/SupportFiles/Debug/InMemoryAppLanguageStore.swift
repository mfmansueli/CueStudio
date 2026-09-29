//
//  InMemoryAppLanguageStore.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// UI tests and unit tests: the interface language lives in memory, so switching it never changes
/// the simulator's language list. A launch with `-AppleLanguages (xx)` starts in that language.
final class InMemoryAppLanguageStore: AppLanguageStoring {
    var chosenLocalization: String?
    var systemLocalization: String
    var systemLanguages: [String]

    init(
        chosenLocalization: String? = nil,
        systemLocalization: String = Bundle.main.preferredLocalizations.first ?? "en",
        systemLanguages: [String] = Locale.preferredLanguages
    ) {
        self.chosenLocalization = chosenLocalization
        self.systemLocalization = systemLocalization
        self.systemLanguages = systemLanguages
    }
}
#endif
