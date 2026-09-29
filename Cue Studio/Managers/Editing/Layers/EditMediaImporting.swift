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
    /// Copies the picked photo or video into `EditMediaFiles`. Throws when it can't be read.
    func importMedia(_ item: PhotosPickerItem) async throws -> ImportedMedia
}
