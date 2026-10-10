//
//  VoyageEyebrowLabelStyle.swift
//  Cue Studio
//

import SwiftUI

/// "★ YOUR FIRST VOYAGE": a small icon close to its mono words.
struct VoyageEyebrowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 10, weight: .bold))
            configuration.title
        }
    }
}
