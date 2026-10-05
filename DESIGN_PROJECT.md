# Cue Studio — Design (v30)

Fonte de verdade: `design/cue-v30/` (começar por `LEIA-ME.md` e `09-Decisions.md`, que vale mais que os outros documentos; `motion/README.md`
tem os valores de cada animação; o protótipo `prototype/Cue App v30.dc.html` é a referência visual). Este arquivo diz **como o app ficou** e
onde as decisões foram tomadas; atualize-o junto com a UI (ver `ARCHITECTURE.md`, seção 5).

O app é **só escuro** (v27, mantido). As regras de negócio não mudaram: 5 exportações grátis (contador no Keychain), 7 dias de teste, preço da
StoreKit, cota de IA e o pipeline das takes (`TakeStage`).

## 1. Nativo primeiro (`07-Liquid-Glass.md`)

| Onde | Como é |
|---|---|
| Tab bar | `TabView` do sistema com `.tabBarMinimizeBehavior(.never)`: a barra não recolhe ao rolar as listas (decisão do criador; o `07` §1 pedia `.onScrollDown`); Record fica no meio como aba normal (`09` §4), nunca `role: .search` |
| Barras de navegação | Scripts, Takes, Profile, Settings e a página do script usam `NavigationStack` + `.toolbar` (voltar do sistema, `ToolbarItemGroup`, `ToolbarSpacer`); Scripts usa `.searchable` + `.searchToolbarBehavior(.minimize)` |
| Sheets | `cueSheetChrome()` (`DesignSystem/Components/CueSheetChrome.swift`): `NavigationStack` com `Button(role: .close)` em vidro à esquerda e fundo de vidro do sistema; `fittedSheet()` soma `Metrics.sheetBarHeight` à altura. `SheetHeader` é só título e subtítulo |
| Botões | `CueStudioButtonStyle`: primário (amarelo) e secundário são Liquid Glass (`.glassEffect(.regular.tint(acc).interactive())`); `.glass` sobre vídeo; os outros mantêm o próprio preenchimento |
| Menus, pickers, contexto | `Menu`, `Picker`, `.contextMenu` |

**Vidro simulado / customizado (exceções do `07` §2) e por quê:** o dock de Scripts (`DockSurface`: vidro nativo sobre as duas auroras do `09` §2), a
barra do recorder e as folhas sobre a câmera (`GlassNight`; precisam ficar sobre vídeo), os painéis e a barra do editor, a faixa de estado da página
do script, a barra de IA sobre uma seleção (a pílula violeta do protótipo, que o menu de edição do `UITextView` não reproduz), o toast e a dica do
My Cue Voice (`VoiceTipViewStyle`).

## 2. Scripts (3.1, 3.2) — o dock

`Screens/Scripts/Dock/ScriptsDock.swift`: vidro limpo (sem céu dentro, `09` §2), fixo em `.safeAreaInset(.bottom)` acima da tab bar.
Linha 1: **Format ⌄ · For {Rede} ⌄ · ✦ Voz nn%** (chips de 36 pt de toque; o Format some na primeira visita). Linha 2: campo de duas linhas
(a ideia sugerida enquanto vazio), ↻, microfone e a seta amarela (**Write it** sem Apple Intelligence). A linha 1 recolhe ao rolar para baixo
(`DockFold`: passa de 40 pt e mais de 2 pt de movimento, somando os passos pequenos de uma rolagem lenta; volta em qualquer subida; nunca com o
campo focado; 0,28 s `(0.2,0.8,0.2,1)`). A dobra é um movimento só (`ScriptsView.foldDock`): a linha leva o espaçamento junto e o vidro fecha sobre os
chips, que ficam parados e somem em 0,2 s. **A lista não sente a dobra:** o espaço que o dock reserva embaixo dela continua o mesmo (o lugar da linha
vira espaço vazio, que deixa passar o toque); quando o fim da lista mudava com o dock, a lista pulava sozinha (~205 pt, medido) e o dock abria e fechava
sem parar. No fim da lista o quique não conta como subida. Uma lista curta (rola menos de 80 pt) recolhe ao passar da metade do que rola, e fica
recolhida parada no fim; uma que quase não rola (menos de 16 pt) nunca recolhe. `DockFold` registra cada mudança no Console
(`studio.cue` / `DockFold`, com a fase da rolagem). Com o campo focado a lista escurece e desfoca (0,25 s). Durante a busca e a seleção o dock sai. Ditado, rascunho e voz são os de antes
(`IdeaDraftService`, `DictationService`).

