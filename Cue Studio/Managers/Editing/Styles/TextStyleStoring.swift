//
//  TextStyleStoring.swift
//  Cue Studio
//

import Foundation

/// Where "My style" is kept between edits: the type the creator saved from a text, and the cover
/// style they saved ("My cover style"), reused on any take.
@MainActor
protocol TextStyleStoring: AnyObject {
    var myStyle: TextLook? { get set }
    /// Layout, typeface, effect and series tag of a cover (v26): what Cover Studio's style starts from when there's none.
    var myCoverLook: CoverLook? { get set }
    /// Cover Studio's "My cover style": new covers start in it.
    var myCoverStyle: CoverStyle? { get set }
}
