//
//  MediaRunStep.swift
//  Cue Studio
//

import SwiftUI

/// Several photos and videos picked together, before they go in: in the order they'll play (the order they were picked), each
/// with how long it shows, "Part…" to choose a video's part, ✕ to leave one out; and what the whole run does: where it
/// starts and ends and, when it doesn't all fit before the end of the video, exactly what is shortened or left out. The
/// video itself never gets longer.
struct MediaRunStep: View {
    @Binding var picks: [MediaPick]
    let run: MediaRun
    let note: String
    let action: String
    let onPart: (UUID) -> Void
    let onBack: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(picks.enumerated()), id: \.element.id) { index, pick in
                        MediaRunRow(
                            pick: pick, number: index + 1, placed: run.placed.first { $0.index == index },
                            onPart: { onPart(pick.id) }, onRemove: { remove(pick.id) }
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            Label(note, systemImage: run.fitsWhole ? "arrow.down.to.line" : "exclamationmark.triangle")
                .font(.system(.footnote, weight: .semibold))
                .foregroundStyle(run.fitsWhole ? Palette.ink : Palette.warnText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("edit.mediaRun.note")
            HStack(spacing: 10) {
                PanelButton(label: String(localized: "Back"), identifier: "edit.mediaRun.back", action: onBack)
                PanelButton(label: action, isPrimary: true, isEnabled: !run.placed.isEmpty, identifier: "edit.mediaRun.confirm", action: onConfirm)
            }
        }
    }

    private func remove(_ id: UUID) {
        guard let pick = picks.first(where: { $0.id == id }) else { return }
        picks.removeAll { $0.id == id }
        // A file another pick doesn't name goes now.
        if !picks.contains(where: { $0.imported.fileName == pick.imported.fileName }) { EditMediaFiles.remove([pick.imported.fileName]) }
    }
}

/// One of the picks: its picture, "Video 2", how long it shows (or that it's shortened or left out), Part… and ✕.
private struct MediaRunRow: View {
    let pick: MediaPick
    let number: Int
    let placed: MediaRun.Placed?
    let onPart: () -> Void
    let onRemove: () -> Void

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var picture: UIImage?

    var body: some View {
        HStack(spacing: 10) {
            Group { if let picture { Image(uiImage: picture).resizable().scaledToFill() } else { Palette.surface2 } }
                .frame(width: 40, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.editorThumbnailRadius, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(pick.isVideo ? String(localized: "Video \(number)") : String(localized: "Photo \(number)"))
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(lengthText)
                    .font(.system(.caption))
                    .foregroundStyle(placed == nil || placed?.isShortened == true ? Palette.warnText : Palette.ink2)
            }
            Spacer(minLength: 0)
            if pick.isVideo {
                Button(String(localized: "Part…"), action: onPart)
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.accText)
                    .frame(minHeight: Metrics.hitTarget)
                    .accessibilityIdentifier("edit.mediaRun.part.\(number)")
            }
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.editorGlyph(EditorGlyph.button, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Leave out"))
            .accessibilityIdentifier("edit.mediaRun.remove.\(number)")
        }
        .padding(.horizontal, 10)
        .editorCard(.plain)
        .task(id: pick.start) {
            picture = await thumbnails.picture(
                of: EditMediaFiles.url(for: pick.imported.fileName), isVideo: pick.isVideo, at: pick.start, maxPixelSize: 160
            )
        }
    }

    private var lengthText: String {
        guard let placed else { return String(localized: "Doesn’t fit before the end") }
        if placed.isShortened {
            return String(localized: "\(DurationText.tenths(placed.span.duration)) of \(DurationText.tenths(pick.wanted)) · shortened to fit")
        }
        return pick.isVideo
            ? String(localized: "Plays \(DurationText.tenths(placed.span.duration))")
            : String(localized: "Shows \(DurationText.tenths(placed.span.duration))")
    }
}
