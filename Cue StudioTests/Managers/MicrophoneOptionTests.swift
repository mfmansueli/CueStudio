//
//  MicrophoneOptionTests.swift
//  Cue StudioTests
//

import AVFAudio
import Testing
@testable import Cue_Studio

@Suite("MicrophoneOption")
struct MicrophoneOptionTests {
    private let iPhone = MicrophoneOption(id: "Built-In Microphone", name: "iPhone Microphone", port: .builtInMic)
    private let dji = MicrophoneOption(id: "dji-usb", name: "DJI Mic", port: .usbAudio)
    private let airPods = MicrophoneOption(id: "airpods", name: "AirPods Pro", port: .bluetoothHFP)

    @Test func describesThePort() {
        #expect(iPhone.isBuiltIn)
        #expect(iPhone.detail == "Built-in")
        #expect(!dji.isBuiltIn)
        #expect(dji.detail == "USB")
        #expect(airPods.detail == "Bluetooth")
        #expect(MicrophoneOption(id: "wired", name: "EarPods", port: .headsetMic).detail == "Wired headset")
    }

    @Test func namesTheInputInUse() {
        #expect(MicrophoneOption.inUse(current: dji, available: [iPhone, dji]) == dji)
    }

    @Test func fallsBackToTheIPhoneMicBeforeTheSessionReportsOne() {
        #expect(MicrophoneOption.inUse(current: nil, available: [airPods, iPhone]) == iPhone)
        #expect(MicrophoneOption.inUse(current: nil, available: [airPods]) == airPods)
        #expect(MicrophoneOption.inUse(current: nil, available: []) == nil)
    }

    @Test func namesThePickedInputBeforeTheSessionReportsOne() {
        #expect(MicrophoneOption.inUse(current: nil, preferredID: "dji-usb", available: [iPhone, dji]) == dji)
        // Picked, then unplugged: back to the iPhone's.
        #expect(MicrophoneOption.inUse(current: nil, preferredID: "dji-usb", available: [iPhone]) == iPhone)
    }

    /// Unplugging the external mic: the session reports the iPhone's, and the pill follows.
    @Test func followsTheRouteWhenAMicIsUnplugged() {
        #expect(MicrophoneOption.inUse(current: iPhone, available: [iPhone]) == iPhone)
    }
}
