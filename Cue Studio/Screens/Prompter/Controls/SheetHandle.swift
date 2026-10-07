//
//  SheetHandle.swift
//  Cue Studio
//

import SwiftUI

/// The handle of the sheet that holds the Selfie controls : a chevron that points up while the sheet is in and turns down as it
/// comes out, turning with the sheet itself. A tap shows or hides the controls; VoiceOver steps up and down. The drags belong to whoever
/// holds the handle, because only it knows what moves.
struct SheetHandle: View {
    static let height: CGFloat = 36

    /// How far the sheet is out, 0...1 (a little past 1 while it stretches).
    let progress: CGFloat
    /// The controls are out of the sheet, once it settles.
    let isOut: Bool
    let onTap: () -> Void
    /// ±1 from VoiceOver.
    let onMove: (Int) -> Void

    var body: some View {
        Image(systemName: "chevron.up")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Palette.ink2)
            .rotationEffect(.degrees(180 * Double(min(max(progress, 0), 1))))
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Controls"))
            .accessibilityValue(Text(isOut ? "Shown" : "Hidden"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onMove(1)
                case .decrement: onMove(-1)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("prompter.sheetHandle")
    }
}
