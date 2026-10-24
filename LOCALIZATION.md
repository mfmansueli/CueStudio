# Cue Studio — Languages

Video caption collection: Cue / Impact / Clean / Pop / Editorial (`CaptionTheme`); Brazilian
Portuguese uses **Impacto**, and **Clean** is the collection's proper name in every interface.
The existing text presets and general "Clean" translation are unchanged. Caption settings use
the same 20-language catalog. Bundled font licenses and local glyph fallbacks are documented in
`CAPTION_FONTS.md`; RTL shaping is preserved in the shared renderer.

How Cue handles languages: the architecture, the terminology every translation follows, and what
right to left and longer languages need. Read with `ARCHITECTURE.md` (strings are always localized)
and `DESIGN_PROJECT.md` (Language & Region screen).

## 1. Three languages, kept apart

Cue has three language settings (Settings › Language & Region) and none follows another:

| Setting | What it is | Stored in | Default |
|---|---|---|---|
| **App Language** | Cue's interface | the app's `AppleLanguages` (the list Settings › Cue › Language edits too) | the iPhone's language |
| **Voice Following Language** | what Cue listens for while the creator reads | `DefaultsKey.voiceFollowingLanguage` | Same as Script |
| **Script Language** | what new scripts are written in; each script keeps its own (`Script.language`, ••• › Script Language) | `DefaultsKey.scriptLanguage` | Auto-detect |

An iPhone in Italian can run Cue in English for a script in Portuguese (Brazil) read aloud in
Portuguese (Brazil). Changing the app language never changes the other two, never translates a
script and never touches the iPhone's language. `LanguageService` owns the three.

Every language is a `CueLanguage` (`Models/CueLanguage.swift`), the only list of languages in the
app: script/speech locale (`pt-BR`, `zh-CN`, `ar-SA`…, the raw value saved with scripts), interface
localization (`pt`, `zh-Hans`…), native and localized names, English name (for AI instructions),
direction and whether it's written without spaces.

- **Interface:** String Catalogs (`Localizable`, `InfoPlist`, `AppShortcuts`) with
  `String(localized:)` and `LocalizedStringKey`. The pick is written to `AppleLanguages`, so every
  later launch is natively in that language (permission prompts, system sheets, formats, right to
  left). The running app switches at once: `String(localized:)` resolves through
  `String+InterfaceLanguage.swift` in `InterfaceLocale.current` (Foundation's own picks the language
  once per launch and ignores `Bundle` overrides), SwiftUI reads `locale` and `layoutDirection` from
  `RootView`'s environment, and `RootView` rebuilds the screens (`.id`). Navigation that must survive
  lives in `PresentationService` (`settingsPath`), so the creator stays on Language & Region.
  Numbers and dates use `Locale.interface` (interface language, iPhone region).
