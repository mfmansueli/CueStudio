//
//  BrandViewModel+Library.swift
//  Cue Studio
//

import Foundation
import PhotosUI
import SwiftUI

/// The media library in the editor: what Add photo or video shows, bringing files in (from Photos, from Files, from a video's
/// media), and putting them in the video: photos and videos the same way as from Photos (their part, where they go), a logo
/// straight in, small over the whole video.
extension BrandViewModel {
    /// What the library shows now; in the sequence, only videos (a clip is a video).
    func shownAssets(videosOnly: Bool) -> [LibraryAsset] {
        library.assets(in: libraryFilter, matching: librarySearch).filter { !videosOnly || $0.kind == .video }
    }

    /// The assets as picks for the video, each its own link to the file (in the order given); one that is missing is left
    /// out and said.
    func picks(of assets: [LibraryAsset]) -> [MediaPick] {
        var picks: [MediaPick] = []
        for asset in assets {
            do {
                let media = try library.media(for: asset)
                session.importedFiles.insert(media.fileName)
                picks.append(MediaPick(media))
            } catch {
                toast.show(String(localized: "\(asset.name) is missing · remove it from your library"), kind: .problem)
            }
        }
        return picks
    }

    /// A logo from the library on the video: small, in the top right corner, over the whole video (one undo step).
    func insertLogo(_ asset: LibraryAsset) {
        guard isReady else { return }
        do {
            let media = try library.media(for: asset)
            session.importedFiles.insert(media.fileName)
            change { snapshot in Self.placeLogo(media, corner: .topRight, width: BrandKitLogo.defaultWidth, in: &snapshot, edit: edit) }
            sayUndoable(String(localized: "\(asset.name) added over the whole video"))
        } catch {
            toast.show(String(localized: "\(asset.name) is missing · remove it from your library"), kind: .problem)
        }
    }

    /// Brings photos and videos picked in Photos into the library (not into the video).
    func addToLibrary(_ items: [PhotosPickerItem], as kind: LibraryAssetKind? = nil) async {
        guard !items.isEmpty, !isAddingToLibrary else { return }
        isAddingToLibrary = true
        defer { isAddingToLibrary = false }
        var added = 0
        var already = 0
        for item in items {
            do {
                let imported = try await importPicked(item)
                let file = EditMediaFiles.url(for: imported.fileName)
                // The library keeps its own link: the import's name goes.
                defer { EditMediaFiles.remove([imported.fileName]) }
                switch try await library.add(fileAt: file, kind: kind) {
                case .added: added += 1
                case .alreadyThere: already += 1
                }
            } catch is CancellationError {
                break
            } catch {
                noteFailure(error, "addToLibrary")
                toast.show(EditorErrorMessage.text(for: error, otherwise: String(localized: "Can't add this file")), kind: .problem)
            }
        }
        sayAdded(added, already: already)
    }

    /// Brings files picked in Files (a logo's PNG, a video) into the library: a picture is kept like a photo from Photos
    /// (upright, at most 2160 px, see-through ones as PNG), a video as it is.
    func addFilesToLibrary(_ urls: [URL], as kind: LibraryAssetKind? = nil) async {
        guard !urls.isEmpty, !isAddingToLibrary else { return }
        isAddingToLibrary = true
        defer { isAddingToLibrary = false }
        var added = 0
        var already = 0
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let kept = try await Task.detached { try Self.copyIn(url) }.value
                defer { EditMediaFiles.remove([kept]) }
                switch try await library.add(fileAt: EditMediaFiles.url(for: kept), name: url.deletingPathExtension().lastPathComponent, kind: kind) {
                case .added: added += 1
                case .alreadyThere: already += 1
                }
            } catch {
                noteFailure(error, "addFileToLibrary")
                toast.show(String(localized: "Can't add this file"), kind: .problem)
            }
        }
        sayAdded(added, already: already)
    }

    /// A photo or video of the video saved to the library (the same bytes, no copy).
    func saveMediaToLibrary(_ id: UUID) async {
        guard let media = edit.media.first(where: { $0.id == id }) else { return }
        do {
            let kind: LibraryAssetKind = media.isLogo == true ? .logo : (media.kind == .video ? .video : .photo)
            switch try await library.add(fileAt: EditMediaFiles.url(for: media.fileName), kind: kind) {
            case .added(let asset): toast.show(String(localized: "Saved to your library as \(asset.name)"))
            case .alreadyThere(let asset): toast.show(String(localized: "Already in your library as \(asset.name)"))
            }
        } catch {
            noteFailure(error, "saveToLibrary")
            toast.show(String(localized: "Can't add this file"), kind: .problem)
        }
    }

    /// Takes an asset out of the library, with Undo; videos that use it keep it.
    func removeFromLibrary(_ id: UUID) {
        guard let removed = library.remove(id) else { return }
        let uses = MediaLibraryFiles.linkCount(of: removed.fileName, in: library.directory) - 1
        let message = uses > 0
            ? String(localized: "\(removed.name) removed · videos that use it keep it")
            : String(localized: "\(removed.name) removed from your library")
        toast.show(message, action: ToastAction(title: String(localized: "Undo")) { [library] in library.restore(removed) })
    }

    // MARK: - Private

    private func sayAdded(_ added: Int, already: Int) {
        if added > 0 {
            toast.show(String(localized: "\(added) added to your library"))
        } else if already > 0 {
            toast.show(String(localized: "Already in your library"))
        }
    }

    /// A file from Files copied into the editor's media for a moment (the library links it, then the copy's name goes):
    /// a picture as `storePhoto` keeps one, a video as it is.
    nonisolated private static func copyIn(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        if let picture = try? EditMediaImporter.storePhoto(data) { return picture.fileName }
        let file = try EditMediaFiles.newFile(pathExtension: url.pathExtension)
        try FileManager.default.copyItem(at: url, to: file.url)
        return file.name
    }

    /// A logo laid over the whole video (the first logo's place if there is one: a second logo replaces its picture there).
    static func placeLogo(_ media: ImportedMedia, corner: BrandLogoCorner, width: Double, in snapshot: inout EditSnapshot, edit: TakeEdit) {
        if let index = snapshot.media.firstIndex(where: { $0.isLogo == true }) {
            snapshot.media[index].fileName = media.fileName
            snapshot.media[index].aspect = media.aspect
            return
        }
        var logo = MediaOverlay(kind: .photo, fileName: media.fileName, aspect: media.aspect, mediaDuration: nil, span: TimeSpan(start: 0, end: 1))
        logo.layout = .window
        logo.width = width
        logo.center = corner.center(width: width, aspect: media.aspect, videoAspect: edit.aspect.widthOverHeight)
        logo.isLogo = true
        logo.layer = (snapshot.media.compactMap(\.layer).max() ?? 0) + 1
        // Over the whole video as it is cut now, from its first second to its last.
        var laid = edit
        laid.media = snapshot.media + [logo]
        laid.layMedia(at: laid.media.count - 1, over: TimeSpan(start: 0, end: max(MediaOverlay.minimumDuration, edit.timeline.editedDuration)))
        snapshot.media = laid.media
    }
}
