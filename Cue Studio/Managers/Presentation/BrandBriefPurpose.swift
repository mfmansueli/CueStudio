//
//  BrandBriefPurpose.swift
//  Cue Studio
//

import Foundation

/// What the brand brief is for: "✦ Write the ad" now (from the card's format), or the sections of a draft to write by hand.
enum BrandBriefPurpose: Hashable {
    case writeFromCard
    case draft
}
