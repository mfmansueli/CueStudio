//
//  TestFonts.swift
//  Cue StudioTests
//

import Foundation

/// Font files for the import tests: the app's own Anton (SIL OFL) with its names changed to `family` (five letters, the same
/// length as "Anton", so no offset in the file moves), a font this iPhone doesn't have yet; written to a temporary file.
enum TestFonts {
    static func renamedAnton(to family: String) throws -> URL {
        precondition(family.count == 5, "The new name keeps Anton's five letters")
        guard let source = Bundle.main.url(forResource: "Anton-Regular", withExtension: "ttf") else { throw CocoaError(.fileNoSuchFile) }
        var data = try Data(contentsOf: source)
        // The name table keeps names as plain bytes (Mac) and as UTF-16 big-endian (Windows).
        replace(Data("Anton".utf8), with: Data(family.utf8), in: &data)
        replace(utf16(of: "Anton"), with: utf16(of: family), in: &data)
        let url = URL.temporaryDirectory.appending(path: "\(family)-\(UUID().uuidString).ttf")
        try data.write(to: url)
        return url
    }

    /// A unique five-letter family name, so tests running together never register the same one.
    static func uniqueFamily() -> String {
        let letters = Array("BCDFGHJKLMNPQRSTVWXZ")
        return "Q" + String((0..<4).map { _ in letters.randomElement() ?? "Z" }).lowercased()
    }

    private static func utf16(of text: String) -> Data {
        Data(text.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] })
    }

    private static func replace(_ old: Data, with new: Data, in data: inout Data) {
        var start = data.startIndex
        while let range = data.range(of: old, in: start..<data.endIndex) {
            data.replaceSubrange(range, with: new)
            start = range.upperBound
        }
    }
}
