#!/usr/bin/env python3
"""Checks for the blind comparison's metrics, pairs and scoring; no device, xcresult or private samples needed."""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import compare  # noqa: E402


def idea(id, kind="technical", language="pt-BR", **engines):
    return {"run": "t", "id": id, "kind": kind, "language": language, "platform": "TikTok", "idea": "Luz da janela em 3 passos",
            "brief": None, "durationPolicy": "informative", "lengthAsked": "free",
            "creator": {"summary": "Fotógrafa de retratos", "phrases": ["Bora lá"], "openings": [], "endings": []},
            "context": "Setting: a short video.", "engines": engines}


def engine(text, title="Luz suave"):
    return {"title": title, "text": text, "failure": None}


class MetricTests(unittest.TestCase):
    def test_words_and_seconds(self):
        self.assertEqual(compare.words("um  dois\ntrês"), 3)
        self.assertEqual(compare.estimated_seconds(180), 72.0)
        self.assertEqual(compare.estimated_seconds(1), 0.4)

    def test_length_fit(self):
        self.assertEqual(compare.length_fit(75, "required 60–90 s"), "in")
        self.assertEqual(compare.length_fit(40, "required 60–90 s"), "short")
        self.assertEqual(compare.length_fit(95.5, "required 60-90 s"), "long")
        self.assertEqual(compare.length_fit(72, "reference 90 s"), 0.8)
        self.assertIsNone(compare.length_fit(72, "free"))

    def test_ends_with_question_ignores_quotes_and_emoji(self):
        self.assertTrue(compare.ends_with_question("E você, já tentou?\n"))
        self.assertTrue(compare.ends_with_question('He asked, "would you?" 🤔 '))
        self.assertTrue(compare.ends_with_question("¿Lo probaste? ✨️"))
        self.assertFalse(compare.ends_with_question("Is it hard? No. It is easy."))

    def test_cta_in_ending(self):
        self.assertEqual(compare.cta_in_ending("Light first. Then the pose. Save this and follow for more.", "en-US"),
                         ["save this", "follow"])
        self.assertEqual(compare.cta_in_ending("Luz primeiro. Me conta nos comentários. E segue pra parte dois!", "pt-BR"),
                         ["me conta", "segue"])
        self.assertEqual(compare.cta_in_ending("Primero la luz. ¿Te sirvió? Guarda este video y sígueme.", "es-MX"),
                         ["guarda", "sígueme"])

    def test_a_question_alone_is_not_a_call_to_action(self):
        self.assertEqual(compare.cta_in_ending("Light matters. Do you know why the window works?", "en-US"), [])
        self.assertEqual(compare.cta_in_ending("A luz importa. Você sabe por que a janela funciona?", "pt-BR"), [])

    def test_cta_only_looks_at_the_last_two_sentences_and_whole_words(self):
        self.assertEqual(compare.cta_in_ending("Follow me. One. Two. Three.", "en"), [])
        self.assertEqual(compare.cta_in_ending("A likely story. The followers grew.", "en"), [])
        self.assertIsNone(compare.cta_in_ending("Abonnez-vous.", "fr-FR"))

    def test_catchphrases_ignore_case_and_punctuation(self):
        text = "Bora lá! Primeiro a luz. bora, lá: agora o fundo. Borala não conta."
        self.assertEqual(compare.catchphrases(text, ["Bora lá", "Fala, galera!"]), {"Bora lá": 2, "Fala, galera!": 0})
        self.assertEqual(compare.catchphrases("Okay real talk, this works.", ["Okay, real talk."]), {"Okay, real talk.": 1})

    def test_em_dashes_and_markdown(self):
        self.assertEqual(compare.em_dashes("Luz — sombra – fundo - nada"), 2)
        self.assertTrue(compare.has_markdown("# Title\nText"))
        self.assertTrue(compare.has_markdown("Intro\n- one\n- two"))
        self.assertTrue(compare.has_markdown("Intro\n1. one"))
        self.assertTrue(compare.has_markdown("This is **bold**."))
        self.assertFalse(compare.has_markdown("Plain text with a #hashtag and a - dash.\n2026 was a year."))

    def test_new_numbers(self):
        supplied = ["Luz da janela em 3 passos", "Fotógrafa há 10 anos"]
        text = "São 3 passos. Em 2 minutos você ganha 40% mais luz, 40 por cento! Custa R$ 50 e não 10. De novo: 2 minutos."
        self.assertEqual(compare.new_numbers(text, supplied), ["2", "40%", "40 por cento", "R$ 50"])
        self.assertEqual(compare.new_numbers("Use 3 lights, 50 percent softer, $20.", ["3 lights"]), ["50 percent", "$20"])
        self.assertEqual(compare.new_numbers("Cuesta 1,5 euros, el 30 por ciento.", ["1.5 y 30"]), [])

    def test_title_accents_come_back_as_the_app_does(self):
        script = "Trocar o celular por uma câmera pode atrasar seus vídeos. Isso é simples e rápido."
        self.assertEqual(compare.accents_restored("Celular ou camera para gravar videos", script), "Celular ou câmera para gravar vídeos")
        self.assertEqual(compare.accents_restored("CAMERA e rapido", script), "CÂMERA e rápido")
        self.assertEqual(compare.accents_restored("Simples e rapido", "Isso é simples e rápido, e bom."), "Simples e rápido")
        self.assertEqual(compare.accents_restored("Why rest days matter", "Rest days make you stronger."), "Why rest days matter")

    def test_title(self):
        self.assertEqual(compare.title_issue(""), "empty")
        self.assertEqual(compare.title_issue("One two three four five six seven eight nine"), "long")
        self.assertEqual(compare.title_issue("Window light."), "period")
        self.assertIsNone(compare.title_issue("Window light"))

    def test_metrics_of_an_idea(self):
        sample = idea("a", apple=engine("Bora lá. São 5 passos. Salva esse vídeo!"))
        m = compare.metrics(sample["engines"]["apple"], sample)
        self.assertEqual((m["words"], m["catchphrases"], m["ctaInEnding"], m["newNumbers"], m["titleWords"]),
                         (8, {"Bora lá": 1}, ["salva"], ["5"], 2))
        self.assertIsNone(compare.metrics({"title": None, "text": None, "failure": "refused"}, sample))


