//
//  MusicTrackRow.swift
//  Cue Studio
//

import SwiftUI

/// One library track: tap the row to hear it from its start (a spinner while its file is fetched, ■ while it plays, a second tap
/// stops it), ⓘ for what it covers of the video, its licence and the sample libraries it plays, + to add it at the playhead. At the accessibility
/// text sizes the words take the card's width: ▶ above them, ⓘ and + under them.
struct MusicTrackRow: View {
    let library: MusicLibraryViewModel
    let track: CueTrack
    let onAdd: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isPlaying: Bool { library.isPlaying(track) }
    private var isPreparing: Bool { library.preparing == track }
    private var isDetailed: Bool { library.detailed == track }
    private var isAdding: Bool { library.adding == track }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if typeSize.isAccessibilitySize {
                hearButton
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    infoButton
                    addButton
                }
                .frame(height: Metrics.hitTarget)
            } else {
                HStack(spacing: 0) {
                    hearButton
                    infoButton
                    addButton
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if isDetailed { details }
        }
        .foregroundStyle(Palette.ink)
        .editorCard(isPlaying || isPreparing ? .picked : .plain)
    }

    private var infoButton: some View {
        Button {
            withAnimation(.snappy) { library.detailed = isDetailed ? nil : track }
        } label: {
            Image(systemName: isDetailed ? "info.circle.fill" : "info.circle")
                .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: Metrics.hitTarget)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("About \(track.title)"))
        .accessibilityIdentifier("edit.library.info.\(track.rawValue)")
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Group {
                if isAdding {
                    ProgressView().tint(Palette.ink)
                } else {
                    Image(systemName: "plus")
                        .font(.system(.body, weight: .bold))
                        .foregroundStyle(Palette.accText)
                }
            }
            .frame(width: Metrics.hitTarget)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(library.adding != nil)
        .accessibilityLabel(Text("Add \(track.title)"))
        .accessibilityIdentifier("edit.library.add.\(track.rawValue)")
    }

    private var hearButton: some View {
        Button { library.togglePreview(track) } label: {
            ReflowStack(spacing: 12) {
                ZStack {
                    if isPreparing {
                        ProgressView().tint(Palette.Editor.laneMusicInk)
                    } else {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                            .foregroundStyle(Palette.Editor.laneMusicInk)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 38, height: 38)
                .background(Palette.Editor.laneMusic, in: RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(.subheadline, weight: .semibold))
                    Text("\(track.style) · \(DurationText.clock(track.duration))")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                    if library.failed == track {
                        Text("Can’t play it · Tap to try again")
                            .font(.caption)
                            .foregroundStyle(Palette.warnText)
                    } else {
                        Text(track.isForTalking ? String(localized: "\(track.use) · For talking") : track.use)
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isPlaying || isPreparing ? "Stop \(track.title)" : "Hear \(track.title)"))
        .accessibilityValue(Text([track.style, DurationText.clock(track.duration), track.use].joined(separator: ", ")))
        .accessibilityIdentifier("edit.library.play.\(track.rawValue)")
    }

    /// What it covers of the video, its mood and pace, and where it comes from: who made it, what may be done with it, the credit,
    /// the sample libraries its instruments come from.
    private var details: some View {
        let licence = track.licence
        return VStack(alignment: .leading, spacing: 6) {
            Divider().overlay(Palette.separator)
            Text("\(library.coverage(of: track)) · \(track.mood.label) · \(Int(track.tempo.rounded())) BPM")
                .font(.system(.caption, weight: .semibold))
            Text(licence.origin)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
            Text(licence.terms)
                .font(.caption)
            Text(licence.attribution)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
            if let libraries = licence.libraries {
                Text(libraries)
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("edit.library.details.\(track.rawValue)")
    }
}
