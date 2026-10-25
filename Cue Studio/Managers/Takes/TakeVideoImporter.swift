//
//  TakeVideoImporter.swift
//  Cue Studio
//

import AVFoundation
import PhotosUI
import SwiftUI

/// `TakeVideoImporting` with the photo library: the video copied out of it (from iCloud first when it isn't on the iPhone),
/// then read for its length, shape and frame rate. One that can't be read leaves no copy behind.
@MainActor
struct TakeVideoImporter: TakeVideoImporting {
    func importVideo(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedTakeVideo {
        guard let movie = try await EditMediaImporter.load(PickedMovie.self, from: item, progress: progress) else {
            throw EditMediaImportError.unreadable
        }
        guard !Task.isCancelled else {
            try? FileManager.default.removeItem(at: movie.url)
            throw CancellationError()
        }
        do {
            let asset = AVURLAsset(url: movie.url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw EditMediaImportError.unreadable }
            let (naturalSize, transform, frameRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration > 0 else { throw EditMediaImportError.unreadable }
            let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
            return ImportedTakeVideo(
                url: movie.url, duration: duration, uprightSize: CGSize(width: abs(upright.width), height: abs(upright.height)),
                frameRate: Double(frameRate)
            )
        } catch {
            try? FileManager.default.removeItem(at: movie.url)
            throw error
        }
    }
}
