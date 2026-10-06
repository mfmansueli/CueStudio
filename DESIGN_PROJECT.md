# Cue Studio — Design (v30)

Fonte de verdade: `design/cue-v30/handoff-telas/` (começar por `LEIA-ME.md` e `docs/09-Decisions.md`, que vale mais que os outros documentos; `ANIMACOES.md`
e `docs/motion-README.md` têm os valores de cada animação; as telas em `screens/*.html` são a referência visual). O pacote anterior (protótipo `Cue App v30.dc.html`,
documentos 01–08) saiu da árvore e está no histórico do git (commit `bb39f35`; `git show bb39f35:design/cue-v30/prototype/…`). Este arquivo diz **como o app ficou** e
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
deixa de esperar quando virou roteiro. **Reduce Motion (`09` §7):** sem voo nem anel, fade de 0,2 s. **Low Power Mode não muda nada** (decisão do dono em 6/10/2026: as animações tocam em qualquer situação; `speed` só serve para encurtar nos testes de UI). Sem Apple Intelligence não há overlay (a seta é "Write it" e abre um rascunho). A estrela vira uma estrela do céu (`SkyMemory`) ao chegar.
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

`Screens/Profile/Universe`. **9.2:** o núcleo é `UniverseSphere`: uma **esfera de 38 pt** iluminada na cor do núcleo (`CoreColor`, gradiente `#FFFBEA → #FFE680 → #FFD60A → #B88A00`), **suspensa 26 pt acima do meio do disco**, que respira 1 → 1,04 em
**6 s** com um brilho de 58 pt (opacidade 0,78 ↔ 1) e **dois anéis finos inclinados** (−14° e 16°) com uma bolinha de 2,3 pt cada (rosa em 40 s, menta em 31 s); a metade de trás de cada anel passa por trás da bola e a da frente por cima.
O mapa (`UniverseMap`) usa a grade 358 × 320 e é visto de cima, em ângulo: um brilho violeta achatado sob o disco, duas elipses (70 × 43 sólida e 122 × 80 tracejada, raios), **um ponto redondo por vídeo** (1,9–2,9 pt, na cor do tema)
no disco que **gira em volta da esfera numa volta de 140 s** (a metade de trás menor e mais apagada, a da frente maior e mais viva), 16 manchas cinzas de profundidade, rotas **curvas** tracejadas (2·4, 35%) da esfera até as redes (planetas com
brilho e rótulo mono) e a estrela **NEW**, amarela e redonda, na ponta direita da órbita externa, que pulsa em 2,6 s. Tudo para com Reduce Motion (09 §7) e nos anos selados. **Toque no núcleo** abre `UniverseCoreSheet` ("Your light…", os temas
como anéis, os marcos e **Core colour**); a cor (`CoreColor`: Gold, Amber, Sunrise, Rose; `PersonalizationService.coreColor`) mora na folha do núcleo e tinge a bola, o brilho, o card do Profile e a imagem de "Share my universe". Um toque num
ponto abre aquela take (o toque procura o ponto mais perto de onde ele está agora, porque o disco gira). **Fonte desta forma:** a foto do protótipo animado que o dono mandou em 6 de outubro. O PNG `9.2_live-2026` do handoff mostra o
universo **achatado** (pontos como traços, núcleo como disco) e `screens/9.2_Your-universe.html` é a versão antiga (bola com anéis planos): nenhum dos dois serve de referência de forma; os tempos (disco 140 s, halo 40 s) vêm do `motion/README.md`.
O catálogo (`-uiTestCatalogue universe`) mostra os tamanhos × 4 cores e um mapa com 23 vídeos. O núcleo de 44 pt do Profile (`UniverseCore .compact`) continua como era.

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

## 10. Settings nativo, 1.1 e 1.2 (handoff de 5 de outubro · `design/cue-v30/handoff-atualizacao`)

**Settings (11.1, `09` §11).** `List` `.insetGrouped` sobre o céu (`cueGroupedList()`, `cardRowBackground()`, cabeçalhos `CueSectionHeader`), `.searchable` na raiz, toda página
empurrada (`SettingsRoute`; não há mais sheets de Settings). Cada linha é um `SettingsEntry` (título, detalhe, caminho "Prompter › Rigs", palavras-chave) e é desenhada por
`SettingsEntryRow`, a mesma na página e no resultado da busca (`SettingsSearchGroup`). Linhas com 52 pt (`Metrics.listRowContent` + o padding da lista), ícones 30 pt raio 8
nas cores do `09` §11. Rodapé ≤ 60 caracteres, nenhum botão amarelo sólido. Recording, Prompter, Remote, Personalize (Deep Space 25 vídeos, First Light 50 · Pro no texto do
protótipo; o app mantém os 5 ícones e as regras de marco que já tinha), Language & Region (o idioma do app abre os Ajustes do iPhone; Voice following e Script language são
menus), Privacy & AI data (On-device AI é a chave de todos os recursos de IA: `PrivacyPreferencesService` → `ScriptWriting.isEnabled`; Help improve Cue só guarda a escolha,
o app não envia uso), Permissions (`PermissionsService`), Acknowledgements. **"Reset Creator Setup" fica como estava** (decisão do dono pendente, `09` §13). A página Prompter
(`SettingsPrompterView`, prévia fixa no topo) também abre pelo **Aa** do gravador Selfie como sheet `.medium`/`.large` (`PrompterSettingsSheet`) sobre os ajustes daquela gravação;
o Studio mantém o sheet Display. As faixas de `PrompterSettings` valem (altura 160–380, largura 50–93%, margens 8–40, espaçamento 1–2): os sliders mostram a faixa do modelo.
Novos campos de `PrompterSettings`: `isFlippedVertically` (Rigs › Flip vertically) e `safeZoneKey` (a zona que o gravador começa mostrando).

