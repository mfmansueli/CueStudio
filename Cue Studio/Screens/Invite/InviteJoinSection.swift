//
//  InviteJoinSection.swift
//  Cue Studio
//

import SwiftUI

/// "Have a friend's code?": a quiet row that opens the field and Join, offered only before this iPhone's first export (a friend's reward is for
/// bringing someone new). It starts open, with the keyboard, when the creator came for it (Ready to travel's link, or nothing else to show).
/// The answer shows under the field; once a code counted, the section says so instead.
struct InviteJoinSection: View {
    var startsOpen = false
    /// True while the field has the keyboard (the sheet hides Share invite meanwhile).
    @Binding var isTyping: Bool

    @Environment(ReferralService.self) private var referral
    @State private var isOpen = false
    @State private var typed = ""
    @State private var answer: ReferralJoinOutcome?
    @State private var isJoining = false
    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            if let code = referral.joinedCode {
                Label {
                    Text("You joined with \(InviteCodeCard.spaced(code)). Your friend’s reward arrives when you export your first video.")
                        .cueFont(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.successText)
                }
                .accessibilityIdentifier("invite.joined")
            } else {
                Button {
                    withAnimation(.smooth) { isOpen.toggle() }
                    if isOpen { focused = true }
                } label: {
                    HStack {
                        Text("Have a friend’s code?")
                            .cueFont(16, weight: .semibold)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .cueFont(.footnote, weight: .semibold)
                            .foregroundStyle(Palette.ink2)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOpen ? .isSelected : [])
                .accessibilityIdentifier("invite.friendCodeRow")
                if isOpen { field.transition(.opacity.combined(with: .move(edge: .top))) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Palette.surface, in: shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(.smooth, value: referral.joinedCode)
        .task {
            // Came for it: open, and the keyboard once the sheet has settled.
            guard startsOpen, referral.joinedCode == nil else { return }
            isOpen = true
            try? await Task.sleep(for: .milliseconds(450))
            focused = true
        }
        .onChange(of: focused) { isTyping = focused }
    }

    private var field: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReflowStack(spacing: 10) {
                TextField("Invite code", text: $typed, prompt: Text("Invite code").foregroundStyle(Palette.ink2))
                    .monoFont(size: 18, weight: .semibold)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.join)
                    .focused($focused)
                    .onSubmit(join)
                    .padding(.horizontal, 12)
                    .frame(minHeight: Metrics.hitTarget)
                    .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous)
                            .strokeBorder(focused ? Palette.acc : Color.clear, lineWidth: 1.5)
                    )
                    .onChange(of: typed) { answer = nil }
                    .accessibilityIdentifier("invite.codeField")
                Button(action: join) {
                    if isJoining { ProgressView() } else { Text("Join") }
                }
                .buttonStyle(.cueSecondary(expands: false))
                .disabled(ReferralCode.normalized(typed) == nil || isJoining)
                .accessibilityIdentifier("invite.joinButton")
            }
            Text(verbatim: answer.flatMap(InviteCopy.joinAnswer) ?? String(localized: "Type it before your first export."))
                .cueFont(.footnote)
                .foregroundStyle(answer.flatMap(InviteCopy.joinAnswer) == nil ? Palette.ink2 : Palette.warnText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("invite.joinAnswer")
        }
        .padding(.bottom, 10)
    }

    private func join() {
        guard !isJoining, ReferralCode.normalized(typed) != nil else { return }
        isJoining = true
        Task {
            let outcome = await referral.join(typed)
            isJoining = false
            answer = outcome
            if outcome == .joined {
                focused = false
                Haptics.success()
            }
        }
    }
}
