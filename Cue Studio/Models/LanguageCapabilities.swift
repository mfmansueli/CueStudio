//
//  LanguageCapabilities.swift
//  Cue Studio
//

import Foundation

/// What this device does for one language, feature by feature.
nonisolated struct LanguageCapabilities: Hashable, Sendable {
    let language: CueLanguage
    private(set) var support: [LanguageFeature: FeatureSupport]

    init(language: CueLanguage, support: [LanguageFeature: FeatureSupport]) {
        self.language = language
        self.support = support
    }

    subscript(feature: LanguageFeature) -> FeatureSupport? { support[feature] }

    /// The features that can't run in this language, with why.
    var unavailable: [(feature: LanguageFeature, cause: FeatureSupport.Cause)] {
        LanguageFeature.allCases.compactMap { feature in
            if case .unavailable(let cause)? = support[feature] { (feature, cause) } else { nil }
        }
    }
}
