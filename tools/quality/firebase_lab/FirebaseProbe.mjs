// Official SDK boundary. The UI and pure editorial flow do not import Firebase.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js';
import { initializeAppCheck, ReCaptchaEnterpriseProvider, getToken } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-check.js';
import { getAI, getGenerativeModel, AgentPlatformBackend } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-ai.js';

export class FirebaseProbe {
    constructor(config) {
        if (config.firebase.projectId !== 'cue-script-ai-lab') throw new Error('Wrong Firebase project');
        if (config.backend !== 'agent-platform' || config.location !== 'global') throw new Error('Credits backend required');
        self.FIREBASE_APPCHECK_DEBUG_TOKEN = config.debugToken;
        const app = initializeApp(config.firebase);
        this.appCheck = initializeAppCheck(app, {
            provider: new ReCaptchaEnterpriseProvider('debug-only-no-production-site-key'), isTokenAutoRefreshEnabled: false,
        });
        this.ai = getAI(app, {backend: new AgentPlatformBackend(config.location)});
    }

    async preflight() {await getToken(this.appCheck, false);}

    async generate(modelName, request) {
        const started = performance.now();
        const generationConfig = {maxOutputTokens: request.responseCap};
        if (request.json) generationConfig.responseMimeType = 'application/json';
        const params = {model: modelName, generationConfig};
        if (request.instructions) params.systemInstruction = request.instructions;
        const requestTimeoutMs = 60000;
        const model = getGenerativeModel(this.ai, params, {timeout: requestTimeoutMs});
        const {response} = await model.generateContent(request.prompt);
        return {
            ...request, text: response.text(), usageMetadata: response.usageMetadata,
            finishReason: response.candidates?.[0]?.finishReason, safetyRatings: response.candidates?.[0]?.safetyRatings,
            seconds: (performance.now() - started) / 1000, requestTimeoutMs,
        };
    }
}
