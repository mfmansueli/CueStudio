//
//  BrandViewModel+Kits.swift
//  Cue Studio
//

import Foundation

/// Brand kits in the editor: made from this video (its text, caption and cover styles, its colors and fonts, its logo) or by
/// hand, and put on the video only when the creator says which parts (`changes(for:)` says what each would do here). Putting
/// a kit on is one undo step that changes only the chosen parts' look: the words, cuts, timing and where each text and the
/// captions sit stay.
extension BrandViewModel {
    /// What putting a part of `kit` on this video does, said before it happens.
    struct KitChange: Identifiable, Equatable {
        let part: BrandKitPart
        /// The part, with the style's name ("Text style · Acme title").
        var title: String
        let detail: String
        /// Nothing to change here (no texts yet, no cover): said, not chosen.
        let isAvailable: Bool

        var id: BrandKitPart { part }
    }

    /// The kit the video wears now.
    var appliedKitID: UUID? { edit.brandKit?.id }

    func changes(for kit: BrandKit) -> [KitChange] {
        let words = edit.texts.filter { $0.graphic == nil }.count
        return kit.parts.map { part in
            switch part {
            case .textStyle:
                let title = "\(part.label) · \(kit.textStyle?.name ?? "")"
                return words == 0
                    ? KitChange(part: part, title: title, detail: String(localized: "For the texts you add"), isAvailable: true)
                    : KitChange(part: part, title: title, detail: String(localized: "On \(words) texts · words, timing and place stay"), isAvailable: true)
            case .captionStyle:
                let title = "\(part.label) · \(kit.captionStyle?.name ?? "")"
                return edit.captions.isEmpty
                    ? KitChange(part: part, title: title, detail: String(localized: "For the captions you make"), isAvailable: true)
                    : KitChange(part: part, title: title, detail: String(localized: "Lines, timing, size and place stay"), isAvailable: true)
            case .coverStyle:
                let title = "\(part.label) · \(kit.coverStyle?.name ?? "")"
                return edit.cover?.composition == nil
                    ? KitChange(part: part, title: title, detail: String(localized: "No cover yet · make one to use it"), isAvailable: false)
                    : KitChange(part: part, title: title, detail: String(localized: "On the cover · its words stay"), isAvailable: true)
            case .fonts:
                let names = [kit.titleFont.map { String(localized: "Titles: \($0.label)") }, kit.captionFont.map { String(localized: "Captions: \($0.label)") }]
                let missing = [kit.titleFont, kit.captionFont].compactMap { $0 }.contains { $0.isMissing }
                let detail = names.compactMap { $0 }.joined(separator: " · ")
                return KitChange(
                    part: part, title: part.label,
                    detail: missing ? String(localized: "\(detail) · not on this iPhone, drawn in SF Pro") : detail, isAvailable: true
                )
            case .colors:
                return KitChange(
                    part: part, title: part.label, detail: String(localized: "\(kit.colors.count) colors first in this video’s color pickers"),
                    isAvailable: true
                )
            case .logo:
                guard kits.hasLogoFile(kit), let logo = kit.logo else {
                    return KitChange(
                        part: part, title: part.label, detail: String(localized: "The logo’s file is missing · pick it again in the kit"),
                        isAvailable: false
                    )
                }
                let replaces = edit.media.contains { $0.isLogo == true }
                return KitChange(
                    part: part, title: "\(part.label) · \(logo.name)",
                    detail: replaces
                        ? String(localized: "Replaces the video’s logo, where it is")
                        : String(localized: "\(logo.corner.label), over the whole video"),
                    isAvailable: true
                )
            }
        }
    }

    /// Opens the parts to choose before `kit` goes on (all of those that can, picked).
    func askToApply(_ kit: BrandKit) {
        kitToApply = kit
    }

