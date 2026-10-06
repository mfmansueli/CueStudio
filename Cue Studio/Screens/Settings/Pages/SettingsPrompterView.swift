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

    @State private var screenScale = ReadingLinePercent.standard

    private var showsSelfie: Bool { activeMode != .studio }
    private var showsStudio: Bool { activeMode != .selfie }

    var body: some View {
        var bindings = bindings
        bindings.screenScale = screenScale
        return List {
            Section {
                row(.followVoice, bindings)
                row(.speed, bindings)
                row(.countdownBeforePlay, bindings)
                row(.aiCoach, bindings)
            } header: {
                CueSectionHeader("Reading")
            }
            Section {
                row(.textSize, bindings)
                row(.font, bindings)
                row(.lineSpacing, bindings)
                row(.alignment, bindings)
                row(.textColor, bindings)
            } header: {
                CueSectionHeader("Text")
            }
            Section {
                row(.showReadingLine, bindings)
                row(.readingLinePosition, bindings)
                row(.resetReadingLine, bindings)
            } header: {
                CueSectionHeader("Reading line")
            } footer: {
                Text(readingLineFooter)
            }
            if showsSelfie {
                Section {
                    row(.windowHeight, bindings)
                    row(.windowWidth, bindings)
                    row(.sideMargins, bindings)
                } header: {
                    CueSectionHeader("Text window · Selfie")
                } footer: {
                    Text("Or drag the ⌟ handle on the recorder.")
                }
                Section {
                    row(.backgroundOpacity, bindings)
                    row(.cameraBlur, bindings)
                    row(.socialSafeZone, bindings)
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
                row(.mirrorText, bindings)
                row(.flipVertically, bindings)
            } header: {
                CueSectionHeader("Rigs")
            } footer: {
                Text("Studio uses these too. The screen stays on while the prompter is open.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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
