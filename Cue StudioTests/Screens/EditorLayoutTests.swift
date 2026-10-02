//
//  EditorLayoutTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("EditorLayout")
struct EditorLayoutTests {
    /// Usable heights (screen minus the real safe areas) of the screens the editor is checked on.
    private enum Screen: CGFloat, CaseIterable {
        case iPhoneSE = 647
        case iPhoneMini = 728
        case iPhone16 = 759
        case iPhone16Pro = 778
        case iPhone16ProMax = 860
    }

    private let sizes: [EditorPanelSize] = [.mini, .medium, .full]

    // MARK: - Classes

    @Test func classesFollowTheUsableHeight() {
        #expect(EditorHeightClass(usableHeight: Screen.iPhoneSE.rawValue) == .veryCompact)
        #expect(EditorHeightClass(usableHeight: Screen.iPhoneMini.rawValue) == .compact)
        #expect(EditorHeightClass(usableHeight: Screen.iPhone16.rawValue) == .regular)
        #expect(EditorHeightClass(usableHeight: Screen.iPhone16Pro.rawValue) == .regular)
        #expect(EditorHeightClass(usableHeight: Screen.iPhone16ProMax.rawValue) == .regular)
    }

    @Test func largeTextMakesARegularScreenCompact() {
        #expect(EditorHeightClass(usableHeight: Screen.iPhone16.rawValue, largeText: true) == .compact)
        #expect(EditorHeightClass(usableHeight: Screen.iPhoneSE.rawValue, largeText: true) == .veryCompact)
    }

    @Test func theSmallestScreensGetShorterBarsAndIconOnlyToolbars() {
        let se = EditorLayout(usableHeight: Screen.iPhoneSE.rawValue)
        #expect(se.topBar == 40)
        #expect(se.playerBar == 40)
        #expect(!se.heightClass.toolbarShowsLabels)
        #expect(se.heightClass.mainTrackHeight == 44)
        #expect(se.heightClass.laneHeight == 22)
        let mini = EditorLayout(usableHeight: Screen.iPhoneMini.rawValue)
        #expect(mini.heightClass.mainTrackHeight == 48)
        #expect(mini.heightClass.laneHeight == 24)
        #expect(mini.heightClass.toolbarLabelSize == 10)
        let pro = EditorLayout(usableHeight: Screen.iPhone16Pro.rawValue)
        #expect(pro.topBar == 44)
        #expect(pro.heightClass.mainTrackHeight == 56)
        #expect(pro.heightClass.toolbarLabelSize == 11)
    }

    // MARK: - Nothing open

    @Test func withNothingOpenTheTimelineTakesAThirdWithinLimits() {
        for screen in Screen.allCases {
            let layout = EditorLayout(usableHeight: screen.rawValue)
            #expect(layout.timeline >= 184 && layout.timeline <= 300, "\(screen)")
            #expect(layout.toolbar == 64)
            #expect(layout.panel == 0)
            #expect(abs(layout.topBar + layout.preview + layout.playerBar + layout.timeline + layout.toolbar - screen.rawValue) < 0.5, "\(screen)")
            #expect(layout.preview >= EditorLayout.previewMinimum(for: screen.rawValue), "\(screen)")
        }
        #expect(EditorLayout(usableHeight: 900).timeline == 288)
        #expect(EditorLayout(usableHeight: 1_200).timeline == 300)
    }

    // MARK: - Panels

    @Test func thePreviewNeverGoesBelowItsMinimum() {
        for screen in Screen.allCases {
            for size in sizes {
                for focus in [false, true] {
                    let layout = EditorLayout(usableHeight: screen.rawValue, panel: size, panelFocusesLane: focus)
                    #expect(layout.preview >= EditorLayout.previewMinimum(for: screen.rawValue) - 0.01, "\(screen) \(size)")
                    #expect(layout.toolbar == 0)
                }
            }
        }
    }

