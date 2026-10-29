#if DEBUG
import FirebaseAppCheck
import FirebaseCore
import Foundation

/// The debug credential is limited to the isolated lab app. No production provider is replaced.
final class UltraLabAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        guard app.name == "CueUltraLab" else { return nil }
        return AppCheckDebugProvider(app: app)
    }
}
#endif