Abaixo da lista: **Logbook · n waiting** (até 2 ideias com ✦ Write e "Open Logbook ›"), `ScriptsLogbookSection`. Enquanto a biblioteca carrega,
`ScriptRowSkeleton` com o brilho de 1,4 s (`SkeletonShine`).

**Formatos (`09` §1):** grade de 9 (Auto · Talking head · Tutorial · Storytime · List / tips · Review · Myth vs fact · POV · Sponsored ad) e a
seção **More formats** com uma linha para cada `ScriptType` que a grade não mostra (Hot take / reply, Launch, Apology). *Talking head* continua sendo
"sem `ScriptType`" (reusa o que já significava isso; não houve caso novo).

## 3. A estrela é a transição (`09` §8, `motion/README.md`)

`IdeaTransitionService` (relógio e estado) + `StarTransitionOverlay` (desenho, por cima do app em `MainView`) + `ScriptStarter.write(from:)`:
a estrela sobe da seta ao centro (0,6 s), o app atrás escurece (brilho 0,35, desfoque 10 pt, escala 0,94), halo, 12 partículas, "Writing in your
voice", a ideia e 7 frases que mudam a cada 1,6 s, Cancel. Dura **no mínimo 3,0 s** (ou o que a IA precisar); quando o roteiro chega: frase final, capa
sólida (0,22 s), anel abrindo (0,42 s), a estrela pousa como cursor (0,44 s) e a página escreve. O teclado do campo desce quando a estrela sobe e a
página aberta por baixo não o pede de volta (título e texto são da IA; `loadPage` não foca nada com um pedido pendente). **Cancel ou erro:** a estrela cai 40 pt e some
(0,3 s), o overlay some (0,22 s), nenhum roteiro fica, a ideia continua no campo (erro: toast "Couldn’t write it · Try again"). A ideia do Logbook só
deixa de esperar quando virou roteiro. **Reduce Motion / Low Power (`09` §7):** sem voo nem anel, fade de 0,2 s; Low Power corta os tempos à metade
(`speed`). Sem Apple Intelligence não há overlay (a seta é "Write it" e abre um rascunho). A estrela vira uma estrela do céu (`SkyMemory`) ao chegar.
O catálogo de debug (`-uiTestCatalogue transition`) segura o estado de espera para fotografar.

## 4. My Cue Voice (`04` §F9, `08`)

- **Dados:** `CreatorProfile` ganhou `style` (energia, frases, palavras, palavrão; o antigo `swearing` migra para cá), `avoid` + `avoidNone`,
  `reach` (redes, duração, humor), `audienceLevel` e `approvals` (todos opcionais, `decodeIfPresent`). Os 8 papéis, os temas (`Niche`) e os 6 tons de
  antes ficam; os tons são 8 (`warmCalm` e `dry` novos; só os rótulos de `casual`, `professional` e `funny` mudaram, os valores salvos não).
- **Força** (`voiceStrength`): Essentials 40 · Personality 40 · Proof 20, com os pesos por campo do `08` §1 (`VoiceField`); cada duas aprovações
  de "Sounds like me" contam como um exemplo.
- **Banco:** `VoiceQuestion` (17 perguntas, na ordem da fila) + `CreatorProfileService+VoiceAnswers` (um lugar para escrever, com a validação do
  `04` §F9). "Talking head" é guardado como a tag "Talking head" e "Reaction" é o formato Hot take / reply.