**1.1 Welcome, a abertura com a estrela (`09` §12).** `WelcomeScript` escreve a cena do quadro de 390 × 844 como `PoseTrack`s (a pose de cada coisa em cada segundo): a estrela
entra pela direita, acende 5 pontos do C (0,2 s entre eles), puxa a perna sem acender o sexto, cai em três palavras (TELEPROMPTER, AUTO CAPTIONS, ✦ AI SCRIPTS; o voo usa as posições
medidas das pílulas), volta e explode no sexto ponto; depois o wordmark "CUE STUDIO", o título palavra a palavra, o subtítulo e os botões. `WelcomeStarPainter` desenha num `Canvas`
dentro de um `TimelineView`; toca uma vez (≈ 8 s) e fica. Hápticos: `.soft` nos pontos, `.light` nas palavras, `.success` na explosão. Só o Reduzir Movimento mostra o estado final; o Modo de Baixo Consumo não tira a abertura (decisão do dono, 6/10/2026).
UI tests mostram o estado final, salvo `-uiTestWelcomeOpening`.

**1.2 Topics become worlds.** O marcador do tema é uma barra vertical de 3 × 14 pt na cor do mundo (nunca bolinha); ao tocar: brilho oval recortado pelo raio do chip, cruz de luz e
oito faíscas no centro do chip, uma luz que viaja em curva até a órbita deixando poeira, e a aterrissagem (nove faíscas, dois anéis, cruz de luz) em 1,4 s; então o planeta aparece
(×1,9 → 1), a órbita desenha (1,4–2,7 s) e o nome chega. `TopicBirth` tem os tempos, `TopicBirthPainter` desenha por cima do capítulo. Na entrada um anel amarelo abre no núcleo
(continuação da estrela da 1.1). Reduzir Movimento: o mundo já está lá.

## 11. Exportações grátis acabando (`09` "Free exports running out")

A regra não mudou (5 exportações grátis no Keychain, depois Pro; a contagem é uma por arquivo entregue, `SHARING.md`). Os rótulos vêm de `FreeExportLabels` (9.1 plano, 8.1
medidor, 6.3 linha sob Share), com o tom: neutro, amarelo na última, laranja quando acabam. **Com 0**, Share / Save video / o ícone de compartilhar abrem o sheet **"Your video is
ready"** (`ExportReadySheet`, `.sheet` com a altura do conteúdo e o fechar nativo; miniatura com "✓ READY", **Start free trial · export now** com brilho, **See what's in Pro**
em vidro, **Not now** e a linha "7 days free, then $39.99/year. Cancel anytime." com o preço da StoreKit). Fechar, deslizar ou **Not now** deixam a take pronta (a linha da 6.3 vira "READY ·
EXPORT WITH PRO" até a próxima tentativa) e mostram o toast "Saved in Takes · export with Pro anytime"; Start e See abrem o **Pro calmo** (`PaywallContext.export`: sem a abertura com
warp, eyebrow "YOUR VIDEO IS READY", título "Keep sharing your universe.", subtítulo "Start the trial and export it now.", botão "Start free trial · export now"); ao comprar a
exportação segue sozinha. `-uiTestExportsLeft <0…5>` fixa quantas restam nos testes de UI. Pro e teste mostram "PRO · UNLIMITED EXPORTS" e escondem Go Pro.


## 12. Pro (11.4, `design/cue-v30/handoff-hoje` §4)

`PaywallView` escolhe pelo contexto. **Pro normal** (`.profile`): `ProOpening` (2,4 s, tocável a partir de 1,4 s) e, por baixo, o `SubscriptionStoreView` do sistema (`ProStoreView`,
`.prominentPicker`, Restore visível, política e termos pelos links do app, `onInAppPurchaseCompletion` atualiza o `StoreManager`). `ProOpeningScript` escreve a cena como funções do tempo:
42 riscos (60–200 pt, `cubic-bezier(.5,0,.8,.4)`, 0–1,1 s), núcleo 0,2 → 1,6 (0,7–1,4 s) que depois **sobe até o planeta** (1,5–2,26 s, ×2,6 → ×4,2 enquanto apaga), onda ×0,4 → ×14 (1,25–2,35 s), planeta "você" (acende em 2,05–2,75 s, passa de 1 e assenta; `ProOpeningScript.settled`), conteúdo subindo 18 pt
com desfoque → nítido a cada 70 ms; háptico `.soft` em 1,25 s e `.success` quando o botão pousa. `ProPlanetArt` desenha o planeta (duas órbitas de −7° em metades, três viajantes, faixa de luz) num
`Canvas`; `ProMarketing` é o texto (eyebrow "CUE PRO", "Take your universe further.", "Free to try · 5 exports included. Then 7 days free.", as 6 linhas do quadro com tag mono). **Pro calmo**
(`.export`, `ProCalmView`): sem abertura, os planos próprios (Yearly com SAVE n%, Monthly), o botão "Start free trial · export now" e Restore · Terms · Privacy. Só o Reduzir Movimento: só um fade de 0,3 s.
`-uiTestProAt <s>` congela a abertura. **A linha "Remote from Apple Watch, iPad & Mac sync" não aparece** (`ProBenefit.isAvailable = false`): o app ainda não faz isso, e a tela não vende o que não existe.

## 13. Profile (9.1) e Edit Profile

