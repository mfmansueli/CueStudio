# Cue Studio — Design

Fonte de verdade do design. Atualize junto com a UI (ver `ARCHITECTURE.md`, seção 5).

Origem: projeto "iOS Teleprompter App Design" no Claude Design, arquivo `Cue Teleprompter v9.dc.html`
(cópia em `design/`, com o prompt `Claude Code Prompt.md`). A v1 do app seguia a v3; a v6 veio por
fases; a v7 mudou a tela de gravação (frame real, zonas seguras em VideoSpace, linha de leitura,
janela de texto, Hide UI) e a escala de velocidade; a v9 abre todos os recursos no grátis (só a
exportação tem limite), refaz o Quick edit (Remove part, aba Clean Up) e simplifica a janela de texto.

---

## 1. Identidade

**Cue** é um teleprompter para criadores de conteúdo. Script primeiro, câmera depois — ou direto para
a gravação. Cada script carrega o destino ("Create for": TikTok, Reels, Shorts, YouTube, LinkedIn,
Stories), o formato (anúncio,
review, tutorial…) e a estrutura (Hook → Body → CTA).

- Tom: direto, de criador para criador. Frases curtas, sem jargão.
- Marca: três linhas de script com a do meio acesa em amarelo (`CueMark`).
- **Nenhum recurso fica bloqueado.** Teleprompter, roteiros, toda a IA (Apple Intelligence, sem custo
  por uso), Creator Voice, Quick edit, Clean Up, legendas, 4K, versões e melhor take são grátis. O
  único limite é **exportar vídeos**: 5 exportações grátis (salvar no Fotos ou compartilhar), sem marca
  d'água; depois, o paywall oferece 7 dias grátis no mensal ou no anual. Gravar, editar e escrever
  nunca param, e as takes nunca são apagadas nem bloqueadas (`UsagePolicy`, `UsageQuotaService`).
  O contador fica no Keychain, então reinstalar não zera. Não há badges "PRO" nem marca d'água.

## 2. Aparência

O app roda **somente em modo escuro** (`UIUserInterfaceStyle = Dark`): é um app de câmera, e uma
tela branca atrapalha a gravação. Os tokens mantêm valores claros para o dia em que isso mudar.

### Cores (`Palette`)

| Token | Escuro | Uso |
|-------|--------|-----|
| `bg` | `#000000` | Fundo das telas |
| `surface` | `#1C1C1E` | Cards, linhas agrupadas, sheets |
| `surface2` | `#2C2C2E` | Controles e linhas dentro de cards/sheets |
| `surface3` | `#3A3A3C` | Tiles um nível acima de `surface2` (destinos de compartilhamento, "More") |
| `surfaceMuted` | `#242426` | Formatos sérios (pedido de desculpas) |
| `fill` | `#767680` 24% | Chips inativos, trilhos de medidores |
| `overlayFill` | branco 10% | Botões sobre a câmera/prompter |
| `neutralAction` | `#636366` | Swipe "More", segmento selecionado |
| `glassBorder` | branco 12% | Borda de 0,5 pt das superfícies de vidro |
| `separator` | `#545458` 60% | Separadores de 0,5 pt |
| `ink` / `ink2` / `ink3` | branco / `#EBEBF5` 60% / 30% | Texto principal, secundário, terciário |
| `acc` | `#FFD60A` | Acento: ação primária, hook, guia de leitura |
| `accInk` | `#000000` | Texto sobre `acc` |
| `accSoft` | `#FFD60A` 16% | Fundos tingidos (tags de cue, botões secundários de gravação) |
| `accWash` → `accWashFaint` / `accBorder` | `#FFD60A` 22% → 5% / 38% | Card de Prompt em destaque |
| `record` | `#FF3B30` | Botão de gravar, badge de gravação |
| `danger` | `#FF453A` | Ações destrutivas |
| `warn` | `#FF9F0A` | Fora da faixa ideal, hook longo, aviso de monetização |
| `info` | `#64D2FF` | Aviso de nova versão no editor |
| `success` | `#34C759` | Toggles, "Kept" no Clean Up, ponto do microfone conectado |
| Plataformas | TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6961` · YouTube `#FF9F0A` · LinkedIn `#0A84FF` · Stories `#FF375F` | Ponto que marca o destino |
| `frameMask` / `frameEdge` | preto 60% / branco 22% | Fora do frame gravado / bordas de 0,5 pt do frame |
| `safeZoneLine` / `safeZoneLabel` | branco 40% / 62% | Contorno tracejado da área segura e a legenda |
| `safeZoneShade` → `safeZoneShadeFaint` / `safeZoneSide` | preto 40% → 10% / 16% | Faixas de risco (degradê em cima e embaixo, sombra nas laterais) |
| `readingLineGlow` | `#FFD60A` 45% | Brilho da linha de leitura sobre a câmera |
| `readingLineHandle` / `…Active` / `…Border` | `#1E1E20` 55% / `#FFD60A` 55% / branco 28% | Alça da linha (em repouso / arrastando) |
| `stopButtonRing` / `stopButtonFill` | branco 85% / preto 18% | Botão de parar mínimo (controles escondidos) |
| `removalFill` · `selectedSectionFill` · `trimDim` · `bubbleBorder` · `frameTick` | `#FF453A` 30% · branco 14% · preto 72% · branco 25% · branco 70% | Quick edit: faixa do Remove part, seção selecionada, o que a alça vai cortar, balão do tempo, marca de cada frame no zoom de precisão |
| `cutLine` · `joinMark` | branco 55% · preto 60% | Quick edit: linha fina de um corte na timeline e o fundo da marca de transição (corte seco) |

### Tipografia