- **Quando:** `VoiceQuestionScheduler` (relógio injetável, estado em `VoiceQuestionState`): 2 dias de uso e 1 roteiro, 1 dica por dia e 3 por semana,
  "Not now" adia 3 dias, 2 dispensas mandam a pergunta para o fim, 3 seguidas pausam 14 dias, "None of these" pula para sempre, para em 100% (um toast),
  reiniciar na página 9.3. Gatilhos que adiantam uma pergunta: 1ª exportação, 2ª edição de um roteiro escrito na voz, 3º roteiro gravado.
- **Dica:** TipKit cuida da lógica (`VoiceQuestionTip`, uma dica por pergunta e rodada) e `VoiceTipViewStyle` do visual (`09` §3), 10 pt acima do dock
  (Scripts) ou da tab bar (Takes). A folha (`VoiceQuestionSheet`): fechar nativo, lista agrupada, "+ Something else", "None of these", "Saved · voice
  nn%" e "One more question" (no máximo 3 respostas seguidas).
- **9.3:** as três camadas pelos campos, cada linha abre a folha daquele campo; "What Cue sends" mostra os campos novos; Reset My Cue Voice.
- **Fluxo de 4 perguntas** (2.1–2.4): a audiência pergunta também o nível ("How much do they already know?") e o último passo tem "Add a voice example".

## 5. Movimento

Céu (`StarfieldMath`): 14 twinkles de 7 s (Soft: 7), comet a cada 105–135 s (o primeiro aos 25 s, relógio do app); deriva 260/160/85 s; nebulosa
26 s. Tudo o mais segue `motion/README.md` e as seções 12 e 13 da v27/v29 já implementadas (contagem, send-off, marco, first star, núcleo YOU, empty state).

## 5.1. Your universe (9.2) e o núcleo YOU

`Screens/Profile/Universe`: o núcleo é `UniverseCore` (`.full` 9.2, `.compact` 9.1, `.preview` na folha). **9.2 (`.full`):** bola de 34 pt em gradiente
(`#FFFBEA → #FFE680 → #FFD60A → #B88A00`, brilho a 38% / 34%) que respira 1 → 1,04 em **6 s**, brilho de 132 pt na cor do núcleo (opacidade 0,78 ↔ 1,
6 s), **três anéis** de 23, 29 e 35 pt (menta, âmbar, rosa, 38%) com uma bolinha de 2,3 pt que gira em **22, 31 e 40 s** (partindo de 20°, 160° e 280°) e
três faíscas de quatro pontas. O mapa (`UniverseMap`) é desenhado na grade 358 × 320 do quadro: brilho violeta de 74 pt, duas elipses (70 × 60 sólida e
122 × 105 tracejada), **um ponto parado por vídeo** (1,6–2,4 pt, na cor do tema, em lugar estável por `videoSpot`), rotas **curvas** tracejadas (2·4, 35%)
até as redes (nó de 4 pt com halo de 10 pt a 18%) e a estrela **NEW** que pulsa 2,4 → 3,6 pt em 2,6 s. Só o núcleo e a estrela NEW se mexem; tudo
para com Reduce Motion (09 §7). **Toque no núcleo** abre `UniverseCoreSheet` ("Your light…", os temas como anéis, os marcos e **Core colour**); a cor
(`CoreColor`: Gold, Amber, Sunrise, Rose; `PersonalizationService.coreColor`) também mora em Settings › Personalize e tinge a bola, o brilho, o card do
Profile e a imagem de "Share my universe". O catálogo (`-uiTestCatalogue universe`) mostra os 3 tamanhos × 4 cores e um mapa com 23 vídeos.

## 5.2. A IA escrevendo na página (4.1)

