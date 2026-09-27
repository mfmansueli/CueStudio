//
//  TestData.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Builders for test scenarios. Times are fixed so assertions never depend on the clock.
enum TestData {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// `count` spoken words.
    static func words(_ count: Int) -> String {
        Array(repeating: "word", count: count).joined(separator: " ")
    }

    static func script(
        title: String = "Test script",
        text: String = "Hook line.\n\nBody line.\n\nCall to action.",
        platform: Platform = .tiktok,
        type: ScriptType? = nil,
        version: Int = 1,
        folder: String? = nil,
        updatedAt: Date = now
    ) -> Script {
        Script(title: title, text: text, platform: platform, type: type, version: version, folder: folder, createdAt: updatedAt, updatedAt: updatedAt)
    }

    static func take(
        scriptID: UUID?,
        title: String = "Test script",
        number: Int = 1,
        recordedAt: Date = now,
        isBest: Bool = false
    ) -> Take {
        Take(
            scriptID: scriptID, scriptTitle: title, scriptVersion: 1, number: number, duration: 30,
            recordedAt: recordedAt, fileName: "take-\(UUID().uuidString).mov", isBest: isBest,
            resolution: .hd1080, frameRate: .fps30, aspect: .portrait, platform: .tiktok
        )
    }
}
