# Cue Studio — Design

Fonte de verdade do design. Atualize junto com a UI (ver `ARCHITECTURE.md`, seção 5).

Origem: projeto "iOS Teleprompter App Design" no Claude Design, arquivo `Cue Teleprompter v6.dc.html`
(cópia local em `design/`, fora do git). A v1 do app seguia a v3; a migração para a v6 é feita por fases.

---

## 1. Identidade

**Cue** é um teleprompter para criadores de conteúdo. Script primeiro, câmera depois — ou direto para
a gravação. Cada script carrega o destino ("Create for": TikTok, Reels, Shorts, YouTube, LinkedIn,
Stories), o formato (anúncio,
review, tutorial…) e a estrutura (Hook → Body → CTA).

- Tom: direto, de criador para criador. Frases curtas, sem jargão.
- Marca: três linhas de script com a do meio acesa em amarelo (`CueMark`).
- O teleprompter é sempre grátis; o Pro destrava exportações limpas e IA ilimitada.

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
| `success` | `#34C759` | Toggles |
| Plataformas | TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6961` · YouTube `#FF9F0A` · LinkedIn `#0A84FF` · Stories `#FF375F` | Ponto que marca o destino |
| `safeZoneLine` / `safeZoneLabel` | branco 22% / 50% | Zonas seguras tracejadas sobre a câmera |

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
`slider.horizontal.3` ajustes de câmera · `timer` contagem · `star.fill` melhor take.

## 3. Componentes (`DesignSystem/`)

| Componente | Uso |
|------------|-----|
| `CueStudioButtonStyle` (`.cuePrimary()`, `.cueSecondary()`, `.cueTinted()`, `.cueOutline()`, `.cueGlass()`) | Botões em cápsula; um primário por tela |
| `CueIconButtonStyle` (`.cueIcon(.glass/.overlay/.surface/.tinted/.accent)`) | Botões redondos |
| `surfaceCard()` / `GroupedCard` | Cards e grupos de linhas com separadores |
| `FilterChip`, `TagPill`, `ColorDot` | Chips de filtro/opção, tags, ponto do destino |
| `SelectableCard` | Tiles selecionáveis (fontes, enquadramento, formato, plano) |
| `ValueSlider`, `SwatchButton`, `UsageMeter` | Sliders com valor, amostras de cor, medidores |
| `SheetHeader`, `SectionHeading` | Cabeçalho de sheet e de grupo |
| `FlowLayout` | Chips que quebram linha (nichos, frases) |
| `ToastView` | Confirmação curta no topo (`ToastService` + `.toastHost()`) |
| `CueMark`, `CameraFeedPlaceholder` | Marca e fundo quando não há câmera |
| `RecordGlyph` | Anel branco com ponto vermelho da aba Record (imagem com cores originais) |
| `fittedSheet()` | Sheet da altura do conteúdo, raio 38 (New script, Start recording) |
| `PromptCard` (`Screens/Shared/PromptCard`) | Caixa de Prompt em destaque: selo Apple Intelligence, exemplo e botão enviar |

## 4. Telas

