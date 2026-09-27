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
        guard FileManager.default.fileExists(atPath: metadataURL.path()) else { return [] }
        let data = try Data(contentsOf: metadataURL)
        return try JSONDecoder.library.decode([Take].self, from: data)
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
        guard FileManager.default.fileExists(atPath: url.path()) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func videoURL(named fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
