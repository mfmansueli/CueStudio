//
//  EditStorageCleaner.swift
//  Cue Studio
//

import Foundation

/// Gives the iPhone's space back once a launch, in the background: the sound files a past session made (`RecordingSoundCache`
/// lives in memory, so after a relaunch nothing holds them), only files of that cache, by their makers' prefixes, made before
/// this launch; the analyses of a tool Cue no longer has; and the edits' media nothing names any more (`orphanedMedia`: an
/// import a closed app never put in a draft, a file an edit left behind). Never a take's recording or an exported video
/// (`ExportLedgerService`).
nonisolated enum EditStorageCleaner {
    /// Files of the sound cache, by the prefix their makers give them.
    static let soundPrefixes = ["Cue-audio-", "Cue-level-", "Cue-master-", "Cue-mix-", "Cue-curve-"]

    /// Analyses kept next to the recordings by a tool Cue no longer has: Eye Contact's (removed 22/10/2026). Nothing reads them,
    /// so each goes by its extension alone, whatever its date.
    static let retiredExtensions: Set<String> = ["cueeyes"]

    static func retired(_ names: some Sequence<String>) -> [String] {
        names.filter { retiredExtensions.contains(URL(filePath: $0).pathExtension) }
    }

    /// The sound cache files to remove: made before this launch.
    static func staleSounds(files: [String: Date], launchedAt: Date) -> Set<String> {
        Set(files.filter { file in soundPrefixes.contains { file.key.hasPrefix($0) } && file.value < launchedAt }.map(\.key))
    }

    /// How long a file of the edits' media has to have gone unchanged, before this launch, to be found orphaned.
    static let orphanAge: TimeInterval = 7 * 24 * 60 * 60

    /// Files kept next to a media file, named after it: a recording's motion analysis, a sound's beats.
    static let sidecarExtensions: Set<String> = [MotionAnalysisStore.pathExtension, BeatStore.pathExtension]

    /// The edits' media nothing names: no file Cue keeps (`mentioned`: the takes, the copies kept aside, the drafts with their
    /// undo steps…) has its name, and it hasn't changed for `orphanAge` before this launch. A sidecar goes with its file, or on
    /// its own when its file is gone. The names are looked for as text, never read as an edit: a file that can't be read as
    /// one (a newer version's, a damaged one) still keeps its media.
    static func orphanedMedia(files: [String: Date], launchedAt: Date, mentioned: (String) -> Bool) -> Set<String> {
        let settled = launchedAt.addingTimeInterval(-orphanAge)
        var orphans = Set<String>()
        for (name, date) in files where date < settled {
            let url = URL(filePath: name)
            if sidecarExtensions.contains(url.pathExtension) {
                let owner = url.deletingPathExtension().lastPathComponent
                if files[owner] == nil, !mentioned(owner) { orphans.insert(name) }
            } else if !mentioned(name) {
                orphans.insert(name)
            }
        }
        return orphans
    }

    /// Removes them, off the main actor.
    @concurrent
    static func clean(
        launchedAt: Date, recordingFolders: [URL] = [LocalTakeRepository.defaultDirectory, EditMediaFiles.directory],
        media: URL = EditMediaFiles.directory, support: URL = .applicationSupportDirectory
    ) async {
        let temporary = URL.temporaryDirectory
        for name in staleSounds(files: modified(in: temporary), launchedAt: launchedAt) {
            try? FileManager.default.removeItem(at: temporary.appending(path: name))
        }
        for folder in recordingFolders {
            for name in retired(modified(in: folder).keys) { try? FileManager.default.removeItem(at: folder.appending(path: name)) }
        }
        sweepOrphanedMedia(launchedAt: launchedAt, media: media, support: support)
    }

    /// The edits' media nothing in `support` names (`orphanedMedia`), with their sidecars.
    static func sweepOrphanedMedia(launchedAt: Date, media: URL, support: URL) {
        let files = modified(in: media)
        guard !files.isEmpty else { return }
        // A saved file that can't be read now (the iPhone locked since it started, a damaged file) might name any of them.
        guard let saved = savedText(in: support, skipping: media) else { return }
        let orphans = orphanedMedia(files: files, launchedAt: launchedAt) { saved.contains($0) }
        for name in orphans {
            try? FileManager.default.removeItem(at: media.appending(path: name))
            for sidecar in sidecarExtensions {
                try? FileManager.default.removeItem(at: media.appending(path: name).appendingPathExtension(sidecar))
            }
        }
    }

    /// Every JSON file Cue keeps under `support` (outside `media`), as one text to look names up in; nil when one of them
    /// can't be read as text.
    static func savedText(in support: URL, skipping media: URL) -> String? {
        let skipped = media.standardizedFileURL.path(percentEncoded: false)
        var text = ""
        let files = FileManager.default.enumerator(at: support, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard !url.standardizedFileURL.path(percentEncoded: false).hasPrefix(skipped), url.pathExtension == "json" else { continue }
            guard let data = try? Data(contentsOf: url), let read = String(bytes: data, encoding: .utf8) else { return nil }
            text += read
        }
        return text
    }

    /// The files in `folder` and when each was last changed (also what `TakeRecovery` looks through).
    static func modified(in folder: URL) -> [String: Date] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: .skipsHiddenFiles
        )) ?? []
        var files: [String: Date] = [:]
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true, let date = values.contentModificationDate else { continue }
            files[url.lastPathComponent] = date
        }
        return files
    }
}