Enquanto o roteiro é escrito a página mostra `ArrivingText` no lugar do editor (volta quando termina): cada palavra entra de blur 7 pt e 5 pt abaixo
em 0,3 s, com um brilho violeta de 14 pt (`#C4B8FF` 95%) que some em 0,8 s, a cada 0,17 s (mais perto quando chegam muitas, nunca mais que ~1 s atrás do
modelo), e um cursor violeta de 2 pt pisca (1 s) depois da última palavra que chegou. A pílula **"✦ Writing in your voice"** (`ScriptWritingPill`, 34 pt,
centrada embaixo) tem o brilho de borda de 2,4 s e o brilho branco que cruza o texto a cada 1,6 s. **A página escrevendo é a página escrita:** título e
contador iguais, a faixa de estado já no lugar (com **Stop** onde vai ficar o Done), "Does it sound like you?" e o aviso de checar fatos esperando
(desabilitados) desde a primeira palavra, e o texto chega com as margens (`ScriptTextEditor.textInsets`: 8 pt em cima e embaixo, 5 pt dos lados),
o tamanho e as etiquetas de cue do editor; nada se move quando termina. Parar no meio tira a pergunta da voz. Reduce Motion: as
palavras só aparecem (fade de 0,2 s), o cursor fica aceso e a pílula parada. `-uiTestCatalogue writing` mostra a cena. **Diferença:** a barra de 3 pt por
seção do quadro (`sc10`) não existe na página única (as seções saíram da escrita); fica para quando a página mostrar as seções.

## 5.3. Onboarding: a escrita e as permissões

- **Escrita do primeiro roteiro** (`OnboardingWritingNotice`, dentro do card do `ScriptChapter` enquanto `scriptState == .writing`): uma estrela que respira
  num halo violeta (2,4 s), "Writing with Apple Intelligence, on this iPhone" com o brilho branco que cruza as palavras a cada 1,6 s (o mesmo da
  pílula da página) e "Written on this iPhone. Nothing leaves it." Parada com Reduce Motion. Sem modelo não há espera (o roteiro de prática aparece na hora).
- **Permissões** (`VoiceChapter`): cada linha é um botão. Sem resposta mostra **Allow** (a primeira sem resposta em amarelo, "a próxima"); tocar pede aquela
  permissão (o microfone pede também a Fala). Negada mostra **Off · Turn on** e abre os Ajustes (o sistema não pergunta duas vezes). Voltar dos Ajustes
  relê o estado. **Continue** pede o que faltar. Se algo foi negado, o rodapé vira "No problem, you can still practice…": o fluxo nunca trava.
- **Tópicos** (`UniverseChapter`): o que se escreve em "+ Your own" entra na lista como chip (`customTopics`), escolhido; se for solto o chip continua
  na lista e pode ser escolhido de novo.
- **Prática** (`SelfieModeView` + `PracticeBottomBar`): a câmera cobre **a tela toda** (`CameraBackdrop(fillsScreen:)`, `resizeAspectFill`; a prática não grava,
  então não há moldura, grade nem zona segura). O painel de baixo é o do gravador, em vidro noturno: **Voice | Steady** (`ScrollModePicker`), voltar ao
  topo, play, e a linha de voz ou o slider de velocidade; embaixo os dois caminhos como botões de verdade: **Record it for real** (amarelo) e **Not now — take
  me to my studio** (vidro). O modo escolhido vale também na gravação de verdade (mesma sessão). Sem microfone o Voice fica apagado, a prática usa Steady
  (`PrompterViewModel.startPractice`) e uma linha diz "Voice Following needs the microphone." com **Open Settings** (relê o estado ao voltar dos Ajustes).
  Sem câmera o `CameraBackdrop` já avisa e leva aos Ajustes. Depois da prática, `MicrophoneNeededCard` cuida do Record.
- **Fala** (`SystemPermissions.requestSpeech`): o callback do `SFSpeechRecognizer.requestAuthorization` volta numa fila de fundo; o closure fica num
  `nonisolated static` (dentro de uma classe `@MainActor` ele herdaria o isolamento e o Swift 6 aborta com `dispatch_assert_queue_fail`).