    /// Puts `parts` of `kit` on the video: one undo step, said in the toast with Undo.
    func apply(_ kit: BrandKit, parts: Set<BrandKitPart>) {
        guard isReady, !parts.isEmpty else { return }
        var logoMedia: ImportedMedia?
        if parts.contains(.logo), let logo = kit.logo, kits.hasLogoFile(kit), let name = try? EditMediaFiles.link(kits.url(of: logo)) {
            session.importedFiles.insert(name)
            logoMedia = ImportedMedia(kind: .photo, fileName: name, aspect: logo.aspect, duration: nil)
        }
        let aspect = edit.aspect
        let current = edit
        change { snapshot in
            Self.wear(kit, parts: parts, logo: logoMedia, on: &snapshot, edit: current, aspect: aspect)
        }
        kitToApply = nil
        let said = BrandKitPart.allCases.filter { parts.contains($0) && kit.has($0) }.map(\.label).joined(separator: ", ")
        sayUndoable(String(localized: "\(kit.name) on this video · \(said)"))
    }

    /// The kit's parts on `snapshot`. Texts keep their words, timing, motion and place; captions their lines, timing, size,
    /// place and format; the cover its words. Graphics (arrows, circles, tags) keep their own look.
    static func wear(_ kit: BrandKit, parts: Set<BrandKitPart>, logo: ImportedMedia?, on snapshot: inout EditSnapshot, edit: TakeEdit, aspect: AspectRatio) {
        wearStyles(kit, parts: parts, on: &snapshot, aspect: aspect)
        if parts.contains(.fonts) { wearFonts(kit, on: &snapshot, aspect: aspect) }
        if parts.contains(.logo), let logo, let kitLogo = kit.logo {
            placeLogo(logo, corner: kitLogo.corner, width: kitLogo.width, in: &snapshot, edit: edit)
        }
        snapshot.brandKit = AppliedBrandKit(id: kit.id, name: kit.name, colors: kit.colors)
        snapshot.brandKitKnown = true
    }

    private static func wearStyles(_ kit: BrandKit, parts: Set<BrandKitPart>, on snapshot: inout EditSnapshot, aspect: AspectRatio) {
        if parts.contains(.textStyle), let style = kit.textStyle {
            snapshot.textLook = style.look
            snapshot.textPreset = nil
            for index in snapshot.texts.indices where snapshot.texts[index].graphic == nil {
                style.look.apply(to: &snapshot.texts[index], keeping: [.position])
                snapshot.texts[index].preset = nil
                snapshot.texts[index].customized = []
            }
        }
        if parts.contains(.captionStyle), let style = kit.captionStyle {
            let before = snapshot.captionCollection
            var next = style.look.settings
            if let before { next = next.laidOut(like: before) }
            if let margins = before?.safeMargins { next.safeMargins = margins }
            if next.format == nil { next.format = before?.format }
            next.savedStyleID = nil
            snapshot.captionCollection = next
            snapshot.captionAnimation = next.motion?.nearestAnimation ?? style.look.animation
            CaptionsViewModel.refit(&snapshot, from: before, aspect: aspect)
        }
        if parts.contains(.coverStyle), let style = kit.coverStyle, let composition = snapshot.cover?.composition {
            snapshot.cover?.composition = style.look.apply(to: composition)
        }
    }

    /// The kit's title font on the texts (at the nearest weight it has) and the cover's title; its caption font on the captions.
    private static func wearFonts(_ kit: BrandKit, on snapshot: inout EditSnapshot, aspect: AspectRatio) {
        if let font = kit.titleFont {
            if snapshot.textLook != nil { snapshot.textLook?.font = font }
            for index in snapshot.texts.indices where snapshot.texts[index].graphic == nil {
                snapshot.texts[index].font = font
                if !font.weights.contains(snapshot.texts[index].weight) {
                    snapshot.texts[index].weight = TextOverlayWeight.nearest(to: snapshot.texts[index].weight.value, in: font.weights)
                }
            }
            if let composition = snapshot.cover?.composition {
                var styled = composition
                styled.title.font = CoverFont(font, weight: composition.title.font.weight)
                snapshot.cover?.composition = styled
            }
        }
        if let font = kit.captionFont, let before = snapshot.captionCollection {
            var next = before.withoutCopiedLook
            next.face = font
            if let weight = next.adjustments?.weight, !next.availableWeights.contains(weight) { next.adjustments?.weight = nil }
            if next.adjustments?.isEmpty == true { next.adjustments = nil }
            snapshot.captionCollection = next
            CaptionsViewModel.refit(&snapshot, from: before, aspect: aspect)
        }
    }

