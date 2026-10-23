//
//  EditMediaImporting.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// Brings photos and videos from the library into Quick edit. Screens depend on this protocol so
/// tests can use a fake.
protocol EditMediaImporting: AnyObject {
    /// Copies the picked photo or video into `EditMediaFiles`, telling how far it got (0 to 1: a video still in iCloud is
    /// downloaded first). Throws when it can't be read, and `CancellationError` when the task is cancelled.
    func importMedia(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedMedia
    /// Copies a sound file picked in Files into `EditMediaFiles`. Throws when it can't be read or
    /// has no sound (a protected song, for one).
    func importAudio(from url: URL) async throws -> ImportedAudio
}

extension EditMediaImporting {
    /// Copies the picked photo or video in, without saying how far it got.
    func importMedia(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        try await importMedia(item) { _ in }
    }
}
