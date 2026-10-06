//
//  VoiceChapter.swift
//  Cue Studio
//

import SwiftUI

/// Chapter 4, 1.5: "Your script is ready. Now it needs you." The microphone and the camera, asked for in the story, one row each: a row
/// the creator has not answered says "Allow" (the next one in yellow) and asks the system; one they refused says "Off · Turn on" and opens
/// Settings (the system doesn't ask twice); **Continue** asks for what is left. The flight never stops for a refusal. The art at the top
/// (`VoicePermissionsArt`) lights the camera's lens when the camera is allowed.
struct VoiceChapter: View {
    let model: OnboardingViewModel
    let onDone: () -> Void
    /// UI tests taking pictures: the art stands still at this second of the board's timeline (the board allows the camera at 4.4 s).
    var frozenAt: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    /// When the camera became allowed (long ago if it already was), for the art's unlock.
    @State private var cameraAllowedAt: Date?

    var body: some View {
        MotionScreen(hold: 0.01, loops: true, frozenAt: frozenAt) { time in
            content(time)
        }
        .onAppear { if model.camera == .allowed, cameraAllowedAt == nil { cameraAllowedAt = .distantPast } }
        .onChange(of: model.camera) { _, state in
            if state == .allowed, cameraAllowedAt == nil { cameraAllowedAt = .now }
        }
        // Back from Settings, where something may have been turned on.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshPermissions() }
        }
        .animation(.easeOut(duration: 0.25), value: model.hasDenied)
    }

    private func unlockAge(_ time: MotionTime) -> Double? {
        // A picture of the board at a second shows the unlock whatever the camera's real state.
        if let frozenAt { return frozenAt >= 3.7 ? frozenAt - 3.7 : nil }
        guard model.camera == .allowed else { return nil }
        return cameraAllowedAt.map { reduceMotion ? 99 : time.now.timeIntervalSince($0) }
    }

    private func content(_ time: MotionTime) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VoicePermissionsArt(unlockAge: unlockAge(time), time: reduceMotion ? 0 : time.ambient)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .horizontal)
            OnboardingHeading(
                label: OnboardingStep.voice.chapterLabel, title: Self.twoLines(String(localized: "Your script is ready. Now it needs you.")),
                subtitle: String(localized: "For voice following and framing. Stays on this iPhone."), poses: [MotionPose(), MotionPose(), MotionPose()]
            )
            .padding(.horizontal, 24)
            .padding(.top, 10)
            Spacer(minLength: 24)
            rows
                .padding(.horizontal, 16)
            footnote
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.inkHint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 19)
            Spacer(minLength: 12)
            OnboardingPrimaryButton(
                title: String(localized: "Continue"), isEnabled: !model.isAskingPermissions,
                identifier: "onboarding.continue"
            ) {
                Task {
                    if !model.hasAnsweredEverything { await model.askPermissions() }
                    try? await Task.sleep(for: .milliseconds(600))
                    onDone()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    /// The board sets the title as two lines, one sentence each; the first sentence's end ends the line (in any language's full stop).
    private static func twoLines(_ title: String) -> String {
        for stop in [". ", "。", "। ", "؟ ", "! ", "? "] {
            guard let range = title.range(of: stop), range.upperBound < title.endIndex else { continue }
            return title.replacingCharacters(in: range, with: stop.trimmingCharacters(in: .whitespaces) + "\n")
        }
        return title
    }

    private var rows: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return VStack(spacing: 0) {
            row(
                Permission(
                    symbol: "mic", title: String(localized: "Microphone"), detail: String(localized: "So the text follows your voice"),
                    tint: Palette.accText, identifier: "microphone"
                ),
                state: model.microphone, isNext: model.microphone == .notAsked
            ) { Task { await model.askMicrophone() } }
            Divider().overlay(Palette.separator)
            row(
                Permission(
                    symbol: "camera", title: String(localized: "Camera"), detail: String(localized: "So you can see yourself while you read"),
                    tint: Palette.aiText, identifier: "camera"
                ),
                state: model.camera, isNext: model.microphone != .notAsked && model.camera == .notAsked
            ) { Task { await model.askCamera() } }
        }
        .background(Palette.surface, in: shape)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.separator, lineWidth: 0.5))
    }

    /// Reassurance first; if something was refused, the way on: the practice still works, and Settings is where it changes.
    @ViewBuilder
    private var footnote: some View {
        if model.hasDenied {
            Text("No problem, you can still practice. Turn them on in Settings whenever you want to record.")
                .accessibilityIdentifier("onboarding.permission.deniedNote")
        } else {
            Text("Cue only records when you tap Record.")
        }
    }

    /// What a row says about its permission.
    private struct Permission {
        let symbol: String
        let title: String
        let detail: String
        let tint: Color
        let identifier: String
    }

    @ViewBuilder
    private func row(_ permission: Permission, state: PermissionState, isNext: Bool, ask: @escaping () -> Void) -> some View {
        let identifier = permission.identifier
        let content = HStack(spacing: 12) {
            Image(systemName: permission.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(permission.tint)
                .frame(width: 36, height: 36)
                .background(
                    permission.tint.opacity(permission.identifier == "camera" ? 0.18 : 0.14),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(permission.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(permission.detail).font(.system(size: 12.5)).foregroundStyle(Palette.flightInk.opacity(0.6))
            }
            Spacer(minLength: 8)
            stateBadge(state, isNext: isNext, isFollowUp: permission.identifier == "camera" && model.microphone != .notAsked)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .background(isNext ? Palette.nightViolet.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        if state == .allowed {
            content
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("onboarding.permission.\(identifier)")
        } else {
            // Not answered: the system's prompt. Refused: the system won't ask twice, so Settings.
            Button {
                Haptics.selection()
                if state == .denied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } else {
                    ask()
                }
            } label: { content }
                .buttonStyle(.plain)
                .disabled(model.isAskingPermissions)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("onboarding.permission.\(identifier)")
        }
    }

    @ViewBuilder
    private func stateBadge(_ state: PermissionState, isNext: Bool, isFollowUp: Bool) -> some View {
        switch state {
        case .allowed:
            Text("✓ Allowed")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.successText)
                .padding(.horizontal, 10).frame(height: 26)
                .background(Palette.success.opacity(0.16), in: Capsule())
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        case .denied:
            HStack(spacing: 6) {
                Text("Off")
                Text(verbatim: "·").accessibilityHidden(true)
                Text("Turn on")
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Palette.warnText)
            .padding(.horizontal, 10).frame(height: 26)
            .background(Palette.warnSoft, in: Capsule())
        case .notAsked:
            // The board says "Next" on the step that follows an answered one, and "Allow" on the first.
            Text(isNext && isFollowUp ? "Next" : "Allow")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isNext ? Palette.accText : Palette.ink2)
                .padding(.horizontal, 10).frame(height: 26)
                .overlay(Capsule().strokeBorder(isNext ? Palette.acc.opacity(0.6) : Palette.glassBorder, lineWidth: 1))
        }
    }
}
