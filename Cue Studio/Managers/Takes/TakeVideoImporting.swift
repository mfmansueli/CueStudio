//
//  TakeVideoImporting.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// Copies a video picked in Photos to a file of its own, to become a take to edit (`TakeLibraryService.importVideo`).
@MainActor
protocol TakeVideoImporting {
    /// The video copied, with its length, upright size and frame rate. Throws `CancellationError` when stopped, and when the file
    /// can't be read (nothing left behind then).
    func importVideo(_ item: PhotosPickerItem, progress: @escaping @MainActor (Double) -> Void) async throws -> ImportedTakeVideo
}
