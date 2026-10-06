# HANDOFF · telas novas de hoje (estado final)

> **Formato das telas:** cada tela é um arquivo HTML em `screens/` com o nome indicado nas listas "Prints:" abaixo (use a extensão `.html`; ex.: `9.2_live-2026.html`). Onde o texto diz "PNG" ou "print", leia "HTML". O movimento está em `ANIMACOES.md` e `motion/screens-motion.json`. `INDEX-TELAS.md` diz como chegar em cada tela; `INDEX.html` mostra todas.

Fonte: `design/cue-v30/prototype/Cue App v30.dc.html`. Em conflito, `09-Decisions.md` vence. Fora do pacote: modo claro / Golden Hour e Studio (5.3).
Dados: painel APP DATA (Sample / New year / New account) e FREE EXPORTS (3 left / Last one / None left).

Regra geral de componentes (07-Liquid-Glass): `NavigationStack` + toolbar, back do sistema, `Button(role: .close)` para fechar sheets, `.buttonStyle(.glassProminent).tint(.cueYellow)` para a ação principal, `.glass` para a secundária, `.sheet` + `presentationDetents`, `Menu`/`Picker`/`.contextMenu`, `.searchable`. Cards de conteúdo são translúcidos (não são vidro). Vidro simulado só quando não existe nativo.
Reduzir Movimento / Low Power: estado final, sem loops (09 §7).

## 1. Settings (11.1) · `List` `.insetGrouped` + `.searchable`
Chegada: aba Settings. Prints: `11.1_root`, `_search-result`, `_search-empty`, `_recording`, `_microphone`, `_prompter`, `_font`, `_safe-zone`, `_remote`, `_personalize`, `_app-icon`, `_language-region`, `_privacy-ai-data`, `_permissions`, `_acknowledgements`, `_menu-open`, `_reset-confirm`.
- **Raiz:** título grande "Settings" · busca · cartão "YOUR SETUP" (prévia do telefone com formato; Camera, Quality, Mic, Text — cada valor abre sua página) · CREATE: Recording, Prompter, Remote · YOUR CUE: My Cue Voice → 9.3, Personalize (NEW) · GENERAL: Language & Region, Privacy & AI data · PRO: Cue Pro → 11.4, Restore purchases · ABOUT: Privacy policy, Terms of use, Acknowledgements, Version. Ícones 30 pt raio 8 (cores em 09-Decisions §11, também listadas em RESPOSTAS.md). Linha ≥ 44 pt; rodapé ≤ 60 caracteres; nenhum botão amarelo sólido.
- **Busca:** resultados são as próprias linhas, agrupadas por caminho ("Prompter › Rigs"). Sem resultado: estado vazio de busca do sistema.
- **Recording:** Starts with Front|Back (segmented) · Resolution 720p/1080p/4K e Frame rate 24/30/60 (`Picker .menu`) · Default format 9:16, 4:5, 1:1, 16:9 · Microphone › (Automatic, iPhone, AirPods Pro, DJI Mic 2) · While recording: Countdown Off/3/5/10, Grid.
- **Prompter** (também aberto por Aa no gravador como `.sheet` medium/large, `presentationBackgroundInteraction(.enabled)`): prévia fixa no topo; Reading (Follow my voice, Speed 80–220 passo 5, Countdown, AI Coach) · Text (size, Font ›, Line spacing 1.00–1.80, Alignment, Text color) · Reading line (Show, Position 10–50, Reset) · Text window · Selfie (Height 150–470, Width 64–96, Side margins 0–48) · Over the camera · Selfie (Background opacity, Camera blur, Social safe zone ›) · Studio (Background color) · Rigs (Mirror, Flip vertically). Rodapé: "Studio uses these too. The screen stays on while the prompter is open."
- **Font:** SF Pro, New York, SF Rounded, Lexend, Atkinson Hyperlegible (+ lista de licenças em Acknowledgements).
- **Social safe zone:** Show safe zone; TikTok/Reels/Shorts/Custom (Top/Bottom/Left/Right 0–40%). Rodapé "A guide, not a guarantee · Never recorded".
- **Remote:** cartão de status (cinza / amarelo aguardando / verde conectado) · Connect a device → Waiting → Connected → Disconnect (destrutivo) · Enter a code, Scan the code.
- **Personalize:** App icon › (Default; Deep Space 25 vídeos; First Light 50 vídeos · Pro) · Your topics → 2.2 · Tag new scripts automatically · Starry sky Off/Calm/Lively (menu) · Celebrations · Haptics.
- **Language & Region:** App language → Ajustes do iPhone (`openSettingsURLString`) · Voice following · Script language.
- **Privacy & AI data:** On-device AI · Help improve Cue · Privacy policy · Permissions › (status + Open iPhone Settings) · **Delete my Cue data** (destrutivo) → `confirmationDialog`: "Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone." · **Delete my Cue data** · Cancel.
- **Menu aberto:** `Picker .menu` / `Menu` nativos.
- Animações: push/pop padrão do `NavigationStack`; céu compartilhado atrás. Sem animação própria.

