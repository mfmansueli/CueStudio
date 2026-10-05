//
//  ShareIntegrationConfigurationTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ShareIntegrationConfiguration")
struct ShareIntegrationConfigurationTests {
    @Test func emptyBlankAndUnexpandedValuesMeanNotSet() {
        let configuration = ShareIntegrationConfiguration(tikTokClientKey: "", tikTokRedirectURI: "  ", metaAppID: "$(CUE_META_APP_ID)")
        #expect(configuration.tikTokClientKey == nil)
        #expect(configuration.tikTokRedirectURI == nil)
        #expect(configuration.metaAppID == nil)
        #expect(!configuration.isTikTokConfigured)
        #expect(!configuration.isInstagramConfigured)
    }

    @Test func tikTokNeedsBothTheClientKeyAndTheRedirectURI() {
        #expect(!ShareIntegrationConfiguration(tikTokClientKey: "key").isTikTokConfigured)
        #expect(!ShareIntegrationConfiguration(tikTokRedirectURI: "https://cue.example/tiktok").isTikTokConfigured)
        #expect(ShareIntegrationConfiguration(tikTokClientKey: "key", tikTokRedirectURI: "https://cue.example/tiktok").isTikTokConfigured)
    }

    @Test func theShippedBundleHasNoIDsYet() {
        // Cue's own Info.plist carries the keys, empty: the integrations stay off until the developer accounts exist.
        let configuration = ShareIntegrationConfiguration.fromBundle()
        #expect(configuration.metaAppID == nil)
        #expect(!configuration.isTikTokConfigured)
    }
}
