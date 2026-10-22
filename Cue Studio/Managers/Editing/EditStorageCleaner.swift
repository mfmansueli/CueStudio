//
//  EditStorageCleaner.swift
//  Cue Studio
//

import Foundation

/// Gives the iPhone's space back once a launch, in the background: the sound files a past session made (`RecordingSoundCache`
/// lives in memory, so after a relaunch nothing holds them). Only files of that cache, by their makers' prefixes, made before
/// this launch: never a take's recording, the edit's media (`EditMediaFiles`, which edits name and only an edit removes) or
/// an exported video (`ExportLedgerService`). Next to the recordings, the analyses of a tool Cue no longer has go too.
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

    /// Removes them, off the main actor.
    @concurrent
    static func clean(launchedAt: Date, recordingFolders: [URL] = [LocalTakeRepository.defaultDirectory, EditMediaFiles.directory]) async {
        let temporary = URL.temporaryDirectory
        for name in staleSounds(files: modified(in: temporary), launchedAt: launchedAt) {
            try? FileManager.default.removeItem(at: temporary.appending(path: name))
        }
        for folder in recordingFolders {
            for name in retired(modified(in: folder).keys) { try? FileManager.default.removeItem(at: folder.appending(path: name)) }
        }
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
