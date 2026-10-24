//
//  FakeTextStyleStore.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Saved styles in memory, so tests never write the simulator's defaults.
@MainActor
final class FakeTextStyleStore: TextStyleStoring {
    var captionStyles = StyleLibrary<MyCaptionStyle>()
    var textStyles = StyleLibrary<TextLook>()
    var coverStyles = StyleLibrary<CoverStyle>()
    var captionCatalogFilter: String?

    /// A store with `myStyle` saved as the creator's one text style.
    init(myStyle: TextLook? = nil) {
        if let myStyle { textStyles.add(myStyle, named: "My style") }
    }
}
