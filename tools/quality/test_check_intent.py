import unittest

from check_intent import contains_literal, evaluate


class IntentReviewTests(unittest.TestCase):
    def test_a_failed_or_absent_generation_never_passes_even_with_no_required_literals(self):
        for sample in [{"text": "", "requiredLiterals": []}, {"text": "draft", "failure": "timeout", "requiredLiterals": []}]:
            self.assertEqual(evaluate(sample)["literal_status"], "not_generated")

    def test_a_literal_pass_leaves_creative_quality_unvalidated(self):
        result = evaluate({"text": "Aurora27 starts at 14:35.", "requiredLiterals": ["Aurora27", "14:35"]})
        self.assertEqual(result["literal_status"], "pass")
        self.assertEqual(result["quality_status"], "not_validated")

    def test_numbers_inside_different_numbers_and_changed_names_do_not_pass(self):
        result = evaluate({"text": "Aurora270 starts at 214:35.", "requiredLiterals": ["Aurora27", "14:35"]})
        self.assertEqual(result["missing_literals"], ["Aurora27", "14:35"])
        self.assertEqual(result["literal_status"], "fail")

    def test_old_samples_without_expectations_are_not_silently_approved(self):
        self.assertEqual(evaluate({"text": "A complete script."})["literal_status"], "not_configured")

    def test_no_literal_requirement_is_not_a_pass(self):
        self.assertEqual(evaluate({"text": "A complete script.", "requiredLiterals": []})["literal_status"], "not_applicable")

    def test_canonical_accents_and_japanese_particles_do_not_cause_false_failures(self):
        self.assertTrue(contains_literal("Cafe\u0301", "Café"))
        self.assertTrue(contains_literal("Aurora27は明日です。", "Aurora27"))


if __name__ == "__main__":
    unittest.main()
