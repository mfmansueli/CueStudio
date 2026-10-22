//
//  VideoCodec.swift
//  Cue Studio
//

import Foundation

nonisolated enum VideoCodec: String, Codable, CaseIterable, Identifiable, Sendable {
    case hevc, h264

    var id: String { rawValue }

    /// "Format" as a file format (not the video's frame or the script's format): the camera sheet's HEVC | H.264 row.
    static var settingLabel: String {
        String(inInterfaceLanguage: LocalizedStringResource(
            "format.file", defaultValue: "Format",
            comment: "The file format a video is saved or shared as: HEVC | H.264 in the recorder's camera sheet, Image | video when sharing the universe."
        ))
    }

    var label: String {
        switch self {
        case .hevc: "HEVC"
        case .h264: "H.264"
        }
    }
}
