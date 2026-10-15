#!/usr/bin/env python3
"""Measures the scripts and ideas of one or more script-quality runs (`tools/quality/collect.py`) and prints them side by side:

  tools/quality/report.py baseline [after-1 …]          the numbers, by language and by how much of My Cue Voice is answered
  tools/quality/report.py baseline --texts              also writes build/reports/quality-<run>.md with every text, to be read

The metrics are written here, by hand, and never call the app's own checkers, so they can grade them. They are proxies: what they cannot say
(is it natural, does it sound like the creator) is for people reading the texts.

Script metrics
  words/min     spoken words over the minimum asked (completeness); cut = the last block stops mid-sentence
  rep           share of repeated word trigrams in the script (1 - unique/total)
  xblock        the most of one block's trigrams already said in an earlier block (cross-block repetition)
  dupsent       pairs of sentences that say the same thing (content-word Jaccard >= 0.6)
  promise       a number promised in the idea or the opening ("3 mistakes") and whether as many items are told
  idea          share of the idea's content words the script uses
  angle/open    for a Find inspiration brief: share of the angle's content words after the first sentence; the first sentence keeps the opening line
  sent          mean words per sentence; cliche = stock phrases ("in today's video", "neste vídeo")
  voice         catchphrase used / catchphrase as the first words / "I" and "we" counts / hype words
  interj        scripts whose first spoken words are a greeting or a filler ("Hey", "Olha só", "Hola", "Alors,"): `INTERJECTIONS`, a short
                list per language of what only opens a video and says nothing; a word that also starts real sentences ("So many…", "Vale la
                pena…", "Så här gör du") only counts with the comma that makes it a filler; a catchphrase that greets ("Okay, real talk.",
                "Fala, galera!") counts too, as the creator asked for it (phrase/1st tell the two apart)
  claims        phrases that claim a lived experience in the first person ("I discovered", "já usei", "me salvó"): with no voice and no story
                given, the model invents them. A proxy (`CLAIMS`, in en/pt/es/fr/de/it; "–" elsewhere): a creator's real story counts too
  s, first      seconds to the script, seconds to the first words; att = drafts written
  tokens        instructions + prompt + schema (the model's own tokenizer), and the answer

Words in languages written without spaces (Japanese, Chinese, Thai): the app counts dictionary words (`WordSegmenter`, NLTokenizer), which
this script does without; it counts the letters of those scripts and divides them by an average word length (`CHARS_PER_WORD`), measured
with NLTokenizer on short spoken scripts: Chinese 1.4 characters a word (1.32 Simplified, 1.43 Traditional), Japanese 1.75 (kana and kanji;
the tokenizer splits particles and verb endings off), Thai 4.5 code points (vowel and tone marks included). Other runs of letters in such a
script (an English brand name, a number) count one word each. The factors are averages, so words/min is good to about ±15% there: enough to
see a script that is half as long as asked, not to compare 0.95 with 1.0.

Idea metrics (each language and condition: two batches of six)
  dup2          pairs of ideas with two or more of title, angle, opening line alike (the same idea reworded)
  dupT          pairs with alike titles; restate = angles that only restate the title; generic = generic titles; q = opening lines that are questions

The 20-language sweep (condition "sweep": no voice, the interface in the language, two scripts and one batch of ideas a language) has its own
table, by language: written, failures, words/min, interj, claims, seconds, and lang = the lowest share, among the language's scripts, of letters
in the language's own writing system (Arabic, Devanagari, Hangul, Thai, kana and kanji, Han); "–" for languages written in Latin letters, where
the script says nothing. Japanese without any kana counts as Chinese (share 0); a Chinese script that uses more characters of the other
writing system (Simplified or Traditional, `HANS_ONLY` / `HANT_ONLY`) is marked "Hans?" or "Hant?". ideas, ilang and is: the batch of
ideas, its share in the writing system (titles, angles and opening lines together) and its seconds.
The sweep's samples stay out of the other tables.
"""

