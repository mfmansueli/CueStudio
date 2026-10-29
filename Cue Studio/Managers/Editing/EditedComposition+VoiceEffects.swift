//
//  EditedComposition+VoiceEffects.swift
//  Cue Studio
//

import AVFoundation

/// Voice effects in the composition: a clip with one plays its stretch of the recording (or of Studio Voice's treatment) through
/// the effect, a voice-over with one plays its whole recording through it (so trimming it never makes it again). Made by
/// `VoiceEffectRenderer`; one that can't be made plays as recorded rather than failing the edit.
nonisolated extension EditedComposition {
    /// The sound of each clip of `segments` with a voice effect, by clip, read from the sound `sound` gives its recording, and
    /// the assets that hold them (kept until the composition is built).
    static func effectSounds(
        for segments: [EditSegment], sound: (UUID?) -> AVAssetTrack?
    ) async throws -> (assets: [AVURLAsset], tracks: [UUID: AVAssetTrack]) {
        var assets: [AVURLAsset] = []
        var tracks: [UUID: AVAssetTrack] = [:]
        for segment in segments where !segment.isMuted {
            guard let setting = segment.voiceEffect, let track = sound(segment.sourceID), let file = (track.asset as? AVURLAsset)?.url else {
                continue
            }
            if let rendered = try await effectTrack(
                of: file, trackID: track.trackID, span: segment.span, setting: setting, clip: segment.id.uuidString, keeping: &assets
            ) {
                tracks[segment.id] = rendered
            }
        }
        return (assets, tracks)
    }

    /// The voice-over's recording with its voice effect, or nil when it has none or it can't be made.
    static func effectSound(of clip: VoiceOverClip, keeping assets: inout [AVURLAsset]) async throws -> AVAssetTrack? {
        guard let setting = clip.voiceEffect else { return nil }
        return try await effectTrack(
            of: EditMediaFiles.url(for: clip.fileName), trackID: nil, span: nil, setting: setting, clip: clip.id.uuidString, keeping: &assets
        )
    }

    private static func effectTrack(
        of file: URL, trackID: CMPersistentTrackID?, span: TimeSpan?, setting: VoiceEffectSetting, clip: String,
        keeping assets: inout [AVURLAsset]
    ) async throws -> AVAssetTrack? {
        let url: URL
        do {
            url = try await VoiceEffectRenderer.render(file: file, trackID: trackID, span: span, setting: setting, clip: clip)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .audio).first else { return nil }
        assets.append(asset)
        return track
    }
}
