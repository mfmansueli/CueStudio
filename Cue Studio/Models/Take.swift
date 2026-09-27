//
//  Take.swift
//  Cue Studio
//

import Foundation

/// A recorded video. The file lives in the app's Takes folder; this is its metadata. The file is
/// referenced by name, not by URL, because the app container's path changes between installs.
nonisolated struct Take: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    /// Nil for freestyle recordings made without a script.
    var scriptID: UUID?
    /// Kept so the take still groups under a name after its script is deleted.
    var scriptTitle: String
    /// The script version that was read; editing the script later creates a new version.
    var scriptVersion: Int?
    var number: Int
    var duration: TimeInterval
    /// When it was recorded ("createdAt").
    var recordedAt: Date = .now
    var fileName: String
    var isBest: Bool = false
    var resolution: VideoResolution
    var frameRate: FrameRate
    var aspect: AspectRatio
    var platform: Platform?
    /// Changed in Quick edit (the original file is never touched).
    var isEdited: Bool = false
    /// Saved or shared at least once; "Not shared" in the library means false.
    var isExported: Bool = false
    /// Quick edit's recipe, applied on top of the recording when it plays or exports.
    var edit: TakeEdit?

    init(
        id: UUID = UUID(), scriptID: UUID?, scriptTitle: String, scriptVersion: Int?, number: Int,
        duration: TimeInterval, recordedAt: Date = .now, fileName: String, isBest: Bool = false,
        resolution: VideoResolution, frameRate: FrameRate, aspect: AspectRatio, platform: Platform?,
        isEdited: Bool = false, isExported: Bool = false, edit: TakeEdit? = nil
    ) {
        self.id = id
        self.scriptID = scriptID
        self.scriptTitle = scriptTitle
        self.scriptVersion = scriptVersion
        self.number = number
        self.duration = duration
        self.recordedAt = recordedAt
        self.fileName = fileName
        self.isBest = isBest
        self.resolution = resolution
        self.frameRate = frameRate
        self.aspect = aspect
        self.platform = platform
        self.isEdited = isEdited
        self.isExported = isExported
        self.edit = edit
    }

    /// The frame the take exports in: the edit's crop, or the frame it was filmed for.
    var outputAspect: AspectRatio { edit?.aspect ?? aspect }

    var label: String { String(localized: "Take \(number)") }

    var isFreestyle: Bool { scriptID == nil }

    // MARK: - Coding

    /// Fields added after v1 are optional, so takes recorded by older builds still open.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scriptID = try container.decodeIfPresent(UUID.self, forKey: .scriptID)
        scriptTitle = try container.decode(String.self, forKey: .scriptTitle)
        scriptVersion = try container.decodeIfPresent(Int.self, forKey: .scriptVersion)
        number = try container.decode(Int.self, forKey: .number)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        recordedAt = try container.decodeIfPresent(Date.self, forKey: .recordedAt) ?? .now
        fileName = try container.decode(String.self, forKey: .fileName)
        isBest = try container.decodeIfPresent(Bool.self, forKey: .isBest) ?? false
        resolution = try container.decode(VideoResolution.self, forKey: .resolution)
        frameRate = try container.decode(FrameRate.self, forKey: .frameRate)
        aspect = try container.decode(AspectRatio.self, forKey: .aspect)
        platform = try container.decodeIfPresent(Platform.self, forKey: .platform)
        isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
        isExported = try container.decodeIfPresent(Bool.self, forKey: .isExported) ?? false
        edit = try container.decodeIfPresent(TakeEdit.self, forKey: .edit)
    }
}
