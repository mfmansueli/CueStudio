//
//  PrompterTextColor+Color.swift
//  Cue Studio
//

import SwiftUI

extension PrompterTextColor {
    var color: Color { Color(hexString: hex) ?? .white }
}
