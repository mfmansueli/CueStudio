//
//  FakeAIModelCapabilities.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// What the Apple Intelligence models can do, as a fixed list: the device model's state and the
/// languages (by ISO code) each one writes. Private Cloud Compute is off unless `cloud` is set.
nonisolated struct FakeAIModelCapabilities: AIModelCapabilities {
    var device: AIModelStatus = .available
    var deviceLanguages: Set<String> = ["en", "pt", "es", "fr", "de", "it", "ja", "ko", "zh", "tr", "vi", "nl", "sv", "da", "nb", "no"]
    var cloud: AIModelStatus?
    var cloudLanguages: Set<String> = []

    var deviceStatus: AIModelStatus { device }
    var cloudStatus: AIModelStatus? { cloud }

    func deviceSupports(_ locale: Locale) -> Bool {
        deviceLanguages.contains(locale.language.languageCode?.identifier ?? "")
    }

    func cloudSupports(_ locale: Locale) async -> Bool {
        cloudLanguages.contains(locale.language.languageCode?.identifier ?? "")
    }
}
