//
//  PickedMovie.swift
//  Cue Studio
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// A video picked in the library, copied straight into `EditMediaFiles` (the picker's own copy is
/// temporary).
nonisolated struct PickedMovie: Transferable, Sendable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let destination = try EditMediaFiles.newFile(pathExtension: ext)
            try FileManager.default.copyItem(at: received.file, to: destination.url)
            return PickedMovie(url: destination.url)
        }
    }
}
