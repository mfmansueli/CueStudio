# Cue Studio — Design

Fonte de verdade do design. Atualize junto com a UI (ver `ARCHITECTURE.md`, seção 5).

Origem: projeto "iOS Teleprompter App Design" no Claude Design, arquivo `Cue Teleprompter v9.dc.html`
(cópia em `design/`, com o prompt `Claude Code Prompt.md`). A v1 do app seguia a v3; a v6 veio por
fases; a v7 mudou a tela de gravação (frame real, zonas seguras em VideoSpace, linha de leitura,
janela de texto, Hide UI) e a escala de velocidade; a v9 abre todos os recursos no grátis (só a
exportação tem limite), refaz o Quick edit (Remove part, aba Clean Up) e simplifica a janela de texto.
O **editor v10** (`design/editor-v10/Cue Editor v10.dc.html`, com `support.js`, `assets/` e o prompt)
troca a interface do Quick edit: timeline com playhead central fixa, ferramentas por contexto e
painéis com altura calculada pela área útil; o motor (receita, prévia, export, Clean Up) continua.
A **v12** (`Projeto de design.zip` › `Cue App v12.dc.html`, com `CueScriptEditorEmbed.dc.html` e
`CueEditorEmbed.dc.html`; cópia do zip em `design/`) alinha o protótipo ao app e refina duas telas: o
**editor de roteiro** (leitura com "Improve script", escrita focada com uma barra só acima do teclado)
e o **editor de vídeo** (faixas com fundo e ícone, dicas nas faixas vazias, Delete fixo, Adjust com
régua). A direção de produto (`DESIGN_DIRECTION.md` do projeto de design) vale para toda decisão de UI.
A **v26** (`design/design_handoff_cue_v26/`: `README.md`, `CUE_WORKFLOW.md`, `CUE_COLORS.md`, protótipo) troca a
identidade para **Night Session** (fundo índigo-preto, superfícies com tom violeta, camada de IA em
violeta) e chega por fases; as **fases 1 a 7** (tokens, nomes, recorder, Takes e revisão, editor, página do script,
My Cue Voice, Profile, Settings e Pro) estão feitas, e o que falta está nas seções 2 e 9 ("v26").

A **v27 — Cue Universe** (`design/cue-universe-v27/`: `01 Direção de design`, `06 Specs/DESIGN-SPEC.md` e `SCREENS.md`, os
boards em HTML/PNG, os ícones e os prompts) substitui a identidade pela metáfora do universo: o app é **só escuro** (a seção 2
sobre o modo claro, a fase 8 da v26 e o ajuste Appearance **saíram**), a IA é violeta, o amarelo é ação e sinal, o vermelho é só
gravação, cada **tópico** é um mundo (cor) e cada **plataforma** é uma galáxia. O que mudou e por quê está na **seção 12**; onde
esta seção diz "claro" ou "Appearance", vale a 12.

A **v29** (`design/cue-v29/`: `01-Direction.md`, `02-Tokens.md`, `03-Screen-map.md`) leva o protótipo v28 ao app em fases. A **fase 1 (fundação)**
está feita e está na **seção 13**: onde esta seção e a 12 falam do orb que viaja na tab bar, do `OrbSlider` (planeta, trilha de luz) ou dos
ícones como assets, vale a 13.

---

## 1. Identidade

**Cue** é um teleprompter para criadores de conteúdo. Script primeiro, câmera depois — ou direto para
a gravação. Cada script carrega o destino ("Create for": TikTok, Reels, Shorts, YouTube, LinkedIn,
Stories), o formato (anúncio,
review, tutorial…) e a estrutura (Hook → Body → CTA).

- Tom: direto, de criador para criador. Frases curtas, sem jargão.
- **Inteligente, nunca controlador.** O **Creator Setup** é "o que você costuma usar"; a
  recomendação da plataforma é "o que recomendamos para este conteúdo"; quando os dois divergem,
  "você escolhe". Uma recomendação nunca muda o Creator Setup, e o criador sempre vê de onde vem cada
  valor da gravação.
- Marca: três linhas de script com a do meio acesa em amarelo (`CueMark`).
- **Nenhum recurso fica bloqueado.** Teleprompter, roteiros, toda a IA (Apple Intelligence, sem custo
  por uso), My Cue Voice, Quick edit (com as ferramentas de criador: texto, mídia, voice-over,
  velocidade, Remove Pauses, estilos, transições e capa), Clean Up, legendas, 4K, versões e melhor
  take são grátis. O
  único limite é **exportar vídeos**: 5 exportações grátis (salvar no Fotos ou compartilhar), sem marca
  d'água; depois, o paywall oferece 7 dias grátis no mensal ou no anual. Gravar, editar e escrever
  nunca param, e as takes nunca são apagadas nem bloqueadas (`UsagePolicy`, `UsageQuotaService`).
  O contador fica no Keychain, então reinstalar não zera. Não há badges "PRO" nem marca d'água.

## 2. Aparência

**O app é só escuro** (v27 "Cue Universe"): a noite é a identidade. `UIUserInterfaceStyle = Dark` no Info.plist e
`.preferredColorScheme(.dark)` na raiz (`RootView`); não há mais **Settings › Appearance**, `AppearanceService`,
paleta clara nem `.videoContext()`. Câmera, prompter, revisão da take, Quick edit e o Remote já eram escuros; agora
tudo é. Todos os pares de cores passam nas regras de contraste da Apple, com e sem Increase Contrast (seção 8,
"Contraste"; `PaletteContrastTests` falha quando um sai do mínimo). Os valores claros da v26 (fundo `#F4F5FA`, cards
brancos, ouro escuro `#7A5C00`, os cards de IA em violeta sólido) saíram junto: ver o histórico do git.

**Papéis das cores** (valem em toda tela): **amarelo `#FFD60A` é ação e sinal** (botão primário, linha de leitura,
orbs, aba ativa), **violeta `#B4A7FF` é IA**, **vermelho é só gravação**, **verde é pronto**, **ciano é em edição**;
**temas são mundos** (âmbar, menta, rosa e azul-céu) e **redes são galáxias** (cores por plataforma). O céu estrelado
(`StarfieldView`, `skyBackground()`) só aparece nas telas de navegação e no onboarding: **nunca sobre a câmera, uma take
ou o editor**.

### Cores (`Palette`)

| Token | Escuro | Uso |
|-------|--------|-----|
| `bg` | `#0A0B12` | Fundo das telas (Night Session) |
| `surface` | `#161826` | Cards, linhas agrupadas, sheets |
| `surface2` | `#1F2236` | Controles e linhas dentro de cards/sheets |
| `surface3` | `#2B2F48` | Tiles um nível acima de `surface2` (destinos de compartilhamento, "More"); derivado, não está na v26 |
| `surfaceMuted` | `#1B1D2E` | Formatos sérios (pedido de desculpas) |
| `fill` | `#6E7496` 26% | Chips inativos, trilho dos segmentados, botões redondos, trilhos de medidores |
| `chipOn` / `chipOnInk` | branco / preto | Chip de texto selecionado (`FilterChip`): nunca amarelo |
| `segmentOn` · `segmentShadow` | `#636366` | Segmento ativo (Voice \| Steady, `PanelSegmented`) |
| `glassFill` · `glassBase` | `#0E101C` 72% / opaco | Vidro noturno das barras e controles flutuantes (`GlassNight`: 60% / 72% / 88% sobre vídeo, sempre 94% no claro) |
| `overlayFill` | branco 10% | Botões sobre a câmera/prompter; item aberto da barra do editor de roteiro |
| `neutralAction` | `#636366` | Swipe "More" |
| `glassBorder` | violeta `#B4A7FF` 22% | Borda de 0,5 pt das superfícies de vidro |
| `separator` | `#505678` 50% | Separadores de 0,5 pt |
| `ink` / `ink2` / `ink3` | branco / `#E1E4F5` 62% / 45% | Texto principal; texto secundário (4,5:1 em toda superfície); o que não precisa ser lido (chevrons, contornos, desligado, 3:1) |
| `acc` | `#FFD60A` | Acento como **preenchimento**: ação primária, hook, guia de leitura |
| `accText` / `warnText` / `dangerText` / `infoText` / `successText` | escuro: o próprio acc/warn/`#FF8078`/info/success | Amarelo, laranja, vermelho, azul e verde **como texto ou ícone**: os preenchimentos somem sobre o branco, estes passam 4,5:1 nas superfícies do app. Com Increase Contrast ficam um degrau mais fortes |
| `inkHint` | `#E1E4F5` 55% (72% com Increase Contrast) | Dicas pequenas e rótulos mono (v27: nunca abaixo de 55% sobre `bg`, uns 5:1) |
| `worldWarm` / `worldMint` / `worldPink` / `worldSky` | `#FFC46B` / `#7EE0B8` / `#FF9BD2` / `#8FB8FF` | **Temas = mundos**: a cor de cada tema do criador (até três, nessa ordem); ponto de cor nos roteiros, órbitas do onboarding |
| `accInk` | `#000000` | Texto sobre `acc` |
| `accAction` | `#8A6500` (igual nos dois) | Fundo do swipe "Record" sob texto branco (5,3:1; o `acc` dá 1,4:1) |
| `insetField` / `insetShade` / `swatchRing` | preto 38% / preto 38% / branco 25% | Poço do campo do Prompt, a sombra móvel do brilho dourado e o anel das amostras de cor |
| `accSoft` | `#FFD60A` 16% | Fundos tingidos (tags de cue, botões secundários de gravação) |
| `accWash` → `accWashFaint` / `accBorder` | `#FFD60A` 22% → 5% / 38% | Card da recomendação (This take), plano escolhido e brilho do paywall, tira "Your takes" |
| `accGlow` → `accGlowFaint` | `#FFD60A` 14% → 2% | Toque de amarelo do card do plano Pro (Profile) e do paywall |
| `aiText` / `aiTextStrong` | `#B4A7FF` / `#E4DEFF` | **Violeta é IA**: ✦, My Cue Voice, Smart, sugestões; texto e ícone (4,5:1 em toda superfície) |
| `aiFill` · `aiBorder` · `aiGlow` → `aiGlowFaint` | `#9D8CFF` 17% · `#B4A7FF` 30% · `#9D8CFF` 20% → 2% | Chips e tiles de IA, borda do card de IA, brilho do card (Your setup, plano Pro) |
| `auroraViolet` / `auroraIndigo` · `auroraBorderLight` · `auroraScanLine` | `#9D8CFF` 30% / `#5E4EE0` 30% · `#B4A7FF` · `#FFD60A` | Aurora do card de ideias (Scripts) e do "Sounds like you" (Profile): o violeta e o índigo que deslizam sobre o fundo, o reflexo que percorre a borda e a **linha de varredura amarela** de 1,5 pt na base (12 s para cruzar; parada e discreta no meio com Reduce Motion) |
| `record` | `#FF3B30` | Botão de gravar, badge de gravação |
| `danger` / `dangerFill` | `#FF453A` / `#D70015` | Ações destrutivas (ícone); fundo do botão que remove, sob texto branco (5,4:1) |
| `warn` | `#FF9F0A` | Fora da faixa ideal, hook longo, aviso de monetização |
| `info` | `#64D2FF` | Aviso de nova versão no editor |
| `success` | `#34C759` | Toggles, "Kept" no Clean Up, ponto do microfone conectado |
| Plataformas (galáxias) | TikTok `#64D2FF` · Reels `#BF5AF2` · Shorts `#FF6B5A` · YouTube `#FF9F0A` · LinkedIn `#0A84FF` · Stories `#FF6FA8` | Ponto que marca o destino |
| `recommendationTop` → `recommendationBottom` · `recommendationRim` · `recommendationIconFill` / `recommendationIcon` · `recommendationShadow` · `warningCard` | `#3E3096` 90% → `#1E1650` 90% · `#C4B8FF` 45% · `#C9BEFF` 20% / `#C9BEFF` · `#1E0F64` 50% · `#161826` 97% | Cartão de recomendação da plataforma (violeta, as linhas em `aiTextStrong`) e o aviso de parada sobre a câmera |
| `posterPill` | `#0E101C` 70% | A pílula escura sobre um pôster (a etapa, "×3"); o texto nela é claro |
| `frameMask` / `frameEdge` | preto 60% / branco 22% | Fora do frame gravado / bordas de 0,5 pt do frame |
| `safeZoneLine` / `safeZoneLabel` | branco 40% / 62% | Contorno tracejado da área segura e a legenda |
| `safeZoneShade` → `safeZoneShadeFaint` / `safeZoneSide` | preto 40% → 10% / 16% | Faixas de risco (degradê em cima e embaixo, sombra nas laterais) |
| `readingLineGlow` | `#FFD60A` 45% | Brilho da linha de leitura sobre a câmera |
| `readingLineHandle` / `…Active` / `…Border` | `#1E1E20` 55% / `#FFD60A` 55% / branco 28% | Alça da linha (em repouso / arrastando) |
| `stopButtonRing` / `stopButtonFill` | branco 85% / preto 18% | Botão de parar mínimo (controles escondidos) |
| `editorPanel` · `editorSeparator` · `editorToast` · `editorBarButton` | `#0E101C` · `#505678` 50% · `#1F2236` 96% · `#2B2F48` 70% | Editor: painéis, separadores, toast (com estrela amarela) e botões da barra superior |
| `laneText` / `laneTextSelected` + `laneTextInk` · `laneCaption` + `laneCaptionInk` · `laneMusic` + `laneMusicInk` · `laneVoiceOver` + `laneVoiceOverInk` · `laneMedia` + `laneMediaInk` · `laneRecording` | branco 20% / 32% + branco · `#9D8CFF` 30% + `#C9BFFF` · `#34C759` 30% + `#7CE59A` · `#FF9F0A` 30% + `#FFB340` · `#64D2FF` 30% + `#9FE3FF` · `#FF453A` 50% | Faixas da timeline (v26): **Aa branco, legendas violeta, música verde, voice-over âmbar, mídia azul-claro**; fundo + texto numa cor mais clara (4,5:1 sobre as duas faixas, `PaletteContrastTests`) |
| `pauseRemoveStripe`/`Gap` · `pauseKeepStripe`/`Gap`/`Border` | amarelo 62% / 20% · branco 25% / preto 30% / branco 75% | Pausas na trilha principal: a remover (hachurado amarelo) e a manter (cinza tracejado) |
| `waveformWell` · `waveformBar` · `rulerLabel` · `laneGhostBorder` / `laneGhostInk` · `joinMark` | `#232326` · `#EBEBF5` 55% · `#EBEBF5` 55% · `#EBEBF5` 45% / 70% · preto 60% | Forma de onda, régua, atalhos tracejados das faixas vazias, marca de um corte seco |
| `laneStrip` · `laneStripActive` · `laneStripRing` · `laneGutterInk` · `laneHintInk` · `adjustDialRing` · `selectedRow` | `#1C1C1E` · `#24231C` · `#FFD60A` 75% · `#EBEBF5` 85% · `#EBEBF5` 60% · `#EBEBF5` 35% · `#FFD60A` 8% | Editor v12: faixa de cada track, a mesma com as ferramentas abertas (com anel), ícone da faixa, dica da faixa vazia (o protótipo usa 45%, 3,9:1; 60% dá 5,9:1), anel de um dial de Adjust em zero, linha da lista em que o cursor está |
| `panelCard` · `sliderTrack` (`#6E7496` 45%) · `toggleOff` · `accTile` · `accCard` · `dangerWash` · `presetCardDim` / `presetCardBorder` · `coverDim` | `#767680` 16% · 40% · `#787880` 36% · amarelo 12% · 10% · `#FF453A` 16% · preto 28% / branco 8% · preto 50% | Controles dos painéis: cards, trilho do slider, switch desligado, tile e card escolhidos, lixeira de uma linha, cards de preset, quadro da capa |

Cores de **conteúdo** (queimadas no vídeo, não tokens de interface): os textos do Quick edit usam
`OverlayColor` (texto: branco, `#111`, amarelo, laranja, vermelho, verde, ciano, roxo; fundos: amarelo,
preto, branco, vermelho, azul, papel `#F4EFE6`).

### Tipografia

- Interface: SF Pro com Dynamic Type (`.largeTitle` 34, `.title2` 22, `.title3` 20, `.body` 17,
  `.subheadline` 15, `.footnote` 13, `.caption` 12).
- Prompter (tamanho fixo, controlado pelo slider 16–56 pt; Studio usa 1,35×):
  **Lexend** (padrão), **Atkinson Hyperlegible** ("Legible"), **Source Serif 4** ("Serif"),
  **SF Rounded** ("Rounded"). Lexend, Atkinson e Source Serif 4 estão em `DesignSystem/Fonts/` (OFL)
  e são registradas no launch.
- Textos sobre o vídeo (Quick edit): designs do sistema (Classic = SF Pro, Rounded, Serif = New York,
  Mono), pesos Regular–Heavy, 12–72 pt num quadro de 402 pt de largura (escala com o export).
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
`slider.horizontal.3` ajustes de câmera e Creator Setup ·
`iphone.radiowaves.left.and.right` Remote Control · `qrcode` parear · `timer` contagem · `star.fill` melhor take ·
`mic.fill` / `mic.slash.fill` entrada de áudio.

## 3. Componentes (`DesignSystem/`)

| Componente | Uso |
|------------|-----|
| `CueStudioButtonStyle` (`.cuePrimary()`, `.cueSecondary()`, `.cueTinted()`, `.cueOutline()`, `.cueGlass()`, `.cueLight()`, `.cueDestructive()`, `.cueDestructiveTinted()`; tamanhos compact 34, medium 42, regular 50, large 54) | Botões em cápsula; um primário (amarelo) por tela. Branco (`light`) para a ação principal de uma ferramenta; vermelho para confirmar uma remoção |
| `CueStudioButtonStyle` variante `.ai` (`.cueAI()`) | O botão violeta da IA ("✦ Shape", "✦ Rewrite", "Adjust"): fundo `aiFill`, texto `aiTextStrong` |
| `CueIconButtonStyle` (`.cueIcon(.glass/.overlay/.surface/.tinted/.accent/.light/.danger)`) | Botões redondos |
| `surfaceCard()` / `GroupedCard` | Cards e grupos de linhas com separadores |
| `FilterChip`, `TagPill`, `ColorDot` | Chips de filtro/opção (selecionado = branco com texto preto, `chipOn`), tags, ponto do destino |
| `SelectableCard` | Tiles selecionáveis (fontes, enquadramento, formato, plano): anel amarelo de 2 pt sobre 12% de amarelo |
| `GlassNight` (`.glassNight(in:density:)`) | Vidro noturno de barras e controles flutuantes: `glassFill` + borda de 0,5 pt (`glassBorder`); `thin` / `regular` / `solid` sobre vídeo |
| `HUDLine` | Linha de status em monoespaçada e caixa-alta, com ponto opcional ("● MIC · SETUP ›", "✓ FITS"); amarelo é sinal de HUD (`accText`) |
| `StageBar` | PICK · EDIT · READY · SHARED: só desenha a etapa que recebe; a etapa é derivada das takes (fase 4), nunca marcada à mão |
| `ValueSlider`, `SwatchButton`, `UsageMeter` | Slider nativo com valor (Display, Creator Setup), amostras de cor, medidores |
| `CueSlider` (`CueSliderMath`) | O slider v26: trilho de 4 pt em amarelo (`accText`) e polegar branco de 24 pt, 44 pt de toque, um elemento ajustável para o VoiceOver (passo de 0,1×); onde o controle fica sobre o vídeo (a velocidade do recorder). O Display e o Creator Setup continuam com o `Slider` nativo (VoiceOver e testes de UI) |
| `SettingToggleRow` | Linha de ajuste com título, detalhe e switch verde `#34C759` (`success`, nos dois modos; Display, câmera) |
| `SheetHeader`, `SectionHeading` | Cabeçalho de sheet e de grupo |
| `FlowLayout` | Chips que quebram linha (nichos, frases) |
| `CueIcon` / `CueIconView` (`DesignSystem/Tokens`, `Assets.xcassets/Icons`) | Os **53 ícones "orbit line" da v27** (grade de 24 pt, traço de 1,75 pt, três motivos: o orb, a órbita e a estrela de quatro pontas), como assets vetoriais em template: a cor vem do contexto (62% branco em repouso, amarelo ativo, violeta IA, vermelho só gravação). Gerados dos SVGs de `design/cue-universe-v27/05 Icons/in-app` |
| `OrbSlider` (`DesignSystem/Controls`, `OrbSliderMath`, `OrbThumb`) | **Todo slider do app (v27)**: um planeta dourado de polegar e uma linha de luz de trilho; variantes `.full` (26 pt), `.row` (20 pt) e `.compact` (16 pt, pílula de vidro sobre o vídeo), contínua ou por passos (estrelas marcam cada passo e a mola 0,28/0,72 encaixa), origem à esquerda ou no centro. Segurar faz o orb crescer 14%, aparece o anel de órbita (uma volta a cada 4 s) e o valor acende; **deslizar o dedo para baixo segura a velocidade em ½ e ¼ ("FINE · ½")**; toque duplo volta ao padrão; o padrão tem um tique tátil; tocar no valor abre um campo para digitar. O valor é sempre escrito, o elemento é ajustável para o VoiceOver (um passo, ou 5% do intervalo) e tem foco tracejado ciano. Háptico: seleção a cada passo, impacto suave nos extremos |
| `StarfieldView` / `skyBackground()` (`DesignSystem/Sky`, `StarfieldMath`) | O **céu das telas de navegação**: três camadas de estrelas (16, 12 e 7 por bloco, deriva de 260, 160 e 85 s), 3 a 8 cintilares (metade com o brilho em cruz), uma estrela cadente a cada 11–14 s e uma ou duas nebulosas violeta, num só `Canvas` a 30 fps. Para parado fora da tela, em Low Power Mode, com Reduce Motion ou com o app inativo. Calm (padrão), Lively (dobra) ou Off (Personalize) |
| Efeitos de luz (`DesignSystem/Effects`) | `HorizonLine` (a linha de leitura que respira em 2,4 s), `IgniteEffect` (núcleo 0 → 1,8 → 1, duas ondas e brilho em cruz), `CometTravel` / `CometPlayer` (cometa com cauda ao longo de uma rota), `WordsFromLight` (palavras que nascem da luz, 0,3 s cada, 0,16 s de intervalo, só para o texto que chega da IA), `aiAura(isActive:)` (luz violeta/amarela que gira na borda a cada 2,8 s) e `shineSweep()` (faixa branca de 70 pt a cada 4–8 s, no máximo um por tela). Todos têm versão de fade com Reduce Motion |
| `CueMotion` (`DesignSystem/Motion`) | As durações, molas e curvas da v27 (orb 0,28/0,72, aba 0,35/0,7, luz `(.16,1,.3,1)`, glide `(.45,0,.25,1)`…) e `animation(_:reduced:)` |
| `SearchField` | Busca em cápsula (`fill`, 40 pt) dentro do conteúdo, para quando algo vem acima dela (Scripts) |
| `ToastView` | Confirmação curta no topo (`ToastService` + `.toastHost()`); com `ToastAction` ganha um botão ("Undo", 4 s) |
| `CueMark`, `CameraFeedPlaceholder` | Marca e fundo quando não há câmera |
| `QRCodeView` | QR code nítido em qualquer tamanho, sobre o branco que os leitores precisam (pareamento do remote) |
| `RecordGlyph` | Anel branco com ponto vermelho da aba Record (imagem com cores originais) |
| `fittedSheet()` | Sheet da altura do conteúdo, raio 38 (New script, Start recording) |
| Controles do editor (`Screens/QuickEdit/Panels/Controls`) | `EditorPanelContainer` (título, escopo, Reset, ✓ amarelo de 40 pt, conteúdo que rola e rodapé fixo; Dynamic Type até AX Medium), `PanelSegmented` (escolha em cinza ou amarela; fonte encolhe até 12 pt; 44 pt de alvo), `PanelSlider` (trilho fino, preenchimento amarelo, do centro nos −100…+100), `PanelRulerSlider` (a mesma ideia como régua de 40 passos, a do Adjust), `PanelTiles`, `PanelChips` (família na própria fonte), `PanelSwatches`, `PanelToggleRow`/`PanelSwitch`, `PanelStepper`, `PanelTabs`, `PanelAdvancedButton`, `PanelButton`, `PanelNote`, `PanelInlineList`, `PanelPresetCard`/`PanelSaveStyleCard`; `EditorToastHost` (toast do editor) |
| `PromptCardSurface` / `PromptCardHeader` (`Screens/Shared/PromptCard`) | A moldura do card de IA (aurora violeta, borda de luz e linha de varredura, raio 26) e o cabeçalho com as três estrelas; o `IdeaPromptCard` (campo, ditado, seta) é o card da home de Scripts. O `PromptCard` do New script saiu na v26 |

## 4. Telas