| Tela | Onde | Conteúdo |
|------|------|----------|
| Scripts (home) | `Screens/Scripts` | "+" no topo (abre New script), título + resumo, busca, chips (All, destinos, pastas), card "Last edited", lista "All scripts" com swipe (Record / More / Delete), segurar mostra preview + menu, modo de seleção com barra (mover, duplicar, apagar) |
| Primeiro uso | `EmptyLibraryView` | "Start with a script." + caixa de Prompt + Write / Import / Generate with AI + "Record without a script" |
| Script (leitura) | `Screens/ScriptDetail` | Título, destino/formato/preset, medidor de duração, faixa de blocos, aviso de hook, banner laranja de checagem de fatos ("Checked" dispensa), texto com blocos e cues, takes, Studio mode + Record |
| Script (edição) | `ScriptEditorView` | Título, faixa de blocos, editor com Writing Tools, painel com aviso de versão, atalhos de IA ("In my voice" + os do formato) e medidor |
| Create for | `DestinationSheet` | 6 plataformas com resumo do preset (formato · qualidade · safe zones · ideal) + "Monetization goals". Escolher mostra o toast "Create for {plataforma}" |
| Hooks | `HooksSheet` | Hook atual + 3 opções escritas pelo modelo no aparelho (sem ele, as do formato) + "More options" |
| New script | `NewScriptSheet` | Caixa de Prompt + grade Write / Import / Themes / Formats. Sobre a câmera, Paste no lugar de Write |
| Start recording | `StartRecordingSheet` | "Read from a script" (4 recentes com duração), "+ New script", "Record without a script →". Sobre a câmera vira "Add a script", sem o freestyle |
| Importar | `ImportScriptSheet` | Files, Scan (câmera de documentos), Photo e Clipboard. Scan, Photo e PDFs escaneados passam por OCR do Vision no aparelho |
| Gerar com IA | `GenerateScript/` | "Generate with AI · Apple Intelligence · private · no cost" + abas **Prompt** (texto livre, exemplos, Create for, Length, "Write in my voice", aviso de fatos), **Themes** (6 ideias do nicho, "New ideas", "Use" preenche o Prompt) e **Formats** (8 formatos; Sponsored ad é PRO) → briefing |
| Selfie | `Screens/Prompter/Selfie` | Câmera em primeiro plano; painel do texto na posição e altura do preset (largura 50–75%, padrão do preset; fundo preto 25%; desfoque opcional da câmera); topo: fechar, Selfie \| Studio e o chip "{Plataforma} · 9:16" (abre Create for; em freestyle troca o enquadramento); barra de vidro: Voice Following \| Steady, velocidade ou "Listening/Paused", voltar ao topo, play, Aa; câmera: última take, ajustes, gravar, virar, timer |
| Studio | `Screens/Prompter/Studio` | Prompter em tela cheia sem câmera, barra de progresso no topo, fechar, Selfie \| Studio e espelhar; barra: Voice Following \| Steady, slider de velocidade (no Voice Following, "Listening/Paused" e "Speed follows your voice"), voltar ao topo, 3 linhas para trás/frente, play grande amarelo e Aa |
| Display | `DisplaySettingsSheet` | "Display · ● Live preview". Quick: AI Coach, Text size, Reading width, Reading line (Top/Bottom), Background opacity, Camera blur (Off/Low/Medium/High) — no Studio, Background color no lugar dos três do Selfie. Advanced (recolhível): fonte, espaçamento, margens, alinhamento, cor, linha de leitura, espelhar. No Selfie, a altura máxima para logo abaixo do painel |
| Câmera | `CameraSettingsSheet` | Lente, enquadramento, resolução, fps, grid, safe zones, estabilização, microfone, contagem, formato. No Selfie com script, a sheet para logo abaixo do painel do texto (não cresce além dele) e não escurece o fundo |
| Revisão do take | `Screens/TakeReview` | Vídeo no formato da take (barras pretas fora do 9:16); topo: voltar, "Take N · 0:44", estrela e lixeira; filmstrip, título (+ EDITED), meta, aviso de exportações; faixa "Your takes · N" (troca de take, "Tap ☆ to pick your best"); Retake · Save · Share (Share amarelo). Só uma melhor take por roteiro |
| Quick edit | `Screens/QuickEdit` | Cancel / "Quick edit 1:04 → 0:58" / Done; prévia ao vivo no formato; Trim (alças amarelas, playhead, Split, Delete da seção, "Remove silences"), Audio (volume 0–150%, Enhance voice, Reduce background noise), Adjust (exposição, contraste, temperatura −100…+100, Auto), Filters (Original, Vivid, Warm, Cool, Mono, Film), Crop (9:16, 4:5, 1:1, 16:9, arrastar, Reset), Captions (do roteiro, sincronizadas à fala; Classic, Bold, Highlight; Top, Middle, Bottom). Done guarda a receita (`TakeEdit`), a nova duração e marca Edited; o arquivo original não muda |
| Takes | `Screens/Takes` | "Takes" + "N takes · N videos"; chips de plataforma e All takes / ★ Best / Not shared / Edited; seções Today / Yesterday / Earlier; cada linha é um vídeo (takes do mesmo roteiro): miniatura no formato certo com estrela e duração, plataforma · formato · qualidade, quando, chips "3 takes · Best: Take 3", "Edited", "Not shared" |
| Profile | `Screens/Profile` | Card do criador, plano e uso, Creator DNA, ajustes, privacidade |
| Paywall | `Screens/Shared/Paywall` | Contexto (perfil, exportação, IA), benefícios, planos, Restore/Terms |

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
`PlatformRulesService`): formato, qualidade, faixa ideal (com e sem monetização), mínimo que
monetiza, posição do painel do Selfie (topo, altura, largura) e zonas seguras. As medidas de layout
são pontos na tela de referência 402 × 874 (iPhone 17) e escalam com a tela real.

| Plataforma | Formato | Qualidade | Ideal | Mínimo (monetização) | Painel (topo · altura · largura) |
|---|---|---|---|---|---|
| TikTok | 9:16 | 1080p30 | 1:00–1:30 (sem metas: 0:15–1:00) | 1:00 | 118 · 280 · 58% |
| Reels | 9:16 | 1080p30 | 0:15–1:00 | — | 104 · 290 · 60% |
| Shorts | 9:16 | 1080p60 | 0:30–1:00 | — | 104 · 262 · 60% |
| YouTube | 16:9 | 4K24 | 8:00–15:00 (sem metas: 4:00–10:00) | 8:00 | 104 · 210 · 70% (na faixa preta) |
| LinkedIn | 4:5 | 1080p30 | 0:30–1:30 | — | 196 · 240 · 64% |
| Stories | 9:16 | 1080p30 | 0:08–0:15 | — | 150 · 264 · 56% |