class CollectTests(unittest.TestCase):
    def test_read_export_uses_the_manifest_names(self):
        with tempfile.TemporaryDirectory() as folder:
            files = {"a.json": idea("x"), "b.json": idea("y"), "c.json": {"script": "other test"}}
            for name, data in files.items():
                with open(os.path.join(folder, name), "w", encoding="utf-8") as handle:
                    json.dump(data, handle)
            manifest = [{"testIdentifier": "T", "attachments": [
                {"exportedFileName": "a.json", "suggestedHumanReadableName": "ultra-quality-t-x_0_ABC.json"},
                {"exportedFileName": "b.json", "suggestedHumanReadableName": "ultra-quality-other-y_0_ABC.json"},
                {"exportedFileName": "c.json", "suggestedHumanReadableName": "ultra-quality-t-c_0_ABC.json"}]}]
            with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as handle:
                json.dump(manifest, handle)
            self.assertEqual([i["id"] for i in compare.read_export(folder, "t")], ["x"])

    def test_a_later_bundle_replaces_the_same_id(self):
        bundles = {"one": [idea("b", apple=engine("Primeira versão.")), idea("a")], "two": [idea("b", apple=engine("Segunda versão."))]}
        with tempfile.TemporaryDirectory() as folder:
            with contextlib.redirect_stdout(io.StringIO()):
                ideas = compare.collect("t", ["one", "two"], folder=folder, read=lambda result, run: iter(bundles[result]))
            self.assertEqual([i["id"] for i in ideas], ["a", "b"])
            self.assertEqual(ideas[1]["engines"]["apple"]["text"], "Segunda versão.")
            self.assertEqual(ideas[1]["engines"]["apple"]["metrics"]["words"], 2)
            self.assertTrue(os.path.exists(os.path.join(folder, "quality-t.json")))


class PairTests(unittest.TestCase):
    def ideas(self):
        return [
            idea("t1", apple=engine("Luz um."), polished=engine("Luz dois."), checked=engine("Luz três.")),
            idea("t2", apple=engine("Sombra um."), polished=engine("Sombra dois."), checked={"title": None, "text": None, "failure": "x"}),
            idea("p1", kind="profile", apple=engine("Perfil um."), polished=engine("Perfil dois."), checked=engine("Perfil três.")),
            idea("p2", kind="profile", language="en-US", polished=engine("Profile two."), checked=engine("Profile three.")),
            idea("t3", language="es-ES", apple=engine("Uno."), polished=engine("Dos."), checked=engine("Tres.")),
        ]

    def test_which_pairs_are_made(self):
        _, key = compare.build_pairs(self.ideas())
        made = sorted((k["id"], k["comparison"]) for k in key.values())
        self.assertEqual(made, [("p1", "apple-vs-checked"), ("t1", "apple-vs-checked"), ("t1", "polished-vs-checked"),
                                ("t3", "apple-vs-checked"), ("t3", "polished-vs-checked")])

    def test_the_seed_decides_order_and_sides(self):
        first = compare.build_pairs(self.ideas(), seed=7)
        self.assertEqual(first, compare.build_pairs(self.ideas(), seed=7))
        self.assertEqual([p["pair"] for p in first[0]], ["P01", "P02", "P03", "P04", "P05"])
        orders = {tuple((k["id"], k["comparison"], k["A"]) for k in compare.build_pairs(self.ideas(), seed=s)[1].values())
                  for s in range(20)}
        self.assertGreater(len(orders), 1)

    def test_the_key_matches_the_texts(self):
        ideas = {i["id"]: i for i in self.ideas()}
        pairs, key = compare.build_pairs(self.ideas())
        for pair in pairs:
            entry = key[pair["pair"]]
            for side in ("A", "B"):
                self.assertEqual(pair[side]["text"], ideas[pair["id"]]["engines"][entry[side]]["text"])

    def test_the_pair_files_name_no_engine(self):
        with tempfile.TemporaryDirectory() as folder:
            compare.save(os.path.join(folder, "quality-t.json"), [compare.enrich(i) for i in self.ideas()])
            with contextlib.redirect_stdout(io.StringIO()):
                compare.make_pairs("t", seed=3, folder=folder)
            for name in ("quality-t-pairs.json", "quality-t-pairs.md"):
                with open(os.path.join(folder, name), encoding="utf-8") as handle:
                    content = handle.read()
                for label in ("apple", "polished", "checked", "Apple Intelligence", "Ultra", "Gemini", "metrics", "comparison"):
                    self.assertNotIn(label.lower(), content.lower(), f"{label} in {name}")
            for pair in compare.load(os.path.join(folder, "quality-t-pairs.json")):
                self.assertEqual(set(pair["A"]), {"title", "text"})
            key = compare.load(os.path.join(folder, "quality-t-key.json"))
            self.assertEqual(len(key), 5)


