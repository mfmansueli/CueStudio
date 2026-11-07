//
//  TextScopeChoice.swift
//  Cue Studio
//

import SwiftUI

/// What Text style's look changes, in the header in the subtitle's place: "This title | All 3 texts", always in sight and a tap
/// away (owner, canvas 2 R2, 07/11/2026). It took a row of its own between the tabs and the styles. With "All 3 texts" the
/// timeline lights the three; Motion never follows it (the header then says only this text moves), and while the words are typed
/// it steps aside for the subtitle, so the field and the tabs keep their room over the keyboard.
///
/// Each choice is as wide as its own words (the panel's segmented control shares the width equally, which cut "Alle 2 Texte"
/// in German beside the header's buttons); when the two don't fit there, the header puts its buttons on a row of their own.
struct TextScopeChoice: View {
    let overlays: OverlaysViewModel

    var body: some View {
        HStack(spacing: 3) {
            ForEach(OverlaysViewModel.textStyleScopes, id: \.self) { scope in
                choice(scope)
            }
        }
        .padding(.horizontal, 3)
        .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
        .fixedSize()
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Style applies to"))
    }

    private func choice(_ scope: TextStyleScope) -> some View {
        let isOn = overlays.textStyleScope == scope
        return Button {
            Haptics.selection()
            overlays.textStyleScope = scope
        } label: {
            Text(overlays.textStyleScopeLabel(scope))
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(isOn ? Palette.ink : Palette.ink2)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(minHeight: 30)
                .background(isOn ? Palette.segmentOn : .clear, in: RoundedRectangle(cornerRadius: Metrics.editorSegmentRadius, style: .continuous))
                // Reached from 44 pt of height, the well's own padding included.
                .padding(.vertical, 3)
                .contentShape(Rectangle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("edit.style.scope.\(scope.rawValue)")
    }
}
