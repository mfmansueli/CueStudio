//
//  FindInspirationSheet.swift
//  Cue Studio
//

import SwiftUI

/// Find inspiration (the empty Scripts' first way in, the dock's lightbulb, "+ › Let Cue draft it" and the ideas notification): a large
/// sheet with "Find inspiration" and "Ideas to start from.", the topics as chips, one featured idea (`InspirationCard`), and at the bottom
/// "Another idea" (a glass circle) beside the yellow "Start with it", and a line saying where it goes. "Start with it" puts the idea's brief in
/// the dock's composer, to change before anything is written (what was there comes back with Undo); "Draft it now", quieter under
/// it, writes it as it is and the star rises. Without Apple Intelligence the ideas are the starters, said so, and the direct way is
/// "Write it yourself" (a blank draft with the idea as its title). Nothing is presented as a trend or as research: they are suggestions.
struct FindInspirationSheet: View {
    /// The feature's sign wherever it is offered (the dock, its introduction): a bulb with an orbit around it.
    static let icon = CueIcon.findInspiration

    @State private var viewModel: FindInspirationViewModel
    private let writer: ScriptWriting

    @Environment(ScriptStarter.self) private var starter
    @Environment(ToastService.self) private var toast
    @Environment(NotificationService.self) private var notifications
    @Environment(LogbookService.self) private var logbook
    @Environment(IdeaDraftService.self) private var ideaDraft
    @Environment(IdeaTransitionService.self) private var transition
    @Environment(PresentationService.self) private var presentation
    @Environment(CreatorProfileService.self) private var profile
    @Environment(ScriptLibraryService.self) private var library
    @Environment(LanguageService.self) private var languages
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// The feature's icon in the starters note, as big as the footnote's symbols.
    @ScaledMetric(relativeTo: .footnote) private var noteIconSize: CGFloat = 16

    @State private var editsTopics = false
    /// Where "Draft it now" is: the star leaves from there.
    @State private var writeCenter: CGPoint?
    /// "Start with it" was tapped: the composer takes the keyboard once the sheet has gone.
    @State private var focusesComposer = false
    /// "Start with it" took the place of the creator's words: the Undo toast comes once the sheet has gone, so all of its time is seen.
    @State private var offersUndo = false
    /// How far the card is dragged sideways: it follows the finger, leaning, and past `swipeThreshold` lets go for the next idea.
    @State private var dragOffset: CGFloat = 0
    /// Which way the drag went first: only a sideways one moves the card (an upward one scrolls the sheet).
    @State private var dragAxis: Axis?
    /// The drag is past the point where letting go turns the card (a click says so, and another when it comes back).
    @State private var isPastThreshold = false
    /// The side the leaving card goes to (−1 leading, 1 trailing), and whether it was thrown there (it flies off) or tapped away.
    @State private var leavesTowards: CGFloat = -1
    @State private var wasThrown = false

    /// How far the card has to be dragged for letting go to turn it.
    private static let swipeThreshold: CGFloat = 90

    init(services: AppServices) {
        _viewModel = State(initialValue: FindInspirationViewModel(
            suggestions: services.ideaSuggestions, draft: services.ideaDraft, profile: services.profile
        ))
        writer = services.writer
    }

    /// Whether Apple Intelligence can write the ideas, which are interface text: in the interface's language.
    private var ideasDrafting: DraftingAvailability { writer.drafting(in: languages.interfaceLanguage) }

    /// Apple Intelligence can write ideas now.
    private var hasAI: Bool { ideasDrafting.isAvailable }