O Profile continua em rolagem de blocos sobre o céu (as capturas do protótipo): **Edit** na toolbar, identidade (avatar de 60 pt: a foto ou a inicial num degradê violeta, nome, "@usuário · tipo de criador"),
**Your universe** (`ProfileUniverseRow`: núcleo de 44 pt, "2026 · 3 topics", "23 videos" à direita; "Starts with your first share" numa conta nova; "{ano passado} · n videos" num ano novo; a linha de baixo diz quantos
vídeos faltam para o próximo marco), o cartão My Cue Voice e o plano. Toque longo na identidade: **Copy @handle · Share profile link · Edit profile**. `EditProfileSheet` (`.large`, Cancel / Done): foto de 96 pt (`PhotosPicker`,
reduzida a 512 px, guardada em `CreatorProfile.photoData`), Name, Username e Creator type, rodapé "Shown on the universe cards you share."; `ProfileDraft` valida (nome 1–40, usuário 2–24 de a–z 0–9 . _, em minúsculas)
e **Done só vale com tudo válido** ("Profile updated"). Abaixo ficam as preferências de criador (Create for padrão, Monetization goals) e o Sign in with Apple, que já existiam e não estão no protótipo (decisão do dono:
manter ou mover). Mudança de comportamento: uma conta sem nome ainda não pode tocar Done; Cancel sai.

## 14. Your universe, um por ano (9.2)

Dados: cada compartilhamento confirmado é um `ShareRecord` (take, data, **redes**, tema); um vídeo conta uma vez, e cada rede confirmada soma um no seu planeta. Os vídeos de antes dos registros usam a data, a plataforma
e o tema da take. `UniverseContent` decide tudo que a tela mostra (puro, testado): **vivo** (ano corrente: pontos e planetas crescem, o ano anterior aparece como fantasma), **selado** (ano que passou: saturação .75, brilho .92,
nada se mexe, selo "◆ SEALED · DEC 31, {ano}", cartão "{ano} · YOUR YEAR" com planeta principal, melhor mês e sequência de semanas), **conta nova** (sem seletor, núcleo com órbitas a 55%, "FIRST STAR · 0 / 1", review
travado, "Record your first video") e **ano novo** (o seletor tem {anterior} {atual}, "FIRST STAR OF {ano}", a review e o botão amarelo falam do ano anterior). Seletor segmentado na toolbar e deslize horizontal no mapa.
**Planetas** (`PlanetSize`, `PlanetPainter`): `d = 14 + 24·ln(min(n,365))/ln(365)` pt arredondado, brilho a 52, anel a 156, lua a 365; crescem em 0,6 s com `cubic-bezier(.3,1.4,.5,1)` da vez que a tela abre
depois de um share (`MilestoneService.seenPlanetCounts`), com háptico `.soft` ao ganhar um detalhe. **Toques:** planeta → popover (`PlanetPopover`: "n VIDEOS IN {ano}", "k more to unlock …" só no ano vivo, **See in Takes ›**);
ponto → a revisão daquela take; tema na legenda (barra 3 × 14 pt) e planeta → Takes filtrado (`TakesRequest`, chip "{ANO} · SHARED ✕", `TakesScopeChip`); núcleo → `UniverseCoreSheet`.
**Share my {ano} universe** (`UniverseShareSheet` + `UniverseShareViewModel`): cartão 9:16 renderizado com `ImageRenderer` (PNG 1080 × 1920) ou **vídeo de 6 s** (`UniverseMediaRenderer`: AVAssetWriter com a API de
receptores do iOS 27, 20 quadros por segundo, o mapa se forma estrela a estrela), Show numbers / Show @handle, Save to Photos e Share… (folha do sistema). **Year in review** (`YearInReviewView`, 5 slides de 3,2 s,
barras de 3 pt, toque à direita/esquerda, ✕, "Share my {ano}" no último; as fatias sem dados saem, sempre ≥ 2; só a partir de 3 vídeos no ano; ao vivo só a partir de 1º de dezembro, antes disso é "PREVIEW · READY DEC 1").
Reduzir Movimento: barras cheias, sem avanço sozinho. `-uiTestUniverse sample|newYear|newAccount` carrega os dados do painel APP DATA.

## 15. Share to universe (8.1, 8.2, 6.3) · fase A

Na revisão, o botão amarelo é **Share to universe**: renderiza o arquivo (1080 × 1920, sem marca d'água; **nada sai do Cue e nada é contado**) e abre **Ready to travel** com as redes por cima (`ShareNetworkPicker`: TikTok marcado
"· from your script", Reels, Shorts, YouTube ("POSTS AS A SHORT" até 3 min na vertical), LinkedIn, "Also save to Photos", "Share to n networks" e "Uses 1 free export · k left after this"; embaixo, legendas e qualidade como antes).
Fechar o sheet deixa Ready com **Share to universe · Save video · ícone de compartilhar** (folha do sistema). Com 0 exportações, qualquer uma delas abre "Your video is ready". **Uma exportação por envio**: o arquivo é um só para todas as redes
e conta quando sai do Cue (salvo em Fotos ou aceito por uma atividade da folha); editar e reexportar dentro da fila não gasta outra (`ExportLedgerService.begin(inheritingCountFrom:)`). **A fila** (`ShareQueue`, `ShareQueueService`, `ShareFlow`):
a explicação "Posting to n networks" (só com 2 ou mais, nas 2 primeiras vezes), o passo de cada rede ("1 OF 3", barra de segmentos, legenda copiada e editável, "In the share sheet, tap {app}", o aviso "◀ Cue", **Send to {app}** · Edit first · Post later)
e "Posted on {rede}?" — **só "Yes, it's live" conta** e acende o planeta (`MilestoneService.recordShare` com a plataforma). Fechar (✕ ou deslizar) manda o resto para later e mostra "Saved · continue anytime". O card **Continue posting**
(`ContinuePostingCard`: 60 pt, 104 pt acima do fundo) aparece em Scripts, Takes e na revisão; "POST TO {REDE} LATER" fica sob o botão na revisão. **8.2** (`SendOffView`): o cartão vira luz, um cometa por rede (350 ms entre eles) até o planeta
no mapa do universo, "+1", "SHARED TO 3 NETWORKS" / "SHARED TO TIKTOK", "On its way." e o link para a nova estrela. **Fase A:** todas as redes usam a folha do sistema (`ShareIntegrationConfiguration.integrationsEnabled = false`); o código do Share Kit
do TikTok e da passagem do Instagram continua e volta com uma linha quando forem validados no aparelho (`SHARING.md`). `-uiTestFakeShareSheet` troca a folha do sistema por um substituto com Complete/Cancel; `-uiTestShareQueue` deixa uma fila.

