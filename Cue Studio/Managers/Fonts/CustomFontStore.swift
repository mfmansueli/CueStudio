//
//  CustomFontStore.swift
//  Cue Studio
//

import Foundation
import os
import UIKit

/// The creator's imported font families: read at launch, their files registered with Core Text for Cue and handed to the
/// renderers (`CustomFontRegistry`). Importing copies each picked file in only once it reads as a whole font; a family that
/// grows a style (Bold after Regular) keeps its name. Removing takes a family out of the pickers but keeps its files: the
/// videos, saved styles and brand kits that use it keep drawing in it until nothing names it (`CustomFontCleaner`). Fonts
/// are never shared with other apps and never leave this iPhone; the creator vouches for the right to use them.
@MainActor
@Observable
final class CustomFontStore {
    private(set) var families: [CustomFontFamily] = []
    /// The families this launch can draw (their files here and registered), as the renderers have them: a picker's "isn't on
    /// this iPhone" note follows it.
    private(set) var drawable: Set<String> = []

    @ObservationIgnored private let repository: CustomFontRepository
    @ObservationIgnored let directory: URL
    @ObservationIgnored private let registry: CustomFontRegistry
    @ObservationIgnored private let logger = Logger(subsystem: "studio.cue", category: "Fonts")
    /// False when the families on disk couldn't be read: writing would replace them with what's in memory.
    @ObservationIgnored private var canSave = true

    init(repository: CustomFontRepository = LocalCustomFontRepository(), directory: URL = CustomFontFiles.directory, registry: CustomFontRegistry = .shared) {
        self.repository = repository
        self.directory = directory
        self.registry = registry
    }

    /// The families offered in the pickers, newest first.
    var offered: [CustomFontFamily] {
        families.filter { !$0.isRemoved }.sorted { $0.importedAt > $1.importedAt }
    }

    /// Reads the families and registers their files; a face whose file is gone or won't register is left out of this launch.
    func load() {
        do {
            families = try repository.load()
            canSave = true
        } catch {
            canSave = false
            logger.error("Could not load fonts: \(error.localizedDescription)")
        }
        publish(registering: true)
    }

    /// The families couldn't be read at launch: read them again now (and register them), keeping the ones imported since.
    func reloadIfUnread() {
        guard mergeUnread() else { return }
        publish(registering: true)
        persist()
    }

    /// The families on disk, read now if they couldn't be before, with the ones imported since; whether they were read.
    private func mergeUnread() -> Bool {
        guard !canSave, let saved = try? repository.load() else { return false }
        let made = Set(families.map(\.name))
        families += saved.filter { !made.contains($0.name) }
        canSave = true
        return true
    }

    struct ImportOutcome: Equatable {
        /// The families that came in or grew, by name.
        var added: [String] = []
        /// Families whose files had gone (the families stayed), back from the files picked.
        var repaired: [String] = []
        /// Files that were already here.
        var alreadyHere: [String] = []
        /// What went wrong with a file, by its name.
        var problems: [String: CustomFontInspector.Problem] = [:]

        var message: String {
            if let name = added.first {
                return added.count == 1
                    ? String(localized: "\(name) added · use it in Text, Captions and Cover")
                    : String(localized: "\(added.count) fonts added · use them in Text, Captions and Cover")
            }
            if let name = repaired.first { return String(localized: "\(name) is back · videos that use it show it again") }
            if let name = alreadyHere.first { return String(localized: "\(name) is already in your fonts") }
            return problems.values.first?.message ?? String(localized: "This file isn’t a font Cue can use · TTF or OTF")
        }
    }

