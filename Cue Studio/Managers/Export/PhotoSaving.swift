//
//  PhotoSaving.swift
//  Cue Studio
//

import Foundation

protocol PhotoSaving: AnyObject {
    /// Saves the video and returns its identifier in the library: the proof the save happened, and what TikTok's Share Kit
    /// asks for. Throws `PhotoLibraryError.notAuthorized` when Photos refuses, and nothing is saved.
    @discardableResult
    func saveVideo(at url: URL) async throws -> String?
    /// Saves an image file (a cover) to the library.
    func saveImage(at url: URL) async throws
}