## 2. Your universe (9.2)
Prints: `9.2_live-2026`, `9.2_sealed-2025`, `9.2_planet-popover`, `9.2_share-sheet`, `9.2_year-in-review-first`, `9.2_year-in-review-last`, `9.2_new-account`, `9.2_new-year`.
Chegada: card "Your universe" em 9.1, ou tab. Seletor de ano (segmented em vidro) e swipe horizontal no universo; linha "{n} VIDEOS SHARED IN {year}" (+ " · SEALED").
- **2026 vivo:** núcleo "YOU", planetas TikTok 12 / Reels 6 / Shorts 5, pontos de vídeo, legenda de temas (barra vertical 3 pt, nunca bolinha), card "NEXT MILESTONE · 23 / 25 · Share 2 more videos · Unlocks the Deep Space app icon", linha "Your 2026 in review" (56 pt, raio 20, chip ▶ Play), botão amarelo "Share my 2026 universe" (50 pt).
- **2025 selado:** badge "◆ SEALED · DEC 31, 2025", saturação .75, brilho .92, animações pausadas.
- **Toques:** planeta → popover ("{Plataforma}", "{n} VIDEOS IN {year}", "{k} more to unlock {detalhe}", **See in Takes ›** → 6.2 filtrado, chip amarelo "{YEAR} · SHARED ✕") · ponto → 6.3 · tema → 6.2 filtrado · review → story · botão amarelo → sheet.
- **Planeta:** `d = 14 + 24·ln(min(n,365))/ln(365)` pt; detalhes em 52 (brilho), 156 (anel), 365 (lua). Crescimento: spring 0,6 s `cubic-bezier(.3,1.4,.5,1)` ao abrir após um share; `.soft` háptico ao cruzar faixa.
- **Sheet Share my universe** (`.sheet` medium, `Button(role: .close)`): cartão 9:16 "MY {year} UNIVERSE"; segmented Image | 6 s video; toggles Show numbers / Show @handle; Save to Photos (glass), Share… (amarelo, folha do sistema). `ImageRenderer`/`AVAssetWriter`.
- **Year in review:** tela cheia, 5 slides de 3,2 s com barras no topo de 3 pt. Slide 1 "YOUR 2026" · 23 · "videos shared" · "so far this year" · rodapé "TAP TO CONTINUE". Slides 2–5: "MAIN PLANET", "BEST MONTH" (gráfico de 12 barras), "LONGEST STREAK" ("{n} weeks in a row"), "STRONGEST THEME" (barra de 6×90 pt na cor do tema, "Morning routines", "12 videos · the world you return to"). Toque à direita avança, à esquerda volta, xmark fecha; último slide: botão amarelo "Share my 2026". No print `year-in-review-last` a 5ª barra está meio preenchida só porque o timer estava rodando; no app ela termina cheia. Entrada `yvIn` 0,3–0,4 s ease-out. Reduzir Movimento: barras cheias, sem avanço automático. Disponível a partir de 1º dez no ano vivo.
- **Conta nova:** sem seletor ("NO VIDEOS SHARED YET"), só o núcleo (órbitas 55%), legenda "Your universe starts with your first share.", card "FIRST STAR · 0 / 1", review travado ("3 VIDEOS TO UNLOCK", toast "Share 3 videos to unlock it"), botão "Record your first video".
- **Ano novo:** 2027 · 2026 · 2025 (anterior selado), "Your 2027 universe starts with your first share.", "FIRST STAR OF 2027 · 0 / 1", review do ano passado, botão "Share my 2026 universe".

## 3. Profile (9.1)
Prints: `9.1_default`, `9.1_context-menu`, `9.1_edit-profile`, `9.1_new-account`.
`NavigationStack` + `List` `.insetGrouped`, título grande "Profile", toolbar **Edit**. Linhas: identidade (avatar 60 pt, "Maya Costa", "@mayacooks · Lifestyle creator"); Your universe → 9.2 ("23 videos"); card My Cue Voice (v28); card Plan (v28) → 11.4.
- Toque na identidade ou Edit → sheet **Edit Profile** (large): Cancel / Done (desabilitado se inválido), foto 96 pt, Name (1–40), Username (2–24 `a–z 0–9 . _`, minúsculas; erro "Use 2–24 letters, numbers, . or _"), Creator type; rodapé "Shown on the universe cards you share."; Done → toast "Profile updated".
- Toque longo (480 ms) no nome → `.contextMenu` com prévia: Copy @handle · Share profile link (`ShareLink`) · Edit profile.
- Conta nova: "0 videos · Starts with your first share", plano "5 OF 5 EXPORTS LEFT".

