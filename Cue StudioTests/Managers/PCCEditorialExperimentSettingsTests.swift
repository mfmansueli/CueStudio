import FoundationModels
import Testing
@testable import Cue_Studio

@Suite("Editorial experiment configuration")
struct PCCEditorialExperimentSettingsTests {
    @Test func defaultsKeepTheRecordedFourWayComparison() throws {
        let settings = try #require(PCCEditorialExperimentSettings(environment: [:]))
        #expect(settings.voice == .full)
        #expect(settings.reasoning == "default" && settings.reasoningLevel == nil)
        #expect(settings.modes == ["baseline", "stack-guided", "lean-guided", "lean-raw"])
        #expect(!settings.creativeSampling)
        #expect(settings.options(responseCap: 4096).maximumResponseTokens == 4096)
    }

    @Test func recordsASeparateRawCapabilityProbe() throws {
        let settings = try #require(PCCEditorialExperimentSettings(environment: [
            "CUE_QUALITY_ABLATION_VOICE": "none", "CUE_QUALITY_REASONING": "deep",
            "CUE_QUALITY_ABLATION_MODES": "lean-raw", "CUE_QUALITY_ABLATION_SAMPLING": "creative",
        ]))
        #expect(settings.voice == .none && settings.creativeSampling)
        #expect(settings.description.contains("seed17") && settings.description.contains("reasoning=deep"))
        #expect(settings.options(responseCap: 4096).temperature == 0.8)
    }

    @Test func rejectsTyposDuplicatesAndSamplingThatTheProductionControlCannotApply() {
        for environment in [
            ["CUE_QUALITY_ABLATION_VOICE": "empty"], ["CUE_QUALITY_REASONING": "deeper"],
            ["CUE_QUALITY_ABLATION_SAMPLING": "random"], ["CUE_QUALITY_ABLATION_MODES": "lean-raw,lean-raw"],
            ["CUE_QUALITY_ABLATION_MODES": ""], ["CUE_QUALITY_ABLATION_SAMPLING": "creative"],
        ] {
            #expect(PCCEditorialExperimentSettings(environment: environment) == nil)
        }
    }
}
