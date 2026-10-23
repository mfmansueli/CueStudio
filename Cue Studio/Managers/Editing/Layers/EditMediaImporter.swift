//
//  EditMediaImporter.swift
//  Cue Studio
//

import AVFoundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Copies what the creator picks from the library into `EditMediaFiles`: videos as they are,
/// photos upright and no larger than 2160 px (plenty for a 4K frame), as JPEG. On the device only.
@MainActor
@Observable
final class EditMediaImporter: EditMediaImporting {
    /// Longest side of an imported photo.
    nonisolated private static let maxPhotoSide: CGFloat = 2160

    func importMedia(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedMedia {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isVideo {
            guard let movie = try await Self.load(PickedMovie.self, from: item, progress: progress) else { throw EditMediaImportError.unreadable }
            // Cancelled as the copy finished: the copy goes.
            guard !Task.isCancelled else {
                try? FileManager.default.removeItem(at: movie.url)
                throw CancellationError()
            }
            return try await Self.describeVideo(at: movie.url)
        }
        guard let data = try await Self.load(Data.self, from: item, progress: progress) else { throw EditMediaImportError.unreadable }
        return try await Task.detached { try Self.storePhoto(data) }.value
    }

    /// What `item` holds as `type`, telling how far the loading is (Photos downloads it from iCloud first when it isn't on the
    /// iPhone) and stopping when the task is cancelled.
    private static func load<Value: Transferable & Sendable>(
        _ type: Value.Type, from item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void
    ) async throws -> Value? {
        let loading = LoadingProgress()
        let value: Value?
        do {
            value = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Value?, Error>) in
                    let started = item.loadTransferable(type: type) { result in continuation.resume(with: result) }
                    loading.watch(started, report: progress)
                }
            } onCancel: {
                loading.cancel()
            }
        } catch {
            // A loading stopped by Cancel ends with the system's own error.
            if Task.isCancelled { throw CancellationError() }
            throw error
        }
        try Task.checkCancellation()
        return value
    }

    /// The copied video's shape and length. One that can't be read leaves no copy behind: nothing names it, so nothing
    /// would ever remove it.
    static func describeVideo(at url: URL) async throws -> ImportedMedia {
        do {
            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw EditMediaImportError.unreadable }
            let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
            let duration = try await asset.load(.duration).seconds
            let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
            let aspect = abs(upright.height) > 0 ? abs(upright.width) / abs(upright.height) : 1
            guard duration.isFinite, duration > 0 else { throw EditMediaImportError.unreadable }
            let hasSound = (try? await asset.loadTracks(withMediaType: .audio).isEmpty == false) ?? false
            return ImportedMedia(kind: .video, fileName: url.lastPathComponent, aspect: Double(aspect), duration: duration, hasSound: hasSound)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func importAudio(from url: URL) async throws -> ImportedAudio {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
        do {
            try FileManager.default.copyItem(at: url, to: file.url)
            let asset = AVURLAsset(url: file.url)
            // A protected song has no track AVFoundation can read.
            guard try await !asset.loadTracks(withMediaType: .audio).isEmpty else { throw EditMediaImportError.unreadableSound }
            let duration = try await asset.load(.duration).seconds
            guard duration.isFinite, duration >= MusicClip.minimumDuration else { throw EditMediaImportError.unreadableSound }
            return ImportedAudio(fileName: file.name, title: url.deletingPathExtension().lastPathComponent, duration: duration)
        } catch {
            try? FileManager.default.removeItem(at: file.url)
            throw EditMediaImportError.unreadableSound
        }
    }

    /// The photo upright, its longest side at most `maxPhotoSide`, read straight from the file at that size (`CGImageSource`):
    /// a 48 MP photo is never decoded whole (about 190 MB) just to be made smaller.
    nonisolated static func storePhoto(_ data: Data) throws -> ImportedMedia {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Upright, whatever the camera wrote in its metadata.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPhotoSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              image.width > 0, image.height > 0,
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else { throw EditMediaImportError.unreadable }
        let file = try EditMediaFiles.newFile(pathExtension: "jpg")
        try jpeg.write(to: file.url, options: .atomic)
        return ImportedMedia(kind: .photo, fileName: file.name, aspect: Double(image.width) / Double(image.height), duration: nil)
    }
}