## 16. Telas ligadas (`handoff-hoje` §7)

**8.3 Milestone** (`MilestoneView` + `MilestoneScript`, os keyframes de 4,5 s do quadro): seis fagulhas caem num ponto (0–1,35 s), o ícone de 140 pt surge (×0,6 → 1,06 → 1 a partir de 1,17 s, `.success` ao pousar), uma cruz de luz abre e fecha sobre ele
(1,55–2,45 s), um anel dourado (1,35–2,79 s) e um anel pálido (1,5–2,5 s) saem dele, e os raios de trás giram uma volta em 40 s. "MILESTONE · 25 VIDEOS IN 2026", "A new icon is yours.", "25 videos in 2026 · Deep Space icon unlocked", a fileira
"ON YOUR HOME SCREEN" (vidro de 76 pt com quatro ícones) e "Use Deep Space" / "Keep my current icon" (as contas dos marcos continuam sendo de todos os vídeos; o texto diz "in {ano}" como o print; para quem não é Pro o botão diz "Get … with Pro" porque o
app mantém a regra de ícones que já tinha). **1.7 First star** (`FirstStarView` + `FirstStarScript` + `FirstStarScene`, os keyframes de 8 s do quadro, `Keyframes` em `DesignSystem/Motion`): o take mostra "✓ SAVED", dobra em luz (1,55 s), um cometa o leva por uma curva até
a estrela (1,6–2,9 s, sobras de brilho no caminho), a estrela acende (2,95 s, `.success`) com explosão de 10 fagulhas, dois anéis e uma cruz de luz, a linha de YOU até ela se desenha (3,3–4,1 s), "CHAPTER 5 · FIRST STAR" e **"Your universe has its first star."** entram
palavra por palavra (desfoque 8 → 0), depois "Saved in Takes. Share it to light your 2026 universe." (o texto do handoff e do print; o HTML diz outra coisa) e os botões; o brilho cruza "Go to my studio" uma vez. O quadro repete; o app toca uma vez a 7,5 s e fica, com as
órbitas ainda girando. `-uiTestStoryAt <s>` congela as duas. **9.3 My Cue Voice:** um cartão de material só (✦ WHAT CUE USES com a chave, medidor, "Next: …" com Answer, depois ESSENCIAIS / PERSONALITY / PROOF em caixa alta com linhas de 52 pt: rótulo cinza à esquerda,
valor à direita ou "+ Add · 1 tap" em amarelo). **6.2 Takes:** vindo de um planeta ou tema, o chip amarelo "{ANO} · SHARED ✕" mostra só os vídeos compartilhados naquele ano, daquela plataforma/tema; ✕ limpa. **Year in review** abre como `fullScreenCover`
(esconde a tab bar), com fade de 0,3 s; barras e ✕ respeitam a área segura.

## 17. Confirmações como o quadro desenha (11.1 "reset confirm")

`CueActionSheet` (`DesignSystem/Components`): a página escurece e embaixo vêm um cartão com a pergunta em cinza e a ação em vermelho, e um cartão **Cancel** separado, em negrito. O `confirmationDialog` do iOS 27 abre como balão, sem Cancel, e não
dá para ficar como o print; por isso é de Cue ("custom porque o nativo não reproduz"). Usado em **Delete my Cue data** e **Reset Creator Setup**.

## 18. handoff-telas (6 de outubro de 2026): o movimento vem dos dados do quadro

Pacote `design/cue-v30/handoff-telas` (55 telas em HTML, `ANIMACOES.md`, `motion/screens-motion.json`). As versões anteriores saíram planas porque o movimento só estava descrito em texto;
agora cada tela com movimento lê o do próprio quadro.

**Motor** (`DesignSystem/Motion`): `tools/bake_motion.py` transforma os `@keyframes` dos HTMLs (camadas `L<n>`) em `Motion/Data/screens-motion.json`; `MotionLibrary.clip("1.2_topics")` entrega um `MotionClip`,
que responde `pose(of: "L16", at: segundo)` (opacidade, deslocamento, escala, rotação, desfoque, traço desenhado, posição ao longo de um caminho, cor, brilho, recorte) com as curvas de cada trecho. `MotionScreen` é o
**relógio único** da tela (um `TimelineView`; toca uma vez e segura em `hold`; `loops` mantém o movimento de fundo; toque pula quando `skippable`), `MotionTime` leva o segundo da coreografia e o do ambiente. Efeitos
reutilizáveis em `DesignSystem/Effects` (`GlowDot`, `StarTrail`, `ImpactRing`, `CrossFlare`, `LightFX`); as galáxias de 1.3 e 1.4 são desenhadas por `GalaxyPainter` a partir de `galaxies.json`
(`tools/bake_galaxies.py`) com cache (`HeroDiscCache`). **Conferir:** `tools/fidelity` (HTML parado num segundo × app com o relógio congelado; `README.md` lá) e `HandoffCaptureTests` (um PNG por tela).
Cada quadro tem o próprio `.night`: `BgWash+Presets` (`welcome`, `universe`, `voyage`, `message`, `permissions`, `firstStar`, `yourUniverse`, `sendOff`, `milestone`, `pro`, `share`) e
`skyBackground(wash:base:)`; as cores de onboarding, prática e send-off sem papel próprio estão em `Palette+Flight.swift` (nenhum hex solto em `Screens/Onboarding` nem `Screens/Prompter/Practice`).

