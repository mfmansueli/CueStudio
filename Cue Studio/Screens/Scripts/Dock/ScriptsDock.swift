//
//  ScriptsDock.swift
//  Cue Studio
//

import SwiftUI

/// The Scripts AI dock (v30 · 3.1, 3.2): clean glass fixed above the tab bar. Row 1 is the choices for the idea (Format, the platform and
/// the voice), and once there are scripts a lightbulb to Find inspiration; row 2 is the idea itself (two lines, opening to five while it
/// is edited, the suggested idea while it is empty, and up to `IdeaPromptDraft.maxCharacters` characters), "↻ another idea", the microphone
/// and the yellow arrow. Scrolling the list down folds row 1 away (09 §6); focusing the field raises the dock with the keyboard.
/// Apple Intelligence's light (`AIGlow`) turns round the glass while a dictation listens, breathing with the voice, and runs round it
/// once when an idea is sent; a new suggestion arrives word by word out of the light (`WordsFromLight`).
///
/// The text is the one draft kept by `IdeaDraftService`. The microphone dictates into the field (speak, see the words, review,
/// edit: it never sends anything itself). The dock owns the microphone while it is on screen: it lets go when the app leaves the
/// foreground, when something else takes the screen (a sheet, the camera, another tab) and when the dock goes away, and the
/// recognizer still finishes the last words into the draft.
struct ScriptsDock: View {
    /// Whether the Format chip is there (the first visit has it too: the owner asked for it, 6/10/2026).
    var showsFormat = true
    /// Row 1 folds away while the list scrolls down.
    var isFolded = false
    /// The field has the keyboard (or is being dictated into): the list behind dims.
    @Binding var isEditing: Bool
    /// Why Apple Intelligence can't write now; nil when it can. The arrow says "Write it" then.
    var unavailableReason: String?
    /// The lightbulb to Find inspiration after the voice chip: always, in every state of Scripts (the owner's call, 10/10/2026; the empty
    /// Scripts has no inspiration card of its own).
    var showsInspiration = true

