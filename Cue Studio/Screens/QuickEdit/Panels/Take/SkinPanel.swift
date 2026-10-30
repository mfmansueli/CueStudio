//
//  SkinPanel.swift
//  Cue Studio
//

import SwiftUI

/// Skin (whole video, or the picked clip alone when opened from it), apart from Adjust: Natural and Studio set every control at
/// once (the state beside them says Custom once a control is moved, Off when nothing is on); a row of chips picks the control on
/// the ruler (Smooth, Face light, Anti-shine, and Refine with the smoothing's Texture), each showing its value once it is on; under
/// them its name, value and Reset, and the ruler. ◐ shows the video without Skin while held (the color, filter, background and texts
/// stay). Opening it never applies anything. The rows keep their places whatever is picked, so the panel never jumps; a smoothing
/// made with the first engine says so beside the name, with "Update" to move it to today's.
struct SkinPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @State private var current: LookViewModel.SkinControl = .smoothing

    private var look: LookViewModel { viewModel.look }

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .skin, onReset: reset, compare: look.skinCompare) {
            presets
            controls
            readout
            ruler
        }
        .onAppear(perform: openOnAskedControl)
        // "Try it" from a notification while Skin is already open.
        .onChange(of: look.skinOpensOn) { openOnAskedControl() }
    }

    private var reset: (() -> Void)? {
        guard look.hasSkinSettings else { return nil }
        return { look.resetSkin() }
    }

    /// Opened on one control (a notification's "Try it"): its chip is picked; nothing changes.
    private func openOnAskedControl() {
        guard let start = look.skinOpensOn else { return }
        look.skinOpensOn = nil
        current = start
    }

    // MARK: - Presets

    /// Natural · Studio, and what the controls are as a whole.
    private var presets: some View {
        HStack(spacing: 12) {
            PanelSegmented(
                options: SkinPreset.allCases.map { PanelOption($0, $0.label, key: $0.rawValue) }, selection: pickedPreset, accent: true,
                identifier: "edit.skin.preset"
            ) { look.applySkinPreset($0) }
            .frame(maxWidth: 260)
            stateLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pickedPreset: SkinPreset? {
        if case .preset(let preset) = look.skinState { return preset }
        return nil
    }

    /// "Custom" once a control is moved off a preset, "Off" with nothing on; nothing beside a preset that is exactly itself. The
    /// longest of the words keeps its room, so the presets never move.
    private var stateLabel: some View {
        ZStack(alignment: .leading) {
            Text("Custom", comment: "Video editor › Skin: the controls were moved off a preset").hidden()
            Text("Off", comment: "Video editor › Skin: nothing is on").hidden()
            switch look.skinState {
            case .custom:
                Text("Custom", comment: "Video editor › Skin: the controls were moved off a preset").foregroundStyle(Palette.accText)
            case .off:
                Text("Off", comment: "Video editor › Skin: nothing is on").foregroundStyle(Palette.ink2)
            case .preset:
                EmptyView()
            }
        }
        .font(.system(.footnote, weight: .semibold))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.skin.state")
    }

    // MARK: - Controls

    private var controls: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(LookViewModel.SkinControl.allCases) { control in
                    chip(control)
                }
            }
        }
        .scrollIndicators(.hidden)
        // The row runs to the panel's edges, so a chip doesn't stop short of them when it scrolls.
        .padding(.horizontal, -16)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private func chip(_ control: LookViewModel.SkinControl) -> some View {
        let isPicked = current == control
        let value = look.skinValue(control)
        // Refine shows no number: its Texture always has one, and it matters only with the smoothing on.
        let shown = control != .texture && value != 0 ? PanelValueFormat.plain.text(value) : nil
        return Button {
            current = control
        } label: {
            PanelDialChip(title: control.chipLabel, valueText: shown, isPicked: isPicked)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(control.chipLabel))
        .accessibilityValue(Text(verbatim: control == .texture ? "\(control.label) \(PanelValueFormat.plain.text(value))" : PanelValueFormat.plain.text(value)))
        .accessibilityHint(Text(control.hint))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.skin.\(control.rawValue)")
    }

    // MARK: - Readout and ruler

    /// "Smooth  40" with its own Reset once it is set; for a clip, where the value comes from while the clip hasn't set it; for a
    /// smoothing on the first engine, "Update" at the other end. All on one line when it fits, else the note under the name, and with
    /// large text a line each. A word never breaks and no label is cut.
    private var readout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                nameAndValue
                if let note { noteText(note, lines: 1) }
                resetButton
                Spacer(minLength: 0)
                updateButton
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    nameAndValue
                    if let note { noteText(note, lines: 1) }
                }
                resetButton
                Spacer(minLength: 0)
                updateButton
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            VStack(alignment: .leading, spacing: 4) {
                nameAndValue
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let note { noteText(note, lines: 3) }
                HStack(alignment: .center, spacing: 10) {
                    resetButton
                    Spacer(minLength: 0)
                    updateButton
                }
                .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
            }
        }
    }

    private var nameAndValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(current.label).font(.system(.subheadline, weight: .semibold))
            Text(PanelValueFormat.plain.text(look.skinValue(current)))
                .font(.system(.subheadline, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    /// For a clip, "From the whole video" while it plays with the video's value; for the first engine's smoothing, so.
    private var note: String? {
        if current == .smoothing, look.smoothingUsesFirstEngine {
            return String(localized: "Earlier smoothing", comment: "Video editor › Skin: this smoothing was made with the first, gentler engine")
        }
        guard look.lookClip != nil, !look.clipOverridesSkin(current) else { return nil }
        return String(localized: "From the whole video")
    }

    private func noteText(_ note: String, lines: Int) -> some View {
        Text(note)
            .font(.system(.footnote))
            .foregroundStyle(Palette.ink2)
            .lineLimit(lines)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var resetButton: some View {
        if look.canResetSkin(current) {
            Button("Reset") { look.resetSkin(current) }
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
                .fixedSize()
                .buttonStyle(.plain)
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .contentShape(Rectangle())
                .accessibilityLabel(Text("Reset"))
                .accessibilityValue(Text(current.label))
                .accessibilityIdentifier("edit.skin.resetOne")
        }
    }

    /// The first engine's smoothing moved to today's, as Adjust has Auto at this end: asked for, with Undo.
    @ViewBuilder private var updateButton: some View {
        if look.smoothingUsesFirstEngine {
            Button {
                look.updateSmoothing()
            } label: {
                Label(String(localized: "Update", comment: "Video editor › Skin: moves an older smoothing to the new engine"), systemImage: "sparkles")
                    .font(.system(.subheadline, weight: .semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(minHeight: Metrics.hitTarget)
                    .background(Palette.fill, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text(
                "Moves this smoothing to the new engine, which goes further and lets you refine its texture.",
                comment: "VoiceOver hint of Update in Video editor › Skin"
            ))
            .accessibilityIdentifier("edit.skin.update")
        }
    }

    @ViewBuilder private var ruler: some View {
        if current == .texture, !look.canRefineTexture {
            // A ruler that would do nothing waits, and says why, in the ruler's room.
            PanelNote(text: textureNote)
                .frame(maxWidth: .infinity, minHeight: PanelRulerSlider.height, alignment: .leading)
                .accessibilityIdentifier("edit.skin.textureNote")
        } else {
            PanelRulerSlider(
                label: current.label, value: look.skinValue(current), range: SkinBeautyCalibration.range, format: .plain,
                identifier: "edit.skin.ruler", hint: current.hint, onChange: { look.setSkin(current, $0) }
            )
        }
    }

    private var textureNote: String {
        look.smoothingUsesFirstEngine
            ? String(localized: "Update the smoothing to refine its texture", comment: "Video editor › Skin › Refine, while the smoothing is on the first engine")
            : String(localized: "Turn up Smooth to refine its texture", comment: "Video editor › Skin › Refine, while Smooth is at zero (Smooth as in skin.smooth)")
    }
}