    @Test func anInlinePanelFillsTheHeightExactly() {
        for screen in Screen.allCases {
            for size in sizes {
                let layout = EditorLayout(usableHeight: screen.rawValue, panel: size)
                guard layout.panelPresentation == .inline else { continue }
                #expect(layout.panel > 0)
                #expect(abs(layout.topBar + layout.preview + layout.playerBar + layout.timeline + layout.panel - screen.rawValue) < 0.5, "\(screen) \(size)")
            }
        }
    }

    @Test func panelsHaveTheirSizesOnTheDesignScreen() {
        let usable = Screen.iPhone16Pro.rawValue
        #expect(EditorLayout(usableHeight: usable, panel: .mini).panel == EditorPanelSize.clamp(0.27 * usable, 200, 250))
        #expect(EditorLayout(usableHeight: usable, panel: .medium).panel == 0.38 * usable)
        #expect(EditorLayout(usableHeight: usable, panel: .full).panel == 0.44 * usable)
        #expect(EditorPanelSize.mini.height(for: 2_000) == 250)
        #expect(EditorPanelSize.medium.height(for: 400) == 250)
        #expect(EditorPanelSize.full.height(for: 2_000) == 380)
    }

    @Test func onABigScreenAPanelTakesItsRoomFromTheTimeline() {
        let usable = Screen.iPhone16ProMax.rawValue
        let resting = EditorLayout(usableHeight: usable)
        let mini = EditorLayout(usableHeight: usable, panel: .mini)
        #expect(mini.preview == resting.preview)
        #expect(mini.timeline < resting.timeline)
    }

    /// The prompt's acceptance check: on the SE with Pauses open, the preview, the video track with
    /// the pauses and the panel's button all show without scrolling.
    @Test func onTheSEPausesKeepsTheVideoTrackInView() {
        let layout = EditorLayout(usableHeight: Screen.iPhoneSE.rawValue, panel: .medium)
        #expect(layout.panelPresentation == .inline)
        #expect(!layout.panelIsCompressed)
        #expect(layout.panel == 250)
        #expect(layout.timeline >= layout.heightClass.rulerHeight + layout.heightClass.panelMainTrackHeight)
        #expect(layout.showsTimeline)
        #expect(layout.preview >= 194)
    }

    @Test func aPanelAboutATrackKeepsThatTrackInView() {
        for screen in Screen.allCases {
            let layout = EditorLayout(usableHeight: screen.rawValue, panel: .medium, panelFocusesLane: true)
            let needed = layout.heightClass.rulerHeight + layout.heightClass.panelMainTrackHeight
                + EditorLayout.laneGap + layout.heightClass.laneHeight
            #expect(layout.timeline >= needed, "\(screen)")
        }
    }

    @Test func fullPanelsMayHideTheTimeline() {
        let layout = EditorLayout(usableHeight: Screen.iPhone16.rawValue, panel: .full)
        #expect(layout.panelPresentation == .inline)
        #expect(layout.timeline < 60)
        #expect(layout.preview >= EditorLayout.previewMinimum(for: Screen.iPhone16.rawValue))
    }

    @Test func onTheSEFullPanelsOpenAsASheetUnderThePreview() {
        let usable = Screen.iPhoneSE.rawValue
        let layout = EditorLayout(usableHeight: usable, panel: .full)
        guard case .sheet(let medium, let large) = layout.panelPresentation else {
            Issue.record("Expected a sheet")
            return
        }
        #expect(layout.preview == EditorLayout.previewMinimum(for: usable))
        #expect(abs(layout.topBar + layout.preview + large - usable) < 0.5)
        #expect(medium <= large)
        #expect(layout.panel == 0)
    }

    @Test func aPanelTooTallForTheScreenGivesWayAndScrolls() {
        let layout = EditorLayout(usableHeight: 560, panel: .full)
        #expect(layout.preview >= EditorLayout.previewMinimum(for: 560))
        let tight = EditorLayout(usableHeight: 600, panel: .medium, panelFocusesLane: true)
        #expect(tight.preview >= EditorLayout.previewMinimum(for: 600) - 0.01)
        #expect(abs(tight.topBar + tight.preview + tight.playerBar + tight.timeline + tight.panel - 600) < 0.5)
    }

