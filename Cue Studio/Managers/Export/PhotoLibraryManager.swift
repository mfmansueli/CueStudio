//
//  PhotoLibraryManager.swift
//  Cue Studio
//

import os
import Photos

/// Saves exported takes to the photo library (add-only access).
@MainActor
@Observable
final class PhotoLibraryManager: PhotoSaving {
    func saveVideo(at url: URL) async throws -> String? {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoLibraryError.notAuthorized }
        // Photos runs the change block on its own queue. The new asset's identifier is known inside it (a placeholder), and
        // reading it needs no more than add-only access.
        let identifier = OSAllocatedUnfairLock<String?>(initialState: nil)
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: url, options: nil)
            let placeholder = request.placeholderForCreatedAsset?.localIdentifier
            identifier.withLock { $0 = placeholder }
        }
        return identifier.withLock { $0 }
    }

    func saveImage(at url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoLibraryError.notAuthorized }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
        }
    }
}
