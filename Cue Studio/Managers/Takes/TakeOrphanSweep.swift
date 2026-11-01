//
//  TakeOrphanSweep.swift
//  Cue Studio
//

import Foundation

/// Gives back the space of take videos nothing names any more: a recording a past session moved in but never filed, a deleted take whose Undo
/// was still on screen when iOS ended Cue, a video a deletion couldn't remove (decision of the owner, 01/11/2026).
///
/// Only the takes' own folder, only its videos and their motion analyses (never a JSON file, never another folder), once a launch, well after it.
/// A video goes only when, at that moment: the library was read (`TakeLibraryService.isRead`) and the camera's leftovers recovered (the sweep runs
/// after `TakeRecovery`); every record Cue keeps as JSON under Application Support could be read and none names it (the library, its kept copies,
/// the drafts…, looked up as text, so a record a newer version wrote still counts); no take in memory has it and no deleted take is waiting on its
/// Undo with it; it hasn't changed for `settleAge`; and it was first found nameless at least `graceAge` ago. That first sighting is kept
/// (`DefaultsKey.takeOrphanSightings`): a file's date says when it was made, not since when nothing names it. A deletion decided is written down
/// before it runs (`PendingTakeDeletions`), so one cut short finishes at the next launch.
nonisolated enum TakeOrphanSweep {
    static let graceAge: TimeInterval = 7 * 24 * 60 * 60
    /// A file changed this recently may be being written (a take moved in, not filed yet): left for the next launch.
    static let settleAge: TimeInterval = 10 * 60
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    struct Plan: Equatable {
        /// When each nameless file was first found so, still waiting for its week.
        var sightings: [String: Date]
        /// What goes now (written down first).
        var doomed: Set<String>
        /// Deletions written down that no longer need doing: the take came back, or the file is already gone.
        var resolved: Set<String>
    }

    /// What the sweep does with `files` (name and last change in the takes' folder). `named`: a take or a saved record names it; `inUse`: videos
    /// held right now (a deleted take's, while its Undo can bring it back), left exactly as they are.
    static func plan(
        files: [String: Date], named: (String) -> Bool, inUse: Set<String>, sightings: [String: Date], pending: Set<String>, now: Date
    ) -> Plan {
        let settled = now.addingTimeInterval(-settleAge)
        var plan = Plan(sightings: [:], doomed: [], resolved: [])
        for (name, changed) in files {
            guard let video = video(of: name, in: files) else { continue }
            if inUse.contains(video) {
                if let first = sightings[name] { plan.sightings[name] = first }
                continue
            }
            if named(video) {
                if pending.contains(name) { plan.resolved.insert(name) }
                continue
            }
            let first = sightings[name] ?? now
            guard changed < settled else {
                plan.sightings[name] = first
                continue
            }
            if pending.contains(name) || now.timeIntervalSince(first) >= graceAge {
                plan.doomed.insert(name)
                let analysis = name + "." + MotionAnalysisStore.pathExtension
                if files[analysis] != nil { plan.doomed.insert(analysis) }
            } else {
                plan.sightings[name] = first
            }
        }
        for name in pending where files[name] == nil && !inUse.contains(name) { plan.resolved.insert(name) }
        return plan
    }

    /// The video a file of the folder stands for: itself, or the one a motion analysis belongs to when that video is gone (with its video
    /// there, an analysis goes with it). Nil for anything else.
    private static func video(of name: String, in files: [String: Date]) -> String? {
        let url = URL(filePath: name)
        let ext = url.pathExtension.lowercased()
        if ext == MotionAnalysisStore.pathExtension {
            let video = url.deletingPathExtension().lastPathComponent
            return files[video] == nil && videoExtensions.contains(URL(filePath: video).pathExtension.lowercased()) ? video : nil
        }
        return videoExtensions.contains(ext) ? name : nil
    }

    /// Runs the sweep (the reading and the removing off the main actor); returns what was removed.
    @MainActor
    @discardableResult
    static func sweep(
        takes: TakeLibraryService, pending: PendingTakeDeletions, folder: URL = LocalTakeRepository.defaultDirectory,
        support: URL = .applicationSupportDirectory, now: Date = .now
    ) async -> Set<String> {
        guard takes.isRead, let found = await read(folder: folder, support: support), takes.isRead else { return [] }
        let library = Set(takes.takes.map(\.fileName))
        let defaults = pending.defaults
        let plan = plan(
            files: found.files, named: { library.contains($0) || found.saved.contains($0) }, inUse: takes.videosAwaitingPurge,
            sightings: defaults.dictionary(forKey: DefaultsKey.takeOrphanSightings) as? [String: Date] ?? [:], pending: pending.names, now: now
        )
        pending.remove(plan.resolved)
        pending.add(plan.doomed)
        if plan.sightings.isEmpty {
            defaults.removeObject(forKey: DefaultsKey.takeOrphanSightings)
        } else {
            defaults.set(plan.sightings, forKey: DefaultsKey.takeOrphanSightings)
        }
        guard !plan.doomed.isEmpty else { return [] }
        let gone = await remove(plan.doomed, in: folder)
        pending.remove(gone)
        return gone
    }

    /// The folder's files and every JSON record under `support` as text; nil when there is nothing to look at or a record can't be read now
    /// (the iPhone locked since launch, a damaged file): it might name any of them.
    @concurrent
    private static func read(folder: URL, support: URL) async -> (files: [String: Date], saved: String)? {
        let files = EditStorageCleaner.modified(in: folder)
        guard !files.isEmpty, let saved = EditStorageCleaner.savedText(in: support) else { return nil }
        return (files, saved)
    }

    /// Removes `names` from `folder`; returns those no longer there (a removal that failed stays written down for the next launch).
    @concurrent
    private static func remove(_ names: Set<String>, in folder: URL) async -> Set<String> {
        var gone = Set<String>()
        for name in names {
            let url = folder.appending(path: name)
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) { try? FileManager.default.removeItem(at: url) }
            if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) { gone.insert(name) }
        }
        return gone
    }
}
