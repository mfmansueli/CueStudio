import test from 'node:test';
import assert from 'node:assert/strict';
import {separateVoiceContext} from './voiceContext.mjs';
import {draftRequest, reviewRequest} from './writerFlow.mjs';

const prompt = 'Platform: Instagram Reels.\n\nCreator profile (context, not a new request):\n\nWho they are: a creator.\n\nTheir audience: young adults.\n\nDelivery: sentences: short and punchy (under twelve words).\n\nUsual opening preference: a common mistake.\n\nNever swear.\n\nCurrent request:\nDiga exatamente: "Aurora27 às 14:35 (under twelve words)".\n\nCurrent request:\nThis phrase is also user content.';

test('content pass keeps identity, audience, hard constraints and exact current request', () => {
    const result = separateVoiceContext(prompt);
    const originalCurrent = prompt.slice(prompt.indexOf('\n\nCurrent request:\n'));
    assert.ok(result.contentPrompt.endsWith(originalCurrent));
    assert.ok(result.voicePrompt.endsWith(originalCurrent));
    assert.ok(result.contentPrompt.includes('Their audience: young adults.'));
    assert.ok(result.contentPrompt.includes('Who they are: a creator.'));
    assert.ok(result.contentPrompt.includes('Never swear.'));
    assert.ok(!result.contentPrompt.includes('Delivery:'));
    assert.equal(result.deferredVoiceNotes.length, 2);
    assert.ok(result.voicePrompt.includes('Usual opening preference: a common mistake.'));
    assert.ok(result.voicePrompt.includes('preserve the developed reasoning'));
});

test('bare prompts are unchanged; malformed markers do not drop content', () => {
    for (const value of ['A bare request', 'Current request:\nOnly user data']) {
        const result = separateVoiceContext(value);
        assert.equal(result.contentPrompt, value);
        assert.equal(result.voicePrompt, value);
    }
});

test('v2 stages use scoped context without changing the source profile or reference', () => {
    const item = {language: 'pt-BR', prompt, instructions: 'old', responseCap: 4096, referenceText: 'DO NOT SEND'};
    const before = JSON.stringify(item);
    const draft = draftRequest(item, 'content-first-v2-reviewed');
    const review = reviewRequest(item, 'A developed argument.', 'content-first-v2-reviewed');
    assert.ok(!draft.prompt.includes('Delivery:'));
    assert.ok(JSON.parse(review.prompt).originalContextAndRequest.includes('Delivery:'));
    assert.equal(JSON.stringify(item), before);
    assert.ok(!draft.prompt.includes(item.referenceText));
    assert.ok(!review.prompt.includes(item.referenceText));
});
