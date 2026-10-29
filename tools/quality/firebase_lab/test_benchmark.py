import unittest
from benchmark import load_cases, model_input


class BenchmarkInputTests(unittest.TestCase):
    def test_reference_answers_and_review_criteria_never_enter_model_input(self):
        for case in load_cases():
            payload = model_input(case)
            self.assertEqual(set(payload), {'instructions', 'prompt', 'maxOutputTokens'})
            if case['referenceText']:
                self.assertNotIn(case['referenceText'], str(payload))
            for check in case['reviewChecks']:
                self.assertNotIn(check, str(payload))

    def test_framework_refusal_is_retained_not_converted_to_approved_text(self):
        case, = [x for x in load_cases() if x['caseID'] == 'pt-BR-tutorial']
        self.assertTrue(case['referenceFailure'])
        self.assertFalse(case['referenceText'])

    def test_controls_have_distinct_keys_and_preserve_exact_inputs(self):
        cases = load_cases()
        self.assertEqual(len({x['id'] for x in cases}), len(cases))
        bare, = [x for x in cases if x['caseID'] == 'pt-BR-editorial-draft' and x['sourceCondition'] == 'bare-raw']
        self.assertEqual(bare['instructions'], '')
        self.assertTrue(bare['prompt'].startswith('Por que um roteiro'))
        self.assertNotIn('Platform:', bare['prompt'])
        self.assertEqual(len(bare['inputSHA256']), 64)
        self.assertEqual({x['voice'] for x in cases}, {'full', 'none'})


if __name__ == '__main__':
    unittest.main()