- Interface: SF Pro com Dynamic Type (`.largeTitle` 34, `.title2` 22, `.title3` 20, `.body` 17,
  `.subheadline` 15, `.footnote` 13, `.caption` 12).
- Prompter (tamanho fixo, controlado pelo slider 16–56 pt; Studio usa 1,35×):
  **Lexend** (padrão), **Atkinson Hyperlegible** ("Legible"), **Source Serif 4** ("Serif"),
  **SF Rounded** ("Rounded"). Lexend, Atkinson e Source Serif 4 estão em `DesignSystem/Fonts/` (OFL)
  e são registradas no launch.
- AI Coach: cues em caixa-alta a 0,42 do corpo, amarelo sobre `accCueWash` (12%), para o texto
  falado ficar em destaque. Sobre a câmera o texto tem sombra leve (`textShadow`).
- Números que mudam (relógio, duração, velocidade) usam `monospacedDigit()`.

### Espaçamento e formas (`Metrics`)

- Margem lateral: 16 pt (cards), 20 pt (títulos e texto solto).
- Raios: card 26, interno 20, tile 18, campo 12, sheet 38; botões e chips em cápsula.
- Alturas: botão 50 (grande 54, compacto 34), chip 34, alvo de toque mínimo 44×44.
- Controles sobre a câmera usam Liquid Glass (`glassEffect`).

### Ícones

SF Symbols por significado: `doc.text` scripts · `film.stack` takes · `person.crop.circle` perfil ·
`record.circle` gravar · `video.fill` gravar script · `text.alignleft` Studio · `sparkles` IA ·
`arrow.up.to.line` voltar ao topo · `chevron.backward.2`/`forward.2` pular linhas ·
`slider.horizontal.3` ajustes de câmera · `timer` contagem · `star.fill` melhor take ·
`mic.fill` / `mic.slash.fill` entrada de áudio.

## 3. Componentes (`DesignSystem/`)

| Componente | Uso |
|------------|-----|
| `CueStudioButtonStyle` (`.cuePrimary()`, `.cueSecondary()`, `.cueTinted()`, `.cueOutline()`, `.cueGlass()`, `.cueLight()`, `.cueDestructive()`, `.cueDestructiveTinted()`; tamanhos compact 34, medium 42, regular 50, large 54) | Botões em cápsula; um primário (amarelo) por tela. Branco (`light`) para a ação principal de uma ferramenta; vermelho para confirmar uma remoção |
| `CueIconButtonStyle` (`.cueIcon(.glass/.overlay/.surface/.tinted/.accent/.light/.danger)`) | Botões redondos |
| `surfaceCard()` / `GroupedCard` | Cards e grupos de linhas com separadores |
| `FilterChip`, `TagPill`, `ColorDot` | Chips de filtro/opção, tags, ponto do destino |
| `SelectableCard` | Tiles selecionáveis (fontes, enquadramento, formato, plano) |
| `ValueSlider`, `SwatchButton`, `UsageMeter` | Sliders com valor, amostras de cor, medidores |
| `SettingToggleRow` | Linha de ajuste com título, detalhe e switch verde (Display, câmera) |
| `SheetHeader`, `SectionHeading` | Cabeçalho de sheet e de grupo |
| `FlowLayout` | Chips que quebram linha (nichos, frases) |
| `SearchField` | Busca em cápsula (`fill`, 40 pt) dentro do conteúdo, para quando algo vem acima dela (Scripts) |
| `ToastView` | Confirmação curta no topo (`ToastService` + `.toastHost()`) |
| `CueMark`, `CameraFeedPlaceholder` | Marca e fundo quando não há câmera |
| `RecordGlyph` | Anel branco com ponto vermelho da aba Record (imagem com cores originais) |
| `fittedSheet()` | Sheet da altura do conteúdo, raio 38 (New script, Start recording) |
| `PromptCard` (`Screens/Shared/PromptCard`) | Caixa de Prompt em destaque: selo Apple Intelligence, exemplo e botão enviar. `.compact` (Scripts) tira a explicação e usa "Describe your next video…" |

## 4. Telas

