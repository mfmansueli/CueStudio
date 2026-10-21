//
//  SettingsRootRow.swift
//  Cue Studio
//

import SwiftUI

/// The rows of the Settings root: the pages (Recording, Prompter, Remote…), Pro, and About.
struct SettingsRootRow: View {
    let entry: SettingsEntry
    let bindings: SettingsBindings

    @Environment(StoreManager.self) private var store
    @Environment(ToastService.self) private var toast
    @Environment(LanguageService.self) private var languages
    @Environment(RemoteControlService.self) private var remote
    @Environment(CreatorProfileService.self) private var profile
    @Environment(UsageQuotaService.self) private var quota
    @Environment(NotificationService.self) private var notifications

    @State private var paywall: PaywallContext?
    @State private var showsPrivacy = false

    var body: some View {
        content
            .accessibilityIdentifier("settings.\(entry.rawValue)")
            .fullScreenCover(item: $paywall) { PaywallView(context: $0) }
    }

    @ViewBuilder
    private var content: some View {
        switch entry {
        case .recording:
            link(.recording, .recording, value: recordingValue)
        case .prompter:
            link(.prompter, .prompter, value: bindings.prompter.wrappedValue.scrollMode.shortLabel)
        case .remote:
            link(.remote, .remote, value: remoteValue)
        case .myCueVoice:
            link(.myCueVoice, .voice, value: "\(profile.profile.voiceStrength)%")
        case .personalize:
            link(.personalize, .personalize, badge: String(localized: "NEW"))
        case .languageRegion:
            link(.languageRegion, .language, value: languages.interfaceLanguage.nativeName)
        case .notifications:
            link(.notifications, .notifications, value: notificationsValue)
        case .privacy:
            link(.privacy, .privacy)
        case .cuePro:
            Button { paywall = .profile } label: {
                SettingsIconLabel(icon: .pro, title: entry.title, value: proValue)
            }
            .buttonStyle(.plain)
        case .restorePurchases:
            Button {
                Task {
                    let restored = await store.restore()
                    toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                }
            } label: {
                SettingsIconLabel(icon: .restore, title: entry.title, titleColor: Palette.accText)
            }
            .buttonStyle(.plain)
        case .privacyPolicy:
            if let url = AppLinks.privacyPolicy {
                Link(destination: url) {
                    SettingsIconLabel(icon: .policy, title: entry.title)
                }
            } else {
                Button { showsPrivacy = true } label: {
                    SettingsIconLabel(icon: .policy, title: entry.title)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
            }
        case .termsOfUse:
            if let url = AppLinks.termsOfUse {
                Link(destination: url) {
                    SettingsIconLabel(icon: .terms, title: entry.title)
                }
            }
        case .acknowledgements:
            link(.acknowledgements, .acknowledgements)
        case .version:
            SettingsIconLabel(icon: .version, title: entry.title, value: Self.version)
        default:
            EmptyView()
        }
    }

    /// "Free · 4 left", or "Pro".
    private var proValue: String {
        guard let left = quota.exportsLeft(for: store.tier) else { return String(localized: "Pro") }
        return String(localized: "Free · \(left) left")
    }

    /// "Off" when iOS doesn't allow Cue's notifications, else how many reminders are set.
    private var notificationsValue: String? {
        if notifications.authorization == .denied { return String(localized: "Off") }
        let count = notifications.upcomingReminders.count
        return count == 0 ? nil : String(localized: "Reminders: \(count)")
    }

    /// "Front · 1080p"
    private var recordingValue: String {
        let camera = bindings.camera.wrappedValue
        let lens = camera.lens.isFront ? String(localized: "Front") : String(localized: "Back")
        return "\(lens) · \(camera.resolution.label)"
    }

    private var remoteValue: String {
        switch remote.state {
        case .off, .failed: String(localized: "Off")
        case .waiting, .searching: String(localized: "Waiting")
        case .connected: String(localized: "Connected")
        }
    }

    /// "1.0 (12)"
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func link(_ route: SettingsRoute, _ icon: SettingsIcon, value: String? = nil, badge: String? = nil) -> some View {
        NavigationLink(value: route) {
            SettingsIconLabel(icon: icon, title: entry.title, value: value, badge: badge)
        }
    }
}
