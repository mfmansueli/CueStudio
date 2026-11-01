//
//  FakePhotoSaver.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakePhotoSaver: PhotoSaving {
    private(set) var savedURLs: [URL] = []
    private(set) var savedImages: [URL] = []
    var error: Error?
    /// Only images (a cover) fail with it; videos still save.
    var imageError: Error?
    /// What Photos says the new asset is called; nil when it gives no identifier.
    var givesIdentifiers = true
    /// Runs as the video is handed to Photos (a save under way).
    var whileSaving: (@MainActor () -> Void)?

    func saveVideo(at url: URL) async throws -> String? {
        whileSaving?()
        if let error { throw error }
        savedURLs.append(url)
        return givesIdentifiers ? "asset-\(savedURLs.count)" : nil
    }

    func saveImage(at url: URL) async throws {
        if let error = error ?? imageError { throw error }
        savedImages.append(url)
    }
}
