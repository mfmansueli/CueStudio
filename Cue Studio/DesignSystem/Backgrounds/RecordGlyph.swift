//
//  RecordGlyph.swift
//  Cue Studio
//

import SwiftUI

/// The record button in miniature (v29): a thin ring around a solid red dot, with no glow. Two colors, so it is
/// drawn rather than a template icon. The ring follows the foreground style; the dot is always `record`
/// (red is for recording only).
struct RecordGlyph: View {
    var size: CGFloat = Metrics.tabRecordSize

    var body: some View {
        ZStack {
            Circle().strokeBorder(.foreground, lineWidth: 1.5)
            Circle()
                .fill(Palette.record)
                .frame(width: size * 0.56, height: size * 0.56)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    RecordGlyph().foregroundStyle(Palette.ink2).padding().background(Palette.bg)
}
#endif
