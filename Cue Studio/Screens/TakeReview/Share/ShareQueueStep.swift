//
//  ShareQueueStep.swift
//  Cue Studio
//

import SwiftUI

/// 8.1 · Post to {network}: "1 OF 3", the bar, what to do there (the caption is copied and can be edited, the captions are in the video, the share
/// sheet), the "◀ Cue" reminder, and **Send to {app}**, **Edit first**, **Post later**. Post later is a menu: a reminder tonight, tomorrow or at a
/// time the creator picks, or none; every choice leaves the network for later, as before.
struct ShareQueueStep: View {
    @Bindable var flow: ShareFlow
    let queue: ShareQueue
    let network: ShareDestination
    let hasCaptions: Bool

    @Environment(NotificationService.self) private var notifications
    @Environment(ToastService.self) private var toast
    @State private var picksTime = false

    private var subject: ReminderSubject { .share(takeID: queue.takeID, network: network) }

    private var item: ShareQueueItem { queue.items.first { $0.network == network } ?? ShareQueueItem(network: network, state: .pending) }

    var body: some View {
        VStack(spacing: 14) {
            header
            ShareQueueBar(items: queue.items, current: network).padding(.horizontal, Metrics.gutter)
            checklist
            reminder
            VStack(spacing: 4) {
                Button { Task { await flow.send(to: network) } } label: { Text("Send to \(network.platform.label)").frame(maxWidth: .infinity) }
                    .buttonStyle(.cuePrimary(.large))
                    .accessibilityIdentifier("shareFlow.send")
                HStack {
                    Button("Edit first") { flow.editFirst() }.accessibilityIdentifier("shareFlow.editFirst")
                    Spacer()
                    postLater
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink2)
                .padding(.horizontal, 40)
                .frame(minHeight: Metrics.hitTarget)
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("shareFlow.step")
    }

    private var postLater: some View {
        let calendar = Calendar.current
        return Menu {
            if let tonight = ReminderChoice.tonight.time(now: .now, calendar: calendar) {
                Button { remind(at: tonight) } label: { Label("Tonight · \(clock(tonight))", systemImage: "moon") }
                    .accessibilityIdentifier("shareFlow.remindTonight")
            }
            if let tomorrow = ReminderChoice.tomorrow.time(now: .now, calendar: calendar) {
                Button { remind(at: tomorrow) } label: { Label("Tomorrow · \(clock(tomorrow))", systemImage: "sunrise") }
                    .accessibilityIdentifier("shareFlow.remindTomorrow")
            }
            Button { picksTime = true } label: { Label("Pick a date and time…", systemImage: "calendar") }
                .accessibilityIdentifier("shareFlow.remindPick")
            Divider()
            Button { flow.postLater(network) } label: { Label("No reminder", systemImage: "bell.slash") }
                .accessibilityIdentifier("shareFlow.noReminder")
        } label: {
            Text("Post later")
        }
        .accessibilityIdentifier("shareFlow.postLater")
        .sheet(isPresented: $picksTime) {
            ReminderSheet(subject: subject, title: queue.title, startsPicking: true) { result in
                flow.postLater(network)
                ReminderFeedback.show(result, toast: toast)
            }
        }
    }

    private func clock(_ time: LocalDateTime) -> String {
        (time.date(in: .current) ?? .now).formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.interface))
    }

    /// The network waits for later, and the reminder is set for it (the toast says whether iOS took it).
    private func remind(at time: LocalDateTime) {
        flow.postLater(network)
        Task {
            let result = await notifications.setReminder(subject, title: queue.title, at: time)
            ReminderFeedback.show(result, toast: toast)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("\(queue.position(of: item)) OF \(queue.count)")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.ink2)
                .accessibilityIdentifier("shareFlow.position")
            Text("Post to \(network.platform.label)").font(.headline)
        }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.successText).frame(width: 20)
                Text("Caption copied · paste it in \(network.platform.label)").font(.system(size: 16)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Copy again") { flow.copy() }
                    .font(.system(size: 15)).foregroundStyle(Palette.aiText)
                    .accessibilityIdentifier("shareFlow.copyAgain")
            }
            TextField("Caption", text: $flow.caption, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...3)
                .padding(12)
                .background(Palette.surface3, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.leading, 32)
                .accessibilityIdentifier("shareFlow.caption")
            if hasCaptions {
                row("checkmark", Palette.successText, "Your captions are in the video · keep auto captions off")
            }
            row("arrow.up.right", Palette.ink2, "In the share sheet, tap \(network.platform.label)")
        }
        .padding(16)
        .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, Metrics.gutter)
    }

    private func row(_ symbol: String, _ tint: Color, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 14, weight: .bold)).foregroundStyle(tint).frame(width: 20)
            Text(text).font(.system(size: 16)).foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
    }

    /// "After posting, tap ◀ Cue at the top left. We'll open Reels next." (the last one: "… to finish.")
    private var reminder: some View {
        HStack(spacing: 12) {
            Text("◀ Cue")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Palette.surface3, in: Capsule())
            Group {
                if let next = queue.next, next.network != network {
                    Text("After posting, tap ◀ Cue at the top left. We'll open \(Text(next.network.platform.label).foregroundStyle(Palette.accText)) next.")
                } else {
                    Text("After posting, tap ◀ Cue at the top left. We'll come back to finish.")
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.acc.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.acc.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, Metrics.gutter)
        .accessibilityElement(children: .combine)
    }
}
