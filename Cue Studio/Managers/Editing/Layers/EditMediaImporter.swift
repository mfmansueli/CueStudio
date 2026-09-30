//
//  EditMediaImporter.swift
//  Cue Studio
//

import AVFoundation
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

    func importMedia(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if isVideo {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw EditMediaImportError.unreadable }
            return try await Self.describeVideo(at: movie.url)
        }
        guard let data = try await item.loadTransferable(type: Data.self) else { throw EditMediaImportError.unreadable }
        return try await Task.detached { try Self.storePhoto(data) }.value
    }

    private static func describeVideo(at url: URL) async throws -> ImportedMedia {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            try? FileManager.default.removeItem(at: url)
            throw EditMediaImportError.unreadable
        }
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let duration = try await asset.load(.duration).seconds
        let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let aspect = abs(upright.height) > 0 ? abs(upright.width) / abs(upright.height) : 1
        guard duration.isFinite, duration > 0 else { throw EditMediaImportError.unreadable }
        let hasSound = (try? await asset.loadTracks(withMediaType: .audio).isEmpty == false) ?? false
        return ImportedMedia(kind: .video, fileName: url.lastPathComponent, aspect: Double(aspect), duration: duration, hasSound: hasSound)
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

    nonisolated private static func storePhoto(_ data: Data) throws -> ImportedMedia {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { throw EditMediaImportError.unreadable }
        let scale = min(1, maxPhotoSide / max(image.size.width, image.size.height))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // Drawing turns it upright, whatever the camera wrote in its metadata.
        let upright = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = upright.jpegData(compressionQuality: 0.9) else { throw EditMediaImportError.unreadable }
        let file = try EditMediaFiles.newFile(pathExtension: "jpg")
        try jpeg.write(to: file.url, options: .atomic)
        return ImportedMedia(kind: .photo, fileName: file.name, aspect: Double(size.width / size.height), duration: nil)
    }
}
