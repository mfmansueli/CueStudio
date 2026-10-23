# Cue Studio — Design (v30)

Este arquivo diz **como o app está hoje** e as decisões do dono que divergem do quadro, tela por tela. Fonte do design: `design/cue-v30/handoff-telas/`
(`LEIA-ME.md`, `docs/09-Decisions.md`, que vale mais que os outros; `ANIMACOES.md` e `docs/motion-README.md` para o movimento; `screens/*.html` para o
visual). Pacotes antigos só no git (commit `bb39f35`). **Como manter:** ao mudar uma tela, reescreva a seção dela no estado atual; o que saiu do app sai
daqui (o histórico fica no git). Os números das seções são citados no código: não renumere.

O app é **só iPhone** no lançamento (`TARGETED_DEVICE_FAMILY = 1`, retrato, sem o Mac "Designed for iPad"; decisão do dono, 23/10/2026: o iPad vem
depois; num iPad ele roda no modo de compatibilidade de iPhone). O app é **só escuro**. Regras de negócio: 5 exportações grátis (contador no Keychain), 7 dias de teste, preço da StoreKit, cota de IA, pipeline das
takes (`TakeStage`). **Movimento:** o Modo de Baixo Consumo não tira nem encurta nenhuma animação (decisão do dono, 6/10/2026; a regra do `09` §7 foi
removida); só o **Reduzir Movimento** mostra o estado final. `speed` só serve para encurtar nos testes de UI.

## 1. Nativo primeiro (`07-Liquid-Glass.md`)

| Onde | Como é |
|---|---|
| Tab bar | `TabView` do sistema, `.tabBarMinimizeBehavior(.never)` (decisão do criador; o `07` §1 pedia `.onScrollDown`); Record é aba normal no meio (`09` §4), nunca `role: .search` |
| Barras de navegação | `NavigationStack` + `.toolbar` em Scripts, Takes, Profile, Settings, página do script, revisão da take, Quick edit, gravador, Pro. Scripts: só Logbook e + na barra; a busca é um campo na lista (§2) |
| Sheets | `cueSheetChrome()`: `NavigationStack`, `Button(role: .close)` à esquerda, fundo `Palette.sheetNight`, raio `Metrics.sheetRadius`; as que têm navegação própria usam `cueSheetSurface()`. `fittedSheet()` soma `Metrics.sheetBarHeight`. `SheetHeader` é só título e subtítulo |
| Botões | `CueStudioButtonStyle`: primário (amarelo) e secundário em Liquid Glass (`.glassEffect(.regular.tint(acc).interactive())`); `.glass` sobre vídeo |
| Controles | `Menu`, `Picker` (`.segmented` em Selfie \| Studio, Voice \| Steady, List \| Grid, Camera \| Recording), `.contextMenu`, `Slider` do sistema (`LabeledSlider`), botões redondos `.glass` (`glassIconButton()`) |

**Vidro customizado (exceções do `07` §2):** o dock de Scripts (`DockSurface`), a barra e as folhas sobre a câmera (`GlassNight`, precisam ler sobre
vídeo), os painéis e a barra do editor, a barra de IA sobre uma seleção (o menu de edição do `UITextView` não
reproduz a pílula violeta), o toast e a dica do My Cue Voice (`VoiceTipViewStyle`). Confirmações destrutivas: `CueActionSheet` (§17).

## 2. Scripts (3.1, 3.2) — o dock

`Screens/Scripts/Dock/ScriptsDock.swift`: vidro limpo (sem céu dentro, `09` §2), em `.safeAreaInset(.bottom)` acima da tab bar.
- **Linha 1:** Format ⌄ · For {Rede} ⌄ · ✦ Voz nn% · lâmpada do Find inspiration (§30). Chips de 36 pt de toque; aparecem também na primeira visita.
- **Linha 2:** o campo (2 linhas em repouso, até 5 editando, 200 caracteres: §25; a ideia sugerida enquanto vazio), ↻, microfone e a seta amarela
  (**Write it** sem Apple Intelligence ou com a Script Language num idioma que o modelo não escreve, com a nota do motivo: §8). Uma sugestão nova (↻, ou a seguinte depois de enviar) chega palavra por palavra saindo da luz violeta
  (`WordsFromLight`, 50 ms entre palavras; a que já estava quando Scripts abre só aparece); o ↻ é `arrow.triangle.2.circlepath` e gira a cada toque.
- **Luz do Apple Intelligence** (`AIGlow`, cores `dockGlow`; a mesma do microfone do Logbook): borda fina colorida girando em volta do vidro, com um halo
  desfocado fino que some a poucos pontos da borda (não chega aos textos; desenhado no tamanho do próprio dock, que não muda de altura). Ditando: fica, uma volta a cada 5 s, mais forte com a voz (`dictation.level`). Enviando: uma volta rápida junto
  com a subida da estrela (1,2 s). Reduzir Movimento: não gira, só acende e apaga.
- **Vibração** (`HapticPatterns`, Core Haptics; cai num toque simples sem Taptic Engine): enviar = toque firme + zumbido que cresce enquanto a
  estrela sobe (1,1 s) + toque na ignição; a estrela pousando como cursor = baque suave + dois brilhos (§3).
- **Dobra** (`DockFold`, `ScriptsView.foldDock`): a linha 1 recolhe ao rolar para baixo (passa de 40 pt e mais de 2 pt de movimento, somando passos
  pequenos), volta em qualquer subida, nunca com o campo focado; 0,28 s `(0.2,0.8,0.2,1)`, um movimento só (o vidro fecha sobre os chips, que somem em
  0,2 s). **O espaço reservado embaixo da lista não muda com a dobra**: quando mudava, a lista pulava ~205 pt e o dock abria e fechava sem parar. O quique
  no fim não conta como subida. Lista curta (rola < 80 pt) recolhe ao passar da metade; uma que rola < 16 pt nunca recolhe. Log: `studio.cue` / `DockFold`.
- Campo focado: a lista escurece e desfoca (0,25 s). Durante a seleção o dock sai.
- **Busca:** lupa na barra, no mesmo vidro do Logbook e do "+" (à esquerda deles; só com a lista, não no Scripts vazio). Ela abre o `SearchField` no
  topo da lista (entre "6 SCRIPTS · 1 READY" e os filtros, rola com ela), já com o teclado, e leva a lista ao topo; o campo some quando fica sem
  teclado e sem palavras (teclado fechado, ✕ ou "Clear search"); com palavras ele fica. O dock fica durante a busca e, com o teclado da busca, fica
  embaixo dele. Por que não `.searchable`: com `.searchToolbarBehavior(.minimize)` o ✕ do iOS 27 só minimizava a busca (a lista ficava filtrada e o
  dock não voltava). Dica do campo em `ink2`.
- **Filtros** (`PlatformFilterChips`): All, as redes que têm roteiros e as pastas. Segurar o chip de uma pasta (ou a ação do VoiceOver) mostra
  **Delete folder**: a pasta sai, os roteiros ficam (em All), e "Folder deleted" tem Undo por 4 s (volta no mesmo lugar, com os seus roteiros).
- **Linhas:** um toque abre a página do roteiro em qualquer estado (rascunho já abre escrevendo); a ponta direita é a ação do estado: **● REC** grava,
  **Continue ›** é só rótulo, **×3 ›** (com takes) é botão para Takes. Deslizar mostra **Record** (vermelho) e **More** (cinza), sem deslize longo; More abre
  `ScriptActionsPopover` na linha (Record, Studio mode, Edit · Duplicate, Move to folder, Script Language, Share · Delete); o que abre outra coisa fecha
  o menu primeiro.
- **Select** (no cabeçalho do primeiro grupo; vira **Done**): cada linha mostra a sua marca **dentro do card**, 16 pt da borda e centrada na altura
  (`ScriptSelectionMark`: anel `ink2` ou o círculo amarelo com ✓, 22 pt), no lugar da ação do estado; um toque na linha marca ou desmarca (não abre o
  roteiro), sem deslize. Não usa o modo de edição da `List`: o sistema punha o círculo na borda do card. A barra de seleção substitui o dock e a tab bar.
- Abaixo da lista: **Logbook · n waiting** (`ScriptsLogbookSection`, até 2 ideias com ✦ Write e "Open Logbook ›"). Carregando: `ScriptRowSkeleton`
  (`SkeletonShine`, 1,4 s). Vazio: §30 e §32.
- **Folhas da linha 1:** Format, For {Rede}, ✦ Voz e a lâmpada abrem todas em tela inteira (`.large`, sem meia altura).
- **Formatos (`09` §1):** grade de 9 (Auto · Talking head · Tutorial · Storytime · List / tips · Review · Myth vs fact · POV · Sponsored ad, com o selo
  "needs brand info" numa linha própria) e **More formats** com os `ScriptType` que a grade não mostra. *Talking head* = sem `ScriptType`.

## 3. A estrela é a transição (`09` §8)

`IdeaTransitionService` (relógio e estado) + `StarTransitionOverlay` (em `MainView`) + `ScriptStarter.write(from:)`: a estrela sobe da seta ao centro
(**1,1 s**, mais lento que o quadro por decisão do dono: os efeitos têm de ser vistos e o roteiro é escrito por trás) enquanto 34 pontos de luz saem do
campo do dock, um após o outro (0,7 s), e correm em curva até ela (1 s cada); ela **acende** onde para (clarão e anel de luz, 1,1 s); o app atrás
escurece (brilho −0,4, saturação 0,7, desfoque 10 pt, escala 0,94), halo, 12 partículas, "Writing in your voice", a ideia e 7 frases a cada 1,6 s, a porcentagem e,
em volta da estrela, uma **órbita de progresso** (`ProgressOrbit`, cores `dockGlow`, que fecha com a porcentagem), Cancel. Dura **no mínimo 3,0 s**;
quando o roteiro chega: frase final, capa sólida (0,3 s), anel (0,8 s) com uma faixa de luz descendo pela página (1,4 s, `transitionSweep`), a estrela
voa até o cursor amarelo onde começa o título deixando um **rastro de cometa** (`CometTrail`, 0,9 s) e a página escreve (§5.2). **Vibração:** a
decolagem do dock (zumbido que cresce na subida, toque na ignição), um toque leve a cada 25% escrito, o pouso (baque + dois brilhos) quando a estrela
vira cursor, um toque suave no Cancel. O teclado desce quando a estrela sobe e a página não o pede de volta. **Cancel ou erro:** a estrela
cai 40 pt e some (0,3 s), nenhum roteiro fica, a ideia continua no campo (erro: toast "Couldn’t draft it · Try again"). Reduzir Movimento: fade de 0,2 s.
Sem Apple Intelligence não há overlay. Idioma que o modelo não escreve: a estrela nem sai, nada abre e o toast diz por quê (§8). Scripts
mostra só o céu de fundo (`skyBackground()`), nada desenha estrelas por cima.

**Porcentagem escrita** (pedido do dono, não está no quadro): linha mono `ink2` sob a frase (`WritingProgressLabel`), estimada por `WritingProgressEstimate`
a partir dos eventos do roteirista (`ScriptWritingEvent`, `WritingProgressMeter`): até 5% em 2 s antes das primeiras palavras; o primeiro rascunho vai de
5% a no máximo 85% pelas palavras contra o mínimo pedido (desacelera depois de 3/4); cada rodada a mais preenche 60% do que falta até 95%. **Só o
roteiro pronto é 100%, e o número nunca volta.** O lugar da linha é guardado desde o início. `numericText`; VoiceOver "Written so far". Contraste em
`PaletteContrastTests.theStarsWordsReadOverItsCoverOnAnyScreen`; ideia e Cancel usam `Palette.Scripts.transitionInk`. O primeiro roteiro do onboarding
não mostra número. Teste: `-uiTestWriterStalls`.

## 4. My Cue Voice

- **Dados** (`CreatorProfile`, tudo opcional, `decodeIfPresent`, `currentVoiceSchema = 2`): papel (8 + `customRole`), `credential`, `speaksAs` (I / We),
  temas (`Niche` + `voiceTopics`, os 15 só do My Cue Voice, fora de `Niche` para não virarem mundos no universo; `topicDetails` até 3 por tema),
  público (`audienceGroup` ou `audienceNote`, `audienceLevel`), `watchReasons` e `contentGoals` (até 2), 8 tons, `style` (energia, frases, palavras,
  palavrão), `avoid`/`avoidNone`, `reach`, `approvedSamples` (até 3), `customTags`, e da importação (§4.2) `excerpts` e `fingerprint`. O que o criador
  digitou nunca é reescrito.
- **Força** (`voiceStrength`): Essentials 40 · Personality 40 · Proof 20, pesos por campo em `VoiceField`; duas aprovações = um exemplo; 4/8/12 trechos
  importados = 1/2/3 exemplos.
- **Um editor só** (`VoiceEditorSheet` + `Screens/Profile/Voice/Editor/*`): a página, as 4 perguntas, a dica do dock e Settings abrem o mesmo campo; toda
  escrita passa por `CreatorProfileService+VoiceAnswers/+VoiceDetails/+Personality`. 25 temas, 7 subtemas sugeridos por tema, 11 formatos, 7 aberturas,
  6 fechos, 9 itens de Avoid. As listas de escolha usam os 10 temas do primeiro voo (`Niche.offered`, `chipLabel`) e mantêm um tema antigo que a pessoa
  já tem.
- **Página 9.3** (`MyCueVoicePage`): um cartão (✦ WHAT CUE USES com a chave, medidor, "Next: …" com Answer), depois ESSENTIALS (I am · Topics ·
  Audience · They watch to · Voice), PERSONALITY (Style · Usual formats · Opens with · Ends with · Videos are for · My phrases · Avoid · Reach) e
  PROOF (Examples), linhas de 52 pt (rótulo cinza, valor à direita ou "+ Add · 1 tap" em amarelo). Rodapé: **Preview** (`VoicePreviewSheet`: "✦ LIVE
  PREVIEW", My voice | Without, "Sounds like me", interruptor "Write in my voice") e **What Cue sends** (`VoiceSendsSheet`, mostra o custo do prompt).
  Não há botão de zerar a voz; "Delete my Cue data" apaga o perfil e zera as perguntas (`VoiceQuestionScheduler.reset()`), como numa instalação nova.
- **Quando perguntar** (`VoiceQuestion`, 17 perguntas; `VoiceQuestionScheduler` com relógio injetável, `VoiceQuestionState`): depois de 2 dias de uso e
  1 roteiro, 1 dica por dia e 3 por semana; "Not now" adia 3 dias, 2 dispensas mandam a pergunta para o fim, 3 seguidas pausam 14 dias, "None of
  these" pula para sempre, para em 100% (toast). Gatilhos: 1ª exportação, 2ª edição de um roteiro na voz, 3º roteiro gravado. A dica (`VoiceQuestionTip`
  no TipKit, `VoiceTipViewStyle`) fica 10 pt acima do dock ou da tab bar e espera enquanto a primeira viagem (§32) tem uma dica. `VoiceQuestionSheet`:
  lista agrupada, "+ Something else", "None of these", "Saved · voice nn%", "One more question" (no máximo 3 seguidas).
- **Setup de 4 perguntas** (2.1–2.4): a audiência pergunta também o nível; o último passo tem "Add a voice example". "Talking head" é guardado como tag;
  "Reaction" é o formato Hot take / reply.

### 4.1 My Cue Voice → Apple Intelligence

- **O prompt** (`Managers/ScriptAI/Voice/*`, `Context/*`): `VoiceBriefBuilder` monta, em inglês e nesta ordem, quem fala → para quem e por quê → temas →
  como soa → como abre e fecha → exemplos → regras, e repete no fim as que não podem falhar ("Remember: …"; o modelo pequeno atende mais ao fim).
  `FormatGuide` diz para que serve cada bloco, `PlatformGuide` dá o registro (LinkedIn sem gíria). Regra de honestidade: nada de história, número, cliente
  ou credencial inventados. Qualquer resposta de Essentials já liga a voz (`canWriteInMyVoice`). Tudo que o criador digita chega ao modelo
  (`VoiceTypedValuesTests`; bordões três por vez; o resto em "Also true of them, in their own words").
- **A ideia manda no assunto, a voz só no jeito** (`IdeaFocus`, `CreatorProfile.voice(inLanguage:idea:)`): temas só vão ao modelo quando a ideia fala
  deles (mesma palavra ou mesmo começo de 5 letras), subtemas só quando a ideia os nomeia; ideia de menos de duas palavras leva todos. O prompt diz "Write
  about this idea and only this one" e termina em "Stay on the idea: …". (Antes um subtema do perfil virava o assunto do roteiro.)
- **Depois do roteiro** (`VoiceConstraintChecker`, `VoiceCheckedWriting`): palavra proibida, "eu"/"nós" trocado (en/pt/es), bordão como primeira frase,
  nome do estilo de abertura escrito, emoji. Se quebrou, o roteiro é escrito **uma** vez mais dizendo a regra. **Qual fica** (`RevisionChoice`,
  `DraftAssessment`): o segundo só substitui o primeiro se o que quebra for **menos grave** (`VoiceViolation.Kind.severity`: palavra proibida 3; eu/nós,
  emoji, nome do estilo 2; bordão cedo 1; o que é só contado 0) **e** não perdeu nada: a frase de abertura do brief, ≥ 80% da cobertura do ângulo (ou da
  ideia), ≥ 75% das palavras, o fim da última frase, e não repete mais (+8% de trigramas). Igual número de violações não basta. Roteiro curto e o desvio da `VoiceFingerprint` são **soft** (`VoiceViolation.isSoft`): nunca causam segunda tentativa sozinhos (custa ~20 s e
  reescrever "mais longo" não alonga). Guardrail recusando o que o criador digitou: uma tentativa só com o que o Cue oferece (`catalogOnly`).
- **Tempo:** `GenerationDeadlines` corta o que nunca responde (`ScriptAIError.timedOut`), "Still drafting · taking a little longer" aparece depois de um
  tempo, e trabalho de fundo no mesmo modelo (`TopicTaggingService`, pré-busca de ideias: `IdeaRequestPriority`) sai da frente de um pedido do criador.
- **Comprimento** (`PlatformRules.json` revisão ≥ 3 — `PlatformRulesService` só aceita revisão mais nova; `ScriptRequestFactory`, `ScriptLength`,
  `preset.idealRange` como fonte única): TikTok e Reels 30–90 s, Stories 15–30 s; Auto usa o comprimento habitual do criador (nunca abaixo de 25 s,
  `spokenFloor`). O modelo escreve menos do que se pede: pede-se 1,5× as palavras e "pelo menos N frases por bloco" (`ScriptPromptBuilder.lengthRule`),
  e blocos curtos são alongados um a um quando o roteiro tem < 70% do mínimo (`ScriptExpansion`, `expandingIfShort`; um roteiro num bloco só vale com
  70%, `rescued`). **Vídeo curto não é esticado:** mínimo até 200 palavras (`shortFormWords`) é pedido como é, sem regra de frases nem alongar, e nunca
  mais que 300 (`shortFormCeiling`); YouTube longo é pedido como é. Cues repetidos 3+ vezes viram um (`collapsingRepeatedCues`).
- **Orçamento do prompt** (`VoiceBrief.budget`, `PromptCost`): janela de 4096 tokens no aparelho. O orçamento é em "caracteres de inglês" (pesos por
  escrita em `PromptCostTests`), **2100** (≈ 640 tokens). Corta nesta ordem: exemplos, tags, onde posta; os itens digitados pelo criador saem por último.
  **A janela inteira** (`Context/ContextBudget`, `PromptMeasuring`, `OnDeviceMeasure`): instruções + prompt + estrutura da resposta (`tokenCount(for:)`
  do próprio modelo) + o teto da resposta (`responseTokens`) + 120 de margem. Estimativa abaixo de 75% da janela vai como está (sem contar); perto da
  borda, o pedido é contado e a voz desce de orçamento (1400, 900, 500, 0: exemplos, alcance, tags) até caber; idioma, ideia, ângulo, frase de abertura,
  fatos da marca e regras da voz nunca saem. Só a rota do aparelho é contada (`AIModelRoute`; a nuvem traria a própria contagem). Medido no iPhone 15 Pro:
  pedidos de 690 a 1360 tokens (estrutura `ScriptDraft` 271), contar leva 85–390 ms, por isso só perto da borda.
- **Exemplos** (`VoiceBriefBuilder.examples`, `ExcerptRetriever`, `CreatorProfile.voice(inLanguage:idea:)`): até 3, nesta ordem: o roteiro aprovado mais
  recente ("Sounds like me"), os trechos importados, os colados, os aprovados antigos. Um exemplo ou trecho **sobre o assunto da ideia** (duas palavras da
  ideia) vai para o fim: era copiado, não imitado. O cabeçalho diz "never reuse these sentences, facts or stories". **Em aberto (dono):** quem tem bordão de
  saudação ("Fala, galera!") e escolheu outra abertura recebe o bordão primeiro em 2 de 3 roteiros, mesmo depois da segunda tentativa: os exemplos dele
  abrem assim; tirar o bordão dos exemplos não mudou nada. **Decidido:** bordão curto (até 3 palavras, uma saudação) dito primeiro é contado mas não
  pede segunda tentativa (`VoiceViolation.countedOnly`): reescrever tirou-o em 2 de ~13 vezes, custando ~10 s cada.
- **Progressão** (`Quality/ScriptProgressionCheck`): bloco que repete outro (≥ 35% dos trigramas), frase dita duas vezes e contagem prometida não cumprida
  ("5 passos", contando frases que começam com primeiro/depois/por fim…; en/pt/es) são **contados** (`GeneratedScript.progressionDefects`), nunca
  reparados: reescrever o bloco no iPhone encheu-o de "Depois, …" vazios. Frase repetida palavra por palavra num roteiro do modelo sai depois da primeira
  (`collapsingRepeatedSentences`; nunca nas reescritas, o criador pode repetir de propósito). **Falha conhecida:** ideia do Find inspiration com meia voz
  ou completa voltava só com o bloco de abertura em 11 de 54 pedidos (~20%, ~50 s e erro para o criador). **Corrigido** (`ScriptPromptBuilder.videoText`):
  o ângulo e a frase de abertura iam duas vezes (no texto "Angle: … / Open with: …" e como regras); agora só como regras, e o texto leva o título e o que
  o criador acrescentou. Medido: 1 de 27 (4%), 10,7 s em média contra 19,9, mesmo comprimento, frase de abertura respeitada em 26 de 26.
- **Abertura sem muleta** (`hookRule`, `forbidsFillerOpening`): as primeiras palavras já são o assunto (afirmação, pergunta ou número), nunca saudação ou
  "olha só"/"hey"/"so". Sem voz, 6 de 9 roteiros abriam com muleta; com a regra, 0 de 9, sem mudar comprimento (0,70 → 0,71 do mínimo) nem tempo; nos 16
  idiomas que o modelo do aparelho escreve, 10 de 32 → 0 de 31 (árabe, hindi, indonésio e tailandês: `unsupportedLanguage`, não validados). O bordão do criador continua no lugar que a voz manda. A regra de
  honestidade diz também "nunca diga que o criador fez, testou, descobriu ou foi salvo por algo" se a ideia não disser.
- **Comprimento de vídeo curto (limite conhecido):** sem voz completa o modelo escreve ~60–90 palavras (≈ 30 s) para um mínimo de 150 (1 min). Pedir
  "pontos concretos" em vez de palavras deixou o roteiro mais curto (metade do mínimo contra 0,7), cumpriu menos a promessa e inventou; saiu. É a quinta
  forma tentada (palavras ×1,5, frases por bloco, alongar bloco a bloco, pontos). **Decidido (dono delegou, 15/10/2026):** o alvo fica. O minuto vem da
  meta de monetização (TikTok Creator Rewards pede mais de 1 min, `PlatformRules.json` › `monetization`), ligada por padrão; baixar o alvo quebraria quem
  monetiza. Para chegar ao minuto existe **Fit to time** (cresce por partes, §23); o caminho para mais conteúdo numa passada é um modelo maior
  (Private Cloud Compute, já previsto em `AIModelRoute` e `PromptMeasuring`).
- **Aprendizado:** "Sounds like me" (`recordApproval`) guarda o começo do roteiro como exemplo (3, o mais antigo sai); edições gravadas também ensinam
  (§33). "Delete my Cue data" apaga tudo.
- **Qualidade medida** (iPhone 15 Pro, `ScriptQualityDeviceTests`: 3 criadores PT/EN/ES com voz completa, meia e sem, 27 roteiros e 18 lotes de ideias
  por rodada; textos em `Fixtures/ScriptQuality/`, números com `tools/quality/report.py`, lógica pura reaplicada aos textos em `QualityReplayTests`):
  nas 10 segundas tentativas lidas a escolha nunca ficou com o rascunho pior (a regra antiga trocou 3 de 3 na linha de base por um igual ou pior); aberturas de
  ideia começando pelo bordão 24/72 → 0/72; roteiro copiando frase do exemplo 1 → 0; um laço de frases repetidas (1 de 27) virou cada frase uma vez; tempo
  igual (14–16 s por roteiro, 10–11 s por lote); pedidos de 690–1360 tokens de 4096.
- **Medido** (iPhone 15 Pro, `VoicePersonaDeviceTests`, 14 criadores × 3 ideias; relatório em `build/reports/voice-report.txt`): nome do estilo como
  primeiras palavras 58% → 0%, bordão primeiro 36% → 0%, curtos 47% → 12%, abre como o criador escolheu 20% → 80%, média 105 → 147 palavras; o criador de
  finanças deixou de ser recusado. Ideia → roteiro sobre ela em 7–12 s (TikTok, 56–117 palavras), YouTube ~1600 palavras em ~73 s.

### 4.2 Import my writing

Na linha Examples (`VoiceExamplesField`), para quem já tem texto (roteiros, legendas, notas). Sem modelo treinado:
- **Entrada** (`WritingImportSheet`: `WritingImportCollectView`, `…ReadingView`, `…ReviewView`): colar (separados por `---`) ou abrir `.txt`, `.md`, `.rtf`,
  `.pdf` (`WritingFileReader`); "I wrote these myself" obrigatório. Roteiros da biblioteca **não** entram (podem ser da IA: aprender com ela é um ciclo).
  `WritingCleaner` tira Markdown, rótulos, pistas, links, contatos, @ e # (até 60 textos, 80 mil caracteres).
- **Medidas** (`WritingAnalyzer`, sem modelo): tamanho da frase, perguntas, exclamações, emoji, eu/nós, mediana de palavras → `VoiceFingerprint`. Com 3+
  textos (`PhraseMiner`, `WritingOpeningReader`): bordões, como abre e como fecha. Léxico en, pt, es, fr, de, it; ja/zh/th sem tamanho de frase.
- **Apple Intelligence só escolhe de listas** (`StyleReading`, `@Generable` + `.anyOf`): tom, temas, público, humor; **só o modelo do aparelho** (nunca
  Private Cloud Compute), limite de 40 s, só trechos ≤ 300 caracteres; sem modelo segue só com as medidas.
- **Revisão** ("Here's what Cue heard", `WritingFindingRow`): o que trocaria uma resposta do criador vem desligado com "Replaces: …"; listas só acrescentam.
  Nada é salvo antes de "Add to My Cue Voice" (`CreatorProfileService.apply`). Ficam até 24 trechos (`VoiceExcerpt`) e as medidas; os originais somem.
  No editor: "Imported from your writing · Excerpts: n", **Import more**, **Forget** (`clearImportedWriting`).
- **No pedido** (`ExcerptRetriever`, `ScriptRequestFactory.narrowed`): só trechos do idioma do roteiro, escolhidos por **variedade**, não por tema (arXiv
  2509.14543): 2 (abre e segue), um 3º (fecha) se sobra espaço, estáveis por ideia. As medidas viram até 2 regras curtas só para o que o criador não
  respondeu. Depois do roteiro, `VoiceFingerprintRules.drift` (frase 45% fora da média, exclamações) é soft.
