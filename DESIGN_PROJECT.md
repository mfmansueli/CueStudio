# Cue Studio — Design (v30)

Este arquivo diz **como o app está hoje** e as decisões do dono que divergem do quadro, tela por tela. Fonte do design: `design/cue-v30/handoff-telas/`
(`LEIA-ME.md`, `docs/09-Decisions.md`, que vale mais que os outros; `ANIMACOES.md` e `docs/motion-README.md` para o movimento; `screens/*.html` para o
visual). Pacotes antigos só no git (commit `bb39f35`). **Como manter:** ao mudar uma tela, reescreva a seção dela no estado atual; o que saiu do app sai
daqui (o histórico fica no git). Os números das seções são citados no código: não renumere.

O app é **só escuro**. Regras de negócio: 5 exportações grátis (contador no Keychain), 7 dias de teste, preço da StoreKit, cota de IA, pipeline das
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
vídeo), os painéis e a barra do editor, a faixa de estado da página do script, a barra de IA sobre uma seleção (o menu de edição do `UITextView` não
reproduz a pílula violeta), o toast e a dica do My Cue Voice (`VoiceTipViewStyle`). Confirmações destrutivas: `CueActionSheet` (§17).

## 2. Scripts (3.1, 3.2) — o dock

`Screens/Scripts/Dock/ScriptsDock.swift`: vidro limpo (sem céu dentro, `09` §2), em `.safeAreaInset(.bottom)` acima da tab bar.
- **Linha 1:** Format ⌄ · For {Rede} ⌄ · ✦ Voz nn% · lâmpada do Find inspiration (§30). Chips de 36 pt de toque; aparecem também na primeira visita.
- **Linha 2:** o campo (2 linhas em repouso, até 5 editando, 200 caracteres: §25; a ideia sugerida enquanto vazio), ↻, microfone e a seta amarela
  (**Write it** sem Apple Intelligence).
- **Dobra** (`DockFold`, `ScriptsView.foldDock`): a linha 1 recolhe ao rolar para baixo (passa de 40 pt e mais de 2 pt de movimento, somando passos
  pequenos), volta em qualquer subida, nunca com o campo focado; 0,28 s `(0.2,0.8,0.2,1)`, um movimento só (o vidro fecha sobre os chips, que somem em
  0,2 s). **O espaço reservado embaixo da lista não muda com a dobra**: quando mudava, a lista pulava ~205 pt e o dock abria e fechava sem parar. O quique
  no fim não conta como subida. Lista curta (rola < 80 pt) recolhe ao passar da metade; uma que rola < 16 pt nunca recolhe. Log: `studio.cue` / `DockFold`.
- Campo focado: a lista escurece e desfoca (0,25 s). Durante a seleção o dock sai.
- **Busca:** `SearchField` sempre visível no topo da lista (entre "6 SCRIPTS · 1 READY" e os filtros, rola com ela); o dock fica durante a busca e, com o
  teclado da busca, fica embaixo dele. Por que não `.searchable`: com `.searchToolbarBehavior(.minimize)` o ✕ do iOS 27 só minimizava a busca (a lista
  ficava filtrada e o dock não voltava). Dica do campo em `ink2`.
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
(0,6 s), o app atrás escurece (brilho 0,35, desfoque 10 pt, escala 0,94), halo, 12 partículas, "Writing in your voice", a ideia e 7 frases a cada 1,6 s,
Cancel. Dura **no mínimo 3,0 s**; quando o roteiro chega: frase final, capa sólida (0,22 s), anel (0,42 s), a estrela pousa como cursor amarelo onde
começa o título (0,44 s) e a página escreve (§5.2). O teclado desce quando a estrela sobe e a página não o pede de volta. **Cancel ou erro:** a estrela
cai 40 pt e some (0,3 s), nenhum roteiro fica, a ideia continua no campo (erro: toast "Couldn’t draft it · Try again"). Reduzir Movimento: fade de 0,2 s.
Sem Apple Intelligence não há overlay. Idioma que o modelo não escreve: a estrela nem sai (§8). A estrela vira uma estrela do céu (`SkyMemory`); Scripts
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
  Reset My Cue Voice.
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

