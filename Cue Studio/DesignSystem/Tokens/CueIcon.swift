//
//  CueIcon.swift
//  Cue Studio
//

import SwiftUI

/// The icon set (v29): 53 icons on a 24 pt grid, round caps and joins, one color that comes from the context (62%
/// white at rest, yellow when active or a signal, violet for AI, red only for recording). Filled where the
/// design says: play, the triangle inside Takes, a marked best take. They are drawn in code from the SVG
/// geometry (`CueIconGeometry`), because the stroke has to stay about 1.6 pt at every size, which an asset that
/// scales as a whole can't do.
///
/// Generated from `design/cue-universe-v27/05 Icons/in-app` (`design/cue-v29/tools/generate_cue_icons.py`); keep
/// the case names in step with the files.
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
}

/// An icon at a size, tinted by the foreground style: `CueIconView(.speed, size: 22)`. The stroke is 1.6 pt
/// at any size (`CueIconGeometry.strokeWidth(forSize:)`). `isFilled` fills the closed shapes too, for a state
/// that is "on" (the best take, once marked).
struct CueIconView: View {
    let icon: CueIcon
    var size: CGFloat = 24
    var isFilled = false

    init(_ icon: CueIcon, size: CGFloat = 24, isFilled: Bool = false) {
        self.icon = icon
        self.size = size
        self.isFilled = isFilled
    }

    var body: some View {
        let elements = CueIconGeometry.elements(for: icon)
        let width = CueIconGeometry.strokeWidth(forSize: size)
        let hasShell = elements.contains { $0.closed && $0.stroked }
        Canvas { context, canvasSize in
            let scale = canvasSize.width / CueIconGeometry.grid
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            // In a layer, so a detail of a filled icon (the star in a marked best take) can be knocked out of
            // the fill without erasing what is behind the icon.
            context.drawLayer { layer in
                for element in elements {
                    let path = element.path.applying(transform)
                    if element.filled, isFilled, hasShell, !element.stroked {
                        layer.blendMode = .destinationOut
                        layer.fill(path, with: .color(.black))
                        layer.blendMode = .normal
                        continue
                    }
                    if element.filled || (isFilled && element.closed) {
                        layer.fill(path, with: .foreground)
                    }
                    if element.stroked {
                        let dash = element.dash.map { $0.map { $0 * scale } } ?? []
                        layer.stroke(
                            path, with: .foreground,
                            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round, dash: dash)
                        )
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