**Regra de movimento (decisão do dono, 6/10/2026):** o **Modo de Baixo Consumo não tira nem encurta nenhuma animação** (céu, estado vazio, 1.1–1.7, Pro, transição da estrela); a regra de "Low Power: só o estado final" do
`09` §7 foi removida. **Reduzir Movimento** (acessibilidade do sistema) continua mostrando o estado final.

**Onboarding (1.1–1.7)**
- **1.1:** `WelcomeScript` como antes, com o brilho (`BgWash.welcome`), a estrela de passagem (`WelcomeShootingStar`) e os botões nas posições do quadro; entra no céu do onboarding (`OnboardingSky`, `SkyDirector`).
- **1.2 Topics:** **10 temas**, do mais comum ao menos (`Niche.offered`: Fitness & wellness · Food & cooking · Beauty & skincare · Fashion & style · Personal finance · Tech & AI · Budget travel · Productivity & career ·
  Parenting & family · Morning routines) + "+ Your own"; `Wellness` e `Education` saem da oferta mas continuam válidos para quem já os escolheu. O nome do chip é o do mundo em todo o app (`Niche.chipLabel`, usado por
  `OnboardingTopic.label`). De 1 a 3 temas; **Continue** fica cinza ("Pick a topic") até o primeiro, o contador (`TopicCounter`) diz quantos faltam; a luz que sai do chip, o planeta, a órbita e o nome vêm das camadas do quadro
  (`TopicBirth`, instante `idade + 2,6 s`). Com 3 escolhidos os outros chips ficam apagados (um toque neles só dá um aviso tátil); tocar em um escolhido o solta, e então outro pode entrar.
- **1.3 Voyage:** `VoyageScene` (Canvas) com a galáxia do criador (`HeroDiscCache`), as galáxias das redes e a rota até a escolhida; nada vem marcado: **Continue** diz "Choose a galaxy" até um chip ou galáxia ser tocado e depois
  "Head to {rede}"; a linha "9:16 · IDEAL … · SAFE ZONES ON" é digitada em 34 passos.
- **1.4 First message:** `ScriptChapter` com o cartão (`MessageCard`: gancho, corpo, CTA e destino chegam palavra por palavra), o esqueleto, a cápsula "MESSAGE READY FOR LAUNCH" e **Load in teleprompter**; mais de 15 s de espera
  oferecem **Use a ready-made message** (a mensagem embutida do tema); 25 s sem resposta a embutida entra sozinha com o toast "Message ready" (`OnboardingViewModel`).
- **1.5 Permissions:** arte da câmera e do microfone (`VoicePermissionsArt`), linhas tocáveis com **Allow** (a primeira) e **Next** (a seguinte); recusa vira "Off · Turn on".
- **1.6 Practice:** a câmera inteira com a caixa do teleprompter do app (`PrompterView` com `isPractice`), texto de 24 pt, **sem** trilho de seção nem linha de leitura até a contagem; o play abre **GET READY 3 · 2 · 1** com
  anéis, depois **READ!**, a mensagem "Nice. That's your teleprompter." e os dois caminhos (`PracticeStage`, `PracticeBoxOverlay`, `PracticeMessageCard`, `PracticeBottomBar`). Não grava nada.
- **1.7 First star:** `FirstStarView` com o `.night` próprio (`BgWash.firstStar`) e o céu por cima; o núcleo respira com os `box-shadow` do quadro (violeta largo sob branco apertado); o título cabe em 300 pt para quebrar depois de "its".

**8.2 Send-off (refeito no quadro de 390 × 844, escalado à tela):** `SendOffLayout` (órbitas de 316 e 220 pt achatadas a 32% e giradas −9°, YOU de 56 pt, planetas nos pontos do quadro com diâmetros 20/18/17/16/14/12 por ordem de vídeos,
cartão de 54 × 96 pt, estrela nova em (236, 262)), `SendOffScript` (tempos do `ANIMACOES` §2: cartão 0,65 s; estrela de cada rede em 0,52 s + 0,35 s·i, voo de 1,05 s com nove pontos de rastro a 38 ms; pulso ×1,35 → ×1,12 em 0,6 s;
anel ×5 em 0,8 s; "+1" em 1,4 s (0,5 s nas seguintes); a contagem sobe um na chegada; estrela nova 0,3 s depois do primeiro pulso, ×1,8 → ×1), `SendOffMap` (cena) e `SendOffView` (cartão, texto e botões, parados desde o primeiro quadro como no HTML).
O arco da estrela (do cartão ao planeta) não está no quadro: é uma curva quadrática que sobe e abre para fora (`SendOffLayout.arc`).

**11.4 Pro:** o núcleo sobe até o planeta (1,5–2,26 s), o anel nasce em ×0,4, o planeta acende em 2,05–2,75 s e o clarão tem o pico aos 30% (`ProOpeningScript`); a luz acaba em 2,4 s e tudo repousa em 2,75 s.

