//
//  BestBadge.swift
//  Cue Studio
//

import SwiftUI

/// Yellow "Best" tag.
struct BestBadge: View {
    var body: some View {
        Label("Best", systemImage: "star.fill")
            .cueFont(.caption2, weight: .bold)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Palette.accInk)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .frame(minHeight: 22)
            .background(Palette.acc, in: Capsule())
    }
}