- **Voice Following:** `SpeechLanguageRequest` (the Voice Following language, else the script's,
  else detected from the script's text) → `SpeechLocaleResolver` → Apple's on-device
  `SpeechTranscriber` (the original engine, tried first for every language, so English and
  Portuguese are recognized exactly as before), or `DictationTranscriber` from the same
  `SpeechAnalyzer` framework for languages or devices `SpeechTranscriber` doesn't cover. Availability
  is always asked of the device; an unavailable language says so (`SpeechUnavailableReason`) and is
  never swapped for another one: the prompter shows the speed instead of "AUTO" and says the text
  scrolls while the creator talks (`VoiceFollowStatus`). While the one language asked for loads or
  downloads, the prompter says that too. The matching (`ScriptSpeechTracker`) didn't change; the
  words it matches come from `WordTokenizer` (below).
- **Captions and Clean Up:** hear a take in the **script's** language (`LanguageService.captionRequest`:
  the script's own, read from its text on Auto-detect; a take without a script, the Script Language,
  else the iPhone's), through the same resolver and recognizers. Never Voice Following's language:
  when Voice Following listens in another one (picked in Language & Region), Captions say so
  (`SpeechLanguageConflict`) next to the language picker, so the two never disagree silently.
- **The language spoken** (captions only, `SpokenLanguageIdentifier`): a take **without a script** on Auto is not trusted to be
  in the guessed language. Its first 10 s of speech are heard in up to four likely languages
  (`LanguageService.likelySpokenLanguages`: the guess above, the iPhone's languages, the interface's, English) and the take is
  captioned in the one `SpeechTranscriber` understood best by its own word confidence (the guess keeps a tie within 0.02; another
  language must reach 0.85 to win, or 0.80 and 0.30 ahead of every other). A recognizer writes what it hears in the language it
  hears it in (Spanish's wrote English for an English reading it scored 0.92 against English's 0.91), so one whose text reads as
  another language drops out; Hindi's writes Hindi in Latin letters, which can't be read, so it stays; when every one wrote
  another language, the language spoken isn't among them and the guess stays. A language **picked unlike the script's** is most
  likely a slip (the take was read in the script's): the two are compared the same way, and the picker then shows the one
  heard. A take with a script on Auto is heard in the script's language straight away. Only the guess may download its model;
  another language is compared only when its model is on the iPhone. The languages compared keep their places among the
  system's five (`SpeechLocaleReservation`): room is made with the language used longest ago, never one being compared nor
  another variant of the one taking the place (zh-CN and zh-TW share a model), because the system's own pick released the
  language being judged and its model then read as not on the iPhone. Dictation doesn't rate its words reliably (no confidence on some results, measured on an iPad Pro
  A12Z), so a language only dictation hears (id, ar, tr, th, vi, nl, sv, da, nb on an iPhone; all of them on a device without
  `SpeechTranscriber`) is never judged: the take is heard in the guess, as before. The status line says "Finding the language
  you speak…" meanwhile.
- **Words:** `WordTokenizer` is the one tokenizer for the script, what Voice Following hears,
  caption transcription and Clean Up. Text with spaces splits at anything that isn't a letter or a
  number (English and Portuguese split exactly as before); Japanese, Chinese and Thai are split
  into dictionary words by `WordSegmenter` (Natural Language), told the language when it's known,
  with digits apart; caption words keep their punctuation ("。" still ends a line). Matching folds
  case, accents and width, Arabic alef/hamza forms, taa marbuta, alef maqsura, vowel marks and
  tatweel, and Hindi nukta and chandrabindu; Thai and Devanagari vowel signs are letters and stay.
  Numbers in digits are spelled out in the language (up to 9999: "3" matches "three", "três",
  "三"). Clean Up keeps accents (Portuguese "é" is a filler, "e" never is).
- **Scripts:** `Script.language` (nil = Auto-detect, read by `LanguageDetector`). The prompter reads
  a script in its own direction whatever the interface's (`ScriptDirection`). Translate creates a
  copy in the new language; the original is never changed. AI writing is told the language by its
  English name (`ScriptPromptBuilder.languageRule`).

Nothing here has a server, an API key or a cost per use: speech recognition, language detection and
word segmentation all run on the device with Apple's frameworks.

## 1.1 What a device does in each language (capabilities)

Six things depend on the language, and the device answers each on its own: **interface** (the String
Catalogs), **Apple Intelligence writing** (generation, rewriting, hooks, ideas, tagging, translating a
script), **dictation**, **Voice Following**, **captions** (and Clean Up) and **translating captions**. None implies another. On a
Mac with Apple Intelligence (macOS 27), `SystemLanguageModel.supportedLanguages` lists 24 locales and
leaves out four of Cue's languages: **Hindi, Indonesian, Arabic and Thai**; all four have speech
recognition. `LanguageCapabilityService` (`Managers/Language`) is the one place that asks, behind
`LanguageCapabilityChecking` (Apple's answers in `AppleLanguageCapabilityChecker`; tests give a list):

- an answer is **supported**, **not installed** (supported; the model downloads or finishes preparing) or
  **unavailable** with a cause (language not supported, device not supported, turned off, interface variant
  not translated: `FeatureSupport`);
- answers are kept, two screens asking at once share one question, "not installed" and "turned off" are
  asked again after 30 s, the rest only when the system version or the iPhone's languages change;
- nothing is ever downloaded to find out. A failed speech-model download isn't retried for 30 s
  (`DownloadCooldown`);
- one feature failing never turns another off: a language without Apple Intelligence still has its
  speech models, and a script in it can still be prompted from the teleprompter.

**Apple Intelligence** (`ScriptAIService`) asks `AIModelPlanner` before anything is sent, with every
language of the request (a translation needs the source *and* the target): the device model's own
`supportsLocale`, never the languages Cue's interface speaks. No model that doesn't write the languages is
tried or fallen back to (`AIPlan`). The failures are told apart: language not written (`unsupportedLanguage`,
or `unsupportedTranslation` naming the pair), model still preparing, device not eligible, Apple Intelligence
off, too long, cancelled (silent). A result that comes back in another language (a polish answered in
English, a translation handed back untouched) is refused and the script left as it was
(`OutputLanguageCheck`; only when the text is long enough and Natural Language is sure). Translating has no
default target. **What can't be drafted is told before anything is sent, and never by opening an empty draft**
(`DraftingAvailability`, `writer.drafting(in:)`): Cue's own On-device AI switch first, then the planner's order (device, Apple
Intelligence off, the language, model preparing). The language is the **script's**: the Script Language when one is set (the
Scripts dock then shows the reason in its note and its "Write it" state, and Language & Region marks the languages the model
doesn't write); on Auto-detect the idea's own, judged only when it is sent (never the interface language as a guess), and then
the idea stays in the field and a toast gives the reason with "Write it". An answered comment is read in the comment's language;
ideas (interface text) in the interface's, and a language the model doesn't write ideas in is never asked. `ScriptAIService`
still builds a format's structured draft when no model can take a `.format` request, but no screen sends one today (every
request from the app is a prompt). **Private Cloud Compute stays off**
(`hasPrivateCloudComputeEntitlement = false`): it is only a candidate when the app has the entitlement.

**No dashes in what the model writes** (§2.1). Every instruction (script, rewrite tools and hooks, block lengthening, ideas)
carries `ScriptPromptBuilder.punctuationRule`, and whatever still comes back goes through `DashRewriter`
(`Managers/ScriptAI/Cleaning/`) inside `ScriptPromptBuilder.clean` / `cleanTitle`, which see only model output, before the
language and voice checks: a dash between two parts becomes the language's comma, colon or full stop (connectors, a short head
before it, a list after it, two full clauses), a pair becomes commas, a line-leading mark or dialogue dash is dropped, a range
is said in words (`%1$@ to %2$@` in the text's language), a spaced ASCII " - " between words counts as a dash. Each language's
marks come from `DashPunctuation` (French space before the colon, 、/，/، /। where they belong, no capitals where the script has
none, Thai spaces). Never touched: hyphens in words, `5 - 3`, −, ー, 〜, links, handles, stage cues, and the creator's words the
model had to repeat (`ScriptRequest.preservedPhrases`: catchphrases, a brand's must-say line, link and code, the idea's opening
line; in a rewrite, every sentence of the creator's that holds a dash, so one the model kept word for word keeps it). Parts a
rewrite leaves as written never pass through it; a translation is cleaned in full. Drafts are not shown while they are
written (the page replays the finished, cleaned text); a screen that someday shows words as they arrive uses
`DashRewriter.displayable`, which holds back the sentence after a dash until it ends, so a dash never appears even for a
moment. Ideas saved by older versions are cleaned when restored; Logbook notes are the creator's and stay.

**Regional variants.** Only the 20 languages above have a translated interface; no variant gets one of its
own. Every interface localization is the language alone (`es`, `fr`, `pt`…), except the two Chinese scripts:
iOS prefers English over a localization whose region doesn't match, so with `pt-BR` an iPhone in pt-PT with
English second opened Cue in English. With `pt`, es-MX/es-419, fr-CA, de-AT, zh-HK, nn-NO, ar-EG and the rest
reach their language (`LocalizationCatalogTests.aRegionalVariantGetsItsLanguage`); Malay and other languages Cue
doesn't have fall back to English. The Portuguese text is Brazilian, and the App Store has its own pt-PT page.
A language the creator picked (Script Language, Voice Following Language) is used as picked, in Cue's
variant (pt-BR, zh-CN…). A language *read from the text* (Auto-detect) keeps the variant of the creator's own
language list (en-GB, pt-PT, es-MX: `CueLanguage.variant(among:)`) for dictation, Voice Following, captions
and the language AI writes in (`ScriptRequest.languageVariant`, asked of the model only when it writes that
variant); the device's country never decides. Chinese is two writing systems: detection, recognition, captions,
translation and the check of AI output all keep Simplified (`zh-Hans`) and Traditional (`zh-Hant`) apart, and a
Traditional script is never heard as Simplified.

**Listening** (`SpeechLocaleReservation`): the system lets an app hold five speech languages at once. Every way
of listening reserves the language it needs, and the oldest other one makes room (captions in a sixth language
used to fail after Voice Following had been used in five).

**To add a language:** add a `CueLanguage` case, add the language to the three String Catalogs and
to `knownRegions` in the project. Nothing else is structural.

## 2. Terminology

One translation per concept, everywhere (buttons, alerts, accessibility labels). Brand and feature
names in **bold** stay in English in every language.

- Brand, unchanged: **Cue**, **Cue Pro**, **Pro**, **Apple Intelligence**, **Private Cloud Compute**,
  **My Cue Voice**, **Selfie**, **Studio**, **TikTok**, **Reels**, **Shorts**, **YouTube**,
  **LinkedIn**, **Stories**, **Instagram**, **Lexend**, and the script page's ✦ **Shape** tool.
- One key, one meaning: a word that means two things gets two English keys (camera *Front* / *Rear* vs. the
  *Back* button; Quick edit's *Ratio* vs. ✦ *Shape*; the apology format's *Closing* section vs. the *Close* button;
  the share sheet's *Post caption* vs. the video's *Caption*), so each language can translate both. When the English must
  stay the same word on screen, the code asks for a key of its own with the English as default
  (`String(inInterfaceLanguage: LocalizedStringResource("step.next", defaultValue: "Next", comment: …))`) and the catalog gives
  that key an `en` value (`scripts/strings.py add` takes `"en"` for such a key). Split this way (22 Oct 2026):
  - **Format**: the video's frame (Quick edit, Recording setup, Script details) keeps `Format`; the script's format (Scripts
    dock chip, Format sheet) is `format.script`; a file format (HEVC | H.264, Image | video) is `format.file`.
  - **Voice**: the creator's writing voice (dock chip ✦ Voice, My Cue Voice) keeps `Voice`; the prompter's Voice | Steady switch
    (Voice Following) is `scrollMode.voice`.
  - **Quick**: Follow face's pace keeps `Quick`; the prompter's Aa sheet heading (quick settings) is `prompter.quickSettings`.
  - **Line**: the caption animation keeps `Line`; Studio's reading line chip and slider is `studio.readingLine`.
  - **Next**: the button keeps `Next`; the status of the step that comes next (first voyage, onboarding pill) is `step.next`;
    `Next: %@` is My Cue Voice's status heading and Cover studio's button is `coverStudio.next`.
- Voice: talk to one creator (pt-BR *você*, es *tú*, fr *vous*, de *du*, it *tu*, id *kamu*,
  tr *sen*, vi *bạn*, zh *你*, ar the singular, hi *आप*, nl *je*, sv *du*, da *du*, nb *du*; ja and ko
  polite and neutral), short sentences, no jargon.
- Two pairs never share a word, because they sit on the same screens: **Record / Save** (fr
  *Filmer* / *Enregistrer*, tr *Kayıt* / *Kaydet*, th *อัด* / *บันทึก*) and **Trim / Crop** (es
  *Recortar* / *Encuadrar*, pt-BR *Aparar* / *Recortar*, id *Pangkas Durasi* / *Pangkas Bingkai*, tr
  *Kısalt* / *Kırp*, vi *Cắt độ dài* / *Cắt khung*, ja *トリム* / *クロップ*, ar *تشذيب* / *اقتصاص*). Each word follows what the
  control does: Trim shortens a clip in time, Crop frames the picture, Split divides a clip in two, Cut removes (text, or
  words from the video) and "a cut" is the point between two clips (ar *قص* removes, *قطع* is the cut point, *تقسيم* splits;
  ja *カット* for both, *分割* splits; ja *トリミング* still reads right where a sentence means trimming text, and *切り抜き* is a
  cutout, not a crop).
- Terms the owner settled from the review (22 Oct 2026): de Voice Following is *Stimme folgen*, a verb phrase, so a
  sentence names it in quotes („Stimme folgen“ ist an) instead of using it as a noun; hi Settings is *सेटिंग्ज़*, Apple's
  spelling, everywhere the plural appears (the singular *सेटिंग* stays); es Color key is *Croma*.
- Arabic calls the hook *الافتتاحية* (the opening) and captions *الترجمة النصية*; *الخطّاف* reads as
  a literal fishing hook.
- Performance cues inside scripts are translated with the script text (`[pause]` → pt-BR
  `[pausa]`, ja `[間]`…) and always use ASCII brackets, so the prompter still recognizes them.
  The script editor's Cues panel (`ScriptCue`) offers the nine cues by those names, in the
  interface's language, and inserts them between ASCII brackets; the panel's own name is "Cues" /
  *Indicaciones* / *Marcações* / *Hinweise*…, never a word another tab already uses (pt-BR *Dicas*
  and tr *İpuçları* are Tips).
- **Draft** (what Cue's AI writes) is always the draft word, never "write" or "the script" (10 Oct 2026, the owner's
  message for the whole app: the creator creates and improves, Cue helps and gives the first pass): es *borrador /
  redactar*, pt-BR *rascunho / rascunhar*, fr *brouillon / rédiger*, de *Entwurf / entwerfen*, it *bozza*, ja *下書き*, ko
  *초안*, zh-Hans/zh-Hant *草稿 / 起草*, hi *ड्राफ़्ट*, id *draf*, ar *مسودة*, tr *taslak*, th *ฉบับร่าง / ร่าง*, vi *bản nháp
  / soạn nháp*, nl *concept*, sv/nb *utkast*, da *udkast*. These texts are kept as short as the English (German and French
  run about 30% longer), so each line still fits where it sits.
- "%@ to %@" is a countdown ("18s to 1:00", "12s to monetize"), not a range.
- Quick edit's Audio menu holds Studio Voice (the take's own speech, treated), Music and Voice-over, and a video over the
  take has its Sound.
- Type preset names (Cue, Impact, Editorial, Soft, Minimal, Label, Pop) are translated where the
  word has a natural equivalent; **Cue** stays as the brand.

**v27: five more languages** (Dutch `nl`, Swedish `sv`, Danish `da`, Norwegian Bokmål `nb`, Traditional
Chinese `zh-Hant`), for 20 in total. Terminology, in the same order: Take *opname / tagning / optagelse /
opptak / 鏡頭*, Script *script / manus / manuskript / manus / 腳本*, Captions *ondertitels / undertexter /
undertekster / undertekster / 字幕*, Settings *Instellingen / Inställningar / Indstillinger / Innstillinger /
設定*, Record *Opnemen / Spela in / Optag / Ta opp / 錄影*, Teleprompter *Teleprompter / Teleprompter /
Teleprompter / Teleprompter / 提詞機*, Hook stays *hook* in nl/sv/da/nb (zh-Hant 開場鉤子), Voice Following
*Stem volgen / Följ rösten / Følg stemmen / Følg stemmen / 跟隨語音*. Brand and feature names stay in
English as above. zh-Hant uses Taiwan wording (照片, 檔案, 儲存, 螢幕), not the zh-Hans glyph swap. None
of the five is right to left; Traditional Chinese is written without spaces (`WordSegmenter`).
Strings are translated by the model that built the app. In October 2026 every language had an AI review in a native
speaker's role (below); a human native review is still welcome before a public release.

| English | es | pt-BR | fr | de | it | ja | ko | zh-Hans | hi | id | ar | tr | th | vi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Teleprompter | Teleprompter | Teleprompter | Téléprompteur | Teleprompter | Teleprompter | プロンプター | 프롬프터 | 提词器 | टेलीप्रॉम्प्टर | Teleprompter | الملقّن | Teleprompter | เทเลพรอมป์เตอร์ | Teleprompter |
| Voice Following | Seguimiento de voz | Seguir voz | Suivi vocal | Stimme folgen | Segui voce | 音声追従 | 음성 따라가기 | 语音跟随 | आवाज़ ट्रैकिंग | Ikuti Suara | تتبّع الصوت | Ses Takibi | ติดตามเสียง | Theo giọng nói |
| Script | Guion | Roteiro | Script | Skript | Copione | 台本 | 대본 | 脚本 | स्क्रिप्ट | Naskah | النص | Senaryo | สคริปต์ | Kịch bản |
| Take | Toma | Take | Prise | Take | Ripresa | テイク | 테이크 | 镜头 | टेक | Take | اللقطة | Çekim | เทค | Cảnh quay |
| Record | Grabar | Gravar | Filmer | Aufnehmen | Registra | 録画 | 녹화 | 录制 | रिकॉर्ड | Rekam | تسجيل | Kayıt | อัด | Quay |
| Save | Guardar | Salvar | Enregistrer | Sichern | Salva | 保存 | 저장 | 存储 | सेव करें | Simpan | حفظ | Kaydet | บันทึก | Lưu |
| Quick edit | Edición rápida | Edição rápida | Montage rapide | Schnellschnitt | Modifica rapida | クイック編集 | 빠른 편집 | 快速剪辑 | क्विक एडिट | Edit cepat | تعديل سريع | Hızlı düzenleme | แก้ไขด่วน | Sửa nhanh |
| Trim | Recortar | Aparar | Raccourcir | Kürzen | Accorcia | トリム | 다듬기 | 修剪 | ट्रिम | Pangkas Durasi | التشذيب | Kısalt | ตัดความยาว | Cắt độ dài |
| Crop | Encuadrar | Recortar | Recadrer | Zuschneiden | Ritaglia | クロップ | 자르기 | 裁剪 | क्रॉप | Pangkas Bingkai | اقتصاص | Kırp | ครอบตัด | Cắt khung |
| Captions | Subtítulos | Legendas | Sous-titres | Untertitel | Sottotitoli | 字幕 | 자막 | 字幕 | कैप्शन | Teks | الترجمة النصية | Altyazılar | คำบรรยาย | Phụ đề |
| Free exports | Exportaciones gratis | Exportações grátis | Exports gratuits | Kostenlose Exporte | Esportazioni gratuite | 無料書き出し | 무료 내보내기 | 免费导出 | मुफ़्त एक्सपोर्ट | Ekspor gratis | عمليات تصدير مجانية | Ücretsiz dışa aktarma | การส่งออกฟรี | Lượt xuất miễn phí |
| Camera | Cámara | Câmera | Caméra | Kamera | Fotocamera | カメラ | 카메라 | 相机 | कैमरा | Kamera | الكاميرا | Kamera | กล้อง | Camera |
| Speed | Velocidad | Velocidade | Vitesse | Tempo | Velocità | 速度 | 속도 | 速度 | स्पीड | Kecepatan | السرعة | Hız | ความเร็ว | Tốc độ |
| Play | Reproducir | Reproduzir | Lire | Abspielen | Riproduci | 再生 | 재생 | 播放 | चलाएँ | Putar | تشغيل | Oynat | เล่น | Phát |
| Settings | Ajustes | Ajustes | Réglages | Einstellungen | Impostazioni | 設定 | 설정 | 设置 | सेटिंग्ज़ | Pengaturan | الإعدادات | Ayarlar | การตั้งค่า | Cài đặt |
| Profile | Perfil | Perfil | Profil | Profil | Profilo | プロフィール | 프로필 | 个人资料 | प्रोफ़ाइल | Profil | الملف الشخصي | Profil | โปรไฟล์ | Hồ sơ |
| Hook | Gancho | Gancho | Accroche | Hook | Gancio | フック | 훅 | 钩子 | हुक | Hook | الافتتاحية | Kanca | ฮุก | Hook |
| Clean Up | Limpieza | Limpeza | Nettoyage | Aufräumen | Pulizia | クリーンアップ | 정리 | 清理 | क्लीन अप | Bersihkan | تنظيف | Temizleme | เก็บกวาด | Dọn dẹp |
| Creator Setup | Configuración de creador | Configuração de criador | Réglages créateur | Creator-Setup | Configurazione creator | クリエイター設定 | 크리에이터 설정 | 创作者设置 | क्रिएटर सेटअप | Setelan Kreator | إعداد صانع المحتوى | İçerik Üretici Ayarları | การตั้งค่าครีเอเตอร์ | Thiết lập nhà sáng tạo |
| Safe zones | Zonas seguras | Zonas seguras | Zones sûres | Sichere Bereiche | Zone sicure | セーフゾーン | 세이프 존 | 安全区 | सेफ़ ज़ोन | Zona aman | المناطق الآمنة | Güvenli alanlar | พื้นที่ปลอดภัย | Vùng an toàn |
| Reading line | Línea de lectura | Linha de leitura | Ligne de lecture | Leselinie | Linea di lettura | 読み取りライン | 읽기 선 | 阅读线 | रीडिंग लाइन | Garis baca | خط القراءة | Okuma çizgisi | เส้นอ่าน | Đường đọc |
| Remote Control | Control remoto | Controle remoto | Télécommande | Fernbedienung | Telecomando | リモコン | 리모컨 | 遥控 | रिमोट कंट्रोल | Kendali Jarak Jauh | التحكم عن بُعد | Uzaktan Kumanda | รีโมตคอนโทรล | Điều khiển từ xa |
| Steady | Constante | Constante | Constant | Gleichmäßig | Costante | 一定速度 | 일정 속도 | 匀速 | स्थिर | Stabil | ثابت | Sabit | คงที่ | Đều |
| Keyframe | Fotograma clave | Quadro-chave | Image clé | Keyframe | Keyframe | キーフレーム | 키프레임 | 关键帧 | कीफ़्रेम | Keyframe | إطار رئيسي | Anahtar kare | คีย์เฟรม | Khung hình chính |
| Music | Música | Música | Musique | Musik | Musica | 音楽 | 음악 | 音乐 | म्यूज़िक | Musik | الموسيقى | Müzik | เพลง | Nhạc |
| Voice (the writing voice, My Cue Voice) | Voz | Voz | Voix | Stimme | Voce | ボイス | 보이스 | 口吻 | आवाज़ | Suara | الصوت | Ses | น้ำเสียง | Giọng văn |
| Background | Fondo | Fundo | Arrière-plan | Hintergrund | Sfondo | 背景 | 배경 | 背景 | बैकग्राउंड | Latar | الخلفية | Arka plan | พื้นหลัง | Nền |
| Color key | Croma | Chroma key | Incrustation | Farbschlüssel | Chroma key | カラーキー | 컬러 키 | 色键抠像 | कलर की | Kunci warna | مفتاح اللون | Renk anahtarı | คีย์สี | Tách màu nền |
| Draft | Borrador | Rascunho | Brouillon | Entwurf | Bozza | 下書き | 초안 | 草稿 | ड्राफ़्ट | Draf | مسودة | Taslak | ฉบับร่าง | Bản nháp |
| Language & Region | Idioma y región | Idioma e região | Langue et région | Sprache & Region | Lingua e area geografica | 言語と地域 | 언어 및 지역 | 语言与地区 | भाषा और क्षेत्र | Bahasa & Wilayah | اللغة والمنطقة | Dil ve Bölge | ภาษาและภูมิภาค | Ngôn ngữ & Vùng |

### 2.1 The October 2026 review

Each of the 19 languages was read in full (about 3,500 strings each) by an AI reviewer in the role of a demanding native
speaker who knows Apple's wording, with the code at hand for strings without a comment; 7,410 strings changed (between 6% and 17% per language,
most of them consistency and the rules below; true meaning errors were 1–2% per language). The
tool is `tools/l10n/review.py` (`export` one language, `check`, `apply` only that language's values); each language's
report, with the terms it settled on and the questions left for the owner, is in `tools/l10n/reports/2026-10-<lang>.md`.
Those term lists extend the table above. What the review taught, for every language and every new string:

- **A cue in brackets inside a template uses exactly the cue's own translated name** (`ScriptCueSymbol` recognizes a cue
  by it). The cue "beat" is a short pause in every language (es *pausa corta*, pt *pausa curta*, de *kurze Pause*…).
