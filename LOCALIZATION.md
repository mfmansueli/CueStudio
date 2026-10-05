# Cue Studio — Languages

Video caption collection: Cue / Impact / Clean / Pop / Editorial (`CaptionTheme`); Brazilian
Portuguese uses **Impacto**, and **Clean** is the collection's proper name in every interface.
The existing text presets and general "Clean" translation are unchanged. Caption settings use
the same 20-language catalog. Bundled font licenses and local glyph fallbacks are documented in
`Cue Studio/DesignSystem/Fonts/CAPTION-FONTS.md`; RTL shaping is preserved in the shared renderer.

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
localization (`pt-BR`, `zh-Hans`…), native and localized names, English name (for AI instructions),
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
default target. A free prompt in a language the model doesn't write opens a blank draft with the reason, the way it
does without Apple Intelligence; a format still gets its structured draft. **Private Cloud Compute stays off**
(`hasPrivateCloudComputeEntitlement = false`): it is only a candidate when the app has the entitlement.

**Regional variants.** Only the 20 languages above have a translated interface; no variant gets one of its
own. A language the creator picked (Script Language, Voice Following Language) is used as picked, in Cue's
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
  **LinkedIn**, **Stories**, **Instagram**, **Lexend**.
- Voice: talk to one creator (pt-BR *você*, es *tú*, fr *vous*, de *du*, it *tu*, id *kamu*,
  tr *sen*, vi *bạn*, zh *你*, ar the singular, hi *आप*, nl *je*, sv *du*, da *du*, nb *du*; ja and ko
  polite and neutral), short sentences, no jargon.
- Two pairs never share a word, because they sit on the same screens: **Record / Save** (fr
  *Filmer* / *Enregistrer*, tr *Kayıt* / *Kaydet*, th *อัด* / *บันทึก*) and **Trim / Crop** (es
  *Recortar* / *Encuadrar*, pt-BR *Aparar* / *Recortar*, id *Pangkas Durasi* / *Pangkas Bingkai*, tr
  *Kısalt* / *Kırp*, vi *Cắt độ dài* / *Cắt khung*).
- Arabic calls the hook *الافتتاحية* (the opening) and captions *الترجمة النصية*; *الخطّاف* reads as
  a literal fishing hook.
- Performance cues inside scripts are translated with the script text (`[pause]` → pt-BR
  `[pausa]`, ja `[間]`…) and always use ASCII brackets, so the prompter still recognizes them.
  The script editor's Cues panel (`ScriptCue`) offers the nine cues by those names, in the
  interface's language, and inserts them between ASCII brackets; the panel's own name is "Cues" /
  *Indicaciones* / *Marcações* / *Hinweise*…, never a word another tab already uses (pt-BR *Dicas*
  and tr *İpuçları* are Tips).
- "%@ to %@" is a countdown ("18s to 1:00", "12s to monetize"), not a range.
- Quick edit's Audio category holds Voice (the take's own speech), Music and Voice-over, and a
  video over the take has its Sound: where a language has one word for all of them (ar *الصوت*, tr
  *Ses*), the Voice tool uses the word for speech (ar *الكلام*, tr *Konuşma*) so the tool never
  repeats its category's name.
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
Strings are translated by the model that built the app and marked for review by a native speaker
before a public release.

