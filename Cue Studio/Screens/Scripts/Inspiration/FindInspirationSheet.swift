//
//  FindInspirationSheet.swift
//  Cue Studio
//

import SwiftUI

/// Find inspiration (the empty Scripts' first way in, the dock's lightbulb, "+ › Let Cue write it" and the ideas notification): a large
/// sheet with "Find inspiration" and "Ideas from your topics.", the topics as chips, one featured idea (`InspirationCard`) with a small
/// orbit beside it, then "Another idea", the yellow "Use this idea" and a line saying where it goes. "Use this idea" puts the idea's brief in
/// the dock's composer, to change before anything is written (what was there comes back with Undo); "Write the script now", quieter under
/// it, writes it as it is and the star rises. Without Apple Intelligence the ideas are the starters, said so, and the direct way is
/// "Write it yourself" (a blank draft with the idea as its title). Nothing is presented as a trend or as research: they are suggestions.
struct FindInspirationSheet: View {
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    @State private var editsTopics = false
    /// Where "Write the script now" is: the star leaves from there.
    @State private var writeCenter: CGPoint?
    /// "Use this idea" was tapped: the composer takes the keyboard once the sheet has gone.
    @State private var focusesComposer = false

    init(services: AppServices) {
        _viewModel = State(initialValue: FindInspirationViewModel(
            suggestions: services.ideaSuggestions, draft: services.ideaDraft, profile: services.profile
        ))
        writer = services.writer
    }

    /// Apple Intelligence can write ideas and scripts now.
    private var hasAI: Bool { writer.writingUnavailableReason == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: String(localized: "Find inspiration"), subtitle: String(localized: "Ideas from your topics."))
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
                    .padding(.top, showsOrbit ? 30 : 18)
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
                symbol: "sparkles",
                text: Text("Pick your topics and the ideas will be about what you make. Until then, here are a few to start."),
                identifier: "inspiration.noTopicsNote"
            )
            .padding(.top, 14)
        }
        if !hasAI {
            note(
                symbol: "lightbulb",
                text: Text("Starter ideas from Cue, to write yourself. With Apple Intelligence, Cue writes new ones about your topics."),
                identifier: "inspiration.startersNote"
            )
            .padding(.top, 14)
        }
    }

    private func note(symbol: String, text: Text, identifier: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
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

    /// The orbit sits above the card's corner when there is room for it (not at the biggest text sizes).
    private var showsOrbit: Bool { !typeSize.isAccessibilitySize }

    private var cardArea: some View {
        ZStack(alignment: .top) {
            switch viewModel.content {
            case .idea(let idea):
                InspirationCard(content: viewModel.card(for: idea), worldColor: OnboardingTopic.color(at: viewModel.worldIndex(of: idea)))
                    .id(idea.id)
                    .transition(cardTransition)
                    .simultaneousGesture(swipe)
                    .accessibilityAction(named: Text("Another idea")) { another() }
            case .waiting:
                InspirationCardSkeleton(topic: chosenTopicLabel)
                    .transition(.opacity)
            case .nothing:
                nothingCard
                    .transition(.opacity)
            }
        }
        .overlay { InspirationStarBurst(trigger: viewModel.turn) }
        .overlay(alignment: .topTrailing) {
            if showsOrbit { InspirationOrbit().offset(x: 6, y: -30) }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.32), value: contentKey)
    }

    /// The idea that leaves breaks into the burst and blurs away; the next slides in from the trailing side. Reduce Motion: a cross-fade.
    private var cardTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 28)).combined(with: .scale(scale: 0.98)),
            removal: AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96))
        )
    }

    /// What the card shows, as a value the animation follows.
    private var contentKey: String {
        switch viewModel.content {
        case .idea(let idea): idea.id
        case .waiting: "waiting"
        case .nothing: "nothing"
        }
    }

    /// The topic the chips have chosen, for the waiting and empty cards.
    private var chosenTopicLabel: String? {
        viewModel.options.first { $0.id == viewModel.selectedOptionID }?.label
    }

    /// A sideways swipe on the card is "Another idea" too.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24).onEnded { value in
            let distance = value.translation
            guard abs(distance.width) > 70, abs(distance.width) > abs(distance.height) * 1.5 else { return }
            another()
        }
    }

    /// Nothing to show and nothing coming: why, honestly, and what to do.
    private var nothingCard: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return VStack(alignment: .leading, spacing: 10) {
            Text("No ideas here right now")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Group {
                if hasAI {
                    Text("Cue couldn’t write ideas about this topic just now. Try again in a moment.")
                } else {
                    Text("Cue’s starter ideas cover the topics it suggests. Apple Intelligence writes ideas about the ones you add yourself.")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Palette.ink2)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if hasAI {
                    Button {
                        viewModel.appear()
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
        .accessibilityIdentifier("inspiration.nothing")
    }

    // MARK: - Actions

    /// "Another idea", the yellow "Use this idea", what it does, and the quieter direct way.
    private var actions: some View {
        let idea = viewModel.idea
        return VStack(spacing: 10) {
            Button(action: another) {
                Label("Another idea", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.cueSecondary(.medium, expands: false))
            .disabled(idea == nil)
            .accessibilityHint(Text("Shows the next idea."))
            .accessibilityIdentifier("inspiration.another")
            Button {
                if let idea { use(idea) }
            } label: {
                Text("Use this idea")
            }
            .buttonStyle(.cuePrimary(.large))
            .disabled(idea == nil || transition.isActive)
            .accessibilityHint(Text("Puts the idea in the composer, to change before it is written."))
            .accessibilityIdentifier("inspiration.use")
            Text("It goes into the composer, so you can make it yours before Cue writes.")
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

    /// The direct way, as a quiet text action so it never competes with "Use this idea": "✦ Write the script now" with Apple Intelligence,
    /// "Write it yourself" (a blank draft) without it.
    private func writeNowButton(_ idea: ThemeIdea?) -> some View {
        Button {
            if let idea { writeNow(idea) }
        } label: {
            Group {
                if hasAI {
                    HStack(spacing: 6) {
                        Text(verbatim: "✦").accessibilityHidden(true)
                        Text("Write the script now")
                    }
                } else {
                    Text("Write it yourself")
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(hasAI ? Palette.aiText : Palette.ink2)
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
        hasAI ? "Writes a script from this idea now, as it is." : "Opens a blank draft with this idea as its title."
    }

    private func another() {
        guard viewModel.idea != nil else { return }
        Haptics.selection()
        viewModel.another()
    }

    /// The brief goes into the composer on Scripts, and the composer takes the keyboard once the sheet has gone. Words the creator had
    /// there are never lost silently: a toast says so, with Undo.
    private func use(_ idea: ThemeIdea) {
        Haptics.light()
        notifications.recordUse(.ideas)
        let replaced = viewModel.use(idea)
        presentation.selectedTab = .scripts
        presentation.scriptsPath = []
        focusesComposer = true
        dismiss()
        if replaced {
            let model = viewModel
            toast.show(
                String(localized: "This idea replaced your draft"),
                action: ToastAction(title: String(localized: "Undo")) { model.undoUse() }
            )
        }
    }

    /// Written as it is: the star rises from the button and the page opens under it. Without Apple Intelligence, a blank draft named after it.
    private func writeNow(_ idea: ThemeIdea) {
        notifications.recordUse(.ideas)
        viewModel.willWrite(idea)
        dismiss()
        guard hasAI else {
            starter.writeByHand(idea: idea.title)
            return
        }
        Haptics.medium()
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
