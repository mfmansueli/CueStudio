#!/usr/bin/env python3
"""Writes the idea library's raw ideas from the Mac (DESIGN_PROJECT §30), the same request `IdeaLibraryDeviceTests` sends from the iPhone.

    python3 tools/ideas/write_library.py --config <folder> [--pairs 5,6] [--languages pt,en] [--parallel 6] [--max-calls 300] [--log <file>]

Ultra AI's call, through the lab's Firebase app: Firebase AI Logic, the Agent Platform Gemini API at `global`, `FirebaseUltraClient.modelName`,
the `.ideas` stage's JSON schema and token cap, and App Check with the lab's registered debug token. `<folder>` holds the lab's
`UltraLab-GoogleService-Info.plist` and `ultra-ios-appcheck-debug-token` (build/firebase-quality of a checkout, as
`tools/ultra/install-lab-config.sh` uses them); nothing of them is printed. The prompt is `IdeaLibraryDeviceTests.prompt(language:topics:)`'s,
written again here: change both together.

Each idea is a `LIBRARY` line and each call a `LIBRARYCOST` line in the log (build/logs/idea-library.log), as the device test prints them, so
`tools/ideas/collect_library.py <log>` gathers them, then `stage`, `IdeaLibraryBuildTests` and `install`, as that file says. From the Mac the
calls run side by side and the iPhone and Xcode stay free; they are not counted in the iPhone's lab cap (`UltraCallBudget`), so `--max-calls`
is this run's cap.
"""
import argparse
import concurrent.futures
import json
import pathlib
import plistlib
import sys
import threading
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
BUNDLE = "com.cuestudioteleprompter"
LAB_PROJECT = "cue-script-ai-lab"
MODEL = "gemini-3.5-flash"  # FirebaseUltraClient.modelName
LOCATION = "global"  # FirebaseUltraClient.location
IDEA_RESPONSE_TOKENS = 32_768  # UltraStageRequest.ideaResponseTokens
TIMEOUT = 300  # FirebaseUltraClient.ideasTimeout
PRICE = {"input": 1.50, "cached": 0.15, "output": 9.00}  # UltraPrice.google, USD per million tokens
PER_TOPIC = 40  # IdeaLibraryDeviceTests.perTopic

# IdeaLibraryDeviceTests.pairs (Niche raw values).
PAIRS = [
    ["fitness", "food"], ["beauty", "fashion"], ["finance", "tech"], ["travel", "productivity"], ["parenting", "lifestyle"],
    ["business", "comedy"], ["education", "healthcare"], ["selfImprovement", "gaming"], ["wellness", "musicArts"], ["relationships", "sports"],
    ["faith", "booksMovies"], ["news", "homeDIY"], ["shopping", "pets"], ["realEstate", "artDesign"], ["law", "cars"], ["trades", "events"],
    ["agriculture", "causes"],
]

# IdeaLibraryDeviceTests.languages.
LANGUAGES = [
    ("en", "English, natural for creators in the US, the UK, Canada and Australia (American spelling)"),
    ("pt", "Brazilian Portuguese, as Brazilian creators really talk on camera"),
    ("es", "Spanish, natural across Latin America and Spain (no regional slang)"),
    ("fr", "French"), ("de", "German"), ("it", "Italian"), ("nl", "Dutch"), ("da", "Danish"), ("sv", "Swedish"),
    ("nb", "Norwegian Bokmål"),
    ("ar", "Arabic, the Modern Standard register creators use on camera"),
    ("hi", "Hindi in Devanagari, the everyday register Indian creators use (English loanwords only where they really use them)"),
    ("id", "Indonesian"), ("ja", "Japanese"), ("ko", "Korean"), ("th", "Thai"), ("tr", "Turkish"), ("vi", "Vietnamese"),
    ("zh-Hans", "Simplified Chinese, as creators in mainland China write"),
    ("zh-Hant", "Traditional Chinese, as creators in Taiwan write"),
]

# IdeaAngle: raw value and `ask`, in its order.
ANGLES = [
    ("list", "a list of things"), ("mistake", "a common mistake and how to fix it"), ("myth", "a myth to bust"),
    ("story", "a short story from experience"), ("tutorial", "a quick how-to"), ("opinion", "an honest opinion"),
    ("fact", "a surprising fact"), ("beforeAfter", "a before and after"), ("beginner", "the question every beginner asks"),
    ("comparison", "a comparison of two options"), ("challenge", "a challenge to try"), ("dayInLife", "a day in the life"),
    ("tool", "a tool or habit that changed things"), ("lesson", "a lesson learned the hard way"),
    ("question", "a question for the audience"), ("prediction", "a prediction"),
]

INSTRUCTIONS = (
    "You are a senior short-form video strategist and a native writer of the language you are asked to write in. You write idea briefs for "
    "creators who film themselves talking to the camera (TikTok, Instagram Reels, YouTube Shorts). You never translate from English: you write "
    "the way creators who speak that language really title and open their videos."
)

