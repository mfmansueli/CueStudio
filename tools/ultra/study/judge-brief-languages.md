# Brief for a blind judge of the Ultra study: the other languages

The owner asked (04/11/2026) how well Ultra AI writes in the 17 languages Cue offers besides Portuguese, English and Spanish: French, German,
Italian, Japanese, Korean, Chinese (Simplified and Traditional), Hindi, Indonesian, Arabic, Turkish, Thai, Vietnamese, Dutch, Swedish,
Danish and Norwegian. Each packet holds **one** script for one request (a card's idea or a typed one), under a random letter. You are one
of three independent judges.

## Rules
1. Everything in `tools/ultra/study/judge-brief.md` applies (blindness, reading before scoring, one JSON per packet in the rubric's shape,
   reporting back only which packets you finished). Read it and `tools/ultra/study/rubric.md` first, entirely.
2. With one script a packet, `ranking` is just that letter.
3. **Judge as a native speaker of the script's language and a short-video scriptwriter from that market**, not as a translator. Ask: would a
   creator from that country say this on camera, in these words?
   - Language and writing system: Simplified characters for zh-CN and Traditional with Taiwanese usage for zh-TW; Hindi in Devanagari;
     no stray words in another language unless creators there really say them (common loanwords are fine).
   - Register, consistent from first line to last and right for a casual vertical video there: German *du*, Korean 해요체 or a consistent
     friendly level, Japanese plain or です/ます without mixing by accident, French *tu* or *vous* without switching, Arabic in a register
     a creator would speak (Modern Standard Arabic read aloud stiffly counts against naturalness; note which variety it is).
   - Translationese: English idioms or sentence shapes carried over word for word, unnatural word order, calques.
   - Local detail: numbers, units, currency and examples that fit the market when the script uses them.
4. Count every language problem once, in its home criterion (the rubric's discipline): wording that sounds translated or written goes to
   **Naturalness**; a wrong register or a creator's rule broken goes to **Voice**; a grammar error, a wrong character or a missing word adds
   the `broken_text` flag; a script in the wrong language, variety or writing system adds `wrong_language_or_address`.
5. Add two keys to each script's object, besides the rubric's: `"fluency"`: 1–5 (5 a native creator would say every sentence as written;
   4 one or two phrases a native would put differently; 3 noticeably non-native or translated in places; 1 hard to follow or wrong
   language), and `"language_notes"`: one sentence naming the language problems you found, quoting the words, or `""` when there are none.
6. Length is judged against the words the context says the app asked for, with the word count given (counted as the app counts them, by
   word for languages written without spaces).
