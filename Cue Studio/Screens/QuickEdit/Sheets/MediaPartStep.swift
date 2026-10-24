//
//  MediaPartStep.swift
//  Cue Studio
//

import SwiftUI

/// One video's part, chosen before it goes in: the video where the part starts (▶ plays the part), the strip with the window
/// over what goes in, "Uses 0:03.0 to 0:08.0 of 0:20.0 · 5.0 s", and where it lands in the video. A slot to fill (Replace)
/// keeps its length: only which part fills it changes.
struct MediaPartStep: View {
    @Binding var pick: MediaPick
    /// The longest the part can be: the room in the video, or the slot to fill (then the length is fixed).
    let longest: TimeInterval
    var isFixedLength = false
    /// Where it lands, under the strip.
    let note: String
    let action: String
    var back = String(localized: "Back")
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        let fileLength = pick.fileLength ?? 0
        VStack(alignment: .leading, spacing: 12) {
            MediaPartPreview(
                url: EditMediaFiles.url(for: pick.imported.fileName), aspect: pick.imported.aspect, start: pick.start, length: partLength
            )
            .frame(maxWidth: .infinity)
            MediaPartStrip(
                url: EditMediaFiles.url(for: pick.imported.fileName), fileLength: fileLength,
                start: $pick.start, length: lengthBinding,
                lengthRange: isFixedLength ? nil : MediaOverlay.minimumDuration...max(MediaOverlay.minimumDuration, min(longest, fileLength))
            )
            VStack(alignment: .leading, spacing: 4) {
                PanelRowLabel(
                    label: String(localized: "Uses \(DurationText.editor(pick.start)) to \(DurationText.editor(pick.start + partLength)) of \(DurationText.editor(fileLength))"),
                    detail: DurationText.tenths(partLength)
                )
                .accessibilityIdentifier("edit.mediaPart.uses")
                Label(note, systemImage: "arrow.down.to.line")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("edit.mediaPart.note")
            }
            HStack(spacing: 10) {
                PanelButton(label: back, identifier: "edit.mediaPart.back", action: onBack)
                PanelButton(label: action, isPrimary: true, identifier: "edit.mediaPart.confirm", action: onConfirm)
            }
        }
        .onAppear { fitLength() }
    }

    /// How long the part is now.
    private var partLength: TimeInterval {
        min(pick.length ?? longest, max(0, (pick.fileLength ?? 0) - pick.start), longest)
    }

    private var lengthBinding: Binding<TimeInterval> {
        Binding(get: { partLength }, set: { pick.length = $0 })
    }

    /// The window starts as long as fits: the whole video, or the room (the slot) when that's shorter.
    private func fitLength() {
        guard let fileLength = pick.fileLength else { return }
        pick.length = min(pick.length ?? fileLength, longest, fileLength)
        pick.start = min(pick.start, max(0, fileLength - (pick.length ?? fileLength)))
    }
}