**6.2 Takes (refeito no quadro):** o topo é o do quadro: título + "12 TAKES · 5 VIDEOS", a **trilha de status** (`TakePipelineCard`: quatro nós de 28 pt sobre uma linha cinza que vira verde e lilás depois de READY; "1" cinza TO PICK, "1" ciano
IN EDIT, "2" verde READY com um anel que pulsa a cada 2 s, ✦ lilás "3 SHARED"; tocar num nó filtra, tocar de novo limpa), o cartão **Up next** (`TakeUpNextCard`: pôster 40 × 56, "UP NEXT · POST IT", título e um botão amarelo Share/Edit/Pick que abre a take
já naquele passo; o cartão abre a take) e as **fichas** (`TakesFilterChips`: a ficha amarela "2026 · SHARED ✕" primeiro quando vem do universo, depois All e uma por rede; a escolhida é branca com texto preto). O menu de rede da barra saiu (as fichas fazem
o papel); o seletor lista/grade continua na barra. O card da grade (`TakeVideoCard`) tem 177:270, anel de 1 pt na cor do estágio (verde pronto, ciano em edição, lilás compartilhado), a pílula do estágio sem anel (READY com ponto verde brilhante, ✦ SHARED)
e, no pé, o título e "● TIKTOK · 1:02" dentro do card (a barra de quatro passos saiu). **Não feito (decisão do dono):** o botão **Select** do quadro (não há seleção em massa no app), a bolinha de tema no card (o `09` pede barra, não bolinha, e o
vídeo não conhece o tema) e os títulos de dia (Today, Yesterday), que o quadro não mostra mas o app mantém.

**8.1 Folhas do Share to universe:** depois da lista de redes cada passo (explicação, passo da rede, "Posted on …?") tem a altura do próprio conteúdo, como as folhas do quadro, e rola só se não couber; "Posted on TikTok?" não tem mais o cartão por trás
do texto. Falta no passo da rede a linha "Cover frame 0:03" do quadro (o app não escolhe quadro de capa).

**11.4 Pro (arte e planos):** a arte do planeta "você" tem o tamanho do quadro (órbitas de 300 × 48 e 192 × 34 pt: os números do `09` são raios) e começa 18 pt abaixo do topo da *tela* (`ProPlansScreen.topInset`); a luz da abertura é desenhada
na tela inteira (`ProOpeningCanvas`, sem a área segura), então o foco (44% da altura) e o planeta (100 pt) são medidos da borda de cima. Os dois planos dividem a largura 1,2 : 1 (`ProPlanRow`), 72 pt de altura, como o quadro (antes o Monthly passava da borda).

**8.3 Milestone:** a cruz de luz e o anel pálido passam por cima do ícone (são as últimas camadas do quadro).

**Onboarding, barra de capítulos:** a prática acende o quarto segmento, o mesmo das permissões (as telas 1.5 e 1.6 do quadro fazem assim); o quinto é do primeiro astro.

**Suposições e diferenças em relação ao HTML (para o dono decidir)**
- A fonte do app é a do sistema (SF); o quadro usa Geist, mais larga: títulos que quebram em duas linhas no quadro têm a largura ajustada (1.7) ou escala mínima (9.2).
- 9.2: a legenda do quadro cobre a terceira linha de tema com o cartão do marco; no app as três linhas aparecem acima do cartão. A tela não é absoluta como o quadro: em aparelhos mais baixos o conteúdo rola.
- 8.2: o texto e os botões não entram em fade (o HTML não os anima); as redes que não receberam o vídeo ficam a 38% como no quadro.
- Os hápticos do onboarding vêm do `09` §12 e do `motion/README.md`; os de 1.2–1.6 são propostas (`.soft` ao tocar, `.success` ao pousar), sem confirmação do dono.
- Argumentos de teste novos (só Debug): `-uiTestOnboardingStep`, `-uiTestChapterAt`, `-uiTestTopicBirthAt`, `-uiTestPlatformAt` (ver `CLAUDE.md` e `LaunchOptions.swift`).

## 19. Correções da revisão do dono (6 de outubro de 2026)

O dono passou pelo app no aparelho e listou o que destoava. O que mudou, e por quê:

- **Voltar do TikTok (travava e dava zoom):** a miniatura de uma take (`TakeThumbnail`) pintava o pôster com `scaledToFill()` + `.clipped()` dentro de um `ZStack`; isso não limita o *layout*: um
  vídeo horizontal fazia a folha "Ready to travel" ficar mais larga que a tela, e ao voltar da folha de compartilhamento o app refazia tudo em escala e travava. O pôster agora é `PosterImage`: a imagem vai em
  `.overlay` de um fundo flexível, então nenhuma proporção muda o tamanho da vista. Testes: `PosterLayoutTests` (5 proporções + sem imagem) e `ShareReturnUITests` (a folha de verdade do sistema).
- **Folhas (fundo e raio):** `cueSheetChrome()` define o fundo (`Palette.sheetNight`) e o raio (`Metrics.sheetRadius`) de todas as folhas do app, e as que têm navegação própria (Format, o fluxo e as perguntas do My Cue Voice, a tradução das legendas) usam `cueSheetSurface()`, que é só esse fundo e esse raio; antes cada uma tinha o seu, ou o cinza do sistema.
- **Scripts vazio:** o Logbook fica na barra e o Format no card do dock **também na primeira visita** (antes sumiam até o primeiro roteiro).
- **My Cue Voice (as 4 perguntas e a folha de perguntas):** mesmo estilo do resto: fundo da noite do app, título 28 bold, chips brancos quando escolhidos, a nota "Common for …" desce para baixo do nome quando não cabe (nunca cortada), e os **temas são os 10 do primeiro voo**
  (`Niche.offered`, rótulos `chipLabel`); um tema que a pessoa já tem fora dos 10 continua na lista. Sem fonte serifada (SF em todo o app: a de Examples, a das ideias e a do tom).
