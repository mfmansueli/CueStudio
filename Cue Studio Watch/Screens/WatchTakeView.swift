//
//  WatchTakeView.swift
//  Cue Studio Watch
//

import SwiftUI

/// A take, in two pages one swipe apart: its time with End, and (with a script) the text's controls.
struct WatchTakeView: View {
    @Bindable var session: WatchSessionModel

    var body: some View {
        if session.state?.scriptTitle != nil {
            TabView(selection: $session.page) {
                ScrollView { VStack(spacing: 8) { WatchRecordingPage(session: session) }.padding(.horizontal, 4) }
                    .tag(WatchSessionModel.Page.recording)
                ScrollView { VStack(spacing: 8) { WatchTextControls(session: session, isRecording: true) }.padding(.horizontal, 4) }
                    .tag(WatchSessionModel.Page.text)
            }
            .tabViewStyle(.verticalPage)
        } else {
            ScrollView { VStack(spacing: 8) { WatchRecordingPage(session: session) }.padding(.horizontal, 4) }
        }
    }
}
