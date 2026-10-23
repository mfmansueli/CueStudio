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
                decoder.decodingReport?.note("\(Element.self) left out of a list")
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

    /// The part at `key`, or nil when there is none or it can't be read: then it is noted in `report` (a part a newer
    /// version wrote, or a damaged one), so the store keeps the file as it was (`DecodingReport`).
    nonisolated func decodeLenient<Value: Decodable>(_ type: Value.Type, forKey key: Key, report: DecodingReport?) -> Value? {
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            report?.note("\(Value.self) at “\(key.stringValue)” left out")
            return nil
        }
    }
}
