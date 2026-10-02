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
  por uso), Creator Voice, Quick edit (com as ferramentas de criador: texto, mídia, voice-over,
  velocidade, Remove Pauses, estilos, transições e capa), Clean Up, legendas, 4K, versões e melhor
  take são grátis. O
  único limite é **exportar vídeos**: 5 exportações grátis (salvar no Fotos ou compartilhar), sem marca
  d'água; depois, o paywall oferece 7 dias grátis no mensal ou no anual. Gravar, editar e escrever
  nunca param, e as takes nunca são apagadas nem bloqueadas (`UsagePolicy`, `UsageQuotaService`).
  O contador fica no Keychain, então reinstalar não zera. Não há badges "PRO" nem marca d'água.

## 2. Aparência

O app roda **somente em modo escuro** (`UIUserInterfaceStyle = Dark`): é um app de câmera, e uma
tela branca atrapalha a gravação. Os tokens mantêm valores claros para o dia em que isso mudar, e
esses valores já passam nas regras de contraste da Apple (seção 8, "Contraste"): quem desenvolver o modo
claro parte de tokens corretos e de testes que falham quando um deles sai do mínimo.

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
| `ink` / `ink2` / `ink3` | branco / `#EBEBF5` 60% / 45% (claro: preto / `#55555A` / `#6E6E73`) | Texto principal; texto secundário (4,5:1 em toda superfície); o que não precisa ser lido (chevrons, contornos, desligado, 3:1) |
| `acc` | `#FFD60A` | Acento como **preenchimento**: ação primária, hook, guia de leitura |
| `accText` / `warnText` / `dangerText` / `infoText` / `successText` | escuro: o próprio acc/warn/`#FF8078`/info/success · claro: `#7A5C00` / `#9A4A00` / `#A8001A` / `#00638F` / `#1A6F2E` | Amarelo, laranja, vermelho, azul e verde **como texto ou ícone**: os preenchimentos somem sobre o branco, estes passam 4,5:1 nas superfícies do app. Com Increase Contrast ficam um degrau mais fortes |
| `accInk` | `#000000` | Texto sobre `acc` |
| `accSoft` | `#FFD60A` 16% | Fundos tingidos (tags de cue, botões secundários de gravação) |
| `accWash` → `accWashFaint` / `accBorder` | `#FFD60A` 22% → 5% / 38% | Card de Prompt em destaque |
| `record` | `#FF3B30` | Botão de gravar, badge de gravação |
| `danger` / `dangerFill` | `#FF453A` / `#D70015` | Ações destrutivas (ícone); fundo do botão que remove, sob texto branco (5,4:1) |
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
| `editorPanel` · `editorSeparator` · `editorToast` · `editorBarButton` | `#121214` · `#545458` 50% · `#2C2C2E` 96% · `#3A3A3C` 70% | Editor: painéis, separadores, toast (com estrela amarela) e botões da barra superior |
| `laneText` / `laneTextSelected` · `laneCaption` · `laneMusic` + `laneMusicInk` · `laneVoiceOver` + `laneVoiceOverInk` · `laneMedia` + `laneMediaInk` · `laneRecording` | `#FFD60A` 20% / 32% · `#EBEBF5` 14% · `#0A84FF` 30% + `#64D2FF` · `#FF9F0A` 30% + `#FFB340` · `#BF5AF2` 30% + `#DA8FFF` · `#FF453A` 50% | Faixas da timeline (fundo + texto na cor cheia; texto amarelo e legenda branca) |
| `pauseRemoveStripe`/`Gap` · `pauseKeepStripe`/`Gap`/`Border` | amarelo 62% / 20% · branco 25% / preto 30% / branco 75% | Pausas na trilha principal: a remover (hachurado amarelo) e a manter (cinza tracejado) |
| `waveformWell` · `waveformBar` · `rulerLabel` · `laneGhostBorder` / `laneGhostInk` · `joinMark` | `#232326` · `#EBEBF5` 55% · `#EBEBF5` 55% · `#EBEBF5` 30% / 70% · preto 60% | Forma de onda, régua, atalhos tracejados das faixas vazias, marca de um corte seco |
| `laneStrip` · `laneStripActive` · `laneStripRing` · `laneGutterInk` · `laneHintInk` · `adjustDialRing` · `selectedRow` | `#1C1C1E` · `#24231C` · `#FFD60A` 75% · `#EBEBF5` 85% · `#EBEBF5` 60% · `#EBEBF5` 35% · `#FFD60A` 8% | Editor v12: faixa de cada track, a mesma com as ferramentas abertas (com anel), ícone da faixa, dica da faixa vazia (o protótipo usa 45%, 3,9:1; 60% dá 5,9:1), anel de um dial de Adjust em zero, linha da lista em que o cursor está |
| `panelCard` · `sliderTrack` · `toggleOff` · `accTile` · `accCard` · `dangerWash` · `presetCardDim` / `presetCardBorder` · `coverDim` | `#767680` 16% · 40% · `#787880` 36% · amarelo 12% · 10% · `#FF453A` 16% · preto 28% / branco 8% · preto 50% | Controles dos painéis: cards, trilho do slider, switch desligado, tile e card escolhidos, lixeira de uma linha, cards de preset, quadro da capa |

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
| `CueIconButtonStyle` (`.cueIcon(.glass/.overlay/.surface/.tinted/.accent/.light/.danger)`) | Botões redondos |
| `surfaceCard()` / `GroupedCard` | Cards e grupos de linhas com separadores |
| `FilterChip`, `TagPill`, `ColorDot` | Chips de filtro/opção, tags, ponto do destino |
| `SelectableCard` | Tiles selecionáveis (fontes, enquadramento, formato, plano) |
| `ValueSlider`, `SwatchButton`, `UsageMeter` | Sliders com valor, amostras de cor, medidores |
| `SettingToggleRow` | Linha de ajuste com título, detalhe e switch verde (Display, câmera) |
| `SheetHeader`, `SectionHeading` | Cabeçalho de sheet e de grupo |
| `FlowLayout` | Chips que quebram linha (nichos, frases) |
| `SearchField` | Busca em cápsula (`fill`, 40 pt) dentro do conteúdo, para quando algo vem acima dela (Scripts) |
| `ToastView` | Confirmação curta no topo (`ToastService` + `.toastHost()`); com `ToastAction` ganha um botão ("Undo", 4 s) |
| `CueMark`, `CameraFeedPlaceholder` | Marca e fundo quando não há câmera |
| `QRCodeView` | QR code nítido em qualquer tamanho, sobre o branco que os leitores precisam (pareamento do remote) |
| `RecordGlyph` | Anel branco com ponto vermelho da aba Record (imagem com cores originais) |
| `fittedSheet()` | Sheet da altura do conteúdo, raio 38 (New script, Start recording) |
| Controles do editor (`Screens/QuickEdit/Panels/Controls`) | `EditorPanelContainer` (título, escopo, Reset, ✓ amarelo de 40 pt, conteúdo que rola e rodapé fixo; Dynamic Type até AX Medium), `PanelSegmented` (escolha em cinza ou amarela; fonte encolhe até 12 pt; 44 pt de alvo), `PanelSlider` (trilho fino, preenchimento amarelo, do centro nos −100…+100), `PanelRulerSlider` (a mesma ideia como régua de 40 passos, a do Adjust), `PanelTiles`, `PanelChips` (família na própria fonte), `PanelSwatches`, `PanelToggleRow`/`PanelSwitch`, `PanelStepper`, `PanelTabs`, `PanelAdvancedButton`, `PanelButton`, `PanelNote`, `PanelInlineList`, `PanelPresetCard`/`PanelSaveStyleCard`; `EditorToastHost` (toast do editor) |
| `PromptCard` (`Screens/Shared/PromptCard`) | Caixa de Prompt em destaque: selo Apple Intelligence, exemplo e botão enviar. `.compact` (Scripts) tira a explicação e usa "Describe your next video…" |

