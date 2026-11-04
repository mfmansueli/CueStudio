//
//  ClaudeStageShape.swift
//  Cue Studio
//

import Foundation

/// The JSON each Ultra AI stage answers in when Claude writes (structured outputs), the same shapes `FirebaseUltraClient` asks Gemini for, every
/// key required. The draft is plain speech and has none. Sent with each call, so the app stays the one place that knows what it reads back.
nonisolated enum ClaudeStageShape {
    static func schema(for stage: UltraStageRequest.Stage) -> [String: Any]? {
        switch stage {
        case .draft: nil
        case .check: object(["script": string, "corrections": array(of: string)])
        case .review: object(["title": string, "script": string, "changes": array(of: string)])
        case .fit: object(["script": string])
        case .ideas: object(["ideas": array(of: idea)])
        }
    }

    /// One of the library's ideas, with its topic's number and its angle's key.
    private static var idea: [String: Any] {
        object(["topic": ["type": "integer"], "angle": string, "title": string, "pointOfView": string, "openingLine": string])
    }

    private static var string: [String: Any] { ["type": "string"] }

    private static func array(of items: [String: Any]) -> [String: Any] {
        ["type": "array", "items": items]
    }

    private static func object(_ properties: [String: [String: Any]]) -> [String: Any] {
        ["type": "object", "properties": properties, "required": properties.keys.sorted(), "additionalProperties": false]
    }
}
