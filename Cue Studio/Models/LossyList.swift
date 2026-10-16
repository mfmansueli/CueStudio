//
//  LossyList.swift
//  Cue Studio
//

import Foundation

/// A saved list read one element at a time: an element that can't be read (a field from a newer version, a damaged value)
/// is left out and counted, instead of taking the whole list — a library of takes, an edit's texts or media — with it.
nonisolated struct LossyList<Element: Decodable>: Decodable {
    let elements: [Element]
    /// Elements that couldn't be read.
    let dropped: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        var dropped = 0
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                // A failed decode doesn't move on: read the element as anything to step past it.
                _ = try? container.decode(Skipped.self)
                dropped += 1
            }
        }
        self.elements = elements
        self.dropped = dropped
    }

    private struct Skipped: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

extension KeyedDecodingContainer {
    /// The list at `key`, element by element (`LossyList`); empty when there is none or it isn't a list.
    nonisolated func decodeLossy<Element: Decodable>(_ type: [Element].Type, forKey key: Key) -> [Element] {
        ((try? decodeIfPresent(LossyList<Element>.self, forKey: key)) ?? nil)?.elements ?? []
    }
}