- **Format (+):** o selo "needs brand info" do Sponsored ad vai numa linha própria (não quebra mais o título).
- **Import (+ › Import):** o campo é um cartão `Palette.surface` com borda, como o resto; "Use this script" desabilitado usa o estado desabilitado do botão (sem esmaecer por fora).
- **Profile › Preview** (`VoicePreviewSheet`): a folha do protótipo: "✦ LIVE PREVIEW", título, **My voice | Without** (a mesma frase com e sem a voz), o cartão do exemplo (violeta com a voz) e o interruptor "Write in my voice".
- **Profile › Fine-tune** (`VoiceFineTunePage`, `CreatorVoiceSection`, `CreatorDefaultsSection`, `AccountSection`): lista agrupada nativa sobre o céu, cabeçalhos `CueSectionHeader`, linhas em `cardRowBackground()`, chips de 32 pt.
- **Profile › Your universe:** o núcleo da linha é `ProfileMiniCore` (o `pfCore` do quadro): bola de 14 pt que respira (6 s) num anel de 30 pt com uma bolinha de luz que dá a volta em 7 s. Parado com Reduce Motion.
- **Profile vazio:** sem nome nem foto, o avatar é um astronauta (`AstronautMark`, desenhado em `Canvas`, nas cores do universo); com nome, a inicial de sempre.
- **Pro (a caixa antes da animação):** o cartão dos benefícios aparece junto com as linhas (`revealed`), não antes: o fundo do cartão era desenhado desde o primeiro quadro.
- **O prompter:** todo caminho que grava (botão da câmera, o Record da página do script, o Record do menu da linha, Retake em Takes, o atalho do Siri) chama `PresentationService.openPrompter(mode: .selfie)`: é a mesma tela.
  Só duas telas diferem, de propósito: o **Studio mode** (só o item "Studio mode" do menu abre; ensaio sem câmera) e a **prática do primeiro voo** (câmera inteira, não grava). `PrompterEntryPointsUITests` confere
  cada caminho (os controles do Selfie estão lá e o do Studio não).

## 20. Skin Smoothing (Quick edit › Adjust)

