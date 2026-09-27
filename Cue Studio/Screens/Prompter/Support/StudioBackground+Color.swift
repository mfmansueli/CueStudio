//
//  StudioBackground+Color.swift
//  Cue Studio
//

import SwiftUI

extension StudioBackground {
    var color: Color { Color(hexString: hex) ?? .black }
}
