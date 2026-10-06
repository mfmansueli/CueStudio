//
//  UniverseShareViewModel.swift
//  Cue Studio
//

import Foundation
import UIKit

/// The sheet "Share my {year} universe" (9.2): what the card is made as, and the two ways out: **Save to Photos** and **Share…** (the system share
/// sheet). The image is made at once; the 6 s video is made when a button needs it, and kept until an option changes.
@MainActor
@Observable
final class UniverseShareViewModel {
    enum Phase: Equatable {
        case idle
        /// Making the video: how far it is.
        case rendering(Double)
        case saved
        case failed
    }

    let snapshot: UniverseSnapshot
    let handle: String
    let coreColor: CoreColor
    var options = UniverseShareOptions() {
        didSet { if options != oldValue { cachedFile = nil; phase = .idle } }
    }
    private(set) var phase: Phase = .idle
    /// The file to hand to the share sheet once it is made.
    var sharedFile: UniverseSharedFile?

    @ObservationIgnored private let photos: PhotoSaving
    @ObservationIgnored private var cachedFile: URL?

    init(snapshot: UniverseSnapshot, handle: String, coreColor: CoreColor, photos: PhotoSaving) {
        self.snapshot = snapshot
        self.handle = handle
        self.coreColor = coreColor
        self.photos = photos
    }

    func card(at time: TimeInterval? = nil) -> UniverseShareCard {
        UniverseShareCard(snapshot: snapshot, handle: handle, options: options, coreColor: coreColor, time: time)
    }

    var isRendering: Bool { if case .rendering = phase { true } else { false } }

    /// The file for the chosen kind, made now or reused.
    private func file() async throws -> URL {
        if let cachedFile { return cachedFile }
        let url: URL
        switch options.kind {
        case .image:
            url = try UniverseMediaRenderer.png(of: card())
        case .video:
            phase = .rendering(0)
            url = try await UniverseMediaRenderer.video(card: { self.card(at: $0) }, progress: { self.phase = .rendering($0) })
        }
        cachedFile = url
        return url
    }

    func save() async {
        do {
            let url = try await file()
            switch options.kind {
            case .image: try await photos.saveImage(at: url)
            case .video: _ = try await photos.saveVideo(at: url)
            }
            phase = .saved
        } catch {
            phase = .failed
        }
    }

    func share() async {
        do {
            let url = try await file()
            phase = .idle
            sharedFile = UniverseSharedFile(url: url)
        } catch {
            phase = .failed
        }
    }
}