SCHEMA = {
    "type": "OBJECT",
    "properties": {"ideas": {"type": "ARRAY", "items": {"type": "OBJECT", "properties": {
        "topic": {"type": "INTEGER"}, "angle": {"type": "STRING"}, "title": {"type": "STRING"},
        "pointOfView": {"type": "STRING"}, "openingLine": {"type": "STRING"},
    }, "required": ["topic", "angle", "title", "pointOfView", "openingLine"]}}},
    "required": ["ideas"],
}


def prompt_names() -> dict[str, str]:
    """Niche.promptName for every theme, read from the Swift source so the two never drift."""
    source = (ROOT / "Cue Studio" / "Models" / "Niche.swift").read_text(encoding="utf-8")
    block = source[source.index("var promptName"):]
    block = block[:block.index("\n    }\n")]
    names = {}
    for line in block.splitlines():
        line = line.strip()
        if line.startswith("case .") and ":" in line and '"' in line:
            cases, text = line[len("case "):].split(":", 1)
            value = text.strip().strip('"')
            for case in cases.split(","):
                names[case.strip().lstrip(".")] = value
    return names


def prompt(language: str, topics: list[str], names: dict[str, str]) -> str:
    angles = "; ".join(f"{raw} ({ask})" for raw, ask in ANGLES)
    numbered = "\n".join(f"{index + 1}. {names[topic]}" for index, topic in enumerate(topics))
    return (
        f"Write video ideas in {language}, for these topics:\n{numbered}\n\n"
        f"For each topic, write {PER_TOPIC} ideas: two or three for each of these angles, every angle used: {angles}.\n\n"
        "Each idea:\n"
        "- topic: the topic's number.\n"
        "- angle: the angle's key, exactly as written above.\n"
        "- title: the video's title, at most 60 characters, naming its exact subject inside the topic (a sunscreen texture, a grocery "
        "list, a resistance band), never a vague word alone (\"products\", \"tips\", \"things\").\n"
        "- pointOfView: one sentence, at most 20 words, telling the creator what to show, argue or explain: something the title doesn't "
        "already say.\n"
        "- openingLine: the first sentence said on camera, at most 18 words, spoken and natural, without quotes, emojis or hashtags.\n\n"
        "Rules:\n"
        "- Anyone in the topic could film it. An idea is a draft the creator adjusts: an imagined scene in the first person is welcome "
        "(\"I used to…\", \"The day I…\"), but never an invented number, study, statistic, credential or result presented as a fact.\n"
        "- Evergreen: no dates, years, seasons, holidays, trends, prices, currencies, brands, products by name, apps or celebrities.\n"
        "- Safe for every audience. Tips, never prescriptions: no medical, legal or financial promises, no diets or doses, no \"guaranteed\".\n"
        "- Every idea is a different subject from the others, not the same idea in other words; the titles vary in shape (not all "
        "questions, not all numbers).\n"
        f"- Everything in {language}, written as a native creator would say it."
    )