    /// Imports font files picked in Files: each is read whole, checked (`CustomFontInspector`), copied in and registered.
    /// A file that fails leaves nothing behind.
    func importFonts(from urls: [URL]) async -> ImportOutcome {
        var outcome = ImportOutcome()
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let label = url.deletingPathExtension().lastPathComponent
            guard let data = try? await Task.detached(operation: { try Data(contentsOf: url, options: .mappedIfSafe) }).value else {
                outcome.problems[label] = .notAFont
                continue
            }
            let known = Set(families.flatMap(\.faces).map(\.postScriptName))
            let inspected: [CustomFontInspector.Face]
            do {
                inspected = try CustomFontInspector.inspect(data) { name in
                    known.contains(name) || UIFont(name: name, size: 12) != nil
                }
            } catch {
                // The same file again: already one of the creator's families.
                if case .alreadyInstalled = error, let faces = faceNames(in: data),
                   let index = families.firstIndex(where: { $0.faces.contains { faces.contains($0.postScriptName) } }) {
                    let repaired = repairFiles(of: families[index], from: data, faces: faces)
                    if families[index].isRemoved {
                        // Removed, and still on this iPhone for the videos that use it: back in the pickers.
                        families[index].isRemoved = false
                        families[index].importedAt = .now
                        outcome.added.append(families[index].name)
                    } else if repaired {
                        families[index].importedAt = .now
                        outcome.repaired.append(families[index].name)
                    } else {
                        outcome.alreadyHere.append(families[index].name)
                    }
                } else {
                    outcome.problems[label] = error
                }
                continue
            }
            guard let added = keep(data, faces: inspected, extension: url.pathExtension) else {
                outcome.problems[label] = .damaged
                continue
            }
            if !outcome.added.contains(added) { outcome.added.append(added) }
        }
        if !outcome.added.isEmpty || !outcome.repaired.isEmpty {
            persist()
            publish(registering: false)
        }
        return outcome
    }

    /// Takes the family out of the pickers; videos using it keep drawing in it. Returns what `restore` puts back.
    @discardableResult
    func remove(_ name: String) -> CustomFontFamily? {
        guard let index = families.firstIndex(where: { $0.name == name }) else { return nil }
        let before = families[index]
        families[index].isRemoved = true
        persist()
        publish(registering: false)
        return before
    }

    /// Undo of `remove`.
    func restore(_ family: CustomFontFamily) {
        guard let index = families.firstIndex(where: { $0.name == family.name }) else { return }
        families[index].isRemoved = false
        persist()
        publish(registering: false)
    }

    /// The files of removed families nothing names any more (no video, draft, undo step, saved style or kit), unregistered
    /// and deleted, and the families forgotten (`LibraryFileSweep`). Nothing goes when something saved can't be read now.
    func sweepRemoved(defaults: UserDefaults) async {
        let removed = families.filter(\.isRemoved).map(\.name)
        guard !removed.isEmpty else { return }
        let directory = directory
        let styles = LibraryFileSweep.savedStyles(in: defaults)
        let unused = await Task.detached(priority: .background) { () -> Set<String> in
            guard let saved = LibraryFileSweep.savedText(fonts: directory, styles: styles) else { return [] }
            return LibraryFileSweep.unusedFonts(removed, saved: saved)
        }.value
        forget(unused)
    }

    /// Deletes the families' files and forgets them.
    func forget(_ names: Set<String>) {
        // A family restored or imported again while the sweep looked stays.
        let names = names.filter { name in families.contains { $0.name == name && $0.isRemoved } }
        guard !names.isEmpty else { return }
        for family in families where names.contains(family.name) {
            for fileName in Set(family.faces.map(\.fileName)) {
                let url = CustomFontFiles.url(for: fileName, in: directory)
                CustomFontFiles.unregister(url)
                try? FileManager.default.removeItem(at: url)
            }
        }
        families.removeAll { names.contains($0.name) }
        persist()
        publish(registering: false)
    }

    /// "Delete my Cue data".
    func eraseAll() {
        families = []
        CustomFontFiles.removeAll(in: directory)
        canSave = true
        publish(registering: false)
    }

    // MARK: - Private

    /// The file copied in and registered, its faces added to their family (made, or grown); the family's name, or nil when
    /// the copy or the registration failed (and the copy is gone).
    private func keep(_ data: Data, faces: [CustomFontInspector.Face], extension pathExtension: String) -> String? {
        let ext = ["ttf", "otf", "ttc", "otc"].contains(pathExtension.lowercased()) ? pathExtension.lowercased() : "ttf"
        let fileName = UUID().uuidString + "." + ext
        let url = CustomFontFiles.url(for: fileName, in: directory)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        guard CustomFontFiles.register(url) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        guard let familyName = faces.first?.familyName else { return nil }
        let kept = faces.map { face in
            CustomFontFace(
                fileName: fileName, postScriptName: face.postScriptName, styleName: face.styleName, weight: face.weight,
                isItalic: face.isItalic, weightRange: face.weightRange
            )
        }
        if let index = families.firstIndex(where: { $0.name == familyName }) {
            families[index].faces += kept
            families[index].isRemoved = false
            families[index].importedAt = .now
        } else {
            families.append(CustomFontFamily(name: familyName, faces: kept, importedAt: .now))
        }
        publish(registering: false)
        return familyName
    }

    /// The PostScript names of the faces in `data`, to recognise a file imported before.
    private func faceNames(in data: Data) -> Set<String>? {
        (try? CustomFontInspector.inspect(data) { _ in false }).map { Set($0.map(\.postScriptName)) }
    }

    /// The files of `family`'s faces in `data` that are gone from this iPhone (the family stayed in fonts.json), written again
    /// from `data` under the names the family keeps and registered, so the videos that use it draw in it again; whether any
    /// came back.
    private func repairFiles(of family: CustomFontFamily, from data: Data, faces: Set<String>) -> Bool {
        let gone = Set(family.faces.filter { faces.contains($0.postScriptName) }.map(\.fileName)).filter { fileName in
            !FileManager.default.fileExists(atPath: CustomFontFiles.url(for: fileName, in: directory).path(percentEncoded: false))
        }
        var repaired = false
        for fileName in gone {
            let url = CustomFontFiles.url(for: fileName, in: directory)
            // Gone while this launch had it registered: registered again from the file now there.
            CustomFontFiles.unregister(url)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try data.write(to: url, options: .atomic)
            } catch {
                continue
            }
            guard CustomFontFiles.register(url) else {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            repaired = true
        }
        if repaired { publish(registering: false) }
        return repaired
    }

    /// Hands the families whose files are here to the renderers; on launch, registers them first.
    private func publish(registering: Bool) {
        var ready: [CustomFontFamily] = []
        for family in families {
            var family = family
            family.faces = family.faces.filter { face in
                let url = CustomFontFiles.url(for: face.fileName, in: directory)
                guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return false }
                return !registering || CustomFontFiles.register(url) || UIFont(name: face.postScriptName, size: 12) != nil
            }
            if !family.faces.isEmpty { ready.append(family) }
        }
        registry.update(ready)
        let names = Set(ready.map(\.name))
        if names != drawable { drawable = names }
    }

    private func persist() {
        if mergeUnread() { publish(registering: true) }
        guard canSave else {
            logger.error("Not saving fonts: the ones on disk still can't be read")
            return
        }
        do {
            try repository.save(families)
        } catch {
            logger.error("Could not save fonts: \(error.localizedDescription)")
        }
    }
}
