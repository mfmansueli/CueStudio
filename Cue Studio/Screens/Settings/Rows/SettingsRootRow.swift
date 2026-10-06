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
            link(.recording, "video.fill", Palette.danger, value: recordingValue)
        case .prompter:
            link(.prompter, "text.alignleft", Palette.acc, glyph: Palette.accInk, value: bindings.prompter.wrappedValue.scrollMode.shortLabel)
        case .remote:
            link(.remote, "iphone.radiowaves.left.and.right", Palette.iconBlue, value: remoteValue)
        case .myCueVoice:
            link(.myCueVoice, "sparkle", Palette.iconIndigo, value: "\(profile.profile.voiceStrength)%")
        case .personalize:
            link(.personalize, "sparkles", Palette.iconPurple, badge: String(localized: "NEW"))
        case .languageRegion:
            link(.languageRegion, "globe", Palette.iconTeal, value: languages.interfaceLanguage.nativeName)
        case .privacy:
            link(.privacy, "hand.raised.fill", Palette.success)
        case .cuePro:
            Button { paywall = .profile } label: {
                SettingsIconLabel(
                    systemImage: "star.fill", tint: Palette.iconPro, glyph: Palette.acc, title: entry.title, value: proValue
                )
            }
            .buttonStyle(.plain)
        case .restorePurchases:
            Button {
                Task {
                    let restored = await store.restore()
                    toast.show(restored ? String(localized: "Purchases restored") : String(localized: "No purchases to restore"))
                }
            } label: {
                SettingsIconLabel(systemImage: "arrow.clockwise", tint: Palette.iconNeutral, title: entry.title, titleColor: Palette.accText)
            }
            .buttonStyle(.plain)
        case .privacyPolicy:
            if let url = AppLinks.privacyPolicy {
                Link(destination: url) {
                    SettingsIconLabel(systemImage: "doc.text.fill", tint: Palette.iconNeutral, title: entry.title)
                }
            } else {
                Button { showsPrivacy = true } label: {
                    SettingsIconLabel(systemImage: "doc.text.fill", tint: Palette.iconNeutral, title: entry.title)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showsPrivacy) { PrivacySheet() }
            }
        case .termsOfUse:
            if let url = AppLinks.termsOfUse {
                Link(destination: url) {
                    SettingsIconLabel(systemImage: "doc.text.fill", tint: Palette.iconNeutral, title: entry.title)
                }
            }
        case .acknowledgements:
            link(.acknowledgements, "info.circle.fill", Palette.iconNeutral)
        case .version:
            SettingsIconLabel(systemImage: "info.circle.fill", tint: Palette.iconNeutral, title: entry.title, value: Self.version)
        default:
            EmptyView()
        }
    }

    /// "Free · 4 left", or "Pro".
    private var proValue: String {
        guard let left = quota.exportsLeft(for: store.tier) else { return String(localized: "Pro") }
        return String(localized: "Free · \(left) left")
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

    private func link(
        _ route: SettingsRoute, _ image: String, _ tint: Color, glyph: Color = .white, value: String? = nil, badge: String? = nil
    ) -> some View {
        NavigationLink(value: route) {
            SettingsIconLabel(systemImage: image, tint: tint, glyph: glyph, title: entry.title, value: value, badge: badge)
        }
    }
}