- **Medido** (`WritingImportDeviceTests`): distância do tamanho de frase 0,73 → 0,28, 0,45 → 0,20, 0,40 → 0,24; bordão em 8 de 9 roteiros (antes 0).

## 5. O céu

`StarfieldMath`, `SkyDensity`, `StarfieldView`, `skyBackground()` (`BgWash` + `StarfieldView`; `SkyBackground`/`SkyBackdrop`). Todas as telas leem o
**relógio do app** (`StarfieldView.sinceLaunch()`, o mesmo do comet, da nave e do astronauta): trocar de aba não recomeça o céu. (Um céu só atrás do
`TabView` não funciona: o conteúdo das abas é opaco.) Settings › Personalize › Starry sky: **Off · Serene · Adrift · Interstellar**; **padrão Serene**
(valor ausente ou desconhecido vira Serene). Valores salvos antigos (`calm`, `lively`, `galactic`) continuam lidos (`SkyDensity.init(saved:)`).
- **Serene:** só as estrelas de fundo (3 camadas, deriva 260/160/85 s, cada camada balançando de lado no seu ritmo e cada bloco com estrelas próprias:
  §34) e 2 nebulosas (26 s).
- **Adrift:** o mesmo + 14 estrelas piscando de cerca de 7 s (cada uma no seu ritmo, §34) (1,2–2 pt, cruz de 5,5 pt de meia haste, menores que no quadro), o comet a cada 105–135 s (o
  primeiro aos 25 s) e o astronauta (§5.0.1).
- **Interstellar:** §5.0.
- Em Serene, Adrift e Interstellar as estrelas são mais delicadas (`StarfieldMath.delicateLook`: 65% de opacidade, as de fundo a 88% do tamanho); o céu
  do primeiro voo (`OnboardingSky`) usa os números do quadro (`boardLook`, 7 estrelas piscando e o comet, `twinkleCountOverride`).
- Reduzir Movimento: céu num quadro parado, sem nave nem astronauta.

## 5.0. Interstellar

"Deep Space" foi descartado porque é o nome de um ícone do app. Noite `Palette.Sky.interstellarBg` (`#030409`) com três luzes (`BgWash.interstellar`:
índigo, magenta, teal); telas com quadro próprio mantêm o próprio brilho. Três nebulosas (azul, magenta, teal; `interstellarNebulae`), uma Via Láctea
diagonal (24°, 150 pt, 5%, 70 grãos, ±18 pt em 90 s; `InterstellarSkyPainter`) e as estrelas do Adrift.
**A nave** (`SpaceshipPainter`, no lugar do comet) é **pequena, lenta e rara** (algo para achar, nunca algo que chama): 16–22 pt, casco facetado, asas delta
índigo com luz ciano, luzes de ponta de asa rosa e menta (2,8 s); rastro de 1,1 pt do azul ao violeta que segue o caminho feito (4,5 s, ≈ 125 pt).
Atravessa em 16–22 s num arco na metade de cima, a 90%; a primeira aos 90 s e depois a cada 4–7 min (`StarfieldMath.spaceship`).
Contraste: `ink`, `ink2`, `inkHint` passam 4,5:1 no ponto mais claro (`PaletteContrastTests`). Debug: `-uiTestCatalogue sky -uiTestSky interstellar`
("Send a spaceship").

## 5.0.1. O astronauta do Adrift

Só no Adrift: um astronauta flutuando e batendo de leve nas bordas.
- **Movimento** (`StarfieldMath.astronaut`, função do relógio e de uma semente): 7–10 pt/s em linha reta, quica nas quatro bordas
  (`StarfieldMath.bounce`), balanço de 4 pt (9 e 13 s), uma volta a cada 70–125 s, empurrão de giro em cada batida (1,5 s). Nunca sai da tela; fade de 4 s
  no início. Fica atrás de tudo.
- **Desenho** (`AstronautPainter`, 37,5 pt): traje branco opaco (`Palette.Sky.astronautSuit` → `astronautSuitShade`, mochila `astronautSuitDeep`), cordão
  solto, painel no peito (luz amarela e ciano que pulsa a cada 3 s), remendo amarelo; capacete com visor quadrado espelhado (índigo ao preto, dois
  reflexos, brilho em cruz, aro prateado). Close-up de 170 pt no catálogo; **Skip 30 s** avança o relógio.
- **Exceção de contraste aceita pelo dono para teste (rever):** o traje mede ≈ 1,1:1 contra `ink`/`ink2`/`inkHint`; só ocorre por segundos quando ele passa
  atrás de texto direto no céu.

## 5.1. Your universe (9.2) e o núcleo YOU

`Screens/Profile/Universe`. O núcleo é `UniverseSphere`: esfera de 38 pt na cor do núcleo (`CoreColor`: Gold, Amber, Sunrise, Rose; gradiente
`#FFFBEA → #FFE680 → #FFD60A → #B88A00`), 26 pt acima do meio do disco, respira 1 → 1,04 em 6 s com brilho de 58 pt, e dois anéis finos (−14° e 16°) com
uma bolinha cada (rosa 40 s, menta 31 s), a metade de trás atrás da bola. O mapa (`UniverseMap`, grade 358 × 320, visto em ângulo): brilho violeta,
elipses 70 × 43 e 122 × 80 (tracejada), **um ponto por vídeo** (1,9–2,9 pt, cor do tema, nítido e sem halo) no disco que gira em 140 s, rotas curvas
tracejadas até os planetas e a estrela **NEW** (pulsa em 2,6 s). Limpo e nítido, com poucos movimentos (pedido do dono, §36). Tudo para com Reduzir
Movimento e nos anos selados. **Toques:** núcleo → `UniverseCoreSheet`
(temas como anéis, marcos, **Core colour**, que tinge bola, brilho, card do Profile e o "Share my universe"); ponto → aquela take (procura o ponto mais
perto de onde ele está agora). Forma: a foto do protótipo animado que o dono mandou (o PNG e o HTML do handoff estão desatualizados). Catálogo:
`-uiTestCatalogue universe`. O núcleo de 44 pt do Profile é `UniverseCore .compact` / `ProfileMiniCore` (§13).

## 5.2. A IA escrevendo na página (4.1)

Enquanto o roteiro é escrito, `ArrivingText` substitui o editor: cada palavra entra de blur 7 pt e 5 pt abaixo em 0,3 s, com brilho violeta (`Palette.Page.arrivalGlow`
a 95%, some em 0,8 s), a cada 0,17 s (mais rápido quando chegam muitas, nunca > ~1 s atrás do modelo); cursor violeta de 2 pt pisca depois da última.
Pílula **"✦ Drafting in your voice"** (`ScriptWritingPill`, 34 pt): brilho de borda 2,4 s e brilho branco a cada 1,6 s; sem a estrela por cima (Try again)
mostra a porcentagem até as palavras chegarem. **A página escrevendo é a página escrita:** título, duração, faixa de estado (com **Stop** no lugar de
Shape), "Does it sound like you?" e o aviso de fatos (desabilitados) já no lugar, com as margens do editor (`ScriptTextEditor.textInsets`); nada se move
ao terminar. **Acabamento (pedido do dono, 20/10/2026):** o título chega primeiro, palavra por palavra (`WordsFromLight` sobre o campo), e o texto começa
0,45 s depois; a página rola sozinha (0,8 s, a cada ~160 caracteres) para manter as palavras novas à vista; no fim espera as últimas chegarem
(`ArrivingText.settleTime`, 1,3 s) e passa ao editor num fade cruzado de 0,7 s (as palavras que chegaram somem por cima enquanto o editor aparece por
baixo), com dois toques suaves; a pílula sai e o Record acorda num movimento só (0,5 s). Parar tira a pergunta da voz. Reduzir Movimento: fade de 0,2 s,
cursor aceso, pílula parada, sem espera nem fade cruzado. `-uiTestCatalogue writing`. A barra de 3 pt por
seção do quadro (`sc10`) não existe (a página não tem seções).

## 5.3. Onboarding: o roteiro de prática, permissões, tópicos, prática

(As telas 1.1–1.7 estão em §10 e §18.)
- **O roteiro da 1.4 é fixo** (decisão do dono, 15/10/2026; §35): o mesmo para todos, sem Apple Intelligence e sem espera; não há estado lento (1.4b).
- **Permissões** (`VoiceChapter`): cada linha é botão; sem resposta mostra **Allow** (a primeira em amarelo); negada mostra **Off · Turn on** e abre os
  Ajustes; voltar relê o estado. **Continue** pede o que faltar; com algo negado o rodapé diz "No problem, you can still practice…" (sem microfone, que o
  texto rola em ritmo constante; só sem câmera, que ela se liga nos Ajustes para gravar). O fluxo nunca trava.
- **Tópicos** (`UniverseChapter`): "+ Your own" vira chip escolhido (`customTopics`); solto, continua na lista.
- **Prática** (`PrompterView` com `isPractice`, `PracticeBottomBar`): câmera em tela cheia (`CameraBackdrop(fillsScreen:)`), sem moldura, grade nem zona
  segura (não grava). Sem seletor de modo: a prática escolhe sozinha (§35) e diz o que move o texto numa cápsula sob a caixa (`PracticeVoiceStatus`);
  embaixo **Explore Cue first** sempre, e **Record my first video** (amarelo) depois do play. Sem microfone: "Turn on the microphone so the text can follow your voice." com
  **Open Settings**; ao voltar a prática relê a permissão (`refreshPracticeMicrophone`). Sem câmera, o `CameraBackdrop` avisa e leva aos Ajustes; depois
  da prática, `MicrophoneNeededCard` cuida do Record.
- **Fala** (`SystemPermissions.requestSpeech`): o callback volta numa fila de fundo; o closure fica num `nonisolated static` (numa classe `@MainActor`
  herdaria o isolamento e o Swift 6 aborta com `dispatch_assert_queue_fail`).

**Teleprompter, só foco:** o texto tem uma cor só e apenas rola conforme a voz é reconhecida (`SpeechLead`, `VoiceGlide`, `ScriptSpeechTracker`); nada de
realce de palavras. Ficam a linha de leitura, o trilho de seções e o chip de voz.

## 5.4. Studio é só teleprompter; o Selfie lembra o último ajuste

**Studio** (`Screens/Prompter/Studio`): sem câmera, sem gravar, sem permissão de câmera; para ensaiar, ajustar o texto ou ler com outra câmera filmando
(espelho e Remote continuam). Gravar é do Selfie. Texto `PrompterTextView` em tela cheia com a linha em `guidePosition`; um toque toca ou pausa.
**Barra** (`StudioControlPanel`, vidro noturno, alça que guarda e ⌃ que traz): (1) Voice | Steady, ‹‹ 3 linhas, play, 3 linhas ››; (2) velocidade ou linha
de voz e estado; (3) chips **Size · Line · Margin · Mirror · Aa More** (`StudioAdjustBar`): um slider por vez (tamanho 12–56 pt, linha 10–70%, margens 8–40 pt; o slider
só existe aberto, `showsSlider`), Mirror para rig, Aa abre o Display. Acima do texto, "0:42 LEFT" e "1:12 · IDEAL 1:00–1:30" (`StudioTimeLine`).
**Contagem:** play do começo usa a de Settings › Prompter (Off, 3, 5, 10 s); a barra some e um toque cancela; retomar toca na hora. Voice Following ouve
pelo medidor do microfone.

**Selfie:** a caixa abre no lugar recomendado (118 pt sob a lente; uma linha antiga abaixo de ~1/3 da tela foi apagada uma vez, `readingLineResetV30`).
Ao sair, a caixa, a linha, tamanho e margens do texto, velocidade, espelho e Voice | Steady viram o ponto de partida da próxima sessão
(`SessionSetupService.rememberReadingLayout`); câmera, qualidade, recomendação da plataforma, fonte e cores são só da sessão; "Back to my setup" volta ao
que estava ao abrir. A prática do onboarding não grava nada. Barra e controles: §22.

## 6. Argumentos de teste

Ver `CLAUDE.md` (Launch arguments) e `SupportFiles/LaunchOptions.swift`.

## 7. Suposições (lacunas do protótipo)

- O dock some durante a seleção; a dica espera 1,2 s com a tela quieta (sem sheet, toast, teclado, busca focada ou seleção).
- A estrela pousa onde começaria o título da página, sem destino medido no protótipo.
- "Speak" do exemplo (08 X1) não foi feito (só Paste e My scripts); o microfone do dock dita ao toque.

## 8. Idiomas e Apple Intelligence: mensagens

Sem tela nova; mensagens nos componentes que já existiam (detalhes em `LOCALIZATION.md` §1.1). **Nenhum rascunho vazio abre só para dizer que a IA não
escreve:** `DraftingAvailability` (`writer.drafting(in:)`) diz antes de qualquer pedido, por ordem: o interruptor do Cue (Settings › Privacy & AI data ›
On-device AI), aparelho sem Apple Intelligence, Apple Intelligence desligado no iOS, idioma que o modelo não escreve, modelo se preparando (esperar não
ajuda um idioma, então o idioma vem antes). Escrever à mão, importar, teleprompter e legendas nunca dependem disso; o idioma nunca muda sozinho.
- **Dock** (decisão do dono, 22/10/2026): com a **Script Language** num idioma que o modelo não escreve (ou qualquer motivo do aparelho), o dock fica no
  estado **Write it** de sempre (sem chip de voz, sem sugestão) e a nota `AIUnavailableNote` diz o motivo + "Write it yourself or import a script."
  (só texto; modelo se preparando diz só o motivo). Em **Auto-detect** nada é julgado antes de enviar (nunca pelo idioma da interface): no toque da seta,
  o idioma real do pedido (o detectado na ideia, ou o da interface se a ideia não diz) decide; se o modelo não escreve, a estrela não sai, nada abre, a
  ideia fica no campo e um toast dá o motivo com **Write it** (só esse toque faz o rascunho em branco com a ideia como título). O mesmo vale para o
  Logbook (a ideia continua esperando), Find inspiration, a última pergunta do My Cue Voice ("Done" em vez de "✦ Draft my script") e "+ › Let Cue draft
  it" (some, como sem IA). O dock pergunta de novo ao voltar para o app e, enquanto o modelo se prepara, a cada 30 s.
- **Answer a comment:** o idioma é o do comentário (não o do inglês que o embrulha); se o modelo não escreve, o subtítulo do "Is this right?" diz o motivo
  + "Write your reply yourself." e só fica **Write it myself** (primário). Uma falha tardia (a IA mudou durante a estrela) guarda o comentário no Logbook.
- **Sponsored ad:** no idioma da ideia do dock, quando conhecido; se o modelo não escreve, o botão é **Open the draft** e a nota de baixo dá o motivo +
  "Open the draft to write it yourself."
- **Ferramentas da página:** no idioma do roteiro, o subtítulo do Improve diz o motivo e as ferramentas que precisam do modelo ficam esmaecidas; a barra
  da seleção não aparece; Shorter do aviso de duração some; "Make a version for…" diz o motivo antes do "Drafting…". Hooks caem nos do formato. Os
  erros dão o motivo quando o criador pode agir (idioma, **par** de idiomas, modelo se preparando, resultado em outro idioma); "Couldn't draft it · Try
  again" só quando tentar de novo resolve. Parar não mostra erro. **Translate** só age com o idioma escolhido, e cada destino que o modelo não escreve
  diz embaixo "Apple Intelligence can’t draft in it yet".
- **Notificações** de ideias, My Cue Voice e Import my writing sem IA: o toast diz o motivo real.
- **Legendas** (`CaptionState.missingLanguages`): diz qual idioma ficou de fora (com **Retry**); par recusado: "This iPhone can’t translate…".
- **Language & Region › Voice Following:** "Ready on this iPhone", "Downloads the first time you use it", "Not available on this iPhone"
  (`LanguageCapabilityService`). **Script Language:** "Apple Intelligence can’t draft in it yet" embaixo de cada idioma que o modelo não escreve (só
  esse motivo; sem IA nenhum idioma é marcado), e o rodapé da seção acrescenta "Apple Intelligence can’t draft in {idioma} yet." quando o escolhido é um
  deles. Teste de UI: `-uiTestAIUnavailable <language|device|off|preparing|cue>` (+ `-uiTestScriptLanguage th-TH`).

## 9. Compartilhar: o que cada estado afirma

