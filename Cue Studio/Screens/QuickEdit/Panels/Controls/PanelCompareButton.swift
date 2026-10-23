//
//  PanelCompareButton.swift
//  Cue Studio
//

import SwiftUI

/// ◐ Compare with original, in the panel's header: a tap shows the original until the next tap; holding shows it only while the
/// finger is down, like Photos. Dimmed (and silent) while there is nothing to compare. VoiceOver toggles it.
struct PanelCompareButton: View {
    let compare: PanelCompare

    /// Whether the original was showing when the finger came down, and when it did.
    @State private var press: (wasOn: Bool, start: Date)?

    /// Shorter than this is a tap; longer is a hold.
    private static let holdThreshold: TimeInterval = 0.3

    var body: some View {
        Image(systemName: "circle.lefthalf.filled")
            .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
            .foregroundStyle(compare.isOn ? Palette.accInk : Palette.ink)
            .frame(width: Metrics.applyButtonSize, height: Metrics.applyButtonSize)
            .background(compare.isOn ? Palette.acc : Palette.fill, in: Circle())
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .opacity(compare.isEnabled || compare.isOn ? 1 : Metrics.disabledOpacity)
            .gesture(pressGesture, isEnabled: compare.isEnabled || compare.isOn)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Compare with original"))
            .accessibilityHint(compare.isEnabled ? Text(compare.hint) : Text("Nothing changed yet"))
            .accessibilityValue(compare.isOn ? Text("Showing the original") : Text("Showing your edit"))
            .accessibilityAddTraits(compare.isOn ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { if compare.isEnabled || compare.isOn { compare.show(!compare.isOn) } }
            .accessibilityIdentifier(compare.identifier)
    }

    /// Down: the original shows at once. Up after a short touch: a tap, so it stays (or, if it was showing, goes). Up after a hold:
    /// back to the edit.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard press == nil else { return }
                press = (compare.isOn, Date())
                if !compare.isOn {
                    Haptics.selection()
                    compare.show(true)
                }
            }
            .onEnded { _ in
                guard let press else { return }
                self.press = nil
                let isTap = Date().timeIntervalSince(press.start) < Self.holdThreshold
                if press.wasOn || !isTap { compare.show(false) }
            }
    }
}
