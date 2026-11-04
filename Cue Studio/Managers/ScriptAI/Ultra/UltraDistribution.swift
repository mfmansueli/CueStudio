//
//  UltraDistribution.swift
//  Cue Studio
//

import Foundation
import StoreKit

/// Whether a Release build offers Ultra AI: on TestFlight (StoreKit's sandbox) and in a build Xcode installed, never from the App Store until Cue's
/// server keeps each creator's credits (the free scripts and Pro's are still counted on the iPhone, `UltraAllowanceService`). Asked once per
/// launch; when StoreKit can't say (no network on the very first launch), Ultra stays off until the next one.
nonisolated enum UltraDistribution {
    static func allowsUltra() async -> Bool {
        guard let result = try? await AppTransaction.shared else { return false }
        return allows(result.unsafePayloadValue.environment)
    }

    static func allows(_ environment: AppStore.Environment) -> Bool {
        environment != .production
    }
}
