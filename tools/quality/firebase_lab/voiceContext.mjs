// Request-local projection only. The creator's stored profile and exact current request are never mutated.
const marker = '\n\nCurrent request:\n';
const deliveryPrefixes = ['They sound ', 'Delivery:', 'Usual opening preference', 'Usual ending preference',
    'They film mostly:', 'Optional familiar expressions:', 'They post on '];

export function separateVoiceContext(prompt) {
    const index = prompt.indexOf(marker);
    if (index < 0) return {contentPrompt: prompt, voicePrompt: prompt, deferredVoiceNotes: []};
    const current = prompt.slice(index + marker.length);
    const blocks = prompt.slice(0, index).split('\n\n');
    const isDelivery = block => deliveryPrefixes.some(prefix => block.startsWith(prefix));
    const deferredVoiceNotes = blocks.filter(isDelivery);
    const contentPrompt = blocks.filter(block => !isDelivery(block)).join('\n\n') + marker + current;
    const voicePrompt = blocks.map(block => block.startsWith('Delivery:')
        ? block.replace('(under twelve words)', '(prefer short sentences with varied lengths; preserve the developed reasoning)') : block)
        .join('\n\n') + marker + current;
    return {contentPrompt, voicePrompt, deferredVoiceNotes};
}
