# Cue Studio — Design

Fonte de verdade do design. Atualize junto com a UI (ver `ARCHITECTURE.md`, seção 5).

Origem: projeto "iOS Teleprompter App Design" no Claude Design, arquivo `Cue Teleprompter v6.dc.html`
(cópia local em `design/`, fora do git). A v1 do app seguia a v3; a migração para a v6 é feita por fases.

---

## 1. Identidade

**Cue** é um teleprompter para criadores de conteúdo. Script primeiro, câmera depois — ou direto para
a gravação. Cada script carrega o destino (TikTok, Reels, Shorts, YouTube), o formato (anúncio,
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
| Plataformas | TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6961` · YouTube `#FF9F0A` | Ponto que marca o destino |

### Tipografia

- Interface: SF Pro com Dynamic Type (`.largeTitle` 34, `.title2` 22, `.title3` 20, `.body` 17,
  `.subheadline` 15, `.footnote` 13, `.caption` 12).
- Prompter (tamanho fixo, controlado pelo slider 16–56 pt; Studio usa 1,35×):
  **Lexend** (padrão), **Atkinson Hyperlegible** ("Legible"), **New York** ("Serif"),
  **SF Rounded** ("Rounded"). Lexend e Atkinson estão em `DesignSystem/Fonts/` (OFL) e são
  registradas no launch.
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
| Script (leitura) | `Screens/ScriptDetail` | Título, destino/formato/preset, medidor de duração, faixa de blocos, aviso de hook, texto com blocos e cues, takes, Studio mode + Record |
| Script (edição) | `ScriptEditorView` | Título, faixa de blocos, editor, painel com aviso de versão, ferramentas de IA e medidor |
| Destino | `DestinationSheet` | 4 destinos com preset + meta de monetização |
| Hooks | `HooksSheet` | Hook atual + 3 opções + "More options" |
| New script | `NewScriptSheet` | Caixa de Prompt + grade Write / Import / Themes / Formats. Sobre a câmera, Paste no lugar de Write |
| Start recording | `StartRecordingSheet` | "Read from a script" (4 recentes com duração), "+ New script", "Record without a script →". Sobre a câmera vira "Add a script", sem o freestyle |
| Importar | `ImportScriptSheet` | Files e área de transferência |
| Gerar com IA | `GenerateScript/` | Formato (8) → briefing em tópicos, destino, tom, frases → rascunho |
| Selfie | `Screens/Prompter/Selfie` | Câmera, painel do prompter, grid, barras de enquadramento, safe zones, barra de controles |
| Studio | `Screens/Prompter/Studio` | Prompter em tela cheia, progresso, velocidade (no Voice follow, o status da escuta), pular linhas, espelhar |
| Display | `DisplaySettingsSheet` | Fonte, tamanho, espaçamento, margens, alinhamento, cor, fundo, rolagem, guia, espelhar, cues |
| Câmera | `CameraSettingsSheet` | Lente, enquadramento, resolução, fps, grid, safe zones, estabilização, microfone, contagem, formato. No Selfie com script, a sheet para logo abaixo do painel do texto (não cresce além dele) e não escurece o fundo |
| Revisão do take | `Screens/TakeReview` | Vídeo, filmstrip, melhor take, Retake / Save / Share, aviso de exportações |
| Takes | `Screens/Takes` | Takes agrupados por script |
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

- **IA:** Foundation Models on-device (nada sai do aparelho). Sem Apple Intelligence, "Generate"
  monta o rascunho estruturado a partir do briefing, e as ferramentas de reescrita explicam por que
  estão indisponíveis. "Add disclosure" e "3 new hooks" não precisam de modelo.
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