import itertools
import json
import os
import re
import statistics
import sys
import unicodedata

SWEEP = "sweep"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FOLDER = os.path.join(ROOT, "Cue StudioTests", "Fixtures", "ScriptQuality")

STOP = set("""
a an the and or but if of to in on at for with from by as is are was were be been being it its this that these those you your yours i me my
we our us they them their he she his her not no do does did so just very really can will would should could about into than then there here
what when where why how who which all any some more most also too up out over only one get got have has had don't it's i'm you're that's
o a os as um uma uns umas e ou mas se de do da dos das em no na nos nas por para com sem que é são foi ser está estão eu meu minha você seu sua
nós nosso nossa eles elas ele ela isso isto esse essa aquele não sim mais muito muita também já só tipo pra pro como quando porque qual quem
el la los las un una unos unas y o pero si de del en por para con sin que es son fue ser está están yo mi mis tú tu su sus nosotros nuestro
nuestra ellos ellas él ella eso esto ese esa no sí más muy también ya solo como cuando porque cual quien te le les lo se me nos
""".split())

ORDINALS = {
    "en": ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "number one", "number two", "number three", "number four",
           "number five", "one:", "two:", "three:", "next", "last", "finally"],
    "pt": ["primeiro", "primeira", "segundo", "segunda", "terceiro", "terceira", "quarto", "quarta", "quinto", "quinta", "número um",
           "número dois", "número três", "por último", "último", "última", "por fim", "e por fim"],
    "es": ["primero", "primera", "segundo", "segunda", "tercero", "tercera", "cuarto", "cuarta", "quinto", "quinta", "número uno",
           "número dos", "número tres", "por último", "último", "última", "finalmente"],
}
NUMBERS = {
    "en": {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7},
    "pt": {"dois": 2, "duas": 2, "três": 3, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7},
    "es": {"dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6, "siete": 7},
}
CLICHES = {
    "en": ["in today's video", "let's dive in", "dive into", "without further ado", "game changer", "game-changer", "stay tuned", "smash that",
           "hey guys", "welcome back", "in this video", "unlock", "level up", "journey", "let's get started"],
    "pt": ["neste vídeo", "nesse vídeo", "no vídeo de hoje", "vamos mergulhar", "sem mais delongas", "fiquem ligados", "jornada",
           "bora lá", "vamos lá", "transformar sua vida", "mudar sua vida"],
    "es": ["en este video", "en el video de hoy", "sin más preámbulos", "vamos a sumergirnos", "quédate hasta el final", "viaje",
           "cambiar tu vida", "transformar tu vida", "vamos allá"],
}
HYPE = {
    "en": ["game-changer", "game changer", "insane", "mind-blowing", "life-changing", "revolutionary", "unbelievable", "cure", "guaranteed"],
    "pt": ["revolucionário", "inacreditável", "absurdo", "milagre", "milagroso", "cura", "garantido"],
    "es": ["revolucionario", "increíble", "milagro", "milagroso", "cura", "garantizado"],
}
PHRASES = {"en": "okay, real talk", "pt": "fala, galera", "es": "hola, familia"}
SINGULAR = {"en": {"i", "i'm", "my", "me", "i've", "i'll"}, "pt": {"eu", "meu", "minha", "meus", "minhas", "mim"},
            "es": {"yo", "mi", "mis", "conmigo"}}
PLURAL = {"en": {"we", "our", "us", "we're", "we've"}, "pt": {"nós", "nosso", "nossa", "nossos", "nossas"},
          "es": {"nosotros", "nuestro", "nuestra", "nuestros", "nuestras"}}
GENERIC = ["tips", "things", "ways", "secrets", "hacks", "dicas", "coisas", "segredos", "consejos", "cosas", "secretos", "trucos"]

# Greetings and fillers that only open a video. Lowercase; Arabic without its short vowels (they are taken off before matching). An entry that
# ends in a comma only counts with it: the bare word also starts ordinary sentences ("So many people…", "Vale la pena…", "Así que…").
INTERJECTIONS = {
    "en": ["hey", "hi", "hello", "yo", "okay", "ok", "alright", "all right", "um", "uh", "so,", "well,", "look,", "guys,"],
    "pt": ["olha só", "olha", "oi", "olá", "e aí", "fala, galera", "fala, gente", "gente,", "bom dia", "então", "bora", "ei", "tipo,"],
    "es": ["hola", "mira", "oye", "buenas", "a ver", "pues", "ey", "eh,", "bueno,", "vale,", "venga,"],
    "fr": ["salut", "coucou", "bonjour", "hey", "ok", "okay", "eh bien", "alors voilà", "alors,", "bon,", "bref,", "voilà,"],
    "de": ["hey", "hi", "hallo", "servus", "moin", "okay", "ok", "naja", "na ja", "na,", "also,", "so,", "leute,"],
    "it": ["ciao", "ehi", "ehilà", "salve", "allora", "dunque", "ok", "okay", "ragazzi,", "bene,", "beh,"],
    "ja": ["はい", "えー", "えっと", "あの", "さて", "どうも", "こんにちは", "みなさん", "皆さん", "やあ", "ねえ", "じゃあ", "では"],
    "ko": ["안녕하세요", "안녕", "여러분", "자", "음", "그러니까", "있잖아요", "얘들아"],
    "zh": ["嗨", "哈喽", "哈囉", "大家好", "你好", "各位", "那么", "那麼", "好的", "嗯", "欸", "哎", "喂", "家人们", "宝子们"],
    "hi": ["नमस्ते", "नमस्कार", "हेलो", "हैलो", "हाय", "दोस्तों", "तो", "अरे", "अच्छा,", "देखो,", "सुनो,"],
    "id": ["halo", "hai", "hei", "oke", "nah", "jadi", "guys", "gaes", "eh,"],
    "ar": ["مرحبا", "اهلا", "أهلا", "السلام عليكم", "هلا", "يا جماعة", "يا شباب", "طيب", "حسنا", "اسمعوا", "شوفوا"],
    "tr": ["merhaba", "selam", "selamlar", "hey", "evet", "tamam", "bakın", "bak,", "arkadaşlar,"],
    "th": ["สวัสดี", "หวัดดี", "ฮัลโหล", "เอาล่ะ", "โอเค", "เฮ้", "ทุกคน"],
    "vi": ["xin chào", "chào", "các bạn ơi", "này", "à,", "ừ,", "ok", "okay", "hello", "hey", "vậy,"],
    "nl": ["hoi", "hey", "hallo", "hé", "oké", "ok", "nou", "dus", "zo,", "goed,", "kijk,", "jongens,"],
    "sv": ["hej", "hallå", "tjena", "tja", "okej", "ok", "alltså", "asså", "så,", "ja,"],
    "da": ["hej", "hejsa", "hallo", "okay", "ok", "altså", "så,", "nå,", "godt,"],
    "nb": ["hei", "heisann", "hallo", "halla", "okei", "ok", "altså", "så,", "nå,", "ja,"],
}
# After an interjection in a language without spaces, the punctuation or the space that sets it apart, maybe after a particle ("大家好呀，",
# "สวัสดีครับ ") — without it, "那么多人…" or "はいる" would count.
UNSPACED_TAIL = {
    "ja": r"[ねよ〜～ー]?",
    "zh": r"[呀啊哇啦呢喔哦~～]?",
    "th": r"(?:ครับ|ค่ะ|คะ|จ้า|จ้ะ)?",
}

# Invented lived experience, said in the first person. Lowercase, apostrophes straight.
CLAIMS = {
    "en": ["i discovered", "i found out", "i realized", "i've used", "i have used", "i've been using", "i tried", "i've tried", "i tested",
           "i've tested", "saved me", "changed my life", "worked for me", "in my experience", "when i started", "i learned", "i've learned",
           "my clients"],
    "pt": ["descobri", "já usei", "eu usei", "tenho usado", "testei", "me salvou", "mudou minha vida", "mudou a minha vida", "funcionou pra mim",
           "funcionou para mim", "na minha experiência", "quando comecei", "quando eu comecei", "aprendi", "minhas clientes", "meus clientes"],
    "es": ["descubrí", "he usado", "usé", "he probado", "probé", "me salvó", "me cambió la vida", "cambió mi vida", "me funcionó",
           "en mi experiencia", "cuando empecé", "aprendí", "mis clientes"],
    "fr": ["j'ai découvert", "j'ai testé", "j'ai essayé", "j'ai utilisé", "m'a sauvé", "a changé ma vie", "d'après mon expérience",
           "quand j'ai commencé", "j'ai appris", "mes clients", "mes clientes"],
    "de": ["ich habe entdeckt", "hab ich entdeckt", "ich habe getestet", "ich habe ausprobiert", "hat mir geholfen", "hat mein leben verändert",
           "meiner erfahrung nach", "als ich angefangen habe", "ich habe gelernt", "meine kunden"],
    "it": ["ho scoperto", "ho provato", "ho usato", "mi ha salvato", "mi ha cambiato la vita", "nella mia esperienza", "quando ho iniziato",
           "ho imparato", "i miei clienti"],
}

# Average letters of a dictionary word where words are not spaced (see the docstring).
CHARS_PER_WORD = {"zh": 1.4, "ja": 1.75, "th": 4.5}
UNSPACED_LETTERS = "ก-ฺเ-๎々-〇぀-ヿㇰ-ㇿ㐀-䶿一-鿿豈-﫿ｦ-ﾟ"
# Letters `\w` misses: the vowel signs and marks of Devanagari, Thai and Arabic (Python's `\w` is letters and digits, not marks).
WORD = r"\w'’ऀ-ॣ०-ॿก-ฺเ-๎๐-๙ً-ٰٟ"
ARABIC_MARKS = re.compile(r"[ً-ٰٟـ]")

# The writing system each non-Latin language is written in, as ranges of code points.
SCRIPTS = {
    "ar": [(0x0600, 0x06FF), (0x0750, 0x077F), (0xFB50, 0xFDFF), (0xFE70, 0xFEFF)],
    "hi": [(0x0900, 0x097F)],
    "ko": [(0xAC00, 0xD7AF), (0x1100, 0x11FF), (0x3130, 0x318F)],
    "th": [(0x0E00, 0x0E7F)],
    "zh": [(0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xF900, 0xFAFF)],
    "ja": [(0x3005, 0x3007), (0x3040, 0x30FF), (0x31F0, 0x31FF), (0x3400, 0x4DBF), (0x4E00, 0x9FFF), (0xFF66, 0xFF9F)],
}
KANA = [(0x3040, 0x30FF), (0x31F0, 0x31FF), (0xFF66, 0xFF9F)]
# Common characters written differently in Simplified and Traditional Chinese, one for one (not 后/後 or 里/裡: Traditional uses both).
HANS_ONLY = set("这个们说时会来对学发么为过还没样经开问关见长东车书门马实现让给觉钱买读认头间听题选机话应该")
HANT_ONLY = set("這個們說時會來對學發麼為過還沒樣經開問關見長東車書門馬實現讓給覺錢買讀認頭間聽題選機話應該")


def lang(code):
    return code.split("-")[0].lower()


def spoken(text):
    return re.sub(r"\[[^\]]*\]", " ", unicodedata.normalize("NFC", text or ""))


def words(text):
    return re.findall(r"[" + WORD + r"]+", spoken(text).lower().replace("’", "'"))


def word_count(text, code):
    """Spoken words; in a language written without spaces, its letters over the average word length (`CHARS_PER_WORD`)."""
    ws = words(text)
    factor = CHARS_PER_WORD.get(code)
    if not factor:
        return len(ws)
    total = 0.0
    for w in ws:
        for run in re.findall(r"[" + UNSPACED_LETTERS + r"]+|[^" + UNSPACED_LETTERS + r"]+", w):
            total += len(run) / factor if re.match(r"[" + UNSPACED_LETTERS + r"]", run) else 1
    return total


def opens_with_interjection(text, code):
    """The script's first spoken words are a greeting or a filler (`INTERJECTIONS`); None for a language without a list."""
    entries = INTERJECTIONS.get(code)
    if entries is None:
        return None
    head = re.sub(r"^[\W_]+", "", spoken(text).strip().lower().replace("’", "'"))
    if code == "ar":
        head = ARABIC_MARKS.sub("", head)
    for entry in sorted(entries, key=len, reverse=True):
        if not head.startswith(entry):
            continue
        rest = head[len(entry):]
        if entry.endswith(","):
            return True
        if code in UNSPACED_TAIL:
            if re.match(UNSPACED_TAIL[code] + r"(?:[\s,，、。！!？?…~～:：.]|$)", rest):
                return True
        elif not re.match(r"[" + WORD + r"]", rest):
            return True
    return False


def claim_count(text, code):
    """First-person phrases of lived experience (`CLAIMS`); None for a language without a list."""
    entries = CLAIMS.get(code)
    if entries is None:
        return None
    lowered = spoken(text).lower().replace("’", "'")
    return sum(len(re.findall(r"(?<![" + WORD + r"])" + re.escape(e) + r"(?![" + WORD + r"])", lowered)) for e in entries)


def in_ranges(character, ranges):
    value = ord(character)
    return any(low <= value <= high for low, high in ranges)


def script_share(text, language):
    """The share of the letters of `text` written in `language`'s own writing system, with a note when Chinese looks like the other variant;
    None for languages written in Latin letters."""
    code = lang(language)
    ranges = SCRIPTS.get(code)
    if ranges is None:
        return None, ""
    letters = [c for c in spoken(text) if unicodedata.category(c)[0] in "LM"]
    if not letters:
        return 0.0, ""
    if code == "ja" and not any(in_ranges(c, KANA) for c in letters):
        return 0.0, ""
    share = sum(1 for c in letters if in_ranges(c, ranges)) / len(letters)
    note = ""
    if code == "zh":
        hans, hant = sum(1 for c in letters if c in HANS_ONLY), sum(1 for c in letters if c in HANT_ONLY)
        if language == "zh-TW" and hans > hant:
            note = " Hans?"
        elif language != "zh-TW" and hant > hans:
            note = " Hant?"
    return share, note


def stems(text):
    return {w[:5] for w in words(text) if w not in STOP and len(w) > 2}


def sentences(text):
    parts = re.split(r"(?<=[.!?…])\s+|(?<=[。！？؟।])\s*|\n+", spoken(text).strip())
    return [p.strip() for p in parts if len(words(p)) > 0]


def trigrams(ws):
    return [" ".join(ws[i:i + 3]) for i in range(len(ws) - 2)]


def jaccard(a, b):
    return len(a & b) / len(a | b) if a and b else 0.0


def blocks(text):
    return [b.strip() for b in (text or "").split("\n\n") if words(b)]


def promised_number(text, code):
    head = text.lower()
    found = [int(n) for n in re.findall(r"\b([2-9]|10)\b", head)]
    for word, value in NUMBERS.get(code, {}).items():
        if re.search(r"\b" + word + r"\b", head):
            found.append(value)
    return max(found) if found else None


def told_items(text, code):
    lowered = spoken(text).lower()
    hits = {marker for marker in ORDINALS.get(code, []) if re.search(r"(?<!\w)" + re.escape(marker) + r"(?!\w)", lowered)}
    numbered = len(set(re.findall(r"(?:^|\n)\s*(\d)[.)]", text or "")))
    return max(len(hits), numbered)


def brief_parts(idea):
    """The angle and the opening line of a brief as the composer lays it out (`IdeaBrief.composerText`): the subject, then "Angle: …", then
    "Open with: “…”", the labels and the quotes in the language of the interface the run had (「…」, «…», „…“)."""
    lines = idea.split("\n")[1:]
    quoted = [l for l in lines if re.search(r"[“«„「‘”]", l)]
    opening = ""
    if quoted:
        found = re.search(r"[“«„「‘”]\s*(.*?)\s*[”»“」’]?\s*$", quoted[-1])
        opening = found.group(1) if found else ""
    angle = next((re.split(r"[:：]", l, maxsplit=1)[1] for l in lines if re.search(r"[:：]", l) and (not quoted or l != quoted[-1])), "")
    return angle, opening


def script_metrics(sample):
    code = lang(sample["language"])
    text = sample.get("text") or ""
    ws = words(text)
    sents = sentences(text)
    tri = trigrams(ws)
    out = {"written": bool(ws)}
    if not ws:
        return out
    minimum = sample.get("minimumWords") or 1
    out["words"] = word_count(text, code)
    out["ratio"] = out["words"] / minimum
    last = spoken(text).strip()
    out["cut"] = bool(last) and last[-1] not in ".!?…\"”»)。！？」』؟।"
    out["rep"] = 1 - len(set(tri)) / len(tri) if tri else 0
    bl = blocks(text)
    worst = 0.0
    for j in range(1, len(bl)):
        mine = trigrams(words(bl[j]))
        before = set(itertools.chain.from_iterable(trigrams(words(b)) for b in bl[:j]))
        if mine:
            worst = max(worst, sum(1 for t in mine if t in before) / len(mine))
    out["xblock"] = worst
    out["blocks"] = len(bl)
    dup = 0
    for a, b in itertools.combinations(sents, 2):
        sa, sb = stems(a), stems(b)
        if len(sa) >= 4 and len(sb) >= 4 and jaccard(sa, sb) >= 0.6:
            dup += 1
    out["dupsent"] = dup
    idea = sample.get("idea", "")
    first_line = idea.split("\n")[0]
    number = promised_number(first_line + " " + " ".join(sents[:2]), code)
    if number:
        out["promise"] = number
        out["delivered"] = told_items(text, code) >= number
    idea_stems = stems(first_line)
    out["idea"] = len(idea_stems & stems(text)) / len(idea_stems) if idea_stems else None
    if sample.get("hasBrief"):
        angle, opening = brief_parts(idea)
        body = " ".join(sents[1:])
        a = stems(angle)
        out["angle"] = len(a & stems(body)) / len(a) if a else None
        o = stems(opening)
        out["open"] = (len(o & stems(" ".join(sents[:2]))) / len(o) >= 0.6) if o else None
    lengths = [len(words(s)) for s in sents]
    out["sent"] = statistics.mean(lengths)
    out["sentsd"] = statistics.pstdev(lengths)
    lowered = spoken(text).lower()
    out["cliche"] = sum(lowered.count(c) for c in CLICHES.get(code, []))
    out["hype"] = sum(1 for h in HYPE.get(code, []) if re.search(r"(?<!\w)" + re.escape(h) + r"(?!\w)", lowered))
    phrase = PHRASES.get(code)
    out["phrase"] = phrase in lowered if phrase else None
    out["phraseFirst"] = lowered.strip().startswith(phrase) if phrase else None
    out["I"] = sum(1 for w in ws if w in SINGULAR.get(code, set()))
    out["we"] = sum(1 for w in ws if w in PLURAL.get(code, set()))
    out["excl"] = text.count("!") / max(1, len(sents))
    out["interj"] = opens_with_interjection(text, code)
    out["claims"] = claim_count(text, code)
    return out


def idea_metrics(batches):
    ideas = [i for b in batches for i in (b.get("ideas") or [])]
    out = {"n": len(ideas), "fail": sum(1 for b in batches if b.get("failure")), "s": [b["seconds"] for b in batches]}
    dup2 = dup_t = 0
    for a, b in itertools.combinations(ideas, 2):
        same = [jaccard(stems(a[f]), stems(b[f])) >= 0.5 for f in ("title", "angle", "openingLine")]
        dup_t += same[0]
        dup2 += sum(same) >= 2
    out["dup2"], out["dupT"] = dup2, dup_t
    out["restate"] = sum(1 for i in ideas if len(stems(i["angle"]) - stems(i["title"])) < 2)
    out["generic"] = sum(1 for i in ideas if any(re.search(r"\b" + g + r"\b", i["title"].lower()) for g in GENERIC))
    out["q"] = sum(1 for i in ideas if i["openingLine"].strip().endswith("?"))
    out["digits"] = sum(1 for i in ideas if re.search(r"\d", i["openingLine"]))
    return out


def load(run):
    with open(os.path.join(FOLDER, "quality-run-" + run + ".json"), encoding="utf-8") as handle:
        return json.load(handle)


def mean(values):
    values = [v for v in values if v is not None]
    return statistics.mean(values) if values else float("nan")


def summarize(samples):
    scripts = [s for s in samples if s["kind"] == "script" and s["condition"] != SWEEP]
    groups = {}
    for s in scripts:
        groups.setdefault((s["language"], s["condition"]), []).append(s)
    if scripts:
        groups[("all", "all")] = scripts
    rows = []
    for key in sorted(groups):
        group = groups[key]
        m = [script_metrics(s) for s in group]
        ok = [x for x in m if x["written"]]
        promised = [x for x in ok if "promise" in x]
        tokens_in = [sum((s.get(k) or 0) for k in ("instructionTokens", "promptTokens", "schemaTokens")) for s in group]
        rows.append({
            "group": f"{key[0]}·{key[1]}", "n": f"{len(ok)}/{len(group)}",
            "words/min": mean([x["ratio"] for x in ok]), "cut": sum(x["cut"] for x in ok),
            "rep": mean([x["rep"] for x in ok]), "xblock": mean([x["xblock"] for x in ok]), "dupsent": sum(x["dupsent"] for x in ok),
            "promise": f"{sum(x['delivered'] for x in promised)}/{len(promised)}",
            "idea": mean([x["idea"] for x in ok]), "angle": mean([x.get("angle") for x in ok]),
            "open": f"{sum(1 for x in ok if x.get('open'))}/{sum(1 for x in ok if x.get('open') is not None)}",
            "sent": mean([x["sent"] for x in ok]), "cliche": sum(x["cliche"] for x in ok), "hype": sum(x["hype"] for x in ok),
            "phrase": f"{sum(1 for x in ok if x.get('phrase'))}/{len(ok)}", "1st": sum(1 for x in ok if x.get("phraseFirst")),
            "I/we": f"{sum(x['I'] for x in ok)}/{sum(x['we'] for x in ok)}",
            "interj": f"{sum(1 for x in ok if x.get('interj'))}/{len(ok)}", "claims": counted([x.get("claims") for x in ok]),
            "s": mean([s["seconds"] for s in group]), "first": mean([s.get("firstResponse") for s in group]),
            "att": mean([s.get("attempts") for s in group]), "tok-in": mean(tokens_in),
            "tok-out": mean([s.get("outputTokens") for s in group]),
        })
    ideas = [s for s in samples if s["kind"] == "ideas" and s["condition"] != SWEEP]
    igroups = {}
    for s in ideas:
        igroups.setdefault((s["language"], s["condition"]), []).append(s)
    irows = []
    for key in sorted(igroups):
        m = idea_metrics(sorted(igroups[key], key=lambda s: s["index"]))
        irows.append({"group": f"{key[0]}·{key[1]}", "n": m["n"], "fail": m["fail"], "dup2": m["dup2"], "dupT": m["dupT"],
                      "restate": m["restate"], "generic": m["generic"], "q": m["q"], "digits": m["digits"], "s": mean(m["s"])})
    return rows, irows


def counted(values):
    """The sum of a count that only some languages measure; "–" when none of them does."""
    values = [v for v in values if v is not None]
    return sum(values) if values else "–"


def share_cell(texts, language):
    """The lowest share of `texts` written in the language's own writing system, with the Chinese variant's note; "–" for Latin letters."""
    found = [script_share(t, language) for t in texts if t]
    if not found or found[0][0] is None:
        return "–"
    share, note = min(found, key=lambda pair: pair[0])
    return f"{share:.2f}{note}"


def sweep(samples):
    """The 20-language sweep, by language: what was written and whether it is in the language."""
    rows = []
    swept = [s for s in samples if s["condition"] == SWEEP]
    for language in sorted({s["language"] for s in swept}):
        scripts = sorted((s for s in swept if s["language"] == language and s["kind"] == "script"), key=lambda s: s["index"])
        batches = [s for s in swept if s["language"] == language and s["kind"] == "ideas"]
        m = [script_metrics(s) for s in scripts]
        ok = [x for x in m if x["written"]]
        interj = [x.get("interj") for x in ok]
        ideas = [i for b in batches for i in (b.get("ideas") or [])]
        rows.append({
            "language": language, "written": f"{len(ok)}/{len(scripts)}",
            "fail": sum(1 for s in scripts + batches if s.get("failure")),
            "words/min": mean([x["ratio"] for x in ok]),
            "interj": "–" if any(v is None for v in interj) else f"{sum(1 for v in interj if v)}/{len(ok)}",
            "claims": counted([x.get("claims") for x in ok]),
            "s": mean([s["seconds"] for s in scripts]), "lang": share_cell([s.get("text") for s in scripts], language),
            "ideas": len(ideas), "ilang": share_cell([" ".join((i["title"], i["angle"], i["openingLine"])) for i in ideas], language),
            "is": mean([b["seconds"] for b in batches]),
        })
    return rows


def fmt(value):
    if isinstance(value, float):
        return "–" if value != value else f"{value:.2f}"
    return str(value)


def table(title, rows):
    if not rows:
        return
    cols = list(rows[0].keys())
    widths = {c: max(len(c), *(len(fmt(r[c])) for r in rows)) for c in cols}
    print(f"\n## {title}")
    print("  ".join(c.ljust(widths[c]) for c in cols))
    for r in rows:
        print("  ".join(fmt(r[c]).ljust(widths[c]) for c in cols))


def texts(run, samples):
    path = os.path.join(ROOT, "build", "reports", f"quality-{run}.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as out:
        out.write(f"# Script quality run `{run}`\n")
        for s in samples:
            out.write(f"\n## {s['kind']} · {s['language']} · {s['condition']} · {s['index']}\n\n")
            out.write(f"**Idea:** {s['idea']}\n\n")
            if s["kind"] == "script":
                m = script_metrics(s)
                out.write(f"{s['seconds']:.1f} s · attempts {s.get('attempts')} · violations {s.get('violations')} · "
                          f"{ {k: (round(v, 2) if isinstance(v, float) else v) for k, v in m.items()} }\n\n")
                out.write(f"**{s.get('title')}**\n\n{s.get('text') or s.get('failure')}\n")
                if s.get("discardedDraft"):
                    out.write(f"\n_Discarded draft:_\n\n{s['discardedDraft']}\n")
            else:
                for i in s.get("ideas") or []:
                    out.write(f"- [{i.get('angleKind')}] **{i['title']}** — {i['angle']} — “{i['openingLine']}”\n")
                if s.get("failure"):
                    out.write(f"\nFailure: {s['failure']}\n")
    print(f"\ntexts: {os.path.relpath(path, ROOT)}")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(64)
    for run in args:
        samples = load(run)
        rows, irows = summarize(samples)
        table(f"{run} · scripts", rows)
        table(f"{run} · ideas", irows)
        table(f"{run} · sweep, by language (no voice)", sweep(samples))
        if "--texts" in sys.argv:
            texts(run, samples)


if __name__ == "__main__":
    main()
