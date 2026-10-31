//
//  ScriptTypeMapTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Every Latin face has a character, every character a face in every script, and the library the faces come from is complete:
/// each family of its script, free, pinned and checkable.
@Suite("Script type map and libraries")
struct ScriptTypeMapTests {
    private let manifest = FontPackManifest.bundled

    @Test func everyLatinFaceHasItsCharacter() {
        let expected: [TextOverlayFont: TypeCharacter] = [
            .montserrat: .geometric, .poppins: .geometric, .tiktokSans: .sans, .dmSans: .sans, .sfPro: .sans, .spaceGrotesk: .sans,
            .rubik: .rounded, .unbounded: .wide, .syne: .wide, .anton: .condensed, .bangers: .comic, .dmSerif: .serif,
            .instrumentSerif: .serif, .caveat: .handwritten, .spaceMono: .mono,
        ]
        for face in TextOverlayFont.editorFonts { #expect(expected[face] == face.character, "\(face)") }
        #expect(TextOverlayFont.character(ofFontNamed: "Anton-Regular") == .condensed)
        #expect(TextOverlayFont.character(ofFontNamed: "Poppins-ExtraBold") == .geometric)
        #expect(TextOverlayFont.character(ofFontNamed: "DMSerifDisplay-Regular") == .serif)
        #expect(TextOverlayFont.character(ofFontNamed: "Inter-Regular") == .sans)
        // Every caption preset reaches a character, at a weight as heavy as it looks.
        for theme in CaptionTheme.allCases {
            let spec = CaptionStyleSpec.spec(for: theme, version: CaptionStyleSpec.currentVersion)
            if spec.fontName.hasPrefix("Anton") || spec.face == .bangers { #expect(spec.scriptWeight == .heavy, "\(theme)") }
            _ = spec.typeCharacter
        }
    }

    @Test func everyCharacterMapsToAFamilyOfItsOwnScript() throws {
        for script in WritingScript.allCases {
            for character in TypeCharacter.allCases {
                guard let id = ScriptTypeMap.packID(for: character, in: script) else {
                    // Arabic's system face is the system font's own (SF Arabic), the cascade's last entry.
                    #expect(script == .arabic || !ScriptTypeMap.systemFaces(for: character, in: script, weight: .bold).isEmpty, "\(script) \(character)")
                    continue
                }
                let pack = try #require(manifest.pack(id), "\(id)")
                #expect(pack.script == script, "\(id) is \(pack.script), mapped for \(script)")
            }
        }
    }

    @Test func theMapKeepsEachStylesPersonality() {
        #expect(ScriptTypeMap.packID(for: .condensed, in: .japanese) == "delagothicone")
        #expect(ScriptTypeMap.packID(for: .rounded, in: .japanese) == "mplusrounded1c")
        #expect(ScriptTypeMap.packID(for: .serif, in: .japanese) == "zenoldmincho")
        #expect(ScriptTypeMap.packID(for: .handwritten, in: .japanese) == "yomogi")
        #expect(ScriptTypeMap.packID(for: .wide, in: .arabic) == "lalezar")
        #expect(ScriptTypeMap.packID(for: .serif, in: .arabic) == "amiri")
        #expect(ScriptTypeMap.packID(for: .handwritten, in: .thai) == "sriracha")
        // Plain Chinese and Korean stay in the system's faces (nothing to download); Poppins draws its own Devanagari.
        #expect(ScriptTypeMap.packID(for: .sans, in: .chineseSimplified) == nil)
        #expect(ScriptTypeMap.packID(for: .sans, in: .korean) == nil)
        #expect(ScriptTypeMap.systemFaces(for: .geometric, in: .devanagari, weight: .heavy).first == "Poppins-ExtraBold")
        #expect(ScriptTypeMap.systemFaces(for: .sans, in: .japanese, weight: .heavy) == ["HiraginoSans-W8"])
        #expect(ScriptTypeMap.systemFaces(for: .serif, in: .japanese, weight: .regular) == ["HiraMinProN-W3"])
    }

    @Test func theLatinStandInsDrawVietnamese() {
        for character in TypeCharacter.allCases {
            let face = ScriptTypeMap.latinStandIn(for: character)
            let font = TextFont.font(face, weight: .bold, size: 30, text: "Tiếng Việt")
            #expect(ScriptFontCascade.coversLatin(font, "Tiếng Việt ệ ộ ữ ỹ Ơ ư đ"), "\(character): \(face)")
        }
    }

    @Test func theLibraryIsCompleteAndCheckable() {
        #expect(manifest.source.hasPrefix("github.com/google/fonts@"))
        #expect(Set(manifest.packs.map(\.id)).count == manifest.packs.count)
        for script in WritingScript.allCases {
            #expect(manifest.packs(for: script).count >= 5, "\(script)")
        }
        let commit = String(manifest.source.split(separator: "@").last ?? "")
        for pack in manifest.packs {
            #expect(pack.licence == "OFL", "\(pack.id)")
            #expect(!pack.copyright.isEmpty && !pack.files.isEmpty && !pack.weights.isEmpty, "\(pack.id)")
            for file in pack.files {
                #expect(file.url.scheme == "https" && file.url.absoluteString.contains(commit), "\(file.file)")
                #expect(file.sha256.count == 64 && file.sha256.allSatisfy(\.isHexDigit), "\(file.file)")
                #expect(file.bytes > 10_000, "\(file.file)")
            }
        }
    }

    @Test func aFamilyDrawsEachWeightFromTheNearestFile() throws {
        let kanit = try #require(manifest.pack("kanit"))
        #expect(kanit.file(for: .regular).file == "Kanit-Regular.ttf")
        // Heavy reaches past ExtraBold to the Black a display family has.
        #expect(kanit.file(for: .heavy).file == "Kanit-Black.ttf")
        #expect(kanit.file(for: .bold).file == "Kanit-Bold.ttf")
        let zenMaru = try #require(manifest.pack("zenmarugothic"))
        #expect(zenMaru.file(for: .heavy).file == "ZenMaruGothic-Black.ttf")
        #expect(zenMaru.weights == [.regular, .medium, .bold, .heavy])
        let cairo = try #require(manifest.pack("cairo"))
        #expect(cairo.files.count == 1 && cairo.file(for: .heavy).weightRange != nil)
        let dela = try #require(manifest.pack("delagothicone"))
        #expect(dela.weights == [.regular])
    }

    @Test func aLibraryFamilyIsSavedByItsID() throws {
        let face = TextOverlayFont.pack("zenmarugothic")
        #expect(face.rawValue == "pack:zenmarugothic")
        #expect(TextOverlayFont(rawValue: "pack:zenmarugothic") == face)
        #expect(face.label == "Zen Maru Gothic")
        #expect(face.character == .rounded)
        #expect(face.weights == [.regular, .medium, .bold, .heavy])
        let data = try JSONEncoder().encode(face)
        #expect(try JSONDecoder().decode(TextOverlayFont.self, from: data) == face)
        // A family a later version dropped still reads, and draws in the system's face.
        #expect(TextOverlayFont(rawValue: "pack:gone")?.label == "gone")
    }
}