class ScoreTests(unittest.TestCase):
    key = {
        "P01": {"comparison": "apple-vs-checked", "A": "checked", "B": "apple", "id": "t1", "kind": "technical", "language": "pt-BR"},
        "P02": {"comparison": "apple-vs-checked", "A": "apple", "B": "checked", "id": "p1", "kind": "profile", "language": "en-US"},
        "P03": {"comparison": "polished-vs-checked", "A": "polished", "B": "checked", "id": "t1", "kind": "technical",
                "language": "pt-BR"},
        "P04": {"comparison": "apple-vs-checked", "A": "apple", "B": "checked", "id": "t2", "kind": "technical", "language": "pt-BR"},
    }
    verdicts = {
        "P01": {"winner": "A", "scores": {"A": {"development": 5, "accuracy": 4}, "B": {"development": 3, "accuracy": 2}},
                "errors": {"A": [], "B": ["invents a 40% figure"]}},
        "P02": {"winner": "B", "scores": {"A": {"development": 2}, "B": {"development": 4}}},
        "P03": {"winner": "tie", "errors": {"A": ["ends with a period in the title"]}},
        "P09": {"winner": "A"},
    }

    def test_wins_scores_and_errors(self):
        summary = compare.summarize(self.verdicts, self.key)
        apple = summary["comparisons"]["apple-vs-checked"]
        self.assertEqual(apple["all"], {"pairs": 2, "tie": 0, "checked": 2})
        self.assertEqual(apple["kind"]["technical"], {"pairs": 1, "tie": 0, "checked": 1})
        self.assertEqual(apple["language"]["en-US"], {"pairs": 1, "tie": 0, "checked": 1})
        self.assertEqual(summary["comparisons"]["polished-vs-checked"]["all"], {"pairs": 1, "tie": 1})
        self.assertEqual(summary["scores"]["apple-vs-checked"]["checked"]["development"], {"mean": 4.5, "n": 2})
        self.assertEqual(summary["scores"]["apple-vs-checked"]["apple"]["development"], {"mean": 2.5, "n": 2})
        self.assertEqual(summary["scores"]["all"]["apple"]["accuracy"], {"mean": 2.0, "n": 1})
        self.assertEqual(summary["errors"]["apple"], [{"pair": "P01", "id": "t1", "error": "invents a 40% figure"}])
        self.assertEqual(summary["errors"]["polished"][0]["pair"], "P03")
        self.assertEqual((summary["judged"], summary["missing"], summary["unknown"]), (3, ["P04"], ["P09"]))
        self.assertIn("apple-vs-checked", compare.report(summary))

    def test_a_bad_winner_is_refused(self):
        with self.assertRaises(ValueError):
            compare.summarize({"P01": {"winner": "apple"}}, self.key)

    def test_score_writes_the_summary(self):
        with tempfile.TemporaryDirectory() as folder:
            compare.save(os.path.join(folder, "quality-t-key.json"), self.key)
            verdicts = os.path.join(folder, "judge-1.json")
            compare.save(verdicts, self.verdicts)
            with contextlib.redirect_stdout(io.StringIO()):
                compare.score("t", verdicts, folder=folder)
            saved = compare.load(os.path.join(folder, "quality-t-score-judge-1.json"))
            self.assertEqual((saved["run"], saved["verdicts"], saved["judged"]), ("t", "judge-1", 3))


if __name__ == "__main__":
    unittest.main()
