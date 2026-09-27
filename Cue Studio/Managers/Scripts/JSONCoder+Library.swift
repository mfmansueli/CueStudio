//
//  JSONCoder+Library.swift
//  Cue Studio
//

import Foundation

/// Coders shared by the local repositories, so dates are written the same way everywhere.
extension JSONEncoder {
    nonisolated static var library: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    nonisolated static var library: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
