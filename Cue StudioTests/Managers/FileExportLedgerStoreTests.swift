//
//  FileExportLedgerStoreTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The ledger's file when something went wrong with it: damaged as a whole, one record damaged, or there but unreadable at
/// launch. Nothing crashes, nothing is written over unread, a damaged file is kept aside, and an export is never counted
/// twice. (A plain round trip and a missing file: `ShareModelsTests`.)
@MainActor
@Suite("FileExportLedgerStore")
struct FileExportLedgerStoreTests {
    private let folder = URL.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString)", directoryHint: .isDirectory)
    private var url: URL { folder.appending(path: "ExportLedger.json") }

    private func operation(createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> ExportOperation {
        ExportOperation(id: UUID(), takeID: UUID(), fingerprint: "f", fileName: "Cue-\(UUID().uuidString.prefix(8)).mov", createdAt: createdAt)
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: url)
    }

    private func keptCopies() -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        return names.filter { $0.hasPrefix("ExportLedger-kept-") }.map { folder.appending(path: $0) }
    }

    private func setPermissions(_ permissions: Int, of file: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: file.path(percentEncoded: false))
    }

    @Test func aDamagedLedgerIsKeptAsideAndANewOneStarts() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let damaged = Data("[{\"id\": \"truncated".utf8)
        try write(damaged)
        let store = FileExportLedgerStore(url: url)
        #expect(store.load().isEmpty)
        let copies = keptCopies()
        #expect(copies.count == 1)
        #expect(try copies.first.map { try Data(contentsOf: $0) } == damaged)

        let fresh = operation()
        store.save([fresh])
        #expect(FileExportLedgerStore(url: url).load() == [fresh])
        #expect(keptCopies().count == 1)
    }

    @Test func oneDamagedRecordStaysOutAndTheFileIsKeptAside() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let good = operation()
        var file = Data("[".utf8)
        file.append(try JSONEncoder().encode(good))
        file.append(Data(", {\"id\": 3}]".utf8))
        try write(file)
        #expect(FileExportLedgerStore(url: url).load() == [good])
        #expect(try keptCopies().map { try Data(contentsOf: $0) } == [file])
    }

    /// The iPhone not unlocked since it started (or a read error) at launch: the operations on disk are still there after
    /// the next save, next to the new one.
    @Test func aLedgerUnreadableAtLaunchIsNeverWrittenOver() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let earlier = operation()
        FileExportLedgerStore(url: url).save([earlier])
        try setPermissions(0o000, of: url)
        let store = FileExportLedgerStore(url: url)
        #expect(store.load().isEmpty)
        try setPermissions(0o644, of: url)

        let later = operation()
        store.save([later])
        #expect(FileExportLedgerStore(url: url).load() == [earlier, later])
        #expect(keptCopies().isEmpty)
    }

    @Test func aLedgerStillUnreadableIsSetAsideBeforeANewOne() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let earlier = operation()
        FileExportLedgerStore(url: url).save([earlier])
        try setPermissions(0o000, of: url)
        let store = FileExportLedgerStore(url: url)
        #expect(store.load().isEmpty)

        let later = operation()
        store.save([later])
        #expect(FileExportLedgerStore(url: url).load() == [later])
        let copy = try #require(keptCopies().first)
        try setPermissions(0o644, of: copy)
        #expect(try JSONDecoder().decode([ExportOperation].self, from: Data(contentsOf: copy)) == [earlier])
    }

    /// The free-export count lives apart from the ledger: a damaged ledger hands nothing back, and a late callback for an
    /// export it lost counts nothing.
    @Test func aDamagedLedgerNeverCountsAnExportTwice() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let quota = UsageQuotaService(counter: FakeExportCountStore(count: 0), defaults: defaults.defaults)
        let before = ExportLedgerService(store: FileExportLedgerStore(url: url), quota: quota, directory: folder)
        let exported = before.begin(takeID: UUID(), fingerprint: "f", file: folder.appending(path: "Cue-a.mov"))
        #expect(before.recordDelivery(.photoLibrary(assetID: "a"), for: exported.id, tier: .free))
        #expect(quota.exportsUsed == 1)

        try write(Data("not a ledger".utf8))
        let after = ExportLedgerService(store: FileExportLedgerStore(url: url), quota: quota, directory: folder)
        #expect(after.operations.isEmpty)
        #expect(!after.recordDelivery(.activity(type: nil), for: exported.id, tier: .free))
        #expect(quota.exportsUsed == 1)
        #expect(keptCopies().count == 1)
    }
}
