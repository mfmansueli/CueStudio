//
//  UltraLabAppCheckFactory.swift
//  Cue Studio
//

#if DEBUG
import FirebaseAppCheck
import FirebaseCore
import Foundation

/// App Check for the lab's Firebase app only: its debug provider, whose token is registered in the lab project. Every other Firebase app (the
/// telemetry one) gets no provider from here, as before. Debug builds only: a debug provider never ships.
final class UltraLabAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        guard app.name == UltraLabConfiguration.appName else { return nil }
        return AppCheckDebugProvider(app: app)
    }
}
#endif
