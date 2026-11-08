//
//  BrandKitEditingSection.swift
//  Cue Studio
//

import SwiftUI

/// The kit editor's Editing and new videos (owner, 08/11/2026: "Meu estilo" is the kit). **Editing** keeps how this video is
/// cleaned up and sounds (Clean up's pauses and gap, how music added starts, Studio Voice), said in words, taken again from this
/// video or removed; putting it on a video readies the tools and cuts nothing. **Use on new videos**: a video edited for the
/// first time opens in this kit (one kit at a time; saving it here takes the mark off another).
struct BrandKitEditingSection: View {
    @Binding var kit: BrandKit
    /// The video open in the editor, where Editing is taken from.
    let edit: TakeEdit
    /// The kit new videos open in now, if another.
    let otherNewVideoKit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            editing
            newVideos
        }
    }

    private var editing: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelRowLabel(label: String(localized: "Editing"))
            if let kept = kit.editing {
                let said = BrandViewModel.said(kept)
                VStack(alignment: .leading, spacing: 2) {
                    Text(said.pauses)
                    Text(said.music)
                    Text(String(localized: "Studio Voice: \(said.voice)"))
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                ReflowStack(spacing: 8) {
                    takeFromVideo
                    PanelButton(label: String(localized: "Remove"), systemImage: "xmark", identifier: "edit.brand.noEditing") { kit.editing = nil }
                }
            } else {
                PanelNote(
                    text: String(localized: "Keep how you clean up and set the sound: pauses, music level, Studio Voice. Nothing is cut until you tap Remove."),
                    teaches: true
                )
                takeFromVideo
            }
        }
    }

    private var takeFromVideo: some View {
        PanelButton(label: String(localized: "Take from this video"), systemImage: "arrow.down.doc", identifier: "edit.brand.editingFromVideo") {
            kit.editing = BrandKitEditing(of: edit)
        }
    }

    private var newVideos: some View {
        PanelToggleRow(
            label: String(localized: "Use on new videos"),
            detail: otherNewVideoKit.map { String(localized: "Instead of \($0) · Undo takes it off one video") }
                ?? String(localized: "Videos you edit for the first time open in this kit · Undo takes it off one video"),
            isOn: kit.usesOnNewVideos == true, identifier: "edit.brand.newVideos"
        ) { kit.usesOnNewVideos = kit.usesOnNewVideos == true ? nil : true }
    }
}