## 4. Telas

| Tela | Onde | Conteúdo |
|------|------|----------|
| Scripts (home) | `Screens/Scripts` | "+" no topo (abre New script), título + resumo, caixa de Prompt compacta (sempre visível, no topo da lista; abre Generate › Prompt), busca, chips (All, destinos, pastas), card "Last edited", lista "All scripts" com swipe (Record / More / Delete), segurar mostra preview + menu, modo de seleção com barra (mover, duplicar, apagar) |
| Primeiro uso | `EmptyLibraryView` | "Start with a script." + caixa de Prompt + Write / Import / Generate with AI + "Record without a script" |
| Script (leitura) | `Screens/ScriptDetail`, `Read/` | Título (28 pt) e **uma linha-resumo** (`ScriptSummaryRow`): ponto da plataforma · "TikTok · 123 words · ~49s" e, em amarelo ou laranja, "In the ideal range ›" / "12s under ideal ›"; tocar abre **Script details**. Botão **Improve script** (tinto, com a etiqueta laranja "1 tip" quando o hook passa de 3,5 s) abre a sheet de IA. Banner laranja de checagem de fatos ("Checked" dispensa). O texto em parágrafos, cada um sob o rótulo do bloco (HOOK · BODY · CTA, uma linha fina e o tempo do bloco, laranja no hook longo); **tocar num parágrafo começa a escrever ali**, com o cursor no fim dele; "Tap any line to edit". Takes, Studio mode + Record. Menu ••• : Script details, Duplicate, Move to folder, Script Language, "Make a version for…", Share, Delete. O Edit da barra continua |
| Script (edição) | `ScriptEditorView`, `Editor/` | **Modo de escrita focado**: sem a barra de navegação, só o cabeçalho (título editável, "● 123 words · ~49s" com o ponto na cor da faixa de duração, e **Done** amarelo), o texto como **blocos** (um `UITextView` por parágrafo, sob o rótulo e o tempo do bloco; Return cria um parágrafo, Backspace no começo junta com o anterior, colar várias linhas vira vários parágrafos, ↑ ↓ nas bordas trocam de parágrafo com teclado físico; o cursor nunca fica escondido) e **uma barra de 48 pt** acima do teclado: **AI** (amarelo) · **[ ]** Cues · Sections · Options · mostrar/esconder o teclado. Cada ferramenta abre um **painel no lugar do teclado**, da altura dele (`EditorToolPanel`): **Improve with AI** (grade de 2 colunas com as ferramentas do formato; "In my voice" primeiro; o texto muda, o painel fecha e o toast diz o que foi feito com **Undo** por 4 s), **Cues** (pause, beat, smile, look at camera, confident, slow down, breathe, show product, demo, na língua da interface; entram no cursor e o painel fica aberto), **Sections** (blocos com as primeiras palavras e o tempo; o bloco do cursor aceso; tocar leva o cursor; "New section at cursor") e **Script options** (Create for, Script type, Show cues while recording = AI Coach do prompter, Text size A A A só do editor, **Discard changes**). Não há Cancel nem aviso de versão em cima do texto: o aviso é o toast ao concluir ("Saved as v2 — your take stays with v1") e só aparece com takes |
| Improve script | `ImproveScriptSheet` | "Improve script · Apple Intelligence · runs on your iPhone"; dica do hook (laranja, abre as opções); as ferramentas em lista com ícone, nome e o que fazem ("Fit to time · Ideal for TikTok: 1:00–1:30"); na leitura, uma ferramenta grava o texto na hora (nova versão quando há takes) e o toast oferece Undo |
| Script details | `ScriptDetailsSheet` | Create for e Script type (abrem suas sheets); o medidor de duração com a faixa ideal e o mínimo de monetização; os blocos em chips (tocar fecha a sheet e leva a leitura até o bloco); Format ("9:16 · 1080p30"), Version ("v2 · 3 takes") e Monetization goals |
| Script type | `ScriptTypeSheet` | "Talking video" (sem formato) e os 8 formatos, cada um com o fluxo ("Hook → Tips → CTA"); define os blocos e as sugestões de IA, nunca as palavras |
| Create for | `DestinationSheet` | 6 plataformas com resumo do preset (formato · qualidade · safe zones · ideal) + "Monetization goals". Escolher mostra o toast "Create for {plataforma}" |
| Hooks | `HooksSheet` | Hook atual + 3 opções escritas pelo modelo no aparelho (sem modelo, as do formato) + "More options" |
| New script | `NewScriptSheet` | Caixa de Prompt + grade Write / Import / Themes / Formats. Sobre a câmera, Paste no lugar de Write |
| Start recording | `StartRecordingSheet` | "Read from a script" (4 recentes com duração), "+ New script", "Record without a script →". Sobre a câmera vira "Add a script", sem o freestyle |
| Importar | `ImportScriptSheet` | Files, Scan (câmera de documentos), Photo e Clipboard. Scan, Photo e PDFs escaneados passam por OCR do Vision no aparelho |
| Gerar com IA | `GenerateScript/` | "Generate with AI · Apple Intelligence · private · no cost" + abas **Prompt** (texto livre, exemplos, Create for, Length, "Write in my voice", aviso de fatos), **Themes** (6 ideias do nicho, "New ideas", "Use" preenche o Prompt) e **Formats** (8 formatos, Sponsored ad incluído) → briefing |
| Selfie | `Screens/Prompter/Selfie` | Câmera em primeiro plano, em camadas que nunca entram no vídeo: o **frame gravado** (o preview mostra exatamente o que é gravado; fora dele, preto 60% e bordas de 0,5 pt), a **zona segura** da plataforma (degradê em cima e embaixo, sombra nas laterais, contorno tracejado e "INSTAGRAM REELS SAFE AREA"), a **janela de texto** (largura 50–93%, padrão 93%; altura 160–380, padrão 380: começa com as preferências do criador e pode ser ajustada na sessão; as linhas quebram normalmente e preenchem a largura; fundo preto 25%; desfoque opcional; o texto já lido esmaece) e a **linha de leitura** fixa logo abaixo da lente (118 pt na frontal; 36% do frame na traseira), com uma alça fina (14 × 34, alvo de 44 pt) para arrastar, que some enquanto o texto roda ou a câmera grava. Sem dica de primeiro uso. A janela segue a linha (a linha fica ~25% abaixo do topo dela). Topo: fechar, Selfie \| Studio e o chip "{Plataforma} · 9:16" (abre Create for; em freestyle troca o enquadramento); gravando: olho (Hide UI), "● 00:42 \| 18s to 1:00" e o chip. Barra de vidro: Voice Following \| Steady, slider de velocidade com o valor (0,3–2,0×) ou a pill do Voice Following (`VoiceIndicator`, `VoiceFollowStatus`): "AUTO · Listening/Paused" só enquanto o reconhecimento segue as palavras; a velocidade no lugar do AUTO quando o texto anda na velocidade definida enquanto a voz soa ("0.7× · While you talk", sem reconhecimento no idioma), e "0.7× · Getting ready" / "0.7× · Downloading 40%" enquanto o modelo do idioma carrega ou baixa; voltar ao topo, play, Aa; entre as duas linhas, no meio do fio que as separa, a **pill do microfone** (`AudioInputPill`: 🎙 + ponto verde + nome da entrada em uso, ex.: "iPhone Microphone", "DJI Mic"; cápsula `overlayFill` de 26 pt, alvo de 40 pt; ponto `ink3` enquanto a sessão de áudio não informou a entrada; "Microphone off" com ponto laranja sem permissão; abre Audio Input e fica travada gravando ou na contagem) e, ao lado, a **pill do setup** (`SetupSummaryPill`: "4K · 9:16"; quando os valores vêm de uma recomendação aceita ou de uma mudança só desta take, a origem vem antes em amarelo: "TikTok setup · 1080p · 9:16", "This take · 4K · 1:1"; abre "This take"; travada gravando); câmera: última take, ajustes, gravar, virar, timer. Quando a plataforma do roteiro recomenda outro setup (formato, qualidade ou fps diferentes do Creator Setup), um **card de recomendação** (`SetupRecommendationCard`, vidro, acima da barra, como o aviso de monetização) diz "Recommended for TikTok · 9:16 · 1080p · 30 fps · TikTok safe zone" e "1080p instead of your usual 4K." (ou "Your usual setup is …" com mais de uma diferença), com **Keep 4K** / **Use 1080p** ("Keep My Setup" / "Use Recommended"); até a resposta grava com o Creator Setup, e gravar sem responder mantém o Creator Setup. Com os controles escondidos ficam só texto, linha, relógio e um botão de parar |
| Studio | `Screens/Prompter/Studio` | Prompter em tela cheia sem câmera, barra de progresso no topo, fechar, Selfie \| Studio, Remote Control (amarelo com um remote conectado) e espelhar; barra: Voice Following \| Steady, slider de velocidade (no Voice Following, "Listening/Paused" e, ao lado, `prompter.voiceStatus`: "Follows your words" enquanto o reconhecimento segue as palavras, "Scrolls at 0.7× while you talk" sem ele, "Getting ready to follow your words…" / "Downloading Thai · 40%…" mesmo antes do play), voltar ao topo, 3 linhas para trás/frente, play grande amarelo e Aa |
| Display | `DisplaySettingsSheet` | "Display · ● Live preview". No Selfie, primeiro **Layout** (`DisplayLayoutSection`): Reading line com ↑/↓ e a distância da câmera, Text window height e width ("Narrow · less eye movement"), **Social safe zone** (chips Reels / TikTok / Shorts / Stories / Custom no 9:16, LinkedIn / Custom no 4:5, Custom no 1:1; no Custom, margens em %), Show safe zone, Hide controls while recording e "Reset to Recommended", com o aviso de que a zona é guia e não garantia. Quick: AI Coach (desligado por padrão), Text size e, no Selfie, Background opacity e Camera blur (Off/Subtle/Soft/Medium, leve); no Studio, Reading line (Top/Bottom) e Background color. Advanced (recolhível): fonte, espaçamento, margens, alinhamento, cor, linha de leitura, espelhar. No Selfie, a altura máxima para logo abaixo da janela de texto (medida quando a sheet abre) |
| Audio Input | `AudioInputSheet` | Aberta pela pill do microfone no Selfie (sheet na altura do conteúdo, sem tela de ajustes separada): "Audio Input" + "Where Cue hears you in this take.", a lista das entradas conectadas agora (nome + tipo: Built-in, Bluetooth, USB, Wired headset…) com a que está em uso marcada (círculo amarelo), e "Plug in or pair a mic and it shows up here.". Tocar numa entrada a torna a entrada da gravação, fecha a sheet e a pill muda na hora. Sem entradas: "No microphone found…"; sem permissão: explicação + Open Settings |
| This take | `RecordingSetupSheet` | Aberta pela pill do setup (sheet na altura do conteúdo): "This take · What Cue records with, and why."; card da recomendação (resumo, "Your usual setup is …", chips Use Recommended / Keep My Setup com ✓ no escolhido, ou "Your setup already matches it."); lista Camera, Microphone, Format, Quality, Frame rate, Text size, Scroll speed, Mirror text, Safe zones com o valor e a origem (`TagPill`: "Your setup", "TikTok setup" com ponto amarelo, "This take" com ponto azul `info`); "Back to my setup" quando há mudanças; linha Remote Control; "Changes here are for this video. Your usual setup stays in Settings › Creator Setup." |
| Remote Control (sheet) | `RemoteControlSheet` | Pelo "This take" (Selfie) ou pelo botão do Studio: "Control your teleprompter from another device." + `RemotePairingPanel` |
| Câmera | `CameraSettingsSheet` | Lente, enquadramento, resolução, fps, grid, safe zones, estabilização, microfone, contagem, formato, e **Background** (Original / Blur / Color + cores; só nesta sessão, travado gravando): o preview mostra o efeito ao vivo e a take é gravada como a câmera vê, com o efeito salvo como receita (aparece na revisão, no Quick edit, onde pode mudar, e no export); "Your recording stays as filmed. The effect is added to the take, and you can change it in Quick edit."; sem detecção de pessoas, "This iPhone can’t find people in video, so the background can’t change here."; se a câmera não entrega frames junto com a gravação, "This camera can’t show the effect while recording. It’s added to the take after you record." Lente, enquadramento, qualidade, microfone e safe zones mudam só nesta sessão ("…change for this take. Your usual setup stays in Settings › Creator Setup."); grid, estabilização, contagem e o resto continuam salvos. No Selfie com script, a sheet para logo abaixo da janela de texto (não cresce além dela) e não escurece o fundo |
| Revisão do take | `Screens/TakeReview` | Vídeo no formato da take (barras pretas fora do 9:16); topo: voltar, "Take N · 0:44", estrela e lixeira; filmstrip, título (+ EDITED), meta, "3 of 5 free exports" + Go Pro (no grátis); faixa "Your takes · N" (troca de take, "Tap ☆ to pick your best", "Suggest best"); Edit · Retake · Save · Share (Share amarelo, abre Share to). Só uma melhor take por roteiro |
| Share to | `TakeReview/Share` | Miniatura, "SHARE TO", título, "0:44 · 9:16 · 1080p"; seis plataformas (a da take com anel amarelo e "recommended"), Save video e More; "Created for X — framed and safe-zoned for it"; Burn in captions; Cover ("Saved to Photos with the video" + Save cover, só quando o Quick edit tem capa; salvar a capa não conta como exportação); Quality 1080p / 4K; exportações grátis restantes + Go Pro. Plataforma: exporta, salva no Fotos e abre o app; "Ready to post on X · N of 5 free exports left". Sem exportações grátis, qualquer exportação abre o paywall e continua sozinha depois da assinatura |
| Quick edit | `Screens/QuickEdit` | **Layout** (`EditorLayout`, testado): pilha vertical calculada pela altura útil `H` (sem posições fixas): barra superior 44 pt, prévia flexível, barra do player 44 pt, timeline `clamp(0,32·H, 184, 300)` e toolbar 64 pt; com painel, o painel tem três tamanhos (mini `clamp(0,27·H, 200, 250)`: Speed, Zoom, Volume, Filters, Crop, Voice-over, Auto captions, Media, Transition; médio `clamp(0,38·H, 250, 340)`: Voice, Pauses, Captions, Adjust, Background, Cover; cheio `clamp(0,44·H, 300, 380)`: Text style, Caption style) e a timeline fica com o resto; a prévia nunca fica abaixo de `max(0,30·H, 190)` (a timeline encolhe primeiro, depois o painel rola; nos cheios a timeline pode sumir). Classes por `H`: regular (≥ 780), compacta (680–780: trilha 48, faixas 24, rótulos 10 pt, abas do Text style na linha do escopo) e muito compacta (< 680, iPhone SE: barras 40, trilha 44, faixas 22, toolbar só com ícones e o rótulo num toque longo, painéis cheios como sheet que nunca cobre a prévia mínima). Até `accessibilityMedium` os controles crescem; acima, os painéis rolam. **Topo:** Done (salva na take: "Edits saved to this take") · "Take 3" + "00:21.6 · Saved" ("Saving…" até o rascunho guardar) · **Export** amarelo. **Prévia:** o quadro no formato da take, em fit; textos e legendas desenhados como no export (proporcionais ao quadro). Tocar num texto o seleciona (contorno amarelo de 2 pt a 5 pt, × para apagar e ⤡ para escalar, brancos de 24 pt com alvo de 44); tocar de novo abre Text style; arrastar move (com keyframes, cria ou ajusta o do playhead), com guias amarelas no centro (encaixe a 2,5% com háptico) e a área segura da plataforma tracejada; arrastar a legenda muda a altura de todas (encaixa em Top 16% / Middle 50% / Bottom 76%); tocar no vazio solta. **Tela cheia** (⤢): só o vídeo; tocar nele dá play/pause, fora sai. **Barra do player:** "00:01.2 / 00:21.6", play no meio, undo/redo (sempre à mão; 60 níveis, gestos contínuos e digitação viram um passo só, coalescidos em 900 ms) e tela cheia; no teclado, espaço, ⌘Z e ⇧⌘Z. **Timeline** (`TimelineScrollingView`, UIKit, `TimelineGeometry` testada): linha branca de 2 pt fixa no centro e o conteúdo rola por baixo com inércia nativa; o dedo faz scrub (seek exato, pausado) e o play move o conteúdo (o player é a fonte do tempo); pinça (ou ctrl/⌘ + scroll) ancorada no playhead, 44 pt/s × 0,35–5; régua de 0,5 / 1 / 2 / 5 s com `mm:ss` a cada dois passos. Trilha principal: miniaturas reais (largura = altura × 9/16, em cache por tempo da gravação) sobre 14 pt de forma de onda (RMS a cada 0,1 s, Accelerate), selo amarelo ("1.5×", "Push in", "Muted") a duração quando selecionado e, quando a gravação tem fundo (Blur, Color, Image), o nome dele no selo; a **Cover** antes do início e o **+** depois do fim (Insert as clip). Faixas: Text (textos e mídia por cima; cada mídia diz o que é e como aparece: "Photo · Full screen", "Video · Window"), Captions, Music, Voice-over; **cada faixa tem seu fundo** (`laneStrip`, de 40 pt da esquerda a 8 pt da direita, que não rola) e, à esquerda, uma **calha preta de 38 pt com o ícone** (Aa, legenda, nota, microfone) por cima da qual o conteúdo rola; uma faixa vazia diz o que um toque faz, em texto simples ("Tap to add text", "Tap to add captions", "Tap to add music or voice-over", 12 pt a 50 pt da esquerda); **tocar na faixa (fundo, calha ou dica) abre as ferramentas dela na toolbar** (Text, Captions ou Audio; Music, Voice-over e a dica de áudio abrem Audio), acende o fundo (`laneStripActive` + anel amarelo de 1,5 pt) e um segundo toque, ou qualquer outro toque, devolve a toolbar principal; com painel, a faixa dele sobe para baixo da régua e a principal encolhe a 40 pt. Tocar seleciona (contorno amarelo, alças amarelas de 16 / 12 pt com alvo ≥ 32, o resto a 50–55%, a faixa cresce de 28 para 36); tocar no vazio solta. Alças com balão ("00:04.1 · 1.8s"); na alça esquerda do clipe o conteúdo acompanha o dedo e se reajusta ao soltar; legendas não passam das vizinhas. Ordem: alça > toque (< 4 pt) > scrub > pinça. Snap com háptico a 6 pt (junções, começo e fim de legendas e textos, keyframes). Cada **corte** tem uma marca de 20 pt (+ num corte seco, amarela com o ícone da transição) que abre Transition. **Toolbar** por contexto (64 pt, ícones de 24, rótulos de 11; rola com fade à direita): principal Edit · Text · Captions · Audio · Pauses · Media · Adjust · Filters · Background · Crop; com algo selecionado, "‹ Clip" (Split · Speed · Zoom · Volume · Voice · Duplicate · Delete), Text (Edit · Style · Keyframe · Duplicate · Delete), Caption (Edit · Split · Join next · Style · Delete), Music (Volume · Replace · Delete), Voice-over (Volume · Re-record · Delete), Media (Edit · Replace · Delete; Replace abre a biblioteca e troca só o arquivo — foto por foto, vídeo por vídeo —, mantendo lugar, duração, janela, camada e keyframes); menus Text (Title · Subtitle · Hook · Callout · Style all), **Captions** (com linhas: Add line · All lines · Style; sem: Auto captions · Write them) e Audio (Voice · Music · Voice-over). **Delete, em vermelho, fica sempre no fim da barra** e não rola (`EditorToolbarItem.isPinned`); as outras ferramentas rolam por baixo de um degradê. Audio › Music **sempre adiciona**: abre Files e o clipe entra no playhead, no espaço livre em volta (`MusicPlacement`: com o playhead sobre um clipe vai para o fim dele, para onde o próximo começa; sem espaço, "No room here — move the playhead to a free spot"); **Replace** (com a música escolhida) troca só o arquivo, mantendo lugar, volume e fades. Edit seleciona o clipe do playhead; Split esmaece fora do clipe (toca e explica). **Painéis** (`EditorPanelContainer`; a superfície vai até a borda da tela, mas os controles e o rodapé param acima da área segura de baixo — onde fica o Home Indicator — mais `Metrics.editorPanelBottomClearance`, via `safeAreaPadding`, onde quer que o painel apareça: sob a timeline ou em sheet; o conteúdo rola e nada fica fora de alcance): título, o escopo no subtítulo ("This clip", "Whole take", "Applies to all 8 lines", "Only this title changes"), Reset quando faz sentido e o ✓ amarelo de 40 pt que aplica e fecha; tudo aparece ao vivo, os detalhes técnicos ficam em **Advanced**. ✓ fecha o painel, Done conclui a edição, Export gera o arquivo. **Speed** (0.5×–2×, "This clip · 00:21.6 → 00:14.4", com um clipe "Split at playhead to change one part"; Advanced: 0,25–4× e Keep voice pitch). **Zoom** (None · Push in · Pull out · Punch in, toca 2,5 s; Advanced: Intensity, até 1,3×). **Volume** 0–200% (clipe, com Mute this clip; música; voice-over). **Voice** (take inteira): Enhance voice e Reduce noise (Off / Soft / Strong) e Compare with original ("Original audio" na prévia). **Pauses** (`CleanUpCard`): pausas marcadas na trilha principal (hachurado amarelo = remover, cinza tracejado = manter; tocar alterna), "Pauses longer than" 0,3–3 s (0,7), cards com duração, tempo, Remove/Keep e Listen (1,2 s antes e depois; marcada, pula o trecho), "Filler words and retakes" do Clean Up no mesmo formato, e o rodapé fixo com o tempo economizado em amarelo, "00:21.6 → 00:17.5" e "Remove N pauses". **Captions** (`CaptionsPanel`): linha fixa com o switch, o idioma falado (lista em linha: Automatic + 15), Translate (lista em linha: Off + idiomas, "Translated on your iPhone with Apple Translation. Nothing is sent anywhere.", "Edit translations" abre a sheet com Both e escrever à mão) e Style branco; as linhas com tempos ("00:05.2 → 00:07.1 · 1.9s"); tocar leva o playhead e seleciona na timeline; **corrigir o texto de uma linha nunca muda o estilo** (o estilo é da coleção, a linha mantém identidade, tempos e destaque da palavra: as palavras trocadas ou acrescentadas dividem o trecho que a voz gastou nas que substituem, e só uma palavra sem trecho nenhum vira estimativa e pede revisão; mover ou apertar uma linha dobra as palavras para dentro do novo tempo); durante o play a atual fica amarela e a lista a acompanha; a selecionada abre com o campo de borda amarela, Start e End −/+ (0,1 s, sem passar das vizinhas, levando o playhead), Play · Split · Join next · lixeira; "Add a line at the playhead" só num intervalo livre ≥ 0,3 s. **Auto captions**: idioma falado (Auto + 15) e "Generate captions" amarelo; sem fala, "Write them myself". **Caption style** (sempre global): Presets (a coleção Cue / Impacto / Clean / Pop / Editorial), Reveal (Line · Fade · Words · Highlight · Box; tocar toca a linha atual), Position (Top / Middle / Bottom e Size 12–28 pt) e Font (cor do destaque; com o visual de um texto, família, peso e cor). **Text style** (`TextStylePanel`): campo no topo (com o teclado ao criar), escopo explícito "This title" · "All texts · N" · "+ Captions" e as abas Presets (Save as my style, My style e os 8 `TypePreset`), Font (família em chips na própria fonte, peso, 12–56 pt), Color (texto; fundo None / Box / Pill e a cor; sombra None / Soft / Outline) e Motion (◀ Add/Remove keyframe ▶, Starts e Ends −/+); losangos brancos marcam os keyframes na faixa. **Cover**: Frame from video / Photo, faixa de miniaturas com o quadro branco arrastável, "Title on the cover" no preset Cue, Reset tira a capa; a prévia mostra a capa. **Adjust** (Reset; **uma fileira de dials** — Exposure, Contrast, Warmth, Saturation, Highlights, Shadows, Sharpness —, cada um com seu valor: anel branco e fundo branco no escolhido, amarelo fora de zero; embaixo "Exposure +10" com o Reset do ajuste e o **Auto** no outro extremo da mesma linha, e **uma régua** de 40 passos com o trilho amarelo a partir do centro e a alça branca de 28 pt; sem Advanced). **Filters** (Original · Vivid · Warm · Cool · Mono · Fade em miniaturas reais e Intensity). **Crop** (9:16 · 4:5 · 1:1 · 16:9 e Fill / Fit). **Background** (Original · Blur · Color · Image; Advanced: força do blur e Color key com Green / Blue screen, cor à mão, Tolerance, Edge e Spill). **Voice-over** (um botão de 72 pt: o círculo vira quadrado; grava do playhead com o vídeo mudo; a faixa cresce em vermelho e vira um item laranja). **Media** (selecionada: Full screen / Window, formato e tamanho, ordem; Advanced: som do vídeo e keyframes). **Transition** (None · Dissolve · Fade · Slide e "Use on every cut"). **Sheets:** Add music (Files, "Use only music you own or have the rights to — songs from Apple Music can't be added.", entra a 40% sob a voz), Add photo or video (Fotos em linha: On top of video / Insert as clip) e **Export** (`QuickEditExportSheet`): miniatura, "Take 3 · 00:21.6", "9:16 · captions and text burned in", Resolution 720p / 1080p / 4K e Frame rate 30 / 60 (nunca acima da gravação: o que não dá fica apagado com o motivo), tamanho estimado, exportações grátis restantes, "Export video"; progresso real ("Exporting · keep Cue open"); "Saved to Photos" + Done / Share. A capa vai para o Fotos junto. **Rascunho:** a edição, o playhead e o histórico ficam guardados enquanto edita ("Draft restored" ao voltar); Done salva na take e reabre exatamente igual. |
| Takes | `Screens/Takes` | "Takes" + "N takes · N videos"; chips de plataforma e All takes / ★ Best / Not shared / Edited; seções Today / Yesterday / Earlier; cada linha é um vídeo (takes do mesmo roteiro): miniatura no formato certo com estrela e duração, plataforma · formato · qualidade, quando, chips "3 takes · Best: Take 3", "Edited", "Not shared" |
| Profile | `Screens/Profile` | Card do criador ("@handle · Signed in with Apple") + botão Sign in with Apple quando fora; Creator Voice: "Sounds like you" (frase ao vivo + "Use my voice in AI scripts"), How I sound, My phrases, My vocabulary, My style, Niche (tudo grátis); **Creator preferences** (Default "Create for", Monetization goals); plano ("Free plan · Every feature included", "Free exports · 3 of 5 left", Apple Intelligence ilimitada, "Try Pro free for 7 days"; no Pro, "Cue Pro · Annual · renews…", "Unlimited exports, up to 4K", Manage); Sign out |
| Settings | `Screens/Settings` | Mesma lista insetGrouped, fundo `Palette.bg`, superfícies, título grande e componentes do Profile. Language & Region (resumo do idioma); **Creator Setup** (mesma linha "Recording, teleprompter & remote", resumo salvo e footer); Privacy & AI data (mesma sheet); Restore purchases (mesma ação do StoreManager); **Acknowledgements** (as fontes do app e o texto da licença SIL OFL 1.1 de cada uma). Não inicia câmera, microfone ou pareamento ao abrir |
| Language & Region | `Screens/Settings/LanguageRegion` | Três linhas separadas, cada uma com sua explicação embaixo: **App Language** ("Controls the language of Cue’s interface."; iPhone Language + os 15 idiomas pelo nome nativo e, embaixo, no idioma da interface; muda a interface na hora e fica nesta tela), **Voice Following Language** ("Controls the language Cue listens for while you speak."; Same as Script + os 15, cada um com "Ready on this iPhone", "Downloads the first time you use it" ou "Not available on this iPhone" em laranja; um indisponível ainda pode ser escolhido, e o prompter avisa e rola na velocidade definida enquanto você fala) e **Script Language** (Auto-detect + os 15; é o idioma dos roteiros novos, e cada roteiro tem o seu em ••• › Script Language). Nenhuma muda a outra nem traduz nada (`LOCALIZATION.md`) |
| Creator Setup | `Screens/CreatorSetup` | Opcional (um criador novo grava sem abrir). Card "This is what you usually use." + como as recomendações funcionam; **Recording**: Camera (Front / Back), Microphone (abre a lista: Automatic, as entradas conectadas e a salva quando não está conectada, com "pair it in Settings › Bluetooth"), Recording quality (720p / 1080p / 4K e 24 / 30 / 60 fps), Default format (9:16, 4:5, 1:1, 16:9); **Teleprompter**: Text size (Small / Medium / Large + slider 16–56), Scroll speed (0,3–2,0× e "about N words a minute"), Reading line (↑/↓ de 8 pt a partir de 118 pt da lente, Reset), Show reading line, Mirror text, Safe zones, Voice Following / Steady e **Display** (abre os mesmos controles Aa, sem câmera/áudio: Selfie com altura/largura da janela, ocultar controles, opacidade/desfoque; Studio com posição relativa da linha e cor de fundo; ambos com AI Coach, fonte, espaçamento, margens, alinhamento e cor; margens da safe zone Custom em %). Tamanho, visibilidade da linha e espelho continuam só na seção original; **Remote Control**: Connect a Device (abre a página), Connected device, Remote status; **Reset Creator Setup** (tinto vermelho) com confirmação ("…Your scripts, takes and edits stay.") |
| Remote Control | `Screens/RemoteControl/RemoteControlView` | "Control your teleprompter from another device."; **Connect a Device** (`RemotePairingPanel`: botão amarelo → QR code 200 pt + código "ABC 234" + "Waiting for your other device…" + Cancel → "Remote Connected" com ✓ verde, o nome do aparelho e Disconnect; erro de rede local com Try again); **Use this device as a remote** (Enter a code → alerta); "Keyboards, foot pedals and presentation remotes are coming next." |
| Remote | `RemoteControllerView` | Tela cheia no outro aparelho (aberta pelo QR escaneado na Câmera, `cuestudio://remote?code=…`, ou pelo código digitado): fechar, "Remote" + ponto verde e o nome do teleprompter; card com o roteiro aberto, progresso, Playing / Paused / Recording e a velocidade (ou "Voice Following"); voltar ao topo, ‹‹, play/pause amarelo de 96 pt, ››; − velocidade +. Procurando: "Looking for the teleprompter…" + "Keep both devices close, with Wi-Fi on." A tela não apaga |
| Paywall | `Screens/Shared/Paywall` | Tela cheia, aberta só pelo Export (depois da 5ª exportação: "Keep posting with Cue") ou pelo Profile ("Create more. Sound like you."); benefícios (exportações ilimitadas até 4K, tudo continua aberto, as takes são suas); Annual (pré-selecionado, "SAVE 58%", "$3.33/mo · 7 days free") / Monthly ("7 days free · cancel anytime"); "Start 7-day free trial" com o que acontece depois; Restore, Terms, Privacy. Sem opção com marca d'água e sem vitalício. Nunca abre durante a gravação |