- **One key, one meaning.** A word with two uses gets two English keys (Front/Rear vs. Back; Ratio vs. ✦ Shape; Closing vs.
  Close; Post caption vs. Caption). Keys still shared and reported for a split: Fade, Fade in, Words, Mono, Pop,
  Reveal, Time, Keep mine, OFF.
- **Placeholders in another order are numbered** (`%2$@ … %1$lld`): unnumbered ones fill in order, and a number in a
  `%@` breaks the string. `LocalizationCatalogTests` fails on a translation that moves unnumbered placeholders of
  different kinds; two of the same kind (`%lld of %lld`) can't be checked by a test, so a reviewer looks.
- **The app never speaks as "I" or "we"**, and never says a video was posted. Buttons where Cue's AI writes (✦ Write,
  Draft my reply, Write the ad) use the draft word too.
- **No dashes, in any language** (owner, 22 Oct 2026, final): no em dash, en dash, horizontal bar, figure dash or their
  small and fullwidth forms, in the interface, notices, help, notifications, accessibility, the examples, templates and
  scripts Cue gives, and in everything Apple Intelligence writes. Each language rewrites with its own punctuation (a full
  stop, a comma, a colon, parentheses, " · " between two short facts), never a hyphen in the dash's place and never two words
  glued. A range is said in words: `DurationText.range` reads the key `%1$@ to %2$@` (pt *1:00 a 1:30*, de *1:00 bis 1:30*,
  ja *1:00〜1:30*, hi *1:00 से 1:30 तक*); "%@ to %@" stays the countdown. Hyphens inside words, the minus sign (−), Japanese ー
  and 〜, URLs and identifiers are other characters and stay. Text the creator wrote or imported is never changed for it.
  `LocalizationCatalogTests.noStringHasADash` fails on a dash in any of the 20 languages; the AI side is below (§1.1).