Enquanto o roteiro é escrito, `ArrivingText` substitui o editor: cada palavra entra de blur 7 pt e 5 pt abaixo em 0,3 s, com brilho violeta (`#C4B8FF`
95%, some em 0,8 s), a cada 0,17 s (mais rápido quando chegam muitas, nunca > ~1 s atrás do modelo); cursor violeta de 2 pt pisca depois da última.
Pílula **"✦ Drafting in your voice"** (`ScriptWritingPill`, 34 pt): brilho de borda 2,4 s e brilho branco a cada 1,6 s; sem a estrela por cima (Try again)
mostra a porcentagem até as palavras chegarem. **A página escrevendo é a página escrita:** título, contador, faixa de estado (com **Stop** no lugar do
Done), "Does it sound like you?" e o aviso de fatos (desabilitados) já no lugar, com as margens do editor (`ScriptTextEditor.textInsets`); nada se move
ao terminar. Parar tira a pergunta da voz. Reduzir Movimento: fade de 0,2 s, cursor aceso, pílula parada. `-uiTestCatalogue writing`. A barra de 3 pt por
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
de voz e estado; (3) chips **Size · Line · Margin · Mirror · Aa More** (`StudioAdjustBar`): um slider por vez (S–XL, linha 10–70%, margens 8–40 pt; o slider
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

Sem tela nova; mensagens nos componentes que já existiam (detalhes em `LOCALIZATION.md` §1.1):
- **Seta ✦** (`ScriptStarter`): se o modelo não escreve no idioma da ideia, a estrela nem sai; toast "Apple Intelligence can't write in this script's
  language yet." e a ideia vira um rascunho em branco.
- **Ferramentas da página** (Improve, seleção, Translate, hooks): o erro dá o motivo quando o criador pode agir (idioma, **par** de idiomas, modelo se
  preparando, resultado em outro idioma); "Couldn't draft it · Try again" só quando tentar de novo resolve. Parar não mostra erro. **Translate** só age
  com o idioma escolhido.
- **Legendas** (`CaptionState.missingLanguages`): diz qual idioma ficou de fora (com **Retry**); par recusado: "This iPhone can’t translate…".
- **Language & Region › Voice Following:** "Ready on this iPhone", "Downloads the first time you use it", "Not available on this iPhone"
  (`LanguageCapabilityService`). Script Language não mostra suporte de IA.

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
`SettingsEntryRow`, igual na página e na busca (`SettingsSearchGroup`); linhas de 52 pt, ícones 30 pt raio 8 nas cores do `09` §11; rodapé ≤ 60
caracteres, sem botão amarelo sólido. Páginas: Recording, Prompter, Remote, Personalize (céu §5, Getting started §32; os 5 ícones e as regras de marco do
app, não as do protótipo), Language & Region (idioma do app abre os Ajustes; Voice following e Script language são menus), Notifications (§27), Privacy &
AI data (**On-device AI** é a chave de todos os recursos de IA: `PrivacyPreferencesService` → `ScriptWriting.isEnabled`; Help improve Cue decide se os eventos
vão ao Analytics), Permissions (`PermissionsService`), Acknowledgements. **Reset Creator Setup fica como está** (decisão pendente, `09` §13).
**Prompter** (`SettingsPrompterView`): na aba, com prévia no topo e céu; pelo **Aa** do Selfie abre como `PrompterSettingsSheet` (`.medium`/`.large`,
`sheetMaxHeight`, fundo `Palette.surface`, sem prévia, `isRecorderSheet`), sobre os ajustes daquela gravação, medindo a linha de leitura pela tela e lente
do gravador (`SettingsPrompterView.screen`). Faixas de `PrompterSettings`: altura 160–380, largura 50–93%, margens 8–40, espaçamento 1–2;
`isFlippedVertically`, `safeZoneKey`, `showsCues` (desligado por padrão).

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

Rolagem de blocos sobre o céu (`profileBlock()`): **Edit** na toolbar, identidade (avatar de 60 pt: foto, inicial num degradê violeta, ou, sem nome nem
foto, o astronauta `AstronautMark`; nome, "@usuário · tipo de criador"), **Your universe** (`ProfileUniverseRow`, núcleo `ProfileMiniCore`: bola de 14 pt que
respira em 6 s num anel de 30 pt com uma luz que dá a volta em 7 s; "2026 · 3 topics", "23 videos"; "Starts with your first share" numa conta nova;
quantos vídeos faltam para o próximo marco), o cartão My Cue Voice e o plano. Toque longo na identidade: Copy @handle · Share profile link · Edit profile.
**`EditProfileSheet`** (`.large`, Cancel / Done): foto de 96 pt (`PhotosPicker`, 512 px, `CreatorProfile.photoData`), Name, Username, Creator type,
"Shown on the universe cards you share."; `ProfileDraft` valida (nome 1–40, usuário 2–24 de a–z 0–9 . _, minúsculas) e **Done só vale com tudo válido**
("Profile updated"). Abaixo, **Create for**, **Monetization goals** (`EditProfilePreferences`) e **Sign in with Apple** (`EditProfileAccount`, ação
imediata, fora do Cancel / Done).

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

Regra em `CLAUDE.md`. **Tokens** (`PaletteContrastTests`, com e sem Aumentar Contraste): `ink`, `ink2` e `inkHint` passam 4,5:1 em todas as superfícies
(`inkHint` 5,15 no fundo, 5,02 no cartão, 4,77 na faixa `1F2236`); **`inkHint` não vai no azulejo `surface3`** (4,3:1; use `ink2`). `ink3` (3,8:1) só para o
que não precisa ser lido. `inkOnLight` (preto 62%, 6:1) para texto secundário sobre chip branco.
**Auditoria** (`tools/contrast/audit.py` sobre `HandoffCaptureTests`, `UserReportCaptureTests`, `ExploratoryTourTests`): a ferramenta **subestima** texto fino
e pequeno (um `ink2` de 6,3:1 sai ~3 em mono de 10 pt) e erra sob telas escurecidas e sobre vídeo; confira à mão os falsos positivos.
**Exceções por desenho:** "3 VIDEOS TO UNLOCK" e passos bloqueados a 62% (componente inativo), chips de tema apagados com 3 escolhidos, setas e
separadores, o astronauta (§5.0.1).

## 22. Página do roteiro, revisão, Quick edit e gravador (pedidos do dono)

**Página do roteiro (o único editor):** Text size pelo **Aa**; salva enquanto se escreve; ••• tem "Make a version for…" (cópia para outra rede), Remind me…
(§27) e Delete (com Undo, como a lista). A versão do roteiro (v2, v3…) liga as takes ao texto lido.
- **Record preso ao pé** (`ScriptRecordButton`, no `safeAreaBar`): cápsula de largura toda (`CueStudioButtonStyle` grande, Liquid Glass amarelo; vidro sem
  tinta num roteiro gravado e sem mudança) sobre o efeito de borda do sistema. Sempre visível (sobe com o teclado do título); o teclado do texto põe as cues
  no lugar dele; apagado enquanto a IA escreve. (A barra de baixo do sistema não dá largura toda.)
- **Cues sobre o teclado** (`ScriptCuesBar`, no mesmo `safeAreaBar`): uma barra de Liquid Glass (tingida com `surface`), cues como etiquetas amarelas que
  rolam com degradê nas pontas, divisor e **+** fixo. O + abre "New cue" (sem colchetes, até 24 caracteres, `ScriptCueName`): entra no cursor e fica na barra
  para todos os roteiros depois das quatro do quadro (`PreferencesService.customCues`); segurar uma do criador: "Remove from bar". (O
  `ToolbarItem(placement: .keyboard)` não dá largura e deixava as cues sem fundo.)
- **Cues ligadas/desligadas** (botão **Cues** ao lado de Improve, `Toggle` `.button`; `PreferencesService.showsCuesOnPage`, ligado por padrão): desligado,
  as cues ficam no texto mas transparentes e com 1 pt. O teleprompter tem o seu (`PrompterSettings.showsCues`).
- **Apagar uma cue apaga a cue inteira** (`ScriptCueDeletion`), com o cursor onde ela estava.
- **"AI can get facts wrong"** (`FactCheckBanner`): centrado na vertical, texto `ink`.

**Revisão da take (6.3):** barra de navegação do sistema (`ReviewToolbar`, `NavigationStack` próprio, fundo escondido sobre o vídeo): voltar, "TAKE 2 OF 3 ✦ ⌄"
como título com menu (takes vizinhas, Suggest best) numa cápsula de vidro, estrela (`star` / `star.fill`) e lixeira numa cápsula à direita.

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
VoiceOver (`SelfieControlSheet`); a área de toque da folha é contêiner de acessibilidade (`ControlSheet`).

**Logbook:** título grande (`.large`) com "Catch it now. Write it later."; segurar o botão grava e um toque começa/termina ("Tap the button again to
finish"; onde nada pode ouvir, diz por quê). Enquanto ouve, a linha embaixo é só "Listening…" e as palavras entram no campo (cresce até 4 linhas; Return
salva). Uma ideia salva rola para cima do teclado. Siri sem abrir o app (`AddToLogbookIntent`: "Add an idea to Cue" / "Save an idea in Cue", pergunta
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
Decoração fora do texto: nenhum par de contraste muda. A sombra só existe fora do cartão (o cartão translúcido de Settings deixa as estrelas passarem).
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

## 26. Gravação e espelhamento da tela escondem as prévias

Gravar a tela com uma prévia tocando daria o vídeo sem exportar. Com a cena gravada, espelhada ou em AirPlay, toda superfície de vídeo vira um cartão
opaco e o player para. Grátis e Pro, sem interruptor.
- **Detecção** (`SceneCaptured`): o `isSceneCaptured` do SwiftUI (traço `sceneCaptureState` da cena; `UIScreen.isCaptured` será descontinuado), lido ao
  aparecer (`onChange(initial: true)`). A gravação do próprio Cue não marca a cena.
- **Onde:** revisão da take, prévia e tela cheia do Quick edit, câmera do Selfie e da prática. Pôsteres, capas e quadros da linha do tempo ficam.
- **Cartão** (`CaptureShield`, `captureShielded(_:)`): `Palette.surface` opaco, `eye.slash` em `ink2`, "Stop screen recording or mirroring to view this
  preview." em `ink`. Sem animação. A superfície fica na árvore com opacidade 0 e sem toques (o player guarda item e posição; a prévia da câmera continua
  dando a rotação). Na câmera, moldura, grade e zonas seguras somem; teleprompter e controles ficam.
- **Player** (`ReviewPlayback`, `QuickEditPlayer`/`EditPlayback.isPlaybackBlocked`): ligar pausa no quadro; enquanto vale nada toca (botão, sessão de áudio,
  busca, reconstrução, voice-over), e um player ligado por fora é parado. No editor a agulha ainda se move. Desligar **não toca**. Sem AirPlay de vídeo
  (`allowsExternalPlayback = false`, que não marcaria a cena).
- **Gravações:** take e voice-over continuam (relógio do voice-over é `recorder.elapsed`). **Exportações:** nada muda.
- **Limites:** é detecção, não bloqueio; o primeiro quadro pode entrar; tela escondida atrás de outra só atualiza ao voltar; câmera apontada para a tela não
  é detectável.
- **Testes:** `ReviewPlaybackTests`, `QuickEditPlayerTests`, `QuickCreatorViewModelTests`, `ExportAccountingTests`, `ScreenCaptureUITests`;
  `-uiTestSceneCapture` + `SimulatedSceneCapture` (o Simulator não marca a cena). **Falta no aparelho:** Gravação de Tela durante a revisão (tocando e
  parada), começada antes de abrir o Cue, editor e tela cheia, voltar ao primeiro plano, Espelhamento para Apple TV/Mac, gravação no meio de uma take e de
  um voice-over.

## 27. Notificações, lembretes e introdução de ferramentas

Sistema completo em `NOTIFICATIONS.md`. Na interface:
- **Settings › Notifications** (`NotificationsSettingsView`, ícone `bell.badge.fill` em `Palette.danger`, valor "Off" ou "Reminders: n"): **On this iPhone**
  (`NotificationPermissionSection`: **Allow notifications** com o estado On / Delivered quietly / Off in iOS Settings / Not asked yet; o toque pede uma vez ou
  abre os Ajustes), **What Cue sends** (cinco categorias; ferramentas e novidades desligadas), **Days and time** (só com a rotina: chips de dia na ordem da
  semana do iPhone, `acc`/`accInk` escolhido, `surface3`/`ink` não; `DatePicker`), **My reminders** (toque edita, deslizar remove; Set, Kept in Cue, Due),
  **Automatic notifications** (quiet hours, pausa de 7/30 dias) e **Show titles in previews**. Em Debug, uma seção DEBUG.
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
  (`EditorUITests.testPlayPlaysAndPauseHoldsThePlayhead`).

## 29. Text style e Caption style (Quick edit)

- **O painel cresce** (`EditorPanelContainer(expansion:)`): alça (decorativa) e botão de expandir no cabeçalho (44 pt, "Expand panel" / "Collapse panel");
  arrastar o cabeçalho 24 pt faz o mesmo. Expandido, o vídeo vai ao menor tamanho do editor (`EditorLayout(panelIsExpanded:)`); a escolha vale para os dois
  painéis enquanto o editor está aberto (`stylePanelIsExpanded`). Altura normal de um painel `.full`: metade da tela (330–420 pt). No iPhone SE o painel é
  folha e o botão troca as duas alturas. O conteúdo para 18 pt acima do Home Indicator (`Metrics.editorStylePanelBottomClearance`) e some em degradê
  (`scrollEdgeEffectStyle(.soft)`).
- **Abas na largura toda** (Presets · Font · Color · Motion), 44 pt; campo e abas fixos, só o resto rola; trocar de aba volta ao topo (`contentKey`). Cores
  (`PanelSwatches`) de 34 pt, segmentos de 38 pt.
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
- **Lâmpada no dock** (`InspirationDockButton`, `CueIcon.findInspiration` 20 pt, `FindInspirationSheet.icon`: lâmpada com uma órbita que passa
  atrás dela, mais suave, e na frente; também na nota "Starter ideas" e na introdução da ferramenta): à direita do My Cue Voice na linha 1, **em qualquer
  estado de Scripts**, contorno amarelo em vidro discreto, 44 pt, "Find inspiration"; dobra com a linha. Sem largura, o chip da rede perde o "For" e depois os
  chips rolam com a lâmpada fixa. Sem dica de primeiro uso.
- **A folha** (`Screens/Scripts/Inspiration/`; abre pela lâmpada, por + › Let Cue draft it e pela notificação de ideia): título, "Ideas to start from.",
  chips de tema ("All my topics" e os salvos, escolhido em violeta; "Topics" abre o editor do My Cue Voice), órbita parada, **um cartão** violeta (TEMA ·
  SUBTEMA · TIPO, título, YOUR ANGLE, OPENING LINE), **Another idea** logo abaixo (ou deslizar; explosão de estrelas de 0,35 s, fade de 0,2 s com Reduzir
  Movimento), **Start with it** em amarelo embaixo, a linha que diz que a ideia vai para o campo, e "✦ Draft it now". Estados: esqueleto, "Finding more
  ideas…", falha com **Try again**, sem temas, sem Apple Intelligence (ideias de partida para escrever à mão).
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
- Contraste: tokens `inspirationCard`, `…Glow`, `…Border`, `inspirationChipOn`, `inspirationOrbit` em
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
- **Capa de qualquer gravação** (`CoverSource.clipFrame`, `CoverFrame`: gravação, clipe e segundo da gravação; `TakeEdit+Cover`). O quadro é sempre o
  da gravação onde foi escolhido, desenhado com o look do clipe que o mostra (uma cópia pode ter o seu); trocar a ordem, duplicar, dividir ou mudar a
  velocidade só muda onde ele toca. Capas antigas (`.frame(segundos)`) são quadros do take. **Se o trecho sai da edição**, a capa continua a mesma
  (da gravação) e a aba Frame diz "This frame is from a part you removed…" com **Use the frame at the playhead**.
- **Exportação: vídeo e capa separados** (`QuickEditExportModel.cover`, `CoverExportState`). "Saved to Photos" é do vídeo; embaixo, a linha da capa:
  Saving the cover… / Cover saved to Photos / Cover not saved (com o motivo), **Tentar de novo** (só salva de novo; desenha só se nunca desenhou) e
  **Share cover**. A imagem fica no temporário até a folha fechar e então é apagada.
- **Studio Voice na montagem** (`StudioVoiceReach`, `TakeEdit+Voice`, `RecordingSounds`, `RecordingSoundCache`): trata o take e as outras gravações
  (cada uma pode ficar de fora em "Applies to"; o take sempre). **Even out volume between clips** leva a fala de cada gravação ao nível do take (até
  +9 / −12 dB, nunca acima de −1 dBFS: uma gravação com pico alto sobe só o que cabe, `AudioCeiling.leveled`). Música, voice-over e som de fotos/vídeos
  por cima nunca são tratados. Prévia e exportação usam os **mesmos arquivos** (cache compartilhado, até 8 tratados; a exportação não trata de novo).
  Edições antigas: só o take, sem nivelar. Subtítulo do painel: "Whole take", "All 3 recordings" ou "2 of 3 recordings". Desfazer cobre tudo (`EditLook`).
- **Clean Up na montagem** (`CleanUpSuggestion.sourceID`, `EditTimeline+CleanUp`, `TakeEdit.cleanUpAnalyzedSources`): ouve cada gravação uma vez (uma
  nova, ao abrir de novo); a lista segue a ordem em que tocam e o cartão diz de onde é ("Interview · 00:22.0"). Remover corta aquela gravação onde ela
  toca (em cada cópia, na velocidade dela), nunca outra no mesmo segundo. Uma gravação que não pôde ser ouvida não apaga as sugestões das outras.
- **Mídias sobrepostas** (`QuickEditViewModel+OverlayPicking`): cada janela visível tem sua alça, na ordem em que o vídeo empilha (a escolhida por cima,
  para alcançá-la mesmo coberta). Um toque pega a de cima; tocar de novo onde elas se cobrem pega a de baixo; tocar a escolhida sozinha abre o painel.
  Contorno das não escolhidas: branco tracejado com halo escuro (`Palette.Editor.overlayOutline`/`overlayOutlineHalo`). **Durante o arraste o vídeo
  não desenha o item** (texto fora da composição; foto/vídeo com opacidade 0 na mesma faixa, sem piscar) e a cópia sob o dedo é a única.
- **Legendas na montagem** (`CaptionJoin`): **Join next** junta só a próxima coisa dita na mesma gravação, pela ordem de reprodução; outra gravação
  ("The next line is from another clip") ou um momento anterior ("…said earlier in this clip") são recusados. O ajuste de início/fim fica dentro do
  clipe da linha; arrastar a barra para um clipe de outra gravação é recusado ("A line stays on its own clip"); Split funciona numa cópia.
- **Testes:** `TakeEditCoverTests`, `CoverRendererTests` (vídeos reais), `QuickEditExportModelTests` (capa), `StudioVoiceReachTests`,
  `StudioVoiceMontageExportTests` (áudio real: −9 dB → dentro de 2 dB), `QuickEditMontageCleanUpTests`, `QuickEditOverlayPickingTests`,
  `QuickEditMontageCaptionTests`.
