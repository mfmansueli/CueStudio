//
//  CaptionLineChoiceDialog.swift
//  Cue Studio
//

import SwiftUI

/// Place or Zoom for a caption picked on the timeline (`CaptionsViewModel+LineChoice`): a system dialog that names the line, its
/// time and what it has now, so what changes is clear before choosing.
struct CaptionLineChoiceDialog: ViewModifier {
    @Bindable var captions: CaptionsViewModel

    func body(content: Content) -> some View {
        content.confirmationDialog(
            captions.lineChoice.map(captions.lineChoiceTitle) ?? "",
            isPresented: Binding(get: { captions.lineChoice != nil }, set: { if !$0 { captions.lineChoice = nil } }),
            titleVisibility: .visible,
            presenting: captions.lineChoice
        ) { choice in
            switch choice.kind {
            case .place:
                ForEach(CaptionPlace.allCases) { place in
                    Button(place.label) { captions.chooseLinePlace(place, for: choice) }
                        .accessibilityIdentifier("edit.lineChoice.place.\(place.id)")
                }
            case .zoom:
                Button("No zoom") { captions.chooseLineZoom(nil, for: choice) }
                    .accessibilityIdentifier("edit.lineChoice.zoom.none")
                ForEach(PhraseZoom.Strength.allCases) { strength in
                    Button(strength.label) { captions.chooseLineZoom(strength, for: choice) }
                        .accessibilityIdentifier("edit.lineChoice.zoom.\(strength.rawValue)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { choice in
            Text(captions.lineChoiceMessage(choice))
        }
    }
}
