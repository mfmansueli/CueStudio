//
//  CoverPanel.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Cover (v26): four tabs. **Frame**: a frame of the video or a photo, with frames along the edit and a
/// white box to drag onto the one wanted. **Text**: the title, its layout (Hook, Number, Kicker, Question,
/// Before/After), titles Cue suggests from the script, the typeface and which word is highlighted.
/// **Elements**: an arrow, a circle, a series tag, a badge and the creator's @handle. **Look**: what is
/// done to the picture behind the words (Text behind me, Outline me, Dim, Blur) and "My cover style".
/// While the panel is open the preview shows the cover, alone or inside a profile's grid.
struct CoverPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var strip: [UIImage?] = []
    @State private var dragTime: TimeInterval?

    private static let stripCount = 10

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .cover, onReset: resetAction, fixed: { tabBar }, content: { tabContent })
        .onAppear { viewModel.drawCover() }
        .onChange(of: viewModel.edit.cover) { _, _ in viewModel.drawCover() }
        .task(id: viewModel.edit.timeline) { await loadStrip() }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.panelTab {
        case .coverText: textTab
        case .elements: elementsTab
        case .look: lookTab
        default: frameTab
        }
    }

    /// The tabs, and at the other end of the row how the preview shows the cover.
    private var tabBar: some View {
        HStack(spacing: 8) {
            PanelTabs(tabs: EditorPanelTab.cover, selection: viewModel.panelTab, isInline: true) { viewModel.panelTab = $0 }
            Spacer(minLength: 0)
            Menu {
                Picker("Preview", selection: $viewModel.coverPreview) {
                    ForEach(CoverPreviewMode.allCases) { Text($0.label).tag($0) }
                }
            } label: {
                Label(viewModel.coverPreview.label, systemImage: viewModel.coverPreview == .grid ? "square.grid.3x3" : "iphone")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Preview"))
            .accessibilityValue(Text(viewModel.coverPreview.label))
            .accessibilityIdentifier("edit.coverPreviewMode")
        }
        .padding(.horizontal, 16)
    }

    private var frameTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            PanelSegmented(
                options: [
                    PanelOption(false, String(localized: "Frame from video"), key: "video"),
                    PanelOption(true, String(localized: "Photo"), key: "photo"),
                ],
                selection: viewModel.coverIsPhoto, identifier: "edit.coverSource"
            ) { photo in
                if photo { viewModel.requestPhoto(.cover) } else { viewModel.useVideoFrameForCover() }
            }
            if !viewModel.coverIsPhoto {
                frameStrip
                PanelNote(text: String(localized: "Drag to pick the frame"))
            }
        }
    }

    /// The title, then one row of tiles: the layouts, what Cue suggests from the script, the typefaces.
    private var textTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(String(localized: "Title on the cover"), text: Binding(
                get: { viewModel.edit.cover?.title ?? "" },
                set: { viewModel.setCoverTitle($0) }
            ))
            .font(.system(.callout))
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("edit.coverTitleField")
            tileRow {
                ForEach(CoverLayout.allCases) { layout in
                    PanelGlyphTile(
                        glyph: layout.glyph, glyphFont: .system(size: 22, weight: .heavy), title: layout.label,
                        caption: layout.purpose, isOn: viewModel.coverDesign.layout == layout,
                        identifier: "edit.cover.layout.\(layout.rawValue)"
                    ) { viewModel.setCoverLayout(layout) }
                }
                ForEach(Array(viewModel.coverSuggestions.enumerated()), id: \.offset) { index, title in
                    PanelGlyphTile(
                        glyph: title, glyphFont: Font(CoverDesignRenderer.words(viewModel.coverDesign.font, size: 14)),
                        title: "✦ " + String(localized: "From your script"), isOn: viewModel.edit.cover?.title == title,
                        isSuggestion: true, width: 118, identifier: "edit.cover.suggestion.\(index)"
                    ) { viewModel.useCoverSuggestion(title) }
                }
                ForEach(CoverFont.allCases) { font in
                    PanelGlyphTile(
                        glyph: "Aa", glyphFont: Font(CoverDesignRenderer.words(font, size: 24)), title: font.label,
                        caption: String(localized: "Font"), isOn: viewModel.coverDesign.font == font, width: 76,
                        identifier: "edit.cover.font.\(font.rawValue)"
                    ) { viewModel.setCoverFont(font) }
                }
            }
            highlightRow
        }
    }

    /// Which word is yellow: tap a word of the title.
    @ViewBuilder
    private var highlightRow: some View {
        let words = viewModel.coverWords
        if words.count > 1, viewModel.coverDesign.layout.showsTitle {
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    Text("Highlight").font(.system(.footnote, weight: .semibold)).foregroundStyle(Palette.ink2)
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        let isOn = viewModel.coverDesign.highlight(in: words.count) == index
                        Button { viewModel.setCoverHighlight(index) } label: {
                            Text(word.uppercased())
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isOn ? Palette.chipOnInk : Palette.ink)
                                .padding(.horizontal, 11)
                                .frame(height: 30)
                                .background(isOn ? Palette.chipOn : Palette.fill, in: Capsule())
                                .frame(minHeight: Metrics.hitTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                        .accessibilityIdentifier("edit.cover.highlight.\(index)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var elementsTab: some View {
        tileRow {
            ForEach(CoverElement.allCases) { element in
                let isOn = viewModel.coverDesign.elements.contains(element)
                let needsHandle = element == .handle && viewModel.creatorHandle.isEmpty
                PanelGlyphTile(
                    glyph: element.glyph, glyphFont: .system(size: 20, weight: .heavy, design: .monospaced), title: element.label,
                    caption: needsHandle ? String(localized: "Set it in Profile") : (isOn ? String(localized: "On") : String(localized: "Off")),
                    captionTint: isOn ? Palette.accText : Palette.ink2, isOn: isOn, width: 92,
                    identifier: "edit.cover.element.\(element.rawValue)"
                ) { viewModel.toggleCoverElement(element) }
            }
        }
    }

    private var lookTab: some View {
        tileRow {
            ForEach(CoverEffect.allCases) { effect in
                PanelGlyphTile(
                    glyph: effect.glyph, glyphFont: .system(size: 18, weight: .heavy, design: .monospaced), title: effect.label,
                    caption: effect.purpose, isOn: viewModel.coverDesign.effect == effect, width: 96,
                    identifier: "edit.cover.effect.\(effect.rawValue)"
                ) { viewModel.setCoverEffect(effect) }
            }
            if viewModel.myCoverLook != nil {
                PanelGlyphTile(
                    glyph: String(localized: "My style"), glyphFont: .system(size: 15, weight: .heavy), title: String(localized: "Apply my cover style"),
                    caption: String(localized: "Font · tag · look"), captionTint: Palette.accText, isOn: false, width: 130,
                    identifier: "edit.cover.applyMyStyle"
                ) { viewModel.applyMyCoverStyle() }
            }
            PanelGlyphTile(
                glyph: "+", glyphFont: .system(size: 24, weight: .regular),
                title: viewModel.myCoverLook == nil ? String(localized: "Save as my style") : String(localized: "Update my style"),
                caption: String(localized: "For the series"), isOn: false, width: 110, identifier: "edit.cover.saveMyStyle"
            ) { viewModel.saveMyCoverStyle() }
        }
    }

    /// A row of tiles that runs to the panel's edges and scrolls sideways (overflow never goes down).
    private func tileRow<Tiles: View>(@ViewBuilder _ tiles: () -> Tiles) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) { tiles() }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    /// Reset takes the cover away.
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.cover != nil else { return nil }
        return { viewModel.removeCover() }
    }

    private var frameStrip: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let total = max(0.001, viewModel.edit.editedDuration)
            let time = dragTime ?? viewModel.coverEditedTime
            let x = CGFloat(time / total) * width
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(strip.enumerated()), id: \.offset) { _, image in
                        Group {
                            if let image {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Palette.surface2
                            }
                        }
                        .frame(width: width / CGFloat(max(1, strip.count)), height: 64)
                        .clipped()
                    }
                }
                Palette.Editor.coverDim
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .frame(width: 40, height: 64)
                                    .position(x: min(max(20, x), width - 20), y: 32)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: 40, height: 64)
                    .position(x: min(max(20, x), width - 20), y: 32)
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let time = Double(min(max(0, drag.location.x), width) / max(1, width)) * total
                        dragTime = time
                        viewModel.scrubCover(toEdited: time)
                    }
                    .onEnded { drag in
                        let time = Double(min(max(0, drag.location.x), width) / max(1, width)) * total
                        dragTime = nil
                        viewModel.endCoverScrub(atEdited: time)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Cover frame"))
            .accessibilityValue(Text(DurationText.editor(time)))
            .accessibilityAdjustableAction { direction in
                let step = total / Double(Self.stripCount)
                let next = direction == .increment ? time + step : time - step
                viewModel.endCoverScrub(atEdited: next)
            }
            .accessibilityIdentifier("edit.coverStrip")
        }
        .frame(height: 64)
    }

    private func loadStrip() async {
        let samples = viewModel.coverStripSamples(count: Self.stripCount)
        var images = [UIImage?](repeating: nil, count: samples.count)
        let groups = Dictionary(grouping: samples.indices, by: { samples[$0].url })
        for (url, indices) in groups {
            let frames = await thumbnails.frames(for: url, at: indices.map { samples[$0].time }, tolerance: 0.5, maxPixelSize: 120)
            for (index, frame) in zip(indices, frames) { images[index] = frame }
        }
        strip = images
    }
}
