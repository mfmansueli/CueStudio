"""Frozen synthetic inputs for Firebase comparison; never send reference answers to the model."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FIXTURES = ROOT / 'Cue StudioTests/Fixtures/ScriptQuality'
SELECTION = [
    ('editorial-v1-opinion-r1', 'lean-raw', 'full'),
    ('editorial-v1-pt-BR-equipment-r1', 'lean-raw', 'full'),
    ('editorial-v1-pt-BR-tutorial-r1', 'lean-raw', 'full'),
    ('editorial-v6-none-bare-r1', 'bare-raw', 'none'),
    ('editorial-v6-none-equipment-r1', 'bare-raw', 'none'),
    ('editorial-v6-none-bare-r1', 'editorial-raw', 'none'),
]


def model_input(case):
    """Only these fields can become model input. Reference/review fields are deliberately absent."""
    return {'instructions': case['instructions'], 'prompt': case['prompt'], 'maxOutputTokens': case['responseCap']}


def load_cases():
    result = []
    for run, condition, voice in SELECTION:
        path = FIXTURES / f'quality-run-{run}.json'
        samples = json.loads(path.read_text())
        sample, = [x for x in samples if x['condition'] == condition]
        if sample.get('editorialExampleInstructions') or sample.get('attempts') not in (None, 1):
            raise ValueError('Only recorded single-call raw comparisons are supported')
        case = {key: sample[key] for key in ('caseID', 'language', 'instructions', 'prompt', 'responseCap')}
        case.update(id=f'{run}/{condition}', voice=voice, source=str(path.relative_to(ROOT)), sourceRun=run,
                    sourceCondition=condition, referenceText=sample.get('text'), referenceFailure=sample.get('failure'),
                    referenceSeconds=sample['seconds'], referenceAttempts=sample.get('attempts'), reviewChecks=sample.get('reviewChecks', []),
                    requiredLiterals=sample.get('requiredLiterals', []), expectedDirection=sample.get('expectedDirection'))
        case['inputSHA256'] = hashlib.sha256(json.dumps(model_input(case), sort_keys=True, ensure_ascii=False).encode()).hexdigest()
        result.append(case)
    return result