O arquivo tem `revision`. Quando `AppLinks.platformRules` aponta para uma cópia publicada (um JSON
estático), o app baixa uma vez por abertura e só adota uma revisão maior, completa e do mesmo
`schemaVersion`; a cópia fica em cache. Sem URL, vale o arquivo do app.

## 6. Estados

- **Vazio:** biblioteca vazia (primeiro uso), filtro sem resultado ("No scripts here yet."), sem
  takes ("No takes yet" + "Record a take"), script vazio ("This script is empty…").
- **Carregando:** "Writing your script…" com brilho pulsante; indicadores nos chips de IA e nos
  botões Save/Share durante a exportação.
- **Erro / indisponível:** câmera sem permissão (botão para Ajustes), sem câmera, câmera parada;
  Apple Intelligence indisponível (explica e usa o rascunho estruturado); importação ilegível;
  compra pendente ou não verificada.

## 7. Movimento

- Sheets e toasts com mola curta (0,25–0,36 s). Contagem regressiva com "pop".
- Rolagem do prompter por `CADisplayLink`, calibrada para 150 palavras/min em 1,0×.
- Voice follow: o texto desliza até a próxima palavra a ler (aproxima ~2/3 do caminho em 0,35 s),
  nunca para trás; a linha lida fica centrada na guia.
- **Reduce Motion:** toasts só com fade, contagem sem escala, barras de voz e ponto de gravação
  sem animação contínua, "Writing your script…" sem pulsar.

## 8. Acessibilidade

- Botões só com ícone têm `accessibilityLabel`; toggles e opções marcam `.isSelected`.
- Cards e linhas combinam os filhos em um elemento; tiles de take leem "Take 3, 0:44, best take".
- Prompter: ajustável com VoiceOver (desliza 3 linhas), valor = progresso.
- Toasts são anunciados (`AccessibilityNotification.Announcement`).
- Alvos de toque de 44×44 mesmo quando o visual é menor.
- Identificadores para UI tests: `"<tela>.<elemento>"` (ex.: `hero.recordButton`, `editor.doneButton`).

## 9. Diferenças em relação ao protótipo

O protótipo simulava várias coisas; o app implementa de verdade ou deixa de fora o que não existe:

- **IA:** só Apple Intelligence (Foundation Models), sem custo e sem backend. No aparelho:
  reescritas, tom, hooks, CTA, "Fit to time", "In my voice" e ideias de tema. Private Cloud Compute:
  o Prompt livre (temas factuais incluídos); se o PCC não estiver disponível (ou falhar), o modelo do
  aparelho escreve e o aviso de fatos continua. Os roteiros saem estruturados (`@Generable`
  `ScriptDraft`: título + blocos), com o Creator Voice nas instructions quando "Write in my voice"
  está ligado. Prompts factuais (história, ciência, "como surgiu…") ganham `factCheck`.
- **Sem Apple Intelligence:** Prompt e as reescritas mostram "Requires Apple Intelligence" e ficam
  desligados; Formats continua gerando o rascunho estruturado a partir do briefing (é um modelo de
  texto, não IA); Themes mostra as ideias locais. O teleprompter não depende de IA.
- **Uso de IA:** ilimitado no grátis (o v1 tinha 5 roteiros/mês). Só o formato Sponsored ad é Pro.
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
- **Conta:** não existe login. O card do perfil é local (nome e @ editáveis); não há "Sign out".
- **Paywall:** só lista o que o Pro realmente destrava (exportações limpas e IA). Itens do protótipo
  como controle pelo Apple Watch e sincronização com iPad/Mac ficaram de fora.
- **"Save takes to Photos":** removido — salvar automaticamente contornaria o limite de exportações
  limpas. Takes ficam no app; Save/Share exportam.
- **Pastas:** o "+" agora abre New script, então pastas nascem em "Move to a new folder…" (menu do
  script, More e barra de seleção) e aparecem como chips depois dos destinos.
- **Tab bar:** a pill flutuante do protótipo é a própria tab bar nativa de Liquid Glass. A aba
  Record usa `RecordGlyph`, uma imagem com cores originais, porque SF Symbols viram monocromáticos
  na tab bar.
- **New script sobre a câmera:** não há editor no prompter, então o tile Write vira Paste.
- **Desfoque da câmera:** o protótipo usa um blur contínuo de 0 a 20; o app usa os materiais do
  sistema atrás do painel (Low/Medium/High), que desfocam o preview e nunca a gravação.
- **Painel do YouTube:** a câmera preenche a tela com o sensor 9:16, então a faixa preta do 16:9 é
  mais baixa que no protótipo; o painel encolhe para caber nela (mínimo 120 pt).
- **Quick edit:** a edição é uma receita aplicada na hora de tocar e exportar (composição do
  AVFoundation + compositor próprio com Core Image), nunca um arquivo novo. "Enhance voice" e
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