    // MARK: - Keyboard

    /// What a software keyboard takes from the usable height (about 336 pt, less the bottom safe area
    /// the usable height already leaves out).
    private let keyboard: CGFloat = 302

    /// Opening the keyboard in a panel's field must not change what kind of screen this is, or how the
    /// panel is shown: that was what turned it into a sheet and closed it.
    @Test func theKeyboardNeverChangesTheClassOrTurnsAPanelIntoASheet() {
        for screen in Screen.allCases where screen != .iPhoneSE {
            for size in sizes {
                let still = EditorLayout(usableHeight: screen.rawValue, panel: size)
                let typing = EditorLayout(usableHeight: screen.rawValue - keyboard, stableHeight: screen.rawValue, panel: size)
                #expect(typing.heightClass == still.heightClass, "\(screen) \(size)")
                #expect(typing.panelPresentation == .inline, "\(screen) \(size)")
                #expect(typing.topBar == still.topBar && typing.playerBar == still.playerBar, "\(screen) \(size)")
                #expect(typing.keyboardIsUp)
            }
        }
    }

    @Test func withTheKeyboardUpTheHeightIsSharedWithoutOverlapAndKeepsTheFieldRoom() {
        for screen in Screen.allCases where screen != .iPhoneSE {
            let usable = screen.rawValue - keyboard
            for size in sizes {
                let layout = EditorLayout(usableHeight: usable, stableHeight: screen.rawValue, panel: size, panelFocusesLane: true)
                let total = layout.topBar + layout.preview + layout.playerBar + layout.timeline + layout.panel
                #expect(abs(total - usable) < 0.5, "\(screen) \(size)")
                #expect(layout.timeline == 0 && layout.toolbar == 0, "\(screen) \(size)")
                // The video still shows the text being typed, and the panel has room for its header and its field.
                #expect(layout.preview >= EditorLayout.previewMinimumWithKeyboard(for: usable) - 0.01, "\(screen) \(size)")
                #expect(layout.panel >= min(EditorPanelSize.mini.height(for: usable), 150), "\(screen) \(size)")
            }
        }
    }

    @Test func aFullPanelGetsRoomForItsFieldAndTabsOverTheKeyboardOnEveryInlineScreen() {
        for screen in Screen.allCases where screen != .iPhoneSE {
            let layout = EditorLayout(usableHeight: screen.rawValue - keyboard, stableHeight: screen.rawValue, panel: .full)
            // Header 56 + field 52 + the scope and tabs row of the compact layout, 152 pt, is the least.
            #expect(layout.panel >= 152, "\(screen)")
        }
    }

    @Test func onTheSEASheetPanelStaysExactlyAsItWasWhenTheKeyboardComesUp() {
        let se = Screen.iPhoneSE.rawValue
        let still = EditorLayout(usableHeight: se, panel: .full)
        let typing = EditorLayout(usableHeight: se - keyboard, stableHeight: se, panel: .full)
        #expect(typing.panelPresentation == still.panelPresentation)
        #expect(typing.preview == still.preview && typing.timeline == still.timeline)
        guard case .sheet = typing.panelPresentation else {
            Issue.record("Expected a sheet")
            return
        }
    }

    @Test func aSmallInsetIsNotAKeyboard() {
        let usable = Screen.iPhone16.rawValue
        let bar = EditorLayout(usableHeight: usable - 55, stableHeight: usable, panel: .full)
        #expect(!bar.keyboardIsUp)
        #expect(!EditorLayout(usableHeight: usable, panel: .full).keyboardIsUp)
    }

    @Test func closingTheKeyboardGivesTheSameLayoutBack() {
        let usable = Screen.iPhone16Pro.rawValue
        let before = EditorLayout(usableHeight: usable, stableHeight: usable, panel: .full)
        let after = EditorLayout(usableHeight: usable, panel: .full)
        #expect(before == after)
    }
}

