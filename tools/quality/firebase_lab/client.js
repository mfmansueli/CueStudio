import {FirebaseProbe} from './FirebaseProbe.mjs';
import {draftRequest, reviewRequest, parseReview} from './writerFlow.mjs';

const ui = id => document.getElementById(id);
const [config, cases] = await Promise.all(['/config.json', '/cases.json'].map(async url => {
    const result = await fetch(url);
    if (!result.ok) throw new Error('Could not load local benchmark configuration');
    return result.json();
}));
const probe = new FirebaseProbe(config);
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
const update = () => {
    const request = draftRequest(selected(), ui('flow').value);
    ui('input').textContent = `${request.instructions}\n\n${request.prompt}`;
};
ui('case').addEventListener('change', update);
ui('flow').addEventListener('change', update);
update();
ui('status').textContent = `Pronto: ${config.backend} / ${config.location}. Lote persistente de até 8 chamadas SDK.`;
ui('run').disabled = false;
const fingerprint = async request => {
    const bytes = new TextEncoder().encode(JSON.stringify(request));
    return [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(x => x.toString(16).padStart(2, '0')).join('');
};
ui('run').addEventListener('click', async () => {
    const flow = ui('flow').value;
    const requiredCalls = flow.endsWith('-reviewed') ? 2 : 1;
    if (calls + requiredCalls > 20) {ui('status').textContent = 'Limite local de chamadas atingido.'; return;}
    for (const id of ['run', 'case', 'modelChoice', 'flow']) ui(id).disabled = true;
    const item = selected();
    const request = draftRequest(item, flow);
    const sample = {
        id: crypto.randomUUID(), kind: 'script', run: 'firebase-agent-platform-v2-2026-10-29', caseID: item.caseID,
        language: item.language, condition: `firebase-${item.voice}-${flow}-${item.sourceCondition}`, index: calls,
        provider: 'firebase-ai-logic', backend: config.backend, location: config.location, project: config.firebase.projectId,
        model: ui('modelChoice').value, voice: item.voice, sourceInputSHA256: item.inputSHA256,
        sourceRun: item.sourceRun, sourceCondition: item.sourceCondition, instructions: request.instructions,
        prompt: request.prompt, flow, responseCap: request.responseCap, requiredLiterals: item.requiredLiterals,
        attempts: 0, phases: [], qualityStatus: 'not_validated', startedAt: new Date().toISOString(),
    };
    const started = performance.now();
    const save = async () => {
        const response = await fetch('/results', {method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify([sample])});
        if (!response.ok) throw new Error('Local checkpoint failed');
    };
    const generate = async phaseRequest => {
        const reservation = await fetch('/reserve', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({model:sample.model})});
        if (!reservation.ok) throw new Error('Persistent batch limit or invalid model; no model call sent');
        const phase = {...phaseRequest, requestSHA256: await fingerprint(phaseRequest), requestedModel: sample.model};
        sample.phases.push(phase);
        calls += 1;
        sample.attempts += 1;
        const phaseStarted = performance.now();
        try {Object.assign(phase, await probe.generate(sample.model, phaseRequest));}
        catch (error) {phase.failure = String(error.message || error); throw error;}
        finally {phase.seconds = (performance.now() - phaseStarted) / 1000; await save();}
        if (!phase.text?.trim() || phase.finishReason !== 'STOP') throw new Error(`Incomplete ${phase.stage}: ${phase.finishReason || 'no text'}`);
        return phase.text;
    };
    ui('status').textContent = 'Verificando App Check…';
    try {
        await probe.preflight();
        sample.appCheckSeconds = (performance.now() - started) / 1000;
        ui('status').textContent = 'Escrevendo um rascunho desenvolvido…';
        sample.draftText = await generate(request);
        await save();
        if (flow.endsWith('-reviewed')) {
            ui('status').textContent = 'Lapidando as ideias, a coerência e a fidelidade ao pedido…';
            const review = parseReview(await generate(reviewRequest(item, sample.draftText, flow)));
            sample.editorialChanges = review.changes;
            sample.text = review.script;
        } else {sample.text = sample.draftText;}
        sample.finishReason = sample.phases.at(-1).finishReason;
        sample.totalUsageMetadata = Object.fromEntries(['promptTokenCount', 'candidatesTokenCount', 'totalTokenCount', 'thoughtsTokenCount']
            .map(key => [key, sample.phases.reduce((sum, phase) => sum + (phase.usageMetadata?.[key] || 0), 0)]));
    } catch (error) {
        sample.failure = String(error.message || error).replaceAll(config.debugToken, '[redacted]');
        for (const phase of sample.phases) if (phase.failure) phase.failure = phase.failure.replaceAll(config.debugToken, '[redacted]');
    }
    sample.seconds = (performance.now() - started) / 1000;
    samples.push(sample);
    const card = document.createElement('article');
    const title = document.createElement('h2'); title.textContent = `${item.caseID} · ${flow} · ${sample.seconds.toFixed(2)}s`;
    const result = document.createElement('pre'); result.textContent = sample.failure || sample.text;
    card.append(title, result);
    if (flow.endsWith('-reviewed') && sample.draftText) {
        const draft = document.createElement('details'); const label = document.createElement('summary');
        label.textContent = 'Rascunho antes da lapidação e ajustes declarados';
        const body = document.createElement('pre'); body.textContent = `${sample.draftText}\n\n${JSON.stringify(sample.editorialChanges || [])}`;
        draft.append(label, body); card.append(draft);
    }
    const control = document.createElement('pre'); control.textContent = `PCC control:\n${item.referenceText || item.referenceFailure || 'Not generated'}`;
    card.append(control); ui('results').prepend(card);
    try {
        const saved = await fetch('/results', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(samples)});
        if (!saved.ok) throw new Error('Local save failed');
        ui('status').textContent = `${calls} chamadas nesta página (lote persistente máximo: 8). Resultado salvo. Qualidade ainda exige avaliação humana.`;
    } catch (_) {ui('status').textContent = 'Falha ao salvar localmente. O resultado permanece visível nesta página.';}
    for (const id of ['case', 'modelChoice', 'flow']) ui(id).disabled = false;
    ui('run').disabled = calls >= 20;
});
