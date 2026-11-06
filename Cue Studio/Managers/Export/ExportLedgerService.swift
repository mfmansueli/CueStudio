//
//  ExportLedgerService.swift
//  Cue Studio
//

import Foundation

/// The one place a free export is counted. An export is an *operation*: one exported file with an identity that outlives
/// the screen, the share sheet and the app (the records are kept on disk). A free export is deducted the first time the
/// video provably leaves Cue (`DeliveryEvidence`: saved to Photos, accepted by a share-sheet activity, received by
/// TikTok), and never again for that video, however many callbacks, retries or later deliveries follow.
///
/// "That video" is its fingerprint (`ExportFingerprint`: the take, the recording, the edit and the export settings, not where it goes):
/// saved today and shared tomorrow, after its file was cleared and made again, is still one export. A counted record stays as long as its
/// take (`forget(takeID:)`), never on a timer; the file it names goes after a day. What does not count: preparing the file, opening another
/// app, cancelling, failing. Another edit or other settings are another video and follow the quota like any other.
///
/// Order matters if the app dies between the two writes: the operation is marked first and the quota second, so the
/// worst case is one export not counted, never one counted twice.
@MainActor
@Observable
final class ExportLedgerService {
    /// An exported file nobody shared is removed after a day. The record of one never delivered, which stops a late callback from counting
    /// twice, after a week; a counted one stays with its take.
    nonisolated static let fileRetention: TimeInterval = 24 * 3600
    nonisolated static let recordRetention: TimeInterval = 7 * 24 * 3600
    private static let maxDeliveriesKept = 8

    private(set) var operations: [ExportOperation]

    private let store: ExportLedgerStoring
    private let quota: UsageQuotaService
    /// A video left Cue for the first time (`ReferralService`, `ReviewPromptService`).
    @ObservationIgnored var firstDelivered: (@MainActor () -> Void)?
    private let directory: URL
    private let files: FileManager
    private let now: () -> Date

    init(
        store: ExportLedgerStoring = FileExportLedgerStore(), quota: UsageQuotaService,
        directory: URL = .temporaryDirectory, files: FileManager = .default, now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.quota = quota
        self.directory = directory
        self.files = files
        self.now = now
        operations = store.load()
        removeExpired()
    }

    // MARK: - Reading

    func operation(id: UUID) -> ExportOperation? {
        operations.first { $0.id == id }
    }

    func fileURL(of operation: ExportOperation) -> URL {
        directory.appending(path: operation.fileName)
    }

    func fileExists(for operation: ExportOperation) -> Bool {
        files.fileExists(atPath: fileURL(of: operation).path)
    }

    /// The operation whose file can serve this export again: same fingerprint (edit and settings) and the file still there.
    func reusableOperation(fingerprint: String) -> ExportOperation? {
        operations.last { $0.fingerprint == fingerprint && fileExists(for: $0) }
    }

    /// This very video already counted, its file there or not.
    func isCounted(fingerprint: String) -> Bool {
        operations.contains { $0.fingerprint == fingerprint && $0.isCounted }
    }

    /// The operation counted, or the same video counted under another one (made again after its file was cleared).
    func isCounted(operationID: UUID) -> Bool {
        operation(id: operationID).map { isCounted(fingerprint: $0.fingerprint) } ?? false
    }

    // MARK: - Operations

    /// A freshly exported file. Nothing is counted yet, unless it carries on an operation that already was (`inheritingCountFrom`: an edit made
    /// inside a "Share to universe" queue is the same export, and costs nothing more) or is a video already counted, made again.
    func begin(takeID: UUID, fingerprint: String, file: URL, inheritingCountFrom source: UUID? = nil) -> ExportOperation {
        var operation = ExportOperation(
            id: UUID(), takeID: takeID, fingerprint: fingerprint, fileName: file.lastPathComponent, createdAt: now()
        )
        let sameVideo = operations.last { $0.fingerprint == fingerprint && $0.isCounted }?.countedAt
        if let counted = source.flatMap({ self.operation(id: $0)?.countedAt }) ?? sameVideo { operation.countedAt = counted }
        operations.append(operation)
        persist()
        return operation
    }

    /// The operation's file was made again (the system cleared the old one): same operation, so it isn't counted twice.
    func replaceFile(of id: UUID, with file: URL) {
        update(id) { $0.fileName = file.lastPathComponent }
    }

    /// Records a delivery and counts the export if this is the video's first. Returns true only for the call that deducted; a repeated
    /// callback, a retry, a second delivery or the same video under another operation returns false and changes nothing in the quota. On the
    /// main actor, the check and the mark are one step: two deliveries at once can't both see "not counted".
    @discardableResult
    func recordDelivery(_ evidence: DeliveryEvidence, for id: UUID, tier: MembershipTier) -> Bool {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return false }
        var operation = operations[index]
        if !operation.deliveries.contains(evidence) {
            operation.deliveries.append(evidence)
            if operation.deliveries.count > Self.maxDeliveriesKept { operation.deliveries.removeFirst() }
        }
        if case .photoLibrary(let assetID?) = evidence { operation.photosAssetID = assetID }
        let isFirst = !isCounted(fingerprint: operation.fingerprint)
        if !operation.isCounted { operation.countedAt = now() }
        operations[index] = operation
        persist()
        if isFirst {
            quota.recordExport(tier: tier)
            firstDelivered?()
        }
        return isFirst
    }

    // MARK: - Files

    /// The file isn't needed any more (the review closed with nothing in flight): it goes, the record stays.
    func releaseFile(of id: UUID) {
        guard let operation = operation(id: id) else { return }
        try? files.removeItem(at: fileURL(of: operation))
    }

    func releaseFiles(forTake takeID: UUID) {
        for operation in operations where operation.takeID == takeID { releaseFile(of: operation.id) }
    }

    /// The take is gone for good: its files and its records go (nothing can export it again).
    func forget(takeID: UUID) {
        releaseFiles(forTake: takeID)
        let kept = operations.filter { $0.takeID != takeID }
        guard kept.count != operations.count else { return }
        operations = kept
        persist()
    }

    // MARK: - Private

    private func update(_ id: UUID, _ change: (inout ExportOperation) -> Void) {
        guard let index = operations.firstIndex(where: { $0.id == id }) else { return }
        change(&operations[index])
        persist()
    }

    private func persist() {
        store.save(operations)
    }

    private func removeExpired() {
        let current = now()
        var changed = false
        for operation in operations where current.timeIntervalSince(operation.createdAt) > Self.fileRetention {
            if fileExists(for: operation) {
                try? files.removeItem(at: fileURL(of: operation))
            }
        }
        let kept = operations.filter { $0.isCounted || current.timeIntervalSince($0.createdAt) <= Self.recordRetention }
        if kept.count != operations.count {
            operations = kept
            changed = true
        }
        if changed { persist() }
    }
}
