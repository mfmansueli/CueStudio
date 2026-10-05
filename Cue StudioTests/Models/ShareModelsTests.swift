//
//  ShareModelsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Sharing models")
struct ShareModelsTests {
    @Test func theShareSheetsThreeEndingsAreToldApart() {
        #expect(ActivityResult(activityType: "a", completed: true, error: nil) == .completed(activityType: "a"))
        #expect(ActivityResult(activityType: nil, completed: false, error: nil) == .cancelled)
        #expect(ActivityResult(activityType: "a", completed: false, error: CocoaError(.fileReadUnknown)) == .failed)
        // An error wins over a completed flag.
        #expect(ActivityResult(activityType: "a", completed: true, error: CocoaError(.fileReadUnknown)) == .failed)
    }

    @Test func aDestinationRecognizesItsOwnShareExtension() {
        #expect(ShareDestination.youtube.matches(activityType: "com.google.ios.youtube.ShareExtension"))
        #expect(ShareDestination.shorts.matches(activityType: "com.google.ios.youtube.ShareExtension"))
        #expect(ShareDestination.reels.matches(activityType: "com.burbn.instagram.shareextension"))
        #expect(ShareDestination.linkedin.matches(activityType: "com.linkedin.LinkedIn.ShareExtension"))
        #expect(!ShareDestination.youtube.matches(activityType: "com.apple.UIKit.activity.AirDrop"))
        #expect(!ShareDestination.tiktok.matches(activityType: nil))
    }

    @Test func theLedgersRecordsRoundTripThroughJSON() throws {
        let operation = ExportOperation(
            id: UUID(), takeID: UUID(), fingerprint: "f", fileName: "a.mov", createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            photosAssetID: "x", countedAt: Date(timeIntervalSince1970: 1_800_000_100),
            deliveries: [.photoLibrary(assetID: "x"), .activity(type: nil), .pasteboardHandoff, .tikTokShareKit]
        )
        let data = try JSONEncoder().encode([operation])
        #expect(try JSONDecoder().decode([ExportOperation].self, from: data) == [operation])
    }

    @Test func theFileStoreKeepsOperationsBetweenLaunches() throws {
        let url = URL.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString)/ExportLedger.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let operation = ExportOperation(id: UUID(), takeID: UUID(), fingerprint: "f", fileName: "a.mov", createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        FileExportLedgerStore(url: url).save([operation])
        #expect(FileExportLedgerStore(url: url).load() == [operation])
        #expect(FileExportLedgerStore(url: url.deletingLastPathComponent().appending(path: "missing.json")).load().isEmpty)
    }
}
