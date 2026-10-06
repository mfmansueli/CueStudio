//
//  SkinFaceTracker.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A face that stays the same face from one detection to the next, and how much of the smoothing it has now.
nonisolated struct TrackedFace: Hashable, Sendable {
    var id: Int
    var landmarks: FaceLandmarks
    /// 0…1: a face that has just come into the shot fades in, one that stops being found fades out, so smoothing never switches on or off in one frame.
    var presence: Double
}

/// Follows the faces of a stretch of video from one detection to the next, so the smoothing doesn't flicker or jump. Pure: it is given the faces each
/// detection found and the time, and says where each face is and how present it is.
/// - A detection near a face already followed is that face: it moves `followRate` of the way there (steady, and still keeps up with a head turn).
/// - A face that stops being found is kept for `holdTime`, fading out, so a blink of the detector goes unseen.
/// - A face that comes into the shot fades in over `fadeInTime`. One found when there was nothing before (the first frame, or after a seek) is there
///   in full at once, so a paused frame shows the whole effect.
/// - A seek (time backwards, or a gap longer than `continuityGap`) forgets everything.
nonisolated struct SkinFaceTracker: Sendable {
    private struct Track: Sendable {
        var id: Int
        var landmarks: FaceLandmarks
        var born: TimeInterval
        var lastSeen: TimeInterval
        /// How the face was moving at the last detection, in the frame's unit square a second.
        var velocity = CGVector.zero

        /// Where the face is `time` seconds after the last detection: carried along at its speed, for a little while.
        func landmarks(at time: TimeInterval) -> FaceLandmarks {
            let ahead = min(max(0, time - lastSeen), SkinSmoothingCalibration.extrapolationLimit)
            return ahead > 0 ? landmarks.translated(by: CGVector(dx: velocity.dx * ahead, dy: velocity.dy * ahead)) : landmarks
        }
    }

    private var tracks: [Track] = []
    private var nextID = 0
    private(set) var lastTime: TimeInterval?

    /// Forgets every face.
    mutating func reset() {
        tracks = []
        lastTime = nil
    }

    /// Whether `time` follows the last one closely enough for what is known to still hold.
    func isContinuous(at time: TimeInterval) -> Bool {
        guard let lastTime else { return false }
        let gap = time - lastTime
        return gap >= 0 && gap <= SkinSmoothingCalibration.continuityGap
    }

    /// Takes what a detection found at `time`.
    mutating func update(with detections: [FaceLandmarks], at time: TimeInterval) {
        if !isContinuous(at: time) { reset() }
        let hadFaces = !tracks.isEmpty || lastTime != nil
        var free = Array(tracks.indices)
        var kept: [Track] = []
        for detection in detections {
            let reach = SkinSmoothingCalibration.sameFaceDistance * max(detection.box.width, detection.box.height)
            let nearest = free.min { distance(tracks[$0].landmarks, detection) < distance(tracks[$1].landmarks, detection) }
            if let nearest, distance(tracks[nearest].landmarks, detection) <= reach {
                free.removeAll { $0 == nearest }
                var track = tracks[nearest]
                // From where the face was expected to be by now (carried along), a part of the way to where it was found.
                let before = track.landmarks.center
                let followed = track.landmarks(at: time).moved(toward: detection, rate: SkinSmoothingCalibration.followRate)
                let elapsed = time - track.lastSeen
                if elapsed > 0.001 {
                    let limit = SkinSmoothingCalibration.maximumSpeed * Double(max(detection.box.width, detection.box.height))
                    var measured = CGVector(dx: (followed.center.x - before.x) / elapsed, dy: (followed.center.y - before.y) / elapsed)
                    let speed = hypot(measured.dx, measured.dy)
                    if speed > limit { measured = CGVector(dx: measured.dx * limit / speed, dy: measured.dy * limit / speed) }
                    track.velocity = CGVector(dx: (track.velocity.dx + measured.dx) / 2, dy: (track.velocity.dy + measured.dy) / 2)
                }
                track.landmarks = followed
                track.lastSeen = time
                kept.append(track)
            } else {
                // New to the shot: it fades in, unless nothing was followed before (a first frame or a seek).
                let born = hadFaces ? time : time - SkinSmoothingCalibration.fadeInTime
                kept.append(Track(id: nextID, landmarks: detection, born: born, lastSeen: time))
                nextID += 1
            }
        }
        // The faces not found this time stay for a moment, fading out.
        for index in free where time - tracks[index].lastSeen < SkinSmoothingCalibration.holdTime { kept.append(tracks[index]) }
        tracks = kept
        lastTime = time
    }

    /// The faces followed and how present each one is at `time`, the largest first.
    func faces(at time: TimeInterval) -> [TrackedFace] {
        tracks.compactMap { track -> TrackedFace? in
            let coming = min(1, max(0, (time - track.born) / SkinSmoothingCalibration.fadeInTime))
            // The fade-out starts once the next detection is overdue: between two detections the face is as present as it was at the last one.
            let unseen = max(0, time - track.lastSeen - SkinSmoothingCalibration.detectionInterval)
            let going = 1 - min(1, unseen / SkinSmoothingCalibration.holdTime)
            let presence = Self.eased(min(coming, going))
            return presence > 0 ? TrackedFace(id: track.id, landmarks: track.landmarks(at: time), presence: presence) : nil
        }
        .sorted { $0.landmarks.box.width * $0.landmarks.box.height > $1.landmarks.box.width * $1.landmarks.box.height }
    }

    private func distance(_ from: FaceLandmarks, _ to: FaceLandmarks) -> Double {
        hypot(from.center.x - to.center.x, from.center.y - to.center.y)
    }

    private static func eased(_ value: Double) -> Double { value * value * (3 - 2 * value) }
}