| Tela | Onde | Conteúdo |
|------|------|----------|
| Scripts (home) | `Screens/Scripts` | v26: título grande "Scripts" com a **lupa** (mostra a busca sob o card) e o "+" (abre New script); sob o título, a contagem em amarelo mono ("05 SCRIPTS / 11 TAKES", `HUDLine`); o **card Let’s Cue** (`IdeaPromptCard`, ver Primeiro uso); a lista **Recent** com o menu "All ⌄" (`ScriptFilterMenu`: todos, uma plataforma ou uma pasta) e Select. **Cada linha** (`ScriptRow`) mostra o título (com **"Continue"** amarelo no roteiro editado por último), o ponto da plataforma e o **status** em mono (`ScriptStatus`, derivado, nunca marcado à mão): "READY TO RECORD · 0:20" antes de qualquer take, depois "3 TAKES · READY" na etapa do vídeo (a mesma `TakeStage` do Takes: TO PICK, IN EDIT, READY, SHARED), e os botões redondos Studio mode e Record; swipe (Record / More / Delete), segurar mostra preview + menu, modo de seleção com barra (mover, duplicar, apagar). O card "Last edited" e os chips de filtro saíram |
| Primeiro uso (Scripts sem roteiros) | `EmptyLibraryView`, `IdeaPromptCard`, `MyCueVoiceChip` | O estado de uma biblioteca **carregada e sem roteiros** (não é carregamento, erro nem busca sem resultado; a lista preenchida não muda). O **"+" continua no canto superior direito**, como em todo estado. **Cabeçalho:** "Your next video starts here." (título) e "Turn an idea into a script." (subtítulo), com a quebra natural da tela e do tamanho da fonte. **Card "Let’s Cue" (v26)** (o mesmo `IdeaPromptCard` com e sem roteiros; aurora violeta e linha de varredura, `AuroraCardBackground`): o rótulo mono amarelo "✦ LET’S CUE" (as três estrelas piscam como antes) e, quando ouve, as barras de voz com "Listening…" no fim da mesma linha, então a altura do card nunca muda; um **campo de três linhas** ("Got an idea? Say it or type it — Cue writes the script.", altura fixa que acompanha o Dynamic Type; se escreve e se dita direto nele, sem sheet; um texto maior rola dentro do campo), o microfone discreto e o **botão circular amarelo com seta** (alvo de 44 pt). Abaixo, **quatro chips** (`IdeaCardChip`; duas por linha, uma sobre a outra com texto grande): **"● For TikTok ⌄"** (abre Create for, `AppSheet.createFor`; a escolha vale para esta ideia, `IdeaDraftService.platform`), **"✦ My Cue Voice · Set up"** (violeta, `MyCueVoiceChip`: sem o mínimo do perfil, tocar abre as **quatro perguntas** desde a primeira, ver My Cue Voice; com o perfil pronto o chip passa a dizer só "✦ My Cue Voice" (tocar abre as perguntas de novo, já respondidas, para mudar) e ganha **um switch verde dentro da cápsula** que liga e desliga a voz, o mesmo estado do Profile), **"Need an idea?"** (abre as ideias, `AppSheet.ideas`) e **"Format ⌄"** (abre Format, `AppSheet.format`; o chip passa a dizer o formato escolhido). **A seta escreve a ideia numa página nova** (`ScriptStarter`): abre um roteiro vazio e o Apple Intelligence escreve **na própria página**, em violeta, com Stop (ver Script); a ideia só sai do card quando o roteiro foi escrito (uma falha a mantém para "Try again"). Com o campo vazio (ou só com espaços) a seta é **"Need an idea?"** e abre as ideias; fica desligada enquanto um ditado ainda escreve e, sem Apple Intelligence, com texto digitado (o aviso de sempre, `AIUnavailableNote`, aparece no card; as ideias abrem mesmo assim, e o ↑ delas fica desligado). **Rascunho único** (`IdeaDraftService`, no `AppServices`): o card, as ideias e o formato leem e escrevem **a mesma cópia** (texto, plataforma, duração e formato); só virar um roteiro os limpa. **Ações:** um container cinza de duas linhas, "Write a script" e "Import text"; "Generate with AI" saiu (o card o substitui). **"Record without a script"** é um link discreto (ponto vermelho de 8 pt, alvo de 44 pt). **Ditado da ideia** (`DictationService`, `DictationButton`, `DictationStatusRow`, `DictationNoticeView`; os testes de ditado usam `-uiTestDictation`): falar → ver o texto → revisar → enviar, como num chat, sem tela de chat nem outro serviço de IA, **no próprio card**. Tocar no microfone é o momento de pedir o microfone (nunca antes; negado uma vez, o card explica e leva a Ajustes, sem pedir de novo); o app grava nada em arquivo, não cria take e não envia áudio a lugar nenhum: o reconhecimento é o `SpeechRecognitionManager` (Speech framework, `SpeechAnalyzer`) com **instância e microfone próprios**, separados do prompter. O **idioma ouvido** é o do roteiro que vai ser escrito (`LanguageService.dictationRequest`: Script Language, senão o idioma do que já está digitado com 3+ palavras, senão o da interface; o idioma de Voice Following nunca entra) e **nunca é trocado por outro**: sem o idioma no aparelho, "Dictation can't listen in Thai on this iPhone. You can type your idea instead."; o modelo do idioma pode baixar na primeira vez ("Getting ready", "Downloading 40%"). **Estados:** tocar liga a escuta e o microfone vira **parar** (quadrado vermelho num anel vermelho, como a gravação; um toque, sem segurar, então pausas para pensar não encerram); no lugar da explicação do card (que continua ocupando o seu espaço, então a altura do card não muda quando a escuta começa ou termina), uma linha discreta com 5 barras que seguem a voz (`DictationStatusRow`, `Palette.acc`, paradas com Reduce Motion) e o texto "Listening…" (ou "Getting ready", "Downloading 40%", "Finishing…"); enquanto isso o campo mostra as mesmas palavras só para leitura, na mesma altura, rolando para as mais novas (um campo que não está sendo editado não rola até elas; ditando no meio de um texto, a vista fica onde está) e rolável à mão para reler; **tocar nelas para a escuta e leva o teclado ao campo**, com o cursor depois das palavras. A seta fica **desligada** do começo da escuta até a última palavra ser finalizada: parar fecha o microfone na hora e o reconhecedor fecha as últimas palavras (até 3 s), então o texto é revisável e editável, nunca enviado sozinho; se nada foi dito, "Didn't catch anything. Try again, or type your idea.". **Proteção do texto** (`IdeaPromptDraft`, `DictationSegment`, testados): o ditado escreve num **trecho próprio**, no ponto de inserção (o cursor do campo, `TextField(selection:)`; sem cursor, o fim; um trecho selecionado recebe o ditado depois, nunca por cima), com espaço certo dos vizinhos (nenhum depois de espaço ou quebra de linha, antes de pontuação final ou em escrita sem espaços como japonês, chinês e tailandês); cada resultado parcial **substitui só o trecho**, então nada repete nem apaga o que veio antes ou depois; se o texto muda por outro caminho (colar, Writing Tools), o ditado larga o trecho e não escreve mais; dois ditados seguidos somam; o cursor fica depois das palavras ao terminar. **Interrupções:** o microfone é solto ao parar, **quando o card sai da tela ou outra coisa a toma (aba, sheet, prompter, controle remoto; o reconhecedor ainda fecha as últimas palavras no rascunho)**, com o app em segundo plano, numa interrupção de áudio (ligação, Siri) e quando o áudio some por alguns segundos (microfone desconectado); nos dois últimos, o texto fica e "Dictation stopped. What you said so far is kept." avisa por 6 s. Erros (sem permissão, idioma indisponível, sem reconhecimento) nunca apagam texto e o digitar segue igual **My Cue Voice no card** (`MyCueVoiceChip`, `CreatorProfileService.writesInMyVoice`): o chip tem **o mesmo estado** do "Use my voice in AI scripts" do Profile, e só vale ligado quando o perfil tem **o mínimo que a IA usa** (`CreatorProfile.missingVoiceSteps`: o que o criador faz, para quem fala e como fala; a primeira pergunta, o tipo de criador, é opcional); audiência e tom só contam depois de escolhidos (`confirmedVoiceSteps`), então os valores iniciais nunca vão junto. **Perfis de versões anteriores** guardam todos os dados e continuam mostrados como estão; o setup abre com as opções atuais marcadas ("Confirm what’s here, or change it.") e salvar sem mudar nada basta. Se um ditado ainda fecha as últimas palavras, tocar no chip o encerra e o setup só abre depois dele; abrir, cancelar ou concluir o setup nunca toca no rascunho |
| Primeiro voo (onboarding, v27) | `Screens/Onboarding`, `Managers/Onboarding`, `Managers/Permissions`, `Screens/Prompter/Selfie/PracticeBars` | Mostrado **uma vez**, por cima do app inteiro (`RootView`, não é cover: o prompter abre por cima no treino), só numa biblioteca vazia (quem já tem roteiros, takes ou temas nunca vê; `OnboardingService.resolve`). **Welcome** ("Every creator has a universe to share.", constelação, *Get started* / *I already use Cue*, que fecha o voo e leva ao Profile para restaurar) e **cinco capítulos** com barra de 5 segmentos e **Skip** (vai ao estado vazio de Scripts com o que já foi escolhido, senão TikTok): **1 · Your universe** (até 3 temas ou "+ Your own", que viram mundos em órbita; alimentam o My Cue Voice: `CreatorProfile.niches` e `customTopics`), **2 · Your first voyage** (a plataforma é uma galáxia; mostra formato · faixa ideal · zonas seguras do `PlatformRules` e o botão "Head to …"), **3 · Your first script** (≈15 s no tema e na plataforma, escrito pelo modelo do aparelho se `writer.isLanguageModelAvailable`; senão o roteiro nosso, rotulado "TELEPROMPTER PRACTICE"; *Use this script* cria o roteiro de verdade, *Another*, *I’ll write my own*), **4 · Give it a voice** (microfone, depois reconhecimento de fala só se o microfone foi permitido, depois câmera; **o único botão é Continue**, seguido do alerta do sistema, sem Skip nem "Not now"; recusar nunca bloqueia) e **5 · Practice** (o prompter real sobre a câmera frontal com `PrompterLaunch.isPractice`: não grava, o texto segue a voz desde a primeira palavra, chip "✦ PRACTICE · NOT RECORDING"; **Record it for real** tira o treino e deixa a gravação normal, **Not now — take me to my studio** fecha). Testes: `-uiTestOnboarding` liga o voo, `-uiTestPermissions granted\|denied` troca os pedidos reais por um stub (`PermissionRequesting`) |
| Script (página, v26) | `Screens/ScriptDetail/Page`, `ScriptDetailViewModel+Page` | **Uma página só, Draft \| Shaped** (`ScriptPageView`), sem barra de navegação: a barra de cima (`ScriptPageTopBar`) tem **voltar** (amarelo), o chip da plataforma ("● TikTok", abre Create for), o seletor **Draft \| Shaped** (como o Voice \| Steady), **•••** e o **Rec** amarelo; depois o **título** (campo de 27 pt) e a linha mono amarela "113 WORDS · ~0:45". **Draft** é escrita livre (`ScriptDraftEditor`, `TextEditor` com seleção, o texto inteiro numa página; as marcas entre colchetes são cues) com a barra de baixo (`ScriptDraftBar`): **✦ Shape** (violeta; vai para o Shaped), **¶ Cue break** (põe uma marca [pause] onde está o cursor), **Aa** (três tamanhos) e "TikTok · ideal 1:00–1:30". **Shaped** (`ScriptShapedView`, `ScriptShape`) lê as mesmas palavras sem reescrever: a faixa de duração (a duração em amarelo, laranja se passa da faixa, a faixa ideal em verde), as **seções** (`ScriptSectionView`: o rótulo em mono num trilho de 2 pt, amarelo no hook e cinza no resto, tracejado quando falta; os cues viram etiquetas amarelas) e, sob a seção, os **avisos violeta** (`ScriptTipRow`: "Hook is 8 s — under 3 s holds more viewers" com **Fix** e "Long sentence — split for reading" com **Split**; ✕ dispensa) e "✦ No CTA yet · Suggest one" (um script genérico só tem CTA se o último parágrafo soa como um); tocar no hook abre Hooks; "Edit the text in Draft — shaping never rewrites it." volta ao Draft; as takes do roteiro ficam abaixo. Um roteiro com texto abre em Shaped; um novo ou importado, em Draft com o título pronto. **Salva sozinha** (sem Done): ao pausar de escrever, ao trocar de face, ao sair e ao gravar; mudar as palavras de um roteiro com takes cria **uma versão nova por visita** ("Saved as v2 — your take stays with v1"). **Selecionar mais de 8 caracteres no Draft** mostra a barra **✦ Rewrite · Shorter · Stronger hook · In my voice** (`SelectionActionBar`); a escolha escreve só aquele trecho e o cartão violeta (`RewriteCandidateCard`) mostra o antigo riscado e o novo em negrito, com **Use** (amarelo) e **Keep mine**. **Rec** no Draft com a duração acima da faixa da plataforma pergunta **uma vez** "A bit long for TikTok" (**Record anyway** / **✦ Shape it**, `LengthNudgeSheet`). **•••**: ✦ Improve with Cue (a sheet Improve script), **Versions & options** (o editor de escrita antigo, ver abaixo), Script details, Studio mode e as ações de sempre (Duplicate, Move to folder, Script Language, "Make a version for…", Share, Delete). **A IA escreve na página**: uma ideia vinda do card abre o roteiro vazio em Draft e as palavras chegam em grupos de quatro (o título primeiro), com "· ✦ WRITING IN YOUR VOICE…" em violeta e **Stop** (as palavras que chegaram ficam); no fim o toast "Draft ready — edit anything" (ou "…check facts before recording" com o banner de fatos). Uma falha mostra "Couldn’t write the script" com **Try again** |
| Script (Versions & options) | `ScriptEditorView`, `Editor/` | O **editor de escrita focado** de antes, agora atrás de ••• › Versions & options: sem a barra de navegação, só o cabeçalho (título editável, "● 123 words · ~49s" e **Done** amarelo), o texto como **blocos** (um `UITextView` por parágrafo, sob o rótulo e o tempo do bloco) e **uma barra de 48 pt** acima do teclado: **AI** (amarelo) · **[ ]** Cues · Sections · Options · mostrar/esconder o teclado, cada ferramenta num **painel no lugar do teclado** (Improve with AI, Cues, Sections, Script options com **Discard changes**). Done e Discard voltam à página, que relê as palavras; ao abrir, a página guarda o que estava escrito |
| Improve script | `ImproveScriptSheet` | "Improve script · Apple Intelligence · runs on your iPhone"; dica do hook (laranja, abre as opções); as ferramentas em lista com ícone, nome e o que fazem ("Fit to time · Ideal for TikTok: 1:00–1:30"); na leitura, uma ferramenta grava o texto na hora (nova versão quando há takes) e o toast oferece Undo |
| Script details | `ScriptDetailsSheet` | Create for e Script type (abrem suas sheets); o medidor de duração com a faixa ideal e o mínimo de monetização; os blocos em chips (tocar fecha a sheet e leva a leitura até o bloco); Format ("9:16 · 1080p30"), Version ("v2 · 3 takes") e Monetization goals |
| Script type | `ScriptTypeSheet` | "Talking video" (sem formato) e os 8 formatos, cada um com o fluxo ("Hook → Tips → CTA"); define os blocos e as sugestões de IA, nunca as palavras |
| Create for | `DestinationSheet` | 6 plataformas com resumo do preset (formato · qualidade · safe zones · ideal) + "Monetization goals". Escolher mostra o toast "Create for {plataforma}" |
| Hooks | `HooksSheet` | Hook atual + 3 opções escritas pelo modelo no aparelho (sem modelo, as do formato) + "More options" |
| New script | `NewScriptSheet` | v26: "Your words, your way." e duas linhas (ícone de 42 pt, título, detalhe): **Write my own** ("A blank page. Shape it later.", com o anel amarelo de 1,5 pt e o ícone amarelo) e **Import** ("Scan, photo, file or paste", abre o Importar), e o rodapé "Want Cue to write it? Use the Let’s Cue card.". A IA mora no card "Let’s Cue!" da home, não aqui: Prompt, Themes e Formats saíram da sheet. Sobre a câmera, Paste no lugar de Write e sem o rodapé |
| Start recording | `StartRecordingSheet` | "Read from a script" (4 recentes com duração), "+ New script", "Record without a script →". Sobre a câmera vira "Add a script", sem o freestyle |
| My Cue Voice (V1) | `Shared/VoiceStyle` (`VoiceSetupSheet`, `Flow/`) | **Quatro perguntas, uma por vez**, numa sheet cheia: a barra de progresso (`VoiceFlowProgress`, "01 / 04"), **Not now** (ou Cancel ao editar) e voltar. **01 · "What kind of creator are you?"** (`VoiceRoleStep`): 8 cartões em duas colunas (`CreatorRole`: Lifestyle & personal, Entertainer, Expert coach or pro, Teacher or explainer, My own business, Content for brands, News & commentary, Community or cause); escolher um marca o cartão e o **Continue** (amarelo, embaixo, ligado só depois de escolher) segue; é opcional ("Skip this one") e não conta no mínimo da voz. **02 · "What do you create?"** (`VoiceNicheStep`): os temas em chips, até 3. **03 · "Who do you talk to?"** (`VoiceAudienceStep`): as quatro audiências em linhas com o marcador redondo. **04 · "How do you talk?"** (`VoiceToneStep`): os seis tons com uma frase de exemplo em serifa e a etiqueta amarela "Common for …" nos comuns ao tipo de criador; até 2. O botão grande diz **Continue**, e na última pergunta **Done** (ou **✦ Write my script** quando há uma ideia no card, com "Just save my voice" embaixo). Tudo grava nos campos do Profile (`CreatorProfile.role` é novo). **O roteiro é a prévia**: um roteiro escrito na voz do criador mostra no topo da página a faixa **"✦ DOES IT SOUND LIKE YOU?"** (`VoicePreviewStrip`): o seletor **My Cue Voice \| Without** (o "Without" escreve a mesma ideia sem a voz, uma vez, e mostra sem tocar nas palavras), **Sounds like me** (guarda e a faixa some, `voiceApproved`) e **Adjust** (`VoiceAdjustSheet`: "What didn’t sound like you?" com Too formal · Too much slang · Too over the top · “I don’t say that” · Too long, a linha do que muda em mono, "This script only" ou "Also my profile" e **✦ Rewrite**; cada resposta é uma mudança pequena na voz, `VoiceAdjustment`) |
| Importar | `ImportScriptSheet` | Files, Scan (câmera de documentos), Photo e Clipboard. Scan, Photo e PDFs escaneados passam por OCR do Vision no aparelho |
| Need an idea? / Format | `CreateScript/Ideas`, `CreateScript/Format` | A sheet de 3 abas (Prompt, Themes, Formats) **saiu**. **Need an idea?** (`IdeasSheet`, S2c): "✦ FROM YOUR TOPICS", o título, os chips "All topics" e um por tema do criador (os nichos do My Cue Voice), as ideias em linhas (`IdeaRow`: o título em serifa, "LIST · ~1 MIN · LIFESTYLE" em mono e o **↑ amarelo** que escreve a ideia numa página nova; tocar na linha leva a ideia ao card para editar antes) e "More ideas" (o modelo escreve novas; sem ele, giram as iniciais). **Format** (`FormatSheet`, S2d): "How Cue builds the script. Auto picks from your idea." e uma grade de duas colunas (**Auto** e os 8 formatos, `FormatTile`: nome, para que serve e os blocos em mono, "HOOK · PROBLEM · PRODUCT…"; o escolhido com o anel amarelo); o formato só define os blocos e as sugestões de IA, nunca as palavras. Os briefs por formato ("bullets") saíram da interface: sem Apple Intelligence não há como escrever, e as ideias abrem mesmo assim |
| Selfie | `Screens/Prompter/Selfie` | Câmera em primeiro plano, em camadas que nunca entram no vídeo: o **frame gravado** (o preview mostra exatamente o que é gravado; fora dele, preto 60% e bordas de 0,5 pt), a **zona segura** da plataforma (degradê em cima e embaixo, sombra nas laterais, contorno tracejado e "INSTAGRAM REELS SAFE AREA"), a **janela de texto** (largura 50–93%, padrão 93%; altura 160–380, padrão 380: começa com as preferências do criador e pode ser ajustada na sessão; as linhas quebram normalmente e preenchem a largura; fundo preto 25%; desfoque opcional; o texto já lido esmaece) **com uma alça no canto inferior direito** (`TextWindowResizeHandle`: um "L" amarelo de 14 pt com alvo de 44 pt; arrastar muda largura e altura ao mesmo tempo, a janela continua centrada; enquanto o dedo está nela a janela ganha um contorno amarelo de 1,5 pt e uma pílula mono diz "WIDTH 93% · 6 LINES"; a largura encaixa em 60 / 75 / 93% e a altura em linhas inteiras, no mínimo 3 linhas e dentro dos limites de 50–93% e 160–380 pt; toque duplo devolve o tamanho original com o toast "Text window reset"; some gravando, com uma sheet aberta e no Studio; vale só para esta take, como o resto do Layout, `TextWindowResize`), e a **linha de leitura** fixa logo abaixo da lente (118 pt na frontal; 36% do frame na traseira), com uma alça fina (14 × 34, alvo de 44 pt) para arrastar, que some enquanto o texto roda ou a câmera grava. Sem dica de primeiro uso. A janela segue a linha (a linha fica ~25% abaixo do topo dela). Topo: fechar, Selfie \| Studio e o chip "{Plataforma} · 9:16" (abre Create for; em freestyle troca o enquadramento); gravando: "● 00:42 \| 18s to 1:00" e o chip. **Barra de vidro noturno** (v26: `glassNight` sólido, 88%, raio 40, 12 pt de margem interna, sobre um material fino; `SelfieControlPanel`), de cima para baixo: (1) o seletor **Voice \| Steady** (`ScrollModePicker`: trilho de 44 pt com 3 pt de respiro, segmento ativo em `segmentOn`; Voice leva uma onda de cinco barras, Steady o ícone de rolagem; o nome completo "Voice Following" fica para o VoiceOver) com voltar ao topo, play e Aa em círculos de 44 pt; (2) em **Steady**, a faixa **SPEED** (`SpeedSlider`: "SPEED" em mono, o `CueSlider` de 0,3 a 2,0× e o valor em amarelo mono, sobre uma cápsula suave de 44 pt); em **Voice**, uma linha de dica (`VoiceIndicator`: a onda ao vivo e "Scrolls when you talk, waits when you stop." enquanto o reconhecimento segue as palavras; quando o modelo do idioma carrega, baixa ou o texto rola na velocidade definida enquanto a voz soa, diz isso com a velocidade, `VoiceFollowStatus.detail`); (3) a **linha HUD** em mono e caixa-alta, "● IPHONE MIC · 1080P 30 · 9:16 ›", com **duas áreas de toque**: o microfone (`AudioInputPill`: ponto verde com a entrada conectada, `ink3` enquanto a sessão de áudio não informou, laranja e "Microphone off" sem permissão; abre Audio Input) e o setup (`SetupSummaryPill`; quando vem de uma recomendação aceita ou de uma mudança só desta take, a origem vem antes em amarelo: "TIKTOK SETUP · 1080P · 9:16 ›", "THIS TAKE · 4K · 1:1 ›"; abre "This take"); ambas travadas gravando ou na contagem; (4) a **fileira de captura**: a última take com a quantidade na etiqueta amarela (`LastTakeButton`), ajustes da câmera, gravar, virar e **•••** (`RecorderMoreMenu`: Countdown, Remote Control e This take; uma etiqueta amarela "3s" avisa a contagem ligada; Countdown e This take travam gravando, o Remote não). Sem roteiro, no lugar de (1) e (2): "Freestyle · No script — add one anytime" e o botão **Add script**. **Gravando, a barra fica compacta** (`RecordingCompactBar`, `RecordingBarState`): o chip do modo ("VOICE FOLLOWING" em amarelo com a onda ao vivo, ou "STEADY 0.7×"; "FREESTYLE" sem roteiro) com, em Steady, o slider da velocidade, mais voltar ao topo e pausa; o **Stop** de 64 pt com o relógio em amarelo mono de 22 pt e "TAKE 4 · TIKTOK SETUP" ("FREESTYLE · TAKE 4" sem roteiro); e "Tap the screen for controls". **Tocar na tela mostra a barra inteira por 4 s** (cada uso dela recomeça a contagem; um arraste só recomeça depois de meio segundo), e ela volta a ser compacta sozinha; parar a take também a fecha. Não há modo de controles escondidos nem botão do olho. No topo, gravando: o pill **REC** (vermelho, ponto que pulsa, relógio mono e, se há mínimo de monetização, o tempo que falta) à esquerda e o chip da plataforma à direita. O cartão de recomendação é violeta (degradê `recommendationTop` → `recommendationBottom`, borda `recommendationRim`; as linhas em `aiTextStrong`) e o aviso de "short of 1:00" é noturno (`warningCard`). Quando a plataforma do roteiro recomenda outro setup (formato, qualidade ou fps diferentes do Creator Setup), um **card de recomendação** (`SetupRecommendationCard`, vidro, acima da barra, como o aviso de monetização) diz "Recommended for TikTok · 9:16 · 1080p · 30 fps · TikTok safe zone" e "1080p instead of your usual 4K." (ou "Your usual setup is …" com mais de uma diferença), com **Keep 4K** / **Use 1080p** ("Keep My Setup" / "Use Recommended"); até a resposta grava com o Creator Setup, e gravar sem responder mantém o Creator Setup. Não há modo de controles escondidos (a v26 troca a barra, na gravação, por uma compacta: fase 3) |
| Studio | `Screens/Prompter/Studio` | Prompter em tela cheia sem câmera, barra de progresso no topo, fechar, Selfie \| Studio, Remote Control (amarelo com um remote conectado) e espelhar; barra no mesmo vidro noturno do Selfie e com o mesmo seletor e o mesmo `SpeedSlider` (no Voice Following, a onda com "Listening/Paused" e, ao lado, `prompter.voiceStatus`: "Follows your words" enquanto o reconhecimento segue as palavras, "Scrolls at 0.7× while you talk" sem ele, "Getting ready to follow your words…" / "Downloading Thai · 40%…" mesmo antes do play), voltar ao topo, 3 linhas para trás/frente, play grande amarelo e Aa. O Studio não grava (outro aparelho filma): não tem a fileira de captura nem a barra compacta; o protótipo v26 mostra o Studio com o botão de gravar, e isso não foi levado ao app |
| Display | `DisplaySettingsSheet` | "Display · ● Live preview". No Selfie, primeiro **Layout** (`DisplayLayoutSection`): Reading line com ↑/↓ e a distância da câmera, Text window height e width ("Narrow · less eye movement"), **Social safe zone** (chips Reels / TikTok / Shorts / Stories / Custom no 9:16, LinkedIn / Custom no 4:5, Custom no 1:1; no Custom, margens em %), Show safe zone e "Reset to Recommended", com o aviso de que a zona é guia e não garantia. Quick: AI Coach (desligado por padrão), Text size e, no Selfie, Background opacity e Camera blur (Off/Subtle/Soft/Medium, leve); no Studio, Reading line (Top/Bottom) e Background color. Advanced (recolhível): fonte, espaçamento, margens, alinhamento, cor, linha de leitura, espelhar. No Selfie, a altura máxima para logo abaixo da janela de texto (medida quando a sheet abre) |
| Audio Input | `AudioInputSheet` | Aberta pela linha HUD do microfone no Selfie ("● IPHONE MIC") (sheet na altura do conteúdo, sem tela de ajustes separada): "Audio Input" + "Where Cue hears you in this take.", a lista das entradas conectadas agora (nome + tipo: Built-in, Bluetooth, USB, Wired headset…) com a que está em uso marcada (círculo amarelo), e "Plug in or pair a mic and it shows up here.". Tocar numa entrada a torna a entrada da gravação, fecha a sheet e a pill muda na hora. Sem entradas: "No microphone found…"; sem permissão: explicação + Open Settings |
| This take | `RecordingSetupSheet` | Aberta pela linha HUD do setup ou pelo menu "•••" (sheet na altura do conteúdo): "This take · What Cue records with, and why."; card da recomendação (resumo, "Your usual setup is …", chips Use Recommended / Keep My Setup com ✓ no escolhido, ou "Your setup already matches it."); lista Camera, Microphone, Format, Quality, Frame rate, Text size, Scroll speed, Mirror text, Safe zones com o valor e a origem (`TagPill`: "Your setup", "TikTok setup" com ponto amarelo, "This take" com ponto azul `info`); "Back to my setup" quando há mudanças; linha Remote Control; "Changes here are for this video. Your usual setup stays in Settings › Creator Setup." |
| Remote Control (sheet) | `RemoteControlSheet` | Pelo menu "•••" ou pelo "This take" (Selfie) ou pelo botão do Studio: "Control your teleprompter from another device." + `RemotePairingPanel` |
| Câmera | `CameraSettingsSheet` | Lente, enquadramento, resolução, fps, grid, safe zones, estabilização, microfone, contagem, formato, e **Background** (Original / Blur / Color + cores; só nesta sessão, travado gravando): o preview mostra o efeito ao vivo e a take é gravada como a câmera vê, com o efeito salvo como receita (aparece na revisão, no Quick edit, onde pode mudar, e no export); "Your recording stays as filmed. The effect is added to the take, and you can change it in Quick edit."; sem detecção de pessoas, "This iPhone can’t find people in video, so the background can’t change here."; se a câmera não entrega frames junto com a gravação, "This camera can’t show the effect while recording. It’s added to the take after you record." Lente, enquadramento, qualidade, microfone e safe zones mudam só nesta sessão ("…change for this take. Your usual setup stays in Settings › Creator Setup."); grid, estabilização, contagem e o resto continuam salvos. No Selfie com script, a sheet para logo abaixo da janela de texto (não cresce além dela) e não escurece o fundo |
| Revisão do take | `Screens/TakeReview` | v26: **abre pausada** (botão de play; tocar no vídeo toca ou pausa), no formato da take (barras pretas fora do 9:16). Barra de vidro no topo: voltar, o pill mono "TAKE 3 1:02", a **estrela** (um anel amarelo; cheia e amarela quando é a melhor) e a lixeira. Com várias takes, o **chip "● ▬ ●  2 / 3"** (`ReviewCompareChip`) e **deslizar o vídeo** para os lados passam para a anterior ou a próxima (sempre em pausa). Embaixo: o filmstrip com o botão de som (mute) e o relógio mono (o tempo em amarelo, a duração em cinza); o **card** (`ReviewInfoPanel`, vidro noturno): o título (+ EDITED), a linha HUD "● TIKTOK · 1080P · 9:16" com "✓ FITS 1:00–1:30" em verde (ou "12s under 1:00–1:30" em laranja, `LengthFit`, contra a faixa ideal da plataforma), a barra **PICK · EDIT · READY · SHARED** com a etapa do vídeo (`StageBar`, na cor da etapa), "From script · v1 ›" (leva ao roteiro) e, com várias takes, a sugestão **✦ Suggest best** em violeta. Ações: **Edit** ("Continue" quando há uma edição aberta), **Retake** e **Save** em botões redondos de vidro com o nome embaixo e o **Share to TikTok** amarelo, o único primário ("Share" sem plataforma, abre Share to); no grátis, "4 OF 5 FREE EXPORTS · GO PRO" em mono sob o botão. Só uma melhor take por roteiro; a faixa "Your takes" saiu (o chip e o deslizar a substituem) |
| Share to | `TakeReview/Share` | Miniatura, "SHARE TO", título, "0:44 · 9:16 · 1080p"; seis plataformas (a da take com anel amarelo e "recommended"), Save video e More; "Created for X — framed and safe-zoned for it"; Burn in captions; Cover ("Saved to Photos with the video" + Save cover, só quando o Quick edit tem capa; salvar a capa não conta como exportação); Quality 1080p / 4K; exportações grátis restantes + Go Pro. Plataforma: exporta, salva no Fotos e abre o app; "Ready to post on X · N of 5 free exports left". Sem exportações grátis, qualquer exportação abre o paywall e continua sozinha depois da assinatura |
| Quick edit | `Screens/QuickEdit` | **Layout** (`EditorLayout`, testado): pilha vertical calculada pela altura útil `H` (sem posições fixas): barra superior 44 pt, prévia flexível, barra do player 44 pt, timeline `clamp(0,32·H, 184, 300)` e toolbar 64 pt; com painel, o painel tem três tamanhos (mini `clamp(0,27·H, 200, 250)`: Speed, Zoom, Volume, Filters, Crop, Voice-over, Auto captions, Media, Transition; médio `clamp(0,38·H, 250, 340)`: Voice, Pauses, Captions, Adjust, Background, Cover; cheio `clamp(0,44·H, 300, 380)`: Text style, Caption style) e a timeline fica com o resto; a prévia nunca fica abaixo de `max(0,30·H, 190)` (a timeline encolhe primeiro, depois o painel rola; nos cheios a timeline pode sumir). Classes por `H`: regular (≥ 780), compacta (680–780: trilha 48, faixas 24, rótulos 10 pt, abas do Text style na linha do escopo) e muito compacta (< 680, iPhone SE: barras 40, trilha 44, faixas 22, toolbar só com ícones e o rótulo num toque longo, painéis cheios como sheet que nunca cobre a prévia mínima). Até `accessibilityMedium` os controles crescem; acima, os painéis rolam. **Teclado:** com o teclado aberto num campo de painel (Text style, linha de legenda, título da capa) a classe de altura e a forma do painel (embutido ou sheet) continuam as da tela **sem o teclado** (`EditorLayout.stableHeight`, medida por `QuickEditView.measuresStableHeight`): abrir o teclado nunca vira o painel em sheet nem muda barras e faixas. Só o espaço é repartido de novo, pelo ajuste nativo do sistema e sem deslocamento manual: o vídeo diminui (mínimo `max(22%·H, 130 pt)`, o suficiente para ver o texto), a timeline sai da frente e o painel fica logo acima do teclado, alto o bastante para o cabeçalho, o campo e o ✓ (e, no iPhone SE, o sheet mantém as alturas da tela sem teclado). Fechar o teclado devolve o layout de antes; nada fecha o painel nem muda a seleção. **Topo (v26):** **voltar** (círculo de 36 pt: fecha sem perguntar e guarda o rascunho, `edit.backButton`) · o chip mono **"● IN EDIT · AUTOSAVED"** (ou "● NO CHANGES YET" antes de mudar algo; o rascunho guarda sozinho) · **Done** amarelo, a única ação primária. **Done sempre pergunta "Is it ready to post?"** (`EditorDoneSheet`, `EditorOutcome`): **Yes — share to social media** (amarelo; salva a edição e abre o "Share to" da revisão → SHARED), **Download video** (salva a edição e o vídeo no Fotos, conta como exportação → SHARED), **Ready, I’ll post later** (salva a edição, a revisão volta com o Share brilhando por 4 s → READY) e **Not yet, I’ll come back** (mantém o rascunho, mesmo sem mudanças, e a revisão passa a dizer "Continue" → IN EDIT); deslizar a sheet para baixo volta ao editor. Cada resposta traz o selo da etapa à direita. A sheet de Export com resolução e fps deixou de ser alcançável pelo app (o código fica). **Prévia:** o quadro no formato da take, em fit; textos e legendas desenhados como no export (proporcionais ao quadro). Tocar num texto o seleciona (contorno amarelo de 2 pt a 5 pt, × para apagar e ⤡ para escalar, brancos de 24 pt com alvo de 44); tocar de novo abre Text style; arrastar move (com keyframes, cria ou ajusta o do playhead), com guias amarelas no centro (encaixe a 2,5% com háptico) e a área segura da plataforma tracejada; arrastar a legenda muda a altura de todas (encaixa em Top 16% / Middle 50% / Bottom 76%); tocar no vazio solta. **Tela cheia** (⤢): só o vídeo; tocar nele dá play/pause, fora sai. **Barra do player:** "00:01.2 / 00:21.6", play no meio, undo/redo (sempre à mão; 60 níveis, gestos contínuos e digitação viram um passo só, coalescidos em 900 ms) e tela cheia; no teclado, espaço, ⌘Z e ⇧⌘Z. **Timeline** (`TimelineScrollingView`, UIKit, `TimelineGeometry` testada): linha branca de 2 pt fixa no centro e o conteúdo rola por baixo com inércia nativa; o dedo faz scrub (seek exato, pausado) e o play move o conteúdo (o player é a fonte do tempo); pinça (ou ctrl/⌘ + scroll) ancorada no playhead, 44 pt/s × 0,35–5; régua de 0,5 / 1 / 2 / 5 s com `mm:ss` a cada dois passos. Trilha principal: miniaturas reais (largura = altura × 9/16, em cache por tempo da gravação) sobre 14 pt de forma de onda (RMS a cada 0,1 s, Accelerate), selo amarelo ("1.5×", "Push in", "Muted", o filtro e "Adjusted" **só quando o clipe tem os seus**, e, quando o clipe ou a gravação tem fundo (Blur, Color, Image), o nome dele) a duração quando selecionado; a **Cover** antes do início e o **+** depois do fim (Insert as clip). Faixas: Text (textos e mídia por cima; cada mídia diz o que é e como aparece: "Photo · Full screen", "Video · Window"), Captions, Music, Voice-over; **cada faixa tem seu fundo** (`laneStrip`, de 40 pt da esquerda a 8 pt da direita, que não rola) e, à esquerda, uma **calha preta de 38 pt com o ícone** (Aa, legenda, nota, microfone) por cima da qual o conteúdo rola; uma faixa vazia diz o que um toque faz, em texto simples ("Tap to add text", "Tap to add captions", "Tap to add music or voice-over", 12 pt a 50 pt da esquerda); **tocar na faixa (fundo, calha ou dica) abre as ferramentas dela na toolbar** (Text, Captions ou Audio; Music, Voice-over e a dica de áudio abrem Audio), acende o fundo (`laneStripActive` + anel amarelo de 1,5 pt) e um segundo toque, ou qualquer outro toque, devolve a toolbar principal; com painel, a faixa dele sobe para baixo da régua e a principal encolhe a 40 pt. Tocar seleciona (v26: **moldura branca** de 2 pt e **alças amarelas** de 16 / 12 pt com alvo ≥ 32, o resto a 50–55%, a faixa cresce de 28 para 36); tocar no vazio solta. Alças com balão ("00:04.1 · 1.8s"); na alça esquerda do clipe o conteúdo acompanha o dedo e se reajusta ao soltar; legendas não passam das vizinhas. Ordem: alça > toque (< 4 pt) > scrub > pinça. Snap com háptico a 6 pt (junções, começo e fim de legendas e textos, keyframes). Cada **corte** tem uma marca de 20 pt (+ num corte seco, amarela com o ícone da transição) que abre Transition. **Toolbar** por contexto (64 pt, ícones de 24, rótulos de 11; rola com fade à direita): principal (v26, na ordem do CapCut) **Edit · Audio · Text · Captions · Filters · Adjust · Crop · Background · Overlay · ✦ Smart** (Smart por último e em violeta; "Overlay" é a antiga Media; Pauses saiu da barra e vive no Smart; Audio abre Studio Voice · Music · Voice-over); com algo selecionado, "‹ Clip" (Split · Speed · Adjust · Filters · Background · Zoom · Volume · Voice · Duplicate · Delete; Adjust, Filters e Background abrem o mesmo painel da toolbar principal, só que mudam **esse clipe**), Text (Edit · Style · Keyframe · Duplicate · Delete), Caption (Edit · Split · Join next · Style · Delete), Music (Volume · Replace · Delete), Voice-over (Volume · Re-record · Delete), Media (Edit · Replace · Delete; Replace abre a biblioteca e troca só o arquivo — foto por foto, vídeo por vídeo —, mantendo lugar, duração, janela, camada e keyframes); menus Text (Title · Subtitle · Hook · Callout · Style all), **Captions** (com linhas: Add line · All lines · Style; sem: Auto captions · Write them) e Audio (Voice · Music · Voice-over). **Delete, em vermelho, fica sempre no fim da barra** e não rola (`EditorToolbarItem.isPinned`); as outras ferramentas rolam por baixo de um degradê. Audio › Music **sempre adiciona**: abre Files e o clipe entra no playhead, no espaço livre em volta (`MusicPlacement`: com o playhead sobre um clipe vai para o fim dele, para onde o próximo começa; sem espaço, "No room here — move the playhead to a free spot"); **Replace** (com a música escolhida) troca só o arquivo, mantendo lugar, volume e fades. Edit seleciona o clipe do playhead; Split esmaece fora do clipe (toca e explica). **Painéis** (`EditorPanelContainer`; a superfície vai até a borda da tela, mas os controles e o rodapé param acima da área segura de baixo — onde fica o Home Indicator — mais `Metrics.editorPanelBottomClearance`, via `safeAreaPadding`, onde quer que o painel apareça: sob a timeline ou em sheet; o conteúdo rola e nada fica fora de alcance): título, o escopo no subtítulo ("This clip", "Whole take", "Applies to all 8 lines", "Only this title changes"), Reset quando faz sentido e o ✓ amarelo de 40 pt que aplica e fecha; tudo aparece ao vivo, os detalhes técnicos ficam em **Advanced**. ✓ fecha o painel, Done conclui a edição, Export gera o arquivo. **Speed** (0.5×–2×, "This clip · 00:21.6 → 00:14.4", com um clipe "Split at playhead to change one part"; Advanced: 0,25–4× e Keep voice pitch). **Zoom** (None · Push in · Pull out · Punch in, toca 2,5 s; Advanced: Intensity, até 1,3×). **Volume** 0–200% (clipe, com Mute this clip; música; voice-over). **✦ Smart** (`SmartPanel`, tiles violeta de 100 × 100): **Auto captions**, **Remove pauses**, **Studio Voice** e **Auto adjust**; cada um abre o painel que faz o trabalho (Auto adjust abre o Adjust e mede a imagem), com o estado em mono embaixo ("12 LINES", "SOFT", "ON") e um anel amarelo no que está ligado. **Studio Voice** (a antiga Voice, take inteira): Enhance voice e Reduce noise (Off / Soft / Strong) e Compare with original ("Original audio" na prévia). **Pauses** (`CleanUpCard`): pausas marcadas na trilha principal (hachurado amarelo = remover, cinza tracejado = manter; tocar alterna), "Pauses longer than" 0,3–3 s (0,7), cards com duração, tempo, Remove/Keep e Listen (1,2 s antes e depois; marcada, pula o trecho), "Filler words and retakes" do Clean Up no mesmo formato, e o rodapé fixo com o tempo economizado em amarelo, "00:21.6 → 00:17.5" e "Remove N pauses". **Captions** (`CaptionsPanel`): linha fixa com o switch, o idioma falado (lista em linha: Automatic + 15), Translate (lista em linha: Off + idiomas, "Translated on your iPhone with Apple Translation. Nothing is sent anywhere.", "Edit translations" abre a sheet com Both e escrever à mão) e Style branco; as linhas com tempos ("00:05.2 → 00:07.1 · 1.9s"); tocar leva o playhead e seleciona na timeline; **corrigir o texto de uma linha nunca muda o estilo** (o estilo é da coleção, a linha mantém identidade, tempos e destaque da palavra: as palavras trocadas ou acrescentadas dividem o trecho que a voz gastou nas que substituem, e só uma palavra sem trecho nenhum vira estimativa e pede revisão; mover ou apertar uma linha dobra as palavras para dentro do novo tempo); durante o play a atual fica amarela e a lista a acompanha; a selecionada abre com o campo de borda amarela (**Return vai para a próxima linha com o teclado aberto**, para revisar a take digitando; na última, fecha o teclado) e uma fileira: **‹ 3/12 ›** (linha anterior/próxima, o playhead vai junto), Play, **More** e a lixeira; **More** mostra Start e End −/+ (0,1 s, sem passar das vizinhas, levando o playhead), Split e Join next, e abre sozinho numa linha com "Check timing"; segurar uma linha abre o menu com Play e Delete line; "Add a line at the playhead" só num intervalo livre ≥ 0,3 s; **"Delete all captions"** (vermelho, no fim do painel e também no menu Captions da toolbar, fixo no fim) apaga todas as linhas de uma vez, sem diálogo: o toast "12 lines deleted" traz **Undo** por 4 s (um passo do desfazer; a transcrição ouvida fica, então Auto captions refaz). **Auto captions**: idioma falado (Auto + 15) e "Generate captions" amarelo; sem fala, "Write them myself". **Caption style** (sempre global): Presets (a coleção **Cue / Educational / Interview / Impact / Pop / Editorial**; Clean só enquanto em uso; cada preset é uma receita completa e traz o seu Reveal, no mesmo passo do desfazer), Reveal (Line · Fade · Words · Highlight · Box; tocar toca a linha atual), Position (Top / Middle / Bottom e Size 12–28 pt) e Font (cor do destaque; com o visual de um texto, família, peso e cor). **Text style** (`TextStylePanel`): campo no topo (com o teclado ao criar), escopo explícito "This title" · "All texts · N" · "+ Captions" e as abas Presets (Save as my style, My style e os 8 `TypePreset`), Font (família em chips na própria fonte, peso, 12–56 pt), Color (texto; fundo None / Box / Pill e a cor; sombra None / Soft / Outline) e Motion (◀ Add/Remove keyframe ▶, Starts e Ends −/+); losangos brancos marcam os keyframes na faixa. **Cover (v26)**, quatro abas (`EditorPanelTab.cover`) e, na ponta da linha das abas, o menu de prévia **Feed \| Profile grid** (no grid, a capa aparece no meio de uma grade 3 × 3 de 3:4, com anel amarelo, entre quadros "EP 02", "EP 04" na fonte da capa): **Frame** (Frame from video / Photo e a faixa de miniaturas com o quadro branco arrastável), **Text** (o título e uma fileira de tiles: os 5 layouts **Hook** — palavras grandes com uma em preto sobre amarelo —, **Number** — o primeiro número do título grande em amarelo —, **Kicker** — a etiqueta "PART 3 · PALAVRA" —, **Question** — o título como pergunta numa caixa escura — e **Before/After** — BEFORE e AFTER num quadro dividido, sem título; as sugestões **✦ From your script** em violeta, até 3; e as fontes **Anton · Grotesk · Serif · SF Pro**; embaixo, a palavra destacada, que se escolhe por chips), **Elements** (Arrow · Circle · Series tag "EP 03" · Badge "NEW" · @handle do Profile; cada um ligado ou desligado) e **Look** (Clean · **Text behind me**, que recorta a pessoa com o Vision e a desenha por cima das palavras · **Outline me**, o recorte com contorno branco · Dim back · Blur back; mais **Save as my style** / **Apply my cover style**, que guardam layout, fonte, efeito e a etiqueta de série para as próximas capas). Cada mudança é um passo do desfazer; a capa é desenhada no aparelho (`CoverDesignRenderer`) e as capas feitas antes (`design` nulo) continuam como eram. Reset tira a capa. **Adjust** (do vídeo todo, ou só do clipe quando aberto pelo clipe: subtítulo "Whole take" / "This clip · the rest stays as it is"; no clipe cada chip mostra o valor do vídeo ("From the whole take") até o clipe ter o seu, e o Reset de um chip ou do painel devolve os valores do vídeo; Reset; **uma fileira de chips** (v26) — Auto, Exposure, Contrast, Warmth, Tint, Saturation, Vibrance, Highlights, Shadows, Sharpness —, o escolhido branco com texto preto e, fora de zero, o valor em amarelo ao lado do nome (o de Auto é a intensidade da correção); embaixo "Exposure +10" com o Reset do ajuste e, no outro extremo da mesma linha, o **◐** (segurar: mostra a imagem como gravada enquanto o dedo está nele, e solta ao levantar; o VoiceOver alterna) e o **Auto** ("Measuring…" enquanto mede; mede o clipe em escopo, ou a gravação da take no vídeo todo), e **uma régua** de 40 passos com o trilho amarelo a partir do centro e a alça branca de 28 pt; a régua de Auto é "quanto da correção aparece", e o Reset de Auto a tira sem mexer nos dials; sem Advanced). **Filters** (Original e a coleção **Natural · Studio · Soft · Cinema · Warm Editorial · Retro · Mono Soft · Mono Contrast**, em miniaturas do próprio vídeo (do clipe, quando aberto pelo clipe), cada uma começando na intensidade que lhe cai bem; os filtros anteriores — Vivid, Warm, Cool, Mono, Film e Fade — só aparecem enquanto escolhidos; e Intensity; no clipe, o filtro do clipe vale sobre o do vídeo e o Reset devolve o do vídeo). **Crop** (9:16 · 4:5 · 1:1 · 16:9 e Fill / Fit). **Background** (do vídeo, ou só do clipe quando aberto pelo clipe, com Reset para o da gravação; um clipe pode ficar sem efeito com um Original próprio; Original · Blur · Color · Image; Advanced: força do blur e Color key com Green / Blue screen, cor à mão, Tolerance, Edge e Spill). **Voice-over** (um botão de 72 pt: o círculo vira quadrado; grava do playhead com o vídeo mudo; a faixa cresce em vermelho e vira um item laranja). **Media** (selecionada: Full screen / Window, formato e tamanho, ordem; Advanced: som do vídeo e keyframes). **Transition** (None · Dissolve · Fade · Slide e "Use on every cut"). **Sheets:** Add music (Files, "Use only music you own or have the rights to — songs from Apple Music can't be added.", entra a 40% sob a voz), Add photo or video (Fotos em linha: On top of video / Insert as clip) e **Export** (`QuickEditExportSheet`): miniatura, "Take 3 · 00:21.6", "9:16 · captions and text burned in", Resolution 720p / 1080p / 4K e Frame rate 30 / 60 (nunca acima da gravação: o que não dá fica apagado com o motivo), tamanho estimado, exportações grátis restantes, "Export video"; progresso real ("Exporting · keep Cue open"); "Saved to Photos" + Done / Share. A capa vai para o Fotos junto. **Rascunho:** a edição, o playhead e o histórico ficam guardados enquanto edita ("Draft restored" ao voltar); Done salva na take e reabre exatamente igual. |
| Takes | `Screens/Takes` | v26: título grande "Takes" e, à direita, o alternador **Lista \| Grade** (`TakesLayoutToggle`, o escolhido em `segmentOn`; a escolha fica guardada, `DefaultsKey.takesLayout`) e o menu de plataforma "All ⌄" (`TakesPlatformMenu`). Sob o título, a contagem em amarelo mono ("12 TAKES / 05 VIDEOS", `HUDLine`) e o **card do pipeline** (`TakePipelineCard`): **TO PICK › IN EDIT › READY › SHARED** com a quantidade de vídeos em cada etapa, cada uma tocável (filtra; tocar de novo limpa) e, abaixo de um fio, a linha **NEXT** ("NEXT  POST IT · 3 MORNING HABITS ›": a primeira etapa com vídeo esperando, na ordem pick, edit, ready, com o vídeo que espera há mais tempo; tocar abre a revisão). Os números do pipeline respeitam a plataforma escolhida e não mudam quando uma etapa é escolhida. Seções Today / Yesterday / Earlier. **Grade** (padrão, 2 colunas): cada vídeo é um pôster 9:16 (`TakeVideoCard`) com a etapa no topo ("● READY", pílula escura com anel na cor da etapa; "×3" com várias takes), o título embaixo sobre quatro passos acesos até a etapa, e, sob o pôster, "● TIKTOK · 1:02"; o anel é amarelo em PICK BEST. **Lista**: `TakeVideoRow` com a etapa, o chip de takes e Edited; deslizar mostra **Share** (amarelo) e **Delete** (vermelho). **Segurar** (peek, nas duas) mostra o pôster e as ações Share, Edit, Retake, Mark as best e Delete (Share e Edit abrem a revisão já no "Share to" ou no Quick edit, `ReviewLaunchAction`). Uma etapa sem vídeos diz por quê ("All caught up", "Nothing ready yet"…). Sem takes: "No takes yet" + Record a take. **A etapa é derivada, nunca marcada à mão** (`TakeStage`): mais de uma take e nenhuma ★ → PICK; um rascunho do Quick edit aberto em alguma take → IN EDIT; nada exportado → READY; senão SHARED (a lista é recalculada quando a aba aparece). Os chips antigos (All takes / ★ Best / Not shared / Edited) saíram |
| Profile | `Screens/Profile` | v26: o card do criador (avatar amarelo com a inicial, "Your name" / "@handle · Signed in with Apple", a pílula FREE/PRO) e o botão Sign in with Apple quando fora, no mesmo grupo; **My Cue Voice** (`MyCueVoiceCard`, sobre a aurora violeta): **sem o mínimo**, "Make scripts sound like you." / "4 quick questions — about 20 seconds. No typing needed." e o botão amarelo **Set up My Cue Voice** (abre as quatro perguntas); **com ele**, "✦ SOUNDS LIKE YOU · Live preview" (uma frase na voz do criador), o interruptor "Use my voice in AI scripts" (o mesmo estado do chip do card de Scripts) e **"WHAT CUE USES"**: as linhas **I am · Topics · Audience · Voice** com o valor, cada uma **abre a pergunta que a guarda** (`VoiceSetupSheet` com `startAt`, modo edit). Abaixo ficam os grupos de ajuste fino (How I sound, My phrases, Who I talk to, My style, Niche; tudo grátis); **Creator preferences** (Default "Create for", Monetization goals); o **card do plano** sobre a aurora noturna (`NightAuroraBackground`): **FREE PLAN** em mono com "Every feature included", "Free exports · 4 of 5 left" com a barra amarela, "✦ Apple Intelligence · On-device · unlimited" e o botão amarelo "Try Pro free for 7 days"; no Pro, **"● PRO ACTIVE"**, "Cue Pro · Annual · renews…", "Unlimited exports, up to 4K" e Manage (com um toque de amarelo na aurora); Sign out |
| Settings | `Screens/Settings` | v26: título grande "Settings" e "How you record, every time."; o card **YOUR SETUP** (`SetupSummaryCard`, aurora violeta): a miniatura do formato padrão ("9:16") e quatro valores tocáveis (**Camera** Front · **Quality** 1080p 30 · **Mic** Automatic · **Text** 28 pt; os três primeiros abrem Recording, o último Prompter) com "Platforms can recommend another setup per video — you choose."; os **três tiles** (`SettingsTile`) **Recording** ("Front · Automatic"), **Prompter** ("Steady · 28 pt") e **Remote** ("Off" / "Connected"), cada um uma página; "Set it up once. Cue remembers how you create."; **GENERAL**: Language & Region (ícone azul, o idioma), **Appearance** (a faixa segmentada Automatic \| Light \| Dark com ícones, `AppearancePicker`, e a nota de que câmera, prompter e editor ficam escuros) e Privacy & AI data; **PURCHASES & ABOUT**: Restore purchases e Acknowledgements; e **Reset Creator Setup** (tinto vermelho, com confirmação: "…Your scripts, takes and edits stay."). Não inicia câmera, microfone ou pareamento ao abrir |
| Language & Region | `Screens/Settings/LanguageRegion` | Três linhas separadas, cada uma com sua explicação embaixo: **App Language** ("Controls the language of Cue’s interface."; iPhone Language + os 20 idiomas pelo nome nativo e, embaixo, no idioma da interface; muda a interface na hora e fica nesta tela), **Voice Following Language** ("Controls the language Cue listens for while you speak."; Same as Script + os 20, cada um com "Ready on this iPhone", "Downloads the first time you use it" ou "Not available on this iPhone" em laranja; um indisponível ainda pode ser escolhido, e o prompter avisa e rola na velocidade definida enquanto você fala) e **Script Language** (Auto-detect + os 20; é o idioma dos roteiros novos, e cada roteiro tem o seu em ••• › Script Language). Nenhuma muda a outra nem traduz nada (`LOCALIZATION.md`) |
| Recording / Prompter (Settings) | `Screens/Settings/Pages`, `Screens/CreatorSetup` | **Recording** (G2, `SettingsRecordingView`): "CAMERA & FORMAT" com Camera (Front / Back), Microphone (abre a lista: Automatic, as entradas conectadas e a salva quando não está conectada, com "pair it in Settings › Bluetooth"), Recording quality (720p / 1080p / 4K e 24 / 30 / 60 fps) e Default format (9:16, 4:5, 1:1, 16:9, em tiles com a proporção), e "Lens, mic, quality and format can still change for one take while recording.". **Prompter** (G3, `SettingsPrompterView`): no alto e fixa, a **prévia estática** em proporção (`TeleprompterPreview`: o texto no tamanho escolhido, a linha de leitura e o espelho) ao lado do seletor **Selfie \| Studio** ("Text over your camera, right under the lens." / "Full-screen text, no camera.") e "Shows proportions on your screen — not the final look."; abaixo, os **chips de seção** Reading · Text · Line · Window · Safe zones, que rolam até as linhas (`SetupRow.anchor`): Text size (Small / Medium / Large + slider 16–56), Scroll speed (0,3–2,0× e "about N words a minute"), Reading mode (Voice \| Steady), Reading line (↑/↓ de 8 pt a partir de 118 pt da lente, Reset), Show reading line, Mirror text, Safe zones e Display (abre os mesmos controles Aa, sem câmera/áudio). O que se muda aqui é o padrão; a recomendação por plataforma e as mudanças de uma take continuam como em 5.1 |
| Remote (Settings) | `Screens/RemoteControl/RemoteControlView` | **Remote Control** (G4): no alto o **status** (`RemoteStatusHero`, aurora noturna): um anel **cinza** sem remote ("No remote connected"), **amarelo** enquanto espera ou procura ("Waiting for your other device…") e **verde** conectado ("Remote connected" e o nome do aparelho); **Connect a Device** (`RemotePairingPanel`: botão amarelo → QR code 200 pt + código "ABC 234" + "Waiting for your other device…" + Cancel → "Remote Connected" com ✓ verde, o nome do aparelho e Disconnect; erro de rede local com Try again); **Use this device as a remote** (Enter a code → alerta); "Keyboards, foot pedals and presentation remotes are coming next." |
| Remote | `RemoteControllerView` | Tela cheia no outro aparelho (aberta pelo QR escaneado na Câmera, `cuestudio://remote?code=…`, ou pelo código digitado): fechar, "Remote" + ponto verde e o nome do teleprompter; card com o roteiro aberto, progresso, Playing / Paused / Recording e a velocidade (ou "Voice Following"); voltar ao topo, ‹‹, play/pause amarelo de 96 pt, ››; − velocidade +. Procurando: "Looking for the teleprompter…" + "Keep both devices close, with Wi-Fi on." A tela não apaga |
| Paywall (M1) | `Screens/Shared/Paywall` | v26: tela cheia sobre a **aurora noturna** (violeta com um toque de amarelo no alto, `NightAuroraBackground`), aberta só pelo Export (depois da 5ª exportação: "Keep posting with Cue") ou pelo Profile ("Create more. Sound like you."); "● CUE PRO" em mono amarelo; no contexto do Export, o **medidor "05 / 05 FREE EXPORTS USED"** (`PaywallExportsMeter`: a linha mono em laranja e a barra cheia; sem conversa de marca d'água); o **card de benefícios** (`PaywallBenefitsCard`: um ícone num tile, a frase e uma etiqueta mono à direita: "Unlimited video exports, up to 4K" · EXPORT, "Every feature stays open…" · FREE em violeta, "Your takes are always yours…" · YOURS); os planos (Annual pré-selecionado com o anel amarelo de 2 pt, "SAVE 58%", "$3.33/mo · 7 days free"; Monthly "7 days free · cancel anytime"); o rodapé em vidro noturno com "Start 7-day free trial", o que acontece depois e Restore, Terms, Privacy. Sem opção com marca d'água e sem vitalício. Nunca abre durante a gravação |

## 5. Navegação

**Tab bar nativa (v29, `TabView`)**: a do sistema, com o Liquid Glass do iOS 27 (nunca uma view própria). O conteúdo das abas rola por baixo dela, a
seleção desliza ao arrastar o dedo sobre a barra e a cápsula da aba ativa é a do sistema; o `.tint` é o amarelo (`accText`). Os ícones são os `CueIcon`
rasterizados como imagens template (`CueTabImage`, 26 pt, traço ≈1,6 pt) e Record é uma imagem com as duas cores (anel + ponto vermelho, 30 pt), porque a
barra só desenha imagens. Ordem: **Scripts → Takes → Record → Profile → Settings**. Record não é destino: selecionar abre "Start recording" e a aba
escolhida continua. A barra some (`toolbarVisibility(.hidden, for: .tabBar)`, via `PresentationService.hidesTabBar`) na página do script e no modo de seleção de Scripts.

```
RootView
└── MainView (TabView)
    ├── Scripts ─ NavigationStack ─ ScriptDetailView (a página Draft | Shaped; ••• › Versions & options abre o editor de escrita)
    ├── Takes ─ NavigationStack
    ├── Profile ─ NavigationStack (identidade, voz, preferências criativas e plano)
    ├── Settings ─ NavigationStack (`settingsPath`) ─ Creator Setup ─ Remote Control
    │                                              ├─ Language & Region ─ App / Voice Following / Script Language
    │                                              └─ Acknowledgements ─ licença de cada fonte
    └── Record (aba-botão; abre "Start recording" sem trocar de aba)
Sheets (sobre as abas): New script (+) · Start recording · Import · Need an idea? · Format · Create for (os três, do card de IA) · My Cue Voice (as quatro perguntas, sobre o card ou o Profile)
Full screen: Prompter (Selfie ⇄ Studio → Revisão do take) · Paywall · Remote (este aparelho controla outro)
Sheets do prompter: Display · Câmera · Audio Input · This take · Remote Control · Create for · scripts
Quick edit (fullScreenCover sobre a revisão): painéis sob a timeline (no iPhone SE, os cheios em sheet) ·
sheets Add music · Add photo or video · Export · Translate
```

A lista de Scripts usa seleção por `UUID`: o cartão "Last edited" e as linhas comuns atribuem
`script.id` como tag ao `NavigationLink`. A mesma identidade de seleção evita que a abertura
do cartão acrescente duas rotas `ScriptRoute` para o mesmo roteiro. Salvar um roteiro pode
promovê-lo a esse cartão sem mudar a hierarquia: Scripts → detalhe, e um único toque no voltar
nativo retorna à lista. Leitura/edição continuam na mesma tela; Studio/Record continuam em
`fullScreenCover`, sem adicionar destinos à pilha de Scripts.

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

**Recomendação, não imposição.** O preset da plataforma (formato, qualidade, fps; a zona segura segue
a plataforma sozinha) vira uma `SetupRecommendation` quando o roteiro abre no prompter, e nunca é
aplicado em silêncio nem gravado no Creator Setup. A gravação resolve cada valor por camadas
(`SessionSetup`): 1. mudança feita nesta sessão; 2. recomendação aceita ("Use Recommended"); 3.
Creator Setup; 4. fallback do sistema na captura (outra câmera ou microfone quando o pedido não
existe). Os padrões ficam em `PreferencesService` (`CameraSettings` + `PrompterSettings`, lidos como
`CreatorSetup`); o prompter lê e muda tudo por `SessionSetupService`, que guarda as mudanças de
teleprompter integralmente na sessão e salva as outras opções de câmera (grid, contagem…) como antes.
Os padrões de leitura usam o mesmo `PrompterSettings` e a mesma chave `prompterSettings` já existente:
fontes, cores e dimensões salvas por versões anteriores são preservadas sem reescrever o blob.
Cada sessão captura uma cópia dos padrões ao abrir; alterar o perfil só afeta novas sessões. A abertura
de roteiros não força mais a caixa ao máximo. Display no perfil e Aa na gravação compartilham os
mesmos controles, limites e unidades; o perfil nunca inicia captura ou reconhecimento. Reset Creator
Setup agora restaura também a aparência; Back to my setup restaura a cópia inicial da sessão. Uma recomendação pode
cobrir qualquer campo do setup (`SetupValues`), então outras plataformas e outros campos (tamanho do
texto, câmera, legendas) entram sem outro caminho.

O arquivo tem `revision`. Quando `AppLinks.platformRules` aponta para uma cópia publicada (um JSON
estático), o app baixa uma vez por abertura e só adota uma revisão maior, completa e do mesmo
`schemaVersion`; a cópia fica em cache. Sem URL, vale o arquivo do app.

## 6. Estados

- **Vazio:** biblioteca vazia (primeiro uso), filtro sem resultado ("No scripts here yet."), sem
  takes ("No takes yet" + "Record a take"), script vazio ("This script is empty…").
- **Carregando:** "Writing your script…" com brilho pulsante e um **Cancel** logo abaixo (cancelar não cria roteiro nem mostra erro; fechar a tela também cancela); se falhar, o aviso diz por quê e oferece **Try again**, que repete o mesmo pedido uma vez; indicadores nos chips de IA e nos
  botões Save/Share durante a exportação; no Quick edit, "Processing…" na prévia só quando uma
  mudança demora mais de 0,3 s (cortes e trims são instantâneos).
- **Erro / indisponível:** câmera sem permissão (botão para Ajustes), sem câmera, câmera parada;
  Apple Intelligence indisponível (explica e usa o rascunho estruturado); importação ilegível;
  compra pendente ou não verificada; take sem o arquivo de vídeo ou ilegível ("This video can't be
  opened", ferramentas desligadas), prévia que não montou ("The preview couldn't be built") e som
  que não pôde ser analisado ("Couldn't listen to this take" + "Try again" no Clean Up). Clean Up
  sem nada a sugerir: "All clean" e "Nothing to clean up here. Your take flows."
- **Carregando (Clean Up):** "Analyzing your take…" enquanto ouve a take (volume e transcrição).
- **Idiomas:** Voice Following num idioma que o aparelho não reconhece nunca troca de idioma: um
  toast (uma vez por sessão) diz "Voice Following can’t listen in Thai on this iPhone. The script
  scrolls while you talk.", o texto rola com o nível da voz e o Studio mostra "Scrolls at 0.7× while
  you talk" (no Selfie, "0.7× · While you talk" no lugar de "AUTO"); sem internet para baixar o
  modelo: "Voice Following needs to download Thai. Connect to the internet and try again.";
  roteiro sem idioma reconhecível: "Set this script’s language to follow your words…".
- **Carregando (Voice Following):** enquanto o modelo do idioma carrega, "Getting ready" (Selfie) /
  "Getting ready to follow your words. Scrolls at 0.7× while you talk." (Studio); baixando (só o
  idioma pedido, nunca outros), "Downloading 40%" / "Downloading Thai · 40%. Scrolls at 0.7× while
  you talk.". Nada disso trava a gravação; o texto anda na velocidade definida enquanto a voz soa
  até o reconhecimento assumir.
- **Setup e remote:** microfone salvo desconectado: a take grava com o disponível e um toast diz
  "AirPods Pro unavailable · Using iPhone Microphone instead" (uma vez por sessão); câmera que o
  aparelho não tem: "Back · Telephoto unavailable · Using Front instead"; no Creator Setup, o mic
  salvo aparece em laranja "Not connected · takes use another mic until it's back". Remote: "Waiting
  for your other device…", "Looking for the teleprompter…", "Remote Connected", sem rede local
  "Cue can't reach nearby devices. Turn on Local Network for Cue in Settings." + Try again; código
  digitado inválido: "That code doesn't look right. Check it and try again."; o remote sem roteiro
  aberto no teleprompter: "Open a script on the teleprompter" e os botões desligados.
- **Ferramentas de criador:** Remove Pauses "Listening for pauses…" → "No long pauses" / "Couldn't
  listen to this take" + Try again; Media "Adding…" no botão, "This photo or video can't be added" e
  "No room here — move the playhead to a free spot"; Voice-over sem microfone: "Turn on the
  microphone for Cue in Settings to record a voice-over", gravação curta demais: "Too short to
  keep"; Transitions sem cortes: "No cuts yet"; Cover desenhando: indicador na prévia, falha:
  "Couldn't draw the cover". Uma foto ou vídeo que sumiu do app fica de fora da prévia e do export
  em vez de derrubar a edição. Music: "Adding…" no botão e "This sound file can't be added" (sem
  trilha legível, como músicas protegidas); uma música ou foto de fundo apagada fica de fora.
  Voice: "Playing the original" com indicador enquanto mede, "There's no speech to compare".
  Background: "This iPhone can’t find people in video…" (o Color key continua) e, na câmera,
  "This camera can’t show the effect while recording…".

## 7. Movimento

- Sheets e toasts com mola curta (0,25–0,36 s). Contagem regressiva com "pop".
- Rolagem do prompter por `CADisplayLink`, calibrada para 215 palavras/min em 1,0×. O padrão é 0,7×
  (≈150 palavras/min, o ritmo natural) e a faixa vai de 0,3× a 2,0×. As estimativas de duração usam a
  mesma constante (`ReadTime`). Velocidades salvas antes da v7 (150 palavras/min em 1,0×) são
  convertidas para manter o mesmo ritmo.
- Voice follow: o texto desliza até a próxima palavra a ler, nunca para trás; a linha lida fica
  centrada na guia. O deslize se adapta à correção (`VoiceGlide`): ~2/3 do caminho em 0,2 s até meia
  linha (as palavras confirmadas uma a uma), em 0,35 s a partir de 2 linhas (o de antes, para um
  salto que o olho acompanhe), proporcional entre os dois. Enquanto a voz soa, o texto já anda um
  pouco à frente da última palavra reconhecida (`SpeechLead`: no ritmo medido da leitura, até 2
  palavras e nunca mais de meia linha); para numa pausa de 0,2 s, e o reconhecimento continua sendo
  a verdade — uma confirmação atrás da previsão segura o texto onde está, uma à frente o leva junto.
  A previsão nunca chega ao fim do roteiro (só a última palavra ouvida o termina).
- Zoom da timeline do Quick edit: desliza em 0,28 s (ease-out, uniforme em escala).
- Transição Slide (0,4 s): a seção que entra desliza da direita sobre a que sai, com ease-in-out;
  faz parte do vídeo (é renderizada), então não muda com Reduce Motion.
- **Reduce Motion:** zoom da timeline sem deslizar, toasts só com fade, contagem sem escala, barras de voz e ponto de gravação
  sem animação contínua, "Writing your script…" sem pulsar.

## 8. Acessibilidade

- Botões só com ícone têm `accessibilityLabel`; toggles e opções marcam `.isSelected`.
- Cards e linhas combinam os filhos em um elemento; tiles de take leem "Take 3, 0:44, best take".
- Prompter: ajustável com VoiceOver (desliza 3 linhas), valor = progresso.
- Alça da linha de leitura: ajustável com VoiceOver (8 pt por gesto), valor = distância da câmera.
- Pill do microfone: label "Audio Input", valor = nome da entrada em uso; na sheet, a entrada em uso
  marca `.isSelected` (`prompter.audioInputButton`, `audioInput.option`).
- Página do script: `page.backButton`, `page.platformChip` (valor = a plataforma), `page.mode.<draft|shaped>`, `page.menuButton`, `detail.recordButton` (o Rec), `page.titleField`, `page.meter`, `page.stopButton`, `page.draftEditor` ("Script text"), `page.shapeButton`, `page.cueBreakButton`, `page.textSizeButton`, `page.platformHint`, `page.lengthBar`, `page.section.N` / `page.sectionText.N` (o do hook abre Hooks), `page.tip.<hook|long>` com `page.tip.fix` e `page.tip.dismiss`, `page.suggestCTA`, `page.toDraft`, `page.takes`, `page.selectionBar` com `page.selection.<rewrite|shorter|strongerHook|inMyVoice>`, `page.candidate` com `page.candidate.use` / `page.candidate.keep`, `page.nudge` com `page.nudge.record` / `page.nudge.shape`, `page.voicePreview` com `page.voice.<mine|without>`, `page.voice.approve`, `page.voice.adjust`; `voiceAdjust.sheet`, `voiceAdjust.<tooFormal|tooMuchSlang|tooOverTheTop|notMyPhrase|tooLong>`, `voiceAdjust.scope`, `voiceAdjust.rewrite`. Scripts: `scripts.summary`, `scripts.searchButton`, `scripts.filterMenu` com `scripts.filter.<all|plataforma|folder.nome>`, `row.recordButton` / `row.studioButton`. Ideias e formato: `ideas.sheet`, `ideas.topic.<all|nicho>`, `ideas.row.<id>`, `ideas.write.<id>`, `ideas.moreButton`, `format.sheet`, `format.<auto|ad|review|tutorial|list|story|opinion|launch|apology>`. My Cue Voice: `ideaCard.voiceChip` (valor "Set up" / "On" / "Off"), `ideaCard.voiceToggle` (o switch do chip), `voiceSetup.progress`, `voiceSetup.role.<id>`, `voiceSetup.skipRole`, `voiceSetup.back`, `voiceSetup.justSave`.
- Card de IA (Scripts, com e sem roteiros): o campo é `ideaCard.field` (rótulo "Your idea", valor = o rascunho; o placeholder é "Speak or type your idea…"), o microfone `ideaCard.dictate` ("Dictate your idea" / "Stop dictation", dica "Your words appear here to review before you send."), a seta `ideaCard.submit` ("Generate script", ou "Need an idea?" com o campo vazio); os chips `ideaCard.platformChip`, `ideaCard.voiceChip`, `ideaCard.ideasChip` e `ideaCard.formatChip`; o estado do ditado é `ideaCard.dictationStatus` (leitura "Listening…" e um aviso falado ao começar a ouvir), as palavras só para leitura são `ideaCard.transcript` (dica "Tap to stop and edit.") e o aviso de erro `ideaCard.dictationNotice` (com "Open Settings" quando o microfone está desligado). My Cue Voice: `profile.useVoiceToggle`, `profile.setUpVoiceButton`, `profile.voiceRow.<role|niche|audience|tone>`, `profile.upgradeButton`; Settings `settings.setupCard`, `settings.setup.<camera|quality|mic|text>`, `settings.<recording|prompter|remote>Tile`, `settings.appearancePicker` com `settings.appearance.<system|light|dark>`, `settings.prompterChip.<reading|text|line|window|safeZones>`, `settings.prompterMode`, `settings.prompterPreview`, `remote.statusHero`; paywall `paywall.benefits`, `paywall.exportsMeter`; setup `voiceSetup.sheet`, `voiceSetup.<niche|audience|tone>.<valor>` (marcam `.isSelected`), `voiceSetup.saveButton` (Continue / Done / Write my script). Alvos de 44 pt, Dynamic Type (a altura do campo do card acompanha o tamanho da fonte).
- Barra do recorder: `prompter.scrollMode.<voice|steady>` (rótulo "Voice Following" / "Steady"), `prompter.speedSlider` (ajustável, valor "0.7×"), `prompter.playButton`, `prompter.displayButton`, `prompter.audioInputButton`, `prompter.setupButton`, `prompter.lastTakeButton` (valor "3 takes"), `prompter.textWindowResizeHandle` (ajustável: uma linha a mais ou a menos; valor "93 percent wide, 6 lines"; ação "Reset text window"), `prompter.cameraSettingsButton`, `prompter.recordButton` (também o Stop da barra compacta), `prompter.moreButton` com `prompter.moreRemote` e `prompter.moreThisTake`; barra compacta `prompter.compactBar`, `prompter.modeChip`, `prompter.recordingClock`, e a área que mostra a barra inteira `prompter.showControlsArea` ("Tap the screen for controls").
- Editor v26: `edit.backButton`, `edit.statusChip`, `edit.doneButton` e a pergunta `edit.doneSheet` com `edit.done.<share|download|ready|notYet>`; Smart `edit.smart.<captions|pauses|voice|autoAdjust>`; Cover `edit.cover.layout.<hook|number|kicker|question|beforeAfter>`, `edit.cover.font.<anton|grotesk|serif|system>`, `edit.cover.suggestion.N`, `edit.cover.highlight.N`, `edit.cover.element.<arrow|circle|series|badge|handle>`, `edit.cover.effect.<clean|lift|outline|dim|blur>`, `edit.cover.applyMyStyle`, `edit.cover.saveMyStyle`, `edit.coverPreviewMode`, `edit.coverGrid`; abas `edit.panel.tab.<frame|coverText|elements|look>`.
- Takes: `takes.pipeline`, `takes.stage.<pick|edit|ready|shared>` (valor = a quantidade, marcam `.isSelected`), `takes.next`, `takes.layout.<grid|list>`, `takes.platformMenu` com `takes.platform.<plataforma|all>`, `takes.video.<id>` (rótulo: título, etapa, plataforma, takes), `takes.emptyStage`. Revisão: `review.takeLabel`, `review.compareChip` com `review.previousTake` / `review.nextTake`, `review.stageBar`, `review.lengthFit`, `review.fromScript`, `review.suggestBestButton`, `review.muteButton`, `review.editButton` / `review.retakeButton` / `review.saveButton` / `review.shareButton`, `review.exportNotice` e `review.goPro`.
- Pill do Voice Following (`prompter.voiceIndicator`): label "Voice Following", valor = o que ele
  está fazendo ("Listening", "Paused", "Scrolls at 0.7× while you talk", "Getting ready to follow
  your words…", "Downloading Thai · 40%…"); a linha do Studio é `prompter.voiceStatus`.
- Quick edit (v10): a timeline é um elemento ajustável (`edit.timeline`, 0,1 s por gesto), valor =
  "Clip 2 of 3, 4.2 seconds, playhead at 00:07.1", com as ações "Select this clip", "Zoom in" e
  "Zoom out". Toolbar `edit.toolbar` com `edit.toolbar.<item>` (`back` volta à principal); no iPhone SE
  os itens só têm ícone e o rótulo fica no VoiceOver e num toque longo. Barra do player:
  `edit.timeLabel`, `edit.playButton`, `edit.undoButton`, `edit.redoButton`, `edit.fullScreenButton`;
  topo `edit.doneButton`, `edit.durationChange`, `edit.exportButton`. Painéis `edit.panel.<painel>`
  com `edit.panel.subtitle`, `edit.panel.reset`, `edit.panel.apply` ("Apply") e
  `edit.panel.advanced`; abas `edit.panel.tab.<aba>`; controles `<id>.<valor>` marcados `.isSelected`
  (ex.: `edit.speed.1.50`, `edit.style.scope.allTexts`, `edit.style.editorial`, `edit.captionReveal.box`,
  `edit.export.resolution.4K`). Pausas `edit.pause.N` (valor "Remove"/"Keep", ação para trocar) com
  `edit.pause.N.listen`, `edit.pauses.apply`; legendas `edit.captionLine.N`, `edit.captionField`,
  `edit.captionStart.minus/plus`, `edit.captionEnd.minus/plus` (dentro de More, `edit.captionMore`), `edit.captionPrev`/`edit.captionNext` (a posição é lida "Line 3 of 12"), `edit.captionPlay`, `edit.captionSplit`, `edit.captionJoin`, `edit.captionDelete`, `edit.captionsDeleteAll`, `edit.toolbar.deleteAll`; Scripts sem roteiros: `empty.promptCard`, `scripts.promptCard`, `empty.writeButton`, `empty.importButton`, `empty.skipButton`; Export `edit.export.*`. Adjust: `edit.adjust.autoDial`, `edit.adjust.autoAmount`, `edit.adjust.auto`, `edit.adjust.compare` (valor "Showing the original" / "Showing your edit"), `edit.adjust.tint`, `edit.adjust.vibrance`; Filters `edit.filter.<id>`; presets `edit.captionPreset.<tema>`. Sliders são
  ajustáveis pelo passo do controle; o switch das legendas é um toggle. Na prévia, cada texto é um
  botão (`edit.textHandle`: "Tap to select" / "Tap to style"), a legenda arrastável também
  (`edit.captionHandle`: "Drag up or down to move every caption").
- Pill do setup: label "Recording setup", valor = origem + "4K · 9:16" (`prompter.setupButton`); card de
  recomendação `prompter.recommendationCard`, `prompter.useRecommendedButton`, `prompter.keepSetupButton`;
  linhas do "This take" `setup.row.<campo>`; Creator Setup `creatorSetup.<campo>.<valor>` (chips e
  tiles marcam `.isSelected`), `creatorSetup.resetButton`; remote `remote.connectButton`,
  `remote.qrCode`, `remote.code`, `remote.connected`, `remoteController.<comando>` (cada botão diz o
  comando: "Faster", "Back three lines"…).
- Editor de roteiro: cada parágrafo da escrita é um campo (`editor.paragraph.N`, "Script text"), o
  título `editor.titleField`, o status `editor.status`, Done `editor.doneButton`; a barra
  `editor.accessoryBar` com `editor.tool.ai|cues|sections|options` (marcam `.isSelected` com o painel
  aberto) e `editor.keyboardButton` ("Hide keyboard" / "Show keyboard"); painéis `editor.panel.<nome>`,
  `editor.cue.<nome>`, `editor.section.N`, `editor.discardButton`, `editor.textSize.<pt>`. Na
  leitura, a linha-resumo é um botão ("Script details", valor = "TikTok, 123 words, ~49s. In the ideal
  range"), cada parágrafo tem a ação "Edit" para o VoiceOver e `detail.paragraph.N`, e os rótulos dos
  blocos são cabeçalhos. O toast com **Undo** (`toast.action`) é anunciado e fica 4 s.
- **Tamanhos de acessibilidade** (`dynamicTypeSize.isAccessibilitySize`, conferidos com o passeio exploratório em
  iPhone 17 e SE, AX3 a AX4): o texto que diz o que um controle faz **quebra em vez de terminar em "…"** (`HUDLine`,
  `IdeaCardChip`, linhas das takes, o cabeçalho "Recent" que passa o menu e o Select para a linha de baixo) e as
  seções do roteiro empilham o rótulo sobre as palavras (`ScriptSectionView`), o aviso violeta põe Fix e ✕ numa linha
  embaixo (`ScriptTipRow`) e o medidor de duração põe o "Ideal" sob o tempo (`ScriptLengthBar`). O que é **cromo de
  navegação ou de player** para de crescer num tamanho limite: a barra do topo da página do script no padrão
  (`large`), a barra de baixo do Draft (`xxLarge`, sem a dica quando não cabe), a revisão da take (`xxxLarge`), a grade de
  destinos do Share to (`xLarge`) e o rodapé do paywall (`xxxLarge`); sem esses limites, a página do script ficava mais
  larga que a tela e as ações da revisão se sobrepunham.
- Toasts são anunciados (`AccessibilityNotification.Announcement`).
- Alvos de toque de 44×44 mesmo quando o visual é menor.
- **Contraste** (Human Interface Guidelines › Accessibility, que pede 4,5:1 para texto e 3:1 para o
  que identifica um controle): vale com e sem **Increase Contrast** (o app é só escuro).
  `ColorContrast` mede (luminância relativa, composição de cores translúcidas) e
  `PaletteContrastTests` falha se um token sair do mínimo: `ink`, `ink2` e os textos coloridos
  (`accText`, `warnText`, `dangerText`, `infoText`, `successText`) em `bg`, `surface` e `surface2`;
  `ink` e `ink2` também em `surface3`; os textos coloridos sobre o próprio `…Soft`; os rótulos sobre
  os preenchimentos vivos (`accInk` sobre `acc` e `warn`, branco sobre `dangerFill`); `ink3` a 3:1 em
  toda superfície. **Regras:** (1) `acc`, `warn`, `danger`, `info` e `success` são preenchimentos e
  pontos; texto e ícone usam o token `…Text`; (2) `ink3` nunca é frase: é chevron, contorno tracejado, anel, desligado; texto
  terciário usa `ink2`; (3) nada de `Color.white`/`.black` solto em tela que muda de aparência: use
  `ink`/`bg`; (4) cor nunca é o único sinal (a faixa de duração diz o texto, o selecionado muda de
  peso e preenchimento); (5) `Color(light:dark:lightIncreasedContrast:darkIncreasedContrast:)` dá a cada
  token translúcido um degrau mais forte com Increase Contrast (`ink2` 60% → 78%, `ink3` 45% → 62%,
  `separator`). **Câmera, prompter, revisão da take e editor** (`.videoContext()`) ficam escuros em
  qualquer aparência: são vistos sobre vídeo, e os tokens dinâmicos resolvem para o escuro dentro
  deles; o resto do app segue o iPhone ou Settings › Appearance, e estes testes e as regras acima são o
  que impede uma tela amarela sobre branco. Ao criar uma tela fora desses quatro contextos, teste-a nas
  duas aparências (`-uiTestAppearance light|dark`).
- Identificadores para UI tests: `"<tela>.<elemento>"` (ex.: `hero.recordButton`, `editor.doneButton`).

## 9. Diferenças em relação ao protótipo

- **v27, fase 1b (primeiro voo):** o onboarding "first voyage" (1.1–1.5 e 1.6 como treino no prompter real). **Decisões:** é uma camada sobre o app (não `fullScreenCover`) para o prompter do treino poder abrir por cima; o roteiro de reserva é **um modelo localizado** com o nome do tema, não oito roteiros; temas digitados ficam em `CreatorProfile.customTopics` (perfis antigos abrem sem o campo); quem já usa o app (roteiros, takes ou temas) nunca vê o voo; o "first star" (1.7) e as animações finas de cada capítulo (comet, ignite) seguem nas fases 1c–1g. **Diferenças:** o protótipo tem a animação do íris abrindo para o rosto ao permitir a câmera; o app mostra o ✓ Allowed sem o íris (o alerta do sistema cobre a cena).
- **v26, fase 7 (Settings, Profile e Pro):** o Profile com o card de My Cue Voice (sem o mínimo, um botão; com ele, a prévia e as linhas "What Cue uses"), o card do plano sobre a aurora noturna, o Settings com o card "Your setup", os três tiles e as páginas Recording, Prompter e Remote, o paywall noturno com o card de benefícios e o medidor de exportações. **Decisões:** a página única Creator Setup virou **três páginas** (Recording, Prompter e Remote), e o Reset Creator Setup passou para a raiz do Settings; o paywall **só promete o que o Pro muda** (exportar), então os benefícios do protótipo ("Full My Cue Voice", "Hook variations", "Cover styles", "Remote from Apple Watch") não entram: tudo isso é grátis no app, e a linha que o diz usa a etiqueta FREE; a prévia do prompter é estática e em proporção, como no protótipo. **Diferenças:** o G3 do protótipo tem um chip "Background" para o Studio e "While recording"; o app mantém Display (janela, fundo e o resto) numa sheet e não tem mais "esconder controles" (saiu na fase 2); o P1 do protótipo mostra "voice examples" nas linhas do card, e o app mostra uma frase só (a de "Sounds like you"); "Language & Region" e "Acknowledgements" (G5, G6) mantêm as telas de antes.
- **v26, fase 6 (página do script, home e My Cue Voice):** a página única Draft \| Shaped, a home com o card Let’s Cue em chips e a lista Recent com o status de cada roteiro, as sheets Need an idea? e Format no lugar da sheet de três abas, a IA escrevendo na página e o My Cue Voice em quatro perguntas com o roteiro como prévia. **Decisões:** o roteiro **salva sozinho** (sem Done) e a versão nova (com takes) é **uma por visita**, para a escrita não criar uma versão por tecla; "Stronger hook" usa a ferramenta More energy e "Rewrite" a More human (não há ferramenta própria); "¶ Cue break" põe a marca [pause] do app (o protótipo desenha um ¶); "Without" escreve a ideia sem a voz só quando o criador pede; o **tipo de criador** (8 cartões) é novo e opcional, e o resto do fluxo usa os campos que o app já tinha (temas, audiência, tom). **Diferenças:** o protótipo tem 20 categorias de tema com subnichos, "+ More topics", audiência livre, nível do público, o que vêm buscar e o que os segura, 8 tons e a sheet "Example" (colar, falar ou escolher um roteiro): o app mantém os 8 temas, as 4 audiências e os 6 tons que o modelo de IA já usa (acrescentar categorias pediria novas ideias iniciais e traduções nos 20 idiomas); a faixa "Does it sound like you?" mostra "Sounds like me" e "Adjust" sem a lista de diferenças por clique; **o progresso parcial não é guardado** ("Not now" fecha e o chip volta a "Set up"); sem Apple Intelligence a seta e o ↑ das ideias ficam desligados (os briefs por formato, que geravam sem modelo, saíram da interface); o menu ••• é o `Menu` nativo, não o popover do protótipo.
- **Alça de redimensionar a janela de texto (Selfie):** vem do protótipo v26 (`rz` em `Cue App v26.dc.html`), que a desenha no canto inferior direito da janela, e não era pinça de dois dedos. **Diferenças:** o protótipo grava o tamanho como padrão do criador ("Saved as your default"); o app o muda só para a take, como todo o Layout (o padrão fica em Settings › Prompter e em Display); os limites são os do app (50–93% de largura, 160–380 pt de altura), não os 50–100% e a altura até o fim da tela do protótipo; a janela segue a linha de leitura (a linha fica 25% abaixo do topo), então a altura que o dedo pede é dividida por 0,75 para o canto ficar sob o dedo.
- **My Cue Voice no card (chip e perguntas):** o protótipo faz do chip o próprio interruptor ("My Cue Voice" aceso / "· Off"); no app o chip abre as perguntas e o liga/desliga é um switch de verdade dentro dele, e a primeira pergunta (tipo de criador) não avança sozinha ao tocar num cartão como no protótipo: todas as perguntas têm o botão Continue, para o criador sempre ver como seguir.
- **v27, fase 1a (cara das abas):** a tab bar flutuante com o orb que viaja, o céu estrelado atrás de Scripts, Takes, Profile e Settings (`skyBackground()`) e os **filtros de Scripts por rede** (`PlatformFilterChips`: "All 5 · TikTok 2 · Reels 1…", o escolhido em branco, pastas depois, no lugar do menu "All ⌄"), com o resumo mono "5 SCRIPTS · 1 READY TO RECORD". **Decisões:** a barra fica fora do quadro das telas (em vez de sobre elas, como na maquete) para que a lista nunca passe por baixo dela e `isHittable` seja honesto; o ponto de cor do tema nos roteiros espera a etiqueta automática (fase U1); o "Go Pro" da revisão e da sheet Share to abre o paywall do Profile enquanto sobram exportações grátis.
- **v27, fase 0 (fundação):** o pacote "Cue Universe" (`design/cue-universe-v27/`, com direção, specs, mapa de telas e prompts; as imagens PNG @3x ficam fora do repositório) entra por fases. A fase 0 traz **o app só escuro** (some o modo claro, o `AppearanceService`, o seletor do Settings, os argumentos de teste e `videoContext()`), os **tokens v27** (`inkHint`, mundos, as novas cores de Shorts e Stories), `CueIcon`, `OrbSlider`, `StarfieldView`, os efeitos de luz, `CueMotion`, o `PersonalizationService` (céu, celebrações, haptics e a etiqueta automática de tema, que a tela Personalize usa) e o **catálogo de design** de debug (`-uiTestCatalogue <colors|icons|orbs|effects|sky>`). **Decisões:** os tokens da v27 evoluem o `Palette` (as mesmas funções, outros valores) em vez de criar `CueColor`, `CueFont` e `CueSpacing` em paralelo; `Haptics` ganhou `soft` e `success` e um interruptor global, em vez de uma classe nova; os ícones viram assets vetoriais e não SF Symbols personalizados. **Diferenças:** o orb ainda não está ligado às telas (isso é a fase 1); a medida de CPU do céu (menos de 2% num iPhone 12) só se faz no aparelho; as fontes do editor entram na fase do editor.
- **Passada de bugs (depois da fase 8):** o "Go Pro" da revisão abre o paywall do Profile enquanto ainda há exportações
  grátis (o texto "You've used your 5 free exports" é só para quando acabaram); a sheet do My Cue Voice sai do conteúdo
  sempre escuro do card, então segue a aparência no claro; Stop antes da primeira palavra mantém a ideia no card, e um
  erro não reinicia a geração só porque a página reapareceu; em árabe, "takes" e "vídeos" voltaram ao formato "N rótulo"
  dos outros idiomas. O preview em branco do editor e da revisão no Simulator **não é bug**: o mesmo acontece no
  commit anterior, o compositor de vídeo só renderiza no aparelho.
- **v26, fase 8:** os três cards de IA ficam violeta sólido com texto branco (ver seção 2) e o resto do claro já vinha dos tokens da fase 1; as telas foram conferidas contra `screens/light/` (Scripts, Profile, Settings, Paywall, sheets). **Diferenças:** o violeta é mais escuro que o do protótipo (`#271C84`–`#2E2290` contra um roxo médio) porque o texto secundário a 62% precisa de 4,5:1 sobre ele, e o teste vale mais que o protótipo; o card do Settings mostra os quatro valores em tiles translúcidos brancos em vez dos cinza do protótipo.
- **v26, fase 5 (editor):** a barra do topo (voltar, chip de rascunho, Done que pergunta), a toolbar na ordem do protótipo com o ✦ Smart em violeta, o Adjust em chips com o ◐ de segurar, a moldura branca do clipe e o Cover em quatro abas com layouts, elementos, efeitos e "My cover style". **Decisões:** o **voltar** usa o `cancel()` de antes (guarda o rascunho e toca o aviso "Draft kept"); "Not yet" guarda o rascunho mesmo sem mudanças (é o que põe o vídeo em IN EDIT); a sheet de Export saiu do alcance, como no protótipo (I02); "Studio Voice" é o novo nome de Voice no editor; o tile Auto adjust do Smart roda a medição real do Adjust (não os números fixos do protótipo). **Diferenças:** as alturas dos painéis continuam por tamanho (mini, médio, cheio) e o conteúdo só rola, como segurança, em telas compactas ou com texto grande — o protótipo fixa 280 pt e quebra em abas, e isso não foi reconstruído painel por painel; "Text behind me" é real (Vision), enquanto o protótipo simula com uma máscara fixa (I09); o destaque da palavra se escolhe por chips, não tocando na palavra da prévia.
- **v26, fase 4 (Takes e revisão):** o `TakeStage` (PICK/EDIT/READY/SHARED) é **derivado** e testado, e alimenta o pipeline, o selo de cada vídeo, o NEXT e a barra da revisão. **Decisões para ficar perto do protótipo:** a grade 9:16 é o padrão e a lista é opcional (a escolha fica guardada); o menu de plataforma é um `Menu` nativo (sem os pontos coloridos nos itens, que o menu não desenha); o peek usa o `contextMenu` com pré-visualização do sistema; deslizar na lista é o `swipeActions` do `List` (só na lista; na grade o atalho é segurar); a revisão não tem mais a faixa "Your takes" nem a sugestão automática de tocar: o chip, o deslizar e o ✦ Suggest best (que leva à take sugerida e deixa a ★ para o criador) a substituem. **Rascunho:** a etapa IN EDIT vem de um rascunho do Quick edit aberto numa take; a pergunta do Done ("Is it ready to post?") e o voltar sem perguntar são da fase 5.
- **v26, fase 3 (barra do recorder):** o Selfie ganhou a barra de vidro noturno (seletor Voice \| Steady, SPEED, linha HUD, última take com a quantidade, •••) e a **barra compacta da gravação** (tocar na tela mostra a inteira por 4 s), o pill REC passou para a esquerda, o cartão de recomendação ficou violeta e o `CueSlider` entrou no recorder. **Decisões para ficar perto do protótipo:** o segmento diz "Voice" (a chave de "Voice" do Quick edit; o nome completo fica no VoiceOver); em Voice a linha traz também a onda ao vivo e, quando o modelo carrega ou não segue as palavras, o estado (informação que o app tem e o protótipo não); o countdown e o Remote saíram dos botões para a •••, um menu nativo. **Diferenças:** o Studio não grava, então fica sem a fileira de captura e a barra compacta; o `CueSlider` só está no recorder (o Display e o Creator Setup mantêm o `Slider` nativo); o vidro é um material fino com o preenchimento noturno, sem o `backdrop-filter` do protótipo.
- **v26, fase 2 (nomes e recursos que saem):** **Creator Voice virou My Cue Voice** em toda a interface (nome de marca, igual
  nos 20 idiomas; os nomes de tipos e as chaves salvas não mudaram). **"Hide controls while recording" e o botão
  do olho saíram** (os ajustes salvos com a chave antiga continuam abrindo; até a fase 3 a barra de controles
  fica na tela gravando). **New script** tem só Write my own e Import (a IA vive no card "Let’s Cue!"), como no
  protótipo. **Decisões tomadas para ficar mais perto do protótipo:** a seta do card com o campo vazio abre as
  ideias ("Need an idea?", `generateScript(.themes)`), como em `go()` do protótipo; sobre a câmera o New script
  oferece Paste e Import (sem IA ali); o `PromptCard`, o `AnimatedPromptBackground` e o caso `generateScript` do
  prompter saíram por ficarem sem uso. As sheets de ideias e de formato como sheets pequenas (S2c/S2d) e a
  aposentadoria das 3 abas do Generate são da fase 6.
- **v26, fase 1 (tokens e componentes):** o `Palette` ganhou os valores de Night Session e os tokens de IA
  (`ai*`), vidro (`glass*`), controles (`chipOn`, `segmentOn`) e faixas (`lane*Ink`); `GlassNight`,
  `HUDLine` e `StageBar` existem mas nenhuma tela os usa ainda (recorder e takes, fases 3 e 4). Nenhum
  layout mudou. **Onde o protótipo não passa nos testes de contraste, vale o teste:** `ink3` claro
  `#6A6D82` (o do protótipo dá 2,7:1 sobre `surface2`), `ink3` escuro a 45% (40% dá 3,0:1 só no
  `surface3`), e os textos coloridos do claro continuam `#7A5C00` / `#9A4A00` / `#1A6F2E` / `#00638F`
  (os do protótipo dão 3,2–4,4:1). `surface3` e `surfaceMuted` são degraus derivados. **Ficou para as
  fases seguintes:** slider customizado (trilho de 4 pt, polegar branco de 24 pt: fases 3 e 5; hoje o
  `Slider` nativo com o tom amarelo), card de IA do claro como degradê violeta sólido com texto branco
  (fase 8), brilho do paywall em violeta com um toque de amarelo (fase 7), e as cores por papel em cada
  tela (estrelas do card de ideias em violeta, linhas HUD): cada uma entra com a tela que a refaz.

- **Quick Creator (editor de criador):** não está no protótipo; vem do pedido "Simple enough for
  anyone. Powerful enough to publish.": os 20% de edição que resolvem 80% de quem grava falando
  para a câmera, sem virar um editor profissional. Tudo roda no aparelho (AVFoundation, Core Image,
  Speech, AVAudioRecorder), sem API, servidor, nuvem nem custo por uso. Arquitetura, sobre o que já
  existia:
  - **Uma receita só.** Tudo entra no `TakeEdit` (texts, media, voiceOvers, textLook, captionLook, cover) e a
    velocidade no `EditSegment.speed` da `EditTimeline`; preview e export continuam montando o mesmo
    `EditedComposition`, e o original nunca muda. Edits salvos antes abrem sem nada disso.
  - **Presos à gravação.** Textos, mídia e o início de cada voice-over guardam segundos da gravação
    (como as legendas) e viram tempo editado por `EditTimeline.editedSpan(forSource:)`. Um corte ou
    uma velocidade antes deles não os tira do que está sendo dito, e a prévia (que toca o
    `reachable`) e o export caem nos mesmos momentos sem deslocamento. Um texto cujo trecho foi
    cortado some; um voice-over toca inteiro a partir do seu início (cortes embaixo não picotam a
    voz) e para no fim da edição.
  - **Velocidade por seção**, sem rampas: a seção é esticada na composição
    (`scaleTimeRange`, imagem e som juntos) e o som mantém o tom (`audioTimePitchAlgorithm =
    .spectral` na prévia e no export). Toda conversão entre tempo editado e da gravação passa pela
    velocidade (trim, cortes, Remove part, frames, zoom, transições); uma troca de velocidade é uma
    costura (mergulho de 12 ms no som), mesmo sem nada removido.
  - **Renderização única.** Textos são desenhados por `TextOverlayRenderer` (UIKit) e compostos pelo
    `CueVideoCompositor` como as legendas; fotos são imagens e vídeos de B-roll vêm de uma trilha de
    vídeo a mais, lida só nos trechos em que um aparece; Slide usa a mesma segunda trilha do Dissolve.
    Na prévia, os contornos e a cópia que segue o dedo são só guias: o que se vê gravado no vídeo é o
    que exporta.
  - **Camadas simples:** até 3 fotos e vídeos ao mesmo tempo, com ordem explícita (vídeo → mídia na
    ordem das camadas → textos → legendas); vídeos sobrepostos vão para trilhas próprias da
    composição. Textos podem se sobrepor (a trilha empilha em até 3 faixas), vários voice-overs em
    trilhas de som próprias.
  - **Movimento** (`OverlayKeyframe`, `OverlayMotion`): keyframes de posição, escala e opacidade em
    textos e mídia, com interpolação linear ou suave, contados do começo do item (mover o item leva o
    movimento; esticar ou cortar deixa os keyframes onde estão no tempo dele, e os que passam do fim
    esperam). Sem editor de curvas. Preview e export avaliam o mesmo `OverlayMotion`.
  - **Tradução de legendas** (`CaptionTranslation`, `CaptionTranslationBuilder`, `AppleTranslationSession`):
    framework Translation da Apple, no aparelho (a `translationTask` do SwiftUI baixa os idiomas depois
    de perguntar), sem API, nuvem nem custo por uso; o suporte de cada par é perguntado a cada vez
    (`LanguageAvailability`), nunca deduzido dos idiomas da interface. Traduz frase por frase (até 4
    linhas, quebra em pontuação, pausa ou troca de gravação), depois quebra em linhas de até 32 letras
    (16 sem espaços) no tempo da frase dividido pelo tamanho: nenhuma palavra da tradução é presa à
    voz, então os efeitos por palavra não passam para ela. Original e tradução ficam separados; cada
    linha traduzida guarda o texto original de quando foi traduzida, e uma mudança no original a marca
    como desatualizada sem apagar correções.
  - **Legendas animadas** (`CaptionAnimator`, `WordEmphasis`): cada estado (uma palavra acesa, um
    grupo) é uma sobreposição desenhada quando aparece (`LazyText`) e guardada num cache pequeno do
    compositor (`OverlayImageCache`, 48), então a memória não cresce com a duração do vídeo. A caixa
    do Box é medida com TextKit na mesma diagramação que desenha a linha; a linha não muda de tamanho
    de uma palavra para outra.
  - **Coleção de legendas do vídeo** (`CaptionTheme`, `CaptionSettings`, `CaptionCollectionRenderer`):
    o catálogo principal tem **Cue, Educational, Interview, Impact, Pop e Editorial** (Clean fica para os edits que o escolheram; ver "Presets completos" abaixo), em faixa horizontal
    com miniaturas realmente renderizadas. Cue é o padrão de novas receitas. As fontes Space Grotesk
    Bold / Anton / Inter SemiBold / Poppins ExtraBold / Manrope Bold ficam no bundle, com licenças
    SIL OFL e alternativa local para glifos ausentes. Interface e teleprompter não mudam.
    Cue destaca só a palavra numa caixa amarela com texto preto; Impacto usa caixa alta, contorno
    preto e palavra lima; Clean é branco com sombra discreta, sem acompanhamento por padrão;
    Pop tem caixas roxas arredondadas por linha e palavra amarela; Editorial tem branco suave,
    fundo preto translúcido e palavra pêssego. O painel secundário contém tamanho, posição,
    cor do destaque, acompanhamento quando há tempos confiáveis e restauração do padrão.
    Trocar estilo nunca transcreve nem altera o roteiro. Desligar Captions mantém as correções.
    `captionCollection == nil` em receitas antigas mantém seu renderer `CaptionStyle`/`TextLook`;
    os sete `TypePreset` continuam para textos, não no catálogo de legendas. `All captions`
    também usa a coleção nova. Cada segmento mantém layout TextKit fixo: só cores e caixa mudam.
    Tempos por segmento ficam estáticos, sem divisão artificial por palavra. O compositor e seu
    cache de 48 imagens são compartilhados com exportação. A posição respeita a área segura.
    `CaptionTimelineMapping` intersecta áudio de origem e trecho mantido antes de aplicar velocidade;
    split sem remoção não reinicia a linha, cortes desconectados produzem instâncias distintas,
    cópias/reordenação seguem seu áudio. Nenhuma palavra ultrapassa o trecho mantido.
    `Take.scriptReference` e `ClipSource.scriptReference` congelam o roteiro usado; takes antigas
    só usam a versão ainda correspondente. A transcrição bruta é persistida e reaproveitada,
    separada das correções, inclusive quando gerada na exportação. Cada take da montagem usa
    sua própria referência e idioma, salvo escolha explícita do criador.
    A análise compartilhada do Clean Up não transforma palavras estimadas num corte de frase
    inteira: fillers/retakes são propostos apenas em sequências de palavras com limites medidos;
    pausas continuam vindo da análise de níveis do áudio.
  - **Montagem** (`ClipSource`, `EditSegment.sourceID`, `ClipAnchor`): outras takes e vídeos entram
    como seções, com o arquivo ligado por hard link em `EditMediaFiles` (sem ocupar espaço, e
    continua se a take for apagada da biblioteca). Uma timeline **linear** (a take sozinha, em ordem)
    funciona como antes, tudo preso aos segundos da gravação. Ao duplicar, reordenar ou juntar outra
    gravação ela fica **arranjada**: as seções tocam na ordem escolhida; as alças aparam só a
    primeira e a última seção; "Remove part" tira o trecho só das seções que cobre; o Clean Up tira
    um momento da take onde ele tocar, nunca de outra gravação. Na primeira vez que arranja, textos,
    mídia e voice-overs são presos à seção onde tocam (`ClipAnchor`: seguem a seção; numa seção
    dividida, vão para o pedaço que os contém) e uma cópia de seção ganha cópias próprias (novas
    identidades). As legendas ficam presas à fala da gravação de onde vieram (`CaptionCue.sourceID`)
    e aparecem em cada cópia; legendar uma montagem ouve cada gravação que toca. Preview e export
    montam a mesma composição: cada seção vem do seu arquivo, com rotação e recorte próprios,
    escalada para o quadro da take; um dissolve entre gravações lê cada lado da sua; uma gravação que
    sumiu toca preta e muda no seu tempo.
  - **Arquivos** (`EditMediaFiles`, Application Support/EditMedia): cópias das fotos e vídeos
    escolhidos e as gravações de voz, nomeadas pelo arquivo. Done ou Cancel sem rascunho apagam o que
    a edição não usou; apagar a take apaga os dela.
  - **Undo** (`EditSnapshot`): além da timeline e das decisões do Clean Up, guarda textos, mídia,
    voice-overs, capa, estilo, estilo das legendas e filtro. Um arraste, um slider ou a sheet de
    texto é um passo só (`beginChange` / `endChange`). Filters é um passo de desfazer; os presets
    tipográficos não mexem no filtro nem na capa. A música também é um passo de desfazer; Voice
    e Adjust continuam mudando direto.
  - **Remove Pauses** é o atalho do Clean Up para pausas (mesma análise, mesmas sugestões): Preview
    aplica sem guardar, Apply guarda como um passo; filler words e regravações seguem no Clean Up.
  - **Voice-over:** a prévia toca muda enquanto grava para o som da take não vazar no microfone
    (com fone também). A sessão de áudio usa `.playAndRecord` com Bluetooth HFP, como as takes.
  - **Capa:** não há API pública para definir a capa no TikTok, Reels ou Shorts; a capa é desenhada
    no aparelho (frame recortado com o look da edição, ou foto, + título no estilo) e salva no Fotos
    junto com cada exportação (e por "Save cover" no Share to), pronta para escolher ao postar. Não
    entra no vídeo.
  - **Transições:** Slide entra no lugar de uma lista longa; None continua o padrão.
  - **Som do projeto** (`Managers/Editing/Sound/`): a música é do criador (Files, copiada para
    `EditMediaFiles`), não há biblioteca de músicas nem catálogo licenciado (o app não tem backend e
    não pode garantir direitos); a nota de direitos fica na ferramenta, e músicas protegidas do
    Apple Music não abrem (sem trilha legível). Cada `MusicClip` tem trilha de som própria, nos
    segundos da edição: na prévia, que toca a timeline crescida até o original inteiro, ela começa
    em `Options.window.start` (o player passa a janela, e com música mudar as pontas monta a prévia
    de novo, com o quadro segurado na tela). O volume ao longo do tempo é um envelope (`MusicEnvelope`): fades
    lineares e, com "Lower under voice", −12 dB (×0,25) enquanto alguém fala, descendo 0,25 s antes
    da voz e voltando 0,2 s depois dela, sem bombear entre falas próximas (junta intervalos curtos).
    A fala vem do nível do som de cada gravação que a edição toca (`VoiceActivity`, −40 dBFS,
    palavras a menos de 0,5 s são uma fala só) mais os voice-overs; é um ducking por nível, não por
    reconhecimento de fala (funciona em qualquer idioma e no simulador). O som de um vídeo por cima
    (`MediaOverlay.audioVolume`) entra numa trilha própria no mesmo trecho; mudo por padrão, como
    antes. Voice: **versão 2** (`VoiceProcessing`, `AudioEnhancer`): EQ de 5 bandas (rumble,
    lama em 250 Hz, presença em 3,5 kHz, ar em 10 kHz, chiado em 8 kHz), compressor para Enhance
    e expansor (não gate) para Reduce noise, cada um em dois níveis conservadores, e um limitador
    de pico no fim, com o arquivo mantido abaixo de −1 dBFS (`AudioCeiling`). A **versão 1** (os
    dois switches antigos) continua igual para edições salvas antes, até um ajuste mudar. Não há
    API da Apple de redução de ruído para arquivos; "Reduce noise" reduz o que está entre as
    palavras e não remove ruído por cima da voz. **Picos:** um export que mistura mais que o som da
    take (música, voice-over, som de vídeo) é mixado uma vez como o export ouviria
    (`Mixdown`: `AVAssetReaderAudioMixOutput` com o mesmo audio mix), passa pelo limitador e é
    trazido para −1 dBFS se ainda passar; o export usa essa trilha única. A prévia mixa ao vivo,
    sem esse passo. "Compare with original" mede a fala dos dois (sem pausas) e toca o original com
    o volume que iguala os dois.
  - **Fundo** (`Managers/Editing/Background/`): por gravação (`TakeEdit.backgrounds`,
    `RecordingBackground`: a take ou uma `ClipSource`), aplicado no quadro recortado de cada
    gravação, antes do Adjust/Filters e de tudo o que vai por cima (mídia, textos, legendas), então
    montagem, dissolve, prévia, export e capa mostram o mesmo. A pessoa vem do Vision
    (`VNGeneratePersonSegmentationRequest`, qualidade `.balanced` na prévia e no export,
    `PersonMasker`) com cache limitado de 90 máscaras por build (voltar o playhead não pede de
    novo); sem máscara (Vision não achou ou o aparelho não suporta) o quadro fica original. O
    chroma key é Core Image puro (`ChromaKeyCube`: cubo 32³ em sRGB que compara a crominância na
    mesma luminosidade, então a tela na sombra também sai e o preto fica; borda suave; spill puxa o
    canal da cor-chave para o maior dos outros). Blur desfoca o próprio quadro (a pessoa por cima
    fica nítida; pode sobrar um halo fino na borda). Não há recorte por IA generativa, rastreamento
    ou refinamento de cabelo além do que o Vision entrega. **Gravação:** com um fundo ligado, a
    sessão ganha uma `AVCaptureVideoDataOutput` com buffers do tamanho do preview
    (`deliversPreviewSizedOutputBuffers`, junto com o movie output desde o iOS 16); o
    `BackgroundPreviewFeed` desenha ~15 quadros por segundo com o Vision em `.fast` por cima do
    preview. O arquivo gravado nunca muda: a take nasce com a receita (`addTake(background:)`, sem
    a marca Edited), e a revisão, o Quick edit e o export aplicam o fundo em `.balanced`, por isso
    a borda pode ficar um pouco melhor que no preview ao vivo. Voice Following não muda.
  - **Deixado de fora de propósito:** biblioteca de músicas, stickers, efeitos, motion graphics,
    tracking, multicam, nuvem, IA generativa de vídeo.

- **Creator Setup + recomendações:** não estão no protótipo; vêm do pedido "Creator Setup + Smart
  Recording Preferences". Antes, abrir um roteiro aplicava o preset da plataforma direto nos ajustes
  salvos (e qualquer toque no prompter virava padrão). Agora: Creator Setup (padrões pessoais, Settings
  › Creator Setup), recomendação por conteúdo (card no Selfie, só por escolha) e mudanças da sessão
  (lente, formato, qualidade, mic, texto, velocidade, linha, espelho, safe zones mudados no prompter
  valem só para aquela gravação). A velocidade das estimativas de duração (Scripts, roteiro, takes)
  continua sendo a padrão. Sem aba nova: o fluxo continua Create → Script → Record → Edit → Export.
- **Remote Control:** Network framework (`NearbyLink`: Bonjour + TCP com mensagens WebSocket, peer
  to peer por Wi-Fi quando os dois não estão na mesma rede; sem conta), o mesmo app nos dois
  aparelhos. O Multipeer Connectivity foi depreciado no iOS 27 e saiu. O teleprompter anuncia um
  serviço com o nome derivado do código de pareamento (um hash, nunca o código, `RemoteCipher`); o
  remote procura esse nome, cada mensagem vai selada com AES-GCM e uma chave derivada do código, e
  o remote só entra respondendo ao desafio do teleprompter; um remote por vez, que volta sozinho se
  sair do alcance. Bluetooth não é usado: os textos pedem só o Wi-Fi ligado. O código tem 6 letras,
  então isso afasta quem está por perto, não quem grava o tráfego e testa códigos. O QR leva
  `cuestudio://remote?code=…` (URL scheme e `NSBonjourServices` `_cue-remote._tcp` no
  `SupportFiles/Info.plist`, junto com `NSLocalNetworkUsageDescription`). O remote controla play,
  pause, velocidade, ‹‹ ›› (3 linhas) e voltar ao topo; gravar continua no aparelho da câmera. Teclado,
  pedal e controles Bluetooth/apresentação ficam para depois: cada um só precisa produzir
  `RemoteCommand`. No Selfie o acesso rápido fica no menu "•••" da fileira de captura (e em "This take"); no Studio,
  um botão ao lado do espelhar.

O protótipo simulava várias coisas; o app implementa de verdade ou deixa de fora o que não existe:

- **IA:** só Apple Intelligence (Foundation Models), sem custo e sem backend. No aparelho:
  reescritas, tom, hooks, CTA, "Fit to time", "In my voice" e ideias de tema. Private Cloud Compute:
  o Prompt livre (temas factuais incluídos); se o PCC não estiver disponível (ou falhar), o modelo do
  aparelho escreve e o aviso de fatos continua. Cada modelo cobre o outro (`AIModelRoute`,
  `AIFailure`): sem rede, cota esgotada ou serviço fora, o aparelho escreve; um roteiro longo demais
  para o contexto do aparelho ou num idioma que ele não escreve vai para o PCC; o que ainda falha
  vira "Too long for Apple Intelligence on this iPhone…" / "Apple Intelligence can't write in this
  script's language yet.". O PCC só conta como disponível enquanto a cota do usuário tem espaço
  (`quotaUsage`). O PCC exige o entitlement gerenciado `com.apple.developer.private-cloud-compute`
  (a Apple concede ao time sob pedido; em 30/09/2026 o portal ainda recusava para o time
  X5392U638Q: "Entitlement … not found and could not be included in profile"); sem ele o
  FoundationModels derruba o app na primeira chamada, então fica desligado
  (`ScriptAIService.hasPrivateCloudComputeEntitlement`) e tudo roda no aparelho até o entitlement
  entrar em `Cue Studio.entitlements`. Enquanto isso, o aviso de fatos e Privacy & AI data não citam
  o PCC ("AI can get facts wrong. Check dates, names and numbers before you record."). Os roteiros
  saem estruturados (`@Generable`
  `ScriptDraft`: título + blocos), com o My Cue Voice nas instructions quando "Write in my voice"
  está ligado. Prompts factuais (história, ciência, "como surgiu…") ganham `factCheck`.
- **Sem Apple Intelligence:** Prompt e as reescritas mostram "Requires Apple Intelligence" e ficam
  desligados; Formats continua gerando o rascunho estruturado a partir do briefing (é um modelo de
  texto, não IA); Themes mostra as ideias locais. O teleprompter não depende de IA.
- **Uso de IA:** ilimitado e completo no grátis (o v1 tinha 5 roteiros/mês): o My Cue Voice
  inteiro, "In my voice", Sponsored ad, os hooks escritos pelo modelo e "Make a version for…". O
  paywall só abre pela exportação ou pelo Profile, nunca durante a gravação.
- **Themes:** as ideias iniciais são a lista local por nicho do protótipo (`ThemeCatalog`);
  "New ideas" pede ideias novas ao modelo do aparelho (sem ele, gira a lista).
- **Import por foto:** não está no protótipo; vem do pedido (Vision OCR). Sai no simulador sem câmera.
- **App Intents:** "Record script {nome}" e "New script" (Siri e Shortcuts) abrem o app no ponto
  certo (`IntentRouter`).
- **Importar:** Files (.txt, .md, .rtf, .html, .pdf, .fountain) e área de transferência. Google Docs e
  Notion entram exportando para Files ou copiando o texto (não há integração direta).
- **Voice follow:** reconhecimento de fala on-device (`SpeechAnalyzer`, nada sai do aparelho, sem
  custo por uso) no idioma de Voice Following (Settings › Language & Region), ou no do roteiro
  ("Same as Script"; um roteiro em Auto-detect tem o idioma lido do texto). `SpeechTranscriber` (o
  motor original) é tentado primeiro em todo idioma; `DictationTranscriber`, do mesmo framework,
  cobre os idiomas e aparelhos que ele não cobre. As palavras ouvidas são alinhadas às do script e o
  texto acompanha o ritmo de leitura; espera nas pausas e quando a fala sai do script. Arrastar ou
  pular linhas muda o ponto de onde a leitura continua. Roteiro, transcrição, legendas e Clean Up
  passam pelo mesmo `WordTokenizer`: japonês, chinês e tailandês são divididos em palavras pelo
  dicionário do sistema (`WordSegmenter`, no idioma conhecido), e a comparação ignora caixa,
  acentos, largura, as formas da hamza e as vogais do árabe, o nukta do hindi, e escreve números por
  extenso ("3" = "three", "três", "三"). Sem modelo para o idioma (ou enquanto ele baixa), volta ao
  nível de áudio: rola na velocidade definida enquanto ouve fala, e diz por quê (e o "AUTO" dá lugar
  à velocidade). O Speech não sabe dizer que idioma alguém está falando antes de reconhecer, então
  não há "auto-detect" falado.
- **Voice follow, Selfie e Studio, idioma e reposicionamento:** (1) **cada modo guarda o seu lugar**: ao sair de Selfie ou Studio o prompter anota a palavra que estava na linha de leitura (`readingPlaces`) e, ao voltar, a recoloca na linha quando o layout termina de se medir (`LayoutAnchor`, 0,6 s; os dois layouts diferem, a fonte do Studio é 1,35×); um modo ainda não visitado começa no topo, e arrastar, pular linhas ou voltar ao topo nesse intervalo cancela a recolocação; (2) **a transcrição recomeça em todo reposicionamento** (`SpeechTranscribing.discardHeard()`: troca de modo, voltar ao topo, play no fim do texto, refazer a take, arrastar ou pular linhas): o rastreador alinha as últimas 8 palavras ouvidas com o texto em volta da posição, e as palavras lidas em outro lugar ainda estariam nelas e puxariam o texto de volta para lá; a sessão de reconhecimento continua a mesma; (3) o áudio vai ao analisador por `AVAudioConverter`, em buffers sem tempo próprio: o `AnalyzerInputConverter` carimba cada buffer com o relógio do próprio conversor, que recomeça do zero ao trocar de modo, e o analisador encerrava com "timestamp overlaps or precedes prior audio input"; (4) o idioma do iPhone (`systemLanguages`) **nunca é entregue ao `NLLanguageRecognizer` como dica**, que a trata como prior total (um iPhone só em inglês lia português claro como inglês e o Voice Following escutava em `en_US`): ele só entra como um empurrão pequeno (`LanguageDetector.leanWeight`) que desempata texto ambíguo.
- **Voice follow, tempo de resposta:** o reconhecimento começa a se preparar junto com a câmera
  (não depois dela) e uma mesma sessão de reconhecimento atravessa a troca Selfie ⇄ Studio (só muda o microfone de
  onde ouve; um conversor por formato de áudio). O nível de cada buffer chega na hora em que o
  buffer chega (`AudioBufferTap` → `AudioLevelSample`, sem o polling de 80 ms de antes), e o
  `VoiceFollowGate` decide no main actor: −40 dBFS numa sala silenciosa como sempre; numa sala com
  ruído constante, aprende o ruído (o mais baixo de cada meio segundo nos últimos 3 s) e exige 10 dB
  acima dele (nada conta antes de ouvir a sala por até meio segundo depois de começar a escutar);
  um estalo de um buffer só (menos de 30 ms) não conta; 0,6 s de hangover. O medidor pula junto
  com o início e o fim da voz e, no meio, redesenha no máximo 20 vezes por segundo. Nada roda
  no thread de áudio além de medir o nível, copiar e converter o buffer. O cancelamento de eco da
  Apple (voice processing) foi avaliado e deixado de fora: o prompter não toca som enquanto ouve, e
  o processamento mudaria o som gravado e o microfone externo. `VoiceFollowMetrics` mede no aparelho
  (início, primeira palavra, voz → indicador, voz → texto, transcrição → alinhamento, quanto o
  texto andou à frente, falsos inícios), grava no log do aparelho em Debug e nunca envia nada.
- **Idiomas:** não estão no protótipo; vêm do pedido "Multilingual architecture". A interface tem
  20 idiomas (inglês, espanhol, português do Brasil, francês, alemão, italiano, japonês, coreano,
  chinês simplificado, hindi, indonésio, árabe, turco, tailandês, vietnamita, chinês tradicional, holandês, sueco, dinamarquês, norueguês), escolhidos em
  Language & Region independentemente do iPhone, do idioma de Voice Following e do idioma dos
  roteiros. Árabe espelha a interface; timelines, vídeo e zonas seguras nunca espelham, e o
  prompter segue a direção do roteiro. Detalhes, terminologia e limitações em `LOCALIZATION.md`.
- **Conta:** Sign in with Apple é opcional e fica no Profile (não bloqueia nada). Entitlement
  `com.apple.developer.applesignin` (Default) em `Cue Studio.entitlements`, capability ligada no App
  ID `com.cuestudioteleprompter` (exige o Apple Developer Program). Sem backend, só
  guarda o ID, o nome e o e-mail que a Apple manda na primeira vez (o nome preenche o perfil vazio);
  no launch e a cada volta ao app confere o estado da credencial e sai se ela foi revogada (o
  "Stop Using Apple ID" acontece nos Ajustes, fora do Cue). Nome e @ continuam editáveis
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
- **Aurora e borda de luz** (`AuroraCardBackground`, `AuroraMotion`): o card de ideias de Scripts (`IdeaPromptCard`, com e sem roteiros, em todos os idiomas) e o card "Sounds like you" do Profile (a linha da seção My Cue Voice; os outros cards do Profile não têm). Duas camadas decorativas atrás do conteúdo, recortadas no raio do card (26 pt), sem toque e fora do VoiceOver: (1) **aurora**: quatro luzes difusas (dourado, âmbar, um brilho embaixo e uma sombra que dá profundidade) desenhadas num `Canvas` sobre a superfície, em senóides de períodos de 10 a 14 s, então a posição é contínua, sem saltos, flashes nem pulsação do card; (2) **borda**: um reflexo dourado de 1,5 pt cobre 30% do contorno e dá uma volta em 9 s, em ritmo igual pela borda (o ângulo acompanha o perímetro, não o centro), com as duas pontas sumindo (`AngularGradient`). Um só `TimelineView` (30 quadros/s) redesenha só essas camadas; o conteúdo do card não é reconstruído. Pausa fora da tela, rolado para fora, com o app inativo ou quando o card é coberto (`animatesBackground`; no card de ideias também pelo próprio setup de "Write in my voice", e no Profile por Edit profile, paywall, assinaturas e o setup), e volta do mesmo quadro (`MotionClock`). Com Reduzir Movimento fica parado: aurora em repouso e a borda como uma linha dourada discreta.
- **Estrelas do Prompt:** os três `sparkle` ao lado do título mantêm posições e forma fixas. Uma
  estrela por vez faz um twinkle curto e irregular com escala, brilho, núcleo branco e glow dourado.
  A sequência repete em 21 s, com os intervalos entre inícios 30% menores e a duração de cada brilho
  preservada (0,8–1,25 s), sem sobreposição;
  a animação usa o mesmo relógio pausável do fundo, não afeta os demais elementos do card e fica
  estática com Reduce Motion.
- **Ditado da ideia:** não está no protótipo; vem do pedido "ditar a ideia por voz dentro do card de IA". Nada de IA nova: ditar é só reconhecimento de fala no aparelho (`SpeechRecognitionManager`, o mesmo do Voice Following, com `SpeechUse.dictation`: sem o limite de 400 letras do Voice Following, e sem espaço entre frases de escrita sem espaços), e gerar o roteiro continua sendo o fluxo de sempre, um passo à parte que só o criador dá. O ditado acontece no próprio card (`IdeaPromptCard`), num campo de altura fixa que rola por dentro (um campo que crescia com a fala deslocava a tela), com o rascunho em `IdeaDraftService`. O reconhecimento é pedido a cada toque (`SpeechAnalyzer.finalizeAndFinishThroughEndOfInput` no parar, para não perder as últimas palavras) e não guarda áudio. "Nada sai do aparelho" vale para o reconhecimento (`SpeechTranscriber`/`DictationTranscriber`, modelo local); o **download** do modelo do idioma, na primeira vez, usa a internet, e um idioma que o iPhone não reconhece não funciona (o app diz e não troca de idioma). O simulador não reconhece fala: os testes usam um reconhecedor roteirizado (`ScriptedDictation`) e o de verdade só se confere num aparelho. As frases de uso do microfone e do reconhecimento de fala (`InfoPlist.xcstrings`) agora citam o ditado.
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
- **Editor de vídeo v12:** `CueEditorEmbed` refina o v10 em cinco pontos, todos no app: o fundo e a
  calha das faixas, as dicas nas faixas vazias (e o toque na faixa que abre as ferramentas dela, com um
  menu Captions novo), o Delete fixo, o Adjust em dials com régua, e a música que entra no playhead em
  espaço livre (Replace troca o arquivo). Diferenças do protótipo: a dica da faixa vazia usa 60%, não
  45%, de `#EBEBF5` (contraste 5,9:1, não 3,9:1); a faixa do protótipo mostra o "Aa" do texto em fonte
  própria, o app usa o SF Symbol `textformat`; o protótipo tem só uma faixa de música e o app várias
  (Add music sempre cria um clipe novo no espaço livre).
- **Editor de roteiro v12:** `CueScriptEditorEmbed` (leitura + escrita focada + sheets). Segue o
  protótipo, com estas diferenças: (1) o status do cabeçalho mostra "123 words · ~49s" com o ponto na
  cor da faixa de duração, e não "Saved · ~49s": o app só grava o roteiro no Done (um rascunho, para que
  Discard changes volte ao que era e a versão nova veja a mudança inteira), então "Saved" seria
  mentira; (2) o teclado é o do sistema (a barra de cima é a do protótipo, o teclado desenhado não),
  e o painel de uma ferramenta tem a altura do último teclado medido; (3) "Check facts" não existe:
  o app não verifica fatos, só pede que o criador confirme ("Checked"); (4) os cues são traduzidos nos
  20 idiomas e entram no texto na língua da interface (`[pausa]`, `[間]`), como o `LOCALIZATION.md`
  pede; (5) o rodapé "4 of 5 free AI edits left" não existe (a IA é grátis e ilimitada); (6) em vez de
  Cancel, **Discard changes** (Options) devolve o roteiro como era; (7) o título do formato sem tipo é
  "Talking video"; (8) o texto de leitura e a escrita escalam com o Dynamic Type; (9) uma ferramenta da
  Improve script, na leitura, salva o texto na hora (como o protótipo) e abre uma versão nova quando já
  há takes, o que o protótipo não mostra.
- **Looks por clipe (Adjust, Filters, Background):** o vídeo todo é a **base** e cada clipe pode ter
  **overrides** opcionais (`EditSegment.look`: `ClipLook`, valores opcionais por dial, filtro, intensidade
  e fundo); o valor efetivo é `override ?? vídeo` (`LookSettings.overridden(by:)`,
  `TakeEdit.lookSettings(for:)`, `TakeEdit.background(for: segment)`), então um clipe sem override segue o
  vídeo, inclusive quando o vídeo muda depois, e nada é copiado para os clipes. Abrir Adjust, Filters ou
  Background **pela toolbar principal** muda o vídeo; **por um clipe selecionado** muda só esse clipe
  (`lookScopeIsClip`, fixo enquanto o painel está aberto; o painel acompanha o clipe selecionado e fecha
  quando ele é solto, então o escopo nunca muda sem o criador ver). Os controles, o `FrameLook` e o
  compositor são os mesmos; o escopo só decide onde a mudança é escrita. Split, Duplicate, Clean Up e
  Remove part copiam o override para os pedaços (`EditSegment.piece`), então cortar um clipe não muda como
  ele parece; `ClipLook` entra no Desfazer pelos clipes da timeline. Render: o compositor recebe o look
  de cada trecho (`CompositionInstruction.look`/`blendLook`, também no outro lado de um dissolve), os
  trechos se cortam onde o look do clipe seguinte difere (`EditedComposition.splitBySource`, como no zoom),
  e o fundo de um clipe vira um `BackgroundRender` próprio por clipe (a mesma máscara do Vision e o
  mesmo chroma key, sem segundo pipeline); a prévia monta a edição de novo quando um look de clipe
  muda (`ItemKey.clipLooks`), mantendo o item (só o desenho muda), e o export usa a mesma composição. A capa usa o look e o fundo do clipe do
  quadro escolhido. Projetos antigos abrem sem `look`. **Escopo das ferramentas:** só vídeo todo — Crop
  (formato de saída), Voice, Captions, Text, Cover, Pauses, Music e Media; só clipe — Split, Speed, Zoom,
  Volume, Duplicate, Delete e a transição de cada corte; os dois — Adjust, Filters e Background. Voice
  aparece na toolbar do clipe (como antes) mas muda a take inteira e diz "Whole take". Um fundo de clipe
  com Color key e foto funciona igual ao da gravação; as fotos de fundo dos clipes entram nos arquivos que
  a edição guarda.
- **Qualidade da imagem (Adjust, Auto e Filters):** tudo passa por `FrameLook`, a mesma função da prévia, do
  export, da capa e das miniaturas, em três etapas independentes e nesta ordem: **Auto**, os **dials** e o
  **filtro**. Zero é neutro em cada uma (um quadro sem nada volta intocado).
  - **Pipeline e cor:** a câmera grava só formatos de 8 bits SDR (os de 10 bits HDR perdem para os padrão), o
    compositor pede `32BGRA` e o `CIContext` trabalha no espaço de trabalho padrão do Core Image (sRGB linear
    estendido); o resultado volta ao espaço do quadro. Não há tone mapping HDR próprio: um vídeo HDR importado
    para a montagem chega como o AVFoundation o entrega em BGRA, e esta entrega não mudou. Curvas "perceptuais"
    (contraste, brilho nos realces, os filtros) são desenhadas em valores sRGB codificados
    (`CIToneCurve`, que já codifica e decodifica sozinho, e `CIColorCubeWithColorSpace` em sRGB), nunca em luz
    linear, onde uma curva em torno do cinza médio seria forte demais nas sombras; codificar de novo antes da
    curva tirava o cinza médio do lugar (testado em `LookVersionTests`).
  - **Dials calibrados e versionados** (`LookCalibration`, `LookSettings.version`): a versão 2 é mais fina perto
    de zero (resposta suavizada, `eased`) e para antes do ponto em que a imagem estraga: exposição ±1,2
    stops; contraste por curva em S em torno do cinza médio, com a inclinação do meio mudando no máximo 30%;
    saturação de 0 a ×1,7; **Vibrance** (`CIVibrance`, poupa pele e cores já fortes); Warmth em mireds (até
    35 mired de luz do dia, uns +1900 K e −1200 K; positivo esquenta: a imagem é tratada como iluminada por essa
    luz e equilibrada de volta para a luz do dia, porque `CITemperatureAndTint` com alvo acima de 6500 K esfria); **Tint** (verde ↔ magenta, ganho de ±12% no verde, mantendo o
    brilho); sombras −0,5…+0,8 (nunca preto); nitidez até 0,6 com raio fino que acompanha a largura do quadro,
    para não haver halos. Edits salvos antes (`lookVersion` ausente) com algum dial fora de zero, no vídeo ou
    num clipe, **ficam na versão 1, com os números de sempre** (`FrameLook+Legacy`); um edit que nunca usou os
    dials, ou um novo, começa na 2. Vibrance, Tint e Auto não existiam: valem nas duas versões.
  - **Auto real** (`AutoAdjustAnalyzer`, `AutoCorrection`): não é Apple Intelligence nem o Auto do app Fotos. Pega
    7 quadros espalhados pelo trecho do clipe (longe das pontas, pelo comprimento de cada trecho), pede ao Core
    Image `autoAdjustmentFilters` (só `enhance`: sem olhos vermelhos e sem corte), ignora quadros quase pretos ou
    estourados, e guarda **a mediana** de cada número (vibrance, realces/sombras, a curva de tom em 5 pontos e,
    se a maioria dos quadros tiver rosto, o balanço de rosto), limitada a faixas seguras. Fica no edit como
    números simples (`TakeEdit.autoCorrection`, `ClipLook.auto`), não como filtros em memória, então toca
    igual em cada quadro, na prévia e no export, e reabre igual. A intensidade (0–100%) é um valor à parte, sem
    medir de novo; Compare mostra a imagem como gravada (`TakeEdit.withoutPictureLook`, só na prévia); Reset
    tira a correção e deixa os dials; tudo é um passo do Desfazer. Roda fora da main thread
    (`@concurrent`), uma por vez, com cache por gravação e trecho (24), e só quando o criador toca em Auto:
    nunca durante o play nem ao arrastar uma régua. Uma medição que volta depois de o painel fechar, o clipe
    mudar ou o editor sair é descartada, nunca aplicada a outra seleção; se falha, a imagem fica como estava e
    um toast discreto avisa. Ao medir o vídeo todo, mede a gravação da própria take; use Auto num clipe para
    uma gravação da montagem.
  - **Coleção de filtros** (`FilterGrade`, `FilterLUT`): Natural (limpo, um pouco mais de contraste e cor),
    Studio (rosto sob boa luz: nítido, levemente frio, cores com punch), Soft (arejado, preto levantado, cores
    suaves), Cinema (sombras em azul-petróleo, realces quentes, contraste firme), Warm Editorial (dourado e
    fosco), Retro (filme desbotado: preto levantado, branco rebaixado, sombras verde-azuladas), Mono Soft e
    Mono Contrast. Cada um é uma **cor definida em código** (curva de tom que soma a mesma variação aos três
    canais, mantendo matiz e detalhe; saturação que poupa a pele; viragem em sombras e realces sem efeito na
    pele; mistura de canais no P&B) amostrada num cubo 32³ (`CIColorCubeWithColorSpace`, em cache de 12): não
    há LUT de terceiros, então não há licença a registrar. A pele (matiz entre laranja e amarelo, croma
    moderado) é medida e testada: os filtros coloridos não mudam o matiz de nenhum tom de pele de teste em mais
    de 3° (`FilterGradeTests`). Intensidades iniciais: Natural 100%, Studio 90, Soft 85, Cinema 75, Warm
    Editorial 85, Retro 75, Mono Soft 90, Mono Contrast 85. Os filtros antigos (Vivid, Warm, Cool, Mono, Film,
    Fade) têm os mesmos identificadores e a mesma renderização, e só aparecem no painel enquanto escolhidos.
    As miniaturas vêm de um quadro do vídeo em escopo, na intensidade inicial, e ficam em cache (6 conjuntos).
- **Presets de legenda completos** (`CaptionStyleSpec`, `CaptionSettings.styleVersion`): cada preset é uma receita
  (fonte, peso, tamanho, contorno ou sombra, cor, placa atrás do texto, espaçamento entre letras e linhas,
  largura e quebra de linha, jeito de mostrar as palavras e de entrar), e o renderizador só lê a receita.
  **Cue** destaca a palavra numa caixa; **Educational** (Manrope 700, placa escura suave, linhas largas, a palavra
  dita em amarelo discreto, sem caixa, fade de 0,12 s) é a leitura clara; **Interview** (Inter 600, espaço entre
  letras, placa leve, no máximo 2 linhas, sem efeito por palavra, só fade de 0,1 s) é sóbria e estável;
  **Impact** (Anton em caixa-alta, contorno preto de 7%, sombra, no máximo 2 linhas curtas, entrada rápida de
  0,1 s); **Pop** (Poppins ExtraBold sobre placa violeta por linha, 4,5:1 com o branco, entrada com salto de
  0,18 s); **Editorial** (DM Serif Display, espaço aberto entre letras, entrelinha larga, placa suave, fade de
  0,2 s). Um preset **traz o seu Reveal** (Educational, Cue, Impact, Pop e Editorial acendem a palavra dita;
  Interview e Clean só mostram a linha) e o Reveal ainda pode ser mudado depois. Escolher um preset mantém a
  posição e zera tamanho e cor. A entrada (fade e salto) vale só no **primeiro** estado da linha e a saída no
  último, de modo que a linha não pisca a cada palavra; é função do tempo, então prévia e export são iguais. O
  espaço entre letras é desligado para escrita que se liga (árabe) ou empilha (hindi, tailandês). Palavras
  seguem os tempos medidos quando existem e, sem eles, a aproximação de `CaptionCue.lineWords`; uma
  **tradução** mostra a linha inteira, sem efeito por palavra. **Compatibilidade:** os edits salvos antes
  (`styleVersion` ausente) continuam com os números exatos da primeira leitura de Cue, Impact, Clean, Pop e
  Editorial (testados); só um preset escolhido agora usa a versão 2. Nenhuma fonte nova entrou (ver
  `DesignSystem/Fonts/CAPTION-FONTS.md`).
- **Correções do editor (fotos, legendas, painéis):**
  - **Um seletor de fotos só** (`EditorPhotoPicker`, `PhotoRequest`): Background › Image, Cover › Photo e
    Replace (mídia) só dizem para que querem a foto; o editor mostra o seletor nativo do iOS uma vez, da
    raiz da tela, em vez de cada painel ou botão apresentar o seu. Replace oferece vídeos quando a mídia
    é um vídeo. O "Add photo or video" continua com o seletor em linha da sheet.
  - **Fundo na timeline:** o fundo (Blur, Color, Image) não é um item da faixa de mídia, vale para a
    gravação inteira; por isso o selo do clipe diz qual é. Uma foto na faixa de mídia é uma sobreposição
    (inteira ou em janela), e o nome dela diz isso.
  - **Legendas:** o estilo é da coleção (`captionCollection`) e a linha mantém sua identidade ao ser
    corrigida, dividida, juntada ou movida; `CaptionRevision.retimed` reparte o trecho da voz entre as
    palavras novas (sem marcar estimativa) e só uma palavra sem trecho nenhum desliga o destaque palavra
    a palavra (`needsTimingReview`). As reticências que o reconhecedor põe quando a fala segue na
    próxima legenda ("interessante...") não entram nas linhas (`CaptionText.withoutContinuation`,
    aplicado na hora de montar as linhas e em edições antigas ainda não corrigidas); o que o criador
    digita, e a pontuação do roteiro, nunca é mexido. A transcrição guardada continua como foi ouvida.
- **Editor v10:** a interface segue o protótipo `Cue Editor v10`; o motor de antes ficou. Diferenças:
  - **Legendas:** o v10 usa os 8 presets de texto também nas legendas; o app mantém a coleção de
    legendas (Cue / Impacto / Clean / Pop / Editorial) em Caption style › Presets e usa os 8 `TypePreset`
    só nos textos; "+ Captions" no Text style passa o visual do texto para as legendas (`captionLook`).
    Caption style › Font muda a cor do destaque na coleção (a família é da coleção); família, peso e cor
    só com o visual de um texto. Reveal "Words" mostra as palavras conforme são ditas.
  - **Mantidos em Advanced** (não estão no protótipo): força do blur, cor do Color key à mão, som e
    keyframes da mídia; "Edit translations" abre a sheet de tradução (Both, escrever à mão, linhas
    desatualizadas). **Saíram da interface:** Remove part (faixa vermelha), zoom de precisão, Clips
    (reordenar) e Copy section; edições antigas com eles abrem e exportam iguais.
  - **Transições:** o protótipo não tem; cada corte ganha uma marca que abre None / Dissolve / Fade /
    Slide (sem ela não haveria como tirar a transição de uma edição antiga).
  - **Voice-over** continua preso à gravação (sobrevive a cortes antes dele), não ao tempo editado.
  - **Voice:** Enhance voice e Reduce noise continuam com EQ e dinâmica (`AudioEnhancer`); não há API
    da Apple de redução de ruído para arquivo além do `AUSoundIsolation`, que não foi confirmado em
    render offline (fica para um teste no aparelho).
  - **Background:** a pessoa é segmentada em `.balanced` na prévia **e** no export (o prompt sugere
    `.accurate` no export), para o arquivo ser igual à prévia.
  - **Export:** 4K só de uma take 4K e 60 fps só de uma take a 50 fps ou mais; o que não dá aparece
    apagado com o motivo. A sheet Share to da revisão continua como era.
  - **Auto captions:** o idioma falado tem os 20 idiomas do app (o protótipo mostra 4).
  - **Pausas:** o respiro de cada lado passou de 0,15 s para os 0,12 s do v10; as pausas vêm da
    análise de volume (o protótipo usa os intervalos entre legendas só para a demo).
  - **Fontes:** DM Sans e DM Serif Display entram no bundle (OFL, licenças em `DesignSystem/Fonts/`),
    registradas no launch como as outras; só têm alfabeto latino, então outros idiomas caem na fonte
    do sistema, como já fazia a coleção de legendas.
- **Quick edit:** a edição é uma receita aplicada na hora de tocar e exportar (composição do
  AVFoundation + compositor próprio com Core Image), nunca um arquivo novo. A timeline é uma lista de
  pedaços do original (`EditTimeline`, a única fonte de verdade da prévia, da timeline, do desfazer e
  do export): o trim move o começo do primeiro e o fim do último, Remove
  part corta um trecho do tempo editado (`removeEdited`, dois cortes e uma remoção), Cut divide uma
  seção no playhead, Delete tira a selecionada, e as sugestões do Clean Up saem do mesmo jeito.
  Clean Up só sugere (`CleanUpSuggestion`, com status pending / kept / removed): nada sai sem o
  criador revisar, uma pausa pode ser intencional e "like" pode ter sentido. As pausas vêm do volume
  (`SilenceDetector`, a partir de 0,3 s; "Pauses longer than" escolhe quais aparecem); filler words
  (`FillerWordDetector`) e possíveis regravações (`RetakeDetector`: frases como "deixa eu falar de
  novo" e palavras repetidas) vêm da transcrição no idioma do roteiro (`CleanUpAnalyzer`). Pausas
  longas e sons como "um" são de alta confiança e entram no "Remove all"; pausas curtas, palavras que
  só às vezes são vício e regravações esperam o criador ouvir. O v9 pede comparar a transcrição com
  o roteiro e usar o Foundation Models nos casos ambíguos; por enquanto as regravações vêm das frases
  e repetições, e os ambíguos ficam de fora do "Remove all". Cada passo do desfazer guarda a timeline
  e as decisões juntas (`EditSnapshot`). A prévia toca a edição com as pontas crescidas até o original inteiro e
  segura a reprodução entre as alças, então arrastar uma alça mostra o frame real sem reconstruir
  nada. **A prévia nunca pisca:** qualquer outra mudança monta a edição de novo, um build por vez e
  sem espera fixa (uma mudança que chega durante um build espera por ele e a mais nova vence, então
  um slider redesenha enquanto o dedo anda, sem empilhar builds). Quando a montagem nova tem as
  mesmas faixas e os mesmos trechos (`CompositionShape`: look, Adjust, filtros, fundo, textos,
  legendas, volume), o item do player fica e só recebe a composição de vídeo e o mix novos, e o
  quadro parado é desenhado de novo; trocar o item apagava a imagem por 40 ms (1080p) a 110 ms (4K)
  no iPhone 18 Pro Max. Trechos ou faixas novos (corte, velocidade, música, Voice) trocam o item, e
  a view da prévia (`FrameHoldingPlayerView`) segura o último quadro composto
  (`CueVideoCompositor.lastFrame`) por cima até o item novo ter imagem (no máximo 1 s). O cache de
  desenhos do compositor é nomeado pelo conteúdo (`LazyText.key`), então um compositor que continua
  depois da mudança nunca devolve um texto velho. `QuickEditPreviewLatencyTests` (opt-in, no
  aparelho) mede o tempo até a mudança aparecer e se a imagem some. As alças atravessam cortes (`EditTimeline.trimStart/trimEnd`): cada passo do arraste parte
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
  (mantendo resolução e fps), porque o mergulho no som, o recorte do frame e o Enhance voice (Soft
  por padrão) precisam de uma nova codificação. Um rascunho guarda a edição, o playhead e o histórico enquanto a tela está
  aberta (e ao sair do app); ao voltar, "Draft restored". O relógio usa `DurationText.timecode`
  (00:04.32 abaixo de 10 min, 00:12:04 a partir de 10 min). "Enhance voice" e
  "Reduce noise" são aproximações com EQ e dinâmica no `AVAudioEngine` (não há API da
  Apple de redução de ruído para arquivo; ver "Som do projeto"). Os filtros usam Core Image e ficam próximos, não
  idênticos, aos do protótipo. As legendas vêm da fala (`SpeechAnalyzer`, no aparelho), com
  ou sem roteiro: o áudio decide **o que foi dito e quando**; o roteiro decide só **como cada palavra
  ouvida se escreve** (grafia, acento, maiúscula, pontuação), e com quanta confiança depende da take
  (`ScriptSpelling`): se a take foi **lida do roteiro** (≥ 60% das palavras ouvidas se alinham, em
  ordem), os escorregões do reconhecedor são corrigidos (uma palavra parecida, de 4+ letras, entre
  palavras que se alinham — "mostra" → "mostrar" —, uma palavra curta entre alinhadas, letras iguais
  divididas em outro número de palavras, com o tempo dividido e marcado como estimativa); se foi
  **improvisada**, só as palavras que se alinham com segurança (a mesma palavra numa sequência de 2+ ou com
  5+ letras) pegam a grafia do roteiro e uma palavra só é trocada quando é quase a mesma. Em qualquer
  caso números, negações, palavras diferentes, improvisos e repetições ficam como foram ditos, e linhas
  do roteiro que não foram ditas nunca aparecem. **Idiomas misturados** (um criador abre em inglês e segue em português, ou fala português com
  frases em inglês): um reconhecedor escuta numa língua só, então o que está em outra sai como palavras
  sem sentido. O idioma principal de um roteiro em Auto-detect é o que a maioria das **palavras** diz,
  frase a frase, com o idioma do iPhone só como leve inclinação (`LanguageDetector`), então quatro
  palavras em inglês no começo não viram o roteiro inglês. E **a take é escutada em cada idioma que o
  roteiro usa** (`ScriptLanguageRuns`: o roteiro em trechos por idioma, frase a frase; só conta uma frase
  de 3+ palavras de que o Natural Language tem 75% de certeza, e uma frase duvidosa fica com a vizinha;
  um idioma com 3+ palavras entra, no máximo 2 além do principal; um que o iPhone não escuta fica de
  fora): cada trecho vem do reconhecedor cujas palavras se alinham a ele, no momento em que foram
  ouvidas (`MixedLanguageMerge`: vence o de maior alinhamento, com pelo menos 2 palavras e 40% do
  trecho; o resto da take é do reconhecedor principal, como antes). Não adivinha pelo som: o criador
  leu o roteiro, então quem ouve aquelas palavras é quem as ouviu na língua certa. Um idioma extra
  custa outra escuta (e o download do modelo, com o progresso de sempre). Uma transcrição guardada
  por um jeito mais antigo de escutar (`CaptionTranscript.version`) é escutada de novo ao gerar as
  legendas. Sem roteiro (fala improvisada) vale a língua principal. E numa take lida do roteiro, uma
  frase do roteiro claramente em outro idioma que o reconhecedor ouviu como palavras sem sentido, com
  quase o mesmo número de palavras, ainda é escrita como o roteiro a tem (`LanguageDetector.isForeign`,
  tempos da voz mantidos): é o que cobre uma expressão no meio de uma frase ou um idioma que o iPhone
  não escuta. Japonês, chinês e tailandês usam a mesma regra, com as
  palavras cortadas pelo mesmo dicionário nos dois lados (palavras de 2+ letras). Antes de ouvir, o
  reconhecedor recebe os nomes e as palavras longas do roteiro como dica de vocabulário
  (`ScriptVocabulary`, `AnalysisContext.contextualStrings`, até 100 termos): isso só inclina a escuta,
  nunca escreve por cima do que foi dito.
  Sem áudio, sem fala ou sem modelo para o idioma, o app diz por quê e nunca distribui o roteiro pela
  duração. A transcrição original fica guardada à parte (`CaptionTranscript`); cada linha tem
  identidade, palavras com tempo (marcadas como estimadas quando o reconhecedor deu um trecho a
  várias palavras ou quando uma correção as criou) e "Check timing" quando o tempo precisa de revisão
  (`CaptionRevision`). Cortes mostram só as palavras que ficaram. Legendas entram no desfazer.
  **O estilo escolhido vale para toda linha, medida ou não** (`CaptionCue.lineWords`): uma linha escrita
  ou corrigida à mão, ou cujas palavras perderam o tempo próprio, reparte o tempo da linha entre as
  palavras (pelo tamanho de cada uma) e recebe os mesmos efeitos (Cue, Words, Highlight, Box) de uma
  linha ouvida; espaços a mais digitados não os desligam (`shownText` é o que se desenha). Quando existem
  tempos medidos, eles mandam. "Check timing" na linha significa só "o efeito é aproximado"; o painel
  Caption style diz "N lines follow the voice approximately", sem aviso de erro.
- **Takes sem roteiro:** o protótipo marca gravações freestyle como Reels; aqui elas aparecem como
  "Freestyle" (sem plataforma) e cada uma é um vídeo próprio.
- **Take:** o arquivo é guardado pelo nome (`fileName`), não por URL, porque o caminho do container
  muda entre instalações; `recordedAt` é o "createdAt" do pedido.
- **Filtros de plataforma:** um menu "All ⌄" com All platforms + TikTok, Reels, Shorts, YouTube e LinkedIn;
  Stories ganha chip só quando algum script é para Stories (roteiros de 8–15 s são raros).
- **Share to:** não há API pública para publicar direto no TikTok, Reels, Shorts ou LinkedIn sem SDK
  de terceiros. Tocar numa plataforma exporta, salva o vídeo no Fotos e abre o app dela (URL scheme)
  para postar; sem o app, abre a share sheet do sistema. "Burn in captions" usa as legendas da edição
  ou, se a take nunca foi legendada, gera e guarda texto/tempos para reutilização sem marcar a take
  como editada. Falha não impede exportar sem legendas. 4K mantém a resolução
  gravada (uma take 1080p não é ampliada) e está em todos os planos.
- **Regras remotas:** o protótipo diz "presets update automatically". Sem backend, a atualização é
  um JSON estático opcional (ver 5.1); até a URL existir, as regras mudam com o app.

## 10. Do's & don'ts

- **Áudio da prévia:** Review e Quick edit preparam a sessão `.playback` / `.moviePlayback`
  antes de tocar, inclusive ao retomar: o modo silencioso do iPhone não silencia o vídeo.
  A ativação é assíncrona e um Pause ou sair da tela cancela o início pendente. Durante uma
  narração, o player continua mudo sem trocar a sessão de gravação; a câmera e o gravador
  configuram a categoria de captura novamente ao iniciar. Volume e saída (alto-falante/fones)
  continuam sendo os escolhidos no iPhone; não há reprodução em segundo plano adicionada.

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

## 12. v27 — Cue Universe

Fonte: `design/cue-universe-v27/`. O app segue a arquitetura de sempre; a v27 é uma camada visual e de movimento sobre a lógica da v26,
mais telas novas. Decisões tomadas sem perguntar (as regras de negócio — 5 exportações grátis, preços, cota de IA, pipeline das takes —
**não mudaram**).

### Fundação (fase 0)
- **Só escuro** (`UIUserInterfaceStyle = Dark`, `.preferredColorScheme(.dark)`): `Palette` tem um valor só por token; `AppearanceService`,
  o seletor e os testes do claro saíram. Tokens novos: mundos (`worldWarm/Mint/Pink/Sky`) e galáxias (`Platform.tint`).
- **`CueIcon`**: os 53 ícones "orbit line" (SVG em `Assets.xcassets/Icons`), na tab bar, no editor, na gravação e nos ajustes.
- **`OrbSlider`** (`DesignSystem/Controls`): todo slider do app. Estilos `full`, `row` e `compact`; origem na ponta ou no centro; contínuo ou em
  passos (estrelas), com tique no padrão (detent), controle fino ao deslizar para baixo (½ e ¼ da velocidade, rótulo FINE), duplo toque que volta
  ao padrão, valor sempre escrito, VoiceOver ajustável e teclado. `OrbSliderMath` é testado. O `PanelSlider` do editor, o `SpeedSlider` do
  prompter, as ajustes de Settings › Prompter e o Personalize são `OrbSlider`.
- **Céu** (`StarfieldView`, `.skyBackground()`): `Canvas` + `TimelineView` a 30 fps, três camadas, brilhos em cruz, estrela cadente e nebulosas;
  só nas telas de navegação (nunca sobre câmera, take ou editor); para fora da tela, com Low Power, Reduce Motion ou **Starry sky: Off**.
- **Efeitos de luz** (`DesignSystem/Effects`): `HorizonLine` (a linha de leitura), `IgniteEffect`, `CometTravel`/`CometPlayer`, `WordsFromLight`,
  `AIAura`, `ShineSweep`, `HorizonParticles`; todos com versão estática para Reduce Motion. `CueMotion` guarda curvas, molas e durações;
  `Haptics` tem um interruptor global (Personalize).
- **Tab bar**: a nativa do sistema (ver a seção 13); Record é o anel com o ponto vermelho.
  Está num `VStack` abaixo do conteúdo (nunca flutua sobre ele), e some em telas de tela cheia (`hidesTabBar`).

### Primeiro voo (onboarding, `Screens/Onboarding`)
Mostrado **uma vez**, por cima do app inteiro e só numa biblioteca vazia (`OnboardingService.resolve`): **Welcome** (constelação, *Get started* /
*I already use Cue*, que leva ao Profile) e cinco capítulos com barra de cinco segmentos e **Skip** (vai ao vazio de Scripts com o que já foi
escolhido): **1 · Your universe** (até 3 tópicos ou "+ Your own", que viram mundos em órbita e alimentam o My Cue Voice: `CreatorProfile.niches`
e `customTopics`), **2 · Your first voyage** (a plataforma é uma galáxia; mostra formato, faixa ideal e zonas seguras do `PlatformRules`),
**3 · Your first script** (≈15 s no tema e na plataforma, pelo modelo do aparelho; **sem Apple Intelligence** é o roteiro nosso, rotulado
"TELEPROMPTER PRACTICE"; *Use this script* cria o roteiro de verdade), **4 · Give it a voice** (microfone, depois reconhecimento de fala só
se o microfone foi permitido, depois câmera; **o único botão é Continue**, seguido do alerta do sistema, sem Skip nem "Not now"; recusar nunca
bloqueia) e **5 · Practice** (o prompter real sobre a câmera frontal com `PrompterLaunch.isPractice`, **sem gravar**; *Record it for real* /
*Not now — take me to my studio*). Depois da primeira take de verdade, **First star** (`FirstStarView`): a take vira luz, um cometa a leva ao
universo e acende a primeira estrela ligada a "YOU"; uma vez só. Quem já tem roteiros, takes ou temas nunca vê o voo.

### Teleprompter (gravação, Studio e treino)
- **Horizonte** (`ReadingGuide` = `HorizonLine` + `HorizonParticles`): linha amarela de 2 pt com setinha, brilho que respira (2,4 s) e, com
  Voice Following, pisca com o nível da voz; até 4 faíscas sobem 34 pt enquanto o texto anda.
- **Palavras acesas** (`PrompterHighlighter`, `WordSpans`, `HighlightedParagraph`): com o reconhecimento seguindo as palavras, o texto descansa a
  42%, as ~7 últimas palavras ditas vão a 100% e a mais nova em amarelo. Só no parágrafo lido; Steady e o fallback por volume não acendem nada.
- **Trilho de seções** (`SectionRail`, `PrompterSections`): 2 pt à direita com uma estrela por seção (Hook · Body · CTA, as do formato do roteiro),
  que enche com a leitura; entrar numa seção faz a estrela "pular" (1,7 → 1 em 0,55 s) com háptico de seleção; o rótulo "HOOK · 1 OF 3" muda
  com fade. O chip "✦ FOLLOWING YOUR VOICE" fica no canto de baixo à esquerda.
- **Contagem** (`CountdownOverlay`): "LET'S CUE" e os segundos num anel de 12 estrelas que acendem enquanto um arco amarelo enche; o número entra
  de 1,35× com blur e sai em 0,2 s; háptico leve a cada número e médio no fim; sem clarão ao fim (a bola amarela foi removida); tocar em qualquer lugar cancela.
  A duração vem de Settings › Prompter (Off, 3, 5 ou 10 s).
- **Velocidade**: `SpeedSlider` é o `OrbSlider` compacto ("SPEED 0.7×"), com tique no ritmo natural.

### Pick your best take, exportação e celebrações
- **`PickBestTakeView`** (✦ Suggest best): as takes lado a lado, a sugerida no meio com a faixa violeta que a escaneia, o selo "✦ Best take" que acende
  com uma onda e os motivos que aparecem um a um. **Os motivos vêm só do que se mede** (`BestTakeReason`: cabe na faixa da plataforma, leu o roteiro
  inteiro, mais perto da duração do roteiro); o protótipo diz "No stumbles" e "Eyes on camera", que o app não mede e por isso não afirma.
  *Use take N* marca a melhor (`markBest`); *Record again* volta à gravação.
- **Ready to travel** (`ReadyToTravelView`, depois de salvar): o vídeo, "EXPORTED · 1080P · 9:16", o medidor de exportações grátis e *Share to
  {plataforma}* (abre o app **sem exportar de novo**, `TakeReviewViewModel.send`), *Saved to Photos* e *Other apps*.
- **Send-off** (`SendOffView`, depois de abrir o app da plataforma): o vídeo se dobra em luz, um cometa o leva até a estrela da plataforma, ela
  pisca e "On its way." sobe; "It's now a star in your universe ›" leva ao Profile. Toca uma vez. Com Reduce Motion só chega.
- **Marcos** (`MilestoneService`, `MilestoneView`): cada vídeo conta **uma vez** como compartilhado; em 1, 10, 25 e 50 chega a tela "A new icon is yours."
  com **Use {ícone}** / **Keep my current icon**. Ícones (`AppIconChoice`, geradas dos SVG do pacote, `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`):
  **Aurora** (1, grátis), **First Light** (10), **Deep Space** (25) e **Constellation** (50), os três últimos **do Pro**. Celebrations desligado: nada
  toca, mas a contagem continua.

### Editor (fase 1e)
- Todo slider dos painéis é um `OrbSlider` (Speed, Zoom, Volume, Filters, Crop, Background, Media, Size e Glow); o Adjust mantém a régua.
- **Text style**: 7 estilos com fontes livres embutidas (OFL, em `DesignSystem/Fonts`): **Orbit** (Unbounded), **Logbook** (Instrument Serif itálico),
  **Signal** (Space Mono), **Launch** (Anton), **Nebula** (Syne), **Comet** (Space Grotesk), **Postcard** (Caveat); a aba Presets traz as cartas, **Size**,
  **Glow** (`TextOverlay.glow` / `TextLook.glow`, desenhado pelo mesmo `TextOverlayRenderer` na prévia e no export, no lugar da sombra) e as cores
  (branco, amarelo, lavanda, azul, rosa, menta, tinta). Os 8 presets antigos continuam existindo nas edições que os usaram. Letras que a fonte não cobre
  caem na fonte do sistema (`TextFont`).
- **Captions**: "Impact" virou **Bold** (Anton); **Size** é um orb em S · M · L · XL (`CaptionSize`).
- **Sound**: *Your voice* 0–150% (tique em 100%), *Music* 0–100% e *Clean up voice* em Off · Light · Strong (`AudioStrength`: Soft virou "Light").
- **Opening your edit** (`EditorOpeningOverlay`): enquanto a take é lida; sem porcentagem inventada (o protótipo mostra "Adding captions… 82%").
- **Comment card**: se o roteiro responde a um comentário, o menu Text ganha *Comment*, que põe o comentário num cartão sobre os 4 primeiros segundos.

### Settings, Personalize e Pro
- **Settings › Prompter**: a prévia no alto, depois **Speed** (wpm), **Text size** (S · M · L · XL, `PrompterTextSize` ganhou o XL de 48 pt), **Reading line**
  (Near the camera · Upper third · Middle, `ReadingLinePreset`), **Margins** (`MarginPreset`), **Follow my voice** e **Countdown**; o resto (ajuste fino da
  linha, espelho, zonas seguras, Display) fica em "More options".
- **Settings › Personalize** (`PersonalizeView`): ícone do app (os de marco aparecem trancados com o número), tópicos e cores (abre o My Cue Voice no passo
  dos temas), **Tag new scripts automatically**, **Starry sky** (Off · Calm · Lively), **Celebrations** e **Haptics**.
- **Paywall**: "Take your universe further."; a lista só promete o que o Pro muda (exportar e agora **todos os ícones de marco**); o item sobre IA **não
  aparece onde o aparelho não roda Apple Intelligence** (`AIStatus`).

### Universo (U1) e Fase 3
- **Tópicos automáticos** (`TopicTaggingService`, `Script.topic`): o modelo **no aparelho** escolhe um dos tópicos do criador para cada roteiro novo (com um
  tópico só, não há o que escolher); aparece como um ponto colorido na lista; o criador muda em ••• › Topic e uma escolha dele nunca é refeita.
- **Your universe** (`YourUniverseView`, `UniverseMap`, `UniverseSnapshot`): "YOU" no meio, uma órbita por tópico com um ponto por vídeo compartilhado, as
  plataformas nas bordas ligadas por rotas, a estrela nova pulsando, o próximo marco e **Share my universe** / **My year in Cue** (imagens geradas no aparelho,
  sem nome nem @). O cartão do Profile (`UniverseProfileCard`) abre a tela.
- **Logbook** (`LogbookView`, `LogbookService`): segure e fale uma ideia (reconhecimento no aparelho; **só as palavras ficam, nunca o som**) ou digite;
  cada ideia espera como um cartão com **✦ Shape**, que a escreve numa página nova. Entrada: o ícone do livro em Scripts.
- **Start a video** (o "+"): Let Cue write it (foca o cartão), Write it myself, Import text, **Answer a comment** e "Record without a script".
- **Answer a comment** (`AnswerCommentSheet`): escolha um screenshot (Vision lê **no aparelho**, `CommentParser` separa @nome e comentário) ou cole o texto,
  confirme (autor, texto, plataforma) e o Cue escreve a resposta na voz do criador; o comentário fica no roteiro (`ScriptComment`). **Diferença:** o
  protótipo recebe o screenshot por uma **extensão de compartilhamento** do app social; o app tem o fluxo dentro dele (a extensão pede um alvo novo no projeto).
- **Year in review**: a imagem "My year in Cue" da tela Your universe (vídeos compartilhados no ano, plataforma mais usada, mundo mais ativo).
- **IA ligada ao aparelho**: Shape, Answer a comment, o paywall e o resto checam a disponibilidade antes de chamar e dizem por quê quando não dá.

### Argumentos de lançamento (Debug)
`-uiTestOnboarding` (liga o primeiro voo), `-uiTestPermissions granted|denied` (troca os pedidos reais por um stub), `-uiTestSky off|calm|lively` (os testes
começam com o céu **desligado**: uma animação que nunca para impede o XCUITest de achar o app ocioso), `-uiTestAppsInstalled` (os apps das plataformas
"abrem", para o send-off), `-uiTestCatalogue <seção>` (o catálogo de design).

## 13. v29 — fase 1: fundação

Fonte: `design/cue-v29/` (os arquivos `04`–`06`, o protótipo `Cue App v28.dc.html` e `icons/` ainda não vieram no pacote: o que segue vem de
`01`–`03`). Nenhuma regra de negócio nem modelo de dados mudou; as telas ainda não foram refeitas (só tab bar, ícones, sliders e microcopy).

### Tokens (`Palette`, `Metrics`)
Todos os "New in v29" de `02-Tokens.md` §1.2 existem: `bgWash*` (e a view `BgWash`, ainda sem uso nas telas), `glassBar*`, `tabCapsule*`, `recPill*`,
`slider*`, `selectionBar*`, `aiReplaced*`, `strip*`, `state*` (READY/DRAFT/RECORDED), `adTag*`, `empty*`, `skyStarYou*`; tamanhos em `Metrics`
(`tabBar*`, `themeRail*`, `platformDot*`, `recPill*`, `slider*`, `selectionBar*`, `strip*`, `stateChip*`, `empty*`, `blockGap`). Os tokens da
v27 ficam; **uma exceção**: `sliderTrack` passou de `#6E7496` 45% para 35% (o v29 redefine o mesmo papel). `PaletteContrastTests` ganhou os pares
novos (chips de estado, texto reescrito pela IA, barra de seleção, faixa de estado, rótulos da tab bar, partes do slider, REC e estado vazio).

### Tab bar (nativa)
**`TabView` do sistema** (Liquid Glass; conteúdo sob a barra, seleção por arrasto). A primeira versão da fase 1 era uma view própria num `VStack` abaixo do
conteúdo, e foi trocada: a barra tem que ser a nativa. Saíram `CueTabBar`, os tokens `glassBar*`/`tabCapsule*` e o teste de contraste da barra (o sistema
decide o vidro e o rótulo). Ficam `CueTabImage` (ícones como imagens), `Metrics.tabIconSize` (26) e `tabRecordSize` (30), e o amarelo no `tint`. `TabBarUITests` confere a
barra nativa (`app.tabBars`), a aba selecionada e que Record não vira seleção.

### Ícones (`CueIcon`, `CueIconGeometry`, `SVGPathParser`)
Os 53 ícones deixaram de ser assets vetoriais e passaram a ser **desenhados em código** a partir da geometria dos SVG (gerada por
`design/cue-v29/tools/generate_cue_icons.py`), porque um asset escala o traço junto com o ícone e a regra do v29 é **≈1,6 pt em qualquer tamanho**
(`1,6 × 24 / tamanho` unidades da grade, entre 1,7 e 3,4; terminações e junções redondas; uma cor, a do contexto). Cheios: play, o triângulo do
Takes, e `isFilled:` para a melhor take marcada. **Diferença:** as formas são as da v27: os quadros de ícones do protótipo v28 não vieram; trocar
uma forma é trocar o SVG e rodar o gerador.

### Slider (`CueSlider`, `CueSliderSpec`)
`OrbSlider` virou `CueSlider` (e o `CueSlider` da v26 saiu): trilha de 4 pt (`sliderTrack`), preenchimento amarelo de 4 pt, polegar branco de 24 pt,
valor em SF Mono; sem orb, planeta, anel de órbita nem estrelas. `OrbSliderMath` ficou (detentes, controle fino ½ e ¼ com "FINE", toque duplo
= padrão, VoiceOver ajustável em 5% ou um múltiplo do passo); controles com poucos passos mostram pontinhos e encaixam com mola, os de muitos passos
(velocidade em 5 wpm, 0–100%) não têm pontinhos e **ganham o controle fino**. Estilos `full`, `row`, `compact` e `bare` (só a trilha, na barra
compacta da gravação). As faixas de §6 estão em `CueSliderSpec` (testada contra a tabela) e valem para: Velocidade 80–220 wpm (passo 5, padrão 150;
o valor guardado continua sendo o multiplicador, `PrompterSettings.speed(forWordsPerMinute:)`), Tamanho do texto 24/30/36/44 pt (padrão 36), Linha de
leitura 10–50% da altura (`ReadingLinePercent`, medida na tela onde o slider está; guarda os mesmos pontos abaixo da câmera), Margens 8–40 pt (passo 2,
padrão 20), Contagem, Céu (Off / Soft / Full, padrão Full: os valores salvos `calm`/`lively` continuam), Texto no vídeo 24–120 (agora em pontos de
`TextOverlay.size`, sem o fator de escala do design), Glow, Tamanho das legendas (padrão L), Sua voz 0–200%, Música 0–100% (tique em 20%),
Limpar voz, Velocidade do clipe 0,5–3×, Intensidade do filtro (padrão 70). **Não mudaram** (fora da tabela): os `ValueSlider` nativos do Display, a
régua do Adjust e os sliders dos painéis que não estão em §6 (Zoom, Mídia, Fundo, fades).

### Componentes novos (`DesignSystem/Components`)
`ThemeRail` (3×30 / 3×14), `PlatformDot` (7 / 6 pt), `RecPill` ("● REC", 26 pt visuais, 44 pt de toque), `StateChip` (READY · DRAFT · RECORDED),
`EmptyState` + `EmptyStateMark` (anel de 88 pt, estrela que orbita em 9 s; parada com Reduce Motion, Low Power e app inativo; título, uma linha,
uma ação amarela e um link). Todos aparecem no catálogo de debug (`-uiTestCatalogue sliders|tabbar|parts|icons|colors`).

### Microcopy
Toasts de até ~28 caracteres e textos de ajuda de uma frase de até ~60, resultado primeiro, "·" para juntar fatos, sem travessão + explicação
(95 chaves novas nos 20 idiomas; as 88 antigas saíram do catálogo). Fora do alcance: o texto da folha Privacy & AI data (descreve a política, não é
ajuda) e mensagens de erro que vêm do sistema (`error.localizedDescription`).

## 14. v29 — fase 2: modelos e migração

Sem mudança visível: os dados que as telas da v29 vão ler. Nenhuma regra de negócio mudou. Os arquivos da v27 abrem com os mesmos valores
(`V29MigrationTests`, com um `scripts.json`, um perfil e ajustes do prompter no formato da v27).

- **`Script.isFinished`** (L1): gravado; ausente = `true` se o roteiro tem texto, `false` se está vazio. **`ScriptState`** (`ready`, `draft`,
  `recorded`) é derivado (`ScriptState.resolve(isFinished:takeCount:)`, `Script.state(takeCount:)`): com ≥ 1 take é RECORDED, senão READY se
  `isFinished`, senão DRAFT. Shape, cues e "Remove all cues" nunca o mudam. `ScriptLibraryService.setFinished(_:of:)` não conta como edição
  (texto, versão e ordem ficam) e `create(…, isFinished:)` recebe o estado explícito (omitido, vale a regra da migração). Uma cópia herda o estado.
  Um formato que esta versão não conhece (gravado por uma mais nova) lê como "sem formato" em vez de impedir a biblioteca de abrir.
- **`ScriptType.mythFact` e `.pov`** (L3): estrutura (Myth · Why people think it · Fact · CTA; POV line · Scene · Twist), briefing, dica, título e
  rascunho sem IA. Os 8 formatos de antes ficam com os mesmos valores.
- **`BrandBrief`** e **`BrandStore`** (L4): marca, produto, "Must say", "Never say", link e código; só vale com marca **e** produto
  (`isUsable`). `BrandStore` guarda as marcas em `Application Support/Library/brands.json` (`BrandRepository`), a mais recente primeiro, sem
  duplicar pelo nome. `adopt(legacyAdBrief:)` transforma o briefing antigo do formato `ad` numa marca **uma vez** (a marca e o produto antigos viram a
  marca, o benefício vira o produto e o "Must say", o código ou o link ficam). `ScriptRequest.brand` leva a marca ao `ScriptPromptBuilder`:
  "use only the facts below", "never invent claims" e "#ad" sempre.
- **`CreatorProfile`**: `openings`, `endings`, `formats`, `swearing` (`Swearing`: never · mild), `examples` (≤ 3, `VoiceExample`, 300 caracteres
  enviados de cada) e `customTags`; as frases (`phrases`) já existiam. Ausentes = vazios. **`voiceStrength`** (0–100, 04 §F9): Essentials 60%
  (tipo, tópicos, público, tom: 15 cada), Personality 25% (aberturas, finais, frases, formatos, palavrões: 5 cada) e Proof 15% (1–3 exemplos, 5
  cada). **`nextQuestion`**: o primeiro item de Personality vazio, na ordem endings → openings → formats → swearing → phrases (a do protótipo),
  pulando os que ficaram para depois (`nextQuestion(excluding:)`). `ScriptPromptBuilder.voiceBrief(profile)` expõe o que a IA recebe ("What Cue sends").
- **`PrompterSettings.boxWidth` / `boxHeight` / `readingLine`** (L8): **a mesma caixa de antes** (`readingWidth`, `textWindowHeight`) e a mesma linha
  (`readingLineOffset`), expostas pelos nomes da v29; nada é guardado duas vezes e os ajustes da v27 abrem no mesmo tamanho. A largura é uma
  **fração** da tela (0,5–0,93), não pontos, para valer em qualquer iPhone; a linha é uma fração da altura (0,10–0,50) convertida pela tela onde é lida
  (`readingLine(on:)`, `setReadingLine(_:on:)`). Ausente, a linha continua onde está hoje (118 pt sob a lente), não nos 22% do protótipo.
- **`SkyMemory`** (L16): `StarPoint` normalizado 0–1; cada ideia enviada acrescenta uma estrela, até 50 guardadas (UserDefaults) e as 14 mais novas
  desenhadas; o lugar sai do número da estrela (sequência de baixa discrepância), então nunca repete nem empilha.
- **Ferramentas** (`design/cue-v29/tools`): `add_strings.py` (junta traduções no catálogo, no formato do Xcode, nos 20 idiomas) e
  `missing_strings.py` (lista o texto novo da árvore de trabalho que ainda não está nos 20 idiomas).

## 15. v29 — fase 3: Scripts e criação

Onde a seção 4 descreve a home de Scripts, o primeiro uso, o card "Let’s Cue", "New script", o formato, o Importar ou o Logbook, vale esta seção.
Nenhuma regra de negócio mudou.

- **Scripts (3.2)** (`ScriptsView`, `ScriptsViewModel`, `ScriptRow`, `ScriptGroup`, `ScriptRowLine`): título "Scripts" com Logbook, busca e "+"; o resumo
  mono "8 SCRIPTS · 3 READY" (`ScriptState.ready`); os filtros por rede (como antes); o card Let’s Cue; e **três grupos** sob cabeçalhos mono:
  **READY TO RECORD · n** (verde), **DRAFTS · n · IN PROGRESS** e **RECORDED · n** (cinza), cada um só existe com roteiros. Cada linha: a barra do tópico
  (`ThemeRail`, na cor do mundo; cinza sem tópico), o título (até 2 linhas), o ponto da rede e a linha mono ("TIKTOK · 0:47 · 4 CUES" pronto,
  "SHORTS · 5H AGO" rascunho, "TIKTOK · 3 TAKES · READY" gravado, com a etapa do vídeo) e o que fazer: **● REC** (`RecPill`) no pronto, **Continue ›** no
  rascunho (abre direto escrevendo), **×n ›** no gravado (vai para a aba Takes; "Open script" no menu de segurar abre a página). **Select** fica no fim
  do primeiro cabeçalho; deslizar para a esquerda mostra **Record** e **More**; segurar mostra a prévia e o menu (Studio mode, Edit, Duplicate, mover,
  idioma, Share, Delete). **Delete tem Undo por 4 s** (`ScriptLibraryService.restore`), também na seleção. Sem resultado (busca, rede ou pasta
  vazia): o estado vazio E ("No {Platform} scripts yet" + **Create for {Platform}**, que põe a rede no card e leva o foco a ele).
- **Card Let’s Cue** (`IdeaPromptCard`): "↻ ANOTHER IDEA" no canto (com o campo vazio), o campo mostra a **ideia sugerida** dos tópicos do criador
  (`IdeaDraftService.suggestion`, a seta a escreve se nada foi digitado) e os chips **Format ⌄ · For {Rede} ⌄ · ✦ Voice nn%** (`MyCueVoiceChip`:
  `CreatorProfile.voiceStrength`, "Voice · Set up" antes do mínimo; abre as perguntas, o liga/desliga da voz fica no Profile). O chip Format mostra a
  tag **AD** quando o anúncio patrocinado está escolhido. **Sem Apple Intelligence** o card é neutro (sem aurora, sem estrelas, sem chip da voz): a seta
  vira **Write it** e abre um rascunho em branco com a ideia no título. "Need an idea?" saiu do card: vive em "+" › Let Cue write it (3.3).
- **A estrela sobe** (`SkyMemory.launchStar`, `StarFlightOverlay`, `SkyStarsLayer`): ao enviar uma ideia, uma estrela branca de 7 pt sai da seta, percorre uma
  curva em 760 ms (encolhendo a 55%, com rastro), brilha em cruz por 380 ms e fica no céu acima de Scripts como uma das "suas estrelas" (as 14 mais novas,
  3 pt amarelo-claro, piscando em 4 s); só depois a página do roteiro abre. Com Reduce Motion a estrela só aparece depois de 150 ms; parada com Low Power.
- **Primeiro uso (3.1)** (`EmptyLibraryView`): "NO SCRIPTS YET", o card, a marca do estado vazio com "Every universe starts with an idea.", "✦ IDEAS FOR YOU ·
  TAP TO START" com 3 ideias (tocar escreve; a estrela sobe da seta da linha; sem IA a linha diz "Write it" e abre o rascunho com a ideia no título),
  "Write my own ›" e "Import ›", e "Record without a script" como o link mais discreto.
- **"+" › Start a video (3.5)**: Let Cue write it (3.3, some sem IA) · Write it myself · **Start from a format** · Import · Answer a comment · Record
  without a script.
- **Formatos (F)** (`FormatChoice`, `FormatSheet`, `FormatTile`): 12 tiles (Auto, Talking head, Tutorial, Storytime, List / tips, Review, Myth vs fact, POV,
  Sponsored ad, Hot take / reply, Announcement, Apology; o quadro tem 11, **Hot take** fica como 12º para nenhum formato se perder), cada um com as seções em
  mono. Escolher só seleciona; **Done** (do card) ou **Open** ("Start from a format": um rascunho em branco, sem Auto) confirma. Sponsored ad vai ao brief.
- **Brand brief (B)** (`BrandBriefSheet`, `BrandBriefViewModel`): marcas salvas em chips (+ New brand), Brand* e Product or offer*, Must say, Never say, Link,
  Code, "Paid partnership label · ALWAYS ON" (#ad, sem interruptor), **Save brand** e **✦ Write the ad** (amarelo só com marca e produto; senão o toast
  "Add brand and product"). Do card, escreve o anúncio **só** com o brief (`ScriptRequest.brand`); em "Start from a format" ou sem IA o botão é "Open the draft".
- **Importar (I)** (`ImportScriptSheet`): **Paste | Scan | Photo | File** põe o texto numa caixa editável (o OCR roda no aparelho) e **Use this script** o cria
  (conta como Done: READY) e abre a página. Scan sem permissão da câmera: "Allow camera in Settings" + Open Settings.
- **Logbook (3.6)**: o botão do cartão é **✦ Write** (sem IA, "Write it": um rascunho com a ideia no título); "Catch it now. Write it later."; vazio com a marca E.
- **Estados ao criar** (04 · F2): "Write it myself" e "Start from a format" nascem DRAFT; a IA que entrega um roteiro completo (card, ideias, Logbook, resposta a
  comentário) o marca como `isFinished` ao terminar; Importar e colar nascem READY.

## 16. v29 — fase 4: página do roteiro

Onde a seção 4 descreve a página do roteiro (Draft | Shaped), o Rec do topo e a barra sobre uma seleção, vale esta seção.

- **Uma página só** (`ScriptPageView`): barra com **voltar**, o chip da plataforma e **•••** (`ScriptPageTopBar`, sem o seletor Draft | Shaped e sem Rec);
  título (27 pt) e a linha mono "113 WORDS · ~0:45"; a **faixa de estado**; a faixa de duração; **Hook** e **✦ Improve** (4.3 e 4.4; o Improve some
  sem IA) e **Aa**; as palavras, sempre editáveis (`ScriptTextEditor`); as dicas; as takes; e **um Record** embaixo.
- **Faixa de estado** (`ScriptStateStrip`, `ScriptStrip`, 44 pt, raio 16): o chip READY / DRAFT / RECORDED, a linha mono ("LIST · 4 CUES", "EDITED · TAP
  DONE", "CHANGED SINCE TAKE 3" em amarelo), **✦ Shape** quando não há cues (só com IA) e **Done**: um botão cinza no DRAFT, texto no READY (sem
  mudanças, só volta), nenhum no RECORDED. O Record da faixa fica de fora: **só há um botão Record por tela**, o de baixo (`ScriptRecordBar`), e ele é o
  único preenchimento amarelo; num roteiro gravado que não mudou desde a take ("Retake") fica cinza, e amarelo depois de editado.
- **Shape é uma ferramenta** (`ScriptCueShaper`): acrescenta até 4 cues (pausa depois do gancho, ênfase no meio, olhar para a câmera antes do fecho e
  sorriso no fim); nunca muda as palavras nem o estado. Os cues aparecem como etiquetas amarelas no texto e a barra sobre o teclado traz **pause · smile ·
  emphasis · look at camera** (`ScriptCuesBar`).
- **Estados** (04 · F2, `ScriptPageRules`): **Done** marca READY (com o toast "Ready to record"); sem texto, "Nothing to save yet" e nada é salvo; com as
  seções de um formato vazias, "{n} sections are still empty." → **Done anyway / Keep writing**; editar e sair sem Done volta o roteiro para DRAFT com o toast
  "Saved as draft" (também ao ir para o segundo plano); um roteiro gravado continua RECORDED e a faixa diz "Changed since take n"; gravar um rascunho o manda
  à câmera como READY.
- **Barra de IA sobre uma seleção** (`AISelectionBar`, `AIPassage`): com Apple Intelligence e mais de 8 caracteres selecionados, uma pílula violeta de 40 pt:
  **✦ Rewrite · Shorter · Punchier · More me · Cut**. A IA troca as palavras **no lugar**, em violeta (`aiReplaced`), e a barra vira **✓ Keep · ↺ Undo · ✦ Try
  again** (escrever, digitar ou selecionar outras palavras mantém; "Try again" refaz a mesma mudança nas palavras de antes). **Cut** só remove, com Undo no toast.
  Sem IA a barra não existe.
- **Sem IA**: a faixa não tem ✦ Shape, a página não tem Improve nem barra, ••• não tem "Improve with Cue"; Hook (as ideias do formato) continua.
- As dicas (gancho longo, frase longa, "No CTA yet · Suggest one") são neutras (leitura do texto, não IA). O editor de blocos antigo continua em ••• › Versions & options.

## 17. v29 — fase 5: gravador

- **Caixa que encolhe** (`ReadingLayout`): gravando, a caixa de texto fica 10 pt mais estreita de cada lado e 16% mais baixa (a linha de leitura não se mexe).
  **Pinça na borda direita** (`ReadingLinePinch`, 56 pt): abrir os dedos leva a linha para baixo, fechar leva para cima, entre 10% e 50% da altura; a alça fina na
  linha continua. Tudo vai para o `PrompterSettings` da sessão (a caixa e a linha são `boxWidth`/`boxHeight`/`readingLine`, ver a seção 14).
  `PrompterViewModel.isCompact` = gravando e sem espiar a barra inteira (os 4 s do toque na tela). "Hide controls while recording" já não existe.
- **Studio grava (5.3)** (`StudioModeView`, `StudioCameraThumbnail`): a câmera **traseira** filma através do vidro do rig enquanto a tela mostra o texto no fundo
  escuro (espelhável); uma miniatura de 64 × 114 pt no canto (anel vermelho gravando) e uma margem de 78 pt à direita para o texto nunca ser coberto. A barra é
  a do Selfie (`SelfieControlPanel(isStudio: true)`, com ‹‹ e ›› ao lado do play): trocar de modo guarda a lente do Selfie e a devolve; sem câmera (Mac, sem
  permissão) o Studio escuta por um medidor próprio, como antes.
- **F3 (04)**: sem microfone, o cartão "Cue needs the microphone" + Open Settings e o Record desligado (`MicrophoneNeededCard`); **armazenamento cheio** ou **uma
  interrupção** (ligação) terminam a take sozinhos: o que o sistema conseguiu fechar vira uma take e o toast diz "Storage full · Take saved" / "Interrupted · Take
  saved" (`RecordingEndReason`, `RecordingDelegate`, `CameraControlling.onRecordingEnded`).
- **Teste sem câmera**: `-uiTestDemoCamera` troca a câmera do gravador por uma que "grava" um vídeo pequeno de verdade (`DemoCamera`, só em Debug).

## 18. v29 — fase 6: Takes, revisão e editor

- **Pick your best take automático (6.1, 04 · F3)**: parar uma gravação que deixa **duas takes ou mais** do roteiro e nenhuma ★ abre a revisão já em "Pick
  your best take" (`ReviewLaunchAction.pickBest`, `PrompterViewModel.shouldPickBest`); uma take só (ou freestyle) vai direto à revisão (6.3).
- **Delete com Undo de 4 s (6.3, F4)**: a lixeira da revisão tira a take da biblioteca na hora (`TakeLibraryService.remove`) e o toast traz **Undo**
  (`restore`); o vídeo e o que o Quick edit guardou só são apagados depois dos 4 s (`purge`).
- **Fotos negadas (6.3)**: salvar sem a permissão do Fotos mostra o cartão "Photos is off for Cue · Allow it to save your video." com **Open Settings**
  (`PhotosDeniedCard`) sobre as ações, em vez de um toast; fechar o cartão ou o próximo salvamento que funciona o tira.
- **Takes vazio (E)**: `EmptyState` ("No takes yet" · "Record one and it shows up here." · **Record a take** · "Write a script first ›").
- **Editor (7.2)**: a toolbar principal é **Edit · Audio · Text · Captions · Filters · ✦ Smart · Cover** (a ordem do CapCut; o Smart em violeta, o Cover no
  fim). **Adjust, Crop, Background e Overlay** ficam nas ferramentas do clipe (Edit): Adjust, Filters e Background mudam esse clipe; Crop (o formato da saída)
  e Overlay (foto ou vídeo por cima) são do vídeo todo, mas moram ali. O **Background do vídeo todo** é o 5º tile do ✦ Smart (Auto captions · Remove pauses ·
  Studio Voice · Auto adjust · Background). Voltar guarda o rascunho e mostra "Draft saved".
- **Legendas sem reconhecimento de fala (7.4)**: "Captions need speech recognition. You can still write the lines yourself." (a ação é "Write them myself").
- **Diferenças**: os painéis do editor têm altura fixa por tamanho (mini, médio, cheio), e o conteúdo ainda **rola por dentro como segurança** em telas
  compactas e com texto grande (o quadro pede "nada rola", mas cortaria controles); a abertura do editor (7.1) mostra o overlay enquanto a take é lida, sem
  esperar 2,8 s fixos; a zona de 34–44 pt sem controles é a área segura de baixo mais `Metrics.editorPanelBottomClearance` (8 pt).

## 19. v29 — fase 7: compartilhar, universo e Pro

- **8.1 anúncio** (`ShareToSheet.adWarning`, `TakeReviewViewModel.isSponsored`): para um roteiro `ad`, a sheet "Share to" mostra a barra "AD · #ad is copied · paste it
  in your caption" e **"#ad" vai para a área de transferência** a cada exportação que dá certo (salvar, uma plataforma ou More); o formato patrocinado já escreve com
  "#ad" sempre ligado (fase 3).
- **Exportar (F6)**: a exportação **só conta depois de o vídeo estar onde ia** (salvo no Fotos ou entregue ao share sheet): uma falha, ou o Fotos negado, deixa o
  contador onde estava. Falha = toast "Couldn't export · Try again"; Fotos negado = o cartão da fase 6. O paywall abre na 6ª exportação e ela continua sozinha
  depois da compra.
- **9.2 Your universe**: o **núcleo animado "YOU"** no meio (brilho violeta que respira em 4 s, disco amarelo → violeta e uma estrela branca que o circula em 12 s;
  parado com Reduce Motion): **sem foto e sem inicial** (L12). Vazio: o núcleo sozinho e o estado E "Your first star is one video away" · "Share a video and it
  becomes a star here." · **Open Takes**. A imagem de "Share my universe" usa o mesmo núcleo.
- **11.4 Pro (F7)**: sem mudança de regras. Compra cancelada volta sem mensagem; sem internet "Can't reach the App Store"; qualquer outro erro "Purchase didn't go
  through" (`StoreManager.message(for:)`); Restore continua visível no rodapé.

## 20. v29 — fase 8: Profile e My Cue Voice

Onde a seção 4 descreve o card de My Cue Voice no Profile ("What Cue uses"), vale esta seção. Nenhuma regra de negócio mudou.

- **9.1 Profile**: o card do My Cue Voice (`MyCueVoiceCard`) mostra o **medidor** ("VOICE 65% · GOOD START", `VoiceMeter`: Just started < 30 · Getting there < 60 ·
  Good start < 85 · Sounds like you), **uma frase** com o que o criador respondeu (`CreatorProfile.voiceSentence`), a prévia ao vivo, **a próxima pergunta** com
  **Answer** (abre a sheet dela) e o interruptor "Use my voice in AI scripts"; **Edit voice ›** abre a página 9.3. As linhas "What Cue uses" saíram do card.
- **9.3 My Cue Voice** (`MyCueVoicePage`, `Screens/Profile/Voice`): o medidor, a frase, o interruptor, a próxima pergunta e as **três camadas**, cada uma com
  seus pontos ("ESSENTIALS 45 / 60", "PERSONALITY 10 / 25", "PROOF 5 / 15", os pesos de `voiceStrength`): **Essentials** (I am · Topics · Audience · Voice, cada
  linha abre as perguntas do My Cue Voice naquele ponto), **Personality** (Ends with · Opens with · Usual formats · Swearing · My phrases,
  `VoicePersonalitySheet`) e **Proof** (Examples, até 3, `VoiceExamplesSheet`); no fim **"What Cue sends"**: o `ScriptPromptBuilder.voiceBrief` em monoespaçada,
  como o modelo o lê ("What Cue tells Apple Intelligence · on device"). Sem Apple Intelligence a página diz "My Cue Voice needs Apple Intelligence · Your answers
  stay saved and you can still edit them", sem nudges, e tudo continua editável.
- **Validação (04 · F9, `VoiceTextValidator`, `CreatorProfileService+Personality`)**: texto livre de 2 a 40 caracteres; um **erro de digitação** de uma opção
  (distância de edição 1, ou 2 em palavras longas) pergunta **"Did you mean “…”? Use · Keep mine"**; uma **palavra que o Apple Intelligence não usa** (palavrões
  fortes em vários idiomas e frases de autodano, com lista de exceções para "hello", "computador"…) não é salva ("Apple Intelligence can’t use this word.");
  **repetido** (sem caixa nem acento) não soma e diz "Already added."; **limites**: tópicos ≤ 3, tons ≤ 2 ("Max 2 · tap to remove"), aberturas ≤ 2, finais ≤ 2, frases ≤ 5,
  formatos ≤ 3, exemplos ≤ 3 → toast "Max n …" (`VoiceLimits`). Exemplos: ≥ 20 caracteres e, com palavras bloqueadas, "…Bleep them (f***) or pick another example.".
- **Nudges (`VoiceNudgeService`, `VoiceNudgeCard`, `VoiceNudgeSlot`)**: uma pergunta de cada vez em **Scripts** (abaixo do card Let’s Cue) e **Takes** (sob o pipeline),
  sobre o primeiro item de Personality vazio (endings → openings → formats → swearing → phrases); só com o mínimo do My Cue Voice e **com Apple Intelligence**.
  Respostas de um toque, **None of these** (a pergunta não volta e não conta como preenchida: `CreatorProfile.declinedVoiceItems`), **+ Something else** (a sheet da
  pergunta com o campo) e **Not now** (segura por 3 dias, `DefaultsKey.voiceNudgeSnoozes`).

## 21. v29 — fase 9: Settings, estados vazios e passada final

- **Settings em sheets (L14, 11.1)**: **Recording**, **Remote** e **Language & Region** abrem como sheets sobre o Settings (`SettingsSheet`, guardado no
  `PresentationService`, então sobrevive à troca de idioma que reconstrói a interface), cada uma numa `NavigationStack` com **Done**; **Prompter** (11.2),
  **Personalize** (11.3) e **Acknowledgements** continuam empurradas. **Privacy & AI data** já era sheet. Um novo item **Cue Pro** (Active / Free plan) em
  Purchases & About abre o paywall (11.4), ao lado de Restore purchases.
- **Delete my Cue data (F8)** (`DataEraserService`, em Privacy & AI data): um alerta "Delete all your Cue data?" → **Delete everything** (irreversível) remove
  roteiros, takes (vídeos, edições e rascunhos), Logbook, marcas, "suas estrelas", My Cue Voice e o setup de gravação. **Não** mexe na compra, no contador das
  5 exportações grátis (fica no Keychain, para apagar os dados não devolver exportações), no idioma nem no que já está no Fotos. "Help improve" não existe: o app
  não envia nada a lugar nenhum.
- **1.2 tópico próprio**: o campo de "+ Your own" usa a mesma validação do My Cue Voice (palavra bloqueada, "Did you mean…", repetido) com a mensagem inline.
- **3.2 chip ✦ Voice**: com a voz pronta, o chip abre a página 9.3 (numa sheet com Done); sem ela, as perguntas.
- **10.2 Answer a comment**: "✦ Draft my reply" (com Apple Intelligence), **Write it myself** (um rascunho em branco com o comentário; o único caminho sem IA) e
  **Save to Logbook** (guarda o comentário como ideia).
- **Estados vazios (L13, padrão E)**: Scripts (3.1), Scripts com filtro sem resultado, Takes, Logbook e Your universe usam o `EmptyState`.
- **Modo claro**: o app é só escuro desde a v27, então não há modo claro a revisar.
