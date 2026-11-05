//
//  InviteFriendsSheet.swift
//  Cue Studio
//

import SwiftUI

/// Invite friends (DESIGN_PROJECT §60): the orbit with a planet for each friend who counted and what one friend brings in large, the code that
/// copies with a tap, three short steps, "Have a friend's code?" before this iPhone's first export, and the small print; **Share invite**
/// stays at the bottom, over the safe area (out of the way while a friend's code is typed, the field scrolled above the keyboard). Opened
/// from Profile, from "Ready to travel" with one free export left or none (and before the first export, for a friend's code: the field
/// opens with the keyboard), and from "Your video is ready". Opening it asks Cue's server for the code and a fresh count.
struct InviteFriendsSheet: View {
    let place: ReferralTelemetryEvent.Place

    @Environment(ReferralService.self) private var referral
    @Environment(\.dismiss) private var dismiss
    @State private var isTyping = false
    @State private var isSharing = false

    private static let joinID = "invite.join"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView { content }
                    .scrollDismissesKeyboard(.interactively)
                    .safeAreaInset(edge: .bottom) {
                        if referral.isOffered && !isTyping { shareBar.transition(.opacity) }
                    }
                    .onChange(of: isTyping) {
                        guard isTyping else { return }
                        // Once the keyboard is up: the field and its answer above it.
                        Task {
                            try? await Task.sleep(for: .milliseconds(350))
                            withAnimation(.smooth) { proxy.scrollTo(Self.joinID, anchor: .bottom) }
                        }
                    }
            }
            .animation(.smooth(duration: 0.2), value: isTyping)
            .navigationTitle("Invite friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("invite.doneButton")
                }
            }
        }
        .tint(Palette.ink)
        .toastHost(inSheet: true)
        .presentationDetents([.large])
        .presentationBackground(Palette.sheetNight)
        .accessibilityIdentifier("invite.sheet")
        .sheet(isPresented: $isSharing) {
            if let status = referral.status {
                let message = InviteCopy.message(code: status.code, link: AppStoreLink.app())
                ActivityView(items: [InviteShareItem(message: message, title: InviteCopy.shareTitle)])
                    .presentationDetents([.medium, .large])
            }
        }
        .task {
            referral.note(.opened, at: place)
            if referral.isOffered { await referral.refresh() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if referral.isOffered {
                InviteHero(reward: referral.reward, status: referral.status, rewards: referral.rewards)
                InviteCodeCard(place: place).padding(.top, 24)
                InviteSteps(reward: referral.reward).padding(.top, 28).padding(.horizontal, 4)
            }
            if referral.canJoin || referral.joinedCode != nil {
                InviteJoinSection(startsOpen: place == .firstExport || !referral.isOffered, isTyping: $isTyping)
                    .padding(.top, referral.isOffered ? 28 : 8)
                    .id(Self.joinID)
            }
            Text("Only friends new to Cue count, once per iPhone. Your friend gets Cue’s free exports, like everyone.")
                .cueFont(.footnote)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 20)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, Metrics.gutter)
    }

    /// Share invite: the system share sheet with the message as plain text (`InviteShareItem`), once the code is here.
    private var shareBar: some View {
        Button {
            referral.note(.shared, at: place)
            isSharing = true
        } label: {
            Label("Share invite", systemImage: "square.and.arrow.up")
        }
        .disabled(referral.status == nil)
        .buttonStyle(.cuePrimary(.large))
        .accessibilityIdentifier("invite.shareButton")
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            LinearGradient(colors: [Palette.sheetNight.opacity(0), Palette.sheetNight], startPoint: .top, endPoint: .center)
                .padding(.top, -24)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

#if DEBUG
#Preview {
    Text(verbatim: "").sheet(isPresented: .constant(true)) { InviteFriendsSheet(place: .profile) }
        .previewEnvironment()
}
#endif