- **Feature names stay in English** like the brand: ✦ Smart, ✦ Shape, Selfie, Studio, My Cue Voice, Cue Voice, and the
  Clean caption collection. **My Cue Voice** stays a proper name.
- **Studio Voice is translated** (owner, 22 Oct 2026): it describes Quick edit's voice treatment (enhancement and noise
  reduction), so each language says what it is: pt *Voz de estúdio*, es *Voz de estudio*, fr *Voix studio*, de *Studio-Stimme*,
  it *Voce da studio*, ja *スタジオ音声*, ko *스튜디오 음성*, zh-Hans *录音棚人声*, zh-Hant *錄音室人聲*, hi *स्टूडियो आवाज़*, id
  *Suara Studio*, ar *صوت الاستوديو*, tr *Stüdyo Sesi*, th *เสียงสตูดิโอ*, vi *Giọng studio*, nl *Studiostem*, sv *Studioröst*, da/nb
  *Studiostemme*; sentences around it follow the word's grammar (hi *आवाज़* is feminine).
- **App icon names are translated** (owner, 22 Oct 2026): First Light, Deep Space, Constellation and Aurora are names the
  creator reads in Settings › Personalize and in the milestone that opens each one, so every language gives them a natural
  name (pt *Primeira Luz, Espaço Profundo, Constelação, Aurora*; es *Primera Luz, Espacio Profundo, Constelación, Aurora*;
  ja *最初の光, 深宇宙, 星座, オーロラ*…). Only the names shown change: `AppIconChoice`'s cases, the asset names and the
  milestones stay. A message that places the name next to the word "icon" puts it where a several-word name still reads
  (da *ikonet %@*, not *%@-ikonet*).
