//
//  PhotoSaving.swift
//  Cue Studio
//

import Foundation

protocol PhotoSaving: AnyObject {
    func saveVideo(at url: URL) async throws
    /// Saves an image file (a cover) to the library.
    func saveImage(at url: URL) async throws
}
