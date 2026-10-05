//
//  ExportOperation.swift
//  Cue Studio
//

import Foundation

/// One exported file and what happened to it. Saving it and then sharing it are two deliveries of the same operation,
/// and a free export is counted once per operation (`ExportLedgerService`).
nonisolated struct ExportOperation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let takeID: UUID
    /// What the file was made from (`ExportFingerprint`): the same edit and settings give the same value.
    let fingerprint: String
    /// The exported file's name in the temporary folder (the folder's path changes between launches, the name does not).
    var fileName: String
    let createdAt: Date
    /// The video's identifier in the photo library once it was saved there (Share Kit asks for it).
    var photosAssetID: String?
    /// Set the first time a delivery counted; nil until then.
    var countedAt: Date?
    /// Every delivery seen, in order (a repeated callback is not added twice).
    var deliveries: [DeliveryEvidence] = []

    var isCounted: Bool { countedAt != nil }
}