**O controle.** Um chip a mais no fim da fileira do Adjust (**Skin Smoothing**, régua de 0 a 100, como Sharpness): mesmo painel, mesmo Reset, mesmo Compare (◐ mostra a imagem sem ele), mesmo escopo
(o vídeo todo, ou só o clipe escolhido, com a mesma regra de "From the whole take"). Começa em 0 (desligado). A régua e o chip falam com o VoiceOver ("Softens the skin of faces. Eyes, lips, hair and
beard stay sharp."), nos 20 idiomas. Nenhuma outra tela mudou. É independente dos Filters (qualquer filtro, ou nenhum, com o mesmo valor).

**Dados.** `TakeEdit.skinSmoothing` (0…100; ausente em edições antigas = 0, valor fora da faixa é cortado ao ler), `ClipLook.skinSmoothing?` (valor do clipe, que vale em vez do do vídeo; um 0 no clipe é uma escolha),
`LookSettings.skinSmoothing` e `EditLook.skinSmoothing?` (desfazer/refazer; passos de antes não têm o campo e deixam o valor como está). Dividir, duplicar e aparar um clipe levam o valor junto
(`ClipLook` já era copiado). O "Compare" e `withoutPictureLook()` zeram o valor no vídeo e em cada clipe.

**Ordem do processamento** (`FrameLook`): Auto → **Skin Smoothing** → dials do Adjust (Sharpness por último) → filtro → (zoom, transições, B-roll) → textos e legendas. O Skin Smoothing vem antes dos dials e do
filtro de propósito: ele lê os tons da própria imagem, então o contraste dos dials e a gradação do filtro não mexem no que conta como pele ou como textura, o grão de um filtro não é alisado, e o Sharpness
(depois) ainda afia o que sobrou. Textos e legendas são desenhados depois (`CueVideoCompositor.decorated`), então nunca são alisados. As faces são achadas no quadro como foi gravado, antes do efeito de fundo
(um rosto numa foto posta atrás do criador não é alisado). A prévia, a exportação e a capa passam pelo mesmo código (`CueVideoCompositor`, `CoverRenderer`).

**O processamento** (`Managers/Editing/SkinSmoothing/`, só Core Image + Vision, sem kernel próprio nem segundo motor): `VisionFaceDetector` (rostos e marcos, num quadro reduzido a 640 px, rostos pequenos descartados,
até 4) → `SkinFaceTracker` (o mesmo rosto de um olhar para o outro, movimento suavizado, entrada e saída em fade, esquecer no corte/seek) → `SkinMaskRaster` (a máscara da pele no espaço do rosto: dentro da
mandíbula e testa de meio caminho das sobrancelhas ao queixo, sem olhos, sobrancelhas e lábios, bordas suaves) + `SkinToneAnalyzer` (o tom e o ruído da pele **daquele** rosto) → `SkinSmoothingFilter`
(máscara × um portão de tom de pele, borrão que só conta pele, textura pequena atenuada, borda e cabelo mantidos, força limitada). Tudo em valores codificados em sRGB (a escala dos limiares), convertidos de e
para a luz linear do Core Image, e só dentro da região do rosto: um quadro 4K custa o tamanho do rosto, não o do quadro. Os tamanhos são frações da largura do rosto em pixels (1080p e 4K saem iguais).
O limite do topo (100) é conservador: no máximo 60% do suavizado sobre o original e metade (no mínimo) do detalhe fino da pele fica. Sem rosto, ou sem tom de pele confiável, o quadro volta idêntico.
Em 0 nada disso roda (nem o Vision): `SkinSmoother.pass(for:value:…)` devolve `nil` antes de olhar a imagem. Detecção no máximo 20 vezes por segundo do vídeo (numa cópia reduzida do quadro, 640 px, desenhada pela GPU); o mesmo instante pedido de novo não olha de novo. Entre duas detecções o rosto **segue na velocidade que tinha** (`SkinFaceTracker`, até 0,1 s à frente, velocidade limitada a 1,5 larguras do rosto por segundo) e a máscara se move junto, um pouco a cada quadro (sem isso ela andava em degraus a cada dois quadros); a força do efeito só começa a baixar quando a próxima detecção atrasa (antes caía a cada quadro sem detecção e o efeito piscava).

**Dependência.** O YUCIHighPassSkinSmoothing (MIT) foi avaliado e **não** adotado (CocoaPods + kernels `.cikernel` obsoletos + clareia a pele + sem rosto nem vídeo); só a ideia (separar tom e textura pelo canal
verde) foi aproveitada, sem copiar código. Ver `THIRD_PARTY_NOTICES.md`.

**Medido num iPhone 15 Pro (6 de outubro de 2026, retrato real, `SkinSmoothingDeviceTests`):** o Vision acha o rosto no retrato e no quadro 1080p; um quadro 1080p com o efeito custa p50 15,3 ms / p95 30,5 ms (sem ele, 5,6 / 7,0 ms), um 4K p50 32,8 ms / p95 56,5 ms (sem ele, 13,8 / 16,9 ms): dentro dos 33 ms de um quadro a 30 fps em 1080p, e **acima no p95 em 4K** (a prévia pode soltar quadros em 4K; a exportação não depende do tempo real). A região do rosto anda no máximo 0,58% da largura de um quadro para o outro, e a prévia e a exportação diferem em média 0,4 de 255.

**Limites conhecidos.** A pele é achada pelos marcos do Vision e por um portão de cor/brilho do próprio rosto: barba bem fechada e pele muito brilhante (reflexo) ficam fora da máscara por desenho; uma
cabeça de lado (perfil) ou muito pequena não tem marcos e não é alisada. O Vision não acha rostos no Simulator: o teste com rosto de verdade (`SkinSmoothingDeviceTests`) é opt-in e no aparelho.

## 21. Contraste (WCAG 2.2 AA): o que foi medido e corrigido (6 de outubro de 2026)

**Regra** (`CLAUDE.md`, seção Contraste): texto 4,5:1 (grande 3:1), partes de controle e ícones que informam 3:1, medidos no pior fundo, só com os tokens de texto de `Palette`.

**Tokens** (`PaletteContrastTests`, com e sem Aumentar Contraste): `ink`, `ink2` e `inkHint` passam 4,5:1 em todas as superfícies do app (`inkHint` 5,15:1 no fundo, 5,02:1 no cartão e 4,77:1 na faixa de segmento `1F2236`); **`inkHint` não é para o azulejo `surface3`** (4,3:1 ali: azulejos usam `ink2`). `ink3` é 3,8:1: **só** para o que não precisa ser lido (setas, tracejados, anéis, controles desligados). Novo token: `inkOnLight` (preto a 62%, 6:1 sobre branco) para o texto secundário sobre um chip branco escolhido (a contagem de `PlatformFilterChips`).

**Auditoria** (`tools/contrast/audit.py` sobre as capturas de `HandoffCaptureTests`, `UserReportCaptureTests` e `ExploratoryTourTests`: 11.211 textos, 2.021 sem nada desenhado no retângulo e por isso descartados): a ferramenta lê o pixel e **subestima** texto fino e pequeno (um `ink2` de 6,3:1 sai como ~3 em rótulos mono de 10 pt) e erra sob telas escurecidas (menu, confirmação) e botões sobre vídeo. O que se repete a ~3,8:1 sobre o fundo é de fato o `ink3` usado como texto, e isso foi corrigido:
- `ink3` virou `inkHint` onde era texto: "PREVIEW" do prompter, rótulos das pontas dos sliders de Settings, título e requisito dos ícones do app, rótulos esmaecidos da barra do editor, contagem da legenda do universo, a linha de preço de "Your video is ready".
- Opacidades inventadas viraram token: `white.opacity(0.45)` (Year in review), `ink.opacity(0.45/0.5/0.55)` (Milestone, Scripts, ScriptRow, dock, Profile, Paywall, chips), `Flight.ink.opacity(0.4/0.5)` (onboarding: mensagem, voz, esqueleto), `ink2.opacity(0.8)` (etapas da revisão), `aiTextStrong.opacity(0.65)` (chip de ideias): todos `inkHint`, `aiText` ou `inkOnLight`.
- Medido à mão numa captura real: o texto do campo do dock (18:1), os cabeçalhos de seção (6,3:1) e "SELECT" (6,3:1) passam.

**Fica como está, por decisão de desenho:** a linha "3 VIDEOS TO UNLOCK" da revisão do universo e as linhas de um passo ainda bloqueado ficam a 62% (o `09` pede o estado inativo; a regra isenta componente inativo, e o toque explica o motivo); os chips de tema apagados quando 3 já foram escolhidos (desabilitados); setas de disclosure e separadores (decorativos).