## 4. Pro (11.4)
Prints: `11.4_pro-final` (título "Take your universe further.", sub "Free to try · 5 exports included. Then 7 days free."), `11.4_pro-calm`.
- **Conteúdo:** eyebrow "CUE PRO", título "Take your universe further.", sub "Free to try · 5 exports included. Then 7 days free."; lista: Unlimited exports, up to 4K (EXPORT) · Full My Cue Voice + sponsored-ad scripts (AI) · Hook variations, platform versions, best-take picks (AI) · Cover styles, series tags, "Text behind me" (EDIT) · Remote from Apple Watch, iPad & Mac sync (STUDIO) · Every milestone app icon (UNIVERSE); planos Yearly "$39.99 · $3.33/mo" (SAVE 58%, selecionado, anel amarelo) e Monthly "$7.99 / month"; CTA "Start 7-day free trial"; "Free for 7 days, then $39.99/year. Cancel anytime in Settings."; links Restore · Terms · Privacy.
- **Final da abertura** (2,4 s, tocável a partir de 1,4 s): warp 42 riscos 0–1,1 s `cubic-bezier(.5,0,.8,.4)`; ignição 0,7–1,4 s `(.2,.9,.25,1)` háptico `.soft` em 1,25 s; onda 1,25–2,35 s; planeta "você" acende 1,5–2,3 s; conteúdo sobe 18 pt e desfoca→nítido a cada 70 ms, 1,35–2,3 s, `.success` ao CTA aparecer; brilho no botão "Start 7-day free trial" a cada 3,6 s a partir de 2,4 s. Reduzir Movimento: só fade 0,3 s, sem brilho.
- **Calma** (vinda de exportações): sem warp; eyebrow "YOUR VIDEO IS READY", título "Keep sharing your universe.", sub "Start the trial and export it now.", CTA "Start free trial · export now". Sucesso → exporta → 8.2, toast "Trial started · video exported".
- Nativo: `SubscriptionStoreView` com `.storeButton(.visible, for: .restorePurchases)`.

## 5. Exportações grátis
Prints: `6.3_last-free-export`, `8.1_last-free-export`, `8.1_your-video-is-ready`.
Rótulos: 5–2 "{n} OF 5 LEFT" · 1 "LAST FREE EXPORT" (amarelo) · 0 "0 OF 5 LEFT · EXPORT WITH PRO" (laranja) · Pro "PRO · UNLIMITED EXPORTS". 6.3: "{n} OF 5 FREE EXPORTS LEFT · GO PRO", "LAST FREE EXPORT · GO PRO", após Not now "READY · EXPORT WITH PRO · GO PRO".
Com 0, tocar em Share/Save/ícone de compartilhar abre a sheet **"Your video is ready"** (`.sheet` medium, entrada 0,36 s `(.2,.9,.25,1)`): miniatura com "✓ READY"; "Saved in Takes · nothing is lost. You've used your 5 free exports."; **Start free trial · export now** (amarelo, brilho); **See what's in Pro** (glass); **Not now**; "7 days free, then $39.99/year. Cancel anytime." Fechar/Not now → 6.3 + toast "Saved in Takes · export with Pro anytime". Start/See → Pro calmo.