- **A language's name may already contain the word "language"** (vi *Tiếng Anh*): a template never adds it again.
- **Lines the creator says to camera** (templates, starters) avoid a gendered first person where the language marks it
  (hi), and address the audience the way creators do (fr *vous*); the interface keeps the register above (ko 해요체
  throughout, 합니다체 only in the system permission prompts).
- Languages Apple Intelligence doesn't write (id, th, hi, ar) are translated faithfully like the rest; the app explains
  before anything is drafted (§1.1).

## 3. Right to left and longer text

- Arabic: SwiftUI mirrors the layout from the environment (`layoutDirection`); directional SF
  Symbols (`chevron.forward`, `chevron.backward`) flip on their own, and nothing uses left/right
  where leading/trailing is meant. Media never mirrors: the Quick edit timelines, layer tracks and
  video run left to right, as time does. The prompter follows the script's direction, not the
  interface's.
- German, French and the other longer languages: labels wrap or shrink (`minimumScaleFactor`)
  instead of clipping; buttons keep their height and grow in width; chips flow (`FlowLayout`); fixed
  label widths are minimum widths.
- Japanese, Chinese and Thai have no spaces between words: word counts, reading time and Voice
  Following use `WordSegmenter` (Voice Following, captions and Clean Up through `WordTokenizer`).
