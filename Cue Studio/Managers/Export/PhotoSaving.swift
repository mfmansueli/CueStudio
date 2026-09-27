//
//  PhotoSaving.swift
//  Cue Studio
//

import Foundation

protocol PhotoSaving: AnyObject {
    func saveVideo(at url: URL) async throws
}
