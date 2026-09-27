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
    func deleteVideo(named fileName: String) throws
    func videoURL(named fileName: String) -> URL
}