- Arabic: the prompter reads the script right to left (`ScriptDirection`), and Voice Following
  matches it whatever the interface's direction; only the text's layout mirrors, never the reading
  guide, the timeline or the video.
- Counts: a string with a number that counts something ("3 lines deleted", "Found 1 pause") varies by plural in the String
  Catalog (Xcode's "Vary by Plural"; `scripts/strings.py add` takes the forms as an object: `{"one": …, "other": …}`, Arabic
  `zero`, `one`, `two`, `few`, `many`, `other`; one plain string for the languages with one form: Japanese, Korean, Chinese,
  Thai, Vietnamese, Indonesian). The code writes the count once (`String(localized: "\(count) lines deleted")`) and never
  rewrites a sentence or adds a "1 …" key to dodge the plural; a zero with words of its own ("No long pauses") stays a branch.
  Every form keeps the key's placeholders; with a second value (`%@`) the forms number them (`%1$lld`, `%2$@`).
  `PluralStringsTests` reads the editor's counts in the 20 languages. Strings with two counts ("2 of 3 recordings") are left
  without plural variations (they would need substitutions per argument).

## 4. Speech recognition by language

Asked of the device at runtime (`SpeechLocaleResolver`, `SpeechRecognitionManager.availability`),
never assumed. Language & Region shows, under each Voice Following language, whether it's ready on
this iPhone, downloads the first time, or isn't available. An unavailable language can still be
picked (an update or another iPhone may add it); the prompter then says so and scrolls at the set
speed while the creator talks, in that language's place, never in another one.

| Language | Locale | Recognizer (both on-device, Speech framework) | Measured on a Mac with Apple's models |
|---|---|---|---|
| English, Spanish, Portuguese (Brazil), French, German, Italian, Japanese, Korean, Chinese (Simplified) | en-US, es-ES, pt-BR, fr-FR, de-DE, it-IT, ja-JP, ko-KR, zh-CN | `SpeechTranscriber` (the original engine), else `DictationTranscriber` | 100% of the script followed |
| Indonesian, Arabic, Turkish, Thai, Vietnamese, Dutch, Swedish, Danish, Norwegian Bokmål | id-ID, ar-SA, tr-TR, th-TH, vi-VN, nl-NL, sv-SE, da-DK, nb-NO | `DictationTranscriber` (`SpeechTranscriber` didn't offer them on the test Mac or the iPhone) | 100% |
| Chinese (Traditional) | zh-TW | `SpeechTranscriber` | 100% (iPhone) |
| Hindi | hi-IN | `DictationTranscriber` first when the script is in Devanagari: `SpeechTranscriber` writes Hindi in Latin letters, which can't match the script | 100% (0% through `SpeechTranscriber`) |

**Dictating an idea** (the empty Scripts card) uses the same recognizers and the same table, in a
fourth, separate choice: the language the script will be written in (`LanguageService.dictationRequest`:
the Script Language, else the language of what is already typed there when it's three words or more,
else the interface's). Voice Following's language never takes part, and a language this iPhone can't
recognize is said ("Dictation can’t listen in Thai on this iPhone…"), never swapped for another; the
idea can always be typed. Writing without spaces (Japanese, Chinese, Thai) is joined without them.
What was said and what is written can differ only by the recognizer's own mistakes: Cue adds nothing,
and the text can be corrected before it is sent.

Which locales a given iPhone has depends on the model, the iOS version and Apple Intelligence
settings; the table is what the framework offers, and the app checks each time.

On an **iPhone 18 Pro Max (iOS 27)**, 30 Sep 2026 (`VoiceFollowingSpeechTests/availabilityOnThisDevice`,
nothing downloaded): English and Portuguese (Brazil) ready; the other 13 offered and downloaded
the first time they're used; none unavailable. `SpeechTranscriber` for en, es, pt-BR, fr, de, it,
ja, ko, zh-CN and hi (Hindi in Devanagari still goes to `DictationTranscriber` first, see above);
`DictationTranscriber` for id, ar, tr, th and vi. Word-by-word following, captions and latency were later
measured on an iPhone (iOS 27.0.1) in all 20 languages: section 5. The iOS Simulator
lists the dictation locales but can't run either recognizer (no audio format), so Voice Following
shows "This iPhone can't recognize speech" there; real recognition is tested on a device or on a
Mac.

Apple's Speech framework can't tell which language someone is speaking before recognizing it, so
Voice Following has no spoken "auto-detect": it listens in the chosen language, or in the script's
(detected from its text by `NLLanguageRecognizer` when the script is on Auto-detect).
The opt-in `VoiceFollowingSpeechTests` plays a recording of each language
(`Cue StudioTests/Fixtures/Speech/`) through the real recognizer and tracker
(`TEST_RUNNER_CUE_SPEECH_E2E=1`, on a device).

## 5. Evidence by language and feature (iPhone, iOS 27.0.1, 5 Oct 2026)

Run on a real iPhone with Apple's own models, one suite at a time and with the screen kept awake (the model is rate
limited in the background, and two speech suites at once compete for the five language places). Speech is
**synthesized** with Apple's system voices (`Fixtures/Speech`; nl, sv, da, nb and zh-TW were added in this pass: Xander,
Alva, Sara, Nora, Meijia): a technical reference that the recognizers and the timings work, not proof of quality with
every human accent. Everything below is measured; what isn't is under *Not validated*.

