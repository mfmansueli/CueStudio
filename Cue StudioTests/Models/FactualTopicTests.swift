//
//  FactualTopicTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("FactualTopic")
struct FactualTopicTests {
    @Test(arguments: [
        "2 minutes on how the electric shower was invented in Brazil",
        "A history fact that sounds fake",
        "Explain compound interest like I’m 12",
        "Como surgiu o chuveiro elétrico",
        "A história do Pix",
    ])
    func factualTopics(_ prompt: String) {
        #expect(FactualTopic.isFactual(prompt))
    }

    @Test(arguments: ["Why I quit coffee for 30 days", "A day in my life as a creator", "My Sunday reset"])
    func personalTopics(_ prompt: String) {
        #expect(!FactualTopic.isFactual(prompt))
    }
}
