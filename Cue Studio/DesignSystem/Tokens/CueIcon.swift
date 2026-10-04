//
//  CueIcon.swift
//  Cue Studio
//

import SwiftUI

/// The v27 "orbit line" icon set: 53 icons on a 24 pt grid with a 1.75 pt round stroke and three quiet
/// motifs (the orb, the orbit, the 4-point star). They are template vector assets in
/// `Assets.xcassets/Icons`, so the color comes from the context: 62% white at rest, yellow when
/// active or a signal, violet for AI, red only for recording.
///
/// Generated from `design/cue-universe-v27/05 Icons/in-app`; keep the case names in step with the files.
enum CueIcon: String, CaseIterable, Sendable {
    // MARK: Create and AI

    case dictate = "cueicon.create-ai.dictate"
    case hooks = "cueicon.create-ai.hooks"
    case importText = "cueicon.create-ai.import-text"
    case needAnIdea = "cueicon.create-ai.need-an-idea"
    case new = "cueicon.create-ai.new"
    case search = "cueicon.create-ai.search"
    case sparkAi = "cueicon.create-ai.spark-ai"
    case writeIt = "cueicon.create-ai.write-it"

    // MARK: Editor

    case adjust = "cueicon.editor.adjust"
    case audio = "cueicon.editor.audio"
    case captions = "cueicon.editor.captions"
    case commentCard = "cueicon.editor.comment-card"
    case editCut = "cueicon.editor.edit-cut"
    case filters = "cueicon.editor.filters"
    case smartEdit = "cueicon.editor.smart-edit"
    case text = "cueicon.editor.text"

    // MARK: Record and teleprompter

    case countdown = "cueicon.record-teleprompter.countdown"
    case flipCamera = "cueicon.record-teleprompter.flip-camera"
    case followsVoice = "cueicon.record-teleprompter.follows-voice"
    case mirrorText = "cueicon.record-teleprompter.mirror-text"
    case readingLine = "cueicon.record-teleprompter.reading-line"
    case speed = "cueicon.record-teleprompter.speed"
    case steadyScroll = "cueicon.record-teleprompter.steady-scroll"
    case stop = "cueicon.record-teleprompter.stop"

    // MARK: Settings and controls

    case celebrations = "cueicon.settings-controls.celebrations"
    case cleanVoice = "cueicon.settings-controls.clean-voice"
    case haptics = "cueicon.settings-controls.haptics"
    case margins = "cueicon.settings-controls.margins"
    case remote = "cueicon.settings-controls.remote"
    case starrySky = "cueicon.settings-controls.starry-sky"
    case textSize = "cueicon.settings-controls.text-size"
    case volume = "cueicon.settings-controls.volume"

    // MARK: Tab bar

    case profile = "cueicon.tab-bar.profile"
    case record = "cueicon.tab-bar.record"
    case scripts = "cueicon.tab-bar.scripts"
    case settings = "cueicon.tab-bar.settings"
    case takes = "cueicon.tab-bar.takes"

    // MARK: Takes and sharing

    case bestTake = "cueicon.takes-sharing.best-take"
    case delete = "cueicon.takes-sharing.delete"
    case favorite = "cueicon.takes-sharing.favorite"
    case fitsPlatform = "cueicon.takes-sharing.fits-platform"
    case play = "cueicon.takes-sharing.play"
    case retake = "cueicon.takes-sharing.retake"
    case save = "cueicon.takes-sharing.save"
    case share = "cueicon.takes-sharing.share"

    // MARK: Universe

    case answer = "cueicon.universe-thematic.answer"
    case logbook = "cueicon.universe-thematic.logbook"
    case milestone = "cueicon.universe-thematic.milestone"
    case personalize = "cueicon.universe-thematic.personalize"
    case route = "cueicon.universe-thematic.route"
    case sendOff = "cueicon.universe-thematic.send-off"
    case topicWorld = "cueicon.universe-thematic.topic-world"
    case yourUniverse = "cueicon.universe-thematic.your-universe"

    /// The asset's name in the catalog.
    var assetName: String { rawValue }

    /// The icon as an image that takes the surrounding foreground style, at `size` points.
    var image: some View {
        Image(rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }
}

/// An icon at a size, tinted by the foreground style: `CueIconView(.speed, size: 22)`.
struct CueIconView: View {
    let icon: CueIcon
    var size: CGFloat = 24

    init(_ icon: CueIcon, size: CGFloat = 24) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        icon.image
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
