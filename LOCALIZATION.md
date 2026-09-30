# Cue Studio — Languages

Video caption collection: Cue / Impact / Clean / Pop / Editorial (`CaptionTheme`); Brazilian
Portuguese uses **Impacto**, and **Clean** is the collection's proper name in every interface.
The existing text presets and general "Clean" translation are unchanged. Caption settings use
the same 15-language catalog. Bundled font licenses and local glyph fallbacks are documented in
`Cue Studio/DesignSystem/Fonts/CAPTION-FONTS.md`; RTL shaping is preserved in the shared renderer.

How Cue handles languages: the architecture, the terminology every translation follows, and what
right to left and longer languages need. Read with `ARCHITECTURE.md` (strings are always localized)
and `DESIGN_PROJECT.md` (Language & Region screen).

## 1. Three languages, kept apart

Cue has three language settings (Profile › Settings › Language & Region) and none follows another:

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
  lives in `PresentationService` (`profilePath`), so the creator stays on Language & Region.
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

**To add a language:** add a `CueLanguage` case, add the language to the three String Catalogs and
to `knownRegions` in the project. Nothing else is structural.

## 2. Terminology

One translation per concept, everywhere (buttons, alerts, accessibility labels). Brand and feature
names in **bold** stay in English in every language.

- Brand, unchanged: **Cue**, **Cue Pro**, **Pro**, **Apple Intelligence**, **Private Cloud Compute**,
  **Creator Voice**, **Selfie**, **Studio**, **TikTok**, **Reels**, **Shorts**, **YouTube**,
  **LinkedIn**, **Stories**, **Instagram**, **Lexend**.
- Voice: talk to one creator (pt-BR *você*, es *tú*, fr *vous*, de *du*, it *tu*, id *kamu*,
  tr *sen*, vi *bạn*, zh *你*, ar the singular, hi *आप*; ja and ko polite and neutral), short
  sentences, no jargon.
- Two pairs never share a word, because they sit on the same screens: **Record / Save** (fr
  *Filmer* / *Enregistrer*, tr *Kayıt* / *Kaydet*, th *อัด* / *บันทึก*) and **Trim / Crop** (es
  *Recortar* / *Encuadrar*, pt-BR *Aparar* / *Recortar*, id *Pangkas Durasi* / *Pangkas Bingkai*, tr
  *Kısalt* / *Kırp*, vi *Cắt độ dài* / *Cắt khung*).
- Arabic calls the hook *الافتتاحية* (the opening) and captions *الترجمة النصية*; *الخطّاف* reads as
  a literal fishing hook.
- Performance cues inside scripts are translated with the script text (`[pause]` → pt-BR
  `[pausa]`, ja `[間]`…) and always use ASCII brackets, so the prompter still recognizes them.
- "%@ to %@" is a countdown ("18s to 1:00", "12s to monetize"), not a range.
- Quick edit's Audio category holds Voice (the take's own speech), Music and Voice-over, and a
  video over the take has its Sound: where a language has one word for all of them (ar *الصوت*, tr
  *Ses*), the Voice tool uses the word for speech (ar *الكلام*, tr *Konuşma*) so the tool never
  repeats its category's name.
- Type preset names (Cue, Impact, Editorial, Soft, Minimal, Label, Pop) are translated where the
  word has a natural equivalent; **Cue** stays as the brand.

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
| Indonesian, Arabic, Turkish, Thai, Vietnamese | id-ID, ar-SA, tr-TR, th-TH, vi-VN | `DictationTranscriber` (`SpeechTranscriber` didn't offer them on the test Mac) | 100% |
| Hindi | hi-IN | `DictationTranscriber` first when the script is in Devanagari: `SpeechTranscriber` writes Hindi in Latin letters, which can't match the script | 100% (0% through `SpeechTranscriber`) |

Which locales a given iPhone has depends on the model, the iOS version and Apple Intelligence
settings; the table is what the framework offers, and the app checks each time.

On an **iPhone 18 Pro Max (iOS 27)**, 30 Sep 2026 (`VoiceFollowingSpeechTests/availabilityOnThisDevice`,
nothing downloaded): English and Portuguese (Brazil) ready; the other 13 offered and downloaded
the first time they're used; none unavailable. `SpeechTranscriber` for en, es, pt-BR, fr, de, it,
ja, ko, zh-CN and hi (Hindi in Devanagari still goes to `DictationTranscriber` first, see above);
`DictationTranscriber` for id, ar, tr, th and vi. Word-by-word following was measured on that
iPhone in English and Portuguese only (`VoiceFollowingLatencyTests`); Japanese, Chinese and Thai
are covered by the recordings on a Mac and by the tokenizer tests with partial results cut
mid-word (`MultilingualVoiceFollowTests`), not yet by a reading on a device, so they shouldn't be
advertised as fully supported until that runs (`TEST_RUNNER_CUE_SPEECH_E2E=1`, downloads each
model). The iOS Simulator
lists the dictation locales but can't run either recognizer (no audio format), so Voice Following
shows "This iPhone can't recognize speech" there; real recognition is tested on a device or on a
Mac.

Apple's Speech framework can't tell which language someone is speaking before recognizing it, so
Voice Following has no spoken "auto-detect": it listens in the chosen language, or in the script's
(detected from its text by `NLLanguageRecognizer` when the script is on Auto-detect).
The opt-in `VoiceFollowingSpeechTests` plays a recording of each language
(`Cue StudioTests/Fixtures/Speech/`) through the real recognizer and tracker
(`TEST_RUNNER_CUE_SPEECH_E2E=1`, on a device).
