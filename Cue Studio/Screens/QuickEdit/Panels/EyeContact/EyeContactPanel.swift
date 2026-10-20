//
//  EyeContactPanel.swift
//  Cue Studio
//

import SwiftUI

/// ✦ Smart › Eye Contact: on or off, how strong, Before/After (a tap, no holding), and an honest line on where it stands: finding
/// the eyes (with Cancel), ready where the playhead is, how much of the video it corrects once all is analyzed, or why it can't.
/// Off by default; Reset brings the strength back to moderate; "✦ Smart" goes back to the other tools.
struct EyeContactPanel: View {
    let viewModel: QuickEditViewModel

    /// Before/After in the preview.
    private enum Shown: Hashable { case after, before }

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .eyeContact, onReset: reset) {
            toggle
            if viewModel.eyeContactIsOn {
                strength
                comparison
            }
            status
            PanelButton(label: String(localized: "✦ Smart"), systemImage: "chevron.backward", identifier: "edit.eyeContact.back") {
                viewModel.panel = .smart
            }
        }
    }

    /// Reset, once the strength isn't the moderate one.
    private var reset: (() -> Void)? {
        let moved = abs(viewModel.eyeContactStrength - EyeContactSettings.defaultStrength * 100) > 0.5
        guard viewModel.eyeContactIsOn, moved else { return nil }
        return viewModel.resetEyeContactStrength
    }

    private var toggle: some View {
        PanelToggleRow(
            label: String(localized: "Eye Contact", comment: "✦ Smart tool that moves the creator's eyes toward the lens"),
            detail: String(localized: "Adjusts your gaze toward the camera"),
            isOn: viewModel.eyeContactIsOn, identifier: "edit.eyeContact.toggle", onToggle: viewModel.toggleEyeContact
        )
    }

    private var strength: some View {
        let range: ClosedRange<Double> = (EyeContactSettings.strengthRange.lowerBound * 100)...(EyeContactSettings.strengthRange.upperBound * 100)
        return PanelSlider(
            label: String(localized: "Strength"), value: viewModel.eyeContactStrength, range: range, step: 5,
            defaultValue: EyeContactSettings.defaultStrength * 100, format: .percent, identifier: "edit.eyeContact.strength",
            onChange: viewModel.setEyeContactStrength,
            onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
        )
    }

    private var comparison: some View {
        let options: [PanelOption<Shown>] = [
            PanelOption(.after, String(localized: "After"), key: "after"),
            PanelOption(.before, String(localized: "Before"), key: "before"),
        ]
        let shown: Shown = viewModel.comparesEyeContact ? .before : .after
        return PanelSegmented(options: options, selection: shown, identifier: "edit.eyeContact.compare") { picked in
            if picked != shown { viewModel.toggleEyeContactComparison() }
        }
    }

    @ViewBuilder private var status: some View {
        let state = viewModel.eyeContactState
        if let note = state.note {
            PanelNote(text: note)
                .accessibilityIdentifier("edit.eyeContact.status")
        }
        if state.isWorking {
            PanelButton(label: String(localized: "Cancel"), systemImage: "xmark", identifier: "edit.eyeContact.cancel", action: viewModel.cancelEyeContact)
        }
    }
}
