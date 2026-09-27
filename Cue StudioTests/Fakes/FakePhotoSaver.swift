//
//  FakePhotoSaver.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakePhotoSaver: PhotoSaving {
    private(set) var savedURLs: [URL] = []
    var error: Error?

    func saveVideo(at url: URL) async throws {
        if let error { throw error }
        savedURLs.append(url)
    }
}
