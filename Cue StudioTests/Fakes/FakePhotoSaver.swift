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
    /// What Photos says the new asset is called; nil when it gives no identifier.
    var givesIdentifiers = true

    func saveVideo(at url: URL) async throws -> String? {
        if let error { throw error }
        savedURLs.append(url)
        return givesIdentifiers ? "asset-\(savedURLs.count)" : nil
    }

    func saveImage(at url: URL) async throws {
        if let error { throw error }
        savedImages.append(url)
    }
}
