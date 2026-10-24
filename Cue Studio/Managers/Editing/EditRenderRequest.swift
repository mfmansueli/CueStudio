//
//  EditRenderRequest.swift
//  Cue Studio
//

import Foundation

/// One drawing of an edit, prepared the same way for the editor's preview, a take's review and the export (`EditRenderPurpose`):
/// what is drawn (`RenderPlan`), Studio Voice's sounds (and the leveling between recordings) and where people speak (for music
/// that ducks). The preview and the export build from it (`build`), so nothing is prepared twice in two ways.
nonisolated struct EditRenderRequest: Sendable {
    let source: URL
    let plan: RenderPlan
    let sound: RecordingSounds
    let speech: VoiceActivity

    /// The request for `edit` of the recording at `source`. `treatsSound` false plays the recordings' own sound (an export of a
    /// take never edited).
    static func prepare(
        source: URL, edit: TakeEdit, purpose: EditRenderPurpose, treatsSound: Bool = true, sounds: RecordingSoundCache
    ) async throws -> EditRenderRequest {
        let sound = treatsSound ? try await RecordingSounds.prepare(for: edit, takeURL: source, cache: sounds) : .none
        return EditRenderRequest(
            source: source, plan: RenderPlan(edit, purpose: purpose), sound: sound,
            speech: await speech(in: edit, take: source, sounds: sounds)
        )
    }

    func build() async throws -> EditedComposition {
        try await EditedComposition.build(source: source, plan: plan, sound: sound, speech: speech)
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
