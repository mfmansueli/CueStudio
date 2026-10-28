"""Regression checks for route-separated quality measurements; no device or private samples needed."""
import math
import unittest

import report


class RouteReportTests(unittest.TestCase):
    def sample(self, model=None, condition="full"):
        sample = {"kind": "script", "language": "en-US", "condition": condition, "index": 0,
                  "idea": "Morning routines", "text": "I start slowly. A glass of water helps me wake up.",
                  "seconds": 2, "minimumWords": 20}
        if model:
            sample["model"] = model
        return sample

    def test_models_and_legacy_are_never_averaged_together(self):
        rows, _ = report.summarize([self.sample("onDevice"), self.sample("privateCloud"), self.sample()])
        self.assertEqual({row["group"] for row in rows}, {
            "en-US·full·onDevice", "en-US·full·privateCloud", "en-US·full·legacy",
            "all·all·onDevice", "all·all·privateCloud", "all·all·legacy"})

    def test_unavailable_cloud_token_counts_are_not_reported_as_zero(self):
        rows, _ = report.summarize([self.sample("privateCloud")])
        self.assertTrue(all(math.isnan(row["tok-in"]) for row in rows))

    def test_language_sweep_also_keeps_each_model_separate(self):
        rows = report.sweep([self.sample("onDevice", "sweep"), self.sample("privateCloud", "sweep")])
        self.assertEqual({row["model"] for row in rows}, {"onDevice", "privateCloud"})


if __name__ == "__main__":
    unittest.main()
