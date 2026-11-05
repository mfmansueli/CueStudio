//
//  AppStoreLink.swift
//  Cue Studio
//

import Foundation

/// Cue's page on the App Store, for the invite message. The app's Apple ID comes from the build (`CUE_APP_STORE_ID` in `Config/App.xcconfig`,
/// Info.plist `CueAppStoreID`); while it is empty, the message names the App Store without a link.
nonisolated enum AppStoreLink {
    static let infoKey = "CueAppStoreID"

    static func app(bundle: Bundle = .main) -> URL? {
        guard let id = bundle.object(forInfoDictionaryKey: infoKey) as? String else { return nil }
        return url(appID: id)
    }

    /// The page of an Apple ID made only of digits; nil otherwise.
    static func url(appID: String) -> URL? {
        let id = appID.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)")
    }
}
