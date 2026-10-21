//
//  LocalTakeRepository.swift
//  Cue Studio
//

import Foundation

/// Keeps take videos in Application Support/Takes and their metadata in a JSON file next to them.
struct LocalTakeRepository: TakeRepository {
    private let directory: URL
    private var metadataURL: URL { directory.appending(path: "takes.json") }

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Takes", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func loadTakes() throws -> [Take] {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: metadataURL.path(percentEncoded: false)) else { return [] }
        let data = try Data(contentsOf: metadataURL)
        // Take by take: one that can't be read stays out, never the whole library; the file as it was is kept aside first,
        // since the next save writes the library without it.
        let list = try JSONDecoder.library.decode(LossyList<Take>.self, from: data)
        if list.dropped > 0 { keepCopy(of: data) }
        return list.elements
    }

    /// `takes.json` as it was, next to it (`takes-kept-<date>.json`), once per damaged file.
    private func keepCopy(of data: Data) {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let copy = directory.appending(path: "takes-kept-\(stamp).json")
        try? data.write(to: copy, options: .atomic)
    }

    func saveTakes(_ takes: [Take]) throws {
        try ensureDirectory()
        let data = try JSONEncoder.library.encode(takes)
        try data.write(to: metadataURL, options: .atomic)
    }

    func storeVideo(from temporaryURL: URL) throws -> String {
        try ensureDirectory()
        let ext = temporaryURL.pathExtension.isEmpty ? "mov" : temporaryURL.pathExtension
        let fileName = UUID().uuidString + "." + ext
        try FileManager.default.moveItem(at: temporaryURL, to: videoURL(named: fileName))
        return fileName
    }

    func deleteVideo(named fileName: String) throws {
        let url = videoURL(named: fileName)
        // Its motion and eye analyses go with it.
        MotionAnalysisStore.remove(forRecording: url)
        EyeContactAnalysisStore.remove(forRecording: url)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func videoURL(named fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
