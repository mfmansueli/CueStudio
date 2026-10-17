//
//  SubjectSample.swift
//  Cue Studio
//

import Foundation

/// Who is in a recording's frame at a moment: the faces and the people (bodies) Vision found, largest first, on the upright
/// frame. Taken ten times a second, which is enough to follow a face and cheap enough to run on every recording.
nonisolated struct SubjectSample: Codable, Hashable, Sendable {
    /// Most faces and bodies kept per moment: the people far behind the creator don't matter for framing.
    static let maximumPerKind = 4

    /// Seconds of the recording.
    var time: TimeInterval
    var faces: [NormalizedBox]
    var bodies: [NormalizedBox]

    init(time: TimeInterval, faces: [NormalizedBox], bodies: [NormalizedBox]) {
        self.time = time
        self.faces = Array(faces.sorted { $0.area > $1.area }.prefix(Self.maximumPerKind))
        self.bodies = Array(bodies.sorted { $0.area > $1.area }.prefix(Self.maximumPerKind))
    }

    private enum CodingKeys: String, CodingKey {
        case time = "t", faces = "f", bodies = "b"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode(TimeInterval.self, forKey: .time)
        faces = (try? container.decodeIfPresent([NormalizedBox].self, forKey: .faces)) ?? []
        bodies = (try? container.decodeIfPresent([NormalizedBox].self, forKey: .bodies)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode((time * 1000).rounded() / 1000, forKey: .time)
        if !faces.isEmpty { try container.encode(faces, forKey: .faces) }
        if !bodies.isEmpty { try container.encode(bodies, forKey: .bodies) }
    }
}