## 6. Share to universe
Prints: `8.1_save-video-share-icon`, `8.1_pick-networks`, `8.1_explainer-2-networks`, `8.1_queue-step`, `8.1_network-app-cue-breadcrumb`, `8.1_posted-question`, `6.3_continue-posting-card`, `8.2_1-network`, `8.2_3-networks`, `6.3_post-later`.
1. **8.1:** **Share to universe** (amarelo) · **Save video** (glass, só Fotos) · ícone de compartilhar na toolbar (`ShareLink`, glass, folha do sistema).
2. **Escolha de redes** (`.sheet` large): miniatura, título, "✓ CLEAN FILE FOR EVERY NETWORK · NO WATERMARKS"; checkboxes TikTok (pré-marcado, "· from your script"), Reels, Shorts, YouTube, LinkedIn com linha mono ("9:16 · 0:52 FITS", "9:16 · POSTS AS A SHORT"); toggle "Also save to Photos"; CTA "Share to {n} networks" (desabilitado com 0: "Pick a network"); "Uses 1 free export · {k} left after this" / "Pro · unlimited exports". Toast "Exported · saved to Photos".
3. **Explicação** (só com 2+ redes, nas 2 primeiras vezes): "Posting to {n} networks"; 1 "Cue opens each app" — "Your video is already loaded and the post text is copied."; 2 "You post there" — "Paste the text, pick the cover, tap Post."; 3 "Tap ◀ Cue to come back" — "Top left of the screen. Cue takes you to the next network."; chips "TIKTOK › REELS › LINKEDIN"; CTA "Start with {rede}".
4. **Passo da fila:** "{i} OF {n}", "Post to {rede}", barra de n segmentos (amarelo atual, verde postado, cinza depois); checklist: "Caption copied · paste it in {app}" (+ **Copy again**, texto editável), "Your captions are in the video · keep auto captions off", "Cover frame 0:03", fase A: "In the share sheet, tap {app}"; aviso (amarelo 10% + anel 1 pt, chip "◀ Cue"): "After posting, tap ◀ Cue at the top left. We'll open {próxima} next." (último: "…to finish."); **Send to {app}** (amarelo), **Edit first**, **Post later**. Fechar = o resto vai para later, toast "Saved · continue anytime".
5. **Tela do app da rede** (stand-in do protótipo): breadcrumb iOS "◀ Cue" no topo esquerdo; no app real, o sistema desenha.
6. **"Posted on {rede}?"**: "Welcome back. Cue lights its planet once it's live." **Not yet** (glass) / **Yes, it's live** (amarelo). Só Yes conta como SHARED.
7. **Card "Continue posting"** (3.2 / 6.2 / 6.3, 16 pt das laterais, 104 pt acima do fundo, 60 pt de altura): "CONTINUE POSTING · {i} OF {n}", "Next: {rede} · {título}", **Continue**, ✕ (move o resto para later, toast "Saved · post when you're ready").
8. **8.2:** uma estrela por rede, 350 ms entre elas; cada planeta pulsa e ganha +1 ("+1 · REELS" em mono amarelo, sem colisão); texto "SHARED TO 3 NETWORKS". Com 1 rede: "SHARED TO {REDE} · On its way." Fases (09): cartão vira estrela 0–0,65 s; arco 0,52–1,57 s; pulso 1,57–2,17 s `.success`; nova estrela 1,87–2,57 s. Reduzir Movimento: estado final.
9. **6.3:** "POST TO LINKEDIN LATER" abaixo de Share.
Sheets: entrada `translateY(100%)→0` 0,36 s `cubic-bezier(.2,.9,.25,1)`; Reduzir Movimento sem slide.

## 7. Telas ligadas
Prints: `8.3_milestone`, `1.7_first-star`, `9.3_my-cue-voice`, `6.2_takes-from-planet`.
- **8.3 Milestone:** título "A new icon is yours."; sub "25 videos in 2026 · Deep Space icon unlocked"; seletor de ícones; CTA "Use Deep Space". Reduzir Movimento: constelação final.
- **1.7 First star:** "Saved in Takes. Share it to light your 2026 universe."
- **9.3 My Cue Voice:** mesma lista agrupada do 9.1 (cartão material, cabeçalhos em caixa alta, linhas 52 pt).
- **6.2 Takes:** vindo do planeta, chip amarelo mono "{YEAR} · SHARED ✕" primeiro no filtro; só vídeos daquela plataforma; ✕ limpa.

## Regras de negócio do dia
- **5 exportações grátis** (Keychain), depois Pro; o resto é grátis.
- **1 por envio:** conta por exportação, nunca por rede. Share to universe para N redes = 1. Save video e o ícone de compartilhar = 1 cada.
- **Contada na entrega do arquivo:** ao salvar nas Fotos ou carregar num app de rede/folha do sistema, mesmo que nunca publique. Uma vez por exportação (as redes seguintes da fila não contam). Falha ou cancelar antes da entrega não conta. Editar e reexportar dentro da fila não gasta outra.
- **Mesma versão final** para todas as redes: Cue nunca corta nem altera na exportação. Arquivo limpo, sem marca d'água. 1080×1920, 30 fps, HEVC/H.264, AAC 48 kHz.
- **Texto do post** não viaja com o vídeo: copiado para a área de transferência a cada passo. "Captions" (legendas) ficam gravadas no vídeo.
- **Fase A (v1.0):** folha de compartilhar do iOS para todas as redes (`UIActivityViewController`/`ShareLink`), botão "Send to {app}", linha "In the share sheet, tap {app}". Sem aprovações.
- **Fase B (após aprovação):** TikTok Share Kit e Meta Reels/Stories; YouTube e LinkedIn continuam na folha. Botão abre o editor direto; a linha "tap {app}" some. Atrás de feature flag `shareKitEnabled = false` na v1.0.
- **Sandbox (desenvolvimento):** TikTok for Developers em modo Sandbox, até 10 contas, sem revisão. Primeiro: spike no aparelho com um vídeo pela folha do sistema para TikTok, Instagram, YouTube e LinkedIn. Preparar política de privacidade e termos, descrição e vídeo demo do Sandbox (revisão ~1–2 semanas). Conferir termos atuais do SDK da Meta.
- Cue não confirma publicação: "Posted?" é a fonte de verdade. Dados: `ShareRecord {takeID, network, date, status}`, `PostText`, `ShareQueue` salvo no aparelho.

