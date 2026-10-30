//
//  UltraLabConfiguration.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Where the lab's Firebase configuration is on this iPhone, and whether it is the lab's. It is copied into the app's Documents by hand
/// (`devicectl … copy to`), never built into the app or committed: the production `GoogleService-Info.plist` (project `cuestudio-app`,
/// telemetry) is a different app and is never read or replaced here. The App Check debug token sits next to it, also out of Git.
nonisolated enum UltraLabConfiguration {
    /// The isolated Firebase project the owner set up for the experiment.
    static let projectID = "cue-script-ai-lab"
    /// The lab's own Firebase app, apart from the default (telemetry) one.
    static let appName = "CueUltraLab"
    static let fileName = "UltraLab-GoogleService-Info.plist"
    static let debugTokenFileName = "UltraLab-AppCheckDebugToken"
    /// Where App Check's debug provider keeps its token (`GACAppCheckDebugProvider`).
    static let debugTokenDefaultsKey = "GACAppCheckDebugToken"

    static var fileURL: URL { URL.documentsDirectory.appending(path: fileName) }
    static var debugTokenURL: URL { URL.documentsDirectory.appending(path: debugTokenFileName) }

    /// The lab's configuration is on this iPhone and is the lab's, read from the file alone (no Firebase, no network): what decides whether Ultra
    /// is offered at all.
    static var isPresent: Bool {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return false }
        return accepts(projectID: plist["PROJECT_ID"] as? String, bundleID: plist["BUNDLE_ID"] as? String, appBundleID: Bundle.main.bundleIdentifier)
    }

    /// Only the lab's project, for this app: anything else (the production project, another bundle) is refused.
    static func accepts(projectID: String?, bundleID: String?, appBundleID: String?) -> Bool {
        projectID == Self.projectID && bundleID != nil && bundleID == appBundleID
    }

    /// The debug token copied next to the configuration, trimmed; nil when there is none (App Check then makes its own, unregistered).
    static func debugToken() -> String? {
        guard let text = try? String(contentsOf: debugTokenURL, encoding: .utf8) else { return nil }
        let token = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
#endif