| Tela | Onde | Conteúdo |
|------|------|----------|
| Scripts (home) | `Screens/Scripts` | "+" no topo (abre New script), título + resumo, caixa de Prompt compacta (sempre visível, no topo da lista; abre Generate › Prompt), busca, chips (All, destinos, pastas), card "Last edited", lista "All scripts" com swipe (Record / More / Delete), segurar mostra preview + menu, modo de seleção com barra (mover, duplicar, apagar) |
| Primeiro uso | `EmptyLibraryView` | "Start with a script." + caixa de Prompt + Write / Import / Generate with AI + "Record without a script" |
| Script (leitura) | `Screens/ScriptDetail` | Título, destino/formato/preset, medidor de duração, faixa de blocos, aviso de hook, banner laranja de checagem de fatos ("Checked" dispensa), texto com blocos e cues, takes, Studio mode + Record. Menu More: "Make a version for…" cria uma cópia ajustada à duração de outra plataforma |
| Script (edição) | `ScriptEditorView` | Título, faixa de blocos, editor com Writing Tools, painel com aviso de versão, atalhos de IA ("In my voice" + os do formato) e medidor |
| Create for | `DestinationSheet` | 6 plataformas com resumo do preset (formato · qualidade · safe zones · ideal) + "Monetization goals". Escolher mostra o toast "Create for {plataforma}" |
| Hooks | `HooksSheet` | Hook atual + 3 opções escritas pelo modelo no aparelho (sem modelo, as do formato) + "More options" |
| New script | `NewScriptSheet` | Caixa de Prompt + grade Write / Import / Themes / Formats. Sobre a câmera, Paste no lugar de Write |
| Start recording | `StartRecordingSheet` | "Read from a script" (4 recentes com duração), "+ New script", "Record without a script →". Sobre a câmera vira "Add a script", sem o freestyle |
| Importar | `ImportScriptSheet` | Files, Scan (câmera de documentos), Photo e Clipboard. Scan, Photo e PDFs escaneados passam por OCR do Vision no aparelho |
| Gerar com IA | `GenerateScript/` | "Generate with AI · Apple Intelligence · private · no cost" + abas **Prompt** (texto livre, exemplos, Create for, Length, "Write in my voice", aviso de fatos), **Themes** (6 ideias do nicho, "New ideas", "Use" preenche o Prompt) e **Formats** (8 formatos, Sponsored ad incluído) → briefing |
| Selfie | `Screens/Prompter/Selfie` | Câmera em primeiro plano, em camadas que nunca entram no vídeo: o **frame gravado** (o preview mostra exatamente o que é gravado; fora dele, preto 60% e bordas de 0,5 pt), a **zona segura** da plataforma (degradê em cima e embaixo, sombra nas laterais, contorno tracejado e "INSTAGRAM REELS SAFE AREA"), a **janela de texto** (largura 50–93%, padrão 93%; altura 160–380, padrão 380: começa no máximo e o criador pode estreitar; as linhas quebram normalmente e preenchem a largura; fundo preto 25%; desfoque opcional; o texto já lido esmaece) e a **linha de leitura** fixa logo abaixo da lente (118 pt na frontal; 36% do frame na traseira), com uma alça fina (14 × 34, alvo de 44 pt) para arrastar, que some enquanto o texto roda ou a câmera grava. Sem dica de primeiro uso. A janela segue a linha (a linha fica ~25% abaixo do topo dela). Topo: fechar, Selfie \| Studio e o chip "{Plataforma} · 9:16" (abre Create for; em freestyle troca o enquadramento); gravando: olho (Hide UI), "● 00:42 \| 18s to 1:00" e o chip. Barra de vidro: Voice Following \| Steady, slider de velocidade com o valor (0,3–2,0×) ou "AUTO · Listening/Paused", voltar ao topo, play, Aa; entre as duas linhas, no meio do fio que as separa, a **pill do microfone** (`AudioInputPill`: 🎙 + ponto verde + nome da entrada em uso, ex.: "iPhone Microphone", "DJI Mic"; cápsula `overlayFill` de 26 pt, alvo de 40 pt; ponto `ink3` enquanto a sessão de áudio não informou a entrada; "Microphone off" com ponto laranja sem permissão; abre Audio Input e fica travada gravando ou na contagem); câmera: última take, ajustes, gravar, virar, timer. Com os controles escondidos ficam só texto, linha, relógio e um botão de parar |
| Studio | `Screens/Prompter/Studio` | Prompter em tela cheia sem câmera, barra de progresso no topo, fechar, Selfie \| Studio e espelhar; barra: Voice Following \| Steady, slider de velocidade (no Voice Following, "Listening/Paused" e "Speed follows your voice"), voltar ao topo, 3 linhas para trás/frente, play grande amarelo e Aa |
| Display | `DisplaySettingsSheet` | "Display · ● Live preview". No Selfie, primeiro **Layout** (`DisplayLayoutSection`): Reading line com ↑/↓ e a distância da câmera, Text window height e width ("Narrow · less eye movement"), **Social safe zone** (chips Reels / TikTok / Shorts / Stories / Custom no 9:16, LinkedIn / Custom no 4:5, Custom no 1:1; no Custom, margens em %), Show safe zone, Hide controls while recording e "Reset to Recommended", com o aviso de que a zona é guia e não garantia. Quick: AI Coach (desligado por padrão), Text size e, no Selfie, Background opacity e Camera blur (Off/Subtle/Soft/Medium, leve); no Studio, Reading line (Top/Bottom) e Background color. Advanced (recolhível): fonte, espaçamento, margens, alinhamento, cor, linha de leitura, espelhar. No Selfie, a altura máxima para logo abaixo da janela de texto (medida quando a sheet abre) |
| Audio Input | `AudioInputSheet` | Aberta pela pill do microfone no Selfie (sheet na altura do conteúdo, sem tela de ajustes separada): "Audio Input" + "Where Cue hears you in this take.", a lista das entradas conectadas agora (nome + tipo: Built-in, Bluetooth, USB, Wired headset…) com a que está em uso marcada (círculo amarelo), e "Plug in or pair a mic and it shows up here.". Tocar numa entrada a torna a entrada da gravação, fecha a sheet e a pill muda na hora. Sem entradas: "No microphone found…"; sem permissão: explicação + Open Settings |
| Câmera | `CameraSettingsSheet` | Lente, enquadramento, resolução, fps, grid, safe zones, estabilização, microfone, contagem, formato. No Selfie com script, a sheet para logo abaixo da janela de texto (não cresce além dela) e não escurece o fundo |
| Revisão do take | `Screens/TakeReview` | Vídeo no formato da take (barras pretas fora do 9:16); topo: voltar, "Take N · 0:44", estrela e lixeira; filmstrip, título (+ EDITED), meta, "3 of 5 free exports" + Go Pro (no grátis); faixa "Your takes · N" (troca de take, "Tap ☆ to pick your best", "Suggest best"); Edit · Retake · Save · Share (Share amarelo, abre Share to). Só uma melhor take por roteiro |
| Share to | `TakeReview/Share` | Miniatura, "SHARE TO", título, "0:44 · 9:16 · 1080p"; seis plataformas (a da take com anel amarelo e "recommended"), Save video e More; "Created for X — framed and safe-zoned for it"; Burn in captions; Quality 1080p / 4K; exportações grátis restantes + Go Pro. Plataforma: exporta, salva no Fotos e abre o app; "Ready to post on X · N of 5 free exports left". Sem exportações grátis, qualquer exportação abre o paywall e continua sozinha depois da assinatura |
| Quick edit | `Screens/QuickEdit` | Cancel (guarda um rascunho: "Draft kept — tap Edit to continue"; Edit o retoma com "Draft restored") / "Quick edit · Original 1:04" ou "1:04 → 0:58" / Done; prévia ao vivo no formato (toque = play/pause, com um ▶︎ no meio quando pausada; menor no Trim e no Clean Up para dar espaço à timeline); 7 ferramentas embaixo. **Trim:** play branco, "00:04.32 / 00:11.00" (playhead / duração editada), desfazer, refazer; timeline de 80 pt com frames reais do que as alças alcançam (o que elas cortaram continua na timeline, escurecido, fora das alças; o que Delete, Remove part e Clean Up tiram não deixa buraco; as seções ficam coladas e cada corte é uma linha fina de 1 pt, `cutLine`, amarela quando selecionado, nunca um vão), alças amarelas (ficam brancas ao arrastar; ficam onde foram soltas e seguem o dedo do mesmo jeito dos dois lados, com alvo de 38 pt; **atravessam cortes**: um corte é uma divisão, não uma barreira, e as seções que a alça passa saem da edição junto com o corte, voltando se ela voltar antes de soltar; enquanto a alça está presa a timeline continua desenhando o que era no começo do arraste, então nada muda de lugar sob o dedo; a escala só muda quando algo sai do meio), playhead arrastável pelo botão acima dos frames mesmo em cima de uma alça (nos frames, a alça vem primeiro) e um balão com o tempo ("Start 00:02.14", ou o tempo do scrub); botões **Remove part** (branco: faixa vermelha de 2 s em volta do playhead, bordas arrastáveis, depois Cancel / "Remove 00:02.10"; Play antes do fim da faixa para exatamente na borda final e fica nela, sem loop, e Play parado na borda final toca a faixa de novo desde a borda inicial), Cut no playhead (seleciona a segunda metade), Delete (vermelho quando há seção selecionada) e Clean Up (com o número a revisar); uma linha de dica. **Transição:** no meio de cada corte uma marca de 20 pt (`joinMark` com + num corte seco; amarela com o ícone quando há transição; some enquanto uma alça é arrastada, com a faixa vermelha na tela ou quando uma das seções vizinhas tem menos de 26 pt); tocar nela seleciona o corte e os botões viram os chips None / Dissolve / Fade + ✓ (dica: "Cut at 00:20.00 · None keeps it a hard cut"). Todo corte nasce **None** (corte seco): jump cut não é defeito, nada suaviza sozinho. Dissolve (0,5 s) mistura as duas seções; Fade (0,6 s) mergulha no preto e volta, com o som; ambos centrados no corte, sem mudar a duração, e mais curtos quando uma seção vizinha é curta. Escolher uma transição leva o playhead 1 s antes do corte. **Zoom de precisão** (`TimelineZoom`, `TimelineZoomController`): com a faixa vermelha na tela, a timeline aumenta a escala de tempo (não as miniaturas) para a faixa ocupar 35–58% da largura, em degraus de ~1,6× (1, 1,5, 2,5, 4, 6, 10, 16…) até frame a frame (12 pt por frame no frame rate real do arquivo); só troca de degrau quando a faixa sai da banda de 18–80% da largura (histerese), e desliza em 0,28 s em volta de uma âncora: a borda arrastada fica sob o dedo, senão o meio da faixa vai para o meio. Sem a faixa, volta ao take inteiro. Pinça amplia ou reduz à mão em volta dos dedos (e desliga o automático até o próximo Remove part; um toque que vira pinça devolve o que o primeiro dedo moveu). Com zoom, segurar uma alça, borda ou o playhead perto de um lado rola a timeline (auto-pan, mais rápido quanto mais perto), e a reprodução que sai da tela rola junto. Tudo que o dedo põe cai num frame (`FrameGrid`), com as pontas do vídeo e os cortes ainda alcançáveis; os frames da parte visível são lidos de novo nos tempos das miniaturas e, a partir de 6 pt por frame, uma marca fina embaixo mostra onde cada frame começa. Com zoom, a dica vira "Zoomed in · …" ou "Frame by frame · …" e o balão e o relógio mostram centésimos mesmo em takes longas. As alças, a faixa, o playhead e o limite de reprodução continuam no tempo real. **Clean Up** (`CleanUpToolView`): mesma barra, timeline fina com marcas por tipo (pausa azul `info`, vício laranja `warn`, regravação vermelha `danger`; esmaecidas quando mantidas), "Analyzing your take…" na primeira vez, depois "N to review" / "All clean" com "Remove all · N" (só as de alta confiança) ou "Done", "Ignore pauses under 0.7s · N short pauses kept" com − / +, e a lista: cor, título ("Long pause", "“um”", "Possible retake"), "00:04.20 · 0.9s · nota", Keep / Remove, ou "Kept" / "Removed" (tocar em Kept volta a revisar; Removed volta com Undo); tocar no item leva o playhead até ele. Audio (volume 0–150%, Enhance voice, Reduce background noise), Adjust (exposição, contraste, temperatura −100…+100, Auto), Filters (Original, Vivid, Warm, Cool, Mono, Film), Crop (9:16, 4:5, 1:1, 16:9, arrastar, Reset), Captions (do roteiro, sincronizadas à fala; Classic, Bold, Highlight; Top, Middle, Bottom). Done guarda a receita (`TakeEdit`), a nova duração e marca Edited; o arquivo original não muda. Trim, remove part, cut, delete e as decisões do Clean Up desfazem e refazem juntas |
| Takes | `Screens/Takes` | "Takes" + "N takes · N videos"; chips de plataforma e All takes / ★ Best / Not shared / Edited; seções Today / Yesterday / Earlier; cada linha é um vídeo (takes do mesmo roteiro): miniatura no formato certo com estrela e duração, plataforma · formato · qualidade, quando, chips "3 takes · Best: Take 3", "Edited", "Not shared" |
| Profile | `Screens/Profile` | Card do criador ("@handle · Signed in with Apple") + botão Sign in with Apple quando fora; Creator Voice: "Sounds like you" (frase ao vivo + "Use my voice in AI scripts"), How I sound, My phrases, My vocabulary, My style, Niche (tudo grátis); plano ("Free plan · Every feature included", "Free exports · 3 of 5 left", Apple Intelligence ilimitada, "Try Pro free for 7 days"; no Pro, "Cue Pro · Annual · renews…", "Unlimited exports, up to 4K", Manage); Settings (Default "Create for", Monetization goals, Privacy & AI data, Restore purchases); Sign out |
| Paywall | `Screens/Shared/Paywall` | Tela cheia, aberta só pelo Export (depois da 5ª exportação: "Keep posting with Cue") ou pelo Profile ("Create more. Sound like you."); benefícios (exportações ilimitadas até 4K, tudo continua aberto, as takes são suas); Annual (pré-selecionado, "SAVE 58%", "$3.33/mo · 7 days free") / Monthly ("7 days free · cancel anytime"); "Start 7-day free trial" com o que acontece depois; Restore, Terms, Privacy. Sem opção com marca d'água e sem vitalício. Nunca abre durante a gravação |

