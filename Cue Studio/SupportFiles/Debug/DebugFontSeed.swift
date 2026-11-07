//
//  DebugFontSeed.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// `-uiTestImportedFont <Name>`: the creator has imported a family called `Name` (five letters): Cue's own Anton under that
/// name, as `TestFonts.renamedAnton` makes it for the unit tests, brought in through the store like a file from Files. For the
/// UI tests of My fonts (Edit, Remove, Undo).
enum DebugFontSeed {
    @MainActor
    static func seed(_ family: String, into fonts: CustomFontStore) async {
        guard family.count == 5, !fonts.offered.contains(where: { $0.name == family }),
              let source = Bundle.main.url(forResource: "Anton-Regular", withExtension: "ttf"),
              var data = try? Data(contentsOf: source) else { return }
        // The name table keeps names as plain bytes (Mac) and as UTF-16 big-endian (Windows).
        replace(Data("Anton".utf8), with: Data(family.utf8), in: &data)
        replace(utf16(of: "Anton"), with: utf16(of: family), in: &data)
        let url = URL.temporaryDirectory.appending(path: "\(family)-Regular.ttf")
        guard (try? data.write(to: url)) != nil else { return }
        _ = await fonts.importFonts(from: [url])
        try? FileManager.default.removeItem(at: url)
    }

    private static func utf16(of text: String) -> Data {
        Data(text.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] })
    }

    private static func replace(_ old: Data, with new: Data, in data: inout Data) {
        var start = data.startIndex
        while let found = data.range(of: old, in: start..<data.endIndex) {
            data.replaceSubrange(found, with: new)
            start = found.upperBound
        }
    }
}
#endif
