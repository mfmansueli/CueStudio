//
//  AddMediaSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Add photo or video": where the pick goes first (`MediaModeCards`: at the same time as the video, beside it in a split
/// screen, in a window or over all of it; or in the sequence, adding time), said with the place and length before picking;
/// then the photo library right in the sheet. Over the video, several can be picked at once, in order, and go one after the
/// other from the playhead. Before anything goes in, a video's part is chosen (`MediaPartStep`), and several picks are
/// reviewed together (`MediaRunStep`), with what is shortened or left out to fit said up front. In the sequence, the
/// creator's other takes come first, for a montage of several takes. "Your library" (`MediaLibrarySection`) in place of
/// Photos offers what the creator kept to reuse: picked the same way, a logo straight on.
struct AddMediaSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var picks: [MediaPick] = []
    @State private var step: Step = .choose
    @State private var detent: PresentationDetent = .medium
    /// The picks went in: nothing to throw away when the sheet goes.
    @State private var isDone = false

    private enum Step: Equatable {
        case choose
        case part(UUID)
        case review
    }

    private var overlays: OverlaysViewModel { viewModel.overlays }
    private var mode: MediaInsertMode { overlays.mediaInsertMode }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch step {
            case .choose:
                choose
            case .part(let id):
                SheetHeader(title: String(localized: "Pick the part"), subtitle: mode.label)
                if let index = picks.firstIndex(where: { $0.id == id }) {
                    MediaPartStep(
                        pick: $picks[index], longest: longest(for: picks[index]), note: partNote(for: picks[index]),
                        action: picks.count > 1 ? String(localized: "Done") : mode.action,
                        onBack: { leavePart() },
                        onConfirm: { confirmPart() }
                    )
                }
            case .review:
                SheetHeader(title: String(localized: "\(picks.count) to add"), subtitle: mode.label)
                let run = overlays.run(of: picks, as: mode)
                MediaRunStep(
                    picks: $picks, run: run, note: overlays.runNote(run, count: picks.count), action: mode.action,
                    onPart: { step = .part($0) }, onBack: { discardPicks() }, onConfirm: { add() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .cueSheetChrome()
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onDisappear {
            if !isDone { EditMediaFiles.remove(Set(picks.map(\.imported.fileName))) }
        }
    }

    // MARK: - Where it goes, and the library

    private var choose: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: String(localized: "Add photo or video"))
            MediaModeCards(selection: Binding(get: { mode }, set: { pick(mode: $0) }))
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.explanation)
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("edit.mediaModeExplanation")
                // Where it lands and for how long, before picking.
                Label(insertionNote, systemImage: "arrow.down.to.line")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(insertionNote))
                    .accessibilityIdentifier("edit.mediaInsertionNote")
            }
            .fixedSize(horizontal: false, vertical: true)
            if mode == .sequence, !viewModel.clips.addableTakes.isEmpty {
                TakeRow(takes: viewModel.clips.addableTakes) { take in
                    Task {
                        await viewModel.clips.addClip(from: take)
                        isDone = true
                        dismiss()
                    }
                }
            }
            PanelSegmented(
                options: [PanelOption(false, String(localized: "Photos"), key: "photos"), PanelOption(true, String(localized: "Your library"), key: "library")],
                selection: viewModel.brand.showsLibrary, identifier: "edit.mediaSource"
            ) { viewModel.brand.showsLibrary = $0 }
            if viewModel.brand.showsLibrary {
                MediaLibrarySection(
                    viewModel: viewModel, videosOnly: mode == .sequence, allowsSeveral: mode.allowsSeveral,
                    onContinue: { assets in proceed(with: viewModel.brand.picks(of: assets)) },
                    onLogo: { asset in
                        viewModel.brand.insertLogo(asset)
                        isDone = true
                        dismiss()
                    }
                )
            } else {
                photoLibrary
            }
        }
        .onChange(of: items) { _, picked in
            // In the sequence one video goes in at a time: picking it is enough.
            guard !mode.allowsSeveral, !picked.isEmpty else { return }
            Task { await bringIn() }
        }
    }

    @ViewBuilder private var photoLibrary: some View {
            ZStack {
                PhotosPicker(
                    selection: $items, maxSelectionCount: mode.allowsSeveral ? 20 : 1, selectionBehavior: .ordered,
                    matching: mode == .sequence ? .videos : .any(of: [.images, .videos]), photoLibrary: .shared()
                ) {
                    EmptyView()
                }
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
                .photosPickerAccessoryVisibility(.hidden, edges: .all)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous))
                if viewModel.isImportingMedia {
                    ProgressView().tint(Palette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.Takes.durationBadge)
                }
            }
            if mode.allowsSeveral, !items.isEmpty {
                PanelButton(
                    label: String(localized: "Continue · \(items.count)"), isPrimary: true,
                    isEnabled: !viewModel.isImportingMedia, identifier: "edit.mediaContinue"
                ) { Task { await bringIn() } }
                .padding(.bottom, 8)
            }
    }

    private var insertionNote: String {
        switch mode {
        case .sequence: viewModel.clips.insertionNote
        default: overlays.insertionNote(for: mode)
        }
    }

    private func pick(mode: MediaInsertMode) {
        overlays.mediaInsertMode = mode
        if mode.isOverlay { overlays.lastOverlayMode = mode }
        // What was picked for another place doesn't carry over (the sequence takes videos only, one at a time).
        items = []
    }

    // MARK: - Steps

    /// Copies what was picked in, then: one video asks for its part, one photo goes straight in, several are reviewed.
    private func bringIn() async {
        let imported = await overlays.importPicks(items)
        items = []
        proceed(with: imported.map { MediaPick($0) })
    }

    /// Picks in hand (from Photos or the library): one video asks for its part, one photo goes straight in, several are
    /// reviewed.
    private func proceed(with picked: [MediaPick]) {
        guard !picked.isEmpty else { return }
        picks = picked
        if picks.count == 1 {
            if picks[0].isVideo {
                step = .part(picks[0].id)
                detent = .large
            } else {
                add()
            }
        } else {
            step = .review
            detent = .large
        }
    }

    /// Back from a part: to the review when several were picked; else the pick is thrown away and the library shows again.
    private func leavePart() {
        if picks.count > 1 {
            step = .review
        } else {
            discardPicks()
        }
    }

    /// The part is chosen: back to the review when several were picked, else in it goes.
    private func confirmPart() {
        if picks.count > 1 {
            step = .review
        } else {
            add()
        }
    }

    private func discardPicks() {
        EditMediaFiles.remove(Set(picks.map(\.imported.fileName)))
        picks = []
        step = .choose
        detent = .medium
    }

    private func add() {
        let picked = picks
        isDone = true
        Task {
            if mode == .sequence, let first = picked.first {
                viewModel.clips.addClip(first)
            } else {
                await overlays.add(picked, as: mode)
            }
        }
        dismiss()
    }

    /// The longest a video's part can be: the room in the video over it, or, in the sequence, all of it (the video grows).
    private func longest(for pick: MediaPick) -> TimeInterval {
        let file = pick.fileLength ?? MediaOverlay.photoDuration
        guard mode.isOverlay else { return file }
        let start = overlays.runStart(for: mode)
        return max(MediaOverlay.minimumDuration, min(file, overlays.runRoom(for: mode, from: start)))
    }

    /// Where the part lands: "00:07.0 to 00:12.0" over the video; in the sequence, where it goes in and how much longer the
    /// video gets.
    private func partNote(for pick: MediaPick) -> String {
        guard mode.isOverlay else {
            return viewModel.clips.insertionNote + " · " + String(localized: "the video gets \(DurationText.tenths(pick.wanted)) longer")
        }
        if picks.count > 1 { return overlays.runNote(overlays.run(of: picks, as: mode), count: picks.count) }
        return overlays.runNote(overlays.run(of: [pick], as: mode), count: 1)
    }
}

extension AddMediaSheet {
    /// "Your takes": the other takes in a sideways row, each with its script, number and length; a tap adds it as a clip.
    private struct TakeRow: View {
        let takes: [Take]
        let add: (Take) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your takes")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(takes) { take in
                            Button { add(take) } label: { card(take) }
                                .buttonStyle(.cuePress)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text("\(take.scriptTitle) · Take \(take.number)"))
                                .accessibilityValue(Text(DurationText.clock(take.duration)))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("edit.addTake.\(take.id.uuidString)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }

        private func card(_ take: Take) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(take.scriptTitle)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(verbatim: "\(String(localized: "Take \(take.number)")) · \(DurationText.clock(take.duration))")
                    .monoFont(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .frame(minHeight: Metrics.hitTarget)
        }
    }
}