## Observações sobre os prints
- Os prints mostram a tab bar do protótipo nas páginas do Settings; no app use a `TabView` nativa.
- Nas telas com título grande (8.1 "Ready to travel.", 8.2 "On its way.", 8.3 "A new icon is yours.") o título quebra em 2 linhas e encosta no subtítulo só por causa da fonte de substituição da captura. No app o título tem 1 linha (SF Pro), com 10 pt até o subtítulo.
- 8.1 e 6.3 têm um rótulo "Exported video" / "Video" sobre o placeholder do vídeo: é o placeholder do protótipo, não vai para o app.
- `1.7_first-star.png` tem resolução menor (capturada com zoom, ampliada para 390×844) e o rótulo "FIRST TAKE · TODAY" aparece cortado: no app ele aparece inteiro, centralizado sobre a estrela. Todos os textos e botões estão no estado final.
- A fonte nos HTMLs (Geist) é do protótipo; no app a interface é SF Pro e os sinais SF Mono (CLAUDE.md).
- Os estados dependem do painel APP DATA / FREE EXPORTS; o nome de cada PNG indica o estado.

## 8. Onboarding (1.1 a 1.7) · telas feitas hoje
Arquivos: `1.1_welcome`, `1.2_topics`, `1.3_voyage`, `1.4_first-message`, `1.4b_slow-loading`, `1.5_permissions`, `1.6_practice`, `1.7_first-star` (`.html`). Todas são animadas e **tocam uma vez** no app, parando no quadro final; Reduzir Movimento / Low Power mostra o quadro final. Detalhes de tempo, curva, háptico e regras de cada uma: `docs/09-Decisions.md` §12 (1.1), §14 e §14b (1.2), §15 (1.3), §16 (1.4 e 1.4b), §17 (1.6), §18 (2.2); a 1.5 (permissões) mantém o fluxo e ganhou a arte do topo (orbes de voz e câmera, feixe de luz, rótulos VOICE e CAMERA); a 1.7 mostra "Saved in Takes. Share it to light your 2026 universe."
- **1.1 Welcome:** estrela entra, toca os 5 primeiros pontos do C, faz a perninha, acende TELEPROMPTER · AUTO CAPTIONS · ✦ AI SCRIPTS, volta ao 6º ponto e explode; "CUE STUDIO" aparece sob o C e o título depois. Get started → 1.2.
- **1.2 Topics:** 1 a 3 temas dos 10 oferecidos (+ "+ Your own"), nada pré-marcado, Continue desabilitado com 0; contador com barras; a estrela chega e vira o núcleo "YOU"; ao tocar num tema o planeta nasce na órbita pelo lado livre. Continue → 1.3.
- **1.3 Voyage:** zoom out da galáxia YOU; 5 galáxias (TikTok, Reels, YouTube, Shorts, LinkedIn) nascem; escolha única; "Head to {P}" → 1.4.
- **1.4 First message:** console de transmissão (cantoneiras, "DESTINATION · {P}", anel de progresso), pílula "MESSAGE READY FOR LAUNCH"; botão único **Load in teleprompter** → 1.5. **1.4b:** carregamento lento (esqueleto, spinner; "Use a ready-made message" após 15 s).
- **1.5 Permissões:** Continue → alertas do sistema (mic → fala → câmera) → 1.6.
- **1.6 Practice:** texto dela no prompter, play central, GET READY · 3 · 2 · 1 · READ!, leitura, card final; **Record it for real** abre o gravador real com o texto dela; Not now → Scripts.
- **1.7 First star:** o 1º take vira a primeira estrela. Go to my studio · Edit this take first.
