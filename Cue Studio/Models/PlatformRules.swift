//
//  PlatformRules.swift
//  Cue Studio
//

import Foundation

/// Every platform number Cue relies on — frame, quality, length goals, monetization minimums,
/// reading width and safe zones — decoded from `PlatformRules.json`. Platforms change their rules
/// and their apps' layout, so the file ships in the bundle and can be replaced by a newer copy from
/// the web (see `PlatformRulesService`).
nonisolated struct PlatformRules: Codable, Hashable, Sendable {
    /// The only file layout this build understands. Remote files with another schema are ignored.
    /// Schema 2 (v7) measures safe zones in pixels of the video instead of points on a screen.
    static let supportedSchemaVersion = 2

    struct Monetization: Codable, Hashable, Sendable {
        var ideal: [Double]
        var minimum: Double
        var goal: MonetizationGoal
    }

    struct Entry: Codable, Hashable, Sendable {
        var aspect: AspectRatio
        var resolution: VideoResolution
        var frameRate: FrameRate
        /// Ideal length in seconds without monetization goals: `[low, high]`.
        var ideal: [Double]
        /// Only for platforms that pay by length.
        var monetization: Monetization?
        var prefersStudio: Bool
        /// Selfie text window width, as a fraction of the screen.
        var readingWidth: Double
        /// Where the platform's UI covers the video. None for horizontal video.
        var safeZone: SocialSafeZonePreset?
    }

    enum ValidationError: Error, Equatable {
        case unsupportedSchema(Int)
        case missingPlatform(String)
        case invalidRange(String)
        case invalidSafeZone(String)
    }

    var schemaVersion: Int
    /// Bumped with every published change; a cached or downloaded file only wins when it is newer.
    var revision: Int
    var platforms: [String: Entry]

    // MARK: - Decoding

    /// Decodes and validates a rules file. Anything incomplete is rejected as a whole, so the app
    /// never mixes rules from two files.
    static func decode(_ data: Data) throws -> PlatformRules {
        let rules = try JSONDecoder().decode(PlatformRules.self, from: data)
        try rules.validate()
        return rules
    }

    func validate() throws {
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw ValidationError.unsupportedSchema(schemaVersion)
        }
        for platform in Platform.allCases {
            guard let entry = platforms[platform.rawValue] else {
                throw ValidationError.missingPlatform(platform.rawValue)
            }
            let ranges = [entry.ideal] + (entry.monetization.map { [$0.ideal] } ?? [])
            for range in ranges where range.count != 2 || range[0] < 0 || range[0] > range[1] {
                throw ValidationError.invalidRange(platform.rawValue)
            }
            if let zone = entry.safeZone, !zone.isValid || zone.aspect != entry.aspect {
                throw ValidationError.invalidSafeZone(platform.rawValue)
            }
        }
    }

    // MARK: - Reading

    /// Validation guarantees every platform has an entry.
    func entry(for platform: Platform) -> Entry {
        guard let entry = platforms[platform.rawValue] else {
            preconditionFailure("PlatformRules was not validated: \(platform.rawValue) is missing")
        }
        return entry
    }

    func preset(for platform: Platform, monetizationGoals: Bool) -> PlatformPreset {
        let entry = entry(for: platform)
        let monetization = monetizationGoals ? entry.monetization : nil
        let ideal = monetization?.ideal ?? entry.ideal
        return PlatformPreset(
            aspect: entry.aspect,
            resolution: entry.resolution,
            frameRate: entry.frameRate,
            idealRange: ideal[0]...ideal[1],
            minimum: monetization?.minimum,
            goal: monetization?.goal,
            prefersStudio: entry.prefersStudio,
            readingWidth: entry.readingWidth,
            safeZone: entry.safeZone
        )
    }

    /// The platform's safe zone, whatever the script is for: the Selfie camera lets the creator
    /// check the frame against another app's layout.
    func safeZone(for platform: Platform) -> SocialSafeZonePreset? {
        entry(for: platform).safeZone
    }
}
