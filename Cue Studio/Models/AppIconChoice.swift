//
//  AppIconChoice.swift
//  Cue Studio
//

import Foundation

/// The app icons: Cue's own and four that milestones in the creator's universe open. Aurora comes with the first
/// video shared; First Light, Deep Space and Constellation (10, 25 and 50 shared) come with Pro.
nonisolated enum AppIconChoice: String, CaseIterable, Identifiable, Sendable {
    case standard, aurora, firstLight, deepSpace, constellation

    var id: String { rawValue }

    /// The name of the alternate icon in the asset catalog; nil is the app's own icon.
    var alternateName: String? {
        switch self {
        case .standard: nil
        case .aurora: "AppIconAurora"
        case .firstLight: "AppIconFirstLight"
        case .deepSpace: "AppIconDeepSpace"
        case .constellation: "AppIconConstellation"
        }
    }

    init(alternateName: String?) {
        self = Self.allCases.first { $0.alternateName == alternateName } ?? .standard
    }

    var title: String {
        switch self {
        case .standard: String(localized: "Default")
        case .aurora: String(localized: "Aurora")
        case .firstLight: String(localized: "First Light")
        case .deepSpace: String(localized: "Deep Space")
        case .constellation: String(localized: "Constellation")
        }
    }

    /// Videos shared before it opens.
    var milestone: Int {
        switch self {
        case .standard: 0
        case .aurora: 1
        case .firstLight: 10
        case .deepSpace: 25
        case .constellation: 50
        }
    }

    /// Past the first one, the icons come with Pro.
    var needsPro: Bool { milestone >= 10 }

    /// The picture shown in the app (an image set), nil for the app's own icon.
    var previewName: String? {
        switch self {
        case .standard: nil
        case .aurora: "IconPreviewAurora"
        case .firstLight: "IconPreviewFirstLight"
        case .deepSpace: "IconPreviewDeepSpace"
        case .constellation: "IconPreviewConstellation"
        }
    }

    /// The icon a milestone opens.
    init?(milestone: Int) {
        guard let match = Self.allCases.first(where: { $0.milestone == milestone && milestone > 0 }) else { return nil }
        self = match
    }
}
