//
//  TopicChoice.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// The topic Cue files a script under (Settings › Personalize › Tag new scripts automatically).
@Generable
nonisolated struct TopicChoice {
    @Guide(description: "Exactly one of the topics given, copied as written, or the word none when the script fits none of them.")
    var topic: String
}
