//
//  WatchButtonStyle.swift
//  Cue Studio Watch
//

import SwiftUI

/// The board's capsule buttons: full width, at least 44 pt, a little smaller while pressed.
struct WatchButtonStyle: ButtonStyle {
    enum Kind {
        /// Record: red.
        case record
        /// End: the stop outline, or armed, solid red with a white edge.
        case stop(armed: Bool)
        /// Everything else.
        case plain
    }

    var kind: Kind = .plain

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundStyle(WatchPalette.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 8)
            .background(background)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var font: Font {
        switch kind {
        case .record, .stop(armed: false): .title3.weight(.semibold)
        case .stop(armed: true), .plain: .body.weight(.semibold)
        }
    }

    private var minHeight: CGFloat {
        switch kind {
        case .record, .stop: 46
        case .plain: 40
        }
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .record:
            Capsule().fill(WatchPalette.record)
        case .stop(let armed):
            if armed {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(WatchPalette.record)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(WatchPalette.ink, lineWidth: 1.5))
            } else {
                Capsule().fill(WatchPalette.stopGround).overlay(Capsule().strokeBorder(WatchPalette.stopLine, lineWidth: 1.5))
            }
        case .plain:
            Capsule().fill(WatchPalette.surface)
        }
    }
}