**Teleprompter, só foco (v30):** o texto não acende palavras. Com o Voice Following o texto tem **uma cor só** e apenas **rola conforme a voz é
reconhecida** (`SpeechLead`, `VoiceGlide`, `ScriptSpeechTracker`); o realce das últimas palavras ditas, o texto a 42% e a palavra nova em amarelo da v27
saíram (`PrompterHighlighter`, `WordSpans` e `HighlightedParagraph` foram apagados). A linha de leitura, o trilho de seções e o chip de voz continuam.

## 5.3. Studio é só teleprompter, e o Selfie lembra o último ajuste

**Studio (v30)** (`Screens/Prompter/Studio`): sem câmera, sem gravar e sem permissão de câmera; serve para **ensaiar** o texto, **ajustar** onde ele fica
para os olhos e a velocidade, ou **ler com outra câmera filmando** (o espelho e o Remote continuam). Saíram a miniatura da câmera, o botão de gravar, a
última take, os ajustes de câmera, virar câmera, a linha de microfone e setup e a barra compacta da gravação (a decisão da v29 · 5.3 de gravar pela câmera
traseira foi desfeita; gravar é do Selfie). O texto é o `PrompterTextView` de tela cheia com a linha de leitura em `guidePosition`, e um toque nele toca ou
pausa. **Barra** (`StudioControlPanel`, vidro noturno como a do Selfie, com uma alça que a guarda e um botão ⌃ que a traz de volta): (1) Voice | Steady,
‹‹ 3 linhas, play, 3 linhas ››; (2) a velocidade (Steady) ou a linha de voz e o estado do reconhecimento (Voice); (3) **chips Size · Line · Margin · Mirror ·
Aa More** (`StudioAdjustBar`): Size, Line e Margin abrem **um slider por vez** (tamanho S–XL, linha 10–70% da tela, margens 8–40 pt), Mirror vira o texto
para o vidro de um rig e Aa abre o Display. Acima do texto, **"0:42 LEFT" e "1:12 · IDEAL 1:00–1:30"** (`StudioTimeLine`, no ritmo escolhido). **Contagem:** dar
play **do começo** usa a contagem de Settings › Prompter (Off, 3, 5, 10 s) para dar tempo de se posicionar; durante ela a barra some e um toque cancela;
retomar depois de uma pausa toca na hora. Voice Following ouve pelo medidor do microfone (sem câmera).

**Selfie: a caixa abre no alto.** Uma linha de leitura guardada pelo Settings antigo a mais de ~1/3 da tela (`PreferencesService.lowestUsualLineOffset`, 260 pt
abaixo da lente) punha a caixa no meio; ela é apagada uma vez (`readingLineResetV30`) e a caixa volta ao lugar recomendado (118 pt sob a lente). **Último ajuste
lembrado:** ao sair do prompter, o que o criador deixou (caixa: largura e altura; linha de leitura; tamanho e margens do texto; velocidade; espelho; Voice |
Steady) vira o ponto de partida da próxima sessão (`SessionSetupService.rememberReadingLayout`). Câmera, qualidade, uma recomendação da plataforma ou fonte e
cores continuam só da sessão; "Back to my setup" volta ao que estava ao abrir. O treino do onboarding não grava nada.

## 6. Argumentos de teste (só Debug)

Além dos de sempre: `-uiTestVoiceTip` (abre as portas da dica) e `-uiTestStarTransition` (mantém os tempos reais da estrela; os testes de UI os
encurtam). `-uiTestSlowWriting` (com o roteirista de teste, as palavras chegam devagar para fotografar a página no meio da escrita).
`-uiTestCatalogue transition` mostra a estrela; `universe` e `writing` mostram o núcleo e a escrita.

## 7. Suposições (lacunas do protótipo)

- O dock some durante a busca e a seleção; o tip espera 1,2 s com a tela quieta (sem sheet, toast, teclado, busca ou seleção).
- A estrela pousa onde começaria o título da página (cursor amarelo) e sem destino medido no protótipo.
- "Speak" do exemplo (08 X1) não foi feito (só Paste e My scripts); o microfone do dock dita ao toque, sem "segurar para gravar".