    // MARK: - Making and keeping kits

    /// A kit from what this video wears: its text style (the one new texts start in, or the first text's), its captions' style,
    /// its cover's style, the colors its words use, its fonts and its logo. Not saved until the creator saves it.
    func kitFromThisVideo() -> BrandKit {
        var kit = BrandKit(name: kits.nextName())
        let videoStyle = String(localized: "This video’s")
        let firstText = edit.texts.first { $0.graphic == nil }
        if let look = edit.textLook ?? firstText.map(TextLook.init(of:)) {
            kit.textStyle = BrandKitStyle(name: videoStyle, look: look)
            kit.titleFont = look.font
        }
        if let settings = edit.captionCollection, !edit.captions.isEmpty {
            kit.captionStyle = BrandKitStyle(name: videoStyle, look: MyCaptionStyle(settings: settings, animation: edit.captionAnimation))
            kit.captionFont = settings.face
        }
        if let composition = edit.cover?.composition {
            kit.coverStyle = BrandKitStyle(name: videoStyle, look: composition.style)
            if kit.titleFont == nil { kit.titleFont = composition.title.font.face }
        }
        kit.colors = Self.colors(of: edit)
        if let logo = edit.media.first(where: { $0.isLogo == true }), let name = try? kits.keepLogo(at: EditMediaFiles.url(for: logo.fileName)) {
            kit.logo = BrandKitLogo(fileName: name, aspect: logo.aspect, name: String(localized: "Logo"), corner: .topRight, width: logo.width)
        }
        return kit
    }

    /// The colors the video's words, captions and cover use, most used first, without white and black (every video has them).
    static func colors(of edit: TakeEdit) -> [OverlayColor] {
        var counts: [OverlayColor: Int] = [:]
        for text in edit.texts where text.graphic == nil {
            counts[text.color, default: 0] += 2
            if text.background != .none { counts[text.backgroundColor, default: 0] += 1 }
        }
        if let settings = edit.captionCollection, !edit.captions.isEmpty {
            for color in [settings.accent, settings.adjustments?.textColor, settings.adjustments?.backgroundColor, settings.adjustments?.emphasisColor] {
                if let color { counts[color, default: 0] += 2 }
            }
        }
        if let title = edit.cover?.composition?.title {
            counts[title.textColor, default: 0] += 1
            counts[title.accent, default: 0] += 1
        }
        return counts.filter { $0.key != .white && $0.key != .black && $0.key != .offBlack }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(BrandKit.maximumColors).map(\.key)
    }

    /// Saves the kit being edited.
    func saveKit(_ kit: BrandKit) {
        let isNew = kits.kit(kit.id) == nil
        kits.save(kit)
        kitBeingEdited = nil
        toast.show(
            isNew
                ? String(localized: "\(kit.name) saved · videos already made don’t change")
                : String(localized: "\(kit.name) updated · videos already made don’t change")
        )
    }

    func deleteKit(_ id: UUID) {
        guard let removed = kits.remove(id) else { return }
        toast.show(
            String(localized: "\(removed.name) deleted · videos that used it keep their look"),
            action: ToastAction(title: String(localized: "Undo")) { [kits] in kits.restore(removed) }
        )
    }

    /// A library picture as the kit's logo (its own link to it).
    func logo(from asset: LibraryAsset) -> BrandKitLogo? {
        guard let name = try? kits.keepLogo(at: library.url(of: asset)) else {
            toast.show(String(localized: "\(asset.name) is missing · remove it from your library"))
            return nil
        }
        return BrandKitLogo(fileName: name, aspect: asset.aspect, name: asset.name)
    }

    /// The text styles the creator saved, to put in a kit.
    var savedTextStyles: [SavedStyle<TextLook>] { styles.textStyles.styles }
    var savedCaptionStyles: [SavedStyle<MyCaptionStyle>] { styles.captionStyles.styles }
    var savedCoverStyles: [SavedStyle<CoverStyle>] { styles.coverStyles.styles }
}