    /// "Draft it now" can draft: what the dock can (a Script Language the model doesn't write can't; on Auto-detect the idea's own language
    /// is told when it is sent).
    private var canDraft: Bool { starter.dockDrafting.isAvailable }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: String(localized: "Find inspiration"), subtitle: String(localized: "Ideas to start from."))
                    .padding(.horizontal, Metrics.gutter)
                    .accessibilityAddTraits(.isHeader)
                InspirationFilterBar(
                    options: viewModel.options, selectedID: viewModel.selectedOptionID,
                    onSelect: { viewModel.select($0) }, onEditTopics: { editsTopics = true }
                )
                .padding(.top, 16)
                notes
                    .padding(.horizontal, Metrics.gutter)
                cardArea
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 18)
                if viewModel.couldNotFindMore {
                    couldNotFindMoreNote
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.top, 8)
                }
                if typeSize.isAccessibilitySize {
                    // At the biggest sizes the actions scroll with the card: pinned, they would take most of the screen.
                    actions.padding(.top, 20)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if !typeSize.isAccessibilitySize { actions }
        }
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { viewModel.appear() }
        .onChange(of: profile.profile.ideaTopics) { viewModel.topicsChanged() }
        .onDisappear {
            if focusesComposer { ideaDraft.wantsFocus = true }
            if offersUndo {
                let model = viewModel
                toast.show(
                    String(localized: "This idea replaced your draft"),
                    action: ToastAction(title: String(localized: "Undo")) { model.undoUse() }
                )
            }
        }
        .sheet(isPresented: $editsTopics) { VoiceEditorSheet(field: .topics) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspiration.sheet")
    }

    // MARK: - Notes

    /// What the creator should know before the card: they have no topics yet, or the ideas are starters (no Apple Intelligence).
    @ViewBuilder
    private var notes: some View {
        if !viewModel.hasTopics {
            note(
                text: Text("Pick your topics and the ideas will be about what you make. Until then, here are a few to start."),
                identifier: "inspiration.noTopicsNote"
            ) {
                Image(systemName: "sparkles").font(.footnote.weight(.semibold))
            }
            .padding(.top, 14)
        }
        if !hasAI {
            note(text: startersNote, identifier: "inspiration.startersNote") {
                // The bulb's base sits on the text's first baseline.
                CueIconView(Self.icon, size: noteIconSize).alignmentGuide(.firstTextBaseline) { $0.height * 0.92 }
            }
            .padding(.top, 14)
        } else if let cause = starter.dockDrafting.cause, cause.isLanguage {
            // The ideas come, but the Script Language is one Apple Intelligence can't draft in: they are to write by hand.
            note(
                text: Text(verbatim: cause.reason + " " + String(localized: "These ideas are yours to write.")),
                identifier: "inspiration.languageNote"
            ) {
                CueIconView(Self.icon, size: noteIconSize).alignmentGuide(.firstTextBaseline) { $0.height * 0.92 }
            }
            .padding(.top, 14)
        }
    }

    /// Why the ideas are the starters: an interface language the model doesn't write ideas in, or no Apple Intelligence.
    private var startersNote: Text {
        if ideasDrafting.cause?.isLanguage == true {
            return Text("Apple Intelligence can’t suggest ideas in \(languages.interfaceLanguage.localizedName) yet. Here are starter ideas to write yourself.")
        }
        return Text("Starter ideas to write yourself. With Apple Intelligence, Cue suggests more.")
    }

    private func note(text: Text, identifier: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            mark()
                .foregroundStyle(Palette.aiText)
                .accessibilityHidden(true)
            text
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - The card

    private var cardArea: some View {
        ZStack(alignment: .top) {
            switch viewModel.content {
            case .idea(let idea):
                InspirationCard(content: viewModel.card(for: idea), worldColor: OnboardingTopic.color(at: viewModel.worldIndex(of: idea)))
                    .offset(x: dragOffset)
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(dragOffset) / 24), anchor: .bottom)
                    .id(idea.id)
                    .transition(cardTransition)
                    .simultaneousGesture(swipe)
                    .accessibilityAction(named: Text("Another idea")) { another() }
            case .waiting:
                InspirationCardSkeleton(topic: chosenTopicLabel)
                    .transition(.opacity)
            case .failed:
                emptyCard(failed: true)
                    .transition(.opacity)
            case .nothing:
                emptyCard(failed: false)
                    .transition(.opacity)
            }
        }
        // The stars come out a little past the card's edge.
        .overlay { InspirationStarBurst(trigger: viewModel.turn).padding(-InspirationStarBurst.reach) }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : CueMotion.inspirationTurn, value: contentKey)
    }

    /// The idea that leaves drifts to the leading side (or flies off the side it was thrown to) and blurs away under the sparkles; the next
    /// comes in from the other side, a touch smaller, and settles on a spring while its lines rise in (`InspirationCard`). Reduce Motion: a
    /// cross-fade.
    private var cardTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: -leavesTowards * 36)).combined(with: .scale(scale: 0.97)),
            removal: AnyTransition(.blurReplace).combined(with: .offset(x: leavesTowards * (wasThrown ? 260 : 28)))
                .combined(with: .scale(scale: 0.95))
        )
    }

    /// What the card shows, as a value the animation follows.
    private var contentKey: String {
        switch viewModel.content {
        case .idea(let idea): idea.id
        case .waiting: "waiting"
        case .failed: "failed"
        case .nothing: "nothing"
        }
    }

    /// The topic the chips have chosen, for the waiting and empty cards.
    private var chosenTopicLabel: String? {
        viewModel.options.first { $0.id == viewModel.selectedOptionID }?.label
    }

    /// The card follows a sideways drag, leaning; let go past `swipeThreshold` (or thrown) it is "Another idea", flying off that side.
    /// Short of it, it springs back. A click when the drag passes the point, and a lighter one if it comes back.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let distance = value.translation
                if dragAxis == nil { dragAxis = abs(distance.width) > abs(distance.height) ? .horizontal : .vertical }
                guard dragAxis == .horizontal, viewModel.idea != nil else { return }
                dragOffset = distance.width
                let isPast = abs(distance.width) > Self.swipeThreshold
                if isPast != isPastThreshold {
                    isPastThreshold = isPast
                    if isPast { Haptics.rigid() } else { Haptics.selection() }
                }
            }
            .onEnded { value in
                defer {
                    dragAxis = nil
                    isPastThreshold = false
                }
                guard dragAxis == .horizontal else { return }
                let width = value.translation.width
                let isThrown = abs(width) > Self.swipeThreshold || abs(value.predictedEndTranslation.width) > Self.swipeThreshold * 2.2
                if isThrown, viewModel.idea != nil {
                    another(towards: width < 0 ? -1 : 1, thrown: true)
                } else {
                    settleCard()
                }
            }
    }

    /// The dragged card back in its place, on a spring.
    private func settleCard() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.38, dampingFraction: 0.72)) { dragOffset = 0 }
    }

    /// Nothing to show: the ideas asked for didn't come (`failed`, with "Try again"), or nothing can come (no Apple Intelligence and nothing
    /// ready for the topic). Why, honestly, and what to do.
    private func emptyCard(failed: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Group {
                if failed {
                    Text("Couldn’t get new ideas")
                } else {
                    Text("No ideas here right now")
                }
            }
            .font(.headline)
            .foregroundStyle(Palette.ink)
            .accessibilityAddTraits(.isHeader)
            Group {
                if hasAI {
                    Text("Cue couldn’t write ideas about this topic just now. Try again in a moment.")
                } else {
                    Text("Try another topic, or type your own idea in the composer.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if hasAI {
                    Button {
                        viewModel.retry()
                    } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
                    .accessibilityIdentifier("inspiration.retry")
                }
                if viewModel.selectedOptionID != "all", let all = viewModel.options.first {
                    Button("All my topics") { viewModel.select(all) }
                        .buttonStyle(.cueSecondary(.compact, expands: false))
                        .accessibilityIdentifier("inspiration.showAll")
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.Scripts.inspirationCard, in: shape)
        .overlay { shape.strokeBorder(Palette.Scripts.inspirationCardBorder, lineWidth: 0.5) }
        .cardDepth(shape, edge: nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(failed ? "inspiration.failed" : "inspiration.nothing")
    }

    /// Under a card that stays because the next ideas didn't come: one quiet line and "Try again".
    private var couldNotFindMoreNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Palette.ink2)
                .accessibilityHidden(true)
            Text("Couldn’t get new ideas")
                .foregroundStyle(Palette.ink2)
            Button("Try again") { viewModel.retry() }
                .foregroundStyle(Palette.aiText)
                .fontWeight(.semibold)
                .frame(minHeight: Metrics.hitTarget)
                .accessibilityIdentifier("inspiration.retryMore")
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inspiration.couldNotFindMore")
    }

    // MARK: - Actions

    /// "Another idea": a Liquid Glass circle beside "Start with it", where it stays whatever the size of the idea above (under the card it
    /// went up and down with each one). At the end of the ready ideas, the next are on their way: the card stays and the circle spins.
    private var anotherButton: some View {
        Button { another() } label: {
            Group {
                if viewModel.isFindingMore {
                    ProgressView().tint(Palette.ink)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .symbolEffect(.rotate.clockwise.byLayer, options: .speed(1.6), value: viewModel.turn)
                }
            }
            .frame(width: Metrics.largeButtonHeight, height: Metrics.largeButtonHeight)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .disabled(viewModel.idea == nil || viewModel.isFindingMore)
        .opacity(viewModel.idea == nil ? 0.4 : 1)
        .accessibilityLabel(viewModel.isFindingMore ? Text("Finding more ideas…") : Text("Another idea"))
        .accessibilityHint(Text("Shows the next idea."))
        .accessibilityIdentifier("inspiration.another")
    }

    /// "Another idea" and the yellow "Start with it", what it does, and the quieter direct way.
    private var actions: some View {
        let idea = viewModel.idea
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                anotherButton
                Button {
                    if let idea { use(idea) }
                } label: {
                    Text("Start with it")
                }
                .buttonStyle(.cuePrimary(.large))
                .disabled(idea == nil || transition.isActive)
                .accessibilityHint(Text("Puts it in the composer to make it yours."))
                .accessibilityIdentifier("inspiration.use")
            }
            Text("It goes into the composer. Make it yours first.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("inspiration.helper")
            writeNowButton(idea)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    /// The direct way, as a quiet text action so it never competes with "Start with it": "✦ Draft it now" with Apple Intelligence,
    /// "Write it yourself" (a blank draft) without it.
    private func writeNowButton(_ idea: ThemeIdea?) -> some View {
        Button {
            if let idea { writeNow(idea) }
        } label: {
            Group {
                if canDraft {
                    HStack(spacing: 6) {
                        Text(verbatim: "✦").accessibilityHidden(true)
                        Text("Draft it now")
                    }
                } else {
                    Text("Write it yourself")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(canDraft ? Palette.aiText : Palette.ink2)
            .padding(.horizontal, 12)
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(idea == nil || transition.isActive)
        .opacity(idea == nil ? 0.4 : 1)
        .onGeometryChange(for: CGPoint.self) { proxy in
            let frame = proxy.frame(in: .global)
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { writeCenter = $0 }
        .accessibilityHint(Text(writeNowHint))
        .accessibilityIdentifier("inspiration.writeNow")
    }

    private var writeNowHint: LocalizedStringKey {
        canDraft ? "Drafts it now. Change anything after." : "Opens a blank draft with this idea as its title."
    }

    /// The next idea: the card leaves `towards` a side (thrown there by a drag, or tapped away to the leading side), with the sparkles and
    /// their ticks when a new one comes (at the end of what is ready the card stays and goes back to its place).
    private func another(towards side: CGFloat = -1, thrown: Bool = false) {
        guard viewModel.idea != nil else { return }
        leavesTowards = side
        wasThrown = thrown
        let turn = viewModel.turn
        viewModel.another()
        if viewModel.turn != turn { HapticPatterns.playSparkles() } else { Haptics.selection() }
        settleCard()
    }

    /// The brief goes into the composer on Scripts, and the composer takes the keyboard once the sheet has gone. Words the creator had
    /// there are never lost silently: a toast says so, with Undo.
    private func use(_ idea: ThemeIdea) {
        HapticPatterns.playCommit()
        notifications.recordUse(.ideas)
        let replaced = viewModel.use(idea)
        presentation.selectedTab = .scripts
        presentation.scriptsPath = []
        focusesComposer = true
        offersUndo = replaced
        dismiss()
    }

    /// Written as it is: the star rises from the button and the page opens under it. Without Apple Intelligence, a blank draft named after it.
    private func writeNow(_ idea: ThemeIdea) {
        notifications.recordUse(.ideas)
        viewModel.willWrite(idea)
        dismiss()
        guard canDraft else {
            // Not `starter.writeByHand`, which empties the composer: the creator's own draft stays where it was.
            let script = library.create(
                title: idea.title, text: "", platform: starter.platform, type: ideaDraft.format, language: languages.scriptLanguage, isFinished: false
            )
            presentation.openScript(script.id, editing: true)
            return
        }
        HapticPatterns.playTakeoff()
        let note = idea.logbookID
        starter.write(
            idea: FindInspirationViewModel.writingText(of: idea), length: idea.brief == nil ? idea.length : nil, brief: idea.brief,
            from: writeCenter
        ) { [logbook] scriptID in
            if let note { logbook.markShaped(note, as: scriptID) }
        }
    }
}

#if DEBUG
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) { FindInspirationSheet(services: .preview) }
        .previewEnvironment()
}
#endif
