# Engines, GitHub and APIs for Cue Studio — checked 27 October 2026

## Which native capabilities could improve Cue's scripts without changing provider?

### Takeaway
Keep Apple Foundation Models/PCC as the production engine. The most credible next improvement is a measured editorial pipeline and a native quality evaluation suite, rather than adding another LLM library and assuming better writing.

### Cited Findings
- Apple documents PCC context of 32K, reasoning levels light/moderate/deep, daily per-user quota, network requirement and no developer-managed authentication/API keys. Its article recommends evaluating the feature, starting reasoning at moderate, and selecting deep when measurements justify more reasoning for complex tasks. It does not promise that deep produces better creative scripts. — [Apple PCC article](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute?changes=latest_major)
- Apple explicitly confirms that `@Generable` structured output and tools work with PCC. Reasoning uses extra context tokens and adds latency; choose model and reasoning level from evaluation results. Its code shows `contextSize` can be 8192 for newer devices on OS27, despite the simplified 4K local comparison in the same presentation. Query the property rather than hardcoding a universal local capacity. — [WWDC26 PCC, 3:25 and 4:32–6:15](https://developer.apple.com/videos/play/wwdc2026/319/)
- Evaluations supplies Swift datasets, evaluators, metrics, aggregation, comparisons and model judges, and works with models available through Foundation Models. — [Evaluations overview](https://developer.apple.com/documentation/Evaluations)
- Apple demonstrates Swift Testing `.evaluates`, deterministic checks mixed with model judges, separate scoring dimensions and a focused starting set of 20–30 cases. Unit test success alone cannot establish probabilistic content quality. — [Meet Evaluations](https://developer.apple.com/videos/play/wwdc2026/298/)
- Installed SDK inspection (read-only, no compilation): `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/FoundationModels.framework/Modules/FoundationModels.swiftmodule/arm64e-apple-ios.swiftinterface` lines2082–2088 exposes typed `streamResponse(to:generating:options:contextOptions:metadata:)`; lines3130–3147 marks `ContextOptions`/reasoning iOS27/macOS27/visionOS27/watchOS27. This can apply directly to Cue's existing `ScriptDraft` stream without a separate planning generation. — [matching official PCC example](https://developer.apple.com/videos/play/wwdc2026/319/)
- Installed Xcode Evaluations interface lives under `Platforms/iPhoneOS.platform/Developer/Library/Frameworks/Evaluations.framework/Modules/Evaluations.swiftmodule/arm64e-apple-ios.swiftinterface`. `Evaluation`, `ModelJudgeEvaluator`, `ScoreDimension`, `ModelSample`, `.evaluates` are annotated anyAppleOS27, tvOS unavailable; `ModelSample<ExpectedValue>` requires Codable+Sendable. This is developer/test tooling, not a reason to ship an evaluation dependency in the production app. — [official framework](https://developer.apple.com/documentation/Evaluations)

### Inferences
- Recommended experiment, not a demonstrated quality gain: compare default/light/moderate on identical PT/EN/ES prompts, including multiple constraints, Auto format, serious statements and brand briefs. Measure blind human preference, explicit-requirement recall, voice fit, unsupported claims, repetition, length and first-token/total latency. Reserve deep for demonstrated complex-brief gains, not every quick script.
- Use a Codable evaluation DTO of the final script/result if the existing `ScriptDraft`/result does not satisfy ModelSample requirements. Evaluate the actual app service, not merely a replicated prompt, so fitting, sanitization, retries and fallbacks are included.
- Keep all sample-only user writing local under current policy; use synthetic/consented fixtures for judges. A PCC judge on the same PCC generator can share biases. Calibrate with human pairwise judgments and keep deterministic assertions independently decisive.
- Suggested quality gates: exact user names/numbers/required phrases survive; supplied facts are not strengthened; no invented personal experience; one new contribution per block; requested no-CTA preserved; opening promise delivered; chosen direction fits intent. A subjective “wow” score alone would hide regressions.

### Gaps
- No actual Cue PCC generation or head-to-head content evaluation was executed in this research. Physical-device validation remains explicitly outside current authorization.
- No official source located establishes a script-specific best reasoning level, a fixed numeric daily quota for every user, or a guaranteed latency bound. The current SDK signatures establish API applicability, not behavioral quality.

## Which GitHub projects are useful, and where would they run?

### Takeaway
The strongest candidates are development tools: native Evaluations first, optionally promptfoo or DeepEval for cross-provider/offline analysis, and DSPy/GEPA later for measured prompt optimization. None is a replacement model that can be installed inside Apple's PCC service.

### Cited Findings
- **promptfoo — developer evaluation tool, MIT.** CLI/library supports model/prompt comparisons and CI. Current repository has substantial history and a release dated 6 October2026, a maintenance signal rather than a quality guarantee. — [repository and license](https://github.com/promptfoo/promptfoo), [releases](https://github.com/promptfoo/promptfoo/releases)
- Custom JavaScript providers implement `id` and `callApi`; provider docs also support Python, executable scripts and HTTP. This offers a possible adapter to exported Cue outputs or an explicitly built local Swift harness; no out-of-the-box native iOS PCC connector was established here. — [custom provider API](https://www.promptfoo.dev/docs/providers/custom-api/), [provider documentation source](https://github.com/promptfoo/promptfoo/blob/main/site/docs/providers/index.md)
- promptfoo assertions include exact/structural checks, custom functions and model-graded comparisons. Local orchestration does not mean a configured remote model or judge receives no text. Its security policy warns that custom code/configured executable features run with user permissions and are not sandboxed. — [assertions](https://www.promptfoo.dev/docs/configuration/expected-outputs/), [security policy](https://github.com/promptfoo/promptfoo/blob/main/SECURITY.md)
- **DeepEval — Python developer evaluation tool, Apache2.0.** Repository exposes test-style evaluation and a large commit history; releases include October2026 activity. — [repository/license](https://github.com/confident-ai/deepeval), [releases](https://github.com/confident-ai/deepeval/releases)
- G-Eval permits custom natural-language criteria and evaluation steps, suitable for separate voice/fidelity/usefulness dimensions. It remains a judge mechanism, not evidence that its scores match Cue creators. — [G-Eval docs](https://deepeval.com/docs/metrics-llm-evals)
- DeepEval enables basic PostHog telemetry by default; `DEEPEVAL_TELEMETRY_OPT_OUT=1` disables it. Confident AI is a separate hosted service storing uploaded data on AWS. Remote judge inference is another data flow to review. — [privacy](https://deepeval.com/docs/data-privacy)
- **DSPy/GEPA — Python prompt/program optimization, MIT.** DSPy describes modular language-model programs and instruction optimization; release3.4.1 dated12 October2026 is an activity signal. — [README](https://github.com/stanfordnlp/dspy), [MIT](https://github.com/stanfordnlp/dspy/blob/main/LICENSE), [releases](https://github.com/stanfordnlp/dspy/releases)
- GEPA evolves textual instructions from scalar metrics plus textual feedback. It searches candidate programs and validates them against examples; useful feedback identifies omitted constraints and failure causes. It requires inference budget and a reflection model, not just a package import. — [official optimizer source docs](https://github.com/stanfordnlp/dspy/blob/main/docs/docs/api/optimizers/GEPA/overview.md)
- **Apple foundation-models-utilities — optional Swift runtime helpers/patterns, Apache2.0.** Official package offers skills, history compression and Chat Completions interoperability. Repository explicitly describes emerging/experimental patterns; only four commits were visible at inspection, so stability should not be inferred from Apple ownership. — [repository](https://github.com/apple/foundation-models-utilities)
- **Apple Python FM SDK — Mac development tool, Apache2.0.** Requirements include macOS26+, Xcode26+, Python3.10+, Apple Intelligence enabled on compatible Mac. README covers on-device inference and analysis of transcripts exported from Swift apps. Do not infer direct PCC support or iOS runtime applicability from its name. — [official repository](https://github.com/apple/python-apple-fm-sdk)

### Inferences
- First use the app's existing quality exporter/replay tools plus native Swift Evaluations; this avoids rewriting the production behavior in Python. Add promptfoo only if its matrix/diff/CI interface solves a demonstrated developer need. Do not introduce both promptfoo and DeepEval by default.
- GEPA is a later offline optimization experiment using a held-out multilingual dataset, latency/call budgets and a frozen evaluator. Export only reviewed winning instruction text back into Swift. Never let optimizer-produced prompts update production automatically or train on private creator examples.
- Auto format maps naturally to a compact editorial “skill” vocabulary, but current one-call native instructions may be simpler than tool-activated skills. Additional tool selection/calls must prove quality and latency gains before adding that runtime abstraction.
- Tools above do not remove daily PCC quotas. Repeated evaluations/optimizations can consume significant calls; remote reflection/judges introduce provider costs and content disclosure. Start with synthetic fixtures and explicit budgets.

### Gaps
- No project was installed, executed or security-audited. No precise latest release claim is made beyond the dated maintenance signals seen; GitHub pages/crawlers can lag.
- No verified drop-in DSPy/promptfoo adapter to Cue's entitled iOS PCC request path was found. A Mac-only on-device SDK is not a substitute for testing the actual iPhone codepath.

## Would external models or local runtimes make Cue better?

### Takeaway
They are possible architectural alternatives, not an established improvement over PCC. Prefer testing the current service before expanding dependencies, app size, provider privacy obligations and cost.

### Cited Findings
- **MLX Swift LM — actual local runtime candidate, MIT.** Official README provides SwiftPM LLM/VLM support, model loading, LoRA and full fine-tuning, and an `MLXFoundationModels` bridge requiring OS27SDK. It explicitly notes breaking changes on main3.x. Models/weights/tokenizers must be selected separately. — [README](https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/main/README.md), [license and repository](https://github.com/ml-explore/mlx-swift-lm)
- MLX Swift examples include iOS/macOS inference with model downloads. Metal-shader build integration and separate model assets are material integration work. — [official MLX Swift](https://github.com/ml-explore/mlx-swift)
- **llama.cpp — local C++ runtime alternative.** Official build script includes iOS-device/simulator XCFramework builds and Metal configuration. This is not Swift-only integration and says nothing about its script quality. — [official XCFramework build](https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh)
- **ClaudeForFoundationModels — third-party cloud runtime candidate, Apache2.0.** Official package conforms to LanguageModel and supports typed/streamed output. README labels APIs beta, OS27/Xcode27 requirements. App Attest authentication can avoid shipping an API key or developer backend and bills the developer workspace; a proxy is another supported option. A bundled API key is extractable. — [official Anthropic package](https://github.com/anthropics/ClaudeForFoundationModels)
- Apple lists third-party providers as separate models and links Gemini to Firebase's iOS SDK. Their availability through Foundation Models does not make their server processing PCC. — [Apple supported providers](https://developer.apple.com/foundation-models-framework/), [Firebase repository](https://github.com/firebase/firebase-ios-sdk)

### Inferences
- MLX/llama.cpp could serve a later offline/specialized feature, but would add weight downloads, model-license review (runtime MIT does not license all weights), memory/thermal/battery testing, cancellation/streaming integration and quality evaluation. No evidence gathered shows they outperform PCC for Cue's multilingual scripts.
- A separate external cloud provider might improve certain judged outputs or add web tools, but needs new privacy disclosure, authentication, abuse/spend controls and a benchmark. Do not claim a custom backend is mandatory: the verified Anthropic package has App Attest; it still changes data recipient and developer billing.
- For now, use these as comparison baselines on synthetic content only after a concrete evaluation need. Do not automatically change a user's provider during fallback.

### Gaps
- No verified engine can execute arbitrary third-party models inside Apple's PCC. No source establishes that installing an open-source package enhances Apple's server weights.
- No latency, memory, battery, token-price or script-quality benchmark was run. No current third-party model ranking is asserted; repository stars and vendor claims cannot establish Cue-specific superiority.
