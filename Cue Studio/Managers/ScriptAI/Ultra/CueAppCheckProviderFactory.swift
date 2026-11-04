//
//  CueAppCheckProviderFactory.swift
//  Cue Studio
//

import FirebaseAppCheck
import FirebaseCore
import Foundation

/// Which App Check provider each Firebase app gets. A shipped build (TestFlight, App Store) proves itself with App Attest, Apple's check that the
/// request comes from the real Cue on a real iPhone. A Debug build uses App Check's debug provider, whose token is registered in Firebase for the
/// owner's iPhones: the Ultra lab's token file (`UltraLabConfiguration`) when it was copied over, registered in both the lab's project and
/// `cuestudio-app` (`server/scripts/register-app-check.js`). A debug provider never ships.
nonisolated final class CueAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if DEBUG
        if let token = UltraLabConfiguration.debugToken() {
            UserDefaults.standard.set(token, forKey: UltraLabConfiguration.debugTokenDefaultsKey)
        }
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
