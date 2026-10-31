//
//  FontPack+Licence.swift
//  Cue Studio
//

import Foundation

/// A library family's licence, for Settings › Acknowledgements: every one is under the SIL Open Font License 1.1, whose text
/// ships in the bundle with the bundled faces (Inter's copy, without Inter's own notice).
nonisolated extension FontPack {
    var licenceName: String { "SIL Open Font License 1.1" }

    static var licenceText: String {
        let text = Bundle.main.url(forResource: "inter-OFL", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        guard let start = text.range(of: "This Font Software is licensed") else { return text }
        return String(text[start.lowerBound...])
    }
}
