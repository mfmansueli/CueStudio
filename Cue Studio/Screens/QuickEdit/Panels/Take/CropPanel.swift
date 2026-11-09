//
//  CropPanel.swift
//  Cue Studio
//

import SwiftUI

/// Aspect ratio: the format for where you post (9:16, 4:5, 1:1, 16:9) in low tiles, Fill or Fit, and Follow face, all in view when the
/// panel opens (F16). The preview takes the new shape at once; dragging the video moves a Fill crop. Follow face moves it with the face, at
/// a pace, and only when the creator turns it on. Reset (the header) goes back to the video as recorded. When the format's crop leaves
/// fewer pixels than the quality, a line says what the file will be ("This format exports at 606×1080 · never enlarged"). Safe zones, at
/// the end, shows where an app's buttons cover the video and switches the app (`LookViewModel+SafeGuide`).
struct CropPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .crop) {
            PanelTiles(
                options: AspectRatio.allCases.map { PanelOption($0, $0.label, systemImage: Self.symbol($0), key: $0.rawValue) },
                selection: viewModel.edit.aspect, isCompact: true, identifier: "edit.crop"
            ) { viewModel.look.setAspect($0) }
            if let size = viewModel.look.exportSizeNote {
                PanelNote(text: size)
                    .accessibilityIdentifier("edit.crop.exportSize")
            }
            PanelSegmented(
                label: String(localized: "Framing"), options: CropFit.allCases.map { PanelOption($0, $0.label) },
                selection: viewModel.edit.cropFit, identifier: "edit.crop.fit"
            ) { viewModel.look.setCropFit($0) }
            PanelToggleRow(
                label: String(localized: "Follow face"), detail: String(localized: "The frame keeps your face in view as you move"),
                isOn: viewModel.look.followsFace, identifier: "edit.crop.followFace"
            ) { viewModel.look.setFollowsFace(!viewModel.look.followsFace) }
                .disabled(!viewModel.look.canFollowFace)
            if viewModel.look.followsFace {
                PanelSegmented(
                    label: String(localized: "Pace"), options: FollowPace.allCases.map { PanelOption($0, $0.label) },
                    selection: viewModel.edit.faceFollow?.pace ?? .natural, identifier: "edit.crop.followPace"
                ) { viewModel.look.setFollowPace($0) }
            }
            if let note = viewModel.look.faceFollowNote {
                PanelNote(text: note)
                    .accessibilityIdentifier("edit.crop.followNote")
            }
            safeZones
        }
    }

    /// Safe zones: the guide over the preview, on for every video once turned on; the app it shows is this video's (the captions
    /// keep to it), opening on the script's platform.
    @ViewBuilder
    private var safeZones: some View {
        let look = viewModel.look
        PanelToggleRow(
            label: String(localized: "Safe zone"), detail: String(localized: "Where an app’s buttons cover your video · approximate"),
            isOn: look.showsSafeGuide, identifier: "edit.crop.safeGuide"
        ) { look.setShowsSafeGuide(!look.showsSafeGuide) }
        if look.showsSafeGuide {
            PanelChips(
                options: look.safeGuideOptions.map { PanelOption($0, $0.label, key: $0.key) },
                selection: look.safeGuide, identifier: "edit.crop.safeGuideApp"
            ) { look.pickSafeGuide($0) }
            PanelNote(text: look.safeGuideNote)
                .accessibilityIdentifier("edit.crop.safeGuideNote")
        }
    }

    private static func symbol(_ aspect: AspectRatio) -> String {
        switch aspect {
        // Each shape its own symbol, drawn in its proportion (9:16 taller than 4:5).
        case .portrait: "rectangle.ratio.9.to.16"
        case .vertical: "rectangle.ratio.3.to.4"
        case .square: "square"
        case .landscape: "rectangle.ratio.16.to.9"
        }
    }
}
