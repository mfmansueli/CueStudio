//
//  SettingsPrompterView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter: a preview that stays on top (the real text window, scaled down: `PrompterPreviewCard`) and, under it, how the
/// text reads and looks, over the sky, for Selfie and Studio. The recorder's Aa has the same rows in tabs, over the settings of that
/// recording (`AaSettingsSheet`).
struct SettingsPrompterView: View {
    let bindings: SettingsBindings

    @State private var screenScale = ReadingLinePercent.standard

    var body: some View {
        var bindings = bindings
        bindings.screenScale = screenScale
        return List {
            Section {
                SettingsEntryRows(entries: [.followVoice, .speed, .countdownBeforePlay, .aiCoach], bindings: bindings)
            } header: {
                CueSectionHeader("Reading")
            }
            Section {
                SettingsEntryRows(entries: [.textSize, .font, .lineSpacing, .alignment, .textColor], bindings: bindings)
            } header: {
                CueSectionHeader("Text")
            }
            Section {
                SettingsEntryRows(entries: [.showReadingLine, .readingLinePosition, .resetReadingLine], bindings: bindings)
            } header: {
                CueSectionHeader("Reading line")
            } footer: {
                Text(readingLineFooter)
            }
            Section {
                SettingsEntryRows(entries: [.windowHeight, .windowWidth, .sideMargins], bindings: bindings)
            } header: {
                CueSectionHeader("Text window · Selfie")
            } footer: {
                Text("Or drag the ⌟ handle on the recorder.")
            }
            Section {
                SettingsEntryRows(entries: [.backgroundOpacity, .cameraBlur, .socialSafeZone], bindings: bindings)
            } header: {
                CueSectionHeader("Over the camera · Selfie")
            } footer: {
                Text("Changes the preview only, never the recording.")
            }
            Section {
                row(.studioBackground, bindings)
            } header: {
                CueSectionHeader("Studio")
            }
            Section {
                SettingsEntryRows(entries: [.mirrorText, .flipVertically], bindings: bindings)
            } header: {
                CueSectionHeader("Rigs")
            } footer: {
                Text("Studio uses these too. The screen stays on while the prompter is open.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("settings.prompterPage")
        .background { SkyBackdrop() }
        .safeAreaInset(edge: .top, spacing: 8) {
            PrompterPreviewCard(settings: bindings.prompter.wrappedValue)
                .padding(.horizontal, Metrics.gutter)
        }
        .onGeometryChange(for: ReadingLinePercent.self) { proxy in
            ReadingLinePercent(
                screenHeight: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom, lensY: proxy.safeAreaInsets.top / 2
            )
        } action: { screenScale = $0 }
        .navigationTitle("Prompter")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// "118 pt below the camera · recommended." while the line is where Cue puts it, else how to move it.
    private var readingLineFooter: String {
        guard bindings.prompter.wrappedValue.readingLineOffset == nil else { return String(localized: "Or drag the line on the recorder.") }
        return String(localized: "\(Int(ReadingLayout.recommendedFrontOffset)) pt below the camera · recommended.")
    }

    private func row(_ entry: SettingsEntry, _ bindings: SettingsBindings) -> some View {
        SettingsEntryRow(entry: entry, bindings: bindings)
    }
}
