//
//  TextStyleStoring.swift
//  Cue Studio
//

import Foundation

/// Where "My style" is kept between edits: the type the creator saved from a text, reused on any
/// take.
@MainActor
protocol TextStyleStoring: AnyObject {
    var myStyle: TextLook? { get set }
}
