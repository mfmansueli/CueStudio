# Cue Studio — Localization

How Cue handles languages, and the terminology every translation follows. Update it with the
String Catalog (`Cue Studio/SupportFiles/Localizable.xcstrings`).

## 1. Three independent languages

| Setting | Where | Stored in | Changes |
|---------|-------|-----------|---------|
| **App Language** | Profile › Settings › Language & Region | `LanguageSettingsService.appLanguage` (`appLanguage` + the system's `AppleLanguages` for Cue) | Only Cue's interface |
| **Voice Following Language** | same screen | `LanguageSettingsService.voiceFollowingLanguage` ("Same as script" or a language) | Only what Voice Following listens for |
| **Script Language** | same screen (default for new scripts) and each script's More › Language | `LanguageSettingsService.scriptLanguage`, `Script.language` | Only which language a script is marked as |

None of them writes another. Changing any of them never translates a script, never changes the
iPhone's language and never changes an existing project. Every language is a `CueLanguage`
(`Models/CueLanguage.swift`): identifier, native and localized names, locale (`pt-BR`, `zh-CN`…),
interface localization (`pt-BR`, `zh-Hans`…), direction.

- **Interface:** String Catalog + `String(localized:)` / `LocalizedStringKey`. The choice goes to the
  system's per-app language list (`AppleLanguages`, the same list Settings › Cue › Language edits), so
  every later launch is natively in that language (formats, right-to-left, permission prompts), and
  `LocalizedBundle` + the SwiftUI `locale`/`layoutDirection` environment switch the running app at once
  (`RootView` rebuilds the interface; navigation lives in `PresentationService`, so the screen stays).
- **Voice Following:** `SpeechLanguageRequest` → `SpeechLocaleResolver` → Apple's on-device
  `SpeechTranscriber` (the original engine), or `DictationTranscriber` from the same framework for
  languages `SpeechTranscriber` doesn't cover on the device. Availability is always asked of the
  device (`AssetInventory`); an unavailable language says so and is never swapped for another one.
- **Scripts:** `Script.language` (nil = Auto-detect). Arabic scripts read right to left in the
  prompter whatever the interface language (`ScriptDirection`).

To add a language: add a `CueLanguage` case, add it to the String Catalogs
(`Localizable`, `InfoPlist`, `AppShortcuts`) and to `knownRegions`. Nothing else is structural.

## 2. Terminology

One translation per concept, everywhere (buttons, alerts, accessibility labels). Brand and feature
names in **bold** stay in English in every language.

- Brand, unchanged: **Cue**, **Cue Pro**, **Pro**, **Apple Intelligence**, **Private Cloud Compute**,
  **Creator Voice**, **Selfie**, **Studio**, **TikTok**, **Reels**, **Shorts**, **YouTube**,
  **LinkedIn**, **Stories**, **Instagram**, **Lexend**.
- Voice: talk to one creator (informal "you": pt-BR *você*, es *tú*, fr *vous*, de *du*, it *tu*),
  short sentences, no jargon.

| English | es | pt-BR | fr | de | it | ja | ko | zh-Hans | hi | id | ar | tr | th | vi |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Teleprompter | teleprompter | teleprompter | téléprompteur | Teleprompter | teleprompter | プロンプター | 프롬프터 | 提词器 | टेलीप्रॉम्प्टर | teleprompter | الملقّن | teleprompter | เทเลพรอมป์เตอร์ | máy nhắc chữ |
| Voice Following | Seguimiento de voz | Seguir voz | Suivi vocal | Sprachfolge | Segui voce | 音声追従 | 음성 따라가기 | 语音跟随 | आवाज़ ट्रैकिंग | Ikuti Suara | تتبّع الصوت | Ses Takibi | ติดตามเสียง | Theo giọng nói |
| Script | guion | roteiro | script | Skript | copione | 台本 | 대본 | 脚本 | स्क्रिप्ट | naskah | النص | senaryo | สคริปต์ | kịch bản |
| Take | toma | take | prise | Take | ripresa | テイク | 테이크 | 镜头 | टेक | take | لقطة | çekim | เทค | bản quay |
| Record | Grabar | Gravar | Enregistrer | Aufnehmen | Registra | 録画 | 녹화 | 录制 | रिकॉर्ड | Rekam | تسجيل | Kaydet | อัด | Quay |
| Quick edit | Edición rápida | Edição rápida | Montage rapide | Schnellschnitt | Modifica rapida | クイック編集 | 빠른 편집 | 快速剪辑 | क्विक एडिट | Edit cepat | تعديل سريع | Hızlı düzenleme | แก้ไขด่วน | Chỉnh sửa nhanh |
| Captions | subtítulos | legendas | sous-titres | Untertitel | sottotitoli | 字幕 | 자막 | 字幕 | कैप्शन | teks | الترجمة | altyazı | คำบรรยาย | phụ đề |
| Export | exportar | exportar | exporter | exportieren | esportare | 書き出す | 내보내기 | 导出 | एक्सपोर्ट | ekspor | تصدير | dışa aktarma | ส่งออก | xuất |
| Camera | cámara | câmera | caméra | Kamera | fotocamera | カメラ | 카메라 | 相机 | कैमरा | kamera | الكاميرا | kamera | กล้อง | camera |
| Speed | velocidad | velocidade | vitesse | Tempo | velocità | 速度 | 속도 | 速度 | स्पीड | kecepatan | السرعة | hız | ความเร็ว | tốc độ |
| Playback / Play | reproducir | reproduzir | lire | abspielen | riproduci | 再生 | 재생 | 播放 | चलाएँ | putar | تشغيل | oynat | เล่น | phát |
| Settings | Ajustes | Ajustes | Réglages | Einstellungen | Impostazioni | 設定 | 설정 | 设置 | सेटिंग्स | Pengaturan | الإعدادات | Ayarlar | การตั้งค่า | Cài đặt |
| Profile | Perfil | Perfil | Profil | Profil | Profilo | プロフィール | 프로필 | 个人资料 | प्रोफ़ाइल | Profil | الملف الشخصي | Profil | โปรไฟล์ | Hồ sơ |
| Hook | gancho | gancho | accroche | Hook | gancio | フック | 훅 | 钩子 | हुक | hook | الخطّاف | kanca | ฮุก | câu mồi |
| Clean Up | Limpieza | Limpeza | Nettoyage | Aufräumen | Pulizia | クリーンアップ | 정리 | 清理 | क्लीन अप | Bersihkan | تنظيف | Temizleme | เก็บกวาด | Dọn dẹp |
| Creator Setup | Configuración de creador | Configuração de criador | Réglages créateur | Creator-Setup | Configurazione creator | クリエイター設定 | 크리에이터 설정 | 创作者设置 | क्रिएटर सेटअप | Setelan Kreator | إعداد صانع المحتوى | Üretici Ayarları | การตั้งค่าครีเอเตอร์ | Thiết lập nhà sáng tạo |
| Safe zone | zona segura | zona segura | zone sûre | sicherer Bereich | zona sicura | セーフゾーン | 세이프 존 | 安全区 | सेफ़ ज़ोन | zona aman | المنطقة الآمنة | güvenli alan | พื้นที่ปลอดภัย | vùng an toàn |
| Reading line | línea de lectura | linha de leitura | ligne de lecture | Leselinie | linea di lettura | 読み取りライン | 읽기 선 | 阅读线 | रीडिंग लाइन | garis baca | خط القراءة | okuma çizgisi | เส้นอ่าน | vạch đọc |
| Remote Control | Control remoto | Controle remoto | Télécommande | Fernbedienung | Telecomando | リモコン | 리모컨 | 遥控 | रिमोट कंट्रोल | Kendali Jarak Jauh | التحكم عن بُعد | Uzaktan Kumanda | รีโมต | Điều khiển từ xa |
| Steady (scroll) | Constante | Constante | Constant | Gleichmäßig | Costante | 一定速度 | 일정 속도 | 匀速 | स्थिर | Stabil | ثابت | Sabit | คงที่ | Đều |
| Free exports | exportaciones gratis | exportações grátis | exports gratuits | kostenlose Exporte | esportazioni gratuite | 無料書き出し | 무료 내보내기 | 免费导出 | मुफ़्त एक्सपोर्ट | ekspor gratis | عمليات تصدير مجانية | ücretsiz dışa aktarma | การส่งออกฟรี | lượt xuất miễn phí |

## 3. Right to left and longer text

- Arabic: SwiftUI mirrors the layout from the environment (`layoutDirection`); directional SF Symbols
  (`chevron.backward`, `arrow.*`) flip on their own, and nothing uses left/right where leading/trailing
  is meant. Media (the timeline, the video, the reading guide) never mirrors: time runs left to right.
- German, French and the other longer languages: labels wrap or shrink (`minimumScaleFactor`) instead
  of clipping; buttons keep their height and grow in width; chips flow (`FlowLayout`).
