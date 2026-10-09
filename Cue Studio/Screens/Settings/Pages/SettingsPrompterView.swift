//
//  SettingsPrompterView.swift
//  Cue Studio
//

import SwiftUI

/// Settings › Prompter: a preview that stays on top and, under it, how the text reads and looks, over the sky. The same page opens from
/// Aa in the recorder, over the settings of that recording (`bindings`), as a sheet like the camera's: no preview there (the real text
/// window is right behind the sheet) and the sheet's still background instead of the sky.
struct SettingsPrompterView: View {
    let bindings: SettingsBindings
    /// The mode of the recording the page opened from: the "· Selfie" sections show with Selfie, "Studio" with Studio. Settings
    /// itself has no mode and shows both.
    var activeMode: PrompterMode?
    /// Opened from the recorder's Aa, as a sheet over the camera.
    var isRecorderSheet = false
    /// The recorder's screen, when the page is a sheet over it: the sheet is shorter than the screen, so its own height can't say where a
    /// percent of the screen is (the reading line slider read 43% for the recommended line and moved it nowhere).
    var screen: ReadingLinePercent?

    @State private var screenScale = ReadingLinePercent.standard

    private var showsSelfie: Bool { activeMode != .studio }
    private var showsStudio: Bool { activeMode != .selfie }

    var body: some View {
        var bindings = bindings
        bindings.screenScale = screen ?? screenScale
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
            if showsSelfie {
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
            }
            if showsStudio {
                Section {
                    row(.studioBackground, bindings)
                } header: {
                    CueSectionHeader("Studio")
                }
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
        .background {
            if !isRecorderSheet { SkyBackdrop() }
        }
        .safeAreaInset(edge: .top, spacing: isRecorderSheet ? 0 : 8) {
            if !isRecorderSheet {
                PrompterPreviewCard(settings: bindings.prompter.wrappedValue)
                    .padding(.horizontal, Metrics.gutter)
            }
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
