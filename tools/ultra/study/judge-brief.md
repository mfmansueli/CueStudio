# Brief for a blind judge of the Ultra study

You are one of three independent judges of spoken video scripts that an AI wrote for content creators (Cue Studio's "Ultra AI"). The
owner wants to know whether cheaper model settings write as well as the most expensive one. Your scores decide that, so they must be
careful, consistent and blind.

## Rules
1. Read `tools/ultra/study/rubric.md` first, entirely. It is the only scale. Apply its anchors literally.
2. Your packets are in `<study folder>/judging/packets/<your judge name>/`. Each packet is one case: the context the app sent and several
   scripts for the same request under random letters.
3. **Stay blind.** Never open `<study folder>/out/`, `<study folder>/judging/keys/`, other judges' folders, `metrics.json`, `scores.json`
   or any file outside your packets and the rubric. Never try to guess which model or setting wrote a script. Never run code on the
   scripts; read them.
4. For each packet: read the context, then read every script fully once before scoring any. Then score each script on the eight criteria
   (1–5), give the practical verdict, tick the hard flags, quote the words behind any score below 5 (short quotes), and rank all the
   scripts of the packet from best to worst (no ties in the ranking; when two are truly equal, put first the one you would rather record).
5. Judge in the script's language as a native speaker and an experienced short-video scriptwriter would: is it something a real creator
   would say on camera, does it deliver, does it fit this creator and this request.
6. Length is never quality by itself: the context says how many words the app asked for, and each script shows its word count.
7. Be calibrated, not generous: 5 means you would not change it; 3 means clearly improvable; reserve 1 for real failures. Use the whole
   scale. Scripts that are all good should still be separated by the ranking and by the small differences the anchors describe.
8. Write one JSON file per packet to `<study folder>/judging/results/<your judge name>/<case>.json`, in the exact shape of the rubric's
   "Judge output" (keys `packet`, `scripts`, `ranking`, `notes`; criteria keys `hook`, `substance`, `format`, `naturalness`, `voice`,
   `accuracy`, `ending`, `length`, `verdict`, `flags`, `evidence`). Valid JSON only, UTF-8, no comments.
9. Report back only which packets you finished and anything that prevented you from judging one. Do not summarise the scores.
