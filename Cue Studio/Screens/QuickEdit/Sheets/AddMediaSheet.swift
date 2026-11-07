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
/// reviewed together (`MediaRunStep`), with what is shortened or left out to fit said up front. Picks come from Photos,
/// "Your library" (`MediaLibrarySection`: what the creator kept to reuse, picked the same way, a logo straight on) or, in the
/// sequence, "Your takes" (a montage of several takes), chosen with the system's segmented control. The header, the cards
/// and the source never move; the gallery takes the room left and scrolls; Continue · N waits in a footer over the safe area.
struct AddMediaSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var picks: [MediaPick] = []
    @State private var step: Step = .choose
    /// Opens tall (owner, canvas 2 F14 and R4: picking in a library, nothing to watch on the video meanwhile).
    @State private var detent: PresentationDetent = .large
    @State private var source: Source = .photos
    /// The picks went in: nothing to throw away when the sheet goes.
    @State private var isDone = false
    /// Cancel, or Back from the review, with picks that would be lost: asked first (owner, canvas 2 R11), saying how many.
    @State private var asksToDiscard: Discard?

    /// What asked to throw the picks away.
    private enum Discard: Identifiable {
        case sheet, review
        var id: Self { self }
    }

    private enum Step: Equatable {
        case choose
        case part(UUID)
        case review
    }

    /// Where the picks come from.
    private enum Source: Hashable {
        case photos, library, takes
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
                SheetHeader(title: String(localized: "\(picks.count) to add"), subtitle: mode.label) { cancel() }
                let run = overlays.run(of: picks, as: mode)
                MediaRunStep(
                    picks: $picks, run: run, note: overlays.runNote(run, count: picks.count), action: mode.action,
                    onPart: { step = .part($0) }, onBack: { backFromReview() }, onConfirm: { add() }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        // The sheet's height exactly: the gallery takes what the controls leave and the footer sits on the bottom edge.
        .frame(maxHeight: .infinity, alignment: .top)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if step == .choose { footer }
        }
        // What the sheet does is said over it (removed from the library · Undo, already in it, a file missing): under the
        // sheet, the editor's own toasts can't be seen.
        .modifier(EditorToastHost())
        .cueSheetChrome()
        .presentationDetents([Self.middle, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        // With picks at stake a swipe down doesn't throw them away: Cancel asks first. With none, it closes at once.
        .interactiveDismissDisabled(atStake > 0)
        .confirmationDialog(
            String(localized: "Discard what you picked?"),
            isPresented: Binding(get: { asksToDiscard != nil }, set: { if !$0 { asksToDiscard = nil } }),
            titleVisibility: .visible, presenting: asksToDiscard
        ) { reason in
            Button(String(localized: "Discard \(atStake)"), role: .destructive) { discard(reason) }
            Button(String(localized: "Keep picking"), role: .cancel) {}
        } message: { _ in
            Text("Picked: \(atStake) · nothing is added")
        }
        .onAppear {
            source = startingSource(for: mode)
        }
        .onDisappear {
            if !isDone { EditMediaFiles.remove(Set(picks.map(\.imported.fileName))) }
            viewModel.brand.libraryPicked = []
        }
    }

    /// The sheet's middle height: four fifths of the screen, so under the cards there is room for a row and more of the
    /// gallery and the footer (at the system's half height the gallery had no room and Continue fell off the sheet).
    static let middle = PresentationDetent.fraction(0.8)

    // MARK: - Where it goes, and where it comes from

    /// Header, mode cards, what the mode does and the source never move: the explanation keeps the room of the longest one
    /// and the note two lines, whatever mode is picked; the gallery below takes the rest and scrolls in it.
    private var choose: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: String(localized: "Add photo or video")) { cancel() }
            MediaModeCards(selection: Binding(get: { mode }, set: { pick(mode: $0) }))
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topLeading) {
                    // The longest explanation holds the room, so changing modes moves nothing under it.
                    ForEach(MediaInsertMode.allCases) { other in
                        Text(other.explanation).font(.footnote).lineLimit(2).hidden().accessibilityHidden(true)
                    }
                    Text(mode.explanation)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .accessibilityIdentifier("edit.mediaModeExplanation")
                }
                // Where it lands and for how long, before picking (two lines held).
                Label(insertionNote, systemImage: roomIsShort ? "exclamationmark.triangle.fill" : "arrow.down.to.line")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(roomIsShort ? Palette.warnText : Palette.ink)
                    .lineLimit(2, reservesSpace: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(insertionNote))
                    .accessibilityIdentifier("edit.mediaInsertionNote")
            }
            .fixedSize(horizontal: false, vertical: true)
            sourcePicker
            Group {
                switch source {
                case .photos: photoLibrary
                case .library:
                    MediaLibrarySection(
                        viewModel: viewModel, videosOnly: mode == .sequence, allowsSeveral: mode.allowsSeveral,
                        onContinue: { assets in proceed(with: viewModel.brand.picks(of: assets)) },
                        onLogo: { asset in
                            viewModel.brand.insertLogo(asset)
                            isDone = true
                            dismiss()
                        }
                    )
                case .takes: takeList
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: items) { _, picked in
            // In the sequence one video goes in at a time: picking it is enough.
            guard !mode.allowsSeveral, !picked.isEmpty else { return }
            Task { await bringIn() }
        }
    }

    /// Where picks come from: Photos, Your library, and in the sequence Your takes, as the system's segmented control.
    private var sourcePicker: some View {
        Picker(String(localized: "Source"), selection: Binding(get: { source }, set: { pick(source: $0) })) {
            Text("Photos").tag(Source.photos)
            Text("Your library").tag(Source.library)
            if mode == .sequence, !viewModel.clips.addableTakes.isEmpty {
                Text("Your takes").tag(Source.takes)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("edit.mediaSource")
    }

    private var photoLibrary: some View {
        ZStack {
            // Continuous: each tap reaches Cue at once, in order (the picker's own Add button is hidden, so a selection that
            // waited for it never came, and Continue stayed off with a photo picked: owner, 25/10).
            PhotosPicker(
                selection: $items, maxSelectionCount: mode.allowsSeveral ? 20 : 1, selectionBehavior: .continuousAndOrdered,
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
    }

    /// The creator's other takes, for a montage: a tap puts one in at the playhead.
    private var takeList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.clips.addableTakes) { take in
                    TakeCard(take: take) {
                        Task {
                            await viewModel.clips.addClip(from: take)
                            isDone = true
                            dismiss()
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
    }

    /// The footer over the safe area, the same height in every mode: Continue (counting what is picked, off until something
    /// is) and how picking works. In the sequence a tap is enough, so only the line shows; the button keeps its room.
    private var footer: some View {
        VStack(spacing: 6) {
            Button {
                continueWithPicks()
            } label: {
                Text(pickedCount == 0 ? String(localized: "Continue") : String(localized: "Continue · \(pickedCount)"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(Palette.acc)
            .foregroundStyle(Palette.accInk)
            .disabled(pickedCount == 0 || viewModel.isImportingMedia || viewModel.brand.isAddingToLibrary)
            .opacity(mode.allowsSeveral ? 1 : 0)
            .allowsHitTesting(mode.allowsSeveral)
            .accessibilityHidden(!mode.allowsSeveral)
            .accessibilityIdentifier("edit.mediaContinue")
            Text(footerHint)
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .accessibilityIdentifier("edit.mediaPickHint")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var footerHint: String {
        guard mode.allowsSeveral else {
            return source == .takes
                ? String(localized: "Tap a take to put it in at the playhead")
                : String(localized: "Tap a video to put it in at the playhead")
        }
        return pickedCount == 0
            ? String(localized: "Tap photos and videos in the order they’ll show, then Continue")
            : String(localized: "Tap more to add them too, in the order you tap")
    }

    private func continueWithPicks() {
        if source == .library {
            let assets = viewModel.brand.libraryPicked.compactMap { viewModel.brand.library.asset($0) }
            viewModel.brand.libraryPicked = []
            proceed(with: viewModel.brand.picks(of: assets))
        } else {
            Task { await bringIn() }
        }
    }

    /// Little room from the playhead to the end (or the next support): said in the warning color, before anything is picked.
    private var roomIsShort: Bool {
        mode.isOverlay && overlays.insertionRoomIsShort(for: mode)
    }

    /// What would be lost now: the picks under review, or what is picked in the gallery.
    private var atStake: Int {
        step == .choose ? pickedCount : picks.count
    }

    /// Cancel: closes at once with nothing picked, else asks.
    private func cancel() {
        if atStake > 0 { asksToDiscard = .sheet } else { dismiss() }
    }

    /// Back from the review: several picks are asked about first; one goes back to the gallery as before.
    private func backFromReview() {
        if picks.count > 1 { asksToDiscard = .review } else { discardPicks() }
    }

    private func discard(_ reason: Discard) {
        switch reason {
        case .sheet: dismiss()
        case .review: discardPicks()
        }
    }

    /// How many are picked, in Photos or in the library.
    private var pickedCount: Int {
        switch source {
        case .photos: items.count
        case .library: viewModel.brand.libraryPicked.count
        case .takes: 0
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
        viewModel.brand.libraryPicked = []
        source = startingSource(for: mode)
    }

    /// In the sequence the creator's other takes come first (a montage of takes); elsewhere, Photos or the library, as last
    /// picked.
    private func startingSource(for mode: MediaInsertMode) -> Source {
        if mode == .sequence, !viewModel.clips.addableTakes.isEmpty { return .takes }
        return viewModel.brand.showsLibrary ? .library : .photos
    }

    private func pick(source: Source) {
        self.source = source
        if source != .takes { viewModel.brand.showsLibrary = source == .library }
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
        detent = .large
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
    /// One of the creator's other takes (Your takes, in the sequence): its script, number and length; a tap adds it as a clip.
    private struct TakeCard: View {
        let take: Take
        let add: () -> Void

        var body: some View {
            Button(action: add) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(take.scriptTitle)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        Text(verbatim: "\(String(localized: "Take \(take.number)")) · \(DurationText.clock(take.duration))")
                            .monoFont(.caption)
                            .foregroundStyle(Palette.ink2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "plus.circle")
                        .font(.editorGlyph(EditorGlyph.large))
                        .foregroundStyle(Palette.ink2)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: Metrics.hitTarget)
                .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            }
            .buttonStyle(.cuePress)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(take.scriptTitle) · Take \(take.number)"))
            .accessibilityValue(Text(DurationText.clock(take.duration)))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("edit.addTake.\(take.id.uuidString)")
        }
    }
}
