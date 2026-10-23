//
//  EditRenderRequest.swift
//  Cue Studio
//

import Foundation

/// One drawing of an edit, prepared the same way for the editor's preview, a take's review and the export (`EditRenderPurpose`):
/// Studio Voice's sounds (and the leveling between recordings), where people speak (for music that ducks) and the options. The
/// preview and the export build from it (`build`), so nothing is prepared twice in two ways.
nonisolated struct EditRenderRequest: Sendable {
    let source: URL
    let edit: TakeEdit
    let sound: RecordingSounds
    let speech: VoiceActivity
    let options: EditedComposition.Options

    /// The request for `edit` of the recording at `source`. `treatsSound` false plays the recordings' own sound (an export of a
    /// take never edited).
    static func prepare(
        source: URL, edit: TakeEdit, purpose: EditRenderPurpose, treatsSound: Bool = true, sounds: RecordingSoundCache
    ) async throws -> EditRenderRequest {
        let sound = treatsSound ? try await RecordingSounds.prepare(for: edit, takeURL: source, cache: sounds) : .none
        return EditRenderRequest(
            source: source, edit: edit, sound: sound, speech: await speech(in: edit, take: source, sounds: sounds), options: purpose.options
        )
    }

    func build() async throws -> EditedComposition {
        try await EditedComposition.build(source: source, edit: edit, sound: sound, speech: speech, options: options)
    }

    /// Where someone speaks in the take and the other recordings the edit plays; nothing when no music ducks.
    private static func speech(in edit: TakeEdit, take: URL, sounds: RecordingSoundCache) async -> VoiceActivity {
        guard edit.ducksMusic else { return .none }
        var activity = VoiceActivity()
        activity.take = await sounds.speechSpans(in: take)
        for source in edit.playedSources {
            activity.sources[source.id] = await sounds.speechSpans(in: EditMediaFiles.url(for: source.fileName))
        }
        return activity
    }
}
