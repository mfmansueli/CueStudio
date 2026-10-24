//
//  TextStyleStoring.swift
//  Cue Studio
//

import Foundation

/// Where the creator's saved styles are kept between edits (`StyleLibrary`): their caption combinations, their texts' looks and
/// their covers' styles, each with its favorites and the style new work starts in, reused on any take.
@MainActor
protocol TextStyleStoring: AnyObject {
    /// Caption style's saved styles: new captions start in the default one.
    var captionStyles: StyleLibrary<MyCaptionStyle> { get set }
    /// Text style's saved looks: new texts start in the default one, on a video with no style of its own yet.
    var textStyles: StyleLibrary<TextLook> { get set }
    /// Cover Studio's saved styles: new covers start in the default one.
    var coverStyles: StyleLibrary<CoverStyle> { get set }
    /// Caption style › Styles' filter, as it was left (`CaptionCatalogFilter.rawValue`); nil: All.
    var captionCatalogFilter: String? { get set }
}