| Language | Voice Following: words reached · largest jump | Voice Following latency p50 / p95 (word → text) | Captions: script heard · timing | AI writing |
|---|---|---|---|---|
| en-US | 100% · 1 | 483 / 803 ms | 100% · measured | in language |
| es-ES | 100% · 1 | 407 / 701 ms | 100% · measured | in language |
| pt-BR | 100% · 2 | 330 / 686 ms | 100% · measured | in language |
| fr-FR | 100% · 1 | 489 / 789 ms | 100% · measured | in language |
| de-DE | 100% · 1 | 221 / 646 ms | 93% · measured | in language |
| it-IT | 100% · 1 | 486 / 774 ms | 100% · measured | in language |
| ja-JP | 100% · 2 | 499 / 829 ms | 92% (by letters) · measured | in language |
| ko-KR | 100% · 3 | 249 / 693 ms | 81% (96% by letters) · measured | in language |
| zh-CN | 100% · 1 | 463 / 715 ms | 100% · measured | in language |
| hi-IN | 100% · 5 | 106 / 949 ms | 61% (Hindi dictation drops words) · **estimated** (see below) | not written by the model |
| id-ID | 100% · 2 | 53 / 447 ms | 96% · measured | not written by the model |
| ar-SA | 100% · 2 | −273 / 367 ms¹ | 77% (96% by letters) · measured | not written by the model |
| tr-TR | 100% · 1 | −127 / 161 ms¹ | 95% · measured | in language |
| th-TH | 100% · 3 | 273 / 581 ms | 90% · partly estimated | not written by the model |
| vi-VN | 100% · 1 | 66 / 279 ms | 100% · partly estimated | in language |
| zh-TW | 100% · 2 | 475 / 702 ms | 97% · measured | in language |
| nl-NL | 100% · 1 | 266 / 455 ms | 100% · measured | in language |
| sv-SE | 100% · 2 | 367 / 559 ms | 100% · measured | in language |
| da-DK | 100% · 2 | 400 / 613 ms | 84% · partly estimated | in language |
| nb-NO | 100% · 2 | 301 / 466 ms | 94% · partly estimated | in language |

¹ A negative time means the text reached a word before the recognizer's own time for it ends: the lead
(`SpeechLead`) runs a little ahead of a word still being said. No language moved before speech began, none moved back,
and none ran more than 2 words ahead of the voice (`VoiceFollowingLatencyTests`). Since 15 Oct 2026 the text waits for the first word recognized
after play (`DESIGN_PROJECT.md` §35): measured again on an iPhone 18 Pro Max and an iPhone 15 Pro in all 20 languages, it never moved before speech,
and its first move came 0.85 s (Dutch) to 1.73 s (Turkish) after the voice began (English 1.0 s); word to text stayed as above.

Apple Intelligence ("AI writing"), 16 of Cue's 20 languages written by the on-device model; **Hindi, Indonesian, Arabic
and Thai are not** (`SystemLanguageModel.supportedLanguages`, 24 locales; the app's own check agreed with the model for
all 20). Those four are refused before any request, with a draft to write by hand; their speech features work.
Translation (pt-BR→en, en→de, ja→zh-TW, fr→es) came back in the target each time, and a pair with an unsupported
language is refused naming the pair. From the card, with "Write in my voice": title, body in the idea's language,
no markdown, and the catchphrase present, in en, pt-BR, es, fr, de, ja, zh-TW and nl.

**Found and fixed by this evidence**
- *Captions after Voice Following* failed in a sixth language ("Too many allocated locales, 5 maximum"): captions now reserve
  the language they need (`SpeechLocaleReservation`).
