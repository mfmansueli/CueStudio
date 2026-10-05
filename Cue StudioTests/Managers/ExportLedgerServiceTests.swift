//
//  ExportLedgerServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("ExportLedgerService")
struct ExportLedgerServiceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private struct Setup {
        let ledger: ExportLedgerService
        let quota: UsageQuotaService
        let store: FakeExportLedgerStore
        let counter: FakeExportCountStore
        let directory: URL
        let defaults: TestDefaults
    }

    private func makeSetup(used: Int = 0, store: FakeExportLedgerStore = FakeExportLedgerStore(), now: Date? = nil) -> Setup {
        let defaults = TestDefaults()
        let counter = FakeExportCountStore(count: used)
        let quota = UsageQuotaService(counter: counter, defaults: defaults.defaults)
        let directory = URL.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let time = now ?? self.now
        let ledger = ExportLedgerService(store: store, quota: quota, directory: directory, now: { time })
        return Setup(ledger: ledger, quota: quota, store: store, counter: counter, directory: directory, defaults: defaults)
    }

    private func write(_ name: String, in setup: Setup) throws -> URL {
        let url = setup.directory.appending(path: name)
        try Data([1]).write(to: url)
        return url
    }

    @Test func theFirstDeliveryDeductsAndTheNextOnesDoNot() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let file = try write("a.mov", in: setup)
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: file)
        #expect(setup.quota.exportsUsed == 0)
        #expect(setup.ledger.recordDelivery(.photoLibrary(assetID: "x"), for: operation.id, tier: .free))
        #expect(!setup.ledger.recordDelivery(.activity(type: "a"), for: operation.id, tier: .free))
        #expect(!setup.ledger.recordDelivery(.activity(type: "a"), for: operation.id, tier: .free))
        #expect(!setup.ledger.recordDelivery(.tikTokShareKit, for: operation.id, tier: .free))
        #expect(setup.quota.exportsUsed == 1)
        #expect(setup.counter.count == 1)
        #expect(setup.ledger.operation(id: operation.id)?.deliveries.count == 3)
        #expect(setup.ledger.operation(id: operation.id)?.photosAssetID == "x")
    }

    @Test func aSubscriberDeliveryIsRecordedWithoutTouchingTheCount() throws {
        let setup = makeSetup(used: 2)
        defer { setup.defaults.tearDown() }
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: try write("a.mov", in: setup))
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: operation.id, tier: .subscriber)
        #expect(setup.quota.exportsUsed == 2)
        #expect(setup.ledger.operation(id: operation.id)?.isCounted == true)
        // Pro ends: the same operation still doesn't cost anything.
        #expect(!setup.ledger.recordDelivery(.activity(type: nil), for: operation.id, tier: .free))
        #expect(setup.quota.exportsUsed == 2)
    }

    @Test func anUnknownOperationChangesNothing() {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        #expect(!setup.ledger.recordDelivery(.tikTokShareKit, for: UUID(), tier: .free))
        #expect(setup.quota.exportsUsed == 0)
    }

    @Test func twoOperationsAreTwoExports() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let take = UUID()
        let first = setup.ledger.begin(takeID: take, fingerprint: "one", file: try write("a.mov", in: setup))
        let second = setup.ledger.begin(takeID: take, fingerprint: "two", file: try write("b.mov", in: setup))
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: first.id, tier: .free)
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: second.id, tier: .free)
        #expect(setup.quota.exportsUsed == 2)
    }

    @Test func theCountSurvivesARestartAndNothingIsDeductedTwice() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: try write("a.mov", in: setup))
        setup.ledger.recordDelivery(.photoLibrary(assetID: "x"), for: operation.id, tier: .free)

        // The app starts again: same Keychain count, same ledger file.
        let quota = UsageQuotaService(counter: setup.counter, defaults: setup.defaults.defaults)
        let restored = ExportLedgerService(store: setup.store, quota: quota, directory: setup.directory, now: { now })
        #expect(quota.exportsUsed == 1)
        #expect(restored.operation(id: operation.id)?.isCounted == true)
        #expect(!restored.recordDelivery(.activity(type: "a"), for: operation.id, tier: .free))
        #expect(quota.exportsUsed == 1)
        #expect(restored.reusableOperation(fingerprint: "f")?.id == operation.id)
    }

    @Test func theLedgerIsWrittenBeforeTheQuotaSoACrashNeverCountsTwice() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: try write("a.mov", in: setup))
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: operation.id, tier: .free)
        // What a restart would read back already says "counted".
        #expect(setup.store.operations.first?.isCounted == true)
    }

    @Test func onlyAMatchingFileThatStillExistsIsReused() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let file = try write("a.mov", in: setup)
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "same", file: file)
        #expect(setup.ledger.reusableOperation(fingerprint: "same")?.id == operation.id)
        #expect(setup.ledger.reusableOperation(fingerprint: "other") == nil)
        try FileManager.default.removeItem(at: file)
        #expect(setup.ledger.reusableOperation(fingerprint: "same") == nil)
    }

    @Test func releasingAFileKeepsTheRecord() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let file = try write("a.mov", in: setup)
        let take = UUID()
        let operation = setup.ledger.begin(takeID: take, fingerprint: "f", file: file)
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: operation.id, tier: .free)
        #expect(setup.ledger.hasCountedOperation(forTake: take))
        setup.ledger.releaseFiles(forTake: take)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(!setup.ledger.hasCountedOperation(forTake: take))
        #expect(setup.ledger.operation(id: operation.id)?.isCounted == true)
    }

    @Test func replacingTheFileKeepsTheOperationAndItsCount() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: try write("a.mov", in: setup))
        setup.ledger.recordDelivery(.photoLibrary(assetID: nil), for: operation.id, tier: .free)
        setup.ledger.replaceFile(of: operation.id, with: try write("b.mov", in: setup))
        #expect(setup.ledger.operation(id: operation.id)?.fileName == "b.mov")
        #expect(setup.ledger.operation(id: operation.id)?.isCounted == true)
        #expect(setup.quota.exportsUsed == 1)
    }

    @Test func oldFilesAndRecordsAreCleanedAtStart() throws {
        let setup = makeSetup()
        defer { setup.defaults.tearDown() }
        let oldFile = try write("old.mov", in: setup)
        let operation = setup.ledger.begin(takeID: UUID(), fingerprint: "f", file: oldFile)

        // A day and a bit later: the file goes, the record stays (a late callback still finds it).
        let dayLater = now.addingTimeInterval(ExportLedgerService.fileRetention + 60)
        let afterADay = makeSetupSharing(setup, now: dayLater)
        #expect(!FileManager.default.fileExists(atPath: oldFile.path))
        #expect(afterADay.operation(id: operation.id) != nil)

        // A week later the record goes too.
        let weekLater = now.addingTimeInterval(ExportLedgerService.recordRetention + 60)
        let afterAWeek = makeSetupSharing(setup, now: weekLater)
        #expect(afterAWeek.operation(id: operation.id) == nil)
    }

    private func makeSetupSharing(_ setup: Setup, now: Date) -> ExportLedgerService {
        ExportLedgerService(store: setup.store, quota: setup.quota, directory: setup.directory, now: { now })
    }

    @Test func evidenceNeverClaimsPublication() {
        let all: [DeliveryEvidence] = [.photoLibrary(assetID: "x"), .activity(type: "a"), .pasteboardHandoff, .tikTokShareKit]
        #expect(all.allSatisfy { !$0.confirmsPublication })
    }
}
