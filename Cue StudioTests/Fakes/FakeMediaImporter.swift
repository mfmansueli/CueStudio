//
//  FakeMediaImporter.swift
//  Cue StudioTests
//

import Foundation
import PhotosUI
import SwiftUI
@testable import Cue_Studio

/// Hands back `media` for any pick (tests call `addMedia` directly; this only stands in).
@MainActor
final class FakeMediaImporter: EditMediaImporting {
    var media = ImportedMedia(kind: .photo, fileName: "photo.jpg", aspect: 1, duration: nil)

    func importMedia(_ item: PhotosPickerItem) async throws -> ImportedMedia {
        media
    }
}
