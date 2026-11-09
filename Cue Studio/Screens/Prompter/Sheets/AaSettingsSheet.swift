//
//  AaSettingsSheet.swift
//  Cue Studio
//

import SwiftUI

/// "Aa" in the recorder, Selfie and Studio: one sheet with tabs on top (the system's segmented control) and a short page under each, made
/// of Settings › Prompter's rows over the settings of this recording (`AaTab`). Selfie: Reading | Text | Window | Camera; Studio: Reading |
/// Text | Studio. The countdown is in the Camera sheet and ••• in Selfie, so only Studio's Aa has it.
///
/// What changes here shows on the text behind the sheet as the creator makes it, and is kept like a change in Settings when the sheet
/// closes (`PrompterViewModel.rememberPrompterSettings`): no "make default". The text settings are the same in both modes; the window and
/// the camera are Selfie's, the background and the line Studio's. The sheet is no taller than `maxHeight`, so the text window (Selfie) or the
/// reading line (Studio) stays in sight.
struct AaSettingsSheet: View {
    let mode: PrompterMode
    /// Tallest the sheet may grow, so the words above it stay readable. `nil` lets it go from medium to large.
    var maxHeight: CGFloat?
    /// The recorder's screen and lens: the reading line's percent is of the screen, not of this sheet.
    var screen: ReadingLinePercent = .standard
    /// The safe zone the recording's network gives this frame (Selfie's Window tab offers it or Custom); nil when only Custom fits (1:1).
    var networkZone: SafeZoneChoice?
    /// The frame has a safe zone at all (not 16:9).
    var hasSafeZone = true

    @Environment(SessionSetupService.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var tab: AaTab = .reading

    var body: some View {
        @Bindable var session = session
        var bindings = SettingsBindings(prompter: $session.prompter, camera: $session.camera)
        bindings.screenScale = screen
        return NavigationStack {
            VStack(spacing: 0) {
                header
                page(bindings)
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { SettingsDestination(route: $0, bindings: bindings) }
        }
        .presentationDetents(maxHeight.map { [.height($0)] } ?? [.medium, .large])
        .presentationBackground(Palette.surface)
        .presentationBackgroundInteraction(maxHeight.map { .enabled(upThrough: .height($0)) } ?? .enabled)
    }

    // MARK: - Header

    /// The tabs and the close button, on one row: the page under them is all the sheet scrolls.
    private var header: some View {
        HStack(spacing: 12) {
            Picker("Display settings", selection: $tab) {
                ForEach(AaTab.tabs(for: mode)) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("display.tabs")
            Button { dismiss() } label: {
                Image(systemName: "xmark").cueFont(.body, weight: .semibold)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(Text("Close"))
            .accessibilityIdentifier("display.doneButton")
        }
        .padding(EdgeInsets(top: 16, leading: Metrics.gutter, bottom: 4, trailing: Metrics.gutter))
    }

    // MARK: - Pages

    private func page(_ bindings: SettingsBindings) -> some View {
        List {
            switch tab {
            case .reading:
                section(nil, [.followVoice, .speed, .aiCoach], bindings)
            case .text:
                section(nil, [.textSize, .font, .lineSpacing, .alignment, .textColor], bindings)
            case .window:
                windowPage(bindings)
            case .camera:
                section(String(localized: "Over the camera"), [.backgroundOpacity, .cameraBlur], bindings,
                        footer: String(localized: "Changes the preview only, never the recording."))
            case .studio:
                studioPage(bindings)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 4, for: .scrollContent)
        .accessibilityIdentifier("settings.prompterPage")
    }

    @ViewBuilder
    private func windowPage(_ bindings: SettingsBindings) -> some View {
        section(String(localized: "Text window"), [.windowHeight, .windowWidth, .sideMargins], bindings,
                footer: String(localized: "Or drag the ⌟ handle on the recorder."))
        section(String(localized: "Reading line"), [.showReadingLine, .readingLinePosition, .resetReadingLine], bindings,
                footer: readingLineFooter(bindings))
        section(String(localized: "Rigs"), [.mirrorText, .flipVertically], bindings)
        if hasSafeZone {
            AaSafeZoneSection(networkZone: networkZone)
        }
    }

    @ViewBuilder
    private func studioPage(_ bindings: SettingsBindings) -> some View {
        Section {
            SettingsEntryRow(entry: .showReadingLine, bindings: bindings, position: .first)
            SettingsSliderRow(
                title: String(localized: "Position"),
                valueText: bindings.prompter.wrappedValue.guidePosition.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                valueSamples: ["70%"], value: bindings.prompter.guidePosition, range: PrompterSettings.guideRange, step: 0.01,
                minLabel: String(localized: "Top"), maxLabel: String(localized: "Bottom"), identifier: "display.studioReadingLine"
            )
            .cardRowBackground(position: .last)
        } header: {
            CueSectionHeader("Reading line")
        }
        section(String(localized: "Studio"), [.studioBackground, .sideMargins, .countdownBeforePlay], bindings)
        section(String(localized: "Rigs"), [.mirrorText, .flipVertically], bindings)
    }

    private func section(_ title: String?, _ entries: [SettingsEntry], _ bindings: SettingsBindings, footer: String? = nil) -> some View {
        Section {
            SettingsEntryRows(entries: entries, bindings: bindings)
        } header: {
            if let title { CueSectionHeader(verbatim: title) }
        } footer: {
            if let footer { Text(footer) }
        }
    }

    /// "118 pt below the camera · recommended." while the line is where Cue puts it, else how to move it.
    private func readingLineFooter(_ bindings: SettingsBindings) -> String {
        guard bindings.prompter.wrappedValue.readingLineOffset == nil else { return String(localized: "Or drag the line on the recorder.") }
        return String(localized: "\(Int(ReadingLayout.recommendedFrontOffset)) pt below the camera · recommended.")
    }
}

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview()
    Color.black.sheet(isPresented: .constant(true)) {
        AaSettingsSheet(mode: .selfie, networkZone: .platform(.tiktok))
    }
    .environment(viewModel.session)
    .previewEnvironment()
}
#endif
