import { initializeApp } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-app.js';
import { initializeAppCheck, ReCaptchaEnterpriseProvider, getToken } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-app-check.js';
import { getAI, getGenerativeModel, GoogleAIBackend } from 'https://www.gstatic.com/firebasejs/13.1.0/firebase-ai.js';

const ui = id => document.getElementById(id);
const [config, cases] = await Promise.all(['/config.json', '/cases.json'].map(async url => {
    const result = await fetch(url);
    if (!result.ok) throw new Error('Could not load local benchmark configuration');
    return result.json();
}));
if (config.firebase.projectId !== 'cue-script-ai-lab') throw new Error('Wrong Firebase project');
// Official App Check debug provider: explicit token stays in ignored local configuration, never exported.
self.FIREBASE_APPCHECK_DEBUG_TOKEN = config.debugToken;
const app = initializeApp(config.firebase);
const appCheck = initializeAppCheck(app, {
    provider: new ReCaptchaEnterpriseProvider('debug-only-no-production-site-key'), isTokenAutoRefreshEnabled: false,
});
const ai = getAI(app, {backend: new GoogleAIBackend()});
const samples = [];
let calls = 0;
ui('modelChoice').value = config.model;
if (!ui('modelChoice').value) throw new Error('Model outside this probe allowlist');
ui('model').textContent = config.model;
ui('modelChoice').addEventListener('change', () => {ui('model').textContent = ui('modelChoice').value;});
for (const item of cases) {
    const option = document.createElement('option');
    option.value = item.id;
    option.textContent = `${item.caseID} · voz ${item.voice} · ${item.sourceCondition}`;
    ui('case').append(option);
}
const selected = () => cases.find(item => item.id === ui('case').value);
const update = () => {const item = selected(); ui('input').textContent = `${item.instructions}\n\n${item.prompt}`;};
ui('case').addEventListener('change', update);
update();
ui('status').textContent = 'Pronto. O teste só começa ao clicar em Gerar.';
ui('run').disabled = false;
ui('run').addEventListener('click', async () => {
    if (calls >= 20) return;
    ui('run').disabled = true;
    ui('case').disabled = true;
    ui('modelChoice').disabled = true;
    const item = selected();
    const sample = {
        id: crypto.randomUUID(), kind: 'script', run: 'firebase-initial-2026-10-29', caseID: item.caseID,
        language: item.language, condition: `firebase-${item.voice}-${item.sourceCondition}`, index: calls,
        provider: 'firebase-ai-logic', backend: 'gemini-developer-api', project: config.firebase.projectId,
        model: ui('modelChoice').value, voice: item.voice, inputSHA256: item.inputSHA256, sourceRun: item.sourceRun,
        sourceCondition: item.sourceCondition, instructions: item.instructions, prompt: item.prompt,
        responseCap: item.responseCap, requiredLiterals: item.requiredLiterals, attempts: 0,
        qualityStatus: 'not_validated', startedAt: new Date().toISOString(),
    };
    const started = performance.now();
    ui('status').textContent = 'Verificando App Check…';
    try {
        // Preflight avoids spending a generation request when attestation is not configured.
        await getToken(appCheck, false);
        sample.appCheckSeconds = (performance.now() - started) / 1000;
        ui('status').textContent = 'App Check validado. Gerando texto no Firebase…';
        const params = {model: sample.model, generationConfig: {maxOutputTokens: item.responseCap}};
        if (item.instructions) params.systemInstruction = item.instructions;
        sample.requestTimeoutMs = 60000;
        const model = getGenerativeModel(ai, params, {timeout: sample.requestTimeoutMs});
        calls += 1;
        sample.attempts = 1;
        const {response} = await model.generateContent(item.prompt);
        sample.text = response.text();
        sample.usageMetadata = response.usageMetadata;
        sample.finishReason = response.candidates?.[0]?.finishReason;
        sample.safetyRatings = response.candidates?.[0]?.safetyRatings;
        if (!sample.text?.trim()) sample.failure = 'No generated text';
    } catch (error) {
        sample.failure = String(error.message || error).replaceAll(config.debugToken, '[redacted]');
    }
    sample.seconds = (performance.now() - started) / 1000;
    samples.push(sample);
    const card = document.createElement('article');
    const title = document.createElement('h2'); title.textContent = `${item.caseID} · ${sample.seconds.toFixed(2)}s`;
    const result = document.createElement('pre'); result.textContent = sample.failure || sample.text;
    const control = document.createElement('pre'); control.textContent = `PCC control:\n${item.referenceText || item.referenceFailure || 'Not generated'}`;
    card.append(title, result, control); ui('results').prepend(card);
    try {
        const saved = await fetch('/results', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(samples)});
        if (!saved.ok) throw new Error('Local save failed');
        ui('status').textContent = `${calls}/20 chamadas. Resultado salvo. Qualidade ainda exige avaliação humana.`;
    } catch (_) {ui('status').textContent = 'Falha ao salvar localmente. O resultado permanece visível nesta página.';}
    ui('case').disabled = false;
    ui('modelChoice').disabled = false;
    // Failure stops here; no silent retries, provider changes, or guardrail changes.
    ui('run').disabled = calls >= 20;
});