## 5. Navegação

```
RootView
└── MainView (TabView)
    ├── Scripts ─ NavigationStack ─ ScriptDetailView (leitura ⇄ edição)
    ├── Takes ─ NavigationStack
    ├── Profile ─ NavigationStack
    └── Record (aba-botão; abre "Start recording" sem trocar de aba)
Sheets (sobre as abas): New script (+) · Start recording · Import · Generate (Prompt | Themes | Formats)
Full screen: Prompter (Selfie ⇄ Studio → Revisão do take) · Paywall
```

## 5.1 Regras por plataforma

Todos os números por plataforma vêm de `SupportFiles/PlatformRules.json` (`PlatformRules` +
`PlatformRulesService`, schema 2): formato, qualidade, faixa ideal (com e sem monetização), mínimo que
monetiza e a zona segura (`SocialSafeZonePreset`). A janela de texto do Selfie não depende mais da
plataforma: abre sempre em 93% × 380 pt. As zonas são
margens em **pixels do vídeo exportado** (VideoSpace: 1080 × 1920 no 9:16, 1080 × 1350 no 4:5) e
chegam à tela por `FrameGeometry`, derivada do retângulo onde o preview realmente desenha a imagem.
Nada é posicionado com números de um iPhone.

| Plataforma | Formato | Qualidade | Ideal | Mínimo (monetização) | Zona segura (topo / base / esq. / dir., px) |
|---|---|---|---|---|---|
| TikTok | 9:16 | 1080p30 | 1:00–1:30 (sem metas: 0:15–1:00) | 1:00 | 160 / 480 / 60 / 140 |
| Reels | 9:16 | 1080p30 | 0:15–1:00 | — | 220 / 420 / 60 / 120 |
| Shorts | 9:16 | 1080p60 | 0:30–1:00 | — | 190 / 380 / 60 / 140 |
| YouTube | 16:9 | 4K24 | 8:00–15:00 (sem metas: 4:00–10:00) | 8:00 | — (vídeo horizontal) |
| LinkedIn | 4:5 | 1080p30 | 0:30–1:30 | — | 0 / 200 / 40 / 40 |
| Stories | 9:16 | 1080p30 | 0:08–0:15 | — | 250 / 250 / 60 / 60 |

