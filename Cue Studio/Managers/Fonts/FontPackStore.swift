//
//  FontPackStore.swift
//  Cue Studio
//

import Foundation
import os
import UIKit

/// The script libraries' files on this iPhone: downloaded one weight at a time, only when a video needs one (the creator picks
/// a library family, or a caption style or a text lands on words in that script: `FontPackNeeds`), checked against the
/// manifest's SHA-256, kept in Application Support out of the backup, registered with Core Text for Cue alone and handed to the
/// renderers (`FontPackRegistry`). Files kept from before are registered again at launch; nothing downloads at launch, and
/// nothing for a script the creator doesn't write in. Until a file is here, its words draw in the system's face of the script
/// (`ScriptFontCascade`), never as empty boxes.
@MainActor
@Observable
final class FontPackStore {
    enum State: Equatable, Sendable {
        case absent
        /// 0…1.
        case downloading(Double)
        case ready
        /// The download or its check failed: picking the family again tries again.
        case failed
    }

    /// A file's state, by "pack/file" (`FontPackRegistry.key`); a file not here is absent.
    private(set) var states: [String: State] = [:]
    /// Counts up when a file arrives or goes: the editor draws again.
    private(set) var generation = 0

    @ObservationIgnored let manifest: FontPackManifest
    @ObservationIgnored private let source: FontPackSource
    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let registry: FontPackRegistry
    @ObservationIgnored private var tasks: [String: Task<Bool, Never>] = [:]
    @ObservationIgnored private let logger = Logger(subsystem: "studio.cue", category: "Fonts")

    init(
        manifest: FontPackManifest = .bundled, source: FontPackSource = GoogleFontsPackSource(), directory: URL = FontPackFiles.directory,
        registry: FontPackRegistry = .shared
    ) {
        self.manifest = manifest
        self.source = source
        self.directory = directory
        self.registry = registry
    }

    // MARK: - Reading

    func state(of pack: FontPack, weight: TextOverlayWeight) -> State {
        states[FontPackRegistry.key(pack, pack.file(for: weight))] ?? .absent
    }

    /// The state a picker's chip shows for a family: downloading or failed while a weight is, ready when the one in use is here.
    func state(of pack: FontPack) -> State {
        let all = pack.files.map { states[FontPackRegistry.key(pack, $0)] ?? .absent }
        if let downloading = all.compactMap({ if case .downloading(let value) = $0 { value } else { nil } }).min() {
            return .downloading(downloading)
        }
        if all.contains(.ready) { return .ready }
        return all.contains(.failed) ? .failed : .absent
    }

    /// The families with at least one file on this iPhone, and what their files take.
    var downloaded: [(pack: FontPack, bytes: Int)] {
        manifest.packs.compactMap { pack in
            let bytes = pack.files.filter { states[FontPackRegistry.key(pack, $0)] == .ready }.reduce(0) { $0 + $1.bytes }
            return bytes > 0 ? (pack, bytes) : nil
        }
    }

    // MARK: - Launch

    /// Registers the files kept from before; downloads nothing.
    func load() {
        for pack in manifest.packs {
            for file in pack.files {
                let url = FontPackFiles.url(of: pack, file, in: directory)
                guard FontPackFiles.exists(url), FontPackFiles.register(url, postScriptName: file.postScriptName) else { continue }
                registry.add(pack, file, postScriptName: file.postScriptName)
                states[FontPackRegistry.key(pack, file)] = .ready
            }
        }
        generation += 1
    }

    // MARK: - Downloading

    /// Downloads what `needs` names that isn't here yet (each file once, however many ask).
    func request(_ needs: Set<FontPackNeed>) {
        for need in needs {
            guard let pack = manifest.pack(need.packID) else { continue }
            request(pack, weight: need.weight)
        }
    }

    /// Downloads `pack`'s file for `weight` unless it is here or on its way.
    @discardableResult
    func request(_ pack: FontPack, weight: TextOverlayWeight) -> Task<Bool, Never> {
        let file = pack.file(for: weight)
        let key = FontPackRegistry.key(pack, file)
        if states[key] == .ready { return Task { true } }
        if let running = tasks[key] { return running }
        states[key] = .downloading(0)
        let task = Task { [weak self] () -> Bool in
            guard let self else { return false }
            return await self.download(pack, file, key: key)
        }
        tasks[key] = task
        return task
    }

    /// What of `needs` isn't drawn now (not downloaded yet, or arrived while another export runs): those words come out in the
    /// system's face of their script.
    func unavailable(_ needs: Set<FontPackNeed>) -> Set<FontPackNeed> {
        needs.filter { need in
            guard let pack = manifest.pack(need.packID) else { return false }
            return !registry.isReady(pack, pack.file(for: need.weight))
        }
    }

    /// Waits for the downloads `needs` started (none starts here), at most `timeout`: an export lets the families it uses arrive
    /// first, and goes with the system's faces for any still on its way after that.
    func awaitDownloads(_ needs: Set<FontPackNeed>, timeout: Duration) async {
        let running = needs.compactMap { need -> Task<Bool, Never>? in
            guard let pack = manifest.pack(need.packID) else { return nil }
            return tasks[FontPackRegistry.key(pack, pack.file(for: need.weight))]
        }
        guard !running.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for task in running { _ = await task.value }
            }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
    }

    /// Files that waited for an export are drawn now (`FontPackRegistry.endExport`): the editor draws again.
    func heldFacesArrived() {
        generation += 1
    }

    // MARK: - Removing

    /// Deletes the family's files; a video that uses it draws in the system's face of its script, and downloads it again when
    /// it is edited.
    func remove(_ pack: FontPack) {
        for file in pack.files {
            let key = FontPackRegistry.key(pack, file)
            tasks[key]?.cancel()
            tasks[key] = nil
            states[key] = nil
            registry.remove(pack, file)
        }
        FontPackFiles.remove(pack, in: directory)
        generation += 1
    }

    /// "Delete my Cue data".
    func eraseAll() {
        for task in tasks.values { task.cancel() }
        tasks = [:]
        states = [:]
        registry.removeAll()
        FontPackFiles.removeAll(in: directory)
        generation += 1
    }

    // MARK: - Private

    private func download(_ pack: FontPack, _ file: FontPack.File, key: String) async -> Bool {
        defer { tasks[key] = nil }
        let url = FontPackFiles.url(of: pack, file, in: directory)
        do {
            let data = try await source.data(for: file) { [weak self] fraction in
                Task { @MainActor [weak self] in
                    guard let self, case .downloading = self.states[key] else { return }
                    // A few steps are enough for a ring: fewer redraws.
                    let shown = (fraction * 20).rounded(.down) / 20
                    if self.states[key] != .downloading(shown) { self.states[key] = .downloading(shown) }
                }
            }
            try Task.checkCancellation()
            guard FontPackFiles.matches(data, file) else {
                logger.error("Font pack file failed its check: \(file.file, privacy: .public)")
                states[key] = .failed
                return false
            }
            let root = directory
            try await Task.detached(priority: .utility) { try FontPackFiles.keep(data, at: url, root: root) }.value
            guard FontPackFiles.register(url, postScriptName: file.postScriptName) else {
                try? FileManager.default.removeItem(at: url)
                states[key] = .failed
                return false
            }
            registry.add(pack, file, postScriptName: file.postScriptName)
            states[key] = .ready
            generation += 1
            return true
        } catch {
            if !(error is CancellationError) {
                logger.error("Font pack download failed: \(file.file, privacy: .public) \(error.localizedDescription, privacy: .public)")
            }
            if tasks[key] != nil || states[key] != nil { states[key] = .failed }
            return false
        }
    }
}