    @Environment(CreatorProfileService.self) private var profile
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(IdeaSuggestionService.self) private var suggestions
    @Environment(NotificationService.self) private var notifications
    @Environment(LogbookService.self) private var logbook
    @Environment(ScriptStarter.self) private var starter
    @Environment(DictationService.self) private var dictation
    @Environment(LanguageService.self) private var languages
    @Environment(PresentationService.self) private var presentation
    @Environment(UltraScriptService.self) private var ultra
    @Environment(GuidanceGate.self) private var guidance
    @Environment(VoiceQuestionScheduler.self) private var voiceQuestions
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(IdeaTransitionService.self) private var transition
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.logsDockMotion) private var logsDockMotion
    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    @State private var scrollPosition = ScrollPosition(edge: .bottom)
    /// Tapping the words while they are being dictated stops the dictation and takes the keyboard.
    @State private var focusesWhenDone = false
    /// The My Cue Voice setup over the dock, if it is open.
    @State private var voiceSetup: VoiceSetupSheet.Mode?
    /// The invitation to finish My Cue Voice, on the first idea sent with questions open (`DockVoiceSheets`).
    @State private var showsVoiceInvite = false
    /// Where the arrow and the writer chip are, outside the dock's state (`DockPlaces`): the star leaves from the arrow.
    @State private var places = DockPlaces()
    /// What the dock shows of Ultra AI, a step behind the service so it moves where it is seen (`syncUltra`): the writer chip lit, and the
    /// invitation's line.
    @State private var showsUltraLit = false
    @State private var showsUltraInvite = false
    /// Go up to fly the ✦ from the invitation to the chip, and to send the chip's ring out.
    @State private var ultraHop = 0
    @State private var ultraRing = 0
    /// Ultra AI lighting the writer chip, a moment after the ring once the ✦ is drawn: the ✦ turns and pops, sends its sparks
    /// (`UltraChipSparks`) and Cue's light goes round the chip (`DockChipLight`).
    @State private var ultraGlyph = 0
    /// Apple Intelligence picked back on the writer chip: the symbol's bounce and Apple Intelligence's light round it (`DockChipLight`).
    @State private var appleLight = 0
    /// The network the platform chip shows: the picked one, once the "Create for" sheet is out of the way.
    @State private var shownPlatform: Platform?
    /// A network picked: the platform chip's logo flips and the network's light goes round it.
    @State private var platformFlip = 0
    /// The send arrow is Ultra AI's (violet, with its rim going round): a step behind the chip, once the ✦ has flown to it.
    @State private var sendIsUltra = false
    /// The writer chip between its old words and its new (`turnChip`).
    @State private var hidesWriter = false
    /// Go up to fly the ✦ from the writer chip to the send arrow, and to pop the arrow as it lands.
    @State private var sendHop = 0
    @State private var sendCharge = 0
    /// Where the ✦ leaves from (the invitation's, the chip's) and lands (the chip's, the arrow's), in the dock's own space.
    /// The writer chip's frame, and how wide its Ultra AI look is: the ✦ sits 15 pt into that look, in the middle of the chip.
    @State private var ultraLookWidth: CGFloat = 0
    nonisolated private static let ultraSpace = "ultraDock"
    /// The height of a line of the field's text, which grows with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var lineHeight = 21.0

    /// The field is two lines (the board) at rest. While it is being edited (the keyboard, or a dictation) it opens as far as the
    /// idea needs, up to five lines, and goes back to two when the editing ends; a longer idea scrolls inside it.
    private static let minLines = 2
    private static let maxLines = 5
    /// Row 1: 30 pt chips with a 36 pt touch area.
    private static let topRowHeight: CGFloat = 36
    private static let rowSpacing: CGFloat = 10
    /// A new suggestion's words, one after the other: quicker than a script's (it is a line to glance at, not to read along).
    private static let suggestionStagger = 0.05
    /// How much shorter the dock is with row 1 folded away.
    static let foldHeight = topRowHeight + rowSpacing

    /// The field is being edited: it can open to show the whole idea (up to five lines). At rest it is back to its two.
    private var isExpanded: Bool { isFocused || dictation.isActive }

    /// Apple Intelligence can write: the arrow sends the idea.
    private var hasAI: Bool { unavailableReason == nil }

    /// The creator's own words are ready to send (not while they are still being dictated).
    private var hasTypedIdea: Bool {
        ideaDraft.canSubmit(isAvailable: true, isDictating: dictation.isActive)
    }

    /// The idea the dock suggests while its field is empty ("↻" brings the next).
    /// The suggestion as VoiceOver says it: with what it came from (`IdeaTie.cardLine`), when it is tied to something.
    private var spokenSuggestion: String? {
        guard let suggestion else { return nil }
        guard let why = suggestions.current?.tie?.cardLine else { return suggestion }
        return suggestion + ", " + why
    }

    private var suggestion: String? {
        guard hasAI, ideaDraft.isEmpty, !dictation.isActive else { return nil }
        return suggestions.current?.title
    }

    /// The arrow works with something to send: the typed idea or the suggestion. Without Apple Intelligence ("Write it")
    /// it needs the typed idea, which becomes the title of a blank draft.
    private var canSend: Bool {
        guard !transition.isActive, !dictation.isActive else { return false }
        return hasAI ? (hasTypedIdea || suggestion != nil) : hasTypedIdea
    }

    /// Something else has the screen: the microphone is theirs.
    private var isCovered: Bool {
        presentation.sheet != nil || presentation.prompter != nil
            || presentation.showsRemoteController || presentation.selectedTab != .scripts
            || voiceSetup != nil || showsVoiceInvite
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The fold is animated by whoever folds it (`ScriptsView`), so the glass moves with the row. The chips stay where they are
            // while the glass closes over them, and fade a little sooner. The row takes its spacing with it (`foldHeight` in all).
            topRow
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2)) { $0.opacity(isFolded ? 0 : 1) }
                .frame(height: isFolded ? 0 : Self.topRowHeight, alignment: .bottom)
                .clipped()
                .padding(.bottom, isFolded ? 0 : Self.rowSpacing)
                .accessibilityHidden(isFolded)
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                if let notice = dictation.notice, !dictation.isActive {
                    DictationNoticeView(notice: notice)
                        .transition(.opacity)
                }
                field
                if let unavailableReason {
                    AIUnavailableNote(reason: unavailableReason)
                }
                // From the second time the AI was used: Ultra AI and its free scripts, until it is tried or closed (here or elsewhere).
                if showsUltraInvite, !isExpanded, !transition.isActive {
                    UltraInviteCard(placement: .dock) { chooseWriter(.ultra) } onClose: {
                        guidance.left(.ultraInvite, at: .scripts, closed: true)
                        ultra.invite?.close()
                    }
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.ultraSpace)) } action: {
                            places.inviteStar = CGPoint(x: $0.minX + 20, y: $0.midY)
                        }
                        .transition(.ultraFold)
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 12, bottom: 12, trailing: 12))
        // Ultra AI allowed from the invitation: its ✦ flies to the writer chip; lit, the chip's ✦ flies on to the send arrow.
        .overlay {
            if let inviteStar = places.inviteStar, let chipStar {
                UltraStarHop(from: inviteStar, to: chipStar, trigger: ultraHop)
            }
        }
        .overlay {
            if let chipStar, let sendStar = places.sendStar {
                UltraStarHop(from: chipStar, to: sendStar, trigger: sendHop)
            }
        }
        .coordinateSpace(.named(Self.ultraSpace))
        .overlay(alignment: .topLeading) { motionLog }
        .dockSurface()
        .overlay {
            AIGlow(
                shape: RoundedRectangle(cornerRadius: Metrics.dockRadius, style: .continuous),
                isListening: dictation.isActive, level: dictation.level
            )
        }
        .animation(.smooth(duration: 0.2), value: dictation.notice)
        .onAppear {
            showsUltraLit = starter.writesWithUltra
            sendIsUltra = starter.writesWithUltra
            showsUltraInvite = invitesUltra
            shownPlatform = starter.platform
        }
        // One suggestion on Scripts at a time (`GuidanceGate`): the line folds while a tip has something to say, and stays away for the
        // session once something there was closed.
        .onChange(of: invitesUltra) { syncUltra() }
        .onChange(of: showsUltraInvite, initial: true) { _, shows in
            if shows { guidance.shown(.ultraInvite, at: .scripts) } else { guidance.left(.ultraInvite, at: .scripts) }
        }
        .onDisappear { if showsUltraInvite { guidance.left(.ultraInvite, at: .scripts) } }
        .onChange(of: starter.writesWithUltra) { syncUltra() }
        .onChange(of: starter.platform) { syncPlatform() }
        // The permission's sheet going: the ✦ waits for it to be out of the way.
        .onChange(of: presentation.sheet == nil) { _, gone in
            guard gone else {
                settleWriter()
                return
            }
            Task {
                try? await Task.sleep(for: .seconds(UltraMotion.afterSheet))
                syncUltra()
                syncPlatform()
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: isExpanded)
        .accessibilityElement(children: .contain)
        .modifier(voiceSheets)
        .onChange(of: ideaDraft.wantsFocus) { _, wants in
            guard wants else { return }
            ideaDraft.wantsFocus = false
            // The caret goes after the text that was put there ("Start with it"), not where it stood in the text it replaced.
            selection = IdeaPromptDraft.selection(at: ideaDraft.text.count, in: ideaDraft.text)
            isFocused = true
        }
        .onChange(of: isFocused) { _, _ in isEditing = isFocused || dictation.isActive }
        .onChange(of: dictation.state) { _, state in
            isEditing = isFocused || dictation.isActive
            if state == .idle { finishDictation() }
            if state == .listening { AccessibilityNotification.Announcement(String(localized: "Listening…")).post() }
        }
        .onChange(of: ideaDraft.text) {
            // Editing is a fresh start: an old "didn't catch anything" is no longer news. While it
            // listens, the view follows the newest words.
            if !dictation.isActive, dictation.notice != nil { dictation.dismissNotice() }
            if dictation.isActive, followsEnd { scrollPosition.scrollTo(edge: .bottom) }
        }
        // The idea is as long as it can be: a dictation would write nothing more, so it ends, and the field says so (the count turns orange).
        .onChange(of: ideaDraft.draft.isAtLimit) { _, isFull in
            guard isFull else { return }
            Haptics.soft()
            if dictation.isActive { dictation.stop() }
        }
        // Stopped and interrupted notes pass by themselves; the ones with something to do stay.
        .task(id: dictation.notice) {
            guard let notice = dictation.notice, notice == .interrupted || notice == .nothingHeard else { return }
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled, dictation.notice == notice { dictation.dismissNotice() }
        }
        // The app in the background (told, once): the microphone is let go and the words stay. Not on
        // `.inactive`: the system's microphone prompt makes the app inactive.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { dictation.interrupt() }
        }
        .onChange(of: isCovered) { _, covered in
            if covered { stopDictating() }
        }
        .onAppear {
            // A dictation that finished while the dock was away leaves its segment behind.
            if !dictation.isActive { ideaDraft.endDictation() }
            // The next ideas are written before "another idea" is tapped.
            suggestions.prepare()
        }
        // Other topics in My Cue Voice: the ideas written for the old ones go and new ones are asked for.
        .onChange(of: profile.profile.ideaTopics) { suggestions.prepare() }
        .onDisappear {
            stopDictating()
            isEditing = false
        }
    }

    // MARK: - Row 1

    /// How much the first row says, from the most words to the fewest: the whole row is seen without scrolling (the owner's call,
    /// 29/10/2026). Only the biggest text sizes still scroll.
    private enum RowWords: Int, Comparable {
        /// "Format ⌄", "For TikTok", "✦ My Cue Voice", "Apple Intelligence ⌄" (an iPad).
        case full
        /// "TikTok" for "For TikTok": room for the lightbulb.
        case shortPlatform
        /// Format as its symbol while it is Auto, "✦ Voice", and the writer as Apple Intelligence's symbol or "✦ Ultra".
        case short
        /// Format as its symbol even with a format picked (its name is in the sheet and VoiceOver's label).
        case fewest

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The choices for the idea, left to right as the board has them: the format, the platform, the voice and, where Ultra is offered, who
    /// writes; then the lightbulb to Find inspiration. While it listens the row says so instead (the dock keeps its height when the dictation
    /// starts and stops). Without Apple Intelligence there is no voice chip: nothing in the dock is violet.
    @ViewBuilder
    private var topRow: some View {
        if dictation.isActive {
            DictationStatusRow(state: dictation.state, level: dictation.level)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // When even the fewest words don't fit (a narrow iPhone, big text), the chips scroll and the lightbulb stays at the end, in
            // reach, instead of any chip being squeezed.
            ViewThatFits(in: .horizontal) {
                fittedRow(.full)
                fittedRow(.shortPlatform)
                fittedRow(.short)
                fittedRow(.fewest)
                HStack(spacing: Self.chipGap) {
                    ScrollView(.horizontal) {
                        HStack(spacing: Self.chipGap) { choiceChips(.fewest) }
                    }
                    .scrollIndicators(.hidden)
                    if showsInspiration { InspirationDockButton { presentation.present(.ideas) } }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Between the row's chips and the lightbulb, on every iPhone (the owner, 30/10/2026): what the row doesn't use stays after the lightbulb.
    private static let chipGap: CGFloat = 8

    private func fittedRow(_ words: RowWords) -> some View {
        HStack(spacing: Self.chipGap) {
            choiceChips(words)
            if showsInspiration { InspirationDockButton { presentation.present(.ideas) } }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func choiceChips(_ words: RowWords) -> some View {
        if showsFormat { formatChip(words) }
        platformChip(short: words >= .shortPlatform, tight: words >= .short)
        if hasAI { MyCueVoiceChip(setup: $voiceSetup, hitHeight: Self.topRowHeight, isShort: words >= .short) }
        if starter.offersUltra { writerChip(compact: words >= .short) }
    }

    /// Who writes the next idea, where Ultra is offered (Debug, with the lab set up): `DockWriterChip`; `compact`, Apple Intelligence's symbol
    /// alone or "✦ Ultra". Picking Ultra the first time asks first (`UltraConsentSheet`); with none left it offers Cue Pro instead. The pick
    /// stays until the creator changes it. Picking Ultra lights the chip in Cue's way (the ✦ turns and pops, the ring goes out); picking Apple
    /// Intelligence back, in Apple's (the symbol bounces and Apple Intelligence's light goes once round it).
    private func writerChip(compact: Bool) -> some View {
        let writesWithUltra = starter.writesWithUltra
        return DockWriterChip(
            writer: Binding(get: { writesWithUltra ? ScriptEngine.ultra : .apple }, set: chooseWriter), showsUltra: showsUltraLit,
            ultraItem: ultra.allowance.map { UltraAllowanceLabels.menu($0.allowance) } ?? String(localized: "Ultra AI"),
            look: { lit, lights, stretches in writerLook(lit: lit, compact: compact, lights: lights, stretches: stretches) },
            ultraRing: ultraRing, ultraLight: ultraGlyph, appleLight: appleLight, rowHeight: Self.topRowHeight, space: Self.ultraSpace,
            onFrame: { [places] in places.writerFrame = $0 }, onUltraLookWidth: { ultraLookWidth = $0 }
        )
    }

    /// Brings what the dock shows of Ultra AI up to the service, where it is seen (never under a sheet). Allowed from the invitation, the
    /// invitation folds as its ✦ leaves for the writer chip, which lights as it lands (`UltraMotion`, `HapticPatterns.ultraOn`). Picked on the
    /// chip, nothing changes until its menu has closed (`UltraMotion.afterMenu`); then what the chip says turns (its width stays) and it
    /// lights: Cue's way for Ultra AI (its ✦ flies on to the send arrow, which turns violet), Apple's for Apple Intelligence (the arrow
    /// turns yellow again). Under Reduce Motion it only fades.
    /// Ultra AI's line is due (`UltraScriptService.showsInvite`) and nothing else has Scripts' place.
    private var invitesUltra: Bool { ultra.showsInvite && guidance.mayShow(.ultraInvite, at: .scripts) }

    private func syncUltra() {
        guard presentation.sheet == nil else { return }
        let lit = starter.writesWithUltra
        let invited = invitesUltra
        guard lit != showsUltraLit || invited != showsUltraInvite else { return }
        let lights = lit && !showsUltraLit
        if lights, showsUltraInvite, !reduceMotion, places.inviteStar != nil, chipStar != nil {
            HapticPatterns.playUltraOn()
            ultraHop += 1
            withAnimation(UltraMotion.fold) { showsUltraInvite = invited }
            Task {
                // The chip turns as the ✦ flies, so its new words come in as it lands.
                try? await Task.sleep(for: .seconds(UltraMotion.hop - UltraMotion.chipTurnLead))
                await turnChip(lit: starter.writesWithUltra)
                lightUltra()
            }
            return
        }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : UltraMotion.fold) { showsUltraInvite = invited }
        guard lit != showsUltraLit else { return }
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsUltraLit = lit
                sendIsUltra = lit
            }
            if lit { HapticPatterns.playUltraIgnite() }
            return
        }
        // Picked on the chip's menu: nothing on the chip changes until the menu has closed back into it. The system's closing follows the
        // chip's frame, and a chip changing its size under it broke both (29/10/2026).
        Task {
            try? await Task.sleep(for: .seconds(UltraMotion.afterMenu))
            let lit = starter.writesWithUltra
            guard presentation.sheet == nil, lit != showsUltraLit else { return }
            await turnChip(lit: lit)
            guard presentation.sheet == nil, starter.writesWithUltra == lit else { return }
            if lit {
                lightUltra()
            } else {
                lightApple()
                withAnimation(UltraMotion.sendTurn) { sendIsUltra = false }
            }
        }
    }

    /// The writer chip turns to who writes, in three beats so the old words and the new never cross (`UltraMotion.chipEmpty`): what it says
    /// goes, its capsule takes the other writer's colour (never its size: the chip keeps one width, `EqualWidthStack`), and the new words come
    /// in with a little spring. Returns as they come in, for the chip to light.
    private func turnChip(lit: Bool) async {
        withAnimation(.easeIn(duration: UltraMotion.chipEmpty)) { hidesWriter = true }
        try? await Task.sleep(for: .seconds(UltraMotion.chipEmpty))
        withAnimation(UltraMotion.chipTurn) { showsUltraLit = lit }
        try? await Task.sleep(for: .seconds(UltraMotion.chipRefill))
        withAnimation(UltraMotion.chipFill) { hidesWriter = false }
    }

    /// A sheet rising over the dock before a writer picked on the chip has shown (its menu had just closed): the chip and the arrow take it at
    /// once, under the sheet, so nothing lights later on its own as the sheet goes (the owner saw Ultra AI light up with a network picked,
    /// 29/10/2026). Ultra AI allowed on its own sheet still lights as that sheet goes: until then it doesn't write.
    private func settleWriter() {
        let lit = starter.writesWithUltra
        guard lit != showsUltraLit || hidesWriter else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            showsUltraLit = lit
            sendIsUltra = lit
            hidesWriter = false
        }
    }

    /// The writer chip lights on Ultra AI, a frame after it shows the ✦ (an animation set on a view as it is drawn doesn't run): the ✦
    /// turns, pops and sends its sparks, Cue's light goes round the chip and its ring goes out (`HapticPatterns.ultraIgnite`). Then the ✦
    /// flies on to the send arrow.
    private func lightUltra() {
        Task {
            try? await Task.sleep(for: .seconds(0.03))
            guard starter.writesWithUltra else { return }
            HapticPatterns.playUltraIgnite()
            ultraRing += 1
            ultraGlyph += 1
            chargeSend()
        }
    }

    /// The ✦ leaves the lit chip for the send arrow (`UltraMotion.toSend`, `UltraStarHop`) and, as it lands, the arrow pops and turns Ultra
    /// AI's (`HapticPatterns.ultraSendCharged`). Without the arrow to fly to (Apple Intelligence can't write here), it only turns.
    private func chargeSend() {
        guard chipStar != nil, places.sendStar != nil, hasAI else {
            withAnimation(UltraMotion.sendTurn) { sendIsUltra = starter.writesWithUltra }
            return
        }
        Task {
            try? await Task.sleep(for: .seconds(UltraMotion.toSend))
            guard starter.writesWithUltra else { return }
            sendHop += 1
            try? await Task.sleep(for: .seconds(UltraMotion.hop))
            guard starter.writesWithUltra else { return }
            HapticPatterns.playUltraSendCharged()
            withAnimation(UltraMotion.sendTurn) { sendIsUltra = true }
            sendCharge += 1
        }
    }

    /// UI tests: how many times each light has gone and what the chip and the arrow show.
    @ViewBuilder
    private var motionLog: some View {
        if logsDockMotion {
            DockMotionLog(text: "ultra=\(ultraGlyph) apple=\(appleLight) platform=\(platformFlip) send=\(sendCharge) "
                + "chip=\(showsUltraLit ? "ultra" : "apple") arrow=\(sendIsUltra ? "ultra" : "apple")")
        }
    }

    /// Where the writer chip's ✦ sits, for its flights (from the invitation, to the send arrow).
    private var chipStar: CGPoint? {
        places.writerFrame.map { CGPoint(x: $0.midX - ultraLookWidth / 2 + 15, y: $0.midY) }
    }

    /// A light once round a chip of the row, the height of the chip it lights.
    private func chipLight(_ trigger: Int, _ colors: [Color]) -> some View {
        DockChipLight(trigger: trigger, colors: colors).padding(.vertical, (Self.topRowHeight - 30) / 2)
    }

    /// Brings the platform chip up to the network picked, where it is seen (never under the "Create for" sheet), flipping its logo.
    private func syncPlatform() {
        guard presentation.sheet == nil, shownPlatform != starter.platform else { return }
        let picked = shownPlatform != nil
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .snappy(duration: 0.3)) { shownPlatform = starter.platform }
        guard picked else { return }
        HapticPatterns.playPlatformOn()
        platformFlip += 1
    }

    /// The writer chip back on Apple Intelligence, a frame after it shows its symbol: the symbol bounces and Apple Intelligence's light goes
    /// once round it, with a soft swell on the Taptic Engine (`HapticPatterns.appleOn`), while the send arrow turns yellow again (`syncUltra`).
    private func lightApple() {
        Task {
            try? await Task.sleep(for: .seconds(0.03))
            HapticPatterns.playAppleOn()
            appleLight += 1
        }
    }

    /// Ultra AI with none left offers Cue Pro (or says when more come); the first time it asks for the permission.
    private func chooseWriter(_ engine: ScriptEngine) {
        guard engine == .ultra, !starter.writesWithUltra else {
            starter.choose(engine)
            return
        }
        if starter.ultraUsedUp {
            starter.showUltraUsedUp()
        } else if !starter.ultraAllowed {
            presentation.present(.ultraConsent)
        } else {
            starter.choose(.ultra)
        }
    }

    /// The writer chip as it looks: Apple Intelligence's symbol (with its name, given room) or "✦ Ultra AI" ("✦ Ultra", `compact`); `stretches`,
    /// as wide as it is given.
    private func writerLook(lit: Bool, compact: Bool, lights: Bool = true, stretches: Bool = false) -> IdeaCardChip {
        IdeaCardChip(
            label: lit
                ? (compact ? String(localized: "Ultra") : String(localized: "Ultra AI"))
                : (compact ? "" : String(localized: "Apple Intelligence")),
            style: lit ? .ai : .neutral, glyph: lit ? "✦" : nil, showsChevron: true, hitHeight: Self.topRowHeight,
            symbol: lit ? nil : DockWriterChip.appleIntelligenceSymbol, symbolBounce: lights ? appleLight : 0,
            glyphLight: lights ? ultraGlyph : 0,
            isTight: compact, hidesContent: lights && hidesWriter, stretches: stretches
        )
    }

    /// The platform chip as it looks for `platform`: its logo and name ("For TikTok", or "TikTok" `short`).
    private func platformLook(_ platform: Platform, short: Bool, tight: Bool) -> IdeaCardChip {
        IdeaCardChip(
            label: short ? platform.label : String(localized: "For \(platform.label)"), hitHeight: Self.topRowHeight, isTight: tight,
            logo: platform.logo, logoFlip: platformFlip
        )
    }

    /// The network the next script is for, with its logo ("TikTok", or "For TikTok" with room). A network picked in "Create for" shows once the
    /// sheet is gone: its logo flips once round, the network's light goes round the chip, with `HapticPatterns.platformOn`.
    private func platformChip(short: Bool, tight: Bool) -> some View {
        let platform = shownPlatform ?? starter.platform
        return Button { presentation.present(.createFor) } label: {
            platformLook(platform, short: short, tight: tight)
                .contentTransition(.interpolate)
        }
        .overlay { chipLight(platformFlip, platform.glow) }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Platform, \(platform.label)"))
        .accessibilityIdentifier("ideaCard.platformChip")
    }

    /// Format ⌄, or the picked format's name; short of room, its symbol alone (with "AD" for a sponsored ad).
    private func formatChip(_ words: RowWords) -> some View {
        let isAuto = ideaDraft.formatChoice == .auto
        let symbolOnly = words >= .fewest || (words == .short && isAuto)
        return Button { presentation.present(.format) } label: {
            IdeaCardChip(
                label: symbolOnly ? "" : (isAuto ? FormatChoice.formatLabel : ideaDraft.formatChoice.title),
                showsChevron: !symbolOnly, isTag: ideaDraft.formatChoice == .type(.ad) ? "AD" : nil, hitHeight: Self.topRowHeight,
                symbol: symbolOnly ? Self.formatSymbol : nil, isTight: words >= .short
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Format, \(isAuto ? String(localized: "Auto") : ideaDraft.formatChoice.title)"))
        .accessibilityShowsLargeContentViewer {
            Image(systemName: Self.formatSymbol)
            Text(isAuto ? FormatChoice.formatLabel : ideaDraft.formatChoice.title)
        }
        .accessibilityIdentifier("ideaCard.formatChip")
    }

    /// Format's symbol where the row is short of room: the formats stacked to pick from (the owner's pick, 30/10/2026).
    private static let formatSymbol = "rectangle.stack"

    // MARK: - Row 2

    /// The idea in a dark box with "another idea", the microphone and the arrow at its end (their places never move).
    private var field: some View {
        HStack(alignment: .bottom, spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                textArea
                if isExpanded, ideaDraft.draft.showsCounter { counter }
            }
            .padding(.leading, 14)
            // At the bottom, by the last line, as the field grows (5 pt up: centred, as they were, while it is two lines).
            HStack(spacing: 6) {
                if suggestion != nil {
                    DockAnotherIdeaButton(isWaiting: suggestions.isWaiting) { suggestions.another() }
                } else if hasAI, !dictation.isActive, ideaDraft.holdsUntouchedIdea {
                    // An idea from Find inspiration not yet changed is a suggestion still: ↻ passes it for the next one (with any change
                    // of the creator's it is theirs, and ↻ goes, as with typed words).
                    DockAnotherIdeaButton(isWaiting: false) { ideaDraft.dropIdea() }
                }
                DictationButton(state: dictation.state, style: .plain, action: toggleDictation)
                sendButton
            }
            .padding(.bottom, 5)
        }
        .padding(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 6))
        .frame(minHeight: 56)
        .background(Palette.Scripts.dockField, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// The field to type in; while dictating, the same words read-only over it, which keeps the newest in view as they grow (a field
    /// that isn't being edited wouldn't scroll to them) and can still be scrolled to read earlier parts. The editor sets the height,
    /// two lines to five as the idea needs, and stays while it listens (hidden), so both have the same height and the dock keeps its
    /// size when the dictation starts and stops.
    private var textArea: some View {
        editor
            .opacity(dictation.isActive ? 0 : 1)
            .allowsHitTesting(!dictation.isActive)
            .accessibilityHidden(dictation.isActive)
            .overlay { if dictation.isActive { transcript } }
            .frame(minHeight: lineHeight * CGFloat(Self.minLines) + 12, alignment: .top)
    }

    /// How much of the limit is used, from `IdeaPromptDraft.counterStart` on; orange when the field is full.
    private var counter: some View {
        let used = ideaDraft.text.count
        let limit = IdeaPromptDraft.maxCharacters
        return Text(verbatim: "\(used.formatted()) / \(limit.formatted())")
            .monoFont(size: 10.5, weight: .semibold)
            .foregroundStyle(ideaDraft.draft.isAtLimit ? Palette.warnText : Palette.ink)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, 4)
            .accessibilityLabel(Text("\(used) of \(limit) characters"))
            .accessibilityIdentifier("ideaCard.counter")
    }

    private var editor: some View {
        // The suggestion is shown as the board shows it: white words over two lines (a text field's prompt keeps to one). A tap on the
        // field opens it to five, as typing does, so the whole idea can be read before it is sent.
        ZStack(alignment: .topLeading) {
            if let suggestion {
                // A new suggestion (↻, or the next after one was sent) arrives word by word out of the AI's light; the one already there
                // when Scripts opens is simply there.
                WordsFromLight(
                    text: suggestion, font: .cue(16, weight: .medium, for: dynamicTypeSize), color: Palette.ink, stagger: Self.suggestionStagger,
                    playsFirst: false
                )
                    .lineLimit(isExpanded ? Self.maxLines : Self.minLines)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            typingField
        }
    }

    private var typingField: some View {
        TextField(text: textBinding, selection: $selection, prompt: placeholder, axis: .vertical) {
            Text("Your idea")
        }
        .lineLimit(Self.minLines...(isExpanded ? Self.maxLines : Self.minLines))
        // Folded to two lines, the third of a longer idea peeked under the second (05/11/2026): the field shows its two lines only.
        .mask { Rectangle().padding(.vertical, isExpanded ? -400 : 0).padding(.horizontal, -12) }
        .focused($isFocused)
        .cueFont(16, weight: .medium)
        .foregroundStyle(Palette.ink)
        .tint(Palette.acc)
        .padding(.vertical, 6)
        .writingToolsBehavior(.limited)
        // The suggestion is drawn behind the field and hidden from VoiceOver: the field says it, so that whoever listens knows what the arrow sends,
        // and what it came from when it is tied to something of theirs (the field has no room to show it; Find inspiration's card does).
        .accessibilityValue(Text(verbatim: spokenSuggestion ?? ideaDraft.text))
        .accessibilityHint(Text("Say or type an idea"))
        .accessibilityIdentifier("ideaCard.field")
    }

    private var transcript: some View {
        ScrollView {
            Group {
                if ideaDraft.text.isEmpty {
                    placeholder
                } else {
                    Text(ideaDraft.text).foregroundStyle(Palette.ink)
                }
            }
            .cueFont(16, weight: .medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(followsEnd ? .bottom : .top)
        .contentShape(Rectangle())
        .onTapGesture {
            focusesWhenDone = true
            dictation.stop()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Tap to stop and edit."))
        .accessibilityIdentifier("ideaCard.transcript")
    }

    /// Shown while the field is empty and nothing is suggested (no Apple Intelligence, or while it listens): what to do.
    private var placeholder: Text {
        if suggestion != nil { return Text(verbatim: "") }
        return Text(hasAI ? "Say it or type your idea…" : "Type or say a title…").foregroundStyle(Palette.ink2)
    }

    /// The arrow that sends the idea (`DockSendArrow`: yellow, or violet while Ultra AI writes the next idea); "Write it" when Apple
    /// Intelligence can't write.
    @ViewBuilder
    private var sendButton: some View {
        if hasAI {
            Button(action: submit) {
                DockSendArrow(isUltra: sendIsUltra, isEnabled: canSend, isRunning: !isCovered && !transition.isActive, charge: sendCharge)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .global)
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { [places] in places.sendCenter = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.ultraSpace)) } action: {
                places.sendStar = CGPoint(x: $0.midX, y: $0.midY)
            }
            .accessibilityLabel(Text("Write it"))
            .accessibilityIdentifier("ideaCard.submit")
        } else {
            Button(action: submit) {
                Text("Write it")
                    .cueFont(15, weight: .semibold)
                    .foregroundStyle(canSend ? Palette.accInk : Palette.ink2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .frame(minHeight: 34)
                    .background(canSend ? Palette.acc : Palette.fill, in: Capsule())
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityIdentifier("ideaCard.submit")
        }
    }

    private var textBinding: Binding<String> {
        Binding(get: { ideaDraft.text }, set: { ideaDraft.text = $0 })
    }

    /// While the words are added at the end, the view follows them; in the middle of a text it stays put.
    private var followsEnd: Bool {
        ideaDraft.draft.dictation?.after.isEmpty != false
    }

    // MARK: - Actions

    /// The microphone starts the dictation, or stops it (also while it is still getting ready).
    private func toggleDictation() {
        Haptics.selection()
        if dictation.isActive {
            dictation.stop()
        } else {
            startDictation()
        }
    }

    /// Dictation writes at the caret (the end when the field has none), after what is there and never
    /// over it. The keyboard goes down so the words have room.
    private func startDictation() {
        guard dictation.state == .idle else { return }
        ideaDraft.beginDictation(caret: IdeaPromptDraft.caretOffset(of: selection, in: ideaDraft.text))
        isFocused = false
        let request = languages.dictationRequest(existingText: ideaDraft.text)
        // The words go to the draft itself, not through this view: they may arrive after it is gone.
        let draft = ideaDraft
        let service = dictation
        Task {
            await service.start(language: request) { draft.hear($0) }
            // It couldn't start (no permission, no recognizer): nothing was written, nothing to keep open.
            if !service.isActive { finishDictation() }
        }
    }

    /// The words stay where they were written, and the caret goes after them, ready to type on.
    private func finishDictation() {
        if let end = ideaDraft.endDictation() {
            selection = IdeaPromptDraft.selection(at: end, in: ideaDraft.text)
        }
        if focusesWhenDone {
            focusesWhenDone = false
            isFocused = true
        }
    }

    private func stopDictating() {
        if dictation.isActive { dictation.stop() }
    }

    /// Ends the editing and sends the idea: its star rises from the arrow and is the transition into the script, where Apple Intelligence
    /// writes it. The suggestion goes when the field is empty. Without Apple Intelligence the idea becomes the title of
    /// a blank draft.
    private func submit() {
        guard canSend else { return }
        IdeaSendTimeline.measure("Idea send") { send() }
    }

    /// The questions and the invitation over the card. The idea they write is the typed one (✦ Voice) or the one the arrow was sending
    /// (the invitation), when Apple Intelligence can draft in its language.
    private var voiceSheets: DockVoiceSheets {
        let draftable = { (text: String?) -> String? in starter.drafting(before: text).isAvailable ? text : nil }
        let typed = ideaDraft.submission
        let waiting = hasTypedIdea ? typed : suggestion ?? typed
        return DockVoiceSheets(
            setup: $voiceSetup, showsInvite: $showsVoiceInvite, typedIdea: { draftable(typed) }, waitingIdea: { draftable(waiting) },
            write: { starter.write() }, send: { send(skippingInvite: true) }
        )
    }

    private func send(skippingInvite: Bool = false) {
        isFocused = false
        guard hasAI else {
            starter.writeByHand()
            return
        }
        let idea = hasTypedIdea ? nil : suggestion
        // An idea in a language Apple Intelligence can't draft in takes nothing off: the starter says why (with "Write it") and it stays.
        guard IdeaSendTimeline.measure("Drafting check", { starter.drafting(before: idea ?? ideaDraft.submission).isAvailable }) else {
            starter.write(idea: idea, fromDock: true, from: places.sendCenter)
            return
        }
        // The first idea sent while My Cue Voice still has questions open invites to finish them, once; the idea waits in the field.
        if !skippingInvite, voiceQuestions.invitesBeforeSending {
            voiceQuestions.sendInviteWasShown()
            showsVoiceInvite = true
            return
        }
        IdeaSendTimeline.measure("Takeoff haptic") { HapticPatterns.playTakeoff() }
        guard idea != nil else {
            starter.write(idea: nil, from: places.sendCenter)
            return
        }
        // The card's own idea follows its angle and opening line (read before `sent()` brings the next one).
        let brief = suggestions.current?.brief
        // The idea sent is what they like (the next ones lean that way); when it was a note of theirs, the note has become a script.
        let note = IdeaSendTimeline.measure("Next idea") { suggestions.sent() }
        // A suggested idea used for real: its introduction stops (a note of their own is the Logbook's, not the ideas').
        if note == nil { notifications.recordUse(.ideas) }
        starter.write(idea: idea, brief: brief, fromDock: true, from: places.sendCenter) { [logbook] scriptID in
            if let note { logbook.markShaped(note, as: scriptID) }
        }
    }
}

#if DEBUG
#Preview {
    @Previewable @State var editing = false
    ScriptsDock(isEditing: $editing)
        .padding()
        .background(Palette.bg)
        .previewEnvironment(seeded: false)
}
#endif
