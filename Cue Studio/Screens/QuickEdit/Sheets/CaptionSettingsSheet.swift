//
//  CaptionSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Secondary controls, saved in the recipe. The captions' text and script remain independent.
struct CaptionSettingsSheet: View {
    @Bindable var viewModel: QuickEditViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: String(localized: "Caption settings")) { dismiss() }
                if let settings = viewModel.edit.captionCollection {
                    ValueSlider(title: String(localized: "Size"),
                                valueText: settings.clampedScale.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                                value: binding(\.sizeScale, default: 1), range: CaptionSettings.sizeRange, step: 0.05, identifier: "edit.captionSize")
                    Picker("Position", selection: Binding(
                        get: { viewModel.edit.captionPosition },
                        set: { position in
                            viewModel.change { $0.captionPosition = position }
                            viewModel.updateCaptionSettings { $0.center = nil }
                        }
                    )) {
                        ForEach(CaptionPosition.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    ValueSlider(title: String(localized: "Horizontal position"), valueText: center.x.formatted(.percent.locale(.interface)),
                                value: positionBinding(horizontal: true), range: 0.1...0.9, step: 0.01, identifier: "edit.captionX")
                    ValueSlider(title: String(localized: "Vertical position"), valueText: center.y.formatted(.percent.locale(.interface)),
                                value: positionBinding(horizontal: false), range: 0.1...0.9, step: 0.01, identifier: "edit.captionY")
                    Text("Highlight color").font(.subheadline)
                    HStack {
                        ForEach(CaptionAccent.allCases) { accent in
                            let parts = accent.components
                            Button {
                                viewModel.updateCaptionSettings { $0.accent = accent }
                            } label: {
                                Circle().fill(Color(red: parts.red, green: parts.green, blue: parts.blue))
                                    .frame(width: Metrics.chipHeight, height: Metrics.chipHeight)
                                    .overlay(Circle().strokeBorder(settings.highlightColor == accent ? Palette.ink : .clear, lineWidth: 2))
                                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(accent.label))
                            .accessibilityAddTraits(settings.highlightColor == accent ? .isSelected : [])
                            .accessibilityIdentifier("edit.captionAccent.\(accent.rawValue)")
                        }
                    }
                    Toggle("Follow spoken words", isOn: binding(\.followsWords, default: true))
                        .tint(Palette.success)
                        .disabled(!viewModel.edit.captions.contains(where: \.hasWordTiming))
                        .accessibilityIdentifier("edit.captionFollowsWords")
                    if viewModel.linesWithoutWordTiming > 0 {
                        Text("\(viewModel.linesWithoutWordTiming) lines show whole: their words don't have their own times.")
                            .font(.caption).foregroundStyle(Palette.warn)
                    }
                    Button("Restore style defaults") { viewModel.resetCaptionTheme() }
                        .buttonStyle(.cueSecondary(.regular))
                        .accessibilityIdentifier("edit.captionReset")
                }
            }
            .padding(Metrics.gutter)
        }
        .background(Palette.surface)
        .presentationDetents([.medium, .large])
        .onAppear { viewModel.beginChange() }
        .onDisappear { viewModel.endChange() }
    }

    private var center: OverlayPoint {
        viewModel.edit.captionCollection?.center ?? OverlayPoint(x: 0.5, y: viewModel.edit.captionPosition.verticalFraction)
    }

    private func binding<Value>(_ key: WritableKeyPath<CaptionSettings, Value>, default value: Value) -> Binding<Value> {
        Binding(get: { viewModel.edit.captionCollection?[keyPath: key] ?? value },
                set: { newValue in viewModel.updateCaptionSettings { $0[keyPath: key] = newValue } })
    }

    private func positionBinding(horizontal: Bool) -> Binding<Double> {
        Binding(get: { horizontal ? center.x : center.y }, set: { value in
            var point = center
            if horizontal { point.x = value } else { point.y = value }
            viewModel.updateCaptionSettings { $0.center = point }
        })
    }
}