Regra de contagem e rotas em `SHARING.md`. **Contagem:** uma exportação por arquivo, descontada quando o vídeo comprovadamente sai do Cue (salvo em Fotos,
atividade da folha concluída, Share Kit do TikTok); abrir um app, preparar, cancelar ou falhar não desconta. **"On its way" / "Shared to X"** só com
entrega comprovada; só o app abriu → "Ready to travel" (`ReadyToTravelView`) com "Ready to post on X"; LinkedIn só salva ("Saved to Photos · Open LinkedIn
to post it"); Instagram: "Opened X with your video · Cue can't see if you post it", sem celebração. Toasts: "Shared with X", "Sharing cancelled",
"Couldn't share · Try again", "Saved to Photos · Open X to post it", "X isn't on this iPhone · Pick another app", "X didn't take the video". Nada diz
"postado". Sem Fotos, só **Save video** mostra "Open Settings".

## 10. Settings (11.1), 1.1 Welcome e 1.2 Topics

**Settings** (`09` §11): `List` `.insetGrouped` sobre o céu (`cueGroupedList()`, `cardRowBackground()`, `CueSectionHeader`), toda página empurrada
(`SettingsRoute`; nenhuma sheet). Título grande do sistema (`.large`); a busca (`SettingsSearchField`) é a primeira linha da lista e rola com ela, e os
resultados são seções da mesma lista (o teclado não cai). Cada linha é um `SettingsEntry` (título, detalhe, caminho, palavras-chave) desenhado por
`SettingsEntryRow`, igual na página e na busca (`SettingsSearchGroup`); linhas de 52 pt; rodapé ≤ 60 caracteres, sem botão amarelo sólido. A raiz
começa em Create (sem card de setup: cada linha já diz o que está escolhido, "Front · 1080p", "Voice"; decisão do dono, 21/10/2026). **Ícones**
(`SettingsIcon`, escolha do dono 21/10/2026): desenhos próprios do Cue em `Assets › SettingsIcons` (SVG de 24 pt, modelo; duotom: corpo a 28%,
contorno de 1,7 e um detalhe sólido do app: o ponto de gravação, a linha de leitura passando da janela, o play transmitindo do Remote, a estrela do Cue,
o pincel do Personalize, o cadeado da política…), em azulejo de 32 pt raio 9 com degradê e um fio de luz no topo, em três famílias: **amarelo** para o
que grava (Recording, Prompter, Remote), **violeta** para a IA (My Cue Voice, Personalize), **cinza** para o resto, e Cue Pro em azulejo amarelo cheio
(`Palette.Settings`, medidos em `PaletteContrastTests`). Páginas: Recording, Prompter, Remote, Personalize (céu §5, Getting started §32; os 5 ícones e as regras de marco do
app, não as do protótipo), Language & Region (idioma do app abre os Ajustes; Voice following e Script language são menus), Notifications (§27), Privacy &
AI data (**On-device AI** é a chave de todos os recursos de IA: `PrivacyPreferencesService` → `ScriptWriting.isEnabled`; Help improve Cue decide se os eventos
vão ao Analytics; **Delete my Cue data**, `DataEraserService`, apaga do iPhone roteiros e pastas, tomadas com vídeos e edições, vídeos exportados à espera
e a fila de compartilhamento, Logbook, marcas, My Cue Voice, ideias e o gosto aprendido, meus estilos, o setup, as marcas da
primeira viagem, os rascunhos, as cópias de uma biblioteca danificada e os lembretes; as pastas de takes, mídias do editor e rascunhos saem
inteiras, com o que nenhuma take nomeia mais, e as gravações em `tmp/take-*.mov` que a recuperação traria de volta (o único lugar que limpa
"órfãos", porque o criador pediu tudo; §37); ficam a compra, o contador de exportações grátis e o registro delas
(só ids), a contagem de vídeos compartilhados do universo, o idioma e o que já está no Fotos), Permissions (`PermissionsService`), Acknowledgements. **Reset Creator Setup fica como está** (decisão pendente, `09` §13).
**Remote** (`SettingsRemoteView`, redesenho do dono 21/10/2026, conceito "dois aparelhos"): `ScrollView` sobre o céu. No topo a cena
(`RemoteHero`, posições em `RemoteSceneLayout`, aparelhos em `RemotePhone`, tudo num relógio só): o teleprompter à esquerda (roteiro subindo
sob a linha de leitura amarela, que passa das laterais e respira) e o controle à direita (play cujo halo chama a cada 3,2 s), flutuando fora de
compasso, com uma linha pontilhada que corre do controle ao teleprompter, quebrada no meio. **Esperando:** o teleprompter desliza ao centro e
cresce (mola criticamente amortecida, sem quique), o roteiro vira o QR em papel branco e a linha de leitura encurta e o varre como um leitor;
anéis saem dele a cada 0,87 s; o controle se afasta. Embaixo, o código em seis caixinhas que sobem do desfoque uma a uma (`RemoteCodeChips`),
"Waiting for your other device…" com os três pontos acendendo em sequência, os passos no outro aparelho e Cancel. **Conectado:** o controle
volta, os dois se inclinam um para o outro, a ligação se desenha em verde do controle ao teleprompter, um ✓ estala no alto com um anel de luz
e luzes correm pela ligação (os comandos); o brilho de fundo passa de amarelo a verde; CONNECTED, o nome do aparelho, "Press play on …" e
Disconnect; os ícones de "From the remote you can" acendem verdes em sequência. Desconectar recolhe a ligação para o controle. **Sem controle:**
"No remote yet", Connect a device amarelo grande, os cartões Enter a code / Scan the code (`RemoteJoinCards`, mesmo fluxo da busca:
`RemoteJoinFlow`), o que o controle faz (`RemoteCapabilities`) e Coming next. Vibrações (Core Haptics, `HapticPatterns`): Connect = toque firme
e um brilho quando o primeiro anel sai; dois tiques quase imperceptíveis nos anéis seguintes; ao conectar, tique + clique + assentar junto com o
✓; Disconnect = queda surda. O texto não promete mais Apple Watch (o app não tem). Reduzir Movimento: mesmas posições, nada se move, estados
trocam na hora. Cores em `Palette.Remote`.
**Personalize** (`PersonalizeView`, redesenho do dono 21/10/2026, "vitrine"): `ScrollView` sobre o céu. No topo, "seu Cue" ao vivo
(`PersonalizeHero`): o céu escolhido (`SkyMiniature`: o mesmo `BgWash` + `StarfieldView` da navegação, estrelas no brilho dos quadros), a luz
do universo respirando na cor escolhida (`CoreColor.glow`) e o ícone escolhido flutuando (`AppIconArt`; o padrão desenhado das camadas de
`AppIcon.icon`), com a legenda "Default · Serene sky · Gold light"; trocar o céu esmaece, a luz muda de cor devagar, o ícone entra numa mola.
**App icon** (`AppIconPicker`, a página própria saiu): os cinco ícones lado a lado como coleção, anel amarelo que desliza (matched geometry) e ✓
no escolhido, bloqueados apagados com cadeado que balança ao toque (e o aviso de quantos vídeos faltam), "10 · Pro"; Pro sem plano abre os planos.
**Starry sky** (`SkyPicker`): quatro cartões 2×2, cada um com o próprio céu ao vivo, nome e o que tem. **Your universe's light**: as
amostras do Profile (`CoreColorSwatches`). **Feel** (`PersonalizeFeelRow`): Celebrations e Haptics com ícone e o que fazem; ligar responde na
hora (as fagulhas sentidas; o primeiro toque). **Your topics** (`PersonalizeTopics`): os tópicos como etiquetas nas cores de Scripts, Edit (folha
do My Cue Voice) e a marcação automática. **Getting started** só até o primeiro vídeo. A busca leva aos mesmos lugares (`SettingsRoute.appIcon`
abre Personalize).
**Prompter** (`SettingsPrompterView`): na aba, com prévia no topo e céu. **A prévia** (`PrompterPreviewCard`, pedido do dono, 20/10/2026) é o topo da
tela deste iPhone no Selfie como o gravador o monta (o mesmo `ReadingLayout`: a linha de leitura sob a lente, onde o criador a pôs ou a 118 pt, e a
janela em volta dela, na largura e altura dele), reduzido para caber num cartão de 236 pt sobre uma câmera de mentira (`Palette.Camera.previewScene*`)
que ocupa o cartão inteiro: a ilha da câmera, a janela escura e desfocada como no gravador, a linha atravessando a tela, e o texto desenhado pelo próprio
teleprompter (`PrompterParagraphs`) rolando na velocidade escolhida (o já lido apaga acima da linha; Reduzir Movimento: parado; o texto de exemplo vem no idioma da interface, cues incluídas); pelo **Aa** do Selfie abre como `PrompterSettingsSheet` (`.medium`/`.large`,
`sheetMaxHeight`, fundo `Palette.surface`, sem prévia, `isRecorderSheet`), sobre os ajustes daquela gravação, medindo a linha de leitura pela tela e lente
do gravador (`SettingsPrompterView.screen`). Faixas de `PrompterSettings`: altura 160–380, largura 50–93%, margens 8–40, espaçamento 1–2;
`isFlippedVertically`, `safeZoneKey`, `showsCues` (desligado por padrão).
**Velocidade e tamanho do texto** (decisão do dono, 20/10/2026): a velocidade vai de **0,2× a 2×** em paradas de 0,1× (19 paradas, `SpeedScale`;
1× = 150 palavras por minuto, o padrão; cada parada é um número inteiro de passos de 5 palavras, então o valor salvo é o da parada) e
`PrompterSettings.speedRange` são as duas pontas, tiradas da escala. Todo lugar segue as mesmas paradas, com um tique em cada uma: o slider de
Settings › Prompter (pontas "0.2×" e "2×"), o do gravador (`SpeedSlider`, Selfie e Studio, sem marcas no trilho: o valor
está escrito acima) e o − / + do Remote (uma parada por toque). Uma velocidade salva acima de 2× (os 3×, 4× e 5× de antes) abre em 2×.
**Text size** é um slider em pontos, de **12 a 56 pt** de 1 em 1 (valor "36 pt", pontas "12" e "56 pt"), o mesmo
alcance do Size do Studio (`studio.slider.size`) e do Text size do Display do gravador (`display.textSize`); o Studio desenha 1,35× maior. Um
tamanho salvo fora da faixa abre na ponta mais próxima. Não há tamanhos com nome (Small, Medium, Large, XL): o bloco Text do cartão de setup
e a folha de setup do gravador mostram os pontos ("36 pt") e a velocidade como o slider ("1×"). Para os testes de UI, os sliders da página
respondem pelo identificador da linha (`settings.speed`, `settings.textSize`: o `accessibilityIdentifier` de `PrompterEntryRow` cobre o do
slider); na aba Settings o arrasto sintético do XCUITest não move os sliders desta página (nenhum deles), então as pontas são testadas pelo Aa
do gravador.

**1.1 Welcome** (`09` §12): `WelcomeScript` escreve a cena de 390 × 844 como `PoseTrack`s: a estrela entra pela direita, acende 5 pontos do C (0,2 s
entre eles), cai em TELEPROMPTER, AUTO CAPTIONS, ✦ AI SCRIPTS, volta e explode no sexto ponto; depois "CUE STUDIO", o título palavra a palavra, o subtítulo
e **Get started**, o único botão (§36). `WelcomeStarPainter` em `Canvas` + `TimelineView`, toca uma vez (≈ 8 s). Hápticos: `.soft` nos pontos, `.light` nas palavras, `.success` na
explosão. Testes de UI mostram o estado final, salvo `-uiTestWelcomeOpening`.

**1.2 Topics become worlds:** marcador do tema é barra de 3 × 14 pt na cor do mundo (nunca bolinha). Ao tocar: brilho no chip, cruz de luz, oito faíscas,
luz em curva até a órbita, aterrissagem em 1,4 s; o planeta aparece (×1,9 → 1), a órbita desenha (1,4–2,7 s), o nome chega (`TopicBirth`,
`TopicBirthPainter`). Na entrada um anel amarelo abre no núcleo. Detalhes do capítulo em §18.

## 11. Exportações grátis acabando (`09` "Free exports running out")

Rótulos de `FreeExportLabels` (9.1 plano, 8.1 medidor, 6.3 linha sob Share): neutro, amarelo na última, laranja quando acabam. **Com 0**, Share / Save
video / compartilhar abrem **"Your video is ready"** (`ExportReadySheet`: miniatura "✓ READY", **Start free trial · export now** com brilho, **See what's
in Pro** em vidro, **Not now**, "7 days free, then $39.99/year. Cancel anytime." com o preço da StoreKit). Fechar ou Not now deixa a take pronta (6.3:
"READY · EXPORT WITH PRO") e toast "Saved in Takes · export with Pro anytime"; Start e See abrem o **Pro calmo** (`PaywallContext.export`, §12); comprando,
a exportação segue sozinha. Pro e teste: "PRO · UNLIMITED EXPORTS", sem Go Pro.

## 12. Pro (11.4)

`PaywallView` escolhe pelo contexto, num `NavigationStack` próprio com `Button(role: .close)` em `.topBarTrailing` (o texto devolve
`ProPlansScreen.barHeight` para a arte não se mover).
- **Pro normal** (`.profile`): `ProOpening` (luz até 3 s, tocável a partir de 1,4 s) sobre o `SubscriptionStoreView` (`ProStoreView`, `.prominentPicker`,
  Restore, links do app). `ProOpeningScript`: 42 riscos (0–1,1 s), uma estrela dourada acende no foco (0,2 → 1,6, 0,7–1,4 s) com a onda ×0,4 → ×14
  (1,25–2,35 s), voa até o planeta com o rastro do primeiro voo (`StarRibbon`, 1,5–2,1 s, curvando para a direita); um anel de luz se fecha no ponto e o
  planeta nasce ali branco incandescente (0,3 → 1,08 → 1, 2,12–2,85 s), esfria ao dourado e solta 14 faíscas; as órbitas se desenham (2,3–3 s) e os
  planetinhas entram (`settled` 3,1 s); conteúdo sobe 18 pt nítido a cada 70 ms; háptico `.soft` 1,25 s e `.success` quando o planeta nasce (2,16 s). A luz
  é desenhada na tela inteira (`ProOpeningCanvas`): foco a 44% da altura, planeta a 150 pt (`PaywallView.planetY`). `ProPlanetArt` (220 pt de altura):
  planeta de 68 pt com atmosfera que respira, faixas, lado escuro, borda de luz e brilho a cada 7 s; órbitas 350 × 58 e 236 × 40 pt com poeira; planetinhas
  com rastro curto. O cartão de benefícios aparece junto com as linhas (`revealed`). `ProMarketing`: "CUE PRO", "Take your universe further.", "Free to
  try · 5 exports included. Then 7 days free." (15 pt), linhas de 16 pt com um símbolo num quadrado colorido (`ProBenefit.symbol`) e a tag mono.
- **Pro calmo** (`.export`, `ProCalmView`): sem abertura; "YOUR VIDEO IS READY", "Keep sharing your universe.", "Start the trial and export it now.",
  planos (Yearly com SAVE n%, Monthly; largura 1,2 : 1, 72 pt, `ProPlanRow`), "Start free trial · export now", Restore · Terms · Privacy.
- Reduzir Movimento: fade de 0,3 s. `-uiTestProAt <s>`. **"Remote from Apple Watch, iPad & Mac sync" não aparece** (`ProBenefit.isAvailable = false`):
  não se vende o que não existe.

## 13. Profile (9.1) e Edit Profile

Rolagem de blocos sólidos sobre o céu (`profileBlock()`; redesenho do dono 21/10/2026, **enxuto**: "muita informação escrita"; **Plan e My Cue
Voice ficam como eram**). Sem Edit na toolbar: ele fica no cartão. **Você** (`ProfileIdentityContent`): avatar de 72 pt (foto, inicial ou o
astronauta) num anel da luz do universo que respira; nome; "@usuário · tipo" (o próprio, `customRole`, ou o da lista), ou, sem nenhum dos dois,
"+ Add a username" em amarelo (sem números: o dono os tirou). Perfil vazio: o astronauta, "Your name" apagado e **Set up your profile**. **Your universe**
(`ProfileUniverseRow`): o universo em miniatura ao vivo (`ProfileMiniUniverse`, 104 pt com folga da borda: o núcleo na cor escolhida respirando, três órbitas e **um planeta por
rede** compartilhada no ano, na cor da rede, a mais usada mais perto, com uma lua), o título e uma linha ("2026 · 1 video", singular/plural no
catálogo); conta nova: "Your universe is waiting", órbitas pontilhadas girando e um planeta tracejado esperando. Os marcos e ícones não aparecem
no Profile (saíram a pedido do dono). Toque longo na identidade: Copy @handle · Share profile link · Edit profile. As animações ambientes (`AmbientTimeline`) já andam ao
abrir a tela: o primeiro aviso de visibilidade do scroll, que chega antes do layout dizendo "invisível", não as para mais.
**`EditProfileSheet`** (`.large`, Cancel / Done; redesenho do dono 21/10/2026). **Tudo é opcional:** `ProfileDraft` aceita nome e usuário
vazios (digitados, nome até 40, usuário 2–24 de a–z 0–9 . _, minúsculas, com o erro embaixo) e **Done só desliga com algo digitado fora do
formato** (antes exigia os dois preenchidos, e um perfil vazio não salvava mais nada: bug do dono). No topo, **"How you appear"**
(`EditProfilePhoto`): o cartão do universo compartilhado ao vivo (o céu do criador, ou Serene se desligado; a foto flutuando com um selo de
câmera amarelo, que abre Choose Photo / Remove Photo; nome, @usuário e o tipo de criador, com o texto de exemplo até ser preenchido). **You:** Name
e Username alinhados igual, contador do nome perto do limite, ✓ verde quando o usuário serve. **What you make** (`CreatorTypePicker`): os tipos
como etiquetas (um por vez, tocar de novo tira) e **"+ Add your own"**, que vira um campo na própria etiqueta e guarda um tipo próprio
(`CreatorProfile.customRole`, o mesmo do My Cue Voice e do roteirista; vale no lugar da lista e aparece no perfil), com × para tirar. **When you
create** (`EditProfilePreferences`): as plataformas como galáxias na cor de cada uma (`Platform.tint`), anel amarelo que desliza, e Monetization
goals com o que muda ("Script lengths aim at what earns on TikTok"). **Account** (`EditProfileAccount`, ação imediata, fora do Cancel / Done): um
cartão discreto dizendo que é opcional e só preenche o nome, com o botão branco da Apple (o estilo pedido em fundo escuro), mais baixo.

## 14. Your universe, um por ano (9.2)

Cada compartilhamento confirmado é um `ShareRecord` (take, data, redes, tema); um vídeo conta uma vez, cada rede confirmada soma no seu planeta; vídeos
antigos usam data, plataforma e tema da take. `UniverseContent` (puro, testado) decide a tela: **vivo** (ano corrente; o anterior como fantasma), **selado**
(saturação .75, brilho .92, nada se mexe, "◆ SEALED · DEC 31, {ano}", cartão "{ano} · YOUR YEAR"), **conta nova** (sem seletor, órbitas a 55%, "FIRST STAR ·
0 / 1", "Record your first video") e **ano novo** ("FIRST STAR OF {ano}", a review fala do ano anterior). Seletor segmentado na toolbar e deslize no mapa.
**Planetas** (`PlanetSize`, `PlanetPainter`): `d = 14 + 24·ln(min(n,365))/ln(365)` pt, brilho a 52, anel a 156, lua a 365; crescem em 0,6 s
`cubic-bezier(.3,1.4,.5,1)` na primeira abertura depois de um share (`MilestoneService.seenPlanetCounts`), `.soft` ao ganhar um detalhe.
**Toques:** planeta → `PlanetPopover` ("n VIDEOS IN {ano}", "k more to unlock …" no ano vivo, **See in Takes ›**); ponto → revisão da take; tema na legenda e
planeta → Takes filtrado (`TakesRequest`, chip "{ANO} · SHARED ✕"); núcleo → `UniverseCoreSheet`.
**Share my {ano} universe** (`UniverseShareSheet`, `UniverseShareViewModel`): cartão 9:16 (`ImageRenderer`, PNG 1080 × 1920) ou vídeo de 6 s
(`UniverseMediaRenderer`, AVAssetWriter, 20 fps), Show numbers / Show @handle, Save to Photos, Share…. **Year in review** (`YearInReviewView`,
`fullScreenCover`, fade 0,3 s): 5 slides de 3,2 s, barras de 3 pt, toque nos lados, ✕, "Share my {ano}" no último; fatias sem dados saem (sempre ≥ 2);
a partir de 3 vídeos; ao vivo só de 1º de dezembro (antes "PREVIEW · READY DEC 1"). Pode abrir pela aba Profile já na história (`ProfileRoute`,
`YourUniverseView(opensYearInReview:)`). Reduzir Movimento: barras cheias, sem avanço sozinho. A legenda mostra as três linhas de tema acima do cartão do
marco (o quadro as cobre); em aparelhos baixos a tela rola.

## 15. Share to universe (8.1, 8.2, 6.3) · fase A

Na revisão, o botão amarelo **Share to universe** renderiza o arquivo (1080 × 1920, sem marca d'água; nada sai do Cue, nada é contado) e abre **Ready to
travel** com as redes (`ShareNetworkPicker`: TikTok "· from your script", Reels, Shorts, YouTube ("POSTS AS A SHORT" até 3 min na vertical), LinkedIn, "Also
save to Photos", "Share to n networks", "Uses 1 free export · k left after this"; embaixo, legendas e qualidade). Fechado o sheet, Ready mostra **Share to
universe · Save video · compartilhar** (folha do sistema). **Uma exportação por envio** (um arquivo para todas as redes; reexportar na fila não gasta
outra: `ExportLedgerService.begin(inheritingCountFrom:)`).
**A fila** (`ShareQueue`, `ShareQueueService`, `ShareFlow`): "Posting to n networks" (com 2+, nas 2 primeiras vezes); o passo de cada rede ("1 OF 3",
segmentos, legenda copiada e editável, "In the share sheet, tap {app}", "◀ Cue", **Send to {app}** · Edit first · **Post later** (`Menu`: Tonight, Tomorrow,
Pick a date and time…, No reminder; §27)); "Posted on {rede}?": **só "Yes, it's live" conta** e acende o planeta (`MilestoneService.recordShare`).
Cada passo tem a altura do próprio conteúdo. Fechar manda o resto para depois ("Saved · continue anytime"); o card **Continue posting**
(`ContinuePostingCard`, 60 pt, 104 pt acima do fundo) aparece em Scripts, Takes e na revisão. Falta a linha "Cover frame 0:03" (o app não escolhe capa).
**Fase A:** todas as redes usam a folha do sistema (`ShareIntegrationConfiguration.integrationsEnabled = false`); Share Kit do TikTok e passagem do Instagram
voltam com uma linha quando validados no aparelho (`SHARING.md`).

## 16. Telas ligadas

- **8.3 Milestone** (`MilestoneView`, `MilestoneScript`, 4,5 s): seis fagulhas caem num ponto (0–1,35 s), o ícone de 140 pt surge (×0,6 → 1,06 → 1 a partir
  de 1,17 s, `.success`), cruz de luz (1,55–2,45 s) e anéis dourado e pálido por cima do ícone, raios girando em 40 s. "MILESTONE · 25 VIDEOS IN 2026", "A new
  icon is yours.", "ON YOUR HOME SCREEN" (vidro de 76 pt, quatro ícones), "Use Deep Space" / "Keep my current icon" (sem Pro: "Get … with Pro"). Os marcos
  contam todos os vídeos.
- **1.7 First star** (`FirstStarView`, `FirstStarScript`, `FirstStarScene`, `Keyframes`, 8 s): o take "✓ SAVED" dobra em luz (1,55 s), um cometa o leva até a
  estrela (1,6–2,9 s), a estrela acende (2,95 s, `.success`) com 10 fagulhas, dois anéis e cruz de luz, a linha de YOU se desenha (3,3–4,1 s), "FIRST
  VIDEO · FIRST STAR" (12 pt) e **"Your first video. Your first star."** palavra por palavra (desfoque 8 → 0, título em 300 pt, uma frase por linha),
  "Saved in Takes. Add captions, edit it or share it to light up your 2026 universe." (17 pt) e **Explore Cue** / **Edit my video**; brilho cruza
  "Explore Cue" uma vez. O acabamento por cima do quadro está em §36. Toca uma vez até 7,5 s e fica (órbitas girando). Noite `BgWash.firstStar`.
  `-uiTestStoryAt <s>`.
- **6.2 Takes** vindo de um planeta ou tema: chip "{ANO} · SHARED ✕" (§18).

## 17. Confirmações (11.1 "reset confirm")

`CueActionSheet` (`DesignSystem/Components`): a página escurece, um cartão com a pergunta em cinza e a ação em vermelho, e um cartão **Cancel** separado em
negrito. Custom porque o `confirmationDialog` do iOS 27 abre como balão, sem Cancel. Usado em **Delete my Cue data** e **Reset Creator Setup**.

## 18. Movimento vindo dos dados do quadro (handoff-telas)

**Motor** (`DesignSystem/Motion`): `tools/bake_motion.py` transforma os `@keyframes` dos HTMLs (camadas `L<n>`) em `Motion/Data/screens-motion.json`;
`MotionLibrary.clip("1.2_topics")` dá um `MotionClip` que responde `pose(of:at:)` (opacidade, deslocamento, escala, rotação, desfoque, traço, caminho, cor,
brilho, recorte). `MotionScreen` é o relógio único da tela (`TimelineView`; toca uma vez e segura em `hold`; `loops` para o fundo; toque pula quando
`skippable`); `MotionTime` leva o segundo da coreografia e o do ambiente. Efeitos em `DesignSystem/Effects` (`GlowDot`, `StarTrail`, `LightFX`); galáxias de
1.3 e 1.4 por `GalaxyPainter` a partir de `galaxies.json` (`tools/bake_galaxies.py`, cache `HeroDiscCache`). **Conferir:** `tools/fidelity` (HTML parado num
segundo × app com o relógio congelado) e `HandoffCaptureTests`. Cada quadro tem o próprio `.night` (`BgWash+Presets`: welcome, universe, voyage, message,
permissions, firstStar, yourUniverse, sendOff, milestone, pro, share; `skyBackground(wash:base:)`); cores de onboarding, prática e send-off em
`Palette+Flight.swift` (nenhum hex solto em `Screens/Onboarding` nem `Screens/Prompter/Practice`).

**Onboarding (1.1–1.7)**
- **1.1:** `WelcomeScript` (§10), `BgWash.welcome`, `WelcomeShootingStar`; céu `OnboardingSky`, `SkyDirector`.
- **1.2 Topics:** 10 temas, do mais comum ao menos (`Niche.offered`: Fitness & wellness · Food & cooking · Beauty & skincare · Fashion & style · Personal
  finance · Tech & AI · Budget travel · Productivity & career · Parenting & family · Daily routines) + "+ Your own"; `Wellness` e `Education` continuam
  válidos para quem já os tem. O nome do chip é o do mundo em todo o app (`Niche.chipLabel`). De 1 a 3: **Continue** fica cinza ("Pick a topic") até o
  primeiro, `TopicCounter` diz quantos faltam; com 3, os outros ficam apagados (toque só dá aviso tátil); soltar um libera outro. Luz, planeta, órbita e
  nome vêm do quadro (`TopicBirth`, `idade + 2,6 s`).
- **1.3 Voyage:** `VoyageScene` (Canvas) com a galáxia do criador, as das redes e a rota, encaixadas entre o título e os chips (`VoyageFit`, §36);
  nada vem marcado: o botão diz "Choose a platform" e depois
  "Continue with {rede}"; "9:16 · IDEAL … · SAFE ZONES ON" (OFF em YouTube e LinkedIn, sem zonas seguras) é digitado em 34 passos.
- **1.4 First script:** `ScriptChapter` com `MessageCard` (gancho, corpo e CTA do roteiro de prática palavra por palavra no ritmo do quadro, "VIDEO FOR ·
  {REDE}" e o tempo de leitura medido), "SCRIPT READY · LET’S TRY IT", "It’s just practice. Nothing is recorded." e **Try the teleprompter** (§35).
- **1.5 Permissions:** `VoicePermissionsArt`, linhas com **Allow** / **Next** (§5.3).
- **1.6 Practice:** caixa do teleprompter do app (`PrompterView` com `isPractice`, 310 pt, §36), texto de 24 pt, sem trilho nem linha até a contagem;
  play abre **GET READY 3 · 2 · 1** com anéis, **READ!** e traz **Record my first video**; o texto então espera a voz (§35); no fim "You’ve got it. Ready to
  record?" e os dois caminhos (`PracticeStage`,
  `PracticeBoxOverlay`, `PracticeMessageCard`, `PracticeVoiceStatus`, `PracticeBottomBar`). A barra de capítulos acende o 4º segmento em 1.5 e 1.6; o 5º é do primeiro astro.
- **1.7:** §16.
- Hápticos de 1.2–1.6 (`.soft` ao tocar, `.success` ao pousar) são proposta, sem confirmação do dono.

**8.2 Send-off** (quadro de 390 × 844 escalado; `SendOffLayout`, `SendOffScript`, `SendOffMap`, `SendOffView`): órbitas de 316 e 220 pt achatadas a 32% e
giradas −9°, YOU de 56 pt, planetas de 20/18/17/16/14/12 pt por ordem de vídeos, cartão de 54 × 96 pt vira luz (0,65 s), uma estrela por rede (0,52 s +
0,35 s·i, voo de 1,05 s, nove pontos de rastro a 38 ms) num arco quadrático (`SendOffLayout.arc`, não está no quadro), pulso ×1,35 → ×1,12, anel ×5,
"+1", contagem sobe na chegada, estrela nova 0,3 s depois do primeiro pulso. "SHARED TO 3 NETWORKS", "On its way." e o link para a nova estrela; texto e
botões parados desde o início; redes que não receberam ficam a 38%.

**6.2 Takes:** título + "12 TAKES · 5 VIDEOS"; **trilha de status** (`TakePipelineCard`: quatro nós de 28 pt, TO PICK cinza, IN EDIT ciano, READY verde com
anel que pulsa a cada 2 s, ✦ SHARED lilás; tocar filtra, de novo limpa); **Up next** (`TakeUpNextCard`: pôster 40 × 56, "UP NEXT · POST IT", botão amarelo
Share/Edit/Pick que abre a take naquele passo); **fichas** (`TakesFilterChips`: "2026 · SHARED ✕" primeiro quando vem do universo, All e uma por rede; a
escolhida branca com texto preto). **List | Grid** é `Picker` `.segmented` (`TakesLayoutToggle`). Card da grade (`TakeVideoCard`, 177:270): anel de 1 pt na
cor do estágio, pílula do estágio, título e "● TIKTOK · 1:02" no pé. Lista: §24. Lista vazia por filtro: "No videos for Shorts here" + **Show every video**.
Segurar um vídeo abre o menu de contexto (a prévia recebe `.environment(services)` e o pôster lê os serviços como opcionais: o sistema redesenha o cartão
fora do ambiente do app). **Não feito (decisão do dono):** Select (sem seleção em massa), bolinha de tema no card; títulos de dia (Today, Yesterday) ficam.

**Diferenças em aberto para o dono:** a fonte é SF (o quadro usa Geist, mais larga): títulos que quebram no quadro têm largura ajustada (1.7) ou escala
mínima (9.2).

## 19. Folhas e telas revistas pelo dono (6/10/2026)

- **Pôsteres** (`PosterImage`): a imagem vai em `.overlay` de um fundo flexível; com `scaledToFill()` + `.clipped()` num `ZStack` um vídeo horizontal
  alargava a folha "Ready to travel" e o retorno da folha de compartilhamento travava e dava zoom. Testes: `PosterLayoutTests`, `ShareReturnUITests`.
- **My Cue Voice** (4 perguntas e folha de perguntas): fundo da noite, título 28 bold, chips brancos quando escolhidos, a nota "Common for …" desce para
  baixo do nome quando não cabe. SF em todo o app (sem serifa).
- **Import (+ › Import):** campo em cartão `Palette.surface` com borda; "Use this script" desabilitado pelo estado do botão.
- **Um prompter só:** todo caminho que grava (botão da câmera, Record da página, da linha, Retake, Siri) chama `PresentationService.openPrompter(mode:
  .selfie)`. Só o item "Studio mode" abre o Studio, e a prática do onboarding é a outra exceção (`PrompterEntryPointsUITests`).

## 20. Skin Smoothing (Quick edit › Adjust)

**Controle:** chip no fim do Adjust (régua 0–100, como Sharpness), mesmo Reset, Compare (◐ mostra sem ele) e escopo (vídeo todo ou o clipe). Começa em 0.
VoiceOver: "Softens the skin of faces. Eyes, lips, hair and beard stay sharp." Independente dos Filters.
**Dados:** `TakeEdit.skinSmoothing` (0…100, ausente = 0, cortado ao ler), `ClipLook.skinSmoothing?` (vale em vez do do vídeo; 0 é escolha),
`LookSettings.skinSmoothing`, `EditLook.skinSmoothing?` (desfazer). Dividir, duplicar e aparar levam o valor; Compare e `withoutPictureLook()` zeram.
**Ordem** (`FrameLook`): Auto → **Skin Smoothing** → dials do Adjust (Sharpness por último) → filtro → zoom, transições, B-roll → textos e legendas
(`CueVideoCompositor.decorated`, nunca alisados). Vem antes dos dials e do filtro porque lê os tons da própria imagem. Rostos achados no quadro como foi
gravado, antes do efeito de fundo. Prévia, exportação e capa usam o mesmo código (`CueVideoCompositor`, `CoverRenderer`).
**Processamento** (`Managers/Editing/SkinSmoothing/`, só Core Image + Vision): `VisionFaceDetector` (quadro de 640 px, até 4 rostos, pequenos descartados) →
`SkinFaceTracker` (mesmo rosto entre olhares, movimento suavizado, fade, esquece no corte/seek; entre detecções segue na velocidade que tinha, até 0,1 s à
frente, ≤ 1,5 larguras/s; a força só baixa se a próxima detecção atrasa) → `SkinMaskRaster` (pele dentro da mandíbula e meia testa, sem olhos,
sobrancelhas e lábios) + `SkinToneAnalyzer` → `SkinSmoothingFilter` (portão de tom, borrão só de pele, textura atenuada, bordas mantidas). Em sRGB codificado,
só na região do rosto; tamanhos em frações da largura do rosto. Topo conservador: ≤ 60% do suavizado e ≥ metade do detalhe fino. Sem rosto ou tom
confiável, o quadro volta idêntico; em 0 nada roda (`SkinSmoother.pass(for:value:…)` devolve `nil`). Detecção ≤ 20 vezes/s.
**Memória:** o compositor esvazia um autorelease pool por quadro (`autoreleaseFrequency: .workItem`) e a detecção roda no seu: sem isso o iPhone matava a
exportação (sinal 9).
**Dependência:** YUCIHighPassSkinSmoothing (MIT) avaliado e não adotado; só a ideia do canal verde (`THIRD_PARTY_NOTICES.md`).
**Medido (iPhone 15 Pro, `SkinSmoothingDeviceTests`):** 1080p p50 15,3 / p95 30,5 ms (sem: 5,6 / 7,0); 4K p50 32,8 / p95 56,5 ms (sem: 13,8 / 16,9), então a
prévia pode soltar quadros em 4K. Prévia × exportação: 0,4 de 255 em média.
**Limites:** barba fechada e reflexo ficam fora da máscara; perfil ou rosto pequeno não é alisado. O Vision não acha rostos no Simulator.

## 21. Contraste (WCAG 2.2 AA): medido e corrigido

Regra em `CLAUDE.md`. **Tokens** (`PaletteContrastTests`, com e sem Aumentar Contraste): `ink`, `inkSoft` (branco 80%, o degrau sob `ink` de etiquetas, do mapa e das palavras quietas do voo; `Flight.quietInk` é ele), `ink2` e `inkHint` passam 4,5:1 em todas as superfícies
(`inkHint` 5,15 no fundo, 5,02 no cartão, 4,77 na faixa `1F2236`); **`inkHint` não vai no azulejo `surface3`** (4,3:1; use `ink2`). `ink3` (3,8:1) só para o
que não precisa ser lido. `inkOnLight` (preto 62%, 6:1) para texto secundário sobre chip branco.
**Auditoria** (`tools/contrast/audit.py` sobre `HandoffCaptureTests`, `UserReportCaptureTests`, `ExploratoryTourTests`): a ferramenta **subestima** texto fino
e pequeno (um `ink2` de 6,3:1 sai ~3 em mono de 10 pt) e erra sob telas escurecidas e sobre vídeo; confira à mão os falsos positivos.
**Exceções por desenho:** "3 VIDEOS TO UNLOCK" e passos bloqueados a 62% (componente inativo), chips de tema apagados com 3 escolhidos, setas e
separadores, o astronauta (§5.0.1).

## 22. Página do roteiro, revisão, Quick edit e gravador (pedidos do dono)

**Página do roteiro (o único editor):** Text size pelo botão redondo `textformat.size`; salva enquanto se escreve; ••• tem Script details, Studio mode,
Remind me… (§27), "Make a version for…" (cópia para outra rede) e Delete (com Undo, como a lista); Improve fica só na página. A versão do roteiro (v2,
v3…) liga as takes ao texto lido. O texto é **corrido**, sem rótulos de estrutura nem régua de tempo (decisão do dono, 20/10/2026: o criador tem de se
sentir livre para escrever como quiser). **Sem dicas embaixo do texto** (gancho longo, frase longa, "No CTA yet"): quem quiser mudanças usa o Improve
(decisão do dono, 20/10/2026).
- **Rascunho ou pronto (decisão do dono, 20/10/2026):** a faixa sob o título (`ScriptStateStrip`, sem caixa) tem o interruptor **"Ready to record"**
  (`ReadyToggle`; RECORDED num roteiro gravado) e "Draft · Formato · n cues" em `ink2`, mais ✦ Shape sem cues e Stop enquanto a IA escreve. Ligar: verde
  (`readyFill`/`readyRim`, `successText` 6,7:1), acende uma vez e dá dois toques suaves (`HapticPatterns.finish`); formato com seções vazias pergunta
  ("Mark ready anyway" / "Keep writing"); página vazia: desativado. Desligar volta a rascunho. **Sair nunca muda o estado** (voltar só salva; editar um
  roteiro pronto não o rebaixa); só o interruptor muda, e gravar (leva a pronto e depois a gravado). **O roteiro que a IA escreve começa como rascunho**
  ("AI is drafting for you"). A página não tem "Done": digitando, o ✓ da barra só fecha o teclado (e a plataforma e o ••• voltam).
- **Duração numa linha** (`ScriptLengthBar`): "113 WORDS · ~0:45" à esquerda, "IDEAL 1:00–1:30" à direita, trilho de 5 pt; amarelo abaixo do ideal,
  verde dentro (com ✓, brilha uma vez e toque leve ao entrar), laranja acima ("CUT 6S", toque firme). Cresce numa mola; os toques são só do que o criador
  digita (não da IA). O título não tem contador embaixo.
  O tempo é sempre no **ritmo natural de fala** (150 palavras por minuto, o mesmo em que a IA escreve), não na velocidade de rolagem do
  teleprompter (decisão do dono, 20/10/2026: a 0,4× um roteiro de 1 min aparecia como 2:28 e "CUT 58S"). Vale também para a duração na lista,
  no Hook, no "Start recording" e na melhor tomada; só o tempo dentro do gravador (Studio) segue a velocidade escolhida.
- **Tab bar:** a página a esconde do jeito do sistema (`toolbarVisibility(.hidden, for: .tabBar)` na página; a da lista fica na raiz da pilha, não na
  pilha toda), então ela sai e volta junto com a animação de entrar e sair, sem o dock e a barra pularem (no voltar e no Cancel da estrela).
- **Título na barra:** rolando além do título, a barra mostra o título pequeno com "WORDS · ~TEMPO" embaixo (como Notas e Mail).
- **Foco ao digitar:** com o teclado no texto, faixa, duração, voz, aviso de fatos e ferramentas ficam a 30% (continuam funcionando); voltam ao fechar.
- **Ferramentas:** Hook (`text.quote`), ✦ Improve, Cues e o Aa redondo, todos com ícone. Inserir uma cue pela barra do teclado dá um tick.
- **Record preso ao pé** (`ScriptRecordButton`, no `safeAreaBar`): cápsula de largura toda (`CueStudioButtonStyle` grande, Liquid Glass amarelo; vidro sem
  tinta num roteiro gravado e sem mudança) sobre o efeito de borda do sistema. Sempre visível (sobe com o teclado do título); o teclado do texto põe as cues
  no lugar dele; apagado enquanto a IA escreve. (A barra de baixo do sistema não dá largura toda.)
- **Cues sobre o teclado** (`ScriptCuesBar`, no mesmo `safeAreaBar`): uma barra de Liquid Glass (tingida com `surface`), cues como etiquetas amarelas que
  rolam com degradê nas pontas, divisor e **+** fixo. O + abre "New cue" (sem colchetes, até 24 caracteres, `ScriptCueName`): entra no cursor e fica na barra
  para todos os roteiros depois das quatro do quadro (`PreferencesService.customCues`); segurar uma do criador: "Remove from bar". (O
  `ToolbarItem(placement: .keyboard)` não dá largura e deixava as cues sem fundo.)
- **Cues ligadas/desligadas** (botão **Cues** ao lado de Improve, `Toggle` `.button`; `PreferencesService.showsCuesOnPage`, ligado por padrão): desligado,
  as cues ficam no texto mas transparentes e com 1 pt. Inserir uma cue pela barra liga o botão de novo (senão ela entrava invisível, só um espaço
  vazio). O teleprompter tem o seu (`PrompterSettings.showsCues`).
- **Apagar uma cue apaga a cue inteira** (`ScriptCueDeletion`), com o cursor onde ela estava.
- **Cues como chips** (pedido do dono, 20/10/2026): no editor (um `UITextView` TextKit 2, `ScriptTextView`) e nas palavras que a IA escreve
  (`ArrivingText`), cada cue é um chip arredondado (amarelo a 14% com borda de 0,5 pt a 35%, `Palette.Cues`) com o nome em seminegrito a 72% do texto e um
  ícone para as cues conhecidas (pause, eye, hand.point.up, face.smiling, exclamationmark…, em qualquer dos 20 idiomas; as do criador sem ícone); os colchetes
  ficam invisíveis, o texto guardado continua `[pause]`, e o chip nunca quebra de linha.
- **Desfazer e refazer** na barra das cues (`ScriptEditorUndo`), à esquerda, desativados quando não há o que desfazer.
- **"AI can get facts wrong"** (`FactCheckBanner`): centrado na vertical, texto `ink`.

**Revisão da take (6.3):** barra de navegação do sistema (`ReviewToolbar`, `NavigationStack` próprio, fundo escondido sobre o vídeo): voltar, "TAKE 2 OF 3 ✦ ⌄"
como título com menu (takes vizinhas, Suggest best) numa cápsula de vidro, estrela (`star` / `star.fill`) e lixeira numa cápsula à direita.
Refinamento do dono (22/10/2026, canvas "Revisão da take, refinada"): **Play** fica no meio do espaço livre do vídeo, acima dos controles (nunca sobre a
linha do tempo, como no 15 Pro), encolhe e some ao tocar (`Haptics.light`); tocar no vídeo tocando pausa e pisca o sinal de pausa (`ReviewPauseFlash`,
`Haptics.soft`). **Linha do tempo** (`ReviewScrubber`): segurando, a bolinha cresce para 24 pt e um balão branco diz o tempo; um tique a cada segundo
cruzado e um toque firme no início e no fim. **Trocar de take** deslizando: a outra take aparece num esmaecer (o dono rejeitou o cartão que seguia o
dedo, 22/10/2026), com um tique e "Take 2 of 3" por 1,4 s. **Estrela**: pula e solta faíscas amarelas (`BestTakeSparkles`, `HapticPatterns.bestTake`).
**Informações** (`ReviewInfoPanel`): só "● TikTok · 0:10 ›"; o toque abre "1080p · 9:16 · 51s shorter than TikTok’s sweet spot · From script v1".
**Trilha**: a barra do estágio atual se preenche ao abrir e quando avança (`Haptics.success` ao subir). **Save**: gira enquanto salva e mostra ✓ verde
"Saved" por 2,2 s quando o vídeo chega às Fotos (depois de fechar "Ready to travel"). Reduzir Movimento: sem pulos, faíscas nem preenchimento.

**Quick edit:** barra do sistema (`EditorTopBar` como `ToolbarContent`, `NavigationStack` próprio): voltar, "● IN EDIT · AUTOSAVED", **Done** em
`.glassProminent` amarelo com texto `accInk` (`ink2` enquanto carrega). Some em tela cheia. `EditorLayout` usa a altura sob a barra (`EditorHeightClass`:
regular a partir de 696, compacta de 636). Painéis: §29, §31.

**Gravador (Selfie e Studio):** barra de navegação do sistema num `NavigationStack` dentro do `PrompterView` (a revisão fica fora): fechar
(`Button(role: .close)`) no início, **Selfie | Studio** (`ModeSwitcher`, `Picker` `.segmented`) no meio, e o chip do quadro (Selfie) ou a rede do roteiro
("● TikTok", abre Create for) e Remote (Studio) no fim; gravando, o REC ocupa o início; escondida na prática. A caixa do Selfie começa embaixo da barra
(`SelfieScreenMetrics.topBarBottom`); a barra de status é medida fora da pilha. Controles de baixo do sistema onde há um: Voice | Steady
(`ScrollModePicker`), botões redondos `.glass` (`glassIconButton()`), velocidade e sliders como `Slider` com nome e valor (`LabeledSlider`), chips `.glass`
(`.glassProminent` quando ligado). Do Cue: gravar, medidor de voz, última take, rótulos de microfone e formato e o painel de vidro noturno. Sem gesto que
cobre o painel: as ações (`setScrollMode`, `setSpeed`, `togglePlay`, `rewind`) chamam `bar.touch()`. Gravando, os controles recolhidos ficam escondidos do
VoiceOver (`SelfieControlSheet`); a área de toque da folha é contêiner de acessibilidade (`ControlSheet`). **Nenhuma take se perde:** cada take pede
tempo em segundo plano do começo até entrar na biblioteca (`ApplicationGrace`), sair do gravador no meio (ou enquanto a câmera ainda começa) guarda a
take sem a revisão, e uma que o sistema encerrou enquanto o criador parava entra uma vez só; o que ficou em `tmp/take-*.mov` (Cue parou no meio, ou a
biblioteca não a recebeu) volta na abertura seguinte como "Freestyle recording", e o que não toca é apagado (`TakeRecovery`). Se a lista de takes não
pode ser gravada (iPhone cheio), a take não entra e o vídeo volta para `tmp/take-*.mov` com o nome da câmera ("The take couldn't be saved"), onde a
recuperação o acha: nunca um vídeo na biblioteca sem take que aponte para ele.

**Logbook:** título grande (`.large`) com "Catch it now. Write it later."; segurar o botão grava e um toque começa/termina ("Tap the button again to
finish"; onde nada pode ouvir, diz por quê); embaixo dele, "Hold to talk · tap to start". Enquanto ouve, a linha embaixo é só "Listening…", os anéis
seguem a voz e as palavras entram no campo. O campo tem a mesma altura vazio ou digitando (ícone centrado; cresce até 4 linhas só com ideia longa;
cursor amarelo; Return salva). **Digitando** (pedido do dono, 20/10/2026): o microfone grande sai, o título vai para a barra e ao lado do campo fica
um botão amarelo de 56 pt, como no Mensagens: microfone com o campo vazio, seta ↑ que salva no Logbook quando há palavras (o microfone ali parecia o
botão de confirmar). As ideias ficam **por dia** (TODAY, YESTERDAY, o dia da semana, a data; `LogbookDays`), cada uma com "SPOKEN · 0:06 · 2 HR.
AGO" ou "TYPED · 9:40 PM"; a recém-salva entra no topo com contorno amarelo por 1,4 s. Vibração: dois toques ao começar a ouvir
(`HapticPatterns.listen`), um suave ao parar. **Movimento:** ao abrir, o círculo respira uma vez (1,08); sob o dedo afunda (0,92) e volta numa mola;
ao começar a ouvir o microfone pula (1,25) e três ondas saem do círculo e somem, mais longe com a voz mais alta (`LogbookRipples`); digitando, o círculo
encolhe em direção ao botão do lado do campo, que cresce de lá; microfone ↔ seta com um pulo (1,14) e um tick; ✦ Write acende o cartão em violeta e a estrela sai do próprio botão; apagar dá um toque
firme e a lista fecha numa mola. Reduzir Movimento: sem ondas, pulos nem respiração. Uma ideia salva rola para cima do teclado. Siri sem abrir o app (`AddToLogbookIntent`: "Add an idea to Cue" / "Save an idea in Cue", pergunta
"What's the idea?", responde "Saved in your Logbook."). Uma nota aberta por notificação vem ao centro com contorno `acc` de 1,5 pt.

## 23. Ferramentas de IA: o botão faz o que diz

Método: `BugHuntUITests` (opt-in, `TEST_RUNNER_CUE_HUNT_DIR=<pasta>`: toca cada controle e grava o mapa "botão → o que abriu"), `ButtonPromisesUITests` (uma
promessa por teste) e `ScriptToolsDeviceTests` no iPhone. **Falsos alarmes do rastreador:** botões sem nome de 28×36 são o botão interno do Menu da barra;
134×44 é a barra de sugestões do teclado; seleção é traço de acessibilidade (chips "não mudam"); o centro de uma linha de interruptor não é o interruptor; a
última linha fica sob o dock até rolar.

**Reescrita** (`Managers/ScriptAI/Rewrite/`; antes, "Fix grammar" trocava 1309 palavras por 188 e dizia "Grammar fixed"):
- `RewriteChunker`: partes de ~150 palavras (custo por `PromptCost`), cada uma vai sozinha; um roteiro de qualquer tamanho volta inteiro (≈ 5 s por 100
  palavras). "Stronger CTA" só pergunta o último parágrafo; "Fit to time" que precisa crescer 3× usa partes menores.
- `RewriteOutcome`: *Shorter & direct* 45–90% das palavras, *Fix grammar* ±15%, *In my voice* 50–140%, *Fit to time* dentro da faixa ±15%; nenhuma ferramenta
  perde mais da metade dos cues (tradução fora); as mesmas palavras não contam como feito (exceto Fix grammar). Cues inventados (`[Scene: …]`) saem.
- `RewriteRunner`: uma segunda pergunta dizendo o erro em números; quem erra duas vezes **fica como o criador escreveu** (a não ser que tenha feito parte do
  pedido); Fit to time ainda faz uma segunda rodada; uma parte recusada não leva as outras; resposta limitada à janela do modelo. Roteiro já no tamanho não
  chama o modelo.
- Grades de proteção para texto do próprio criador (`permissiveContentTransformations`); recusa vira "Apple Intelligence won’t work on this text. Try
  rewording it, or use another tool." (`ScriptAIError.declined`).
- `RewriteNotice` escolhe o toast pelo que aconteceu (textos em §33): "Shorter · 132 → 53 words", "Closer to 1:00–1:30 · now 0:48", "Already fits 1:00–1:30",
  "No mistakes to fix", "n of m parts left as written", "Couldn’t draft it · Try again" (nada salvo, sem Undo). Roteiro vazio não chama o modelo.

**Ideias do ↻ e do Find inspiration** (`IdeaSuggestionService`, no ambiente; detalhes do pool em §30): ideias do modelo sobre **todos** os assuntos do
criador (`IdeaTopic`, `CreatorProfile.ideaTopics`: os do primeiro voo, os do My Cue Voice e os digitados, com subtemas); lotes de 6 pedidos quando restam
4; guardadas para os mesmos assuntos, idioma e voz (`DefaultsKey.ideaSuggestions`). **Cada lote é diferente** (`IdeaAngle`): listar as ideias já vistas faz
o modelo copiá-las, então cada lote ordena ângulo e assunto ("1. uma lista sobre X; 2. um erro comum sobre Y…") começando mais adiante nos 16 ângulos;
temperatura 1,0; quase iguais caem, dentro do lote também (`IdeaSimilarity.repeats`, `IdeaEcho`: título quase igual, ou duas de título, ângulo e
começo da abertura no mesmo tema; temas diferentes só pelo título; as últimas 60 ficam guardadas); com menos de 4 novas, mais uma volta. **Inspiração** (`IdeaInspiration`): o Logbook e os títulos
recentes vão como "o criador tem pensado em…", e as anotações dele aparecem no ↻ a cada quatro ideias (uma vez por sessão; enviar marca como escrita).
**Gosto** (`IdeaTaste`, §30). O ↻ nunca volta às ideias de partida enquanto há mais a caminho: vira uma rodinha (`isWaiting`). O valor do campo é lido pelo
VoiceOver ("Your idea").
**Medido** (iPhone 15 Pro): 6–10 s por lote, 18 ideias diferentes em três lotes; dia de um criador (`CreatorDayDeviceTests`): ideias 10 s, roteiro 10–16 s,
encurtar 102 → 63 em 6 s, 3 ganchos 3 s, tradução 5 s, YouTube 102 → 563 palavras em 28 s.

## 24. Cartões das listas com profundidade (pedido do dono, não está no quadro)

`cardDepth` (`DesignSystem/Components/CardDepth.swift`, tokens `Palette.Depth`): duas sombras (14 pt de desfoque e 8 de deslocamento; 2 pt e 1,5), **luz na
borda de cima** (violeta `B4A7FF` 38%, some até 60% da altura) e borda fina violeta (`Palette.Depth.edge`, 0,5 pt; quem já tem borda passa `edge: nil`).
Decoração fora do texto: nenhum par de contraste muda. A sombra só existe fora do cartão. **Todos os cartões são `surface` sólido** (Scripts, Takes,
Profile, todas as páginas de Settings, Remote): o translúcido de Settings deixava o céu passar e destoava (pedido do dono, 20/10/2026).
- **Um cartão feito de linhas** (`CardRowPosition`, `CardRowSlice`): cada linha desenha a sua fatia (só a primeira tem luz e cantos de cima, só a última
  sombra e cantos de baixo, `openEdges`). **A posição é passada à linha ao criá-la** (`CardRowPosition(index:count:)`; `SettingsEntryRows`;
  `cardRowBackground(position:)` / `cardRowSurface(_:position:)`): uma `List` avalia cada linha isolada e `listRowBackground` não vê o ambiente, então a
  linha não descobre sozinha. Linha única = `.only`. Raio `Metrics.groupedListRadius` **26 pt** (um pouco maior que o recorte de ~24 pt do sistema; com
  22 a borda sumia nos cantos).
- **Lista de Takes** nativa: `List` `.insetGrouped`, um cartão por dia, `swipeActions` (Share em `Palette.Takes.shareAction`, azul 5,2:1; Delete em
  `dangerFill`), menu de contexto do sistema; a linha é `Button` (a revisão é apresentação, `PresentationService.openReview`).
- **Onde:** Scripts (grupos e Logbook), folha do Logbook (linhas 6/8 pt), Takes, Profile e My Cue Voice, todas as páginas de Settings, as listas das
  perguntas, `GroupedCard` e `SelectableCard` das folhas, Pick the best take. **Fora:** controles das folhas do editor, Privacy & AI data e Translate captions
  (listas do sistema), o dock e o Pro.
- Testes: `CardDepthTests`, `CardRowPositionTests`, `CardDepthCaptureTests` (opt-in, `TEST_RUNNER_CUE_FIDELITY_DIR`).

## 25. O campo do dock: 2 a 5 linhas, 200 caracteres (pedido do dono)

Em repouso, 2 linhas; editando (teclado ou ditado), uma linha por vez até 5 (`ScriptsDock.minLines` / `maxLines`, `isExpanded`; `TextField` `axis: .vertical`,
`lineLimit(2...5)` só editando); passando de 5 rola. Ao sair do teclado (ou enviar, ou apagar) volta em 0,25 s (sem animação com Reduzir Movimento). O dock
inteiro cresce (é o `safeAreaInset`). O editor define a altura também ditando (o texto ditado fica por cima, somente leitura). Botões alinhados à última
linha, 5 pt acima do fundo.
- **Limite de 200** (`IdeaPromptDraft.maxCharacters`, caracteres como o criador vê): poucos tokens em qualquer escrita (≤ 200 em zh/ja), a ideia nunca tira o
  lugar do roteiro. **O que não cabe não é escrito; o que já estava nunca é cortado** (`IdeaPromptDraft.limited(_:replacing:)`, todo caminho passa por
  `IdeaDraftService.text`; ditado: `DictationSegment.hear(_:limit:)`, termina quando enche).
- **Contagem** ("184 / 200", mono 10,5 pt, `ink`; `warnText` cheio) a partir de 160 (`counterStart`); `Haptics.soft` ao encher; VoiceOver "184 of 200
  characters".
- Testes: `IdeaPromptDraftTests`, `DockGrowthUITests`.

## 26. Gravação e espelhamento da tela: a marca do Cue no plano grátis

Decisão do dono (23/10/2026): **Pro** não muda nada (já pagou); no **grátis**, a prévia continua visível e tocando, com a marca do Cue por cima,
para que uma gravação de tela saia assinada (a exportação é o vídeo limpo). Nenhum player para.
- **Detecção** (`SceneCaptured`): o `isSceneCaptured` do SwiftUI (traço `sceneCaptureState` da cena; `UIScreen.isCaptured` será descontinuado), lido ao
  aparecer. A gravação do próprio Cue não marca a cena.
- **Onde:** revisão da take, prévia e tela cheia do Quick edit, câmera do Selfie e da prática (a área inteira da câmera). Pôsteres, capas e quadros da
  linha do tempo ficam como estão.
- **Marca** (`CaptureWatermark`, `captureWatermarked(_:markY:)`, lê o plano no `StoreManager`): "✦ CUE STUDIO" em SF Mono 13 semibold, branco a 70%
  com sombra, centrada a três quartos da altura; na câmera, no meio do espaço livre entre o texto e os controles (`captureMarkY`). Sem animação, sem
  toques. É o nome da marca: como logotipo, não tem mínimo de contraste (WCAG 1.4.3), e a sombra a deixa visível em imagem clara.
- **AirPlay de vídeo** continua desligado (`allowsExternalPlayback = false`): ele não marcaria a cena, e a marca não apareceria.
- **Gravações e exportações:** nada muda.
- **Limites:** é detecção, não bloqueio; o primeiro quadro pode entrar sem a marca; câmera apontada para a tela não é detectável.
- **Testes:** `ScreenCaptureUITests` (grátis assina e toca na revisão, no editor e na tela cheia e na câmera durante uma take; Pro não muda),
  `ExportAccountingTests`; `-uiTestSceneCapture` + `SimulatedSceneCapture` (o Simulator não marca a cena). **Falta no aparelho:** Gravação de Tela e
  Espelhamento de verdade, no grátis e no Pro.

## 27. Notificações, lembretes e introdução de ferramentas

Sistema completo em `NOTIFICATIONS.md`. Na interface:
- **Settings › Notifications** (`NotificationsSettingsView`, redesenho do dono 22/10/2026: curta e direta, a versão B do canvas; valor "Off" ou
  "Reminders: n"): no topo, **o interruptor do iOS** (`NotificationPermissionRow`): sino em contorno `accText` que balança de leve a cada ~5 s enquanto
  está desligado; "Notifications are off · Cue can’t remind you yet." / "Notifications are off in iOS · Allow Cue in iOS Settings." / "Notifications
  arrive quietly · Without a banner or a sound." / "Notifications are on · Cue only reaches out when it helps." (com um ✓ verde no sino). Ligar sem
  nunca ter sido perguntado traz a pergunta do iOS, e o sim **liga tudo junto** (`NotificationService.allowEverything`): o sino toca, os interruptores
  de baixo acendem um a um com um tique cada (`HapticPatterns.notificationsOn`, `NotificationsCascade`) e a rotina abre seus dias. Qualquer outra
  mudança abre o Cue nos Ajustes do iOS; voltar de lá liberado depois de um não também liga tudo. **From Cue**: dois interruptores (`NotificationGroup`):
  **Help me finish what I start** ("When a script or video is waiting.") e **Tools and news** ("Now and then, something new for you."); rodapé "At most
  one a day, never at night. Your reminders always arrive." **Creation routine**: **Remind me to create**, que abre os dias (chips `acc`/`accInk` e
  `surface3`/`ink`, chegando em cascata; tique e mola a cada toque; o último dia não sai) e **Time**. **Your reminders** (toque edita, deslizar remove; Set,
  Kept in Cue, Due). Sem ícones nas linhas. Não são mais escolhas: os lembretes do criador (sempre chegam), quiet hours (21h–9h fixas), pausa e títulos nas
  notificações (nunca: "your script"). Em Debug, uma seção DEBUG.
- **Remind me…** (••• da página e menu de um vídeo): `ReminderSheet` (`fittedSheet`): Tonight (até 19:30), Tomorrow, **Pick a date and time** (`DatePicker` +
  **Set reminder**), nota de quiet hours, lembretes marcados com ✕. Toast "Reminder set · Tomorrow 10:00 AM" só quando o sistema aceitou.
- **Introdução de uma ferramenta** (`FeatureIntroSheet`): ícone `aiText` em azulejo `surface2`, nome, benefício, o que ela usa ("Free. Nothing changes until
  you choose."), **Try it**, **Not now**, "Don’t suggest this" em `ink2`. Try it abre a ferramenta (Quick edit direto no painel: `EditorTool`,
  `QuickEditViewModel+Opening`; Adjust já em Skin Smoothing, `adjustOpensOn`).
- **Convite** (`NotificationInviteSheet`, mesmo desenho): sino `bell.badge`, a pergunta, "One notification when something is waiting, at most one a day. You
  can change it in Settings.", **Allow notifications** (só ele traz a pergunta do sistema) e **Not now**.
- Contraste: `PaletteContrastTests.theNotificationSheetsReadOnTheirNight`.

## 28. Notas dos testes de UI

- A última linha de uma página fica "tocável" atrás da tab bar e o toque cai na aba: role antes (`XCUIApplication.scrollAboveTabBar`).
- A prévia do Quick edit não toca no Simulator (a composição falha com -12784): os testes de UI conferem Play/Pause; o tempo andando só no aparelho
  (`EditorUITests.testPlayPlaysAndPauseHoldsThePlayhead`). O Simulator do iOS 27 não toca **nenhuma** composição de vídeo, nem a do próprio AVFoundation
  (-11800 com -12784 por baixo; o item toca sem ela e exporta), por isso o vigia de falha do item (`QuickEditPlayer.watch`) fica desligado ali: no
  aparelho, um item que falha mostra "Try again"; no Simulator a prévia segue em branco e as ferramentas ficam acesas.

## 29. Text style e Caption style (Quick edit)

- **O painel cresce** (`EditorPanelContainer(expansion:)`): alça (decorativa) e botão de expandir no cabeçalho (44 pt, "Expand panel" / "Collapse panel");
  arrastar o cabeçalho 24 pt faz o mesmo. Expandido, o vídeo vai ao menor tamanho do editor (`EditorLayout(panelIsExpanded:)`); a escolha vale para os dois
  painéis enquanto o editor está aberto (`stylePanelIsExpanded`). Altura normal de um painel `.full`: metade da tela (330–420 pt). No iPhone SE o painel é
  folha e o botão troca as duas alturas. O conteúdo para 18 pt acima do Home Indicator (`Metrics.editorStylePanelBottomClearance`) e some em degradê
  (`scrollEdgeEffectStyle(.soft)`).
- **Abas na largura toda** (Presets · Font · Color · Motion), 44 pt, com pelo menos 16 pt entre os nomes (sem esse espaço, rolam de lado); campo e abas
  fixos, só o resto rola; trocar de aba volta ao topo (`contentKey`). Em tamanhos de acessibilidade só as abas ficam fixas: o campo rola com o resto
  e os controles da aba vêm antes de "Style applies to". Cores (`PanelSwatches`) de 34 pt, a paleta em linhas (§44), segmentos de 38 pt.
- **Digitando** (teclado no campo): só cabeçalho, campo e abas sobre o teclado (`EditorLayout.typingPanelHeight`, 180 pt); o vídeo fica com o resto
  e mostra o texto mudando. Tocar numa aba guarda o teclado e mostra os controles dela (como no CapCut). Com texto grande (xxLarge ou
  mais) isso não caberia: os controles ficam e rolam sobre o teclado (`TextStylePanel.hidesControlsWhileTyping`).
- **Presets do Caption style em grade** (colunas de 104 pt: três por linha no iPhone), todos à vista, sem rolar de lado.
- **Escopo só do visual:** "Style applies to" **This title | All texts · N** só em Presets, Font e Color ("Words, timing and motion stay with each text.");
  em Motion: "Motion and timing change only this text".
- **Apply this style to captions** (`PanelButton` no fim de Presets, Font e Color, quando há legendas): pergunta antes (alerta: o que troca, o que fica, e
  a nova cor de destaque se a atual sumiria, `CaptionAccent.standingOut`); copia **uma vez** (`CaptionStyleCopy`), um passo de desfazer, toast "Captions use
  this style" com Undo; nada fica ligado. A cópia mora em `CaptionSettings.customLook`: o Caption style a mostra como **Custom** ("Custom style copied from a
  text. Pick a preset to replace it."); escolher um preset a substitui. Prévia e exportação iguais (`CaptionCollectionRenderer`).
- **`CueSlider`: só o polegar arrasta** (44 pt de toque em volta); um toque na trilha leva o polegar até lá. Antes um arraste para rolar o painel por cima
  de um slider mudava o valor. Vale em todo o app.
- Contraste: `PaletteContrastTests.theEditorsPanelReads` (`ink`/`ink2` sobre `fill`).
- Testes: `CaptionStyleCopyTests`, `CaptionAccentTests`, `QuickEditCaptionStyleCopyTests`, `QuickEditTextStyleTests`, `EditorLayoutTests`,
  `CaptionCollectionRendererTests`, `CaptionCollectionExportTests`, `TextStyleUITests` (6,1" e SE).

## 30. Find inspiration

Cada inspiração é um brief (`IdeaBrief`): título, **ângulo** (instrução curta) e **frase de abertura** (sugestão para dizer, nunca afirmação sobre o criador:
nada de história, resultado, número ou tendência inventados).
- **Scripts vazio** (`Screens/Scripts/Empty/`, `ScriptsEmptyState`): constelação acima do título a 60%, "How do you want to start?", "Pick the easiest way to
  get your words flowing." e dois cartões: **Write it yourself** e **Import a script**. Quem já teve roteiros (`LibraryHistory`,
  `DefaultsKey.hasEverHadScript`) vê "Ready for the next one?", sem ilustração. **Cabe entre o título e o dock sem rolar** (`ViewThatFits`: com a
  constelação, sem ela, e só então rolando); contêiner de acessibilidade.
- **Import a script** (`ImportScriptSheet`): um PDF sem camada de texto (escaneado) é lido como fotos, só as 10 primeiras páginas (cada uma vira uma
  imagem de 2000 px na memória), desenhadas fora da tela principal (`DocumentImportService.pageImages`, `ScannedPDFPages`); com mais páginas, "Pages
  read: 10 of 23" fica embaixo do texto lido.
- **Lâmpada no dock** (`InspirationDockButton`, `CueIcon.findInspiration` 20 pt, `FindInspirationSheet.icon`: lâmpada com uma órbita que passa
  atrás dela, mais suave, e na frente; também na nota "Starter ideas" e na introdução da ferramenta): à direita do My Cue Voice na linha 1, **em qualquer
  estado de Scripts**, contorno amarelo em vidro discreto, 44 pt, "Find inspiration"; dobra com a linha. Sem largura, o chip da rede perde o "For" e depois os
  chips rolam com a lâmpada fixa. Sem dica de primeiro uso.
- **A folha** (`Screens/Scripts/Inspiration/`; abre pela lâmpada, por + › Let Cue draft it e pela notificação de ideia): título, "Ideas to start from.",
  chips de tema ("All my topics" e os salvos, escolhido em violeta; "Topics" abre o editor do My Cue Voice), **um cartão** violeta (TEMA ·
  SUBTEMA · TIPO, título, YOUR POINT OF VIEW, OPENING LINE), e embaixo, fixos, **Another idea** (círculo de vidro ↻ de 54 pt à esquerda; não sobe
  e desce com o tamanho da ideia; deslizar no cartão também troca) e **Start with it** em amarelo, a linha que diz que a ideia vai para o campo, e
  "✦ Draft it now". **Arrastar:** o cartão segue o dedo para o lado, inclinando (1° a cada 24 pt); passou de 90 pt, um clique (`Haptics.rigid`) e,
  soltando (ou jogando), ele voa para aquele lado e vem a próxima; antes disso volta numa mola. O ↻ gira a cada troca. **Vibração:** cinco ticks que
  enfraquecem junto com os brilhos; Start with it = toque firme + um suave quando a ideia cai no campo; Draft it now = a decolagem do dock.
  **Troca de ideia:** o cartão que sai vai para a esquerda e se desfaz em blur (−28 pt, 95%); 14 brilhos de quatro pontas acendem um
  após o outro em volta da borda e se afastam ~7–18 pt (0,65 s; violeta, branco e um amarelo; `InspirationStarBurst`); o novo entra da direita (+36 pt,
  97%) numa mola (`CueMotion.inspirationTurn`); as linhas sobem 8 pt saindo do blur, uma a cada 60 ms; uma faixa de luz cruza o cartão uma vez (0,8 s,
  `inspirationSweep`). Reduzir Movimento: só fade de 0,2 s. Estados: esqueleto, "Finding more
  ideas…", falha com **Try again**, sem temas, sem Apple Intelligence (ideias de partida para escrever à mão). As ideias são escritas no idioma da
  interface: se o modelo não o escreve, ele nem é pedido e a nota diz "Apple Intelligence can’t suggest ideas in {idioma} yet. Here are starter ideas to
  write yourself."; com a Script Language num idioma que o modelo não escreve, as ideias vêm, a nota diz o motivo + "These ideas are yours to write." e
  o botão é **Write it yourself** (§8).
- **Do cartão ao roteiro:** *Start with it* põe o brief no campo em três linhas (título / "Angle: …" / "Open with: “…”", ≤ 200 caracteres, corta em fim de
  palavra), cursor no fim, mantém formato, rede e voz; se havia texto, toast com **Undo**. Só vai ao modelo a parte do brief que o texto ainda diz
  (`IdeaBrief.standing(in:)`: 70% das palavras do título, 60% do ângulo e da abertura). *Draft it now* escreve sem tocar no campo. Com o brief, o roteiro
  abre com a frase e segue o ângulo (`ScriptPromptBuilder`; a checagem da voz aceita a abertura dada).
- **Motor** (`IdeaSuggestionService`, um pool para a folha e o ↻): o próximo cartão sai do cache sem chamar o modelo; cada filtro reabastece em lotes de 6
  com 4 restando; temas, idioma ou voz mudados cancelam o pedido; **o roteiro vem primeiro** (`IdeaRequestPriority`). Ideias de partida: 6 por tema do
  primeiro voo, todas com brief, e 7 modelos para temas digitados ou do My Cue Voice. **Gosto** (`IdeaTaste`, entre sessões, qualquer idioma): passar −0,35,
  usar +1,5, enviar pelo card +3, roteiro escrito +4 (o ângulo só conta se ainda estava no texto); no máximo metade do lote para os ângulos preferidos, o
  resto para os menos vistos.
- **Briefs fracos** (`IdeaSpecificity`): ângulo que só repete o título e título de palavras feitas ("5 tips") — uma fraqueza vai para o fim do lote, as
  duas descartam. O bordão do criador sai do começo da frase de abertura (`CatchphraseTrim`: com a voz, as seis começavam iguais).
- O ↻ do campo e a lâmpada tiram do mesmo pool (o ↻ troca a sugestão sem abrir nada).
- **Medido** (`InspirationDeviceTests`): lote de 6 briefs 8,6 s (6 títulos: 8,3 s); nenhum cortado, nenhuma abertura com afirmação; o roteiro abriu com a
  frase em 2 de 2. **Falta no aparelho:** a explosão de estrelas, o foco do teclado depois de Start with it, o VoiceOver do cartão, uma rodada maior.
- Contraste: tokens `inspirationCard`, `…Glow`, `…Border`, `inspirationChipOn` em
  `PaletteContrastTests.findInspirationReadsOnItsCardItsChipsAndItsWaysIn`; rótulos de seção em `ink2` (`inkHint` dava ~4,2 sob o brilho).

## 31. Background (Quick edit)

Layout do `BackgroundPanel` (valores, prévia, exportação e desfazer são os de sempre). O motivo: "Color key" escondido em Advanced fazia o Cue só trocar o
verde/azul, e num vídeo sem tela verde Color "não fazia nada".
- **Cabeçalho** fixo com Reset e ✓; subtítulo com alcance e estado ("Whole take · Blur behind you", "This clip · Color on the green or blue screen", "Whole
  take · As recorded"; `backgroundSubtitle` / `backgroundSummary`).
- **Nota de alcance** (`backgroundScopeNote`), só quando existe: clipe usando o fundo do take; clipe com fundo próprio (só aí o Reset aparece); take com
  clipes que têm o seu.
- **Behind you:** Original · Blur · Color · Image e só o controle da escolhida (Blur strength, cores, foto; em Original, uma linha).
- **Cutout** em cartão próprio (`Palette.Editor.panelCard`): **Automatic | Green or blue screen** com uma frase de cada; "Can't find people here" no
  Automatic. Em tela verde/azul: **Screen color** (Green | Blue, "Your own color" quando escolhida à mão), "Pick the screen's color", e **Tolerance, Edge,
  Spill** recolhidos em "Fine-tune the cutout" ("· adjusted" quando mudados), cada um com o que faz (`ChromaKeyCube`). Com Original: "Used once a
  background is picked".
- Última linha: "Changes show in the preview and are saved as you make them. ✓ closes the panel."
- Continua `.medium` (não expande: depende da trilha e da agulha), com a folga do Home Indicator (`EditorPanel.scrollsClearOfHomeIndicator`).
- Contraste: `PaletteContrastTests.theBackgroundPanelsCutoutCardReads`; `PanelAdvancedButton` usa `ink2`.
- Testes: `QuickEditBackgroundPanelTests`, `BackgroundPanelUITests` (6,1" e SE), `BackgroundCompositionTests`, `BackgroundDeviceTests`.

## 32. A primeira viagem: o guia do primeiro vídeo, em dicas

Seis passos, **uma dica de cada vez, no lugar e na hora certos** (HIG "Teach through interactivity"; NN/g: tutoriais em cartões não ajudam). Sem cartão fixo
nem faixa (o dono pediu algo orgânico).
- **Passos** (`VoyageStep`): Write your first script · Practice with the teleprompter · Record a take · Pick your best take · Polish it (legendas, Clean Up,
  opcional) · Share to your universe. **Lidos do que o criador tem** (`VoyageProgress`, puro); nada travado; a dica é a do primeiro que falta; o primeiro
  compartilhamento conclui. Marcas próprias em `VoyageMarks` (`DefaultsKey.firstVoyage`).
- **Para quem:** só quem ainda não compartilhou (`VoyageStage.notNeeded` para os outros). "Hide guide" guarda até Settings › Personalize › Getting started ›
  "First video guide". "Delete my Cue data" recomeça.
- **Dica flutuante** (`VoyageFloatingTip`): 10 pt acima do dock (Scripts) ou da tab bar (Takes); espera 1,2 s de tela quieta, entra em 0,40 s (opacidade,
  10 pt, 0,97 → 1; Reduzir Movimento só aparece). O botão leva ao lugar (`VoyageNavigator`: Get an idea, Try it, Record, Compare/Watch, Add captions, Share).
  Fica até o passo mudar ou o ✕. A dica do My Cue Voice espera por ela. O dock nunca muda de lugar.
- **Dicas no lugar** (`VoyageTipCard`): na página do roteiro sobre o Record (primeiro, uma vez, a do primeiro rascunho: "A first draft. Yours to change." ·
  **Edit**; depois a do treino com a duração: **Try it**), na revisão (**Compare** com mais de um take), no editor acima das ferramentas (**Add captions** ·
  Skip) e no "Share to universe". **"★ 2 OF 6"** abre `VoyageStepsSheet` (feitos, próximo com Start, seguintes, Hide guide).
- **O ✕ vale pela sessão** (a do primeiro rascunho, uma vez só).
- **Aviso de passo feito** (`VoyageAnnouncer` em `MainView`, `VoyageNotice`): toast com toque suave ao sair da câmera e da revisão, sem outro toast na tela:
  "✓ Rehearsed · Next: record", "✓ Recorded · Next: pick a take", "✓ Captions on · Next: share", "✓ Your first star is out there". Só quando o "Next" é
  verdade; cada passo uma vez.
- **Telemetria** (`VoyageTelemetryEvent`, `cue_voyage`, só com "Help improve Cue"): dica vista, botão, ✕, passo feito; nunca texto.
- Vistas do Cue, não TipKit (a ordem e o estado são da viagem; TipKit duplicaria e atrapalha os testes).
- Contraste: `PaletteContrastTests.theFirstVoyageReadsOnItsTipsAndItsCard`.
- Testes: `VoyageProgressTests`, `VoyageNoticeTests`, `FirstVoyageServiceTests`, `FirstVoyageUITests` (UISmoke); só com `-uiTestVoyage`.

## 33. Você cria. O Cue facilita (pedido do dono)

A IA é **o ponto de partida**: quem cria e melhora é o criador; o Cue dá a partida, sugere e aprende com o que ele escreve.
- **Regras de texto:** o que a IA entrega é um **rascunho** (*draft*, nunca *write*/"the script"); sempre o próximo passo humano ("make it yours", "fix any
  word", "you decide"); "aprende com você" só onde é verdade; nada de "perfeito"; **curto** (alemão e francês crescem ~30%). "draft" está no glossário do
  `LOCALIZATION.md` §2.
- Exemplos em uso: "Drafting in your voice", "Couldn’t draft it · Try again", "+ › Let Cue draft it", "Start with it", "Draft it now", Improve script
  ("Cue suggests. You decide."; "New version", "In your voice · …", "Shorter · 132 → 53 words"; vazio: "Write a few lines. Cue builds on them."), "Saved · Cue
  learns from it", "Use my voice in drafts", "Cue drafts the lines. Fix any word."
- **Aprende de verdade** (`DraftLearningService`, `DraftEdits`, `CueDraft`): cada rascunho do Cue guarda as palavras como chegaram (até 30,
  `DefaultsKey.cueDrafts`). Quando o roteiro é **gravado** com pelo menos 20% e 8 palavras mudadas (sem cues, caixa, pontuação), o começo da versão gravada
  vira exemplo (fonte "Your edits", os últimos três; não conta como aprovação) e o toast "Cue learned from this" tem **Undo**. Rascunho gravado como veio
  espera; cada um ensina uma vez; "Delete my Cue data" apaga. Testes: `DraftLearningTests`.

## 34. Direção de movimento (pedido do dono, não está no quadro)

Mais expressão nas cenas de descoberta e celebração, discrição no roteiro, na gravação e na edição; um movimento principal por vez.
- **Troca de capítulo do onboarding** (`OnboardingView`, `DepthTransition`, `CueMotion.chapterExit/chapterEnter/hazeShift/skyShift`): três profundidades em
  três velocidades. O capítulo que sai recua (×0,97, 8 pt para cima, desfoque 4 pt) em 0,22 s acelerando; o próximo chega 0,1 s depois de perto do vidro
  (×1,03, 14 pt abaixo, desfoque 4 pt) na curva da luz (0,55 s, `(0.16, 1, 0.3, 1)`). A névoa (`BgWash`) passa para a do próximo capítulo em 0,8 s e o céu
  sobe 24 pt em 0,95 s. Reduce Motion: só fades (0,2 s), céu parado.
- **Céu** (`StarfieldMath`, `StarfieldView`): cada bloco de estrelas tem as suas (`tileSeed`, `tileRow`: o bloco as mantém enquanto desce); as camadas balançam
  de lado ±2, ±4 e ∓7 pt em 97, 71 e 53 s (a mais perto para o outro lado); as nebulosas andam numa curva lenta (±20 pt, 1 → 1,16, períodos diferentes).
  Mesmo custo de desenho; tudo função do relógio do app, sem saltos ao trocar de aba.
- **Resposta ao toque** (`PressResponse`, `CueMotion.pressIn/pressRelease`): botão sólido afunda e escurece 8% na hora (mola de 0,16 s, sem quique) e volta numa
  mola de 0,34 s que passa um pouco do lugar; nunca fica transparente. Afunda 3% (50 pt ou mais), 5% (compactos) ou 6% (ícones). Botões de Liquid Glass
  (amarelo e secundário de `CueStudioButtonStyle`, ícones de vidro) ficam só com o `.interactive()` do sistema; os amarelos do onboarding usam a mesma
  resposta. Reduce Motion: só escurece.
- **Relógios que param quando ninguém vê** (`MotionScreen`, `AmbientTimeline`, `WelcomeChapter`, `YearInReviewView`): fora da tela, rolado para fora ou com o
  app inativo o relógio para (`MotionClock`) e continua do mesmo quadro. Todo laço ambiente usa `AmbientTimeline` (linha de leitura, partículas do horizonte,
  brilho dos botões, aura da IA, constelação do dock, shimmer, "Drafting in your voice", READY de Takes, núcleo YOU e mininúcleo, planeta do Pro,
  "Opening your edit", universo do 1.2). As vibrações do 1.1 são batidas do relógio da cena; os slides da retrospectiva não avançam com o app fora.
- **Gravação calma** (`ReadingGuide.isCalm`, `HorizonLine.breathes`): com a câmera gravando, a linha de leitura não respira e as partículas somem; o brilho que
  acompanha a voz continua.
- **Ritmos próprios:** cada estrela que pisca tem o seu ciclo (7 s ±12%, `StarfieldMath.twinkleRhythm`). Os planetas do 1.2 e da galáxia YOU do 1.3 andam mais
  rápido na frente e mais devagar atrás, 10% maiores e mais claros na frente, menores e 20% mais apagados atrás (`OrbitMotion`). O universo do Perfil (9.2)
  continua linear, como o quadro.
- **Pular uma história** (`MotionScreen` com `skippable`, `ProOpening`): o toque leva tudo ao estado final em 0,3 s (`CueMotion.skipSettle`). Retrospectiva: o
  slide recua e o próximo avança (`DepthTransition`).
- **Luz que soma** (só no 1.3; `GalaxyPainter`): halos, braços, estrelas, bojo e cruz de luz das galáxias usam `.plusLighter` (`ANIMACOES.md` §5). Planetas,
  órbitas e núcleo continuam sólidos.
- **Celebrações** (`StoryCover`, `CueMotion.storyIn/storyOut`): a primeira estrela e o marco entram em fade sobre a revisão do take (0,35 s, curva da luz) e saem
  em 0,25 s; de "Ready to travel" para o send-off a capa troca sem descer e subir. Depois da história, primeira estrela, send-off e marco desenham a 30 fps e
  param com o app inativo.
- **Toasts** (`AnyTransition.toast`, app e editor): entram descendo 8 pt em 0,25 s e saem em fade de 0,2 s (`motion/README.md`).
- **Ícones que trocam** (`symbolSwap`, `CueMotion.symbolSwap`): play/pause do gravador e do editor, o olho dos cues, o microfone do Logbook, a conexão do
  controle remoto e a estrela de melhor take (com um pequeno pulo) usam o `replace` do sistema.
- **Chips e cartões** (`CuePressButtonStyle`, `.cuePress` / `.cuePressCard`): chips de filtro (Scripts, Takes, voz, blocos, painéis do editor) e cartões que são
  um botão só (planos do Pro e do Perfil, caminhos da biblioteca vazia, presets do editor) afundam como os botões (cartão 1,5%).

## 35. O texto do primeiro voo e o Voice Following da prática (15 de outubro de 2026; pedido do dono)

O primeiro voo explica o app para quem chegou procurando um teleprompter: preparar o roteiro, ler olhando para a câmera, gravar no app, legendas
automáticas, editar o take e compartilhar. Telas, fluxo, universo e animações são os mesmos; mudou o texto de 1.1 a 1.7 (inglês e os 20 idiomas; a lista
completa e o roteiro estão em `ONBOARDING_COPY_MEMORY.md`), e a prática passou a demonstrar o que promete.

- **Texto** (onde diverge do quadro, vale este): 1.1 "A teleprompter made for your creative universe." e a linha do que o Cue faz; 1.2 "What do you
  usually talk about?"; 1.3 "Where will you share your videos?", **Choose a platform** / **Continue with {rede}**, "CHOOSE ONE PLATFORM" e "SAFE ZONES ON/OFF" conforme a
  rede (antes dizia ON sempre); 1.4 "Your first script. Ready to read." e **Try the teleprompter**; 1.5 "Let the text follow your voice." e três recusas
  (microfone e câmera, só microfone, só câmera); 1.6 o cartão diz o que fazer e o que move o texto ("Tap play and wait for the count. Then read out
  loud: the text follows your voice.", "Nothing is recorded."), **Record my first video** e **Explore Cue first**; 1.7 "Your first
  video. Your first star.", **Explore Cue** e **Edit my video**. Os rótulos dos capítulos: YOUR TOPICS, YOUR FIRST VIDEO, YOUR FIRST SCRIPT, CAMERA &
  VOICE. Nenhum travessão em texto novo.
- **Roteiro fixo** (decisão do dono: sempre o mesmo, nada de IA no onboarding): `OnboardingScript.practice(followsVoice:)`, título "From idea to video",
  gancho, corpo e CTA do dono. A 1.4 o mostra chegando no console com o ritmo do quadro (`MessageTimeline`); o tamanho das palavras é o maior que cabe
  (21, 19, 17, 15 ou 13 pt, `ViewThatFits`), para o cartão, a cápsula e o botão ficarem numa tela também em alemão; japonês, chinês e tailandês chegam por
  palavra do dicionário (`OnboardingWords`, que também quebra o título da 1.1 nessas línguas, antes uma linha só que saía da tela). A duração é medida
  (`readingSeconds`, 150 palavras por minuto): **24 s** em inglês. O cartão não mostra mais o tema (o roteiro não é sobre ele). `OnboardingWritingNotice`,
  `MessageSkeleton`, o botão "Use a ready-made message" e o roteiro embutido por tema saíram.
- **Voice Following na prática** (`PrompterViewModel+Practice`): ao abrir, com o microfone liberado a sessão passa para **Voice Following**; sem ele, Steady.
  O reconhecimento começa a se preparar ali mesmo, durante a apresentação, antes do toque no play. O modo é **só desta sessão**: `practiceChoseScrollMode`
  faz `rememberReadingLayout(includingScrollMode: false)`, então a preferência salva do criador não muda; se ele escolher um modo depois (no gravador),
  vale a escolha. "Record my first video" continua com Voice Following naquela gravação.
- **O estado de verdade** (`PracticeVoice`, cápsula `PracticeVoiceStatus` sob a caixa e a linha do cartão): "Getting ready to follow your voice"
  (modelo carregando), "Getting Voice Following ready · 40%" (baixando), "Voice Following is on" antes do play, "Waiting for your voice" / "Following your
  voice" lendo, "Moves while you talk" quando o iPhone não segue as palavras daquele idioma, "Microphone off · Steady scroll" sem microfone.
- **O roteiro diz só o que é verdade** (`matchPracticeScript`): sem microfone, ou quando o reconhecimento diz que não segue o idioma, a prática troca para o
  corpo sem "follows my voice", só enquanto o texto ainda está escurecido (antes do texto andar). Preparando ou baixando, fica a versão com a frase (é o que
  vai acontecer); se o download falhar no meio da leitura o texto não troca, e a cápsula e o aviso dizem o que houve.
- **A linha espera a voz** (vale para todo Voice Following, prática e gravador): `play()` zera a previsão, descarta o que foi ouvido antes (palavras ditas na
  contagem) e o texto só anda depois do **primeiro trecho reconhecido** desde o play (`heardFirstWord`); palavras ouvidas com o texto parado não movem nada.
  Sem reconhecimento por palavra o texto anda enquanto a pessoa fala, mas só depois de um início de fala de verdade (`SpeechOnset`: 0,25 s de som acima da
  sala em 0,6 s), então um clique, uma batida ou uma tosse não o movem. Steady (sem microfone) não ouve ninguém: rola no ritmo definido depois do READ!,
  e a prática diz isso.
- **Testes:** `PrompterPracticeTests` (modo da sessão sem mudar o salvo, versão do roteiro sem microfone e sem idioma, contagem e silêncio sem mover a linha,
  primeira palavra move), `PrompterViewModelVoiceTests` (silêncio longo, ruído e picos antes da primeira palavra, primeira palavra atrasada em deslize,
  palavras antes do play, pico vs. voz sem reconhecimento), `SpeechOnsetTests`, `OnboardingScriptTests`, `OnboardingUITests` (estados da prática com
  `-uiTestVoiceFollowing listening|preparing|unavailable` e microfone negado). Sem a correção, quatro dos testes novos falham.
- **Medido nos iPhones** (`VoiceFollowingLatencyTests`, gravações dos 20 idiomas tocadas pelo caminho de áudio da câmera, 15/10/2026; iPhone 18 Pro
  Max e iPhone 15 Pro, 5 de 5 em cada): o texto **nunca andou antes da fala** em nenhum idioma, nem com ruído de sala (−45 e −36 dBFS); todos seguidos
  até o fim, nunca mais de 2 palavras à frente; palavra → texto p50 de −0,28 a 0,49 s (como na tabela do `LOCALIZATION.md` §5). O custo: a primeira
  movimentação espera a primeira palavra reconhecida, de 0,85 s (holandês) a 1,73 s (turco) depois do início da voz, 0,98–1,0 s em inglês, os dois
  aparelhos com diferença de no máximo 0,03 s (antes, a previsão começava com a voz). Que a linha fica parada com alguém em silêncio e anda natural ao
  ler só se confirma com uma pessoa falando no aparelho.
- **Contraste:** medido nos pixels das capturas (`HandoffCaptureTests.test1_FirstFlightCopy`, inglês, alemão e japonês): o menor texto novo fica em
  4,9:1 (rótulo BODY, já existente), a cápsula da prática em 15,7:1, "24 SEC" em 11,5:1; `Palette.Flight.quietInk` (o mesmo token da branch de movimento)
  substitui `Color.white.opacity(0.8)` e `Flight.ink.opacity(0.78)` na prática e entra em `PaletteContrastTests`.

## 36. Refinamentos tela a tela (15 de outubro de 2026; pedido do dono)

O dono revisou no iPhone, tela a tela, o primeiro voo, a primeira estrela, o Pro e Your universe. Onde diverge do quadro, vale este.

- **O rastro das estrelas** (`StarRibbon`, `DesignSystem/Effects`): toda estrela que voa deixa o mesmo rastro: o caminho dos últimos 0,32 s como uma fita
  contínua que afina, apaga e esfria do branco ao dourado, sobre uma cópia larga e desfocada; a cabeça é um núcleo branco com halo e uma cruz que gira.
  Usam: 1.1 (`WelcomeStarPainter`), a estrela que entra na 1.2 (`StarTrail`), a luz que leva o tema à órbita (`TopicBirthPainter`, nas cores do tema), o
  cometa da 1.7, a estrela que vira o planeta do Pro e as luzes que nascem os planetas em Your universe.
- **1.1:** os pontos do C piscam ao serem tocados (clarão de 0,9 s) e depois respiram e cintilam, cada um no seu ritmo (`WelcomeScript.shine`/`glint`; o
  relógio segue depois da história, parado com Reduzir Movimento); o sexto ponto respira em amarelo. Ao ser tocada, cada palavra (TELEPROMPTER, AUTO
  CAPTIONS, ✦ AI SCRIPTS) vira uma cápsula **amarela sólida** com letras pretas (`accInk` sobre `acc`) e fica assim. Título "A teleprompter made for your
  creative universe."; **Get started** é o único botão, 82 pt acima da borda: **não há "I already use Cue" nem Skip** em nenhum capítulo (todo criador novo
  faz o primeiro voo).
- **1.2:** "What do you usually talk about?"; o tema de estilo de vida é **Daily routines** (o que a IA lê: "daily routines and daily life").
- **1.3:** as galáxias são desenhadas no quadro, mas encaixadas na faixa entre o título e "CHOOSE ONE PLATFORM" (`VoyageFit`: 14 pt de folga, de ×0,8 a
  ×1,12 conforme cabe, nunca sob as palavras); cada galáxia das redes é ×1,25 do quadro e a do criador ×1,12, sobre o próprio centro (nomes e anéis se
  afastam junto). Os chips ficam 36 pt acima do botão.
- **1.5:** a arte VOICE / CAMERA é o quadro de 390 × 200 escalado pela largura da tela e centralizado (até ×1,15, num Pro Max ≈ ×1,13). As linhas de
  permissão têm o fundo da caixa; o próximo passo é o **Allow** de borda amarela.
- **1.6:** caixa de 310 pt (o quadro e 30% a mais abaixo da linha; menos numa tela baixa, nunca menos que 238); a cápsula da voz (`PracticeVoiceStatus`,
  44 pt, texto de 15 pt) tem uma onda de 9 barras (`PracticeVoiceWave`) que segue o nível do microfone enquanto ouve a voz e, esperando, uma ondulação
  lenta; a borda acende em amarelo com a voz. O cartão fica 58 pt abaixo da caixa. **Record my first video** sobe depois do play; **Explore Cue first**
  está sempre lá. A etiqueta "✦ PRACTICE · NOT RECORDING" é sólida (`surface3`, borda lilás), não vidro.
- **1.7 (acabamento por cima do quadro):** uma luz percorre a borda do take antes dele dobrar; onde ele vira luz, um reflexo horizontal de lente e uma onda;
  o cometa com o rastro e 5 toques táteis que apertam até a chegada; o universo escurece por um instante antes da estrela acender, um clarão branco e
  dourado, uma onda de luz pelas órbitas de dentro para fora e o YOU pulsando; uma conta de luz desenha a linha do YOU (lilás ao dourado); a cena se
  aproxima 4% durante a história; a cruz da estrela gira devagar com raios diagonais e a estrela cintila a cada 3,4 s; um brilho dourado cruza o título; uma
  estrela cadente a cada 9 s depois que tudo para.
- **Pro:** ver §12 (abertura e arte). A lista de benefícios ficou como estava no texto: o dono decide depois quais recursos são só do Pro (hoje só as
  exportações ilimitadas e os ícones de marco a partir de 10 são).
- **Your universe:** constrói-se ao abrir (`UniverseOpening`, 2,9 s; não nos anos selados, com Reduzir Movimento, nas imagens do "Share my universe" nem nos
  testes de UI, `playsUniverseOpening`): YOU nasce branco num clarão e esfria à sua cor, as órbitas se desenham, cada ponto voa do YOU ao seu lugar e pousa
  com um anel, uma luz corre por cada rota e o planeta nasce branco onde ela chega (com faíscas, um toque leve cada), a estrela NEW acende por último. Depois,
  só o YOU girando devagar: faixas suaves, duas manchas que giram com ele (36 s a volta), borda escurecida, reflexo e uma linha de atmosfera
  (`UniverseSphere.drawSurface`). Os planetas são esferas limpas com o lado escuro suave. Sem manchas cinzas no disco, sem halo nos pontos e sem os pontos
  do ano anterior (dele ficam rotas e planetas, bem fracos).
- **Testes:** `WelcomeScriptTests` (cápsula fica amarela, brilho dos pontos), `VoyageFitTests`, `ProOpeningScriptTests` (voo, nascimento, nada antes da
  estrela chegar), `UniverseOpeningTests`, `PaletteContrastTests.thePracticeNoticeReadsOnItsSolidCapsule`, `OnboardingUITests` (sem Skip nem "I already use
  Cue"; Record só depois do play); captura `HandoffCaptureTests.test1_7_FirstStarFinish` com os segundos do acabamento.

## 37. Quick edit: montagens confiáveis, capa e exportação (16 de outubro de 2026; pedido do dono)

O editor trata cada gravação de uma montagem (o take, outros takes, vídeos do Fotos) como a dona do que foi achado ou escolhido nela. Progresso e
auditoria: `reports/editor-award-checklist.md`.
- **Outra take na montagem:** Media › **Insert as clip** mostra "Your takes" (as outras takes do criador, a mais nova primeiro; script, número e
  duração) antes do Fotos; tocar uma a põe como clipe depois do clipe no cursor (`addableTakes`, `addClip(from:)`, `AddMediaSheet`).
- **Capa de qualquer gravação** (`CoverSource.clipFrame`, `CoverFrame`: gravação, clipe e segundo da gravação; `TakeEdit+Cover`). O quadro é sempre o
  da gravação onde foi escolhido, enquadrado como o vídeo o mostra ali (`FramePipeline`, `EditFraming`: Stabilize, o zoom do clipe naquele momento,
  Follow face, Fit, a escala da montagem, o fundo e o look do clipe que o mostra; uma cópia pode ter o seu); trocar a ordem, duplicar, dividir ou mudar a
  velocidade só muda onde ele toca. Capas antigas (`.frame(segundos)`) são quadros do take. **Se o trecho sai da edição**, a capa continua a mesma
  (da gravação); a etapa Picture mostra a faixa da edição de agora, e escolher outro quadro troca a capa.
- **Cover Studio** (`Screens/QuickEdit/CoverStudio/`, `CoverStudioViewModel`, `CoverComposition`): a capa é feita em tela cheia, sobre o editor (Capa
  na barra, o bloco de capa da timeline, "Try it" de notificação), em **cinco etapas** com Next e barra de etapas: **Picture** (quadro da faixa, ±1
  quadro, ou foto; zoom/mover com os dedos ou o controle, Reset; no antes/depois, Before | After com a metade emoldurada em amarelo, rótulos
  editáveis), **Template** (Educational, Opinion, List, Demo, Before/After, Series, cada miniatura desenhada com a foto e o título reais; trocar de
  modelo mantém título, destaques, enquadramento, segunda foto e os gráficos do criador; os do modelo, se não tocados, são trocados), **Title**
  (texto ou ✦ sugestões, palavras em destaque (várias), Type: fonte, tamanho, largura, alinhamento, maiúsculas; Color: texto, destaque e "Color |
  Box"; Readability: None, Shadow, Outline, Box + cor da caixa; Line above), **Graphics** (Arrow, Circle, Tag, @handle como objetos: tocar,
  arrastar, pinçar e girar com dois dedos ou a alça do canto, ✕, cor, texto, tamanho e giro por controle, Copy, In front, Behind, Delete) e
  **Finish** (Clean, Text behind me, Outline me, Dim, Blur com Strength; sem pessoa: "No person found" e a explicação; My cover style: Save as my
  style / Use my style; Remove cover). Desfazer/refazer próprio; Done é **um** passo no editor; Cancel com mudanças pergunta. Guias amarelas no
  meio e nos terços; guia de recorte "Profile grid 3:4 · approx." / "Square 1:1 · approx." (aproximações: o Cue não define a capa em nenhuma rede).
  O teclado esconde a barra de etapas; tocar na capa o recolhe. A timeline mostra a capa desenhada no bloco de capa.
- **Texto da capa** (`CoverTextLayout`, Core Text): o bloco inteiro cabe — a letra diminui (até 3,4% da largura) até a palavra mais longa, as
  linhas (até 6) e a altura caberem, sempre dentro da capa em volta do centro e longe de tags, @handle e rótulos do antes/depois. Quebra só no
  início de uma palavra (separação de palavras do sistema: espaços, ou dicionário em japonês, chinês e tailandês); RTL alinha do próprio lado;
  fontes sem a escrita caem para as versões em negrito do sistema (Thonburi-Bold, Hiragino W7, PingFang, Geeza Pro…); emoji e acentos medidos
  como glifos. Destaque em caixa só passa da palavra onde há espaço. "Too long to fit…" quando nem o menor tamanho cabe. Sombra suave atrás de
  palavras sem caixa (lê em foto clara); contorno com junção redonda; tinta automática sobre a cor de destaque/caixa (contraste ≥ 3 ou troca).
- **Estilo salvo** (`CoverStyle`, `DefaultsKey.myCoverStudioStyle`; o antigo `myCoverLook` é convertido): modelo, como o título é composto, efeito
  e força, gráficos (lugar, tamanho, giro, cor); nunca palavras, destaques, foto, enquadramento, texto do kicker ou de uma tag.
- **Capas antigas** desenham como antes até serem abertas no estúdio; aí viram o modelo mais próximo (`CoverComposition(legacy:)`). Cancel não muda nada.
- **Exportação:** é a da revisão da take (Done › **Download video**, Save, Share), descrita em §38; o editor não tem folha de exportação própria
  (a `QuickEditExportSheet`, que nada abria, saiu). A capa escolhida vai ao Fotos depois do vídeo (`saveCoverIfChosen`).
- **Studio Voice na montagem** (`StudioVoiceReach`, `TakeEdit+Voice`, `RecordingSounds`, `RecordingSoundCache`): trata o take e as outras gravações
  (cada uma pode ficar de fora em "Applies to"; o take sempre). **Even out volume between clips** leva a fala de cada gravação ao nível do take (até
  +9 / −12 dB, nunca acima de −1 dBFS: uma gravação com pico alto sobe só o que cabe, `AudioCeiling.leveled`). Música, voice-over e som de fotos/vídeos
  por cima nunca são tratados. Prévia e exportação usam os **mesmos arquivos** (cache compartilhado, até 8 tratados e no máximo um quarto do espaço livre, de 512 MB a 3 GB, o mais antigo
  sai primeiro; a exportação não trata de novo).
  Edições antigas: só o take, sem nivelar. Subtítulo do painel: "Whole take", "All 3 recordings" ou "2 of 3 recordings". Desfazer cobre tudo (`EditLook`).
- **Clean Up na montagem** (`CleanUpSuggestion.sourceID`, `EditTimeline+CleanUp`, `TakeEdit.cleanUpAnalyzedSources`): ouve cada gravação uma vez (uma
  nova, ao abrir de novo); a lista segue a ordem em que tocam e o cartão diz de onde é ("Interview · 00:22.0"). Remover corta aquela gravação onde ela
  toca (em cada cópia, na velocidade dela), nunca outra no mesmo segundo. Uma gravação que não pôde ser ouvida não apaga as sugestões das outras.
- **Mídias sobrepostas** (`OverlaysViewModel+Picking`): cada janela visível tem sua alça, na ordem em que o vídeo empilha (a escolhida por cima,
  para alcançá-la mesmo coberta). Um toque pega a de cima; tocar de novo onde elas se cobrem pega a de baixo; tocar a escolhida sozinha abre o painel.
  Contorno das não escolhidas: branco tracejado com halo escuro (`Palette.Editor.overlayOutline`/`overlayOutlineHalo`). **Durante o arraste o vídeo
  não desenha o item** (texto fora da composição; foto/vídeo com opacidade 0 na mesma faixa, sem piscar) e a cópia sob o dedo é a única.
- **Legendas na montagem** (`CaptionJoin`): **Join next** junta só a próxima coisa dita na mesma gravação, pela ordem de reprodução; outra gravação
  ("The next line is from another clip") ou um momento anterior ("…said earlier in this clip") são recusados. O ajuste de início/fim fica dentro do
  clipe da linha; arrastar a barra para um clipe de outra gravação é recusado ("A line stays on its own clip"); Split funciona numa cópia.
- **Localizar e trocar nas legendas** (`CaptionFindSheet`, `CaptionFindReplace`; Captions › **Find and replace** e o menu de legendas, como no
  editor de legendas do CapCut): uma palavra em todas as linhas que tocam, na ordem em que tocam, sem diferenciar maiúsculas nem largura (acentos
  contam: "e" não acha "é"). Cada resultado mostra a linha com a palavra em amarelo (`accText`, negrito) e **Replace**; **Replace all** troca
  todas num passo de desfazer ("Replaced N times" · Undo). Só o texto muda: a linha guarda seus tempos e as palavras que continuam iguais, os da
  voz (`CaptionRevision.retimed`); linhas de trechos cortados ficam como estão. Tocar num resultado leva a agulha à linha (a folha fica a meia
  altura, com o vídeo à vista).
- **Várias linhas de legenda de uma vez** (`CaptionPickTools`, `CaptionsViewModel+Picks`; Captions › **Select lines**, ou segurar uma
  linha › Select lines, como a edição em lote do CapCut): cada linha ganha um círculo; tocar põe ou tira. Enquanto escolhe, o painel cresce até
  a altura dos painéis de estilo (`openPanelSize`), no lugar da chave e dos chips fica "N selected", **Select all** / **Deselect all** e **Done**,
  e as ações ficam fixas embaixo da lista (rodapé do painel, como no CapCut, que as mantém à mão enquanto a lista rola; decisão depois de
  comparar: no topo da lista elas sumiam ao rolar e as linhas mal cabiam): chip **Emphasis** (a linha inteira na cor de destaque, como a palavra
  dita; em caixa onde a revelação usa caixa; ligado em `accText` sobre `accSoft`), menu **Size** (Regular, Bigger 1,25×, Biggest 1,5×, nunca
  menor, para não cair abaixo do tamanho em que as cores foram medidas; dentro do limite da coleção), ‹ › (**Move earlier / Move later**, 0,1 s
  por toque, todas juntas, até onde a que tem menos espaço pode ir: dentro do seu clipe e sem encostar numa linha não escolhida; "The lines
  can’t move further") e a lixeira ("N lines deleted" · Undo). Cada ação
  é um passo de desfazer (toques seguidos de mover são um). O estilo fica na linha (`CaptionCue.lineStyle`, `CaptionLineStyle`; linhas antigas
  sem ele) e é desenhado por `CaptionCollectionRenderer` na prévia e na exportação; legendas antigas sem coleção (`captionCollection` nil) não
  separam estilo por linha e o painel diz "Pick a look in Style…". Dividir uma linha mantém o estilo nas duas metades; traduções mostram as
  linhas sem o estilo. Sair da lista (outro painel) termina a seleção; a timeline continua mostrando uma linha escolhida por vez.
- **Replace clip** (barra do clipe › **Replace**, `ClipsViewModel+ReplaceClip`, `EditTimeline.replaceSource`, `TakeEdit.moveOverlays`; o
  padrão do CapCut): o Fotos abre só com vídeos; o escolhido entra no lugar do clipe, do começo do vídeo, pela mesma duração (se o vídeo é mais
  curto, o clipe fica do tamanho dele: "Clip replaced · the video is shorter, so the clip is too"), com a mesma velocidade, zoom, volume,
  transição e look. Textos, mídias e narrações presos ao clipe ficam no mesmo momento dele. Legendas e Studio Voice são da gravação: a nova não
  tem legendas até Auto captions ouvir de novo. A gravação antiga nunca muda; um Undo ("Clip replaced" · Undo) a traz de volta. Foto: "Pick a
  video first"; menos de 0,3 s: "Video too short to add".
  Diferença que fica do CapCut (comparado em 17/10/2026): lá se escolhe que trecho do vídeo novo entra; aqui ele entra do começo e as alças do
  clipe aparam. Próximo passo: a faixa "Part of the video" do B-roll (`MediaTrimStrip`) também para um clipe de outra gravação.
- **Extract audio** (barra do clipe e, num vídeo com som por cima, a da mídia; `AudioViewModel+ExtractAudio`, `SoundExtractor`,
  `TakeEditing.extractSound`): o som do clipe sai para a faixa de música como um clipe próprio ("Sound · Clip 2" / "Sound · Video",
  `MusicClip.extractedFrom`), onde tocava, no volume do clipe (ou do vídeo), sem fades e sem abaixar sob a voz, e o clipe (ou o vídeo) fica mudo:
  nada toca duas vezes ("Sound on its own track · the clip is muted" · Undo; o novo som fica escolhido, com Volume, Replace e Delete). O som sai
  como o Cue toca: do clipe, com o tratamento do Studio Voice e o nivelamento entre gravações (`RecordingSounds`), e na velocidade do clipe
  (mantendo o tom da voz se o clipe mantém; num clipe com curva, renderizado ao longo da curva como a prévia e a exportação o tocam,
  `CurveSoundRenderer`), num `.m4a` do próprio aparelho (AAC, `EditMediaFiles`). Na faixa de música ele se move, apara,
  ganha fades e volume como uma música, mas, como um efeito sonoro, segue o seu momento quando algo antes dele é cortado e nunca ocupa o lugar
  de uma música nova (`MusicClip.followsTheVideo`, `takesMusicRoom`). Sem som: "This clip has no sound"; num clipe ou vídeo mudo (o som já extraído, ou desligado), nada sai, para não tocar duas vezes ("This clip is muted · Turn its sound on to extract it"); se os cortes mudarem enquanto o som é
  escrito, nada entra ("The video changed meanwhile · Extract the sound again").
- **Contagens no plural certo** (String Catalog com variações de plural, `LOCALIZATION.md` §3): as frases com número do editor ("1 line
  deleted", "Found 1 pause", "Cut 1 word from the video", "1 word cut · 0.8 s", "Frame frozen for 2 seconds", "3 matches"…) escolhem a forma
  de cada idioma (árabe com as seis); o botão de Edit by text diz "Cut N words from the video" e o toast "N words cut · 0,8 s".
- **Barras como um editor de celular (decisão do dono, 16/10/2026, depois de comparar com CapCut, Edits e InShot; diverge da ordem do quadro
  v29 · 7.2).** Principal: **Edit · Captions · Text · ✦ Smart · Media · Audio · Format · Adjust · Filters · Cover** (Adjust e Filters do vídeo inteiro, §44) — a ordem em que um vídeo falado é feito, as
  cinco primeiras na tela do iPhone. **Format** (antes Crop, só na barra do clipe) abre o painel "Format" ("Whole video · format for where you post").
  Clipe: **Split · Speed · Zoom · Volume · Stabilize · Duplicate · Freeze frame · Reverse · Replace · Extract audio · Reorder · Adjust · Filters ·
  Background · Copy look · Paste look · Delete** (Stabilize e Reverse: §39): só o que é do clipe, o mais usado primeiro; o que muda o vídeo inteiro
  (Format, Studio Voice, Media) fica na principal. Texto ganha **Motion** (Style › Motion); mídia ganha **Track** (§39), **Duplicate** (por cima,
  mesmo arquivo) e, num vídeo com som, **Extract audio**.
- **Reordenar clipes** (`ClipOrderSheet`): **segurar um clipe** na timeline (0,45 s, toque háptico) ou **Reorder** na barra do clipe abre a lista dos
  clipes com quadro, número, origem e duração, arrastados pela alça; cada mudança é um passo de desfazer e o que toca no clipe vai junto. Um clipe só:
  "Split or add a clip to reorder".
- **Arrastar no tempo:** com um texto, mídia, legenda ou som escolhido, arrastar o **corpo** do bloco o move (o tamanho fica), grudando nos cortes e
  bordas com toque háptico; as pontas amarelas continuam aparando (`TimelineGeometry.bodies`, `HandleTarget.move`).
- **Marcas de corte sempre à mão:** com um clipe escolhido, os outros cortes mantêm a marca (tocar abre Transitions); só as bordas do clipe
  escolhido a cedem às alças. **Use on every cut** fica num rodapé fixo do painel de transição (sempre visível, mesmo no SE).
- **Nada termina em silêncio:** Paste look que não muda nada diz "Every clip already looks like this" / "This clip already looks like this";
  Edit by text que não ouviu palavras mostra o motivo (`CaptionState.message`, em `warnText`) e só oferece **Try again** quando pode ajudar.
- **Edit by text à vista:** primeiro bloco de ✦ Smart › Tools, botão "Edit by text · cut words from the video" no painel de legendas e o menu da faixa.
- **Mídia na barra principal** (**Media**, `.addMediaChoice`): a folha explica cada caminho — **Over the video** (B-roll: "Plays over your video…
  Move and resize it on the preview") e **As a clip** ("Becomes a clip of its own in the sequence, after the clip at the playhead. Videos only.").
- **Animações prontas** (`MotionPreset`, `OverlayAnimation`, `MotionPresetPicker` no topo do painel de movimento de textos, gráficos e mídias):
  Fade, Slide up, Slide in, Gentle zoom, Pop e In and out, com **Duration** (0,2–1,5 s) e **Strength**, e **Play it**. A animação é calculada por
  cima dos keyframes (base + animação), então a edição manual em **Keyframes** ("To move it your own way") continua valendo junto.
- **Copiar e colar o look** (`CopiedClipLook`, `ClipLookPart`, `PasteLookSheet`): **Copy look** na barra do clipe guarda Adjust, Filter,
  Background e Zoom do clipe; **Paste look** abre a folha para escolher as partes ("The words, sound and timing stay") e colar no clipe ou em
  **Every clip**, num passo de desfazer. Em todos os clipes, o look vai para os ajustes do vídeo e cada clipe perde a cópia própria das partes
  coladas (Filters, Adjust e Background do vídeo inteiro continuam valendo); num clipe, ele guarda só o que difere do vídeo.
- **Trecho do B-roll** (`MediaOverlay.mediaStart`, `MediaTrimStrip`): no painel da mídia, **Part of the video** mostra a faixa do arquivo com o trecho
  ("0:03 to 0:05 of 0:06"); arrastar escolhe de onde começa, **Plays for** muda a duração; nunca passa do fim do arquivo. Edições antigas: do 0.
- **Efeitos sonoros** (`SoundEffect`, `SoundEffectSynth`, na folha "Add music or a sound"): 11 sons **sintetizados no aparelho pelo próprio Cue**
  (Whoosh, Pop, Click, Ding, Sparkle, Riser, Boom, Ping, Typing, Shutter, Wrong), agrupados por uso (Transitions, Text appears, Big moment, Right
  answer, Mistake, Taps, steps…) — "Made by Cue · free to use in your videos": nenhum arquivo de terceiros, nenhum download. Ouvir antes ("Hear …"),
  adicionar na agulha; entram na faixa de música como clipes curtos (mínimo 0,5 s, pico −3 dBFS).
- **Gráficos no vídeo** (`TextOverlay.graphic`, desenhados por `CoverCompositionRenderer` como na capa): o menu de texto ganha **Arrow, Circle e
  Tag**; mover, pinçar, girar, cor e animação como um texto (`GraphicStylePanel`); "Style all" não muda gráficos.
- **Edit by text** (`TranscriptEditSheet`, `TranscriptEditing`, menu de legendas): **Listen to the video** transcreve no aparelho (Speech, nada sai
  do iPhone); tocar uma palavra e outra escolhe o intervalo. **Cut N words from the video** corta o vídeo (com 0,05 s antes e 0,15 s depois, sem
  invadir as palavras vizinhas); **Fix caption text** muda só o texto da legenda; palavras cortadas aparecem riscadas, com **Put back**. A
  explicação "Cut removes the words from the video. Fix caption text only changes what the caption says." fica na folha.
- **✦ Smart em duas categorias** (`SmartPanelSection`, abas **Tools | Templates** no topo do painel): Tools são os blocos violeta (Edit by text, Auto captions,
  Remove pauses, Studio Voice, Auto adjust, Background); Templates é a lista de modelos, cada um num cartão com o que muda ("Big captions that light
  each word · a hook that pops in") e o ✓ amarelo no que a edição está usando (`appliedVideoTemplate`).
- **Texto grande** (tamanhos de acessibilidade, conferido no iPhone SE em AX L): blocos de opção em 3 colunas, subtítulo do painel em até 2 linhas;
  no Cover Studio, "Next" sem o nome da etapa, "Video" no lugar de "Frame from video" e a barra de etapas só com ícones. Na linha de cima das
  legendas, quando não cabe numa linha (SE, texto grande): a chave e Style em cima, idioma e tradução embaixo; no cartão da linha, More desce
  para baixo de ‹ 3/12 ›. "Is it ready to post?" rola quando passa da altura da tela (começa pelo "EDIT SAVED"). O título "Cover" do Cover
  Studio só aparece quando cabe inteiro (no SE, não).
- **Painéis com texto grande e em telas estreitas** (`EditorLayout.largeTextPanelGrowth`, controles de `Panels/Controls`): de xxLarge para cima um
  painel mini ou médio cresce até 1,5× a sua altura e o vídeo cede até o mínimo (régua e trilha do vídeo ficam); os painéis de estilo não mudam.
  Nenhum rótulo quebra no meio da palavra nem botão empilha letras: **Adjust** põe nome, valor, ◐ e Auto numa linha; a nota de um clipe ("From the
  whole take") fica embaixo do nome, na mesma altura, quando não cabe ao lado (iPhone 17 e SE), e com texto grande nome, nota e botões têm
  linhas próprias; segmentos (Speed) com
  mais de 3 opções vão em linhas de 3 nos tamanhos de acessibilidade; os cartões de **Filters** se alinham pelo topo e alargam com o texto (até
  96 pt). **Pauses:** cartão em duas linhas (duração e Remove/Keep; quando e o círculo de Listen, 44 pt de toque), a 8 pt do "Pauses longer than",
  inteiro no SE; a largura deixa o próximo cartão aparecendo na borda quando há mais (`PausesPanel.cardWidth`); com texto grande o botão "Remove N
  pauses" desce para uma linha própria. **Volume:** sem os rótulos 0%/200% (o valor fica escrito em cima), e "Mute this clip" a 8 pt do slider,
  inteiro acima do Home Indicator.
- **Templates** (`VideoTemplate`, ✦ Smart › **Templates**: Bold hook, Tutorial, Story, Clean, Interview): legendas (tema e revelação, mantendo linhas,
  posição e margens), tipo e animação de todos os textos (não dos gráficos) e o estilo dos próximos; sem texto, abre o vídeo com o título do
  roteiro. As palavras, a posição de cada texto, os cortes, o som e os gráficos ficam; **um** Undo desfaz tudo ("Bold hook on the whole video" ·
  Undo). Sem legendas, a aba diz "No captions yet…" com **Make captions**. **Legendas de cada template** (escolha do dono numa página de
  opções; `VideoTemplate.captionSettings`: tema, revelação, look de texto copiado nas legendas, tamanho e cor da palavra dita), todas sobre placa
  ou cartão, porque branco só com sombra some em cena clara: **Bold hook** Pop (letra grossa numa faixa violeta por linha), 1,2×, palavra dita em
  amarelo; **Tutorial** Educational com o look Label (maiúsculas num cartão escuro), palavra dita em amarelo; **Story** Editorial (serifa numa
  placa preta de 62%), palavra dita em pêssego; **Clean** Educational (placa preta de 55%), linha a linha; **Interview** com o look Soft
  (cartão branco, letra escura), linha a linha. Pior caso sobre cena branca (`VideoTemplateCaptionContrastTests`): placa de 55% 4,7:1; a placa
  do Editorial passou de 55% para 62% (texto 4,4 → 5,7:1, pêssego 2,9 → 3,8:1), também fora dos templates. As opções são renderizadas por
  `TemplateCaptionOptionsCaptureTests` (`TEST_RUNNER_CUE_CAPTION_OPTIONS=<pasta>`).
- **Transições** (`EditTransition`, `TransitionDrawing`, Core Image sem kernel próprio): além de None, Dissolve, Fade e Slide, **Zoom, Blur,
  Flash, Push, Punch e Wipe** (movimento adaptado do GL Transitions, MIT; atribuição em Settings › Acknowledgements e `THIRD_PARTY_NOTICES.md`).
  **Duration** de 0,2 a 1,5 s por corte (`EditSegment.transitionDuration`; nil = a duração própria; um clipe curto encurta). O painel passou a
  `.medium` e as opções quebram em linhas de 5.
- **Freeze frame** (barra do clipe, `StillClipWriter`, fora da thread da interface, toast "Freezing the frame…"; se os cortes mudarem enquanto o
  quadro é feito, nada entra e o toast pede para congelar de novo): o quadro da agulha vira um vídeo
  mudo de 5 s na mídia da edição e entra como clipe de 2 s ali (o clipe é dividido; colado no início de um clipe, entra antes dele), com o look e o
  fundo do clipe de origem; a alça do fim estica até 5 s. A música e as narrações continuam; a gravação nunca muda. Numa gravação **HDR**
  (`.containsHDRVideo`, como as do iPhone em HLG) o quadro congelado é o próprio quadro decodificado em 10 bits, gravado em HEVC Main 10 com as
  mesmas primárias, função de transferência e matriz e a mesma rotação da gravação, para o editor convertê-lo como os clipes vizinhos; numa SDR,
  uma imagem em pé em H.264. Se o HDR não puder ser gravado, o quadro congela em SDR (nunca falha por isso).
- **Efeitos sonoros seguem o momento** (`MusicClip.following`): um corte antes de um efeito o traz junto, como textos e legendas; a música fica.
- **Use on every cut** copia também a duração; se todos já têm, o toast diz "Every cut already has it".
- **Edit by text numa montagem** corta só o clipe onde as palavras foram lidas (uma cópia as mantém); palavras com 44 pt; a nota diz que Undo traz
  de volta o que foi cortado.
- **iPhone quente e espaço:** ficam na exportação da revisão (§38).
- **Arquivos:** no lançamento, `EditStorageCleaner` apaga só os sons temporários de sessões passadas e, ao lado das gravações, as análises
  `.cueeyes` que nada lê mais (as mídias das edições
  nunca são varridas: só a edição remove o que acrescentou; um varredor de "órfãos" foi descartado na revisão porque uma lista de takes que não
  carregasse apagaria tudo). Excluir uma take (na hora ou depois do Undo) leva o rascunho dela e as mídias que só o rascunho nomeava; um vídeo
  importado que não pode ser lido não deixa cópia. **Bibliotecas:** takes, roteiros e as listas de uma edição (textos, mídias, músicas,
  legendas…) são lidos item por item (`LossyList`); um item ilegível fica de fora sozinho e o arquivo como era é guardado ao lado
  (`takes-kept-…`/`scripts-kept-…`); uma biblioteca que não pôde ser lida nunca é gravada por cima. **Sair do editor só diz "salvo" quando está no
  disco:** se o Done não consegue gravar a take, a edição fica como rascunho que o Edit reabre ("Couldn't save the edits · Kept as a draft"); se nem o
  rascunho pode ser gravado (Back, Not yet ou Done), "Couldn't save the edits · Free up space on this iPhone", nunca "Draft saved"
  (`TakeLibraryService.applyEdit` e `QuickEditDraftStoring.save` lançam o erro). **Roteiros e takes que não puderam ser gravados** ficam na
  memória (`saveFailed`): o Cue grava de novo ao voltar para a frente (`AppServices.reloadWhatCouldntBeRead`) e, com o Cue na frente, avisa
  "Couldn't save your work · Free up space on this iPhone" (`RootView`); uma falha em segundo plano (bloqueado) só avisa se a nova tentativa também
  falhar. A página do roteiro não diz "Saved as v…" sem gravar. Travamentos, CPU e escrita em disco medidos pelo MetricKit chegam ao Crashlytics como non-fatal (`DiagnosticsObserver`).
- **Movimento** (seguir rosto no Format, Stabilize, Track, curvas de velocidade, Reverse e Beats): §39.
- **Roteiro na tela durante o voice-over** (`NarrationScriptOverlay`, `NarrationScriptPace`, `AudioViewModel+NarrationScript`; como o
  roteiro na tela do Edits): numa take com roteiro, o painel Voice-over (médio) põe Record ao lado do rótulo e, embaixo, **Show script** ("On
  your screen while you record · not in the video", ligado até o criador desligar; lembrado para todas as takes, `EditorPreferencesStore`) e,
  ligado, a **Speed** do teleprompter (`SpeedSlider`, começa na velocidade do criador, lembrada). O roteiro (sem as cues) aparece sobre o topo da
  área da prévia, na largura toda, abaixo do "● REC", com a fonte, a cor, o espaçamento e o alinhamento do teleprompter (`PrompterParagraphs`) em
  letra grande (7% da largura, ≥ 17 pt) sobre uma faixa escura (`Palette.Editor.narrationScrim`, preto 72%: toda cor do teleprompter ≥ 4,5:1
  mesmo sobre quadro branco); antes de gravar mostra o começo, ao gravar rola em ritmo constante (as palavras por minuto do teleprompter, a
  mesma calibração do `PrompterScrollEngine`), um toque pausa ("Paused") e outro continua; com Reduce Motion pula de linha em linha. Não segue
  a voz (o microfone está gravando a narração) e nada dele entra no vídeo. Enquanto ele aparece, as alças dos itens da prévia somem. Take sem
  roteiro: o painel de sempre, mini, sem nada novo.
- **Demo do editor** (só Debug, `-uiTestDemoEdit`, `SampleEdit.demo`, arquivos feitos no lançamento por `SampleEditMedia`): além das legendas,
  textos e pausas, a take vem em 2 clipes (corte em 12,4 s, Reorder abre), uma música com batida de 120 BPM feita dos efeitos do próprio Cue
  (Beats acha 120 BPM), uma janela de B-roll (4,2–8 s, vídeo de amostra) e um voice-over (0,5–4,5 s). `ToolAuditCaptureTests.test10DemoTracks`
  fotografa Reorder, Beats, o painel da mídia, as barras de mídia, música, voice-over e legenda escolhidos e o Voice-over com o roteiro.
- **Testes:** `CoverTextLayoutTests` (títulos longos, árabe, tailandês, japonês, emoji, alemão), `CoverCompositionTests`, `CoverStudioViewModelTests`,
  `QuickEditCoverTests`, `CoverStudioUITests` (cinco etapas, cancelar, antes/depois), `CoverGalleryCaptureTests` (opt-in: todos os modelos × títulos ×
  idiomas × foto clara/escura), `PaletteContrastTests.theCoverGuidesAndOverlayOutlinesReadOnAnyPicture`, `TakeEditCoverTests`, `CoverRendererTests` (vídeos reais), `StudioVoiceReachTests`,
  `StudioVoiceMontageExportTests` (áudio real: −9 dB → dentro de 2 dB), `QuickEditMontageCleanUpTests`, `QuickEditOverlayPickingTests`,
  `QuickEditMontageCaptionTests`, `OverlayAnimationTests`, `QuickEditMotionPresetTests`, `QuickEditCopyLookTests`, `BrollPartTests`/`BrollPartExportTests`,
  `SoundEffectSynthTests`/`SoundEffectExportTests`, `QuickEditSoundEffectTests`, `QuickEditGraphicsTests`, `QuickEditTranscriptEditTests`,
  `QuickEditVideoTemplateTests`, `TransitionDrawingTests`, `CodeCreditTests`, `QuickEditFreezeFrameTests`/`FreezeFrameExportTests`,
  `PaletteContrastTests.theEditorsPickedTilesRead`, `EditorUITests.testSmartHasTemplatesInATabOfTheirOwn`, `NarrationScriptPaceTests`,
  `QuickEditNarrationScriptTests`, `PaletteContrastTests.theNarrationScriptReadsOverAnyPicture`,
  `EditorUITests.testVoiceOverShowsTheScriptOverThePreviewUntilItsSwitchIsOff`.

## 38. Exportação confiável: fora do Cue, progresso, espaço e calor (16 de outubro de 2026; pedido do dono)

A exportação é a da revisão da take (`TakeReviewViewModel`: Save, Share to universe, Share, e o Download video do editor). O arquivo e a entrega
(Fotos, a rede) são **um só trabalho** (`BackgroundExportRunner`), para que nada pare entre os dois.

- **Fora do Cue** (`BGContinuedProcessingTask`, iOS 26+; `SystemContinuedTaskScheduler` é o único arquivo que fala com `BackgroundTasks`):
  - Num iPhone que dá GPU a uma tarefa em segundo plano (`BGTaskScheduler.supportedResources` contém `.gpu`; entitlement
    `com.apple.developer.background-tasks.continued-processing.gpu` no perfil desde 16/10/2026), o Cue pede uma tarefa contínua com GPU (`.fail`,
    identificador `com.cuestudioteleprompter.export.<uuid>`, registrado logo antes, handler na fila principal, 5 s para começar). O iOS mostra o
    progresso numa Live Activity ("Exporting your video", a take); se o iOS encerrar a tarefa, o trabalho é cancelado, o arquivo parcial é apagado
    e o toast diz "iOS stopped the export · Try again".
  - Sem GPU em segundo plano, ou com o pedido recusado, a exportação roda como antes, com o tempo que o iOS dá a um app que sai
    (`beginBackgroundTask`). **Nunca** uma tarefa só de CPU: medida no 15 Pro, ela mantinha o Cue acordado sem desenhar os quadros e a exportação
    não terminava.
  - **Medido no iago Lima iphone (iPhone 15 Pro, iOS 27):** `supportedResources` vazio (sem GPU em segundo plano); pedido com GPU recusado, sem GPU
    aceito. Take de 2:30 em 1080p com legendas: 37 s com o Cue aberto, e pronta na volta depois de 60 s fora (Home + Câmera). Take de 6:40: 73% na
    volta depois de 60 s fora, seguiu e terminou em 97 s, o mesmo tempo de com o Cue aberto. **Mansuelli iPhone 18 Pro Max:** também sem GPU
    em segundo plano; 2:30 em 22 s com o Cue aberto; 6:40 com 60 s fora, 88% na volta e pronta em 71 s. Medido sob XCUITest; o uso à mão
    confirma no roteiro do dono. iPhone 15 comum (A16) e o caminho com GPU e Live Activity: **não validados**.
- **Na revisão, enquanto exporta** (`ExportProgressCard`, sobre `surface2`): "Exporting · N%" com barra; embaixo "You can leave Cue. The export goes
  on." (tarefa aceita) ou "Keep Cue open until it’s done."; com o iPhone quente (`thermalState` `.serious`/`.critical`, `DeviceHeat`), "The iPhone
  is hot, so the export takes longer. Let it cool down if you can." (`warnText`). A qualidade e as animações não mudam.
- **Espaço:** antes de renderizar, "Not enough space on this iPhone. Free about N MB and try again." (`StorageSpace`: o dobro do tamanho estimado,
  2,2 MB/s em 1080p e 6,5 em 4K, + 150 MB); nada começa.
- **Parou com o Cue** (fechado pelo seletor de apps, ou encerrado pelo iOS): a take fica marcada enquanto exporta (`PreferencesService
  .exportsInFlight`); marcada no lançamento seguinte vira `stoppedExports`, e a revisão dela mostra `ExportStoppedCard` (ícone, "The last export
  stopped" e × numa linha; "Cue closed before it finished. Export again to get the video."; **Save video**). Um vídeo não continua do meio:
  exportar de novo recomeça. Contraste medido na captura: título 15,7:1, texto `ink2` 5,6:1, barra amarela 11,1:1 sobre `surface2`.
- **Interrompida pelo iOS** (`AVError.operationInterrupted` → `VideoExportError.interrupted`): o mesmo toast de tentar de novo; o arquivo parcial
  é apagado.
- **Testes:** `BackgroundExportRunnerTests`, `TakeReviewBackgroundExportTests`, `ContinuedTaskDeviceTests` (aparelho: o que o iOS responde),
  `BackgroundExportDeviceUITests` (aparelho: take real com Save e Câmera; takes longas em memória, `-uiTestLongTake <s>`), `ExportProgressUITests`
  (os dois cartões; `-uiTestSlowExport`, `-uiTestStoppedExport`).

## 39. Quick edit: movimento (17 de outubro de 2026; pedido do dono)

Seis ferramentas que leem o movimento do vídeo, todas no iPhone (Vision, AVFoundation e Accelerate; nada sai do aparelho, nenhum serviço pago).
Prévia e exportação passam pelo mesmo compositor (`CueVideoCompositor`), então mostram o mesmo quadro. Relatório: `reports/editor-motion-report.md`.

- **Análise de movimento** (`MotionAnalysisService`, `MotionAnalyzer`, `MotionAnalysis`): ao abrir Format ou Stabilize (e ao abrir o editor numa
  edição que já usa Follow face ou Stabilize), cada gravação que a edição toca (a take e as outras da montagem) é analisada em segundo plano do app, uma por vez, com prioridade baixa (`.utility`): cada quadro (até 30 por segundo)
  é desenhado de pé numa cópia de 512 pontos; o movimento da câmera é medido numa grade de 4 × 6 blocos do fundo, sem os blocos que as pessoas
  cobrem (`BackgroundTiles`) nem os lisos (céu, parede), e vale o deslize e o giro que melhor explicam os blocos, medidos de novo sem os que
  destoam (`CameraMotion`: mínimos quadrados robustos; giro só com blocos espalhados e até 0,03 rad por quadro); 10 vezes por
  segundo, rostos e corpos (`SubjectSample`). **Para** quando o Cue vai para o segundo plano (`scenePhase`) ou o iPhone esquenta (`thermalState`
  sério ou crítico) e **continua de onde parou** (`analyzedUntil`; o que foi feito fica salvo a cada 5 s de vídeo, ou a cada vigésimo da duração
  num vídeo longo). Fica **ao lado da gravação** (`<gravação>.cuemotion`, fora do backup, versionado: `MotionAnalysis.currentVersion`; outra versão é
  refeita) e sai com ela (take apagada, `EditMediaFiles.remove`; nada é salvo de uma gravação apagada durante a análise). As últimas 6 análises lidas
  ficam na memória com a data do arquivo, e com os caminhos do Stabilize de cada nível (`MotionAnalysisStore`): os painéis e cada build da prévia não
  decodificam o arquivo de novo enquanto ele não muda. Com Seguir rosto ou Estabilizar ligados, cada gravação nova que a edição passa a tocar (um
  clipe invertido ou trocado, um clipe novo da montagem) também é pedida. Nada da edição depende dela: sem análise, o vídeo toca como gravado.
  Exportar com Seguir rosto ou Estabilizar faz a análise que faltar antes de começar, fora da thread principal; se o iPhone esquenta (sério ou
  crítico) ela para, o que foi feito fica salvo e a exportação diz "Your iPhone is too warm to finish this video. Let it cool down, then export
  again." (nunca sai um vídeo diferente do que o criador pediu). Os painéis dizem quanto falta: "Finding your face · 40%", "Measuring the shake · 40%", "Waiting for the
  iPhone to cool down · 40%", "Goes on when Cue is open · 40%", "This video couldn’t be read".
- **Format › Follow face** (`TakeEdit.faceFollow`, `FaceFollow`, `FollowPace`, `FaceFollowPath`): com Fill e um formato que corta (4:5, 1:1 ou 16:9 de
  uma gravação 9:16; numa montagem, qualquer um), o recorte acompanha o rosto como um operador de câmera: fica parado enquanto o rosto anda numa
  zona calma, vai atrás quando ele sai, nunca mais rápido que o ritmo, começa e para suave (caminho suavizado nos dois sentidos, sem atraso), com
  os olhos um pouco acima do meio e sem sair da gravação. **Pace:** Calm · Natural · Quick. Segue o rosto mais próximo do que vinha seguindo (o
  maior no começo); sem rosto, a cabeça do corpo. Arrastar o vídeo desliga ("Follow face is off · You moved the frame"). Sem espaço: "Pick 4:5,
  1:1 or 16:9 to follow your face"; com Fit: "Follow face works with Fill"; sem rosto: "No face found in this video". A capa feita de um quadro
  usa o recorte daquele momento. Um passo de desfazer (`EditLook`). O painel Format passou a `.medium`.
- **Stabilize** (barra do clipe, entre Volume e Duplicate; `EditSegment.stabilization`, `StabilizationLevel`, `StabilizationPath`, `StabilizePanel`):
  **Off · Gentle · Standard · Strong** (suavização de 0,25 / 0,6 / 1,2 s; zoom de no máximo 5 / 9 / 14%). O caminho da câmera é suavizado nos
  dois sentidos; o zoom é o **menor** que esconde as bordas em 9 de cada 10 quadros; onde a câmera mexe mais (uma panorâmica), o caminho é mantido
  dentro do corredor que esse zoom permite e suavizado de novo, então nunca aparece borda nem tranco. Cada quadro da gravação tem a sua
  correção, mesmo quando a edição o segura (câmera lenta, gravação de 15 ou 24 quadros por segundo). Mostra "Zoomed in 6% to hide the edges",
  "Steady already · no zoom needed" ou "No shake found in this clip"; **Use on every clip** num passo.
- **Track** (texto, gráfico ou mídia: barra do item e o painel de movimento; `ObjectTracker`, `FramePlacement`, `TrackedMotion`): o criador põe o
  item em cima do que ele deve seguir, na agulha, e toca **Track**; o Cue segue, com o Vision, o que está sob o centro do item (um quadrado de 14%
  da largura do vídeo) para a frente e para trás, enquanto o item aparece no clipe da agulha ("Tracking · 40%", Cancel). O caminho vira
  **keyframes editáveis** (os mínimos que ficam a 0,4% do caminho, em ritmo constante, mantendo tamanho e opacidade), num passo de desfazer;
  os keyframes que havia no trecho seguido saem, os outros ficam. Se perde o objeto: "Lost it after 3.2 s · It holds from there". O Vision roda
  fora da thread principal; o ponto do vídeo leva em conta a correção do Stabilize do clipe (`FramePlacement.steady`). Um resultado só entra se é
  da corrida em curso, com o editor aberto e o vídeo e o item como estavam ("The video changed meanwhile · Track it again"); fechar o editor
  cancela.
- **Speed › Curve** (`EditSegment.speedCurve`, `SpeedCurve`, `SpeedCurvePreset`, `SpeedCurvePanel`, `SpeedCurveEditor`): o painel Speed tem
  **Normal | Curve**. Curve: None, **Hero, Bullet, Ramp up, Ramp down, Montage, Flash in, Flash out** (cada cartão desenha a curva) e **Custom**
  (cinco pontos a 1×); o editor mostra a curva (0,25× a 4×, a faixa do varispeed da Apple, para o som sem "Keep voice pitch" nunca se afastar
  da imagem; escala logarítmica, linha de 1×, agulha) e os pontos: arrastar para cima acelera,
  para baixo desacelera, os de dentro também andam para os lados (VoiceOver: ajustável). A velocidade flui entre os pontos (cúbica monótona em
  escala log, sem passar dos pontos) e o tempo de cada momento é a integral de 1/velocidade, numa tabela fina: a imagem é esticada em 30 passos
  por segundo (sem degraus; no máximo 1.500 passos por clipe) e **o som é renderizado inteiro ao longo da curva** (`CurveSoundRenderer`: unidade
  de time-pitch da Apple com "Keep voice pitch", varispeed sem), sem cortes nem estalos: fora da thread principal, lendo a gravação um segundo por
  vez (no máximo ~3 s na memória, `SoundChunkReader`), parado quando a prévia é refeita; os renders antigos de cada clipe saem (ficam os 2
  últimos). Enquanto um dedo arrasta um ponto da curva ou uma alça de clipe, a prévia estica o som em passos (instantâneo) e o renderiza quando o
  dedo solta (`EditPlayback.stepsCurveSound`). Dividir um clipe curvo mantém a parte da curva de cada lado (no máximo 25 amostras da curva, mais os
  pontos de dentro quando são até 8: cortar muitas vezes, como em Cut on the beats, nunca a faz crescer); aparar pelas alças estica a curva
  no que sobrou; na prévia, as alças alcançam o resto da gravação na velocidade da ponta. Escolher uma velocidade em Normal tira a curva. Selo do clipe: o nome da curva ou "Curve".
- **Reverse** (barra do clipe, depois de Freeze frame; `ReversedClipWriter`, `ReversedSound`, `ClipReversal`): o trecho do clipe é escrito de trás
  para a frente, imagem e som, como um vídeo próprio na mídia da edição (HEVC no tamanho, quadros por segundo e orientação da gravação; alguns
  quadros por vez, no máximo ~100 MB na memória), e o clipe passa a tocá-lo, com a mesma velocidade, look e lugar; textos, mídias e voice-overs em
  cima ficam onde estavam no vídeo. **Reverse de novo** volta ao original; mais uma vez, toca o vídeo invertido já escrito (ir e voltar nunca escreve
  outro arquivo). Vídeos invertidos que nada toca saem da edição no Done; se o editor fecha enquanto um é escrito, ele é apagado. Até 2 minutos ("Reverse works on clips up to 2 minutes · Split it first"). Um passo
  de desfazer; a gravação nunca muda.
- **Beats** (só para música trazida dos Files: o Cue não tem biblioteca de música; efeitos sonoros e sons extraídos do vídeo não têm; `BeatDetector`, `BeatTracker`, `BeatStore`, `BeatCuts`,
  `BeatsPanel`): as batidas são achadas no iPhone quando a música entra (fluxo espectral, tempo pela autocorrelação entre 60 e 200 BPM, batidas
  por programação dinâmica), guardadas ao lado do arquivo (`<arquivo>.cuebeats`) e aparecem como risquinhos na faixa da música. **Beats** na barra
  da música: **Snap to beats** (a agulha e as bordas grudam nas batidas; `TakeEdit.snapsToBeats`, ligado), **Move cuts to the beats** (cada corte
  vai para a batida mais próxima, até 0,5 s, encurtando ou alongando o clipe antes dele, nunca além da gravação nem para dentro da parte seguinte)
  e **Cut on** Every beat · Every 2 · Every 4 › **Cut the video on the beats**. Subtítulo: "112 BPM · 48 beats in the video", "Finding the
  beats…" ou "No steady beat in this music". Cada ação é um passo de desfazer.
- **Barras:** Clipe: Split · Speed · Zoom · Volume · **Stabilize** · Duplicate · Freeze frame · **Reverse** · Reorder · Adjust · Filters · Background ·
  Copy look · Paste look · Delete. Texto: Edit · Style · Motion · Keyframe · **Track** · Duplicate · Delete. Mídia: Edit · **Track** · Duplicate ·
  Replace · Delete. Música: Volume · **Beats** · Replace · Delete (efeitos sonoros e sons extraídos sem Beats).
- **Comparação com CapCut, Edits e InShot** (17/10/2026): Follow face é o "Auto reframe" do CapCut (formato + velocidade do acompanhamento), no
  painel de formato; Stabilize tem três níveis como o do CapCut, por clipe, e ganha "Use on every clip"; Track: no CapCut se arrasta uma caixa
  sobre o objeto; no Cue o próprio item é a caixa (põe e toca Track), um passo a menos, sem caixa de tamanho ajustável; Speed com Normal | Curve
  e Reverse na barra do clipe como no CapCut e no InShot; Beats como as marcas de batida do CapCut, com o ímã e os cortes automáticos. Nenhuma
  diferença pediu mudança de layout além das descritas.
- **Testes:** `MotionAnalyzerTests`, `MotionAnalysisServiceTests` (também: exportação que para no calor, nada salvo de gravação apagada),
  `FaceFollowPathTests`, `StabilizationPathTests`, `ObjectTrackerTests` (com a correção do Stabilize), `QuickEditTrackTests` (corrida cancelada ou
  desatualizada), `SpeedCurveTests` (dez divisões seguidas), `BeatTrackerTests`, `QuickEditReverseTests` (voice-over, reaproveitar o invertido),
  `QuickEditExtractAudioTests` (clipe curvo, sem Beats), `QuickEditPlayerTests` (som em passos durante o arraste), `SoundExtractorTests`; exportações reais `MotionExportTests` (o recorte segue,
  o tremor cai), `SpeedCurveExportTests` (cada quadro no momento da curva; som sem queda nem estalo), `ReverseExportTests`; UI `EditorMotionUITests`;
  aparelho `MotionAnalysisDeviceTests`, `EditorMotionDeviceTests` (`CUE_DEVICE=… scripts/test.sh device …`, cópias das takes).

## 41. Legendas: o idioma falado (20 de outubro de 2026; pedido do dono)

- **Vídeo sem roteiro, idioma em Auto:** antes de ouvir, as legendas ouvem os primeiros 10 s de fala em até quatro idiomas
  prováveis (o padrão de antes, os do iPhone, o do app e inglês) e legendam no que o reconhecedor entendeu melhor
  (`SpokenLanguageIdentifier`, regras em `LOCALIZATION.md` §1, medidas no §5). A linha de estado diz "Finding the language you speak…" / "Descobrindo o
  idioma que você fala…" (1–3 s num iPhone 15 Pro). Também vale para as legendas feitas na exportação de um vídeo nunca editado.
- **Com roteiro:** no Auto, o idioma do roteiro, sem espera. Um idioma escolhido no seletor diferente do roteiro é tratado como
  engano provável: compara os dois, legenda no falado e o seletor passa a mostrar esse. Sem aviso (decisão do dono).
- **Onde não julga:** idiomas que só o ditado ouve (id, ar, tr, th, vi, nl, sv, da, nb no iPhone; todos num aparelho sem
  `SpeechTranscriber`, como o iPad Pro A12Z) seguem no idioma de antes.
- **Linhas:** palavras com horários redistribuídos (o reconhecedor errou os horários) formam linhas como as medidas, nunca uma palavra
  por linha.
- **Testes:** `SpokenLanguageIdentifierTests`, `LanguageServiceTests/aTakeWithoutAScriptIsComparedInItsLikelyLanguages`,
  `QuickEditLanguageTests/aLanguagePickedUnlikeTheScriptsIsCheckedAgainstIt`, `CaptionBuilderTests/wordsSpreadOverTheSpeechMakeWholeLines`;
  aparelho `SpokenLanguageDeviceTests`.

## 42. Desempenho medido no iPhone (22 de outubro de 2026)

`PerformanceDeviceUITests` (opt-in: `CUE_DEVICE=… TEST_RUNNER_CUE_PERF=1 scripts/test.sh device-ui PerformanceDeviceUITests`), com as métricas do
XCTest, em memória e com os exemplos (nunca a biblioteca do criador), animações reais. Build **Debug**: compare rodadas entre si, não com a App Store.
iPhone 15 Pro, média de 5:
- **Abertura a frio** até aceitar toques: 1,20 s.
- **Scripts rolando sobre o céu Interstellar:** 0 travadas (hitch ratio 0 ms/s), ~82 fps, pico de memória ~200 MB.
- **Editor ficando pronto** (do toque em Edit às ferramentas acesas, "Getting your take ready"): 1,78 s, CPU 0,9 s; ida e volta inteira 5,3 s,
  pico 144 MB.
- **Universo** (Profile e de volta a Scripts): 3,7 s, 75 MB.

**Prévia do Quick edit** (`QuickEditPreviewLatencyTests`, `CUE_DEVICE=… scripts/test.sh device QuickEditPreviewLatencyTests`; 23/10/2026, iPhone
15 Pro, take de 22 s com título, subtítulo e 8 legendas, 10 mudanças por cenário). A composição da prévia (e da exportação) é montada fora da
linha principal (`EditedComposition.build` é `@concurrent`): enquanto ela se monta, a tela segue o dedo numa alça, num slider ou no
enquadramento.
- **Linha principal ocupada por mudança** (o que o dedo sente): antes ~40 ms (filtro, texto, desfoque em 1080p), 44 ms (4K), 52 ms (corte);
  agora ~9 ms em todos (o passo da medida) e 14 ms no corte.
- **Da mudança ao quadro novo na tela:** 45–63 ms (filtro, texto, 4K), ~120 ms num corte (item novo, com o quadro antigo segurado; nunca em
  branco). Igual antes e depois.
- **Debug × código otimizado** (`CUE_SWIFT_OPTIMIZATION=-O`, como o Release): a mudança aparece no mesmo tempo (o trabalho é do AVFoundation e
  da GPU); montar a prévia ao abrir fica ~35% mais rápido (285 → 191 ms com texto, 282 → 183 ms em 4K, 277 → 173 ms no corte). O app instalado
  pelo `scripts/build.sh install` é Debug: para julgar a fluidez como na App Store, `CUE_CONFIGURATION=Release`.

**Take longo** (`LongTakeDeviceTests`, `CUE_DEVICE=… scripts/test.sh device LongTakeDeviceTests`; 23/10/2026, iPhone 15 Pro, Debug): 30 minutos
de vídeo 720p com 600 linhas de legenda (cinco palavras cada), o Cue na frente.
- **Editor:** abre em 18 ms (sem o player); a linha sob o cursor, pedida a cada quadro, leva 1 µs (`CaptionMap`; mapear todas as linhas de novo,
  como cada leitura fazia antes, leva 1,3 ms, e arrastar uma legenda fazia isso uma vez por barra); a timeline sai em 0,3 ms; corrigir uma linha,
  0,6 ms; +36 MB de memória.
- **Rascunho:** 6 MB depois de 20 correções de legenda (cada passo de desfazer guarda as 600 linhas), escrito fora da linha principal em 125 ms.
  Guardar só as linhas que mudaram em cada passo fica para a Fase C (as legendas viram uma parte própria do editor).
- **Prévia:** a composição de 30 minutos com as 600 legendas leva 1,0 s para montar (fora da linha principal), +50 MB.
- **Studio Voice:** 78 s para tratar os 30 minutos; o arquivo tem 302 MB; o limite do cache era 2,8 GB com 27 GB livres.

## 43. Apple Watch: o gravador no pulso (22 de outubro de 2026; pedido do dono)

Referência: canvas **Cue Studio v31 · Apple Watch** (claude.ai/artifact/2vSQB5yQS7rw4m7LfDSmi4: mapa de navegação, protótipo de 40 mm, componente
de tela e os 25 estados). O relógio é **companion**: grava, encerra, ensaia e conduz o texto do gravador do iPhone; não grava nem guarda nada.
**O relógio só pede; a tela muda quando o iPhone responde** (nunca "Gravando", "Salvo" ou "Pronto" sem a confirmação).
- **Alvo** `Cue Studio Watch` (watchOS **10**, para rodar também no Series 4 e 5, cujo último watchOS é o 10; `Config/Watch.xcconfig`). **Compila
  em todo build do app do iPhone (dependência do alvo), mas ainda não vai embutido nele** (decisão do dono, 22/10/2026: é uma base, não validada
  num relógio de verdade; volta a ir junto quando estiver pronta, com uma fase "Embed Watch Content" no alvo do iPhone: copiar o
  `Cue Studio Watch.app` para `$(CONTENTS_FOLDER_PATH)/Watch`). Ícone: o mesmo `AppIcon.icon`, copiado para a pasta do relógio. Código compartilhado (os dois alvos) em
  `Cue Watch Shared/`: `WatchAction`/`WatchCommand` (relógio → iPhone), `WatchPhoneState`/`WatchPhase` (iPhone → relógio), `WatchMessage`
  (JSON pelo WatchConnectivity) e `WatchScreenRule`, a regra pura que decide a tela.
- **iPhone** (`Managers/Remote/Watch/`): `WatchLinkService` (vive na sessão do app; o gravador se liga ao abrir e se desliga ao fechar, e aí o
  relógio ouve "Prepare on your iPhone"), `WatchConnectivityTransport` (mensagem com resposta quando o relógio está ao alcance e o
  application context sempre, para o relógio ler ao abrir). `PrompterViewModel+Watch`: cada comando muda o que mudaria no iPhone e o estado
  diz qual comando já aconteceu (`answering`): **Gravar** começa a contagem ou o take como o botão vermelho (de um take salvo, **Gravar outro**
  faz o Refazer da revisão e grava); **Encerrar** para e salva sem o aviso de monetização (o criador escolheu no pulso) e a revisão abre no
  iPhone como depois do Stop dele; **Ensaiar** toca o roteiro sem gravar (pausado continua sendo ensaio); texto (ler/pausar, voltar 3 linhas,
  − e + de velocidade, a coroa com a velocidade exata). **Indisponível** no Studio (teleprompter para outra câmera) e na prática do primeiro voo.
- **Relógio** (`Cue Studio Watch/`): `WatchSessionModel` (último estado do iPhone, comando à espera, Encerrar armado por 3 s, coroa, página),
  `WatchSessionLink` (WCSession). Telas: Verificando o iPhone, Pronto (roteiro ou gravação livre, Seguir voz ou Manual · 1,2×, Gravar vermelho
  no mesmo lugar, Ensaiar), Pedindo ao iPhone (com Cancelar), contagem no anel amarelo ("Ainda não grava"), **Gravando** (tempo contado no pulso
  desde o início que o iPhone informou; Encerrar pede dois toques em 3 s) com a página **Texto** a um deslize (`TabView` vertical), Salvando,
  **Take salvo** (número e duração, Gravar outro, Concluir), Ensaio, e os avisos (Sem sessão, Sem conexão com o último estado tracejado,
  Sem resposta após 5 s, Não começou a gravar, Salvamento não confirmado, Indisponível). Cabeçalho: iPhone (verde), Conectando/Sem
  conexão/Sem resposta (laranja), ● REC, PREPARANDO, ENSAIO; a hora é a do sistema. **Concluir** só sai do take salvo no relógio.
- **Vibrações** (`WatchHaptics`), uma vez cada e só depois da confirmação: contagem começou (clique), gravando (início), encerrado (parada),
  take salvo (sucesso), falha ou conexão perdida (falha). Nada a cada segundo nem durante a fala.
- **Cores** (`WatchPalette`, do canvas), medidas: texto secundário 8,4:1 na noite e 6,9:1 no céu; branco no vermelho de gravar 5,4:1; demais
  pares acima de 6:1. Texto ampliado: estilos de texto do sistema (crescem com o tamanho escolhido no relógio).
- **Idiomas:** catálogo próprio `Cue Studio Watch/Localizable.xcstrings` (20 idiomas; `scripts/strings.py … --catalog Watch`). O português segue o
  canvas, exceto "Voice Following", que segue o glossário do app (Seguir voz).
- **Testes:** `WatchScreenRuleTests` (todos os estados, esperas, sem resposta, estado antigo), `WatchMessageTests`, `PrompterWatchTests` (gravar,
  encerrar e salvar, gravar outro, câmera que não começa, ensaio, velocidade, Studio indisponível, gravação livre).

## 44. Quick edit: um sistema para todas as ferramentas (23 de outubro de 2026; pedido do dono)

O editor segue o canvas "Cue: um sistema para todas as ferramentas" (aprovado pelo dono; regras 01–17), mantendo o que já fazia bem: o
Excluir fixo no canto da barra, o ✓ amarelo, o ‹ do contexto, as marcas no clipe e os ícones de hoje. Captions e ✦ Smart ficam na estrutura de
antes (o dono achou a versão redesenhada pior). Comparado com CapCut, Edits e InShot (página "Referências" do canvas): 11 de 13 convenções
iguais ou melhores; o fundo e o recorte num painel só, de propósito.
- **Cabeçalho de painel** (`EditorPanelContainer`): título, **escopo** na linha de baixo ("Clip 2 of 3" numa montagem, "This clip" com um
  clipe, "Whole video"), **Reset** à esquerda de ◐ e ✓ assim que algo mudou (`QuickEditViewModel+PanelReset`: Speed, Zoom, Volume, Stabilize,
  Transition e Studio Voice; Adjust, Filters, Background e Caption style com o seu), num passo de desfazer.
- **◐ Compare with original** (`PanelCompare`, `PanelCompareButton`) no cabeçalho de Adjust, Filters, Background e Studio Voice: toque mostra
  o original até o próximo toque; segurar mostra só enquanto o dedo está; esmaecido quando não há o que comparar. A prévia diz "Original" (a
  imagem como gravada: sem Auto, Adjust, filtro **nem fundo**, `TakeEdit.withoutPictureLook`) ou "Original audio".
- **Escolhas de 2 a 4 palavras são segmentados:** Studio Voice (Off · Light · Strong) e o tamanho da legenda (S · M · L · XL). "None" para
  "sem efeito" (Zoom, Stabilize); o giro em graus ("15°"); 9:16 e 4:5 com símbolos na proporção.
- **Advanced** diz quantos ajustes estão mudados lá dentro ("· 1 changed": Speed, Zoom, fades da música).
- **Desativado:** 40% em todo controle (`Metrics.disabledOpacity`), linhas com chave incluídas, sempre com o motivo escrito (Paste look: "Turn on
  a part to paste it.").
- **Timeline:** o clipe e o item escolhidos seguem com contorno branco e alças amarelas pegas a 32 pt. A alça do clipe fica sobre o corte e o
  alcance a mais cresce **para dentro do clipe escolhido**, nunca sobre o vizinho: ali só a alça que se vê é dele, o resto do vizinho é do
  vizinho (alças de 44 pt sobre o vizinho confundiam qual clipe o dedo pegava). A etiqueta do clipe diz também "Stabilized" e "Volume 150%".
  **Música e narração** se movem e aparam como um texto: a música ganha alças (o começo leva o arquivo junto, `resizeMusic`); a narração se
  arrasta pelo corpo e apara pelas alças (`VoiceOverClip.offset`/`length`: o que da gravação toca; a composição insere a partir dali). As bordas
  de fotos, vídeos, música e narrações também atraem as alças e a agulha (`TimelineGeometry.snapTimes`).
- **Capa:** um toque acha o gráfico, o título e o divisor exatamente onde a alça deles pega o dedo (`CoverStudioViewModel.itemTouchSize`,
  `titleTouchFrame`, `dividerTouchFrame`, os mesmos que as alças desenham): toque e arraste sempre acham a mesma coisa.
- **Legendas:** Top · Middle · Bottom e os pontos onde o arraste gruda são um só conjunto (0,16 · 0,5 · 0,76, `CaptionPosition.verticalFraction`);
  Middle é o meio do quadro, na guia da prévia.
- **Fontes:** uma lista para textos, legendas e capa (`TextOverlayFont.editorFonts`, 15): Montserrat, TikTok Sans, Poppins, Rubik, DM Sans,
  SF Pro, Space Grotesk, Unbounded, Syne, Anton, Bangers, DM Serif Display, Instrument Serif, Caveat, Space Mono (as favoritas das legendas
  primeiro; as cinco primeiras e Bangers vieram da pesquisa de 2025–26, SIL OFL 1.1, em Acknowledgements). A capa usa as mesmas e seus pesos
  (`CoverFont` = família + peso; capas antigas com "Grotesk", "Serif" abrem nas mesmas faces). Caption style › Font troca a família **sobre um
  preset** (`CaptionSettings.face`, chip "Preset" volta à dele) e mantém o resto; escolher outro preset traz a fonte dele. Texto num idioma que a
  família não cobre (árabe, hindi, tailandês, CJK; vietnamita em Poppins, Rubik, DM Sans, DM Serif, Instrument Serif, Syne e Caveat) sai na fonte
  do sistema.
- **Cores:** uma paleta de 13 na mesma ordem em todo seletor do editor e da capa (`OverlayColor.palette`: White, Paper, Ink, Yellow, Peach,
  Orange, Red, Blush, Lavender, Blue, Cyan, Mint, Lime) — texto, caixa, gráficos, legenda, destaque da legenda (`CaptionAccent` é a paleta),
  palavras da capa e fundo do vídeo; em linhas (7 + 6), todas à vista. Black, Green, Pink e Purple ficam só para edições antigas. A cor do
  texto mora só na aba Color do Text style.
- **Filtros:** 13 (`VideoFilter.collection`): Natural, Studio, Soft, **Golden Glow**, Cinema, Warm Editorial, **Warm Film**, Retro, **Digicam**,
  **VHS**, Mono Soft, Mono Contrast, **B&W Film**. Os novos (a pesquisa de 2025–26) têm, além da cor (`FilterGrade`), uma textura
  (`FilterTexture`): grão que muda a cada 1/24 s e é o mesmo no mesmo instante na prévia e na exportação (`FrameLook.apply(time:)`), brilho nas
  altas luzes, cantos escuros, nitidez, e no VHS imagem mais macia com franjas de cor e linhas. Nomes sem marcas (nada de Kodak/Fuji/Portra).
- **Texto do tamanho do iPhone:** painéis, folhas, avisos, o tempo do player, o chip de status, as palavras da capa e os chips crescem com o
  Dynamic Type (estilos de texto, ou `@ScaledMetric` onde o tamanho do desenho fica entre dois); o tempo para em xxLarge (a barra mantém a
  altura); os blocos do Smart crescem com o nome. A barra de ferramentas mantém a altura: com os maiores tamanhos, segurar mostra o nome grande
  (Large Content Viewer), como a barra de abas do sistema. As etiquetas da timeline (desenhadas em UIKit, faixas de altura fixa) não crescem.
- **Modo de Pouca Energia** (`QuickEditViewModel+LowPower`, `LowPowerNotice`, `LowPowerNoticeBanner`): enquanto ligado, um aviso no pé da prévia
  diz que a tela fica em 60 quadros e editar e exportar ficam mais lentos, e onde desligar (Central de Controle; nenhum app desliga nem abre a
  Bateria), com ✕; no máximo uma vez por dia (`DefaultsKey.lowPowerNoticeShownAt`), some quando o modo é desligado. Nada para por causa dele.
  UI test: `-uiTestLowPower`.
- **Barra do player:** ‹ › ao lado do Play andam **um quadro** (pausado; segurar repete), para dividir e aparar no ponto exato
  (`QuickEditViewModel+FrameStep`); somem com texto muito grande.
- **Barra de ferramentas:** principal com **Adjust** (vídeo inteiro) ao lado de Filters; o esmaecido só no lado onde há mais ferramentas; "Add
  line" adiciona uma linha na agulha; Text › **Motion** (antes "Animation"); Subtitle e Hook com o símbolo do papel.
- **Avisos** (`EditorPart+Toasts`): dividir, duplicar, apagar e adicionar dizem o quê e onde ("Clip 2 deleted", "Photo added at
  00:07.0") e trazem **Undo**.
- **Dois toques** num texto ou legenda no vídeo abrem as palavras com o teclado (Text style ou a linha em Captions).
- **Folhas:** Translate captions fecha com o X do sistema e escolhe o idioma numa lista com check; Auto captions escolhe o idioma falado numa
  linha que abre a lista no lugar (Automatic primeiro).
- **My style das legendas** (`MyCaptionStyle`, `DefaultsKey.myCaptionStyle`): "Save as my style" e o cartão "My style" no topo de Caption style
  › Presets; um toque põe em todas as linhas (um Undo); legendas novas num vídeo nunca estilizado já nascem nele. Guarda o preset, o look
  copiado, tamanho, destaque, posição e revelação; nunca as palavras nem as margens da plataforma.
- **Testes:** `QuickEditFrameStepTests`, `QuickEditMyCaptionStyleTests`, `LookVersionTests.theOriginalPictureHasNoBackground`,
  `QuickEditPreviewTests` (dois toques), `QuickEditClipLookTests`/`QuickEditBackgroundPanelTests` (escopo), `EditorUITests` (◐ toque e
  segurar), `QuickEditToolbarTests` (Lock), `TimelineGeometryTests` (alcance da alça dentro do clipe, item travado sem alças, música e narração),
  `QuickCreatorViewModelTests.aVoiceOverMovesAndTrimsOnTheTimeline`, `QuickCreatorExportTests.aTrimmedVoiceOverIsHeardFromItsNewStart`,
  `CoverStudioViewModelTests.aTapFindsWhatTheHandlesTake`, `EditorFontCatalogTests`, `OverlayPaletteTests`, `FilterTextureTests`,
  `QuickEditLowPowerTests`, `EditorUITests.testLowPowerModeIsSaidOverThePreviewUntilClosed`; `ToolAuditCaptureTests` (opt-in,
  `TEST_RUNNER_CUE_SCREENSHOT_DIR`) fotografa cada ferramenta (`test11`: tipo, cor e avisos no tamanho padrão e em XXXL);
  `FilterEvaluationCaptureTests` (opt-in, `TEST_RUNNER_CUE_FILTER_PORTRAITS`/`_OUTPUT`) desenha cada filtro em retratos.
- **Contraste:** `PaletteContrastTests.theOriginalBadgesReadOverAnyPicture` ("Original" e o ◐ sobre vídeo branco e preto),
  `theNarrationScriptReadsOverAnyPicture` (roteiro do voice-over), `theLowPowerNoticeReadsOverAnyPicture` (título, frase, ✕ e bateria).

## 45. Quick edit: sólido para o lançamento (Fase A, 23 de outubro de 2026; pedido do dono)

O editor por dentro, para milhares de criadores: nada se perde, nada some, nada trava a tela, e o que falha se explica.
- **Desfazer cobre tudo:** a edição só muda por um caminho (`edit` é `private(set)`; `changeEdit`, `change`, `commit` fazem um passo; `restore` é
  Desfazer/Refazer; `updateFindings` põe o que a escuta achou, transcrições e Clean Up, fora do histórico). O enquadramento arrastado é um passo (o
  Follow face para dentro dele), e o botão de legendas, o cadeado e o idioma das legendas entram no desfazer; um Desfazer em outra coisa nunca os leva
  junto. `EditSnapshotCompletenessTests` falha quando um campo novo de `TakeEdit` não volta num passo nem é listado como achado.
- **Edições salvas por uma versão mais nova abrem:** filtros, fontes, cores, pesos, transições, temas de legenda, formato… desconhecidos viram um padrão
  seguro (`LenientChoice`); um som, adesivo ou tipo de mídia que não dá para mostrar sai sozinho da lista; uma edição ilegível abre a take como gravada; um
  rascunho com passos ilegíveis mantém a edição. O que ficou de fora é anotado (`DecodingReport`), vai ao Console e o `takes.json` é guardado ao lado
  antes de ser salvo de novo. `Fixtures/SavedEdits/saved-takes-1.0.json` é congelado: toda versão futura tem de lê-lo inteiro.
- **Prévia:** a composição é montada fora da linha principal (§42). Dois clipes dos mesmos segundos de gravações diferentes trocados reconstroem a prévia
  (`ItemKey.sources`; teste Mirror de `EditSegment`). Um item que falha depois de tocar mostra "The preview couldn't be built · Your edit is safe" com
  **Try again**, e o Cue tenta sozinho ao voltar para a frente.
- **Sair do editor** cancela tudo que ele começou (`startJob`, prévias curtas, comparação, tradução); o que termina depois é descartado.
- **Rascunho:** gravado 600 ms depois de cada mudança numa fila em segundo plano, com os passos de desfazer finos (legendas e traduções iguais às do passo
  seguinte ficam de fora; ~5× menor num vídeo longo). Leituras, descartes e o rascunho guardado ao sair esperam a fila.
- **Falhas que o criador vê** (exportar, salvar, rascunho, prévia, importar, congelar, inverter, extrair, legendas, Clean Up, Track, traduzir, voice-over)
  vão ao Crashlytics como non-fatal `Editor.<operação>.<motivo>` com contagens e o estado do aparelho, nunca conteúdo (`EditorFailureReport`).
- **Robustez:** mídia de edição que nada cita há 7 dias é apagada no lançamento (busca do nome em todo JSON do app; um arquivo ilegível cancela a
  varredura); voice-over interrompido por ligação ou outro app para e guarda o que gravou ("Recording stopped · Another app took the microphone"), e um
  arquivo que não grava é descartado com aviso; Cancel e "Not yet" durante a gravação guardam a narração no rascunho; foto importada já reduzida a 2160
  px pelo `CGImageSource`; erros do sistema viram frases (iPhone cheio, microfone ocupado, Fotos sem conexão; `EditorErrorMessage`), e "Mic is off for
  Cue" tem o botão Settings.
- **Idiomas:** espaço entre letras só onde a escrita permite (nunca árabe, hindi, tailandês…; textos, legendas, capa e rótulos `interfaceTracking`);
  maiúsculas no idioma do texto (turco "İ"); com árabe escolhido no Cue num iPhone em outro idioma, folhas, capas e pilhas de navegação também ficam da
  direita para a esquerda (`InterfaceDirection`, o traço da janela); o tempo corre da esquerda para a direita em todo idioma (recorte, curva de
  velocidade, quadros da capa, passos de linha, keyframe e quadro); voltar é `chevron.backward`; toasts e escolhas segmentadas usam duas linhas antes de
  cortar.
- **VoiceOver:** textos e fotos sobre o vídeo são ativados como um toque e têm Move up/down/left/right, Bigger, Smaller; a linha do tempo anda 1 s por
  gesto e tem Next cut / Previous cut; Desfazer e Refazer são anunciados; o título do painel recebe o foco e o escape (Z com dois dedos) fecha o painel;
  um contador é um valor ajustável. `EditorUITests.testTheEditorPassesTheAccessibilityAudit` roda a auditoria do Xcode (tamanhos de texto limitados de
  propósito e o esmaecimento da borda da barra à parte).
- **Testes:** `RealMedia` (tag `.realMedia`, fora do Fast): o editor numa gravação real, com o serviço, o player e os arquivos de verdade, pelos passos de
  um criador.
- **Ainda não feito (Fase C):** divisão do `QuickEditViewModel` por ferramenta, `RenderPlan` no lugar da chave do player, reuso das camadas da
  timeline. A Fase B está em §46.

## 46. Quick edit: consistente por dentro (Fase B, 23 de outubro de 2026; pedido do dono)

O editor organizado para crescer sem quebrar: cada coisa num lugar, e a prévia igual à exportação, ferramenta por ferramenta. Nenhuma tela mudou de lugar.
- **Documento** (`EditDocument`): a edição e os passos de desfazer; o único jeito de mudar a edição (`changeEdit`, `change`, `commit`, `updateFindings`,
  um passo por gesto, Desfazer e Refazer). O editor ouve cada mudança e cuida do resto (prévia, rascunho, capa, soltar o que sumiu).
- **O que está escolhido e aberto**: uma seleção só, o corte entre clipes incluído (`EditorSelection.join`, escolhido só com o painel Transition aberto;
  fechar o painel solta o corte). Painel e seleção mudam por `show(_:)` e `pick(_:)`: sair de um painel termina o que acontecia nele, numa ordem; escolher
  algo fecha um painel que não serve para ele **sem** encerrar o passo de desfazer de um gesto. A narração para quando o vídeo para (fim, Pause) e é
  guardada: a regra está no editor, não na tela do painel; o microfone para antes do vídeo.
- **Tarefas** (`EditorJobs`): Auto, legendas, Track, capa, prévias curtas, comparação do Studio Voice, rascunho, batidas, Clean Up, aviso depois de uma
  folha e ferramentas: uma de cada tipo por vez (a nova cancela a antiga e o resultado velho é descartado pelo bilhete), ferramentas lado a lado, e fechar o
  editor cancela todas. Clean Up começa a ouvir ao abrir Pauses.
- **Um enquadramento para vídeo e capa** (`FramePipeline`, `EditFraming`): a capa mostra o que o vídeo mostra naquele ponto (§37). Texto, legendas,
  transições e B-roll ficam fora da capa, que tem título próprio. `CoverMatchesVideoFrameTests`.
- **Prévia = exportação** (`EditRenderRequest`, `EditRenderPurpose`): o mesmo preparo para a prévia do editor, a da revisão e a exportação. A prévia do editor
  toca a timeline esticada até a gravação inteira (as alças mostram quadros de verdade sem reconstruir), mas o zoom de um clipe e as transições são
  medidos na edição como ela é: com o primeiro clipe aparado, o zoom se espalhava pelo clipe inteiro e uma transição ao lado de um clipe curto ficava mais
  longa que na exportação. `PreviewMatchesExportTests` compara 18 ferramentas quadro a quadro, com as duas pontas aparadas.
- **Versões de leitura** (`ReadingVersion`): uma tabela para o look, o Studio Voice, os estilos de legenda, a transcrição e o Auto (versão de hoje,
  primeira, e o que vale quando a edição salva não tem o número). Uma medição do Auto feita por um Cue mais novo não é desenhada (fica salva).
- **Vídeos longos**: as legendas cronometradas na edição são calculadas uma vez por mudança e achadas por linha ou por momento (`CaptionMap`); a lista de
  legendas com mais de 60 linhas cria os cartões conforme aparecem; os arquivos do Studio Voice ficam num limite de espaço (§37); a análise de movimento
  espera Format ou Stabilize (§39). Medido no iPhone: §42.
- **Reverse e importar da biblioteca dizem quanto falta** ("Reversing · 40%", "Importing · 40%", com **Cancel**), num aviso no pé da prévia que só aparece
  se a espera passar de um instante (`EditorWorkPill`). Um vídeo que ainda está no iCloud é baixado antes; Cancel (ou sair) deixa a edição como estava,
  sem mensagem de erro.
- **Um cartão, um aviso, um desfazer**: os cartões dos painéis e folhas são um só (`editorCard`: o fundo do cartão; escolhido, com o fundo de destaque e o
  anel amarelo; marcado, o do Clean Up; 14 pt de canto, anel de 1,5 pt). A Capa usa os toasts do editor (lidos pelo VoiceOver) e o mesmo desfazer
  (`EditHistory`: 60 passos; digitar em sequência é um passo só). Cantos e tamanhos de símbolo do editor vêm de tokens (`Metrics` do editor,
  `EditorGlyph`), e o SwiftLint acusa número solto em `Screens/QuickEdit`.
- **Árabe e outras escritas**: os rótulos em fonte mono (o selo "In edit · Autosaved", contadores e títulos pequenos do app todo) usam a mono só onde ela
  tem as letras (latim, grego, cirílico); em árabe, hindi, tailandês, japonês, coreano e chinês, a fonte do sistema com dígitos iguais (`monoFont`,
  `hudFont`). Os intervalos de tempo ("00:05.2 → 00:07.1", antes → depois do Clean Up, a duração gravada → tocada da Speed) usam "←" em árabe, que lê da
  direita para a esquerda.

## 47. Quick edit: partes, plano de desenho e vídeos longos (Fase C, 24 de outubro de 2026; pedido do dono)

O editor dividido em partes que crescem sem esbarrar uma na outra, a prévia decidida por um plano só, e um vídeo longo leve de editar. Nenhuma tela mudou.
- **Partes do editor** (`EditorPart`): Legendas (`CaptionsViewModel`), Capa (`CoverViewModel`), Visual (`LookViewModel`: Adjust, Auto, Filters, Background,
  Format com Follow face, Stabilize, Copy look), Áudio (`AudioViewModel`: Studio Voice, música, efeitos, batidas, voice-over com o roteiro, Extract audio),
  Sobreposições (`OverlaysViewModel`: textos, gráficos, fotos e vídeos, keyframes, Track, estilos) e Clipes (`ClipsViewModel`: cortar, Speed e curvas,
  Zoom, Volume, transições, montagem, Reverse, Replace clip, Pauses e Clean Up, Edit by text). Cada parte guarda o estado dos seus painéis e muda a edição
  só pelo documento (§46), por uma sessão (`EditorSession`: documento, player, tarefas, avisos, arquivos trazidos, o aviso de progresso, o pedido de foto);
  nenhuma parte chama outra. O editor (`QuickEditViewModel`) é o coordenador: o que está escolhido e aberto, o que a mudança de uma parte significa para
  as outras (sair de um painel, a edição mudou, fechar), o que a prévia toca, a timeline com as faixas de todas as partes, a barra de ferramentas,
  Desfazer e o rascunho. Uma parte segura a sessão, e o editor só de leve: uma tarefa que termina depois de o editor fechar não encontra nada para
  escolher e nunca derruba o app.
- **Plano de desenho** (`RenderPlan`): tudo o que um desenho da edição lê, calculado uma vez a partir da edição e do propósito (§46): a edição como é
  desenhada, onde ela começa e toca no desenho, transições e zooms, opções. A montagem lê só o plano, e a prévia decide se precisa de um item novo pelo
  mesmo plano (`RenderPlan.Item`, no lugar da lista feita à mão do player). Uma exceção, de propósito: o grão de um filtro (Warm Film, Golden Glow,
  Digicam, VHS, Film Mono) conta do começo da edição, e arrastar a alça do começo sob ele não remonta a prévia a cada movimento (o grão é ruído: contado
  de um começo anterior, parece o mesmo).
- **Timeline que guarda o que não mudou**: cada pedaço (régua, capa, clipe com quadros e onda, pausa, corte, item, dica, "+", alça) mantém sua camada
  enquanto aquilo de que foi desenhado não muda; um quadro que chega preenche só o quadrinho que esperava por ele. Mudar a aparência, a escala da tela ou
  Aumentar Contraste desenha tudo de novo.
- **Rascunho de um vídeo longo**: cada passo de desfazer grava as linhas de legenda (e de cada tradução) que mudou, com a ordem só quando linhas entraram,
  saíram ou trocaram de lugar (`LinesChange`), e não todas as linhas em todo passo. 20 correções num vídeo de 600 linhas: de 2,3 MB para 183 KB. Um
  rascunho gravado no meio de um gesto (o app deixado durante um arraste) leva o gesto como um passo próprio, e o Desfazer volta ao começo dele.
- **Legendas diagramadas uma vez**: o tamanho de cada linha fica guardado por estilo (`CaptionLineSizes`); uma montagem que não muda linha nenhuma (um
  ajuste, um corte, um som) não diagrama nenhuma de novo, e uma linha corrigida é a única refeita. As linhas de um vídeo longo ainda não diagramadas são
  feitas lado a lado em todos os núcleos. Medido no iPhone: §42.