A zona mostrada é a escolhida em Display › Layout (nesta sessão), senão a da plataforma do roteiro,
senão Reels (9:16) ou LinkedIn (4:5); no 1:1, Custom; no 16:9, nenhuma. Custom usa margens do
criador em % do frame (padrão 11 / 22 / 6 / 11), guardadas nos ajustes.

O arquivo tem `revision`. Quando `AppLinks.platformRules` aponta para uma cópia publicada (um JSON
estático), o app baixa uma vez por abertura e só adota uma revisão maior, completa e do mesmo
`schemaVersion`; a cópia fica em cache. Sem URL, vale o arquivo do app.

## 6. Estados

- **Vazio:** biblioteca vazia (primeiro uso), filtro sem resultado ("No scripts here yet."), sem
  takes ("No takes yet" + "Record a take"), script vazio ("This script is empty…").
- **Carregando:** "Writing your script…" com brilho pulsante; indicadores nos chips de IA e nos
  botões Save/Share durante a exportação; no Quick edit, "Processing…" na prévia só quando uma
  mudança demora mais de 0,3 s (cortes e trims são instantâneos).
- **Erro / indisponível:** câmera sem permissão (botão para Ajustes), sem câmera, câmera parada;
  Apple Intelligence indisponível (explica e usa o rascunho estruturado); importação ilegível;
  compra pendente ou não verificada; take sem o arquivo de vídeo ou ilegível ("This video can't be
  opened", ferramentas desligadas), prévia que não montou ("The preview couldn't be built") e som
  que não pôde ser analisado ("Couldn't listen to this take" + "Try again" no Clean Up). Clean Up
  sem nada a sugerir: "All clean" e "Nothing to clean up here. Your take flows."
- **Carregando (Clean Up):** "Analyzing your take…" enquanto ouve a take (volume e transcrição).

## 7. Movimento

- Sheets e toasts com mola curta (0,25–0,36 s). Contagem regressiva com "pop".
- Rolagem do prompter por `CADisplayLink`, calibrada para 215 palavras/min em 1,0×. O padrão é 0,7×
  (≈150 palavras/min, o ritmo natural) e a faixa vai de 0,3× a 2,0×. As estimativas de duração usam a
  mesma constante (`ReadTime`). Velocidades salvas antes da v7 (150 palavras/min em 1,0×) são
  convertidas para manter o mesmo ritmo.
- Voice follow: o texto desliza até a próxima palavra a ler (aproxima ~2/3 do caminho em 0,35 s),
  nunca para trás; a linha lida fica centrada na guia.
- Zoom da timeline do Quick edit: desliza em 0,28 s (ease-out, uniforme em escala).
- **Reduce Motion:** zoom da timeline sem deslizar, toasts só com fade, contagem sem escala, barras de voz e ponto de gravação
  sem animação contínua, "Writing your script…" sem pulsar.

## 8. Acessibilidade

- Botões só com ícone têm `accessibilityLabel`; toggles e opções marcam `.isSelected`.
- Cards e linhas combinam os filhos em um elemento; tiles de take leem "Take 3, 0:44, best take".
- Prompter: ajustável com VoiceOver (desliza 3 linhas), valor = progresso.
- Alça da linha de leitura: ajustável com VoiceOver (8 pt por gesto), valor = distância da câmera.
- Pill do microfone: label "Audio Input", valor = nome da entrada em uso; na sheet, a entrada em uso
  marca `.isSelected` (`prompter.audioInputButton`, `audioInput.option`).
- Quick edit: cada marca de corte é um botão ("Transition at cut N", valor = a transição, `edit.join.N`);
  os chips de transição marcam `.isSelected` (`edit.transition.hardCut/dissolve/fade`).
- Quick edit: a timeline é ajustável (1 s por gesto), valor = "tempo / duração, seção N de M",
  com as ações "Select this section", "Zoom in" e "Zoom out" (um degrau, em volta do playhead); as
  alças de trim e as bordas do Remove part também (0,5 s por gesto, ou 1 frame no zoom de
  precisão). A timeline fina do Clean Up é ajustável como a do Trim.
- Toasts são anunciados (`AccessibilityNotification.Announcement`).
- Alvos de toque de 44×44 mesmo quando o visual é menor.
- Identificadores para UI tests: `"<tela>.<elemento>"` (ex.: `hero.recordButton`, `editor.doneButton`).

## 9. Diferenças em relação ao protótipo

O protótipo simulava várias coisas; o app implementa de verdade ou deixa de fora o que não existe:

- **IA:** só Apple Intelligence (Foundation Models), sem custo e sem backend. No aparelho:
  reescritas, tom, hooks, CTA, "Fit to time", "In my voice" e ideias de tema. Private Cloud Compute:
  o Prompt livre (temas factuais incluídos); se o PCC não estiver disponível (ou falhar), o modelo do
  aparelho escreve e o aviso de fatos continua. O PCC exige o entitlement gerenciado
  `com.apple.developer.private-cloud-compute` (a Apple concede ao time sob pedido); sem ele o
  FoundationModels derruba o app na primeira chamada, então fica desligado
  (`ScriptAIService.hasPrivateCloudComputeEntitlement`) e o Prompt livre roda no aparelho até o
  entitlement entrar em `Cue Studio.entitlements`. Os roteiros saem estruturados (`@Generable`
  `ScriptDraft`: título + blocos), com o Creator Voice nas instructions quando "Write in my voice"
  está ligado. Prompts factuais (história, ciência, "como surgiu…") ganham `factCheck`.
- **Sem Apple Intelligence:** Prompt e as reescritas mostram "Requires Apple Intelligence" e ficam
  desligados; Formats continua gerando o rascunho estruturado a partir do briefing (é um modelo de
  texto, não IA); Themes mostra as ideias locais. O teleprompter não depende de IA.
- **Uso de IA:** ilimitado e completo no grátis (o v1 tinha 5 roteiros/mês): o Creator Voice
  inteiro, "In my voice", Sponsored ad, os hooks escritos pelo modelo e "Make a version for…". O
  paywall só abre pela exportação ou pelo Profile, nunca durante a gravação.
- **Themes:** as ideias iniciais são a lista local por nicho do protótipo (`ThemeCatalog`);
  "New ideas" pede ideias novas ao modelo do aparelho (sem ele, gira a lista).
- **Import por foto:** não está no protótipo; vem do pedido (Vision OCR). Sai no simulador sem câmera.
- **App Intents:** "Record script {nome}" e "New script" (Siri e Shortcuts) abrem o app no ponto
  certo (`IntentRouter`).
- **Importar:** Files (.txt, .md, .rtf, .html, .pdf, .fountain) e área de transferência. Google Docs e
  Notion entram exportando para Files ou copiando o texto (não há integração direta).
- **Voice follow:** reconhecimento de fala on-device (`SpeechAnalyzer`, nada sai do aparelho) no
  idioma do script. As palavras ouvidas são alinhadas às do script e o texto acompanha o ritmo de
  leitura; espera nas pausas e quando a fala sai do script. Arrastar ou pular linhas muda o ponto de
  onde a leitura continua. Sem modelo para o idioma (ou enquanto ele baixa), volta ao nível de
  áudio: rola na velocidade definida enquanto ouve fala.
- **Conta:** Sign in with Apple é opcional e fica no Profile (não bloqueia nada). Sem backend, só
  guarda o ID, o nome e o e-mail que a Apple manda na primeira vez (o nome preenche o perfil vazio);
  no launch confere o estado da credencial e sai se ela foi revogada. Nome e @ continuam editáveis
  e locais. O protótipo mostra "Signed in with Apple" sem botão de entrar; aqui ele aparece enquanto
  você não entrou.
- **Paywall:** só promete o que o Pro muda (exportar sem limite). A v9 ainda desenha a comparação
  com marca d'água, o selo "PRO" num formato e a lista antiga ("Studio remote from Apple Watch, iPad
  & Mac sync"); o app segue o prompt da v9, que tirou marca d'água, badges e bloqueios. Enquanto
  `AppLinks.privacyPolicy` não tiver URL, "Privacy" abre o resumo "Privacy & AI data" do app.
- **Produtos:** `studio.cue.pro.annual` / `.monthly` (os IDs da v1, com prefixo, em vez de
  `pro.annual` do pedido), ambos com oferta introdutória de 7 dias grátis; o vitalício saiu. Os
  preços regionais (ex.: R$ 24,90 / R$ 119,90) são definidos no App Store Connect; o
  `CueStudio.storekit` só tem os preços dos EUA.
- **Contador de exportações:** o prompt sugere Keychain ou iCloud Key-Value Store; o app usa o
  Keychain (só este aparelho), que sobrevive a reinstalar sem exigir iCloud. Contagens antigas em
  UserDefaults migram sem devolver exportações.
- **Melhor take:** "Suggest best" escolhe a take completa mais próxima da duração do roteiro, dentro
  da faixa ideal da plataforma (`BestTakeSuggester`); o app troca para ela e você confirma com ☆.
- **"Save takes to Photos":** removido — salvar automaticamente contornaria o limite de exportações
  grátis. Takes ficam no app; Save/Share exportam.
- **Prompt na home:** como no v9, a caixa de Prompt fica no topo de Scripts, acima da busca, e nunca
  some (filtro, busca ou seleção não a escondem). A busca da barra de navegação fica sempre acima do
  conteúdo, então a de Scripts é um `SearchField` logo abaixo da caixa.
- **Pastas:** o "+" agora abre New script, então pastas nascem em "Move to a new folder…" (menu do
  script, More e barra de seleção) e aparecem como chips depois dos destinos.
- **Tab bar:** a pill flutuante do protótipo é a própria tab bar nativa de Liquid Glass. A aba
  Record usa `RecordGlyph`, uma imagem com cores originais, porque SF Symbols viram monocromáticos
  na tab bar.
- **New script sobre a câmera:** não há editor no prompter, então o tile Write vira Paste.
- **Desfoque da câmera:** o protótipo usa um blur leve (no máximo ~6 pt); SwiftUI não desfoca a
  camada da câmera por raio, então o app cobre a câmera atrás da janela de texto com o material mais
  fino do sistema em três intensidades (Subtle 35%, Soft 60%, Medium 85%, `CameraBlurLevel`). Desfoca
  só o preview, nunca a gravação.
- **Frame e VideoSpace:** o app grava o sensor inteiro em retrato e recorta 4:5, 1:1 e 16:9 no
  export, então o VideoSpace do 16:9 é o recorte do sensor (1080 × 606 em 1080p), não 1920 × 1080
  como diz o prompt da v7. O preview mostra o sensor com `resizeAspect` no retângulo do frame, nunca
  `resizeAspectFill` em tela cheia.
- **Lente:** não existe API para a posição da câmera frontal. O app estima a lente no meio da área
  segura superior (Dynamic Island ou notch) e guarda a linha como distância até ela, então a linha fica
  no mesmo lugar em qualquer iPhone. O app é só retrato no iPhone.
- **Entrada de áudio:** não está no protótipo; vem do pedido. A `AVCaptureSession` não configura mais a
  sessão de áudio sozinha (`automaticallyConfiguresApplicationAudioSession = false`): deixada com ela, a
  sessão trocava a entrada escolhida e não aceitava microfones Bluetooth (AirPods). O app usa
  `.playAndRecord` / `.videoRecording` com Bluetooth HFP (`AudioRoute`) e grava pela entrada preferida
  (`CameraSettings.microphoneID`), aplicada toda vez que a câmera liga e quando muda. A pill mostra a
  entrada que a sessão de áudio informa (`currentRoute`), então mostra o que vai para a take: se o
  microfone externo desconecta, o sistema volta para o do iPhone e a pill acompanha
  (`routeChangeNotification`). A entrada não muda durante a gravação.
- **Speed na Display › Layout:** o prompt coloca Speed no Layout; o protótipo (e o app) deixam o
  slider só na barra.
- **Zona no 16:9:** o protótipo mostra o chip Custom no 16:9 sem desenhar a zona; o app não mostra
  chips e desliga "Show safe zone" ("Not needed for horizontal video").
- **Sheets sobre a janela:** o limite de altura da Display é medido quando ela abre; mudar a altura
  da janela com a sheet aberta não move a sheet sob o dedo.
- **Timeline do Trim:** o v9 pede uma timeline só da edição que se reajusta ao soltar a alça. Na
  prática a alça do começo voltava sempre para a borda (parecia travada) e não tinha para onde
  voltar; a timeline agora mostra o mesmo `reachable` que a prévia toca, com as pontas cortadas
  escurecidas, como no Fotos.
- **Zoom de precisão:** não está no protótipo; vem do pedido ("adaptive temporal resolution"). O
  zoom só muda a escala de desenho: o playhead, as alças, a faixa vermelha e o limite de reprodução
  do Remove part continuam no tempo real, e nada novo aparece na tela além da dica e das marcas de
  frame.
- **Quick edit:** a edição é uma receita aplicada na hora de tocar e exportar (composição do
  AVFoundation + compositor próprio com Core Image), nunca um arquivo novo. A timeline é uma lista de
  pedaços do original (`EditTimeline`, a única fonte de verdade da prévia, da timeline, do desfazer e
  do export): o trim move o começo do primeiro e o fim do último, Remove
  part corta um trecho do tempo editado (`removeEdited`, dois cortes e uma remoção), Cut divide uma
  seção no playhead, Delete tira a selecionada, e as sugestões do Clean Up saem do mesmo jeito.
  Clean Up só sugere (`CleanUpSuggestion`, com status pending / kept / removed): nada sai sem o
  criador revisar, uma pausa pode ser intencional e "like" pode ter sentido. As pausas vêm do volume
  (`SilenceDetector`, a partir de 0,3 s; "Ignore pauses under" escolhe quais aparecem); filler words
  (`FillerWordDetector`) e possíveis regravações (`RetakeDetector`: frases como "deixa eu falar de
  novo" e palavras repetidas) vêm da transcrição no idioma do roteiro (`CleanUpAnalyzer`). Pausas
  longas e sons como "um" são de alta confiança e entram no "Remove all"; pausas curtas, palavras que
  só às vezes são vício e regravações esperam o criador ouvir. O v9 pede comparar a transcrição com
  o roteiro e usar o Foundation Models nos casos ambíguos; por enquanto as regravações vêm das frases
  e repetições, e os ambíguos ficam de fora do "Remove all". Cada passo do desfazer guarda a timeline
  e as decisões juntas (`EditSnapshot`). A prévia toca a edição com as pontas crescidas até o original inteiro e
  segura a reprodução entre as alças, então arrastar uma alça mostra o frame real sem reconstruir
  nada. As alças atravessam cortes (`EditTimeline.trimStart/trimEnd`): cada passo do arraste parte
  da timeline do começo do arraste (`trimOrigin`), as seções que a alça passa saem, e num corte que
  não removeu nada a alça cai exatamente onde está o dedo (num trecho removido, no começo da seção
  seguinte). Cada corte guarda a transição da seção que começa nele (`EditSegment.transitionIn`,
  `EditTransition`: `hardCut` = "None", `dissolve`, `fade`); a primeira seção é sempre corte seco,
  e a transição sai com o corte quando um trim ou Delete o elimina. `TransitionWindow` coloca cada
  transição na edição (centrada no corte, sem mudar a duração); o compositor escurece o frame no
  Fade (e o som mergulha junto no lugar do mergulho de 12 ms) e, no Dissolve, lê uma segunda trilha
  de vídeo que tem o outro lado do corte (a seção que entra antes do seu começo, a que sai depois do
  fim, frames reais do original) e mistura as duas. Um Dissolve num corte que não removeu nada não
  aparece (os dois lados são o mesmo vídeo) e a dica diz isso. A arquitetura deixa pronto um futuro
  **Smooth Cut** (zoom leve ou reenquadramento para suavizar um jump cut de talking-head): é mais um
  caso de `EditTransition` e um ramo no compositor. O export junta os mesmos pedaços, com um mergulho de 12 ms no som em cada corte que removeu
  algo (sem clique). O prompt da v9 pede passthrough quando só há cortes; o app sempre renderiza
  (mantendo resolução e fps), porque o mergulho no som, o recorte do frame e o Enhance voice (ligado
  por padrão) precisam de uma nova codificação. Um rascunho guarda a edição, o playhead e o histórico enquanto a tela está
  aberta e quando se sai com Cancel; ao voltar, "Draft restored". O relógio usa `DurationText.timecode`
  (00:04.32 abaixo de 10 min, 00:12:04 a partir de 10 min). "Enhance voice" e
  "Reduce background noise" são aproximações com EQ e dinâmica no `AVAudioEngine` (não há API da
  Apple de redução de ruído para arquivo). Os filtros usam Core Image e ficam próximos, não
  idênticos, aos do protótipo. As legendas usam o texto do roteiro com o tempo do `SpeechAnalyzer`;
  sem modelo para o idioma, são distribuídas pela duração.
- **Takes sem roteiro:** o protótipo marca gravações freestyle como Reels; aqui elas aparecem como
  "Freestyle" (sem plataforma) e cada uma é um vídeo próprio.
- **Take:** o arquivo é guardado pelo nome (`fileName`), não por URL, porque o caminho do container
  muda entre instalações; `recordedAt` é o "createdAt" do pedido.
- **Filtros de plataforma:** como no protótipo, All + TikTok, Reels, Shorts, YouTube e LinkedIn;
  Stories ganha chip só quando algum script é para Stories (roteiros de 8–15 s são raros).
- **Share to:** não há API pública para publicar direto no TikTok, Reels, Shorts ou LinkedIn sem SDK
  de terceiros. Tocar numa plataforma exporta, salva o vídeo no Fotos e abre o app dela (URL scheme)
  para postar; sem o app, abre a share sheet do sistema. "Burn in captions" usa as legendas da edição
  ou, se a take nunca foi legendada, gera na hora só para essa exportação. 4K mantém a resolução
  gravada (uma take 1080p não é ampliada) e está em todos os planos.
- **Regras remotas:** o protótipo diz "presets update automatically". Sem backend, a atualização é
  um JSON estático opcional (ver 5.1); até a URL existir, as regras mudam com o app.

## 10. Do's & don'ts

- ✅ Uma ação primária amarela por tela. ✅ Destino sempre visível com seu ponto colorido.
- ✅ Cores, fontes e raios só dos tokens. ✅ Confirmações curtas em toast.
- ❌ Valores hex, fontes ou raios soltos em `Screens/`. ❌ Prometer no paywall o que não existe.
- ❌ Hooks, piadas ou CTAs em formatos sérios.

## 11. Checklist de UI

- [ ] Tokens do `DesignSystem/`; nenhum valor solto
- [ ] Estados vazio, carregando e erro
- [ ] Textos localizáveis; labels e identifiers de acessibilidade
- [ ] Reduce Motion respeitado
- [ ] Este documento atualizado
