//
//  FakeMediaImporter.swift
//  Cue StudioTests
//

import Foundation
import PhotosUI
import SwiftUI
@testable import Cue_Studio

/// Hands back `media` for any pick (tests call `addMedia` directly; this only stands in), and
/// `audio` for any sound file.
@MainActor
final class FakeMediaImporter: EditMediaImporting {
    var media = ImportedMedia(kind: .photo, fileName: "photo.jpg", aspect: 1, duration: nil)
    /// How far it says it got before handing `media` back.
    var progressSteps: [Double] = []
    /// Waits (like a video coming from iCloud) until the import is cancelled, then throws `CancellationError`.
    var waitsUntilCancelled = false

    func importMedia(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedMedia {
        for step in progressSteps { progress(step) }
        if waitsUntilCancelled {
            while !Task.isCancelled { try? await Task.sleep(for: .milliseconds(5)) }
            throw CancellationError()
        }
        return media
    }

    /// What `importAudio` hands back; nil throws, like a file that can't be read.
    var audio: ImportedAudio? = ImportedAudio(fileName: "song.m4a", title: "Morning song", duration: 95)
    private(set) var importedAudio: [URL] = []

    func importAudio(from url: URL) async throws -> ImportedAudio {
        importedAudio.append(url)
        guard let audio else { throw EditMediaImportError.unreadableSound }
        return audio
    }
}