- *Hindi captions* were timed at about half their real moments by the dictation model (10 s of speech finished at 5 s):
  such times are spread over the spoken stretch and marked estimated (`TranscriptTimingCheck`). Spread words used to make a
  line each (an iPad's dictation, or a language picked unlike the one spoken); they now make lines like measured ones.
- *The language spoken* (iPhone 15 Pro, 20 Oct 2026, `SpokenLanguageDeviceTests`, each recording compared from a wrong first
  guess among pt-BR, en, es and its own): found in all 11 languages `SpeechTranscriber` hears (en, es, pt-BR, fr, de, it, ja,
  ko, zh-CN, zh-TW, hi), in 1.0–2.7 s; the language spoken scored 0.86 (hi) to 0.99, the others 0.00–0.75 (0.95 for English
  heard as Spanish, 0.89 for Italian heard as Spanish). The 9 dictation-only languages are not validated. Real takes in
  Portuguese: 0.96 against 0.16–0.68.
- *A Japanese idea written in English* (the creator's English catchphrase pulled the model): refused, then tried once more
  with the language stated firmly; the same for "In my voice". *Scripts a third of the length asked*: the minimum is now
  in the prompt (44 to 82 words before, 89 to 179 after, for 150 to 225 asked). *"Context size exceeded" on short requests*:
  retried once.
- *The iPhone 18 Pro Max's model* (a different model from the 15 Pro's) wrote every script in **English** with "Write in my
  voice" on (English voice instructions, an English catchphrase), in pt-BR, es and ja, even with the language stated in the
  instructions; the check refused them. The language is now also asked for in the request itself, and they come back in the
  language (pt-BR, es, de, ja, nl measured on the 15 Pro; pt-BR and es on the 18 Pro Max, the rest of that run was cut by the
  rate limit below).
- *Rate limit*: after a long run of scripts the model answers "rate limited" for a while. It is told as "needs a short break"
  (new string, 20 languages), never retried at once, never sent to another model.
- *A script that ran on* for 60 s and more before "context size exceeded": the answer is now bounded (three tokens a word of the
  longest script asked) and what had arrived is kept when there is enough of it (two blocks and half the words).
- *An empty answer* from the model, now and then, is retried once.
- *Off-script filler* ("so", "and", "the") put the text up to 47 words ahead of the reader in a simulated reading; common
  words now count for less (4 words, `VoiceFollowingRobustnessTests`).

### People's voices (FLEURS, iPhone 15 Pro, iOS 27, 24 Oct 2026)

The same suites, played four people's readings a language (two women, two men) from Google's FLEURS
(`Fixtures/Speech/Human`, `human-speech.json`, CC BY 4.0: Conneau et al., 2022) next to the system voice, on the same build
(`TEST_RUNNER_CUE_SPEECH_VOICE=both`). FLEURS is read speech with room noise, numbers and foreign names, not a creator talking
freely; es-ES is read by Latin American speakers, ar-SA by Egyptian ones, zh-TW by Mainland ones (transcripts converted to
Traditional characters). Captions are the share of the script heard (Korean, Japanese, Chinese and Thai by letters); latency is
the shipping settings, word to text.

| Language | Captions heard: system · people (worst) | Voice Following reached: system · people (worst) | Latency p50 / p95: system · people | Language spoken found: people |
|---|---|---|---|---|
| ar-SA | 77% · 82% (≥ 76%) | 100% · 95% (≥ 88%) | -275 / 347 ms · 71 / 450 ms | not judged (dictation) |
| da-DK | 84% · 96% (≥ 91%) | 100% · 100% (≥ 100%) | 389 / 601 ms · 176 / 514 ms | not judged (dictation) |
| de-DE | 93% · 91% (≥ 85%) | 100% · 100% (≥ 100%) | 212 / 623 ms · 302 / 598 ms | 4 of 4 |
| en-US | 100% · 94% (≥ 90%) | 100% · 100% (≥ 100%) | 475 / 797 ms · 383 / 676 ms | 4 of 4 |
| es-ES | 100% · 97% (≥ 95%) | 100% · 100% (≥ 100%) | 403 / 681 ms · 382 / 686 ms | 4 of 4 |
| fr-FR | 100% · 87% (≥ 80%) | 100% · 100% (≥ 100%) | 476 / 777 ms · 508 / 924 ms | 4 of 4 |
| hi-IN | 61% · 76% (≥ 70%) | 100% · 98% (≥ 92%) | 102 / 943 ms · -401 / 211 ms | 4 of 4 |
| id-ID | 96% · 96% (≥ 91%) | 100% · 100% (≥ 100%) | 60 / 433 ms · 129 / 600 ms | not judged (dictation) |
| it-IT | 100% · 99% (≥ 95%) | 100% · 100% (≥ 100%) | 484 / 777 ms · 381 / 609 ms | 4 of 4 |
| ja-JP | 92% · 100% (≥ 100%) | 100% · 100% (≥ 100%) | 479 / 808 ms · 598 / 1048 ms | 4 of 4 |
| ko-KR | 96% · 96% (≥ 92%) | 100% · 100% (≥ 100%) | 228 / 676 ms · -260 / 432 ms | 4 of 4 |
| nb-NO | 94% · 92% (≥ 84%) | 100% · 98% (≥ 92%) | 281 / 462 ms · 241 / 434 ms | not judged (dictation) |
| nl-NL | 100% · 90% (≥ 80%) | 100% · 100% (≥ 100%) | 261 / 434 ms · 248 / 564 ms | not judged (dictation) |
| pt-BR | 100% · 91% (≥ 83%) | 100% · 100% (≥ 100%) | 327 / 665 ms · 324 / 638 ms | 4 of 4 |
| sv-SE | 100% · 93% (≥ 87%) | 100% · 100% (≥ 100%) | 350 / 541 ms · -68 / 356 ms | not judged (dictation) |
| th-TH | 90% · 96% (≥ 94%) | 100% · 100% (≥ 100%) | 284 / 564 ms · 197 / 504 ms | not judged (dictation) |
| tr-TR | 95% · 91% (≥ 78%) | 100% · 100% (≥ 100%) | -26 / 309 ms · 157 / 990 ms | not judged (dictation) |
| vi-VN | 100% · 95% (≥ 82%) | 100% · 100% (≥ 100%) | 54 / 279 ms · 320 / 517 ms | not judged (dictation) |
| zh-CN | 100% · 88% (≥ 73%) | 100% · 99% (≥ 95%) | 446 / 692 ms · 537 / 986 ms | 4 of 4 |
| zh-TW | 97% · 95% (≥ 90%) | 100% · 100% (≥ 100%) | 476 / 689 ms · 593 / 892 ms | 4 of 4 |

- **Sync** (captions): no caption starts before the voice or ends after it in any of the 80 readings; the first word sits within
  0.25 s of the voice in 75. The other five start later than the loudness reference only because the reading opens with noise
  or a click as loud as speech (two Japanese, two Turkish: the reference fails there, not the captions) or a breath (one
  Norwegian, 0.36 s).
- **Found and fixed by these voices** (all in the app, measured again after): a room's hiss at −40 dBFS was taken for speech, so
  measured times were spread over it and lost (English) and estimated ones started 2 s before anyone spoke (Hindi, Turkish,
  Vietnamese); Korean's first word ran back to 0.00 s, up to 2.4 s before the voice (`TranscriptTimingCheck`). The spoken
  language: German, then Traditional Chinese, were never judged (the system released the language being compared to make room;
  `SpeechLocaleReservation`), and an English reading was taken for Spanish (0.92 against 0.91) until the recognizers' own
  writing counted (`SpokenLanguageIdentifier`): 55 of 55 found, from 50. Edit by text: a word beside the cut was lost in natural
  speech, where the recognizer gives touching words one shared edge; edges now move to the pause between them
  (`WordBoundaries`): English 5 of 5 clean.
- **Known limits**: Portuguese read by people: Edit by text clips the first sound of the word after the cut in every reading
  (its word edges are up to ~150 ms off, "maneira" timed 0.18 s); a known issue in `EditByTextDeviceTests`. Voice Following's
  first move waits for the first recognized word: 0.9–2.6 s after the voice with people (4.5 s on one Turkish reading opening
  with a name; dictation is slower to its first word). One Arabic reading was followed to 62% in real time (its last words
  came late from dictation; 88% given time). The speaking indicator lit on breaths before the voice in a few readings; the text
  never moved before it.

**Not validated** (do not read the table as "20 languages fully validated")
- The iPhone 18 Pro Max (iOS 27.0): only its availability list (en, es, pt-BR ready; 17 download on first use; none unavailable) and
  Apple Intelligence writing (the same 16 languages written, the same 4 refused) were run; its Voice Following, captions and latency
  runs were cut because the phone locked, and the rest of its Apple Intelligence run by the model's rate limit.
- Quality of the generated text to a native speaker, and the voice's fidelity: only language, structure and length are measured.
- Spontaneous speech, music under the voice and long readings: people's readings (FLEURS) are read sentences of 6–16 s;
  added noise is measured in English only.
- Hindi recognition (61%) and Arabic by words (77%) are the models' own limits; they follow the script, but the text they hear
  is rough.
- Apple Intelligence on other iPhones and OS versions, and Private Cloud Compute (off: no entitlement).
- The interface translations are still by the model that built them, awaiting native review (28 App Shortcuts phrases
  are flagged `needs_review`).

