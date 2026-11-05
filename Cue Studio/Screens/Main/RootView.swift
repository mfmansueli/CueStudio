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
            // The text grows up to the third accessibility size: past it a row holds a word or two and the screens stop working
            // (`InterfaceType`, DESIGN_PROJECT §53).
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .environment(\.layoutDirection, LayoutDirection(rightToLeft: languages.interfaceLanguage.isRightToLeft))
            // And for UIKit, which lays out sheets, covers and navigation stacks.
            .onChange(of: languages.interfaceLanguage, initial: true) { _, language in
                InterfaceDirection.apply(rightToLeft: language.isRightToLeft)
            }
            .task {
                await services.store.start()
            }
            .task {
                await services.rules.refresh()
            }
            .task {
                await services.session.verify()
            }
            // A friend's first export the server didn't hear yet, and a creator who invites: their friends' first exports.
            .task {
                await services.referral.refreshIfInviting()
            }
            .onChange(of: scenePhase) { _, phase in
                // The motion analyses run only while Cue is in front.
                services.motion.setActive(phase == .active)
                // A deleted take's video goes before Cue can be ended unnoticed, and the Undo that would bring back a take without it goes too.
                if phase == .background, services.takes.purgeAwaiting() { services.toast.dismiss() }
                guard phase == .active else { return }
                services.reloadWhatCouldntBeRead()
                if services.hasUnsavedWork { warnUnsavedWork() }
                Task { await services.store.refreshEntitlements() }
                // "Stop Using Apple ID" happens in Settings, outside Cue.
                Task { await services.session.verify() }
                Task { await services.referral.refreshIfInviting() }
            }
            // A save that failed in front of the creator is said at once (one that failed in the background, locked, is tried
            // again on the way back first).
            .onChange(of: services.hasUnsavedWork) { _, unsaved in
                if unsaved, scenePhase == .active { warnUnsavedWork() }
            }
            .onChange(of: IntentRouter.shared.pending, initial: true) {
                handleIntent()
            }
            // A notification tapped (also the one that launched Cue): taken once the first flight is over and nothing is being recorded.
            .onChange(of: NotificationRouter.shared.pending.count, initial: true) { handleNotificationTaps() }
            .onChange(of: services.onboarding.isActive) {
                handleNotificationTaps()
                handleIntent()
            }
            .onChange(of: services.presentation.prompter == nil) {
                handleNotificationTaps()
                handleIntent()
            }
            .onChange(of: services.presentation.showsRemoteController) { handleIntent() }
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
    /// Scripts or takes are only in memory: the creator hears it while there is still time to free space.
    private func warnUnsavedWork() {
        services.toast.show(String(localized: "Couldn't save your work · Free up space on this iPhone"), kind: .problem)
    }

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

    /// A Siri shortcut waits like a notification tap: the first flight, the camera (a take being recorded would end) and the remote keep it
    /// until they close.
    private func handleIntent() {
        let presentation = services.presentation
        guard !services.onboarding.isActive, presentation.prompter == nil, !presentation.showsRemoteController,
              let route = IntentRouter.shared.take() else { return }
        switch route {
        case .record(let id):
            guard services.library.script(id: id) != nil else { return }
            presentation.openPrompter(scriptID: id, mode: .selfie)
        case .newScript:
            presentation.present(.newScript)
        }
    }
}