## 8. Idiomas e Apple Intelligence: nenhuma tela nova (v30)

O trabalho de qualidade de idiomas (`LOCALIZATION.md` §1.1) não mudou layout, identidade visual nem navegação. Só mudaram **mensagens**, que
reaproveitam os componentes que já existiam (toast, linha de estado das legendas, lista de Language & Region):

- **Seta ✦ do card de ideias** (`ScriptStarter`): se o Apple Intelligence não escreve no idioma da ideia, a estrela nem sai. Um toast diz o motivo ("Apple
  Intelligence can't write in this script's language yet.") e a ideia vira um rascunho em branco para escrever à mão, como já acontecia sem o Apple
  Intelligence. Antes a estrela voava 3 s e caía com "Couldn't write it · Try again", que não resolvia nada.
- **Ferramentas de IA da página do script** (Improve script, seleção, Translate, hooks): o erro mostra o motivo quando o criador pode agir sobre ele
  (idioma não suportado, **par** de idiomas na tradução, modelo ainda se preparando, resultado em outro idioma) e "Couldn't write it · Try again" só para
  o que tentar de novo resolve. Parar uma ferramenta não mostra erro. **Translate** só age com o idioma escolhido no menu (antes caía em espanhol).
- **Legendas** (`CaptionState.missingLanguages`, na linha de estado que já existia sob o interruptor): quando o roteiro usa outro idioma por um trecho e este
  iPhone não consegue ouvi-lo, as legendas dizem qual idioma ficou de fora (com **Retry**), em vez de omitir o trecho sem avisar. Um par de idiomas que o
  sistema recusa no meio da tradução diz "This iPhone can’t translate…" (como a checagem prévia), não "Try again".
- **Language & Region › Voice Following** continua com os mesmos três rótulos ("Ready on this iPhone", "Downloads the first time you use it", "Not
  available on this iPhone"), agora vindos de `LanguageCapabilityService` (uma consulta, guardada), e a lista de Script Language não mostra suporte de IA.
- Textos novos: 3 strings, nos 20 idiomas (`LocalizationCatalogTests` confere placeholders e presença em todos).

## 9. Compartilhar: a tela é a mesma, o que ela diz ficou exato

"Share to" (`ShareToSheet`), "Ready to travel" e "On its way" mantêm layout, botões e navegação. Mudou o que cada estado **afirma** (detalhes e
regra de contagem em `SHARING.md`):

- **Contagem:** a exportação grátis é descontada quando o vídeo comprovadamente sai do Cue (salvo em Fotos, atividade da folha de compartilhamento
  concluída, Share Kit do TikTok), uma vez por arquivo exportado. Abrir um app, preparar o arquivo, cancelar ou falhar não desconta.
- **"On its way" / "Shared to X"** só aparece com entrega comprovada àquele app. Quando só o app abriu (plataformas sem integração configurada:
  vídeo salvo em Fotos), a tela é "Ready to travel" e o aviso continua "Ready to post on X" (o vídeo está pronto); no LinkedIn o vídeo só é salvo e o aviso
  recomenda postar pelo app ("Saved to Photos · Open LinkedIn to post it", sem abrir o app); no Instagram (vídeo na área de
  transferência, sem resposta da Meta) o aviso diz "Opened X with your video · Cue can't see if you post it" e não há celebração (a exportação conta: o vídeo saiu do Cue).
- **Avisos novos** (toast, nos 20 idiomas): "Shared with X", "Sharing cancelled", "Couldn't share · Try again", "Saved to Photos · Open X to post it", "X isn't on this iPhone · Pick
  another app" (a folha do sistema abre em seguida) e "X didn't take the video". Nada diz "postado" ou "publicado": nenhuma plataforma informa.
- **Sem Fotos:** os destinos usam a folha do sistema, que recebe o arquivo direto; só **Save video** mostra o cartão "Open Settings".