## 5. Navegação

Tab bar nativa, na ordem **Scripts → Takes → Profile → Settings → Record**. Settings usa
`gearshape`, imediatamente depois de Profile; Record mantém `RecordGlyph` e abre a sheet sem
mudar a aba selecionada. Materiais, transparência, cor e tamanhos continuam os nativos existentes.

```
RootView
└── MainView (TabView)
    ├── Scripts ─ NavigationStack ─ ScriptDetailView (leitura ⇄ edição)
    ├── Takes ─ NavigationStack
    ├── Profile ─ NavigationStack (identidade, voz, preferências criativas e plano)
    ├── Settings ─ NavigationStack (`settingsPath`) ─ Creator Setup ─ Remote Control
    │                                              ├─ Language & Region ─ App / Voice Following / Script Language
    │                                              └─ Acknowledgements ─ licença de cada fonte
    └── Record (aba-botão; abre "Start recording" sem trocar de aba)
Sheets (sobre as abas): New script (+) · Start recording · Import · Generate (Prompt | Themes | Formats)
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
  `edit.captionStart.minus/plus`, `edit.captionEnd.minus/plus`; Export `edit.export.*`. Sliders são
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
- Toasts são anunciados (`AccessibilityNotification.Announcement`).
- Alvos de toque de 44×44 mesmo quando o visual é menor.
- **Contraste** (Human Interface Guidelines › Accessibility, que pede 4,5:1 para texto e 3:1 para o
  que identifica um controle): vale nos dois modos, claro e escuro, e com **Increase Contrast** ligado.
  `ColorContrast` mede (luminância relativa, composição de cores translúcidas) e
  `PaletteContrastTests` falha se um token sair do mínimo: `ink`, `ink2` e os textos coloridos
  (`accText`, `warnText`, `dangerText`, `infoText`, `successText`) em `bg`, `surface` e `surface2`;
  `ink` e `ink2` também em `surface3`; os textos coloridos sobre o próprio `…Soft`; os rótulos sobre
  os preenchimentos vivos (`accInk` sobre `acc` e `warn`, branco sobre `dangerFill`); `ink3` a 3:1 em
  toda superfície. **Regras:** (1) `acc`, `warn`, `danger`, `info` e `success` são preenchimentos e
  pontos; texto e ícone usam o token `…Text` (no claro o amarelo vira ouro escuro; sobre o branco o
  `acc` dá 1,5:1); (2) `ink3` nunca é frase: é chevron, contorno tracejado, anel, desligado; texto
  terciário usa `ink2`; (3) nada de `Color.white`/`.black` solto em tela que muda de aparência: use
  `ink`/`bg`; (4) cor nunca é o único sinal (a faixa de duração diz o texto, o selecionado muda de
  peso e preenchimento); (5) `Color(light:dark:lightIncreasedContrast:darkIncreasedContrast:)` dá a cada
  token translúcido um degrau mais forte com Increase Contrast (`ink2` 60% → 78%, `ink3` 45% → 62%,
  `separator`). **Câmera, prompter, revisão da take e editor** (`.videoContext()`) ficam escuros em
  qualquer aparência: são vistos sobre vídeo, e os tokens dinâmicos resolvem para o escuro dentro
  deles. O app continua só em modo escuro (`UIUserInterfaceStyle = Dark`); quando o travamento sair,
  estes testes e as regras acima são o que impede uma tela amarela sobre branco.
- Identificadores para UI tests: `"<tela>.<elemento>"` (ex.: `hero.recordButton`, `editor.doneButton`).

## 9. Diferenças em relação ao protótipo

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
    o catálogo principal tem somente **Cue, Impacto, Clean, Pop e Editorial**, em faixa horizontal
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
    em `Options.window.start` (o player passa a janela, e com música mudar as pontas reconstrói a
    prévia depois de 0,25 s). O volume ao longo do tempo é um envelope (`MusicEnvelope`): fades
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
  `RemoteCommand`. No Selfie o acesso rápido fica em "This take" (a barra não tem espaço para mais um
  botão); no Studio, um botão ao lado do espelhar.

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
  15 idiomas (inglês, espanhol, português do Brasil, francês, alemão, italiano, japonês, coreano,
  chinês simplificado, hindi, indonésio, árabe, turco, tailandês, vietnamita), escolhidos em
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
- **Luz do Prompt:** o mesmo `PromptCard` (home, biblioteca vazia e New script) mantém layout, campo,
  borda e máscara de 26 pt. `AnimatedPromptBackground` combina a base original com duas luzes
  radiais `#FFD60A` e uma sombra difusa, blur de 12 pt só no fundo e origens em ciclos de 16 e 19 s.
  A luz principal percorre 48% da largura, com raio de 65% do lado maior; a sombra móvel marca a
  passagem da luz sem aumentar a saturação. O wash fixo fica mais fraco para não esconder o movimento.
  O efeito tem maior contraste: amarelo da marca com opacidade de 34% na luz principal e 13% na
  secundária, contraposto à sombra preta móvel de 38%. A cápsula escura do campo permanece igual.
  Um `TimelineView` limitado a 24 atualizações/s redesenha apenas o fundo; pausa sem saltar ao
  retomar quando fora da área visível, em aba/tela encoberta ou com o app inativo. Reduce Motion
  usa uma composição estática. O fundo não recebe toques nem aparece no VoiceOver; texto, botão,
  cápsula escura e tokens de contraste permanecem os mesmos. O app continua só em modo escuro.
