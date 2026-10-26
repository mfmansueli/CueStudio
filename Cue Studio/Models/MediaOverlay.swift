//
//  MediaOverlay.swift
//  Cue Studio
//

import Foundation

/// A photo or video from the creator's library laid over the take: B-roll over the whole frame or in a window, or a support
/// in its own area of a split screen (`layout`). The file is a copy kept by the app (`EditMediaFiles`), so the edit never
/// depends on the library. Pinned to the recording like texts, stacked when they overlap (up to `simultaneousLimit`). A video
/// plays from `startInFile` (its own start unless the creator picked another part of it), muted unless its sound is kept, at
/// its own speed whatever the speed of the clip under it; where the edit cuts out speech under it, the same stretch is cut out
/// of it (`pieces`), so what it shows stays with what is said.
nonisolated struct MediaOverlay: Codable, Hashable, Identifiable, Sendable {
    /// Narrowest a window can be, as a fraction of the frame's width.
    static let widthRange: ClosedRange<Double> = 0.25...1
    /// Shortest it can show.
    static let minimumDuration: TimeInterval = 0.3
    /// Most photos and videos on screen at once: each video is one more track to decode for every
    /// frame, and more than this drops frames on the iPhones Cue runs on. A still logo stays out of it (`isStaticLogo`).
    static let simultaneousLimit = 3
    /// How long a photo shows when added.
    static let photoDuration: TimeInterval = 3

    var id = UUID()
    var kind: MediaKind
    /// The copy's name in `EditMediaFiles`.
    var fileName: String
    /// Width over height of the media, upright.
    var aspect: Double
    /// Length of a video; nil for a photo.
    var mediaDuration: TimeInterval?
    /// Where in the video it starts playing (seconds of the file); nil from its start (media added before a part could be
    /// picked). Apart from `span`, which is where it shows in the edit: picking another part never moves it.
    var mediaStart: TimeInterval?
    /// Seconds of the recording it is pinned to.
    var span: TimeSpan
    /// In an arranged edit, the piece it is pinned to (`span` is then of that piece's recording).
    var clipAnchor: ClipAnchor?
    /// Where it stacks: higher is drawn over lower. Nil (media added before they could overlap)
    /// is the bottom, in the order they were added.
    var layer: Int?

    /// Where it goes, how big and how opaque over its own time; nil or empty stands still.
    var keyframes: [OverlayKeyframe]?
    /// A ready-made entrance (or exit) over its place and keyframes; nil for none.
    var animation: OverlayAnimation?

    /// Whether a video has its own sound; nil for media added before sound could play.
    var hasSound: Bool?
    /// A video's own sound, 0 to 1; nil plays it muted (as every video over the take did before).
    var audioVolume: Double?

    /// `layer`, with media from before stacking at the bottom.
    var stackOrder: Int { layer ?? 0 }
    var layout: MediaLayout = .fullFrame
    /// The window's center (unused full screen).
    var center: OverlayPoint = .center
    /// The window's width as a fraction of the frame's.
    var width: Double = 0.6
    var shape: MediaShape = .original
    /// A mask showing only part of it (`MediaMask`); nil shows it whole. Kept while it's a support of the split screen (whose
    /// area is already its shape), for when it's a window or full screen again.
    var mask: MediaMask?

    /// A support's layout (`SplitScreen.layout(id:)`); nil uses the video's.
    var splitLayoutID: UUID?
    /// How its picture sits in its place: a support's in its area (Fill or Fit, zoomed, moved); a window's or a full-screen
    /// one's under its mask (always Fill, zoomed and moved by Mask › Picture). Nil fills it, centered.
    var areaFraming: AreaFraming?
    /// How loud the main video plays while it shows, 0 to 1; nil leaves the main video as it is. With the support's own sound
    /// up, 0 hears only the support.
    var mainVolume: Double?
    /// Whether a cut in the speech under it cuts the same stretch out of it (`pieces`): set on everything added since; nil
    /// (media added before) plays straight on from where it starts, as it always did.
    var followsCuts: Bool?
    /// Edited seconds it plays on after the speech it's laid over, over another recording's clip it was laid across into
    /// (`TakeEdit.pinMedia`); nil: it ends with that speech.
    var tail: TimeInterval?
    /// A video whose own voice is captioned while it shows, in place of the main video's (heard on its own, never mixed with
    /// it: one voice at a time); nil or false: the main video's.
    var captionsItsVoice: Bool?
    /// A logo (a brand kit's, or one from the library): small over the whole video, its transparency kept.
    var isLogo: Bool?

    /// A logo that is a still picture: drawn as an image, never decoded frame by frame, so it doesn't count in
    /// `simultaneousLimit` (the owner's call, 25/10). A video marked as a logo still counts.
    var isStaticLogo: Bool { isLogo == true && kind == .photo }

    init(kind: MediaKind, fileName: String, aspect: Double, mediaDuration: TimeInterval?, span: TimeSpan) {
        self.kind = kind
        self.fileName = fileName
        self.aspect = aspect.isFinite && aspect > 0 ? aspect : 1
        self.mediaDuration = mediaDuration
        self.span = span
    }

    /// Seconds of the video where it starts playing, kept inside the file.
    var startInFile: TimeInterval {
        guard let mediaDuration else { return 0 }
        return min(max(0, mediaStart ?? 0), max(0, mediaDuration - Self.minimumDuration))
    }

    /// The longest it can show in the edit: what's left of a video from where it starts, else no limit.
    var longestDuration: TimeInterval {
        mediaDuration.map { $0 - startInFile } ?? .greatestFiniteMagnitude
    }
}
