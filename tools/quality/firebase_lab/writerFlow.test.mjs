import test from 'node:test';
import assert from 'node:assert/strict';
import {draftRequest, reviewRequest, parseReview} from './writerFlow.mjs';

const item = {language: 'pt-BR', instructions: 'old instructions', prompt: 'Current request:\nPreserve Aurora27 às 14:35.',
    responseCap: 4096, referenceText: 'REFERENCE ANSWER', reviewChecks: ['JUDGE ONLY']};

test('new flow retains the exact supplied input without leaking a reference or review rubric', () => {
    const before = JSON.stringify(item);
    for (const mode of ['recorded-control', 'editorial-v1', 'editorial-v1-reviewed']) {
        const request = draftRequest(item, mode);
        assert.equal(request.prompt, item.prompt);
        assert.equal(request.responseCap, 4096);
        assert.equal(JSON.stringify(item), before);
        assert.ok(!JSON.stringify(request).includes(item.referenceText));
        assert.ok(!JSON.stringify(request).includes(item.reviewChecks[0]));
    }
});

test('editor receives original context plus actual draft, not a benchmark answer', () => {
    const request = reviewRequest(item, 'A generous draft with useful detail.');
    assert.deepEqual(JSON.parse(request.prompt), {originalContextAndRequest: item.prompt, draft: 'A generous draft with useful detail.'});
    assert.ok(!request.prompt.includes(item.referenceText));
    assert.throws(() => reviewRequest(item, ''));
});

test('failed or malformed review cannot silently become a finished script', () => {
    for (const value of ['', 'not JSON', '{}', '{"script":"","changes":[]}', '{"script":"ok","changes":[4]}',
        '{"script":"ok","changes":[],"approved":true}']) assert.throws(() => parseReview(value));
    assert.deepEqual(parseReview('{"script":"A complete script.","changes":["Clarified a transition"]}'),
        {script: 'A complete script.', changes: ['Clarified a transition']});
});

test('unsupported flows and languages do not silently enter a different experiment', () => {
    assert.throws(() => draftRequest(item, 'typo'));
    assert.throws(() => draftRequest({...item, language: 'es-ES'}, 'editorial-v1'));
});


test('creative mode permits imagined first-person scenes without relaxing technical accuracy or changing the request', () => {
    const item = {language:'pt-BR', prompt:'Current request: meu pedido literal', responseCap:4096};
    const draft = draftRequest(item, 'content-first-v4-reviewed');
    const review = reviewRequest(item, 'Uma história imaginada.', 'content-first-v4-reviewed');
    for (const request of [draft, review]) {
        assert.ok(request.instructions.includes('Imagine por ele'));
        assert.ok(request.instructions.includes('fabricar dados técnicos'));
        assert.ok(!request.instructions.includes('Não crie um passado para produzir conexão emocional'));
        assert.ok(!request.instructions.includes('Não faça a pessoa afirmar que viveu algo não fornecido'));
    }
    assert.equal(draft.prompt, item.prompt);
});