- **Estrelas do Prompt:** os três `sparkle` ao lado do título mantêm posições e forma fixas. Uma
  estrela por vez faz um twinkle curto e irregular com escala, brilho, núcleo branco e glow dourado.
  A sequência repete em 21 s, com os intervalos entre inícios 30% menores e a duração de cada brilho
  preservada (0,8–1,25 s), sem sobreposição;
  a animação usa o mesmo relógio pausável do fundo, não afeta os demais elementos do card e fica
  estática com Reduce Motion.
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
  15 idiomas e entram no texto na língua da interface (`[pausa]`, `[間]`), como o `LOCALIZATION.md`
  pede; (5) o rodapé "4 of 5 free AI edits left" não existe (a IA é grátis e ilimitada); (6) em vez de
  Cancel, **Discard changes** (Options) devolve o roteiro como era; (7) o título do formato sem tipo é
  "Talking video"; (8) o texto de leitura e a escrita escalam com o Dynamic Type; (9) uma ferramenta da
  Improve script, na leitura, salva o texto na hora (como o protótipo) e abre uma versão nova quando já
  há takes, o que o protótipo não mostra.
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
  - **Auto captions:** o idioma falado tem os 15 idiomas do app (o protótipo mostra 4).
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
  (mantendo resolução e fps), porque o mergulho no som, o recorte do frame e o Enhance voice (Soft
  por padrão) precisam de uma nova codificação. Um rascunho guarda a edição, o playhead e o histórico enquanto a tela está
  aberta (e ao sair do app); ao voltar, "Draft restored". O relógio usa `DurationText.timecode`
  (00:04.32 abaixo de 10 min, 00:12:04 a partir de 10 min). "Enhance voice" e
  "Reduce noise" são aproximações com EQ e dinâmica no `AVAudioEngine` (não há API da
  Apple de redução de ruído para arquivo; ver "Som do projeto"). Os filtros usam Core Image e ficam próximos, não
  idênticos, aos do protótipo. As legendas vêm da fala (`SpeechAnalyzer`, no aparelho), com
  ou sem roteiro: o áudio decide o que foi dito e quando; o roteiro só empresta grafia e pontuação
  onde a correspondência é confiável (`CaptionBuilder`, `WordAlignment`: a mesma palavra numa sequência
  de 2+ ou com 5+ letras), então números, negações, improvisos e repetições ficam como foram ditos.
  Sem áudio, sem fala ou sem modelo para o idioma, o app diz por quê e nunca distribui o roteiro pela
  duração. A transcrição original fica guardada à parte (`CaptionTranscript`); cada linha tem
  identidade, palavras com tempo (marcadas como estimadas quando o reconhecedor deu um trecho a
  várias palavras ou quando uma correção as criou) e "Check timing" quando o tempo precisa de revisão
  (`CaptionRevision`). Cortes mostram só as palavras que ficaram. Legendas entram no desfazer.
- **Takes sem roteiro:** o protótipo marca gravações freestyle como Reels; aqui elas aparecem como
  "Freestyle" (sem plataforma) e cada uma é um vídeo próprio.
- **Take:** o arquivo é guardado pelo nome (`fileName`), não por URL, porque o caminho do container
  muda entre instalações; `recordedAt` é o "createdAt" do pedido.
- **Filtros de plataforma:** como no protótipo, All + TikTok, Reels, Shorts, YouTube e LinkedIn;
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
