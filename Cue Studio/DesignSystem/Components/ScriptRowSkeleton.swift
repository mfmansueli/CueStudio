//
//  ScriptRowSkeleton.swift
//  Cue Studio
//

import SwiftUI

/// A placeholder of a Scripts row (a title bar and a line of meta) at the rows' own size, so nothing jumps when they arrive.
struct ScriptRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.fill).frame(width: 200, height: 14)
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Palette.fill.opacity(0.6)).frame(width: 130, height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 66)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .skeletonShine()
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 8) { ForEach(0..<3, id: \.self) { _ in ScriptRowSkeleton() } }
        .padding()
        .background(Palette.bg)
}
#endif
