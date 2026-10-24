//
//  TextStyleStore.swift
//  Cue Studio
//

import Foundation

/// The creator's saved styles in UserDefaults, on this device. The single "My style" each kind had before saved styles is read
/// once into its library, as the first style (and, for captions and covers, as the default, since new captions and covers
/// already started in it); the old key stays, so an earlier version of Cue still finds it.
@MainActor
final class TextStyleStore: TextStyleStoring {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var captionStyles: StyleLibrary<MyCaptionStyle> {
        get { library(at: DefaultsKey.captionStyleLibrary, legacy: decoded(MyCaptionStyle.self, at: DefaultsKey.myCaptionStyle), isDefault: true) }
        set { write(newValue, at: DefaultsKey.captionStyleLibrary) }
    }

    var textStyles: StyleLibrary<TextLook> {
        // Text's "My style" was a card to pick, not where new texts started.
        get { library(at: DefaultsKey.textStyleLibrary, legacy: decoded(TextLook.self, at: DefaultsKey.myTextStyle), isDefault: false) }
        set { write(newValue, at: DefaultsKey.textStyleLibrary) }
    }

    var coverStyles: StyleLibrary<CoverStyle> {
        get { library(at: DefaultsKey.coverStyleLibrary, legacy: legacyCoverStyle, isDefault: true) }
        set { write(newValue, at: DefaultsKey.coverStyleLibrary) }
    }

    var captionCatalogFilter: String? {
        get { defaults.string(forKey: DefaultsKey.captionCatalogFilter) }
        set { defaults.set(newValue, forKey: DefaultsKey.captionCatalogFilter) }
    }

    // MARK: - Private

    /// The library at `key`; the first time, made from the single style an earlier version saved (and written, so its
    /// identity stays).
    private func library<Look: Codable & Hashable & Sendable>(at key: String, legacy: Look?, isDefault: Bool) -> StyleLibrary<Look> {
        if let library = decoded(StyleLibrary<Look>.self, at: key) { return library }
        // Saved styles this version can't read (a newer one wrote them) are never replaced by the old single style.
        guard defaults.data(forKey: key) == nil else { return StyleLibrary() }
        var library = StyleLibrary<Look>()
        guard let legacy else { return library }
        let style = library.add(legacy, named: String(localized: "My style"))
        if isDefault { library.setDefault(style.key) }
        write(library, at: key)
        return library
    }

    /// Cover Studio's "My cover style"; a creator who saved one in the v26 Cover panel starts from it, converted.
    private var legacyCoverStyle: CoverStyle? {
        if let style = decoded(CoverStyle.self, at: DefaultsKey.myCoverStudioStyle) { return style }
        guard let look = decoded(CoverLook.self, at: DefaultsKey.myCoverStyle) else { return nil }
        var design = CoverDesign()
        design.apply(look)
        var cover = VideoCover(source: .frame(0))
        cover.design = design
        return CoverComposition(legacy: cover).style
    }

    private func decoded<Value: Decodable>(_ type: Value.Type, at key: String) -> Value? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }

    private func write<Value: Encodable>(_ value: Value, at key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}
