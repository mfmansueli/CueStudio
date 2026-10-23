//
//  LocalTakeRepository.swift
//  Cue Studio
//

import Foundation
import os

/// Keeps take videos in Application Support/Takes and their metadata in a JSON file next to them.
struct LocalTakeRepository: TakeRepository {
    private let directory: URL
    private var metadataURL: URL { directory.appending(path: "takes.json") }
    private static let logger = Logger(subsystem: "studio.cue", category: "TakeLibrary")

    /// Application Support/Takes.
    nonisolated static var defaultDirectory: URL { URL.applicationSupportDirectory.appending(path: "Takes", directoryHint: .isDirectory) }

    init(directory: URL = Self.defaultDirectory) {
        self.directory = directory
    }

    func loadTakes() throws -> [Take] {
        // Unencoded: `path()` gives "Application%20Support", which FileManager never finds.
        guard FileManager.default.fileExists(atPath: metadataURL.path(percentEncoded: false)) else { return [] }
        let data = try Data(contentsOf: metadataURL)
        // Take by take: one that can't be read stays out, never the whole library, and inside a take, a part that can't be
        // read (an edit, a text, a filter a newer version added) stays out or reads as a stand-in. The file as it was is
        // kept aside first, since the next save writes the library without what was left out.
        let report = DecodingReport()
        guard let list = try? JSONDecoder.library.reporting(to: report).decode(LossyList<Take>.self, from: data) else {
            // Read, but no longer a list of takes: kept aside, and a new list starts, rather than one never saved again.
            Self.logger.error("takes.json isn't a list of takes: kept aside, a new library starts")
            keepCopy(of: data)
            return []
        }
        let notes = report.notes
        if list.dropped > 0 || !notes.isEmpty {
            Self.logger.error("takes.json read with \(notes.count) parts left out or read as a stand-in: \(notes.joined(separator: "; "), privacy: .public)")
            keepCopy(of: data)
        }
        return list.elements
    }

    /// The whole folder: videos, `takes.json`, the analyses next to the videos and the copies `keepCopy` set aside.
    func deleteEverything() {
        try? FileManager.default.removeItem(at: directory)
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

    func returnVideo(named fileName: String, to temporaryURL: URL) throws {
        try FileManager.default.moveItem(at: videoURL(named: fileName), to: temporaryURL)
    }

    func deleteVideo(named fileName: String) throws {
        let url = videoURL(named: fileName)
        // Its motion analysis goes with it.
        MotionAnalysisStore.remove(forRecording: url)
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
