//
//  CropPanel.swift
//  Cue Studio
//

import SwiftUI

/// Crop: the format for where you post (9:16, 4:5, 1:1, 16:9) and Fill or Fit. The preview takes
/// the new shape at once; dragging the video moves a Fill crop.
struct CropPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .crop) {
            PanelTiles(
                options: AspectRatio.allCases.map { PanelOption($0, $0.label, systemImage: Self.symbol($0), key: $0.rawValue) },
                selection: viewModel.edit.aspect, identifier: "edit.crop"
            ) { viewModel.setAspect($0) }
            PanelSegmented(
                label: String(localized: "Framing"), options: CropFit.allCases.map { PanelOption($0, $0.label) },
                selection: viewModel.edit.cropFit, identifier: "edit.crop.fit"
            ) { viewModel.setCropFit($0) }
        }
    }

    private static func symbol(_ aspect: AspectRatio) -> String {
        switch aspect {
        case .portrait: "rectangle.portrait"
        case .vertical: "rectangle.portrait"
        case .square: "square"
        case .landscape: "rectangle"
        }
    }
}
