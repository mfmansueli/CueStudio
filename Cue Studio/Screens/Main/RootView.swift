//
//  RootView.swift
//  Cue Studio
//

import AppIntents
import SwiftUI

/// Injects the app session's services and takes requests from Siri and Shortcuts. Cue has no
/// onboarding gate: a first run simply shows the empty library.
struct RootView: View {
    let services: AppServices

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let languages = services.languages
        ZStack {
            content
            // The first flight, over the whole app, until it is told or skipped.
            if services.onboarding.isActive {
                OnboardingView(services: services)
                    .transition(.opacity)
            }
        }
            .animation(.easeInOut(duration: 0.5), value: services.onboarding.isActive)
            // A new interface language rebuilds the screens, so every string is read again in it.
            // Navigation lives in PresentationService, so the creator stays where they were.
            .id(languages.interfaceLanguage)
            // Inside the environment: the host reads ToastService from it.
            .toastHost()
            .environment(services)
            .environment(\.locale, languages.interfaceLocale)
            // Dark only: the night is the identity.
            .preferredColorScheme(.dark)
            .environment(\.layoutDirection, LayoutDirection(rightToLeft: languages.interfaceLanguage.isRightToLeft))
            .task {
                await services.store.start()
            }
            .task {
                await services.rules.refresh()
            }
            .task {
                await services.session.verify()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await services.store.refreshEntitlements() }
                // "Stop Using Apple ID" happens in Settings, outside Cue.
                Task { await services.session.verify() }
            }
            .onChange(of: IntentRouter.shared.pending, initial: true) {
                handleIntent()
            }
            // A notification tapped (also the one that launched Cue): taken once the first flight is over and nothing is being recorded.
            .onChange(of: NotificationRouter.shared.pending.count, initial: true) { handleNotificationTaps() }
            .onChange(of: services.onboarding.isActive) { handleNotificationTaps() }
            .onChange(of: services.presentation.prompter == nil) { handleNotificationTaps() }
            .modifier(NotificationTriggers(services: services, onActive: handleNotificationTaps))
            // A remote pairing code scanned with the Camera on this device.
            .onOpenURL { url in
                // TikTok's Share Kit answers through a universal link.
                if services.sharing.handleCallback(url) { return }
                guard let code = RemotePairing.code(from: url), services.remote.join(code: code) else { return }
                services.presentation.openRemoteController()
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL { _ = services.sharing.handleCallback(url) }
            }
            .onChange(of: services.library.scripts.count, initial: true) {
                // Keeps "Record {script}" phrases in step with the library.
                CueShortcuts.updateAppShortcutParameters()
            }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if CommandLine.arguments.contains("-uiTestCatalogue") {
            DesignCatalogueView(section: Self.catalogueSection)
        } else {
            MainView(services: services)
        }
        #else
        MainView(services: services)
        #endif
    }

    #if DEBUG
    /// `-uiTestCatalogue <section>` opens the design catalogue on that section.
    private static var catalogueSection: DesignCatalogueView.Section {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "-uiTestCatalogue"), arguments.indices.contains(index + 1) else { return .colors }
        return DesignCatalogueView.Section.allCases.first { $0.rawValue.lowercased() == arguments[index + 1].lowercased() } ?? .colors
    }
    #endif

    /// The first flight, the camera, the editor or the remote hold a tap back until they close; then it opens what it names (checked
    /// again by `NotificationNavigator`), or the tool's introduction first.
    private func handleNotificationTaps() {
        let presentation = services.presentation
        guard !services.onboarding.isActive, presentation.prompter == nil, !presentation.showsRemoteController,
              let interaction = NotificationRouter.shared.take() else { return }
        Task {
            if let opening = await services.notifications.open(interaction) {
                if let intro = opening.intro {
                    presentation.scriptsPath = []
                    presentation.present(.featureIntro(intro))
                } else {
                    await NotificationNavigator(services: services).go(to: opening.destination)
                }
            }
            handleNotificationTaps()
        }
    }

    private func handleIntent() {
        guard let route = IntentRouter.shared.take() else { return }
        switch route {
        case .record(let id):
            guard services.library.script(id: id) != nil else { return }
            services.presentation.openPrompter(scriptID: id, mode: .selfie)
        case .newScript:
            services.presentation.closePrompter()
            services.presentation.present(.newScript)
        }
    }
}
