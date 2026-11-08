//
//  CoverGalleryCardTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Template's row: the creator's styles, then Cue's templates; "Save style" ends the creator's styles, or the whole row while
/// there are none (the same rule as Caption style and Text).
@Suite("Cover gallery card")
struct CoverGalleryCardTests {
    @Test func withoutSavedStylesSaveStyleIsTheLastCard() {
        let cards = CoverGalleryCard.gallery(saved: [])
        #expect(cards.last == .saveStyle)
        #expect(Array(cards.dropLast()) == CoverTemplate.allCases.map(CoverGalleryCard.template))
        #expect(cards.filter { $0 == .saveStyle }.count == 1)
    }

    @Test func withSavedStylesSaveStyleEndsThem() {
        let mine = [UUID(), UUID()]
        let cards = CoverGalleryCard.gallery(saved: mine)
        #expect(Array(cards.prefix(3)) == [.saved(mine[0]), .saved(mine[1]), .saveStyle])
        #expect(Array(cards.dropFirst(3)) == CoverTemplate.allCases.map(CoverGalleryCard.template))
        #expect(Set(cards.map(\.id)).count == cards.count)
    }
}