| English | es | pt-BR | fr | de | it | ja | ko | zh-Hans | hi | id | ar | tr | th | vi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Teleprompter | Teleprompter | Teleprompter | Téléprompteur | Teleprompter | Teleprompter | プロンプター | 프롬프터 | 提词器 | टेलीप्रॉम्प्टर | Teleprompter | الملقّن | Teleprompter | เทเลพรอมป์เตอร์ | Teleprompter |
| Voice Following | Seguimiento de voz | Seguir voz | Suivi vocal | Sprachfolge | Segui voce | 音声追従 | 음성 따라가기 | 语音跟随 | आवाज़ ट्रैकिंग | Ikuti Suara | تتبّع الصوت | Ses Takibi | ติดตามเสียง | Theo giọng nói |
| Script | Guion | Roteiro | Script | Skript | Copione | 台本 | 대본 | 脚本 | स्क्रिप्ट | Naskah | النص | Senaryo | สคริปต์ | Kịch bản |
| Take | Toma | Take | Prise | Take | Ripresa | テイク | 테이크 | 镜头 | टेक | Take | اللقطة | Çekim | เทค | Cảnh quay |
| Record | Grabar | Gravar | Filmer | Aufnehmen | Registra | 録画 | 녹화 | 录制 | रिकॉर्ड | Rekam | تسجيل | Kayıt | อัด | Quay |
| Save | Guardar | Salvar | Enregistrer | Sichern | Salva | 保存 | 저장 | 存储 | सेव करें | Simpan | حفظ | Kaydet | บันทึก | Lưu |
| Quick edit | Edición rápida | Edição rápida | Montage rapide | Schnellschnitt | Modifica rapida | クイック編集 | 빠른 편집 | 快速剪辑 | क्विक एडिट | Edit cepat | تعديل سريع | Hızlı düzenleme | แก้ไขด่วน | Sửa nhanh |
| Trim | Recortar | Aparar | Raccourcir | Kürzen | Accorcia | トリミング | 다듬기 | 修剪 | ट्रिम | Pangkas Durasi | التشذيب | Kısalt | ตัดความยาว | Cắt độ dài |
| Crop | Encuadrar | Recortar | Recadrer | Zuschneiden | Ritaglia | 切り取り | 자르기 | 裁剪 | क्रॉप | Pangkas Bingkai | قص | Kırp | ครอบตัด | Cắt khung |
| Captions | Subtítulos | Legendas | Sous-titres | Untertitel | Sottotitoli | 字幕 | 자막 | 字幕 | कैप्शन | Teks | الترجمة النصية | Altyazılar | คำบรรยาย | Phụ đề |
| Free exports | Exportaciones gratis | Exportações grátis | Exports gratuits | Kostenlose Exporte | Esportazioni gratuite | 無料書き出し | 무료 내보내기 | 免费导出 | मुफ़्त एक्सपोर्ट | Ekspor gratis | عمليات تصدير مجانية | Ücretsiz dışa aktarma | การส่งออกฟรี | Lượt xuất miễn phí |
| Camera | Cámara | Câmera | Caméra | Kamera | Fotocamera | カメラ | 카메라 | 相机 | कैमरा | Kamera | الكاميرا | Kamera | กล้อง | Camera |
| Speed | Velocidad | Velocidade | Vitesse | Tempo | Velocità | 速度 | 속도 | 速度 | स्पीड | Kecepatan | السرعة | Hız | ความเร็ว | Tốc độ |
| Play | Reproducir | Reproduzir | Lire | Abspielen | Riproduci | 再生 | 재생 | 播放 | चलाएँ | Putar | تشغيل | Oynat | เล่น | Phát |
| Settings | Ajustes | Ajustes | Réglages | Einstellungen | Impostazioni | 設定 | 설정 | 设置 | सेटिंग्स | Pengaturan | الإعدادات | Ayarlar | การตั้งค่า | Cài đặt |
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
| Voice (Quick edit tool) | Voz | Voz | Voix | Stimme | Voce | 声 | 목소리 | 人声 | आवाज़ | Suara | الكلام | Konuşma | เสียงพูด | Giọng nói |
| Background | Fondo | Fundo | Arrière-plan | Hintergrund | Sfondo | 背景 | 배경 | 背景 | बैकग्राउंड | Latar | الخلفية | Arka plan | พื้นหลัง | Nền |
| Color key | Clave de color | Chroma key | Incrustation | Farbschlüssel | Chroma key | カラーキー | 컬러 키 | 色键抠像 | कलर की | Kunci warna | مفتاح اللون | Renk anahtarı | คีย์สี | Tách màu nền |
| Language & Region | Idioma y región | Idioma e região | Langue et région | Sprache & Region | Lingua e area geografica | 言語と地域 | 언어 및 지역 | 语言与地区 | भाषा और क्षेत्र | Bahasa & Wilayah | اللغة والمنطقة | Dil ve Bölge | ภาษาและภูมิภาค | Ngôn ngữ & Vùng |

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
and none ran more than 2 words ahead of the voice (`VoiceFollowingLatencyTests`).

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
  such times are spread over the spoken stretch and marked estimated (`TranscriptTimingCheck`).
- *A Japanese idea written in English* (the creator's English catchphrase pulled the model): refused, then tried once more
  with the language stated firmly; the same for "In my voice". *Scripts a third of the length asked*: the minimum is now
  in the prompt (44 to 82 words before, 89 to 179 after, for 150 to 225 asked). *"Context size exceeded" on short requests*:
  retried once.
- *Off-script filler* ("so", "and", "the") put the text up to 47 words ahead of the reader in a simulated reading; common
  words now count for less (4 words, `VoiceFollowingRobustnessTests`).

**Not validated** (do not read the table as "20 languages fully validated")
- Quality of the generated text to a native speaker, and the voice's fidelity: only language, structure and length are measured.
- Real human speech and accents, background noise in languages other than English, and long readings: fixtures are
  10 s of synthetic speech; the noise run is English only.
- Hindi recognition (61%) and Arabic by words (77%) are the models' own limits; they follow the script, but the text they hear
  is rough.
- Apple Intelligence on other iPhones and OS versions, and Private Cloud Compute (off: no entitlement).
- The interface translations are still by the model that built them, awaiting native review (28 App Shortcuts phrases
  are flagged `needs_review`).

