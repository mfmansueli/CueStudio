//
//  TakeRepository.swift
//  Cue Studio
//

import Foundation

/// Where takes (metadata and video files) are stored.
protocol TakeRepository {
    func loadTakes() throws -> [Take]
    func saveTakes(_ takes: [Take]) throws
    /// Moves a finished recording into storage and returns the stored file name.
    func storeVideo(from temporaryURL: URL) throws -> String
    /// Puts a stored recording back where `storeVideo` took it from, when the library couldn't record it.
    func returnVideo(named fileName: String, to temporaryURL: URL) throws
    func deleteVideo(named fileName: String) throws
    func videoURL(named fileName: String) -> URL
    /// "Delete my Cue data": every video, the metadata, the analyses next to the videos and the copies of a damaged library,
    /// including what no take points to any more.
    func deleteEverything()
}

extension TakeRepository {
    func returnVideo(named fileName: String, to temporaryURL: URL) throws {}
    func deleteEverything() {}
}