class Lab:
    """The lab's Firebase app: its key and project, and an App Check token exchanged for the registered debug token."""

    def __init__(self, folder: pathlib.Path):
        with open(folder / "UltraLab-GoogleService-Info.plist", "rb") as file:
            info = plistlib.load(file)
        if info.get("PROJECT_ID") != LAB_PROJECT or info.get("BUNDLE_ID") != BUNDLE:
            sys.exit("Not the lab's configuration: nothing sent.")
        self.api_key = info["API_KEY"]
        self.project = info["PROJECT_ID"]
        self.app_id = info["GOOGLE_APP_ID"]
        self.debug_token = (folder / "ultra-ios-appcheck-debug-token").read_text(encoding="utf-8").strip()
        self.lock = threading.Lock()
        self.token = None
        self.expires = 0.0

    def app_check(self) -> str:
        with self.lock:
            if self.token and time.time() < self.expires - 300:
                return self.token
            url = (f"https://firebaseappcheck.googleapis.com/v1/projects/{self.project}/apps/{self.app_id}:exchangeDebugToken"
                   f"?key={self.api_key}")
            request = urllib.request.Request(url, data=json.dumps({"debugToken": self.debug_token}).encode(), method="POST", headers={
                "Content-Type": "application/json", "x-ios-bundle-identifier": BUNDLE,
            })
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    reply = json.load(response)
            except urllib.error.HTTPError as error:
                sys.exit(f"App Check refused the debug token (HTTP {error.code}).")
            self.token = reply["token"]
            self.expires = time.time() + float(str(reply.get("ttl", "3600s")).rstrip("s"))
            return self.token

    def generate(self, system: str, text: str) -> dict:
        url = (f"https://firebasevertexai.googleapis.com/v1beta/projects/{self.project}/locations/{LOCATION}/publishers/google/models/"
               f"{MODEL}:generateContent")
        body = {
            "systemInstruction": {"role": "system", "parts": [{"text": system}]},
            "contents": [{"role": "user", "parts": [{"text": text}]}],
            "generationConfig": {"maxOutputTokens": IDEA_RESPONSE_TOKENS, "responseMimeType": "application/json", "responseSchema": SCHEMA},
        }
        request = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST", headers={
            "Content-Type": "application/json", "x-goog-api-key": self.api_key, "x-ios-bundle-identifier": BUNDLE,
            "X-Firebase-AppCheck": self.app_check(), "X-Firebase-AppId": self.app_id,
        })
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return json.load(response)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=pathlib.Path)
    parser.add_argument("--pairs", default=None, help="pair numbers, e.g. 5,6 (all without it)")
    parser.add_argument("--languages", default=None, help="localizations, e.g. pt,en (all without it)")
    parser.add_argument("--parallel", type=int, default=6)
    parser.add_argument("--max-calls", type=int, default=300)
    parser.add_argument("--log", type=pathlib.Path, default=ROOT / "build" / "logs" / "idea-library.log")
    args = parser.parse_args()

    names = prompt_names()
    pairs = [int(p) for p in args.pairs.split(",")] if args.pairs else list(range(len(PAIRS)))
    wanted = set(args.languages.split(",")) if args.languages else None
    cases = [(loc, name, pair) for loc, name in LANGUAGES if wanted is None or loc in wanted for pair in pairs]
    if len(cases) > args.max_calls:
        sys.exit(f"{len(cases)} calls asked, more than --max-calls {args.max_calls}.")
    lab = Lab(args.config)
    lab.app_check()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    log = args.log.open("a", encoding="utf-8")
    write = threading.Lock()
    calls = {"made": 0, "usd": 0.0, "failed": []}

    def run(case):
        localization, language, pair = case
        topics = PAIRS[pair]
        for attempt in range(2):
            with write:
                if calls["made"] >= args.max_calls:
                    return f"{localization} · pair {pair}: cap reached"
                calls["made"] += 1
            started = time.time()
            try:
                reply = lab.generate(INSTRUCTIONS, prompt(language, topics, names))
            except (urllib.error.URLError, TimeoutError) as error:
                code = getattr(error, "code", type(error).__name__)
                if attempt == 0:
                    time.sleep(10)
                    continue
                calls["failed"].append(f"{localization}·{pair}")
                return f"{localization} · pair {pair}: failed ({code})"
            usage = reply.get("usageMetadata", {})
            prompt_tokens = usage.get("promptTokenCount", 0)
            cached = usage.get("cachedContentTokenCount", 0)
            output = usage.get("candidatesTokenCount", 0)
            thinking = usage.get("thoughtsTokenCount", 0)
            usd = ((prompt_tokens - cached) * PRICE["input"] + cached * PRICE["cached"] + (output + thinking) * PRICE["output"]) / 1e6
            candidate = (reply.get("candidates") or [{}])[0]
            finished = candidate.get("finishReason") == "STOP"
            text = "".join(part.get("text", "") for part in candidate.get("content", {}).get("parts", []) if not part.get("thought"))
            try:
                ideas = json.loads(text)["ideas"]
            except (ValueError, KeyError):
                ideas = []
            counts = {topic: 0 for topic in topics}
            lines = [f"LIBRARYCOST {localization} pair {pair}: {time.time() - started:.0f} s, in {prompt_tokens}, out {output}, "
                     f"thinking {thinking}, USD {usd:.4f}, finished {'yes' if finished else 'no'}"]
            for idea in ideas:
                number = idea.get("topic", 0)
                if not 1 <= number <= len(topics):
                    continue
                topic = topics[number - 1]
                counts[topic] += 1
                lines.append("LIBRARY " + json.dumps({
                    "language": localization, "topic": topic, "angle": idea.get("angle", ""), "title": idea.get("title", ""),
                    "pointOfView": idea.get("pointOfView", ""), "openingLine": idea.get("openingLine", ""),
                }, ensure_ascii=False))
            with write:
                calls["usd"] += usd
                log.write("\n".join(lines) + "\n")
                log.flush()
            short = [t for t, n in counts.items() if n < PER_TOPIC * 3 // 4]
            if short and attempt == 0:
                continue
            if short:
                calls["failed"].append(f"{localization}·{pair}")
            return f"{localization} · pair {pair}: {counts} USD {usd:.3f}" + (" SHORT" if short else "")
        return f"{localization} · pair {pair}: gave up"

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.parallel) as pool:
        for line in pool.map(run, cases):
            print(line, flush=True)
    print(f"{calls['made']} calls, USD {calls['usd']:.2f}; failed or short: {', '.join(calls['failed']) or 'none'}; log {args.log}")


if __name__ == "__main__":
    main()
