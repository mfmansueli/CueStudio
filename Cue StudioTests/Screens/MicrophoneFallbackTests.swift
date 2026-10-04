//
//  MicrophoneFallbackTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("MicrophoneFallback")
struct MicrophoneFallbackTests {
    private let iPhone = MicrophoneOption(id: "built-in", name: "iPhone Microphone", detail: "Built-in", isBuiltIn: true)
    private let airPods = MicrophoneOption(id: "airpods-pro", name: "AirPods Pro", detail: "Bluetooth")
    private let preferred = MicrophoneChoice.input(id: "airpods-pro", name: "AirPods Pro")

    @Test func saysWhichMicIsMissingAndWhatRecordsInstead() {
        let notice = MicrophoneFallback.notice(for: preferred, available: [iPhone], inUse: nil)
        #expect(notice == "No AirPods Pro · Using iPhone Microphone")
    }

    @Test func staysQuietWhenThePreferredMicIsThere() {
        #expect(MicrophoneFallback.notice(for: preferred, available: [iPhone, airPods], inUse: airPods) == nil)
    }

    @Test func staysQuietForAutomaticOrUnknownInputs() {
        #expect(MicrophoneFallback.notice(for: .automatic, available: [iPhone], inUse: iPhone) == nil)
        #expect(MicrophoneFallback.notice(for: preferred, available: [], inUse: nil) == nil)
    }
}
