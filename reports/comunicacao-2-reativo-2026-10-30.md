# Cue Studio — inventário do sistema de comunicação REATIVO

Tudo o que o app diz de volta ao criador em resposta a algo: toasts, alertas e confirmações, avisos dentro das telas, erros, estados vazios, progresso, retorno durante a gravação, limites e Pro, anúncios do VoiceOver. O lado proativo (notificações locais, TipKit, dicas da primeira viagem, onboarding, folhas de convite, celebrações) está no outro inventário.

**Método.** Levantado no código de `main` (1f62fb24, 30/10/2026), sem build. O texto em inglês é a chave do String Catalog (`Cue Studio/SupportFiles/Localizable.xcstrings`, e `Cue Studio Watch/Localizable.xcstrings` para o relógio); o PT-BR é o valor `pt` do catálogo (o catálogo só tem `pt`, que é o português do Brasil). Os toasts foram extraídos por script de todas as chamadas `toast.show` / `showWorking` e dos atalhos que terminam nelas (`sayUndoable`, `say`, `sayApplied`, `sayAdded`, `sayAfterSheet`, `adopt`, `finishExtracting`, `announce`, `gone`, `ReminderFeedback.show`, `remove(…message:)`, `file(…message:)`, `add(…saying:)`); as demais seções listam cada texto dos arquivos de cada componente (linha a linha). `%@` / `%lld` são valores inseridos em tempo de execução; `[one] … / [other] …` são as variações de plural. Strings só de acessibilidade (rótulos de VoiceOver) aparecem quando estão nos arquivos listados; identificadores de teste foram omitidos.

**Contagens.** Ver o fim de cada seção e o resumo em "Observações".

## 0. Componentes visuais (para redesenhar em HTML)

Tokens: `Palette` em `Cue Studio/DesignSystem/Tokens/Palette/*.swift`, medidas em `Metrics.swift`, tipos em `InterfaceType.swift` / `CueStudioFont.swift` (`cueFont(...)` escala com Dynamic Type). Valores: `bg #0A0B12`, `surface3 #2B2F48`, `ink #FFFFFF`, `ink2 #E1E4F5 @62%` (80% com Aumentar Contraste), `inkSoft branco @80%` (92%), `acc / accText #FFD60A`, `accInk preto`, `warn / warnText #FF9F0A` (`#FFB340` em AC), `aiText #B4A7FF` (`#CFC6FF`), `Metrics.gutter 16`, `hitTarget 44`, `toastRadius 22`, `editorNoticeRadius 17`, `cardRadius 26`, `sheetRadius 38`.

| Componente | Arquivo | Como é |
|---|---|---|
| Toast (pílula) | `DesignSystem/Components/ToastView.swift, ToastIcon.swift, Styles/View+ToastSurface.swift, Motion/AnyTransition+Toast.swift, Tokens/Palette/Palette+Toast.swift` | Pílula **opaca** `Palette.Toast.fill #2B2F48`, canto contínuo 22 pt, contorno 1 pt branco 24% (40% em AC), duas sombras (preto 35% r3 y2 e preto 50% r14 y10). Altura mínima 44; padding esq. 9, dir. 16 (6 com botão), vertical 9 (6 com botão). À esquerda o disco de 26 pt (escala com `.subheadline`): ✓ verde `#34C759`, ★ amarela `#FFD60A`, ! laranja `#FF9F0A`, glifo preto; `working` = anel (trilho branco 28%, arco amarelo de 1/4 que gira a cada 0,9 s). Texto `cueFont(.subheadline, .semibold)` `ink`, até 2 linhas, encolhe até 85%. Botão opcional (Undo, Settings, Write it, On the seam…): cápsula `acc` com texto preto semibold, 32 pt de altura, área de toque 44. Entrada: opacidade + 8 pt de cima em 0,25 s (curva `CueMotion.light`), saída fade 0,2 s; Reduzir Movimento: só fade. Ícone: disco cresce de 50% (mola 0,32 s), ✓ desenha (Draw On) a partir de 0,2 s, ★ gira de −40° e 40%→118%→100%, ! balança (−16°, 12°, −6°, 0) preso embaixo. Topo da tela, 8 pt abaixo da safe area, margem 16 (editor: 10 pt, margem 16, sobre a prévia). Toque na pílula dispensa. Um por vez: o seguinte substitui (o de trabalho vira o resultado na mesma pílula). |
| Host do toast | `Screens/Shared/Toast/ToastHost.swift, Screens/QuickEdit/Bars/EditorToastHost.swift` | `toastHost()` na raiz (`RootView`) e no gravador (`PrompterView`); `toastHost(inSheet: true)` só no Logbook. `EditorToastHost` no editor, Cover Studio, AddMediaSheet, BrandKitEditorSheet, BrandKitApplySheet (duração padrão 2 s enquanto está na tela; 2,4 s no resto do app; 4 s com botão; 60 s de teto para `working`). |
| Pílula de trabalho do editor | `Screens/QuickEdit/Player/EditorWorkPill.swift, Support/EditorWork.swift` | Cápsula com `toastSurface`, anel de progresso amarelo `Palette.Toast.ring`, texto `ink` ("Importing · 42%"), botão **Cancel** em `accText`. Sobre a prévia. |
| Aviso de Pouca Energia | `Screens/QuickEdit/Player/LowPowerNoticeBanner.swift` | Cartão com `toastSurface`, canto 17 pt (`editorNoticeRadius`), ícone `battery.25percent` em `accText`, título + texto `ink`, ✕ (44 pt). Sobre a prévia do editor; nunca bloqueia. |
| Confirmação destrutiva Cue (`CueActionSheet`) | `DesignSystem/Components/CueActionSheet.swift` | `fullScreenCover` com fundo preto 40%; embaixo, cartão `surface3` canto 16 com a pergunta `cueFont(13.5)` `ink2` centrada (padding 20/14), separador 0,5 pt, ação `cueFont(19)` em `Palette.danger` (56 pt); 8 pt abaixo, cartão **Cancel** `cueFont(19, .semibold)` `ink`. Toque fora cancela. Margens 8. |
| Alerta / confirmationDialog do sistema | `SwiftUI `.alert` / `.confirmationDialog`` | Visual nativo do iOS 27 (o `confirmationDialog` abre como balão ancorado, sem Cancel visível quando não declarado). Usados com campo de texto (nomear pasta, cue, estilo, código) e em erros de compra/importação/rascunho. |
| Cartões de aviso na revisão (export, parou, Fotos) | `Screens/TakeReview/Sections/ExportProgressCard.swift, ExportStoppedCard.swift, PhotosDeniedCard.swift` | Cartão `surface` canto 16; título `cueFont(.subheadline, .semibold)` `ink`, texto `cueFont(.footnote)`; ícone `exclamationmark.arrow.circlepath` (18) ou `photo.badge.exclamationmark` (20) em `warnText`; barra de progresso `acc`; botão secundário compacto (`cueSecondary`) e ✕ de 44 pt. Calor em `warnText`. |
| Nota de IA indisponível | `Screens/CreateScript/GenerateScript/AIUnavailableNote.swift` | Linha com `sparkles` + texto `cueFont(.footnote)` `ink` sobre `surface`, canto 16. No dock de Scripts, "+ › Let Cue draft it", Answer a comment, Sponsored ad. |
| Aviso de fatos (Ultra/IA) | `Screens/ScriptDetail/Structure/FactCheckBanner.swift` | Faixa `warnWash` com borda `warnBorder`, canto 16, `sparkles` em `warnText`, texto `cueFont(.footnote)`, botão **Checked** semibold em `accText`. |
| Nota de painel do editor (`PanelNote`) | `Screens/QuickEdit/Panels/Controls/PanelNote.swift` | Só texto `.footnote` do sistema (não `cueFont`), `ink2` (ou tint passado), quebra livre. 72 usos. |
| Linha de status de legenda / tradução | `Screens/QuickEdit/Panels/Captions/CaptionStatusRow.swift` | Linha com texto de estado, `fill` de fundo, botão **Stop** / **Try again** (44 pt). |
| Cartão de análise de movimento | `Screens/QuickEdit/Support/MotionAnalysisNote.swift` | Linha de texto com porcentagem dentro dos painéis Auto/Stabilize/Face follow. |
| Cartão de recomendação de setup | `Screens/Prompter/Controls/SetupRecommendationCard.swift` | Cartão sobre a câmera, canto 26, gradiente `Camera.recommendationTop→Bottom`, borda `recommendationRim`, ícone `sparkles` em disco, título `.headline semibold`, texto `.subheadline`/`.footnote`, botões **Use Recommended** (primário amarelo) e **Keep My Setup** (`cueGlass`). |
| Aviso de parar cedo (monetização) | `Screens/Prompter/Controls/StopWarningCard.swift` | Cartão `warningCard` canto 26 com borda `glassBorder`, ícone `stopwatch` `warnText`, título `.headline semibold`, texto `.subheadline`, botões **Stop anyway** (primário) e **Keep going** (`cueGlass`). |
| Câmera/microfone sem acesso | `Screens/Prompter/Camera/CameraBackdrop.swift, Controls/MicrophoneNeededCard.swift` | Fundo da câmera com `video.slash` `.title`, título `.headline semibold`, texto `.subheadline`, botão `cueGlass` compacto **Open Settings**; cartão do microfone `warningCard` canto 26, `mic.slash.fill` `warnText`. |
| Estado vazio (`EmptyState`) | `DesignSystem/Components/EmptyState.swift, EmptyStateMark.swift, EmptyStateIcon.swift` | Marca animada (anel `Scripts.emptyRing`, órbita `emptyOrbiter` com brilho, ícone em `aiTextStrong`) ; título `cueFont(22, .bold)` tracking −0,44 `ink`; mensagem `cueFont(15)` `ink2` até 280 pt; botão primário amarelo (com ponto vermelho opcional, "● Record"); link `cueFont(15, .semibold)` `inkSoft`. |
| `ContentUnavailableView` | `SwiftUI` | Visual do sistema: ícone SF grande, título e descrição centrados (Settings sem resultado, roteiro/take apagado, capa ilegível, scanner indisponível). |
| Folha "Your video is ready" | `Screens/TakeReview/Share/ExportReadySheet.swift` | Folha `sheetNight`; miniatura com selo "✓ READY" (`Takes.posterPill`, `success`); título `cueFont(22, .bold)`, texto `cueFont(15)` `ink2`; **Export with Cue Pro** primário com brilho; **Not now** texto. |
| Folha de duração (`LengthNudgeSheet`) | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift` | Folha curta: duração `~1:42`, título `.title3 bold`, texto `.subheadline`, **Record anyway** (primário com ponto `record`) e **Make it shorter** (`cueAI`, violeta, `sparkles`). |
| Contagem regressiva | `Screens/Prompter/Camera/CountdownOverlay.swift` | Número gigante branco (`CueStudioFont.countdown`) no centro da câmera; tocar cancela (VoiceOver: "Recording in N" / "Cancels the countdown"). |
| Cartão de rastreamento do Blur | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift` | Linha com sinal (✓ `successText` / ! `warnText`), texto `ink`, botões Track / Track again / Go there / It's right; barra `acc`. |
| Relógio: aviso (`WatchNoticeView`) | `Cue Studio Watch/Screens/WatchNoticeView.swift, WatchNotice.swift` | Tela cheia do watchOS: título, explicação, botão (Try again / Refresh / OK) e o último estado conhecido ("Last state at 10:42: recording, 0:31"). |

**Haptics que acompanham mensagens** (`SupportFiles/Haptics`): toast ✓ sem vibração (o toque do criador já teve a dele), exceto quando encerra um trabalho (`Haptics.success`); toast ★ `Haptics.soft` 0,35 s após chegar (no auge da estrela); toast ! `Haptics.warning` 0,2 s após chegar (no balanço); trabalho que termina bem `Haptics.success`. Fora dos toasts: aviso da primeira viagem `Haptics.soft`; Blur seguido com o painel aberto `Haptics.success` / `Haptics.warning` + anúncio do VoiceOver em vez de toast; sair da conta `Haptics.medium`; adicionar área de Blur `Haptics.selection`. Alertas e `CueActionSheet` não vibram.

## 1. Toasts

Serviço `Cue Studio/Managers/ToastService.swift` (um toast por vez; `show(_:kind:duration:action:)`, `showWorking` / `endWorking`; cada toast é anunciado ao VoiceOver por `AccessibilityNotification.Announcement`). Tipos em `Models/ToastKind.swift`: **done ✓** (padrão), **cue ★**, **problem !**, **working** (anel). Botão: `Models/ToastAction.swift` (um só; o toque executa e fecha). Durações: 2,4 s no app, 2 s com o editor na tela (`EditorToastHost`), 4 s com botão, 5 s nos avisos de notificação tocada (`NotificationNavigator.goneDuration`), até 60 s ou até o próximo toast para `working`. Posição: topo da tela (no editor, topo da prévia). "Option C" de §52 é este sistema (tipos com ícone colorido, Undo amarelo; `DESIGN_PROJECT.md` §1 "Avisos (toasts)").

Launch args úteis: base `-uiTestInMemory -uiTestSeedSamples` (o `CueApp.launch` dos testes já usa `-uiTestFastAnimations`); editor `-uiTestSampleVideo` / `-uiTestDemoEdit` (+ `-uiTestDemoTranscript`, `-uiTestDemoSplit`); IA `-uiTestStubAI`, `-uiTestNoAI`, `-uiTestAIUnavailable <language|device|off|preparing|cue>`, `-uiTestScriptLanguage th-TH`, `-uiTestWriterStalls`, `-uiTestIdeasFail`; Ultra `-uiTestUltra -uiTestUltraAllowed -uiTestUltraScriptsLeft 0`, `-uiTestUltraReviewFails`; compartilhar `-uiTestFakeShareSheet`, `-uiTestAppsInstalled`, `-uiTestShareQueue`, `-uiTestExportsLeft <0…3>`; exportação `-uiTestSlowExport`; permissões `-uiTestPermissions denied`; notificação tocada `-uiTestNotificationTap <destino>`, `-uiTestNotificationAuth <estado>`; remoto `-uiTestRemoteConnects`; primeira viagem `-uiTestVoyage`; Pro `-uiTestPro`. A coluna de arg não é repetida em cada linha: vale a da tela.


### 1.1 App (raiz)

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T001 | done ✓ | `leaveForLater` | Saved · post when you’re ready | Salvo · poste quando estiver pronto | — | 2,4 s | `Screens/Main/MainView.swift:100` |
| T002 | done ✓ | `sheetContent` | Imported %1$@ · %2$lld words | %1$@ importado · %2$lld palavras | — | 2,4 s | `Screens/Main/MainView.swift:225` |
| T003 | done ✓ | `sheetContent` | Saved to Logbook | Salvo no Diário de bordo | — | 2,4 s | `Screens/Main/MainView.swift:248` |
| T004 | problem ! | `warnUnsavedWork` · The first flight, the camera, the editor or the remote hold a tap back until they close; then it opens what it names (checked again by `NotificationNavigator… | Couldn't save your work · Free up space on this iPhone | Não foi possível salvar seu trabalho · Libere espaço neste iPhone | — | 2,4 s | `Screens/Main/RootView.swift:118` |
| T005 | problem ! | `openProject` · A script, a take or a queue: | That script is no longer in Cue | Esse roteiro não está mais no Cue | — | 2,4 s | `Screens/Main/Support/NotificationNavigator.swift:42` |
| T006 | problem ! | `openProject` · A script, a take or a queue: | That script is no longer in Cue | Esse roteiro não está mais no Cue | — | 2,4 s | `Screens/Main/Support/NotificationNavigator.swift:45` |
| T007 | done ✓ | `openQueue` · The queue's next network, or the one named; a video already posted everywhere opens its review and says so. | Already shared on the networks you chose | Já compartilhado nas redes que você escolheu | — | 5 s | `Screens/Main/Support/NotificationNavigator.swift:110` |
| T008 | problem ! | `openIdea` · The idea goes into the card's field, ready to send; nothing is written until the creator sends it. | That idea isn’t here any more · try ↻ for another | Essa ideia não está mais aqui · toque em ↻ para outra | — | 5 s | `Screens/Main/Support/NotificationNavigator.swift:125` |
| T009 | problem ! | `openWriting` · Ideas, My Cue Voice and Import my writing need Apple Intelligence; without it, Scripts opens and says why. | *(variável)* Apple Intelligence isn’t available on this iPhone right now / Turned off in Settings › Privacy & AI data. / Apple Intelligence isn't available right now. / Requires Apple Intelligence. This device doesn't support it. / Requires Apple Intelligence. Turn it on in Settings to use AI tools. / Apple Intelligence is still getting ready. Try again in a few minutes. | A Apple Intelligence não está disponível neste iPhone agora / Desligada em Ajustes › Privacidade e dados de IA. / A Apple Intelligence não está disponível agora. / Requer Apple Intelligence. Este aparelho não é compatível. / Requer Apple Intelligence. Ative em Ajustes para usar as ferramentas de IA. / A Apple Intelligence ainda está se preparando. Tente de novo em alguns minutos. | — | 5 s | `Screens/Main/Support/NotificationNavigator.swift:145` |
| T010 | problem ! | `gone` | *(variável)* That script is no longer in Cue | Esse roteiro não está mais no Cue | — | 5 s | `Screens/Main/Support/NotificationNavigator.swift:167` |
| T011 | problem ! | `goneTake` | That recording is no longer in Cue | Essa gravação não está mais no Cue | — | 5 s | `Screens/Main/Support/NotificationNavigator.swift:172` |

### 1.2 Compartilhado › Paywall

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T012 | done ✓ | `restore` | Purchases restored | Compras restauradas | — | 2,4 s | `Screens/Shared/Paywall/ProPlansScreen.swift:169` |
| T013 | problem ! | `restore` | No purchases to restore | Nenhuma compra para restaurar | — | 2,4 s | `Screens/Shared/Paywall/ProPlansScreen.swift:172` |
| T014 | done ✓ | `finish` | *(variável)* Welcome to Cue Pro / Welcome to Cue Pro · video exported / [one] Welcome to Cue Pro · %lld Ultra AI script this month / [other] Welcome to Cue Pro · %lld Ultra AI scripts this month | Boas-vindas ao Cue Pro / Boas-vindas ao Cue Pro · vídeo exportado / [one] Boas-vindas ao Cue Pro · %lld roteiro do Ultra AI este mês / [other] Boas-vindas ao Cue Pro · %lld roteiros do Ultra AI este mês | — | 2,4 s | `Screens/Shared/Paywall/ProPlansScreen.swift:194` |

### 1.3 Compartilhado › Privacy

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T015 | done ✓ | `var body: some View` | Your Cue data is deleted | Seus dados do Cue foram apagados | — | 2,4 s | `Screens/Shared/Privacy/PrivacySheet.swift:61` |

### 1.4 Compartilhado › Reminders

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T016 | done ✓ | `show` | Reminder set · %@ | Lembrete criado · %@ | — | 2,4 s | `Screens/Shared/Reminders/ReminderFeedback.swift:14` |
| T017 | problem ! | `show` | Saved in Cue · notifications are off / Settings | Salvo no Cue · notificações desligadas / Ajustes | Settings (Ajustes) | 4 s | `Screens/Shared/Reminders/ReminderFeedback.swift:16` |
| T018 | done ✓ | `show` | Saved · Cue schedules it closer to the time | Salvo · o Cue agenda quando o horário estiver mais perto | — | 2,4 s | `Screens/Shared/Reminders/ReminderFeedback.swift:23` |
| T019 | problem ! | `show` | Pick a time in the future | Escolha um horário no futuro | — | 2,4 s | `Screens/Shared/Reminders/ReminderFeedback.swift:25` |
| T020 | problem ! | `show` | Couldn’t set the reminder · Try again | Não foi possível criar o lembrete · Tente de novo | — | 2,4 s | `Screens/Shared/Reminders/ReminderFeedback.swift:27` |

### 1.5 Criar roteiro

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T021 | problem ! | `pasteFromClipboard` | Copy your script first | Copie seu roteiro primeiro | — | 2,4 s | `Screens/CreateScript/ImportScriptSheet.swift:206` |

### 1.6 Criar roteiro › Brand

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T022 | problem ! | `confirm` | Add brand and product | Adicione marca e produto | — | 2,4 s | `Screens/CreateScript/Brand/BrandBriefSheet.swift:165` |

### 1.7 Editor

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T023 | problem ! | `fixCaptionOfSelectedWords` · "Fix caption text": | No caption line for these words | Nenhuma linha de legenda para estas palavras | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+EditByText.swift:20` |
| T024 | problem ! | `place` · Pins a bar to where it was dropped: | A line stays on its own clip | A linha fica no próprio clipe | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Layers.swift:133` |
| T025 | done ✓ | `toggleLockOfSelection` · Locks the picked layer, or unlocks it. | Unlocked · It moves and trims again | Destravado · Dá para mover e aparar de novo | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Lock.swift:26` |
| T026 | done ✓ | `toggleLockOfSelection` · Locks the picked layer, or unlocks it. | Locked in place on the timeline | Travado no lugar na linha do tempo | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Lock.swift:29` |
| T027 | done ✓ | `applyVideoTemplate` | %@ on the whole video | %@ no vídeo todo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/QuickEditViewModel+Templates.swift:51` |
| T028 | problem ! | `pickNearestJoin` · VoiceOver: | No cuts yet | Ainda não há cortes | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Timeline.swift:264` |
| T029 | cue ★ | `tap` · A toolbar button. | Applies to the whole video, not only to %@. | Vale para o vídeo todo, não só para %@. | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Toolbar.swift:84` |
| T030 | problem ! | `open` · A panel from the toolbar. | This video has no sound | Este vídeo não tem som | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Toolbar.swift:169` |
| T031 | problem ! | `performOnMedia` · The actions on a picked photo or video. | *(variável)* A split-screen area already has its shape · Show it as a window or full screen to use a mask | Uma área da tela dividida já tem a sua forma · Mostre como janela ou tela cheia para usar máscara | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel+Toolbar.swift:248` |
| T032 | done ✓ | `performOnMedia` · The actions on a picked photo or video. | Places swapped | Lugares trocados | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/QuickEditViewModel+Toolbar.swift:257` |
| T033 | done ✓ | `prepare` · Opens the recording, picks up a draft left behind and starts the player. | Draft restored | Rascunho recuperado | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:244` |
| T034 | problem ! | `done` · Saves the edit on the take (its new length, marked Edited) when anything changed. | Couldn't save the edits · Kept as a draft | Não foi possível salvar as edições · Mantidas como rascunho | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:518` |
| T035 | done ✓ | `done` · Saves the edit on the take (its new length, marked Edited) when anything changed. | Edits saved to this take | Edições salvas neste take | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:521` |
| T036 | problem ! | `askIfReadyToPost` · Done: | A Blur area is still being tracked · Wait a moment | Uma área desfocada ainda está sendo seguida · Aguarde um instante | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:537` |
| T037 | problem ! | `keepForLater` · "Not yet, I'll come back": | *(variável)* Couldn't save the edits · Free up space on this iPhone / A Blur area is still being tracked · Wait a moment | Não foi possível salvar as edições · Libere espaço neste iPhone / Uma área desfocada ainda está sendo seguida · Aguarde um instante | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:569` |
| T038 | kept ? done ✓ : problem ! | `cancel` · Leaves without saving on the take. | Draft saved | Rascunho salvo | — | 2 s (editor) | `Screens/QuickEdit/QuickEditViewModel.swift:585` |
| T039 | done ✓ | `sayUndoable` | *(variável)* (saída de todos os `sayUndoable` dos painéis: cada chamada aparece em sua própria linha) |  | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Support/EditorPart.swift:76` |
| T040 | done ✓ | `sayUndoable` · The toast for a change that can be taken back. | *(variável)* (idem) |  | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Support/EditorSession.swift:147` |

### 1.8 Editor › Audio

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T041 | problem ! | `moveCutsToBeats` | No cut is near a beat / Split the video first, or use Cut on the beats | Nenhum corte está perto de uma batida / Divida o vídeo antes ou use Cortar o vídeo nas batidas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Beats.swift:75` |
| T042 | cue ★ | `moveCutsToBeats` | %lld cuts on the beat | %lld cortes na batida | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Beats.swift:81` |
| T043 | problem ! | `cutOnBeats` | No beat to cut on | Nenhuma batida para cortar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Beats.swift:88` |
| T044 | cue ★ | `cutOnBeats` | %lld cuts on the beats | %lld cortes nas batidas | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Beats.swift:92` |
| T045 | done ✓ | `useLoweringOnAllMusic` · Every music clip lowers as `id` does (whether it does, how far, in pauses), in one undo step. | [one] Used on %lld music clip / [other] Used on all %lld music clips | [one] Usado em %lld clipe de música / [other] Usado nos %lld clipes de música | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Ducking.swift:74` |
| T046 | problem ! | `extractAudio` | This clip is muted · Turn its sound on to extract it | Este clipe está mudo · Ligue o som dele para extrair | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:39` |
| T047 | done ✓ | `extractAudio` | Sound on its own track · the clip is muted | Som numa faixa própria · o clipe ficou mudo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:59` |
| T048 | problem ! | `extractAudio` | This video has no sound | Este vídeo não tem som | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:69` |
| T049 | problem ! | `extractAudio` | This video is muted · Turn its sound on to extract it | Este vídeo está mudo · Ligue o som dele para extrair | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:73` |
| T050 | done ✓ | `extractAudio` | Sound on its own track · the video is muted | Som numa faixa própria · o vídeo ficou mudo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:93` |
| T051 | working (anel) | `extract` | Extracting the sound… | Extraindo o som… | — | até o próximo toast ou endWorking (teto 60 s) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:103` |
| T052 | problem ! | `extract` | This clip has no sound | Este clipe não tem som | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:114` |
| T053 | problem ! | `extract` | Can't extract this sound | Não foi possível extrair este som | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:120` |
| T054 | problem ! | `discardExtracted` | The video changed meanwhile · Extract the sound again | O vídeo mudou nesse meio-tempo · Extraia o som de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:128` |
| T055 | done ✓ | `finishExtracting` · The new track is picked, so its tools (Volume, Delete) are at hand, with the playhead where it starts. | *(variável)* Sound on its own track · the clip is muted / Sound on its own track · the video is muted | Som numa faixa própria · o clipe ficou mudo / Som numa faixa própria · o vídeo ficou mudo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:148` |
| T056 | problem ! | `importMusic` · Copies the sound file in and adds it at the playhead, or puts it in the clip "Replace" asked for: | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:40` |
| T057 | problem ! | `addLibraryTrack` · Adds a library track at the playhead, or puts it in the clip "Replace" asked for, as a file from Files: | Can't add this track | Não deu para adicionar esta faixa | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:71` |
| T058 | problem ! | `addMusic` · Adds a sound file at the playhead, in the free room around it (see `MusicPlacement`), for as long as the file or that room lasts. | No room · Move the playhead | Sem espaço · Mova o cursor | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:89` |
| T059 | problem ! | `addMusic` · Adds a sound file at the playhead, in the free room around it (see `MusicPlacement`), for as long as the file or that room lasts. | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:95` |
| T060 | done ✓ | `addMusic` · Adds a sound file at the playhead, in the free room around it (see `MusicPlacement`), for as long as the file or that room lasts. | Music added at %@ · 40%% | Música adicionada em %@ · 40%% | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:109` |
| T061 | problem ! | `replaceMusic` · "Replace": | The music clip is gone · Nothing replaced | O clipe de música não existe mais · Nada foi trocado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:119` |
| T062 | problem ! | `replaceMusic` · "Replace": | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:124` |
| T063 | done ✓ | `replaceMusic` · "Replace": | Music replaced | Música substituída | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:137` |
| T064 | problem ! | `addSoundEffect` · Adds a sound effect at the playhead (over music or another effect), at 80%, never going down under the voice. | No room · Move the playhead | Sem espaço · Mova o cursor | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:157` |
| T065 | done ✓ | `addSoundEffect` · Adds a sound effect at the playhead (over music or another effect), at 80%, never going down under the voice. | %@ added at %@ | %@ adicionado em %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:170` |
| T066 | problem ! | `addSoundEffect` · Adds a sound effect at the playhead (over music or another effect), at 80%, never going down under the voice. | Can't add this sound | Não deu para adicionar este som | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:173` |
| T067 | done ✓ | `deleteMusic` · Takes a music clip, sound effect or extracted sound off the track, said with Undo like every other delete (its file stays for Undo until the editor closes). | Sound deleted / Music deleted | Som apagado / Música apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Music.swift:189` |
| T068 | done ✓ | `addSpoken` · The made narration: | Voice-over replaced | Narração substituída | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+TextToSpeech.swift:38` |
| T069 | done ✓ | `addSpoken` · The made narration: | Voice-over added | Narração adicionada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+TextToSpeech.swift:48` |
| T070 | problem ! | `setComparesOriginal` · Plays the untreated sound (at the treated one's loudness) or the treated one again. | There's no speech to compare | Não há fala para comparar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Voice.swift:101` |
| T071 | problem ! | `startVoiceOver` | Still working · Record when it finishes | Ainda trabalhando · Grave quando terminar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:30` |
| T072 | problem ! | `startVoiceOver` | Mic is off for Cue / Settings | Microfone desligado para o Cue / Ajustes | Settings (Ajustes) | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:34` |
| T073 | problem ! | `startVoiceOver` | Couldn't start recording | Não deu para começar a gravar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:50` |
| T074 | problem ! | `stopVoiceOver` · Stops recording, adds the narration where it started and plays it back. | Too short to keep | Curto demais para manter | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:78` |
| T075 | problem ! | `voiceOverStoppedByItself` · The narration stopped without Stop. | Recording stopped · Another app took the microphone | A gravação parou · Outro app usou o microfone | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:105` |
| T076 | problem ! | `voiceOverStoppedByItself` · The narration stopped without Stop. | Couldn't record the voice-over · Try again | Não deu para gravar a narração · Tente de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:109` |
| T077 | done ✓ | `deleteVoiceOver` | Voice-over deleted | Narração apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Audio/AudioViewModel+VoiceOver.swift:167` |

### 1.9 Editor › Blur

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T078 | problem ! | `startAdding` · "Blur area": | Move the playhead onto the video | Ponha o cursor sobre o vídeo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Adding.swift:57` |
| T079 | done ✓ | `pickFace` · A tap on face `index` of the first step: | Face hidden · Tracking it | Rosto escondido · Seguindo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Adding.swift:110` |
| T080 | done ✓ | `pickAllButLargest` · Every face but the largest (the creator, most of the time): | [one] %lld face hidden · Tracking it / [other] %lld faces hidden · Tracking them | [one] %lld rosto escondido · Seguindo / [other] %lld rostos escondidos · Seguindo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Adding.swift:118` |
| T081 | done ✓ | `add` · Adds `regions` in one undo step and picks the first; the first step ends. | *(variável)* Face hidden · Tracking it / [one] %lld face hidden · Tracking it / [other] %lld faces hidden · Tracking them / Drag it onto what to hide | Rosto escondido · Seguindo / [one] %lld rosto escondido · Seguindo / [other] %lld rostos escondidos · Seguindo / Arraste sobre o que quer esconder | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Adding.swift:153` |
| T082 | problem ! | `endHere` · "End here": | Move the playhead inside the area first | Ponha o cursor dentro da área antes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Editing.swift:131` |
| T083 | problem ! | `endHere` · "End here": | Move the playhead inside the area first | Ponha o cursor dentro da área antes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Editing.swift:138` |
| T084 | done ✓ | `endHere` · "End here": | Ends at %@ | Termina em %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Editing.swift:144` |
| T085 | done ✓ | `markChecked` · "It's right": | Checked · Covered the whole time / [one] Checked · %lld left to check / [other] Checked · %lld left to check | Conferido · Coberto o tempo todo / [one] Conferido · falta %lld / [other] Conferido · faltam %lld | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Editing.swift:218` |
| T086 | done ✓ | `delete` · Takes the area off; nothing else in the edit changes. | Blur area deleted | Área desfocada apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Editing.swift:243` |
| T087 | problem ! | `startFollowing` | A photo doesn't move · Nothing to track | Uma foto não se mexe · Nada para seguir | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:57` |
| T088 | problem ! | `startFollowing` | Move playhead onto it first | Mova o cursor até lá primeiro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:65` |
| T089 | covered ? cue ★ : problem ! | `followingFinished` | Couldn’t track it here · Move it onto what it hides | Não deu para seguir aqui · Ponha a área sobre o que ela esconde | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:129` |
| T090 | covered ? cue ★ : problem ! | `followingFinished` | Tracked the whole time | Seguido o tempo todo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:140` |
| T091 | covered ? cue ★ : problem ! | `followingFinished` | Not tracked for %@ · Check the marked part | Não seguido por %@ · Confira o trecho marcado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:143` |
| T092 | covered ? cue ★ : problem ! | `say` · How following came out. | *(variável)* Tracked the whole time / Not tracked for %@ · Check the marked part / Couldn’t track it here · Move it onto what it hides | Seguido o tempo todo / Não seguido por %@ · Confira o trecho marcado / Não deu para seguir aqui · Ponha a área sobre o que ela esconde | — | 2 s (editor) | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:162` |

### 1.10 Editor › Brand

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T093 | outcome.kind | `importFonts` · Brings the picked files in and says what came of them; `then` gets the first family that came in (the picker picks it). | *(variável)* %@ added · use it in Text, Captions and Cover / [one] %lld font added · use it in Text, Captions and Cover / [other] %lld fonts added · use them in Text, Captions and Cover / %@ is back · videos that use it show it again / %@ is already in your fonts / This file isn’t a font Cue can use · TTF or OTF / This font is damaged or has no letters / This font file is too large / %@ is already on this iPhone | %@ adicionada · use em Texto, Legendas e Capa / [one] %lld fonte adicionada · use em Texto, Legendas e Capa / [other] %lld fontes adicionadas · use em Texto, Legendas e Capa / %@ voltou · os vídeos que usam essa fonte a mostram de novo / %@ já está nas suas fontes / Este arquivo não é uma fonte que o Cue pode usar · TTF ou OTF / Esta fonte está danificada ou não tem letras / Este arquivo de fonte é grande demais / %@ já está neste iPhone | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Fonts.swift:24` |
| T094 | done ✓ | `removeFont` · Takes a family out of the pickers, with Undo; videos and styles that use it keep drawing in it. | %@ removed · videos that use it keep it | %@ removido · os vídeos que usam continuam com ele | Undo (Desfazer) | 4 s | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Fonts.swift:33` |
| T095 | done ✓ | `apply` · Puts `parts` of `kit` on the video: | %@ on this video · %@ | %@ neste vídeo · %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Kits.swift:101` |
| T096 | done ✓ | `saveKit` · Saves the kit being edited. | %@ saved · videos already made don’t change / %@ updated · videos already made don’t change | %@ salvo · vídeos já feitos não mudam / %@ atualizado · vídeos já feitos não mudam | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Kits.swift:222` |
| T097 | done ✓ | `deleteKit` | %@ deleted · videos that used it keep their look | %@ apagado · os vídeos que o usaram continuam iguais | Undo (Desfazer) | 4 s | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Kits.swift:231` |
| T098 | problem ! | `logo` · A library picture as the kit's logo (its own link to it). | %@ is missing · remove it from your library | %@ está ausente · remova da sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Kits.swift:240` |
| T099 | problem ! | `picks` · The assets as picks for the video, each its own link to the file (in the order given); one that is missing is left out and said. | %@ is missing · remove it from your library | %@ está ausente · remova da sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:29` |
| T100 | done ✓ | `insertLogo` · A logo from the library on the video: | %@ added over the whole video | %@ adicionado por cima do vídeo todo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:42` |
| T101 | problem ! | `insertLogo` · A logo from the library on the video: | %@ is missing · remove it from your library | %@ está ausente · remova da sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:44` |
| T102 | problem ! | `addToLibrary` · Brings photos and videos picked in Photos into the library (not into the video). | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:69` |
| T103 | done ✓ | `addToLibrary` · Brings photos and videos picked in Photos into the library (not into the video). | *(variável)* [one] %lld added to your library / [other] %lld added to your library / Already in your library | [one] %lld adicionado à sua biblioteca / [other] %lld adicionados à sua biblioteca / Já está na sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:72` |
| T104 | problem ! | `addFilesToLibrary` · Brings files picked in Files (a logo's PNG, a video) into the library: | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:95` |
| T105 | done ✓ | `addFilesToLibrary` · Brings files picked in Files (a logo's PNG, a video) into the library: | *(variável)* [one] %lld added to your library / [other] %lld added to your library / Already in your library | [one] %lld adicionado à sua biblioteca / [other] %lld adicionados à sua biblioteca / Já está na sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:98` |
| T106 | done ✓ | `saveMediaToLibrary` · A photo or video of the video saved to the library (the same bytes, no copy). | Saved to your library as %@ | Salvo na sua biblioteca como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:107` |
| T107 | done ✓ | `saveMediaToLibrary` · A photo or video of the video saved to the library (the same bytes, no copy). | Already in your library as %@ | Já está na sua biblioteca como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:108` |
| T108 | problem ! | `saveMediaToLibrary` · A photo or video of the video saved to the library (the same bytes, no copy). | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:112` |
| T109 | done ✓ | `removeFromLibrary` · Takes an asset out of the library, with Undo; videos that use it keep it. | *(variável)* %@ removed · videos that use it keep it / %@ removed from your library | %@ removido · os vídeos que usam continuam com ele / %@ removido da sua biblioteca | Undo (Desfazer) | 4 s | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:123` |
| T110 | done ✓ | `sayAdded` | [one] %lld added to your library / [other] %lld added to your library | [one] %lld adicionado à sua biblioteca / [other] %lld adicionados à sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:130` |
| T111 | done ✓ | `sayAdded` | Already in your library | Já está na sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Panels/Brand/BrandViewModel+Library.swift:132` |

### 1.11 Editor › Captions

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T112 | done ✓ | `pickCaptionTheme` · A style of the catalogue on every line (one undo step): | %@ on the captions | %@ nas legendas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Catalog.swift:148` |
| T113 | done ✓ | `replaceCaptionMatch` · "Replace" on one match: | Replaced | Substituído | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Find.swift:44` |
| T114 | done ✓ | `replaceAllCaptionMatches` · "Replace all": | [one] Replaced %lld time / [other] Replaced %lld times | [many] Substituído %lld vezes / [one] Substituído %lld vez / [other] Substituído %lld vezes | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Find.swift:58` |
| T115 | done ✓ | `setCaptionFormat` · Cuts the lines again by `format`. | Captions format: %@ | Formato das legendas: %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Format.swift:33` |
| T116 | done ✓ | `saveCaptionStyle` · Keeps the captions' combination now (look and layout) as a style named `name`. | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:22` |
| T117 | done ✓ | `updateCaptionStyle` · The saved style takes the captions' combination now; videos already made keep the look they have. | %@ updated · Videos already made keep theirs | %@ atualizado · Vídeos já feitos mantêm o deles | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:35` |
| T118 | done ✓ | `duplicateCaptionStyle` · A copy of a saved style, or one of Cue's saved as the creator's own (with these captions' size, place and format). | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:44` |
| T119 | done ✓ | `duplicateCaptionStyle` · A copy of a saved style, or one of Cue's saved as the creator's own (with these captions' size, place and format). | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:52` |
| T120 | done ✓ | `toggleDefaultCaptionStyle` · New captions start in `key`; picked again, they go back to Cue's own start. | New captions start in Cue / New captions start in %@ | Legendas novas começam com Cue / Legendas novas começam com %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:66` |
| T121 | done ✓ | `deleteCaptionStyle` · Deletes a saved style; the toast's Undo puts it back as it was. | %@ deleted | %@ apagado | Undo (Desfazer) | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:73` |
| T122 | done ✓ | `applySavedCaptionStyle` · A saved style's look on every line (one undo step), keeping where the captions sit, how big and how they are cut, like any other style; `full` takes its size… | %@ on the captions | %@ nas legendas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Library.swift:106` |
| T123 | done ✓ | `deleteAllCaptions` · Every line at once, without picking and deleting them one by one. | Line deleted / [one] %lld line deleted / [other] %lld lines deleted | Linha apagada / [one] %lld linha apagada / [other] %lld linhas apagadas | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+LineByLine.swift:48` |
| T124 | done ✓ | `setCaptionsItsVoice` · The voice of the video `id` laid over the take captioned in place of the main video's while it shows, or not. | Its voice is captioned when you make captions | A voz dele é legendada quando você criar as legendas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:142` |
| T125 | problem ! | `joinSupportVoice` · The support's lines in place of the ones it had, cut the way the others are; nothing heard is said. | No speech in this video | Não há fala neste vídeo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:179` |
| T126 | cue ★ | `joinSupportVoice` · The support's lines in place of the ones it had, cut the way the others are; nothing heard is said. | [one] %lld line from the support’s voice to check / [other] %lld lines from the support’s voice to check | [one] %lld linha da voz do apoio para conferir / [other] %lld linhas da voz do apoio para conferir | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:201` |
| T127 | cue ★ | `finishCaptions` · Lines from every recording that gave some; when none did, the take's own reason. | [one] %lld line to check / [other] %lld lines to check | [one] %lld linha para conferir / [other] %lld linhas para conferir | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:353` |
| T128 | problem ! | `splitCaptionAtPlayhead` · Caption › Split: | Move playhead into the line | Mova o cursor para dentro da linha | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:485` |
| T129 | problem ! | `splitCaptionAtPlayhead` · Caption › Split: | Only one word here | Só há uma palavra aqui | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:490` |
| T130 | done ✓ | `splitCaptionAtPlayhead` · Caption › Split: | Line split | Linha dividida | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:498` |
| T131 | problem ! | `breakCaptionLine` · Caption › Line break: | Only one word here | Só há uma palavra aqui | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:529` |
| T132 | done ✓ | `breakCaptionLine` · Caption › Line break: | Line break added | Quebra de linha adicionada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:549` |
| T133 | problem ! | `joinCaption` · Caption › Join next. | *(variável)* This is the last line / The next line is from another clip / The next line was said earlier in this clip | Esta é a última linha / A próxima linha é de outro clipe / A próxima linha foi dita antes neste clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:555` |
| T134 | done ✓ | `joinCaption` · Caption › Join next. | Joined with next line | Unida com a próxima linha | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:559` |
| T135 | done ✓ | `deleteCaptionLine` · Caption › Delete. | Line deleted | Linha apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Lines.swift:567` |
| T136 | problem ! | `addCaptionAtPlayhead` · "Add a line at the playhead": | Line here · Move to a gap | Já há uma linha aqui · Vá para um espaço vazio | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Panels.swift:68` |
| T137 | problem ! | `addCaptionAtPlayhead` · "Add a line at the playhead": | Not enough room here | Não há espaço suficiente aqui | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Panels.swift:74` |
| T138 | done ✓ | `pickCaptionTranslation` · A language picked under Translate: | Captions in %@ | Legendas em %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Panels.swift:123` |
| T139 | problem ! | `movePickedCaptions` · Earlier (−) or Later (+): | The lines can’t move further | As linhas não podem ir além disso | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Picks.swift:144` |
| T140 | done ✓ | `deletePickedCaptions` · Every picked line goes, one undo step (Undo in the toast brings them back); picking ends. | [one] %lld line deleted / [other] %lld lines deleted | [one] %lld linha apagada / [other] %lld linhas apagadas | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Picks.swift:181` |
| T141 | done ✓ | `moveCaptions` · The captions dropped while a split screen shows: | Captions on the seam during the split screen | Legendas na divisória durante a tela dividida | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Preview.swift:89` |
| T142 | done ✓ | `moveCaptions` · The captions dropped while a split screen shows: | Captions stay where you put them / On the seam | As legendas ficam onde você as colocou / Na divisória | On the seam (Na divisória) | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Preview.swift:91` |
| T143 | done ✓ | `copyStyleToCaptions` · Apply: | Captions use this style | Legendas com este estilo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:53` |
| T144 | cue ★ | `performTranslation` · The view's translation task gave a session for `request`: | Translated to %@ | Traduzido para %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+Translation.swift:85` |

### 1.12 Editor › Clip

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T145 | problem ! | `analyzeIfNeeded` · Listens to each recording the edit plays the first time Clean Up opens on it (the take, then a montage's other takes and videos): | Couldn't listen to this take | Não deu para ouvir este take | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:67` |
| T146 | problem ! | `analyzeIfNeeded` · Listens to each recording the edit plays the first time Clean Up opens on it (the take, then a montage's other takes and videos): | Couldn't listen to every clip | Não deu para ouvir todos os clipes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:71` |
| T147 | problem ! | `splitClip` · Splits the picked clip (or the one under the playhead) at the playhead and picks the right part, ready to delete. | Move playhead onto the clip | Mova o cursor para o clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:37` |
| T148 | problem ! | `splitClip` · Splits the picked clip (or the one under the playhead) at the playhead and picks the right part, ready to delete. | Move playhead onto the clip | Mova o cursor para o clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:41` |
| T149 | problem ! | `splitClip` · Splits the picked clip (or the one under the playhead) at the playhead and picks the right part, ready to delete. | Move playhead onto the clip | Mova o cursor para o clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:46` |
| T150 | done ✓ | `splitClip` · Splits the picked clip (or the one under the playhead) at the playhead and picks the right part, ready to delete. | Split at %@ | Dividido em %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:51` |
| T151 | done ✓ | `duplicateClip` · Copies a clip right after itself, with what plays on it, and picks the copy with the playhead at its start, as Split does: | %@ duplicated after it | %@ duplicado logo depois | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:64` |
| T152 | problem ! | `deleteClip` · Takes a clip out of the video (never out of the recording). | Keep at least one clip | Mantenha pelo menos um clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:71` |
| T153 | done ✓ | `deleteClip` · Takes a clip out of the video (never out of the recording). | %@ deleted | %@ apagado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Cutting.swift:80` |
| T154 | done ✓ | `duplicateSection` · Copies a section right after it, with what plays on it. | Section copied | Trecho copiado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:68` |
| T155 | problem ! | `addClip` · Adds another take from the library at the playhead (`addSource`). | Can't add this take | Não dá para adicionar o take | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:101` |
| T156 | problem ! | `addClip` · Adds a video from Photos at the playhead (`addSource`), from the part picked (`pick`). | Pick a video first | Escolha um vídeo primeiro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:110` |
| T157 | problem ! | `addSource` · The new clip goes where `sequenceInsertion` says (playing `part` of its recording, the whole of it by default), is picked (its tools and outline show where i… | Video too short to add | Vídeo curto demais para adicionar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:148` |
| T158 | done ✓ | `addSource` · The new clip goes where `sequenceInsertion` says (playing `part` of its recording, the whole of it by default), is picked (its tools and outline show where i… | %@ added as clip %lld, at %@ · the video is %@ longer | %@ adicionado como clipe %lld, em %@ · o vídeo ficou %@ mais longo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:158` |
| T159 | problem ! | `openClipTransition` · Reorder: | Split or add a clip to add a transition | Divida ou adicione um clipe para pôr uma transição | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:167` |
| T160 | problem ! | `openClipOrder` | Split or add a clip to reorder | Divida ou adicione um clipe para reordenar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:177` |
| T161 | problem ! | `freezeFrame` · Holds the frame under the playhead: | Move playhead onto the clip | Mova o cursor para o clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:199` |
| T162 | working (anel) | `freezeFrame` · Holds the frame under the playhead: | Freezing the frame… | Congelando o quadro… | — | até o próximo toast ou endWorking (teto 60 s) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:208` |
| T163 | problem ! | `freezeFrame` · Holds the frame under the playhead: | Can't freeze this frame | Não deu para congelar este quadro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:218` |
| T164 | problem ! | `freezeFrame` · Holds the frame under the playhead: | The video changed meanwhile · Freeze the frame again | O vídeo mudou nesse meio-tempo · Congele o quadro de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:228` |
| T165 | done ✓ | `freezeFrame` · Holds the frame under the playhead: | [one] Frame frozen for %lld second · drag its end to hold longer / [other] Frame frozen for %lld seconds · drag its end to hold longer | [one] Quadro congelado por %lld segundo · arraste o fim para segurar mais / [other] Quadro congelado por %lld segundos · arraste o fim para segurar mais | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:263` |
| T166 | problem ! | `applyCleanUp` · Takes every marked pause and word out (one undo step) and keeps the others listed. | Keep at least one clip | Mantenha pelo menos um clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:95` |
| T167 | cue ★ | `applyCleanUp` · Takes every marked pause and word out (one undo step) and keeps the others listed. | [one] Removed %1$lld pause · %2$@ / [other] Removed %1$lld pauses · %2$@ / Removed %1$lld · %2$@ | [one] %1$lld pausa removida · %2$@ / [other] %1$lld pausas removidas · %2$@ / [one] %1$lld removido · %2$@ / [other] %1$lld removidos · %2$@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:110` |
| T168 | done ✓ | `listen` · Listen: | Playing without this pause / Hearing the pause as it is | Tocando sem esta pausa / Ouvindo a pausa como está | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:124` |
| T169 | problem ! | `replaceClip` · Copies the picked video in and puts it in the clip. | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+ReplaceClip.swift:40` |
| T170 | problem ! | `replaceClip` · Puts `imported` in the clip `id` (see above), from `start` (seconds of the new video). | Pick a video first | Escolha um vídeo primeiro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+ReplaceClip.swift:52` |
| T171 | problem ! | `replaceClip` · Puts `imported` in the clip `id` (see above), from `start` (seconds of the new video). | Video too short to add | Vídeo curto demais para adicionar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+ReplaceClip.swift:57` |
| T172 | problem ! | `replaceClip` · Puts `imported` in the clip `id` (see above), from `start` (seconds of the new video). | Clip replaced · its Blur area was on the old video | Clipe trocado · a área desfocada era do vídeo antigo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+ReplaceClip.swift:78` |
| T173 | done ✓ | `replaceClip` · Puts `imported` in the clip `id` (see above), from `start` (seconds of the new video). | Clip replaced · the video is shorter, so the clip is too / Clip replaced | Clipe substituído · o vídeo é mais curto, então o clipe também / Clipe substituído | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+ReplaceClip.swift:82` |
| T174 | problem ! | `resetClip` | This clip is already as filmed | Este clipe já está como foi gravado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reset.swift:25` |
| T175 | done ✓ | `resetClip` | Clip reset | Clipe redefinido | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reset.swift:34` |
| T176 | done ✓ | `reverseClip` | Reversed | Invertido | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:29` |
| T177 | problem ! | `reverseClip` | Reverse works on clips up to 2 minutes · Split it first | Inverter funciona em clipes de até 2 minutos · Divida antes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:33` |
| T178 | problem ! | `reverseClip` | Can’t reverse this clip | Não foi possível inverter este clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:54` |
| T179 | problem ! | `reverseClip` | The video changed meanwhile · Reverse it again | O vídeo mudou nesse meio-tempo · Inverta de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:64` |
| T180 | done ✓ | `reverseClip` | Reversed | Invertido | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:71` |
| T181 | done ✓ | `putBack` · The clip plays its original again. | Plays forward again | Volta a tocar para a frente | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Reverse.swift:80` |
| T182 | problem ! | `cutSelectedWords` · "Cut from video": | Keep at least one section | Mantenha pelo menos uma seção | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+TranscriptEdit.swift:72` |
| T183 | done ✓ | `cutSelectedWords` · "Cut from video": | [one] %1$lld word cut · %2$@ / [other] %1$lld words cut · %2$@ | [one] %1$lld palavra cortada · %2$@ / [other] %1$lld palavras cortadas · %2$@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+TranscriptEdit.swift:79` |
| T184 | done ✓ | `restoreSelectedWords` · "Put back": | Words put back | Palavras devolvidas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+TranscriptEdit.swift:99` |
| T185 | done ✓ | `setTransitionOnEveryCut` · The same transition on every cut, as long as the picked cut's, in one undo step. | Every cut already has it | Todos os cortes já têm | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Transitions.swift:68` |
| T186 | done ✓ | `setTransitionOnEveryCut` · The same transition on every cut, as long as the picked cut's, in one undo step. | Every cut is a hard cut / %@ on every cut | Todos os cortes são secos / %@ em todos os cortes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Transitions.swift:72` |

### 1.13 Editor › Cover

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T187 | done ✓ | `saveCoverStyle` · "Save style": | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:20` |
| T188 | done ✓ | `updateCoverStyle` · The saved style takes this cover's look; covers already made keep theirs. | %@ updated · Videos already made keep theirs | %@ atualizado · Vídeos já feitos mantêm o deles | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:49` |
| T189 | done ✓ | `duplicateCoverTemplate` · A template, drawn as this cover would be in it, saved as the creator's own style. | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:58` |
| T190 | done ✓ | `duplicateCoverStyle` | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:65` |
| T191 | done ✓ | `toggleDefaultCoverStyle` · New covers start in `key`; picked again, Cue's own start. | New covers start in Cue's template / New covers start in %@ | Capas novas começam com o modelo do Cue / Capas novas começam com %@ | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:78` |
| T192 | done ✓ | `deleteCoverStyle` | %@ deleted | %@ apagado | Undo (Desfazer) | 4 s | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Library.swift:84` |
| T193 | problem ! | `usePhoto` · A photo from the library: | Pick a photo for the cover | Escolha uma foto para a capa | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Picture.swift:50` |
| T194 | problem ! | `usePhoto` · A photo from the library: | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverStudioViewModel+Picture.swift:56` |
| T195 | done ✓ | `finishCoverStudio` · Done: | Cover removed / Cover saved · Goes to Photos with the video | Capa removida / Capa salva · Vai para o Fotos com o vídeo | — | 2 s (editor) | `Screens/QuickEdit/CoverStudio/CoverViewModel.swift:67` |

### 1.14 Editor › Layers

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T196 | problem ! | `setMaskShape` · Puts a mask of `shape` on the picked photo or video, or another shape in place of its own (keeping where it is), or takes it off (nil). | *(variável)* A split-screen area already has its shape · Show it as a window or full screen to use a mask | Uma área da tela dividida já tem a sua forma · Mostre como janela ou tela cheia para usar máscara | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Mask.swift:60` |
| T197 | done ✓ | `setMaskShape` · Puts a mask of `shape` on the picked photo or video, or another shape in place of its own (keeping where it is), or takes it off (nil). | Mask removed | Máscara removida | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Mask.swift:74` |
| T198 | done ✓ | `resetMask` · Back to where a new mask of its shape starts, keeping Invert; the picture filling its place again. | Mask reset | Máscara redefinida | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Mask.swift:156` |
| T199 | problem ! | `importMedia` · Copies the picked photo or video in and adds it at the playhead. | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:32` |
| T200 | problem ! | `addMedia` | No room · Move the playhead | Sem espaço · Mova o cursor | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:56` |
| T201 | problem ! | `addMedia` | Max 3 photos or videos | Máx. 3 fotos ou vídeos | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:62` |
| T202 | done ✓ | `addMedia` | Photo added at %@ / Video added at %@ | Foto adicionada em %@ / Vídeo adicionado em %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:82` |
| T203 | problem ! | `duplicateMedia` · A copy of the photo or video on top of the others, a little lower when it doesn't fill the frame, picked. | Max 3 photos or videos | Máx. 3 fotos ou vídeos | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:134` |
| T204 | done ✓ | `duplicateMedia` · A copy of the photo or video on top of the others, a little lower when it doesn't fill the frame, picked. | Media duplicated | Mídia duplicada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:155` |
| T205 | done ✓ | `deleteMedia` · Takes the photo or video out (Undo brings it back). | Support removed · the main video fills the frame there / Media removed | Apoio removido · ali o vídeo principal ocupa todo o quadro / Mídia removida | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:163` |
| T206 | problem ! | `setMediaLength` · How long the photo or video shows, from where it starts in the edit: | 3 photos or videos already show then · up to 3 at a time | Já aparecem 3 fotos ou vídeos nesse momento · até 3 por vez | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:197` |
| T207 | problem ! | `replaceMedia` · Copies the picked file in and swaps it for the one on the media track; a video longer than the slot first asks which part of it fills the slot (`partChoice`). | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:242` |
| T208 | problem ! | `replaceMedia` · Puts `pick` in the place of a photo or video: | 3 photos or videos already show then · up to 3 at a time | Já aparecem 3 fotos ou vídeos nesse momento · até 3 por vez | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:262` |
| T209 | problem ! | `replaceMedia` · Puts `pick` in the place of a photo or video: | Replaced · its Blur area was on the old one | Trocado · a área desfocada era do antigo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:298` |
| T210 | done ✓ | `replaceMedia` · Puts `pick` in the place of a photo or video: | Replaced · its voice's captions went with the old one | Trocado · as legendas da voz foram com o antigo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:302` |
| T211 | done ✓ | `replaceMedia` · Puts `pick` in the place of a photo or video: | *(variável)* Photo in its place · place and settings kept / Video in its place · place and settings kept / Video in its place · it’s shorter, so it ends sooner / Replaced · its Blur area was on the old one | Foto no lugar · posição e ajustes mantidos / Vídeo no lugar · posição e ajustes mantidos / Vídeo no lugar · ele é mais curto, então termina antes / Trocado · a área desfocada era do antigo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Media.swift:311` |
| T212 | problem ! | `toggleKeyframe` · Adds a keyframe at the playhead where the item is now, or takes away the one there. | Move playhead onto it first | Mova o cursor até lá primeiro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Motion.swift:165` |
| T213 | done ✓ | `toggleKeyframe` · Adds a keyframe at the playhead where the item is now, or takes away the one there. | Keyframe removed | Quadro-chave removido | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Motion.swift:171` |
| T214 | done ✓ | `toggleKeyframe` · Adds a keyframe at the playhead where the item is now, or takes away the one there. | Keyframe added · Now drag | Quadro-chave adicionado · Arraste | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Motion.swift:176` |
| T215 | done ✓ | `sayApplied` · "Gold on this text"; when a style that moves took a text's Motion off (`wearing`), it says so with Undo: | %@ on every text / %@ on this text | %@ em todos os textos / %@ neste texto | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Style.swift:54` |
| T216 | done ✓ | `sayApplied` · "Gold on this text"; when a style that moves took a text's Motion off (`wearing`), it says so with Undo: | %@ on every text · Motions removed, the style moves them / %@ on this text · Motion removed, the style moves it | %@ em todos os textos · Movimentos removidos, o estilo os anima / %@ neste texto · Movimento removido, o estilo o anima | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Style.swift:57` |
| T217 | done ✓ | `applyLook` | *(variável)* %@ on this text · Motion removed, the style moves it | %@ neste texto · Movimento removido, o estilo o anima | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Style.swift:80` |
| T218 | done ✓ | `applyLook` | *(variável)* %@ on every text · Motions removed, the style moves them | %@ em todos os textos · Movimentos removidos, o estilo os anima | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Style.swift:96` |
| T219 | done ✓ | `applyLook` | %@ on the captions | %@ nas legendas | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Style.swift:103` |
| T220 | problem ! | `importPicks` · Copies what was picked into the edit's media, in the order picked; one that can't be read is said and skipped, a cancel (the pill) stops there. | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:107` |
| T221 | problem ! | `add` · Puts `picks` in as `mode` says, one after the other from where they start, in one undo step: | The video changed meanwhile · Add it again | O vídeo mudou nesse meio-tempo · Adicione de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:146` |
| T222 | done ✓ | `add` · Puts `picks` in as `mode` says, one after the other from where they start, in one undo step: | *(variável)* [one] %1$lld added to the split screen from %2$@ / [other] %1$lld added to the split screen from %2$@ / Video added to the split screen at %@ / Photo added to the split screen at %@ / Video added at %@ / Photo added at %@ / [one] %1$lld added over the video from %2$@ / [other] %1$lld added over the video from %2$@ / muted / [one] %lld didn’t fit / [other] %lld didn’t fit | [one] %1$lld adicionado à tela dividida a partir de %2$@ / [other] %1$lld adicionados à tela dividida a partir de %2$@ / Vídeo adicionado à tela dividida em %@ / Foto adicionada à tela dividida em %@ / Vídeo adicionado em %@ / Foto adicionada em %@ / [one] %1$lld adicionado por cima do vídeo a partir de %2$@ / [other] %1$lld adicionados por cima do vídeo a partir de %2$@ / sem som / [one] %lld não coube / [other] %lld não couberam | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:190` |
| T223 | problem ! | `roomIsLeft` · Whether `spans` still have room for `picks` as `layout`: | *(variável)* No room · Move the playhead / 3 photos or videos already show then · up to 3 at a time / Another support shows then · one at a time in the split screen | Sem espaço · Mova o cursor / Já aparecem 3 fotos ou vídeos nesse momento · até 3 por vez / Outro apoio aparece nesse momento · um por vez na tela dividida | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:208` |
| T224 | problem ! | `anotherSupportShows` · Whether a support other than `id` shows over `span` (one at a time in the split screen); says so when it does. | Another support shows then · one at a time in the split screen | Outro apoio aparece nesse momento · um por vez na tela dividida | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:389` |
| T225 | done ✓ | `setMutesAllMedia` · "Mute all supports": | Every support is muted / Supports play their sound again | Todos os apoios silenciados / Os apoios voltaram a ter som | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:458` |
| T226 | problem ! | `splitMedia` · Split (the scissors) on a photo or video: | Move the playhead inside it to split it | Mova o cursor para dentro dele para dividir | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:470` |
| T227 | done ✓ | `splitMedia` · Split (the scissors) on a photo or video: | Split at %@ | Dividido em %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:497` |
| T228 | done ✓ | `closeGap` · "Close gap": | Moved %@ back to meet the one before · the speech didn’t change | Movido %@ para trás até encostar no anterior · a fala não mudou | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Supports.swift:516` |
| T229 | done ✓ | `addGraphic` · Text menu › Arrow, Circle or Tag: | %@ added · drag it on the video | %@ adicionado · arraste no vídeo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Text.swift:67` |
| T230 | done ✓ | `duplicateText` · A copy of the text a little lower, picked. | Text duplicated | Texto duplicado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Text.swift:91` |
| T231 | done ✓ | `deleteText` | Text deleted | Texto apagado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Text.swift:105` |
| T232 | done ✓ | `saveTextStyle` · Keeps the picked text's look as a style named `name`. | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:20` |
| T233 | done ✓ | `updateTextStyle` · The saved style takes the picked text's look; texts already made keep theirs. | %@ updated · Videos already made keep theirs | %@ atualizado · Vídeos já feitos mantêm o deles | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:33` |
| T234 | done ✓ | `duplicateTextStyle` · A copy of a saved style, or one of Cue's presets saved as the creator's own. | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:42` |
| T235 | done ✓ | `duplicateTextStyle` · A copy of a saved style, or one of Cue's presets saved as the creator's own. | Saved as %@ | Salvo como %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:47` |
| T236 | done ✓ | `toggleDefaultTextStyle` · New texts start in `key` on videos with no style of their own; picked again, Cue's own start. | New texts start in Cue's style / New texts start in %@ | Textos novos começam com o estilo do Cue / Textos novos começam com %@ | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:61` |
| T237 | done ✓ | `deleteTextStyle` · Deletes a saved style; the toast's Undo puts it back. | %@ deleted | %@ apagado | Undo (Desfazer) | 4 s | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+TextLibrary.swift:68` |
| T238 | problem ! | `trackSelectedItem` | Move playhead onto it first | Mova o cursor até lá primeiro | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Track.swift:27` |
| T239 | problem ! | `trackingFinished` · The tracked path on the item as keyframes, in one step: | The video changed meanwhile · Track it again | O vídeo mudou nesse meio-tempo · Use Seguir de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Track.swift:99` |
| T240 | problem ! | `trackingFinished` · The tracked path on the item as keyframes, in one step: | Couldn’t follow anything there · Put it on what it should follow | Não deu para seguir nada ali · Coloque sobre o que ele deve seguir | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Track.swift:103` |
| T241 | lost ? problem ! : cue ★ | `trackingFinished` · The tracked path on the item as keyframes, in one step: | Lost it after %@ · It holds from there / Tracked · %lld keyframes to adjust | Perdido depois de %@ · Fica parado a partir daí / Seguimento concluído · %lld quadros-chave para ajustar | — | 2 s (editor) | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Track.swift:122` |

### 1.15 Editor › Library

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T242 | problem ! | `tap` | %@ is missing · remove it from your library | %@ está ausente · remova da sua biblioteca | — | 2 s (editor) | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:217` |

### 1.16 Editor › Take

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T243 | problem ! | `autoAdjust` · Measures the picture and applies the result. | Couldn’t measure · No change | Não deu para medir · Sem mudanças | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Auto.swift:62` |
| T244 | problem ! | `finishAuto` | The clip changed meanwhile · Tap Auto again | O clipe mudou nesse meio-tempo · Toque em Auto de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Auto.swift:97` |
| T245 | problem ! | `finishAuto` | Couldn’t measure · No change | Não deu para medir · Sem mudanças | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Auto.swift:102` |
| T246 | done ✓ | `finishAuto` | Already balanced | Já está equilibrado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Auto.swift:107` |
| T247 | cue ★ | `finishAuto` | Auto applied · Adjust below | Auto aplicado · Ajuste abaixo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Auto.swift:121` |
| T248 | problem ! | `importBackgroundImage` · Copies the picked photo in and puts it behind the creator, where it was asked for: | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Background.swift:149` |
| T249 | problem ! | `importBackgroundImage` · Copies the picked photo in and puts it behind the creator, where it was asked for: | Can't add this file | Não dá para adicionar o arquivo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Background.swift:157` |
| T250 | problem ! | `setBackgroundImage` · Puts a photo already in the edit's media behind the creator: | The clip is gone · Pick the photo again | O clipe não existe mais · Escolha a foto de novo | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Background.swift:168` |
| T251 | done ✓ | `useWholeVideosLookOnAllClips` · "Use this on all": | Every clip uses this now | Todos os clipes usam este agora | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Take/LookViewModel+ClipScope.swift:69` |
| T252 | done ✓ | `copyClipLook` · Copies the picked clip's look. | Look copied · pick a clip and Paste look | Visual copiado · escolha um clipe e toque em Colar visual | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:17` |
| T253 | problem ! | `askToPasteLook` · Paste look: | Copy a clip's look first | Copie primeiro o visual de um clipe | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:25` |
| T254 | done ✓ | `pasteLook` · Pastes the picked parts on the picked clip, or on every clip. | Every clip already looks like this | Todos os clipes já estão com este visual | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:40` |
| T255 | done ✓ | `pasteLook` · Pastes the picked parts on the picked clip, or on every clip. | This clip already looks like this | Este clipe já está com este visual | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:50` |
| T256 | done ✓ | `pasteLook` · Pastes the picked parts on the picked clip, or on every clip. | Look pasted on every clip / Look pasted | Visual colado em todos os clipes / Visual colado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:55` |
| T257 | done ✓ | `sayAfterSheet` · The paste's toast once the sheet has gone (about 0.35 s), so it's seen over the editor, not under a closing sheet. | *(variável)* Every clip already looks like this / This clip already looks like this / Look pasted on every clip / Look pasted | Todos os clipes já estão com este visual / Este clipe já está com este visual / Visual colado em todos os clipes / Visual colado | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+CopyLook.swift:63` |
| T258 | done ✓ | `beginCropMove` · A finger starts moving the frame on the preview (only while Format is open): | Follow face is off · You moved the frame | Seguir rosto desligado · Você moveu o enquadramento | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+FaceFollow.swift:46` |
| T259 | done ✓ | `updateSmoothing` · "Update": | Smoothing updated | Suavização atualizada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/QuickEdit/Panels/Take/LookViewModel+Skin.swift:147` |
| T260 | done ✓ | `useStabilizationOnEveryClip` · "Use on every clip": | Every clip already has it | Todos os clipes já têm | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Stabilize.swift:23` |
| T261 | done ✓ | `useStabilizationOnEveryClip` · "Use on every clip": | Stabilize on every clip | Estabilizar em todos os clipes | — | 2 s (editor) | `Screens/QuickEdit/Panels/Take/LookViewModel+Stabilize.swift:31` |

### 1.17 Gravador (Prompter)

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T262 | problem ! | `pasteAndAttach` | Copy your script first | Copie seu roteiro primeiro | — | 2,4 s | `Screens/Prompter/PrompterView.swift:209` |
| T263 | done ✓ | `resetTextWindow` · Double-tap on the corner: | Text window reset | Janela de texto redefinida | — | 2,4 s | `Screens/Prompter/PrompterViewModel+Layout.swift:132` |
| T264 | done ✓ | `useRecommendedSetup` · "Use Recommended": | Using %@ | Usando %@ | — | 2,4 s | `Screens/Prompter/PrompterViewModel+Setup.swift:22` |
| T265 | done ✓ | `keepCreatorSetup` · "Keep My Setup". | Keeping your setup | Mantendo sua configuração | — | 2,4 s | `Screens/Prompter/PrompterViewModel+Setup.swift:28` |
| T266 | done ✓ | `backToCreatorSetup` · Drops this take's changes and the accepted recommendation. | Back to your setup | Voltar à sua configuração | — | 2,4 s | `Screens/Prompter/PrompterViewModel+Setup.swift:34` |
| T267 | problem ! | `followSpeech` · Listens for the script being read, in the Voice Following language (or the script's), and keeps the tracker on the next word to read. | *(variável)* Can't follow %@ · Scrolling / Set a script language first / Go online to get %@ / Go online to get this language / No speech recognition here / Couldn't start listening | Não segue a voz em %@ · Rolando / Defina o idioma do roteiro primeiro / Conecte-se à internet para baixar %@ / Conecte-se à internet para baixar o idioma / Sem reconhecimento de fala aqui / Não deu para começar a ouvir | — | 2,4 s | `Screens/Prompter/PrompterViewModel+VoiceFollow.swift:88` |
| T268 | done ✓ | `setPlatform` · "Create for" from the camera: | Create for %@ | Criar para %@ | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:325` |
| T269 | done ✓ | `rewind` | Back to the top | Voltar ao início | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:476` |
| T270 | problem ! | `recordButtonTapped` · The big red button: | The camera isn't ready | A câmera não está pronta | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:553` |
| T271 | problem ! | `beginRecording` | *(variável)* This device has no camera Cue can use. / Cue couldn't switch to this camera. / The camera isn't ready yet. | Este aparelho não tem uma câmera que o Cue possa usar. / O Cue não conseguiu trocar para esta câmera. / A câmera ainda não está pronta. | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:609` |
| T272 | problem ! (via file → :697) | `stopRecording` · Stops the take, files it in the library and opens its review. | *(variável)* (parar pelo botão: nenhum toast; a revisão abre) |  | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:657` |
| T273 | problem ! (via file → :697) | `recordingEndedByItself` · The take ended on its own: | *(variável)* Storage full · Take saved / Interrupted · Take saved / Recording stopped · Take saved | Armazenamento cheio · Take salvo / Interrompido · Take salvo / Gravação parada · Take salvo | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:671` |
| T274 | problem ! | `file` · The recorded clip becomes a take; `message` (why it stopped) replaces nothing when the take can't be saved. | The take couldn't be saved | Não deu para salvar o take | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:685` |
| T275 | problem ! | `file` · The recorded clip becomes a take; `message` (why it stopped) replaces nothing when the take can't be saved. | *(variável)* Storage full · Take saved / Interrupted · Take saved / Recording stopped · Take saved | Armazenamento cheio · Take salvo / Interrompido · Take salvo / Gravação parada · Take salvo | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:697` |
| T276 | problem ! | `file` · The recorded clip becomes a take; `message` (why it stopped) replaces nothing when the take can't be saved. | The take couldn't be saved | Não deu para salvar o take | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:700` |
| T277 | done ✓ | `attach` · Adds a script to a freestyle session. | Script added | Roteiro adicionado | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:740` |
| T278 | problem ! | `noticeCaptureFallbacks` · When the camera or microphone asked for isn't on this device right now, the take records with another one instead of failing, and a toast says so, once for e… | No %1$@ · Using %2$@ | Sem %1$@ · Usando %2$@ | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:758` |
| T279 | problem ! | `noticeCaptureFallbacks` · When the camera or microphone asked for isn't on this device right now, the take records with another one instead of failing, and a toast says so, once for e… | *(variável)* No %1$@ · Using %2$@ | Sem %1$@ · Usando %2$@ | — | 2,4 s | `Screens/Prompter/PrompterViewModel.swift:766` |

### 1.18 Primeira viagem

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T280 | done ✓ | `announce` | *(variável)* Your first star is out there / Rehearsed · Next: record / Recorded · Next: pick a take / Captions on · Next: share | Sua primeira estrela está no mundo / Ensaiado · Próximo: gravar / Gravado · Próximo: escolher o take / Legendas prontas · Próximo: compartilhar | — | 2,4 s | `Screens/FirstVoyage/VoyageAnnouncer.swift:41` |

### 1.19 Profile › Sections

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T281 | done ✓ | `var menu: some View` | Copied @%@ | @%@ copiado | — | 2,4 s | `Screens/Profile/Sections/ProfileContextMenu.swift:48` |

### 1.20 Profile › Sheets

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T282 | done ✓ | `var body: some View` · A card, quiet on purpose (nothing in Cue needs an account): | Signed out | Você saiu | — | 2,4 s | `Screens/Profile/Sheets/EditProfileAccount.swift:31` |
| T283 | done ✓ | `signedIn` · Apple sends the name only on the first sign-in; it fills an empty name. | Signed in with Apple | Sessão iniciada com a Apple | — | 2,4 s | `Screens/Profile/Sheets/EditProfileAccount.swift:65` |
| T284 | problem ! | `signedIn` · Apple sends the name only on the first sign-in; it fills an empty name. | Couldn't sign in · Try again | Não deu para iniciar sessão · Tente de novo | — | 2,4 s | `Screens/Profile/Sheets/EditProfileAccount.swift:67` |
| T285 | done ✓ | `save` | Profile updated | Perfil atualizado | — | 2,4 s | `Screens/Profile/Sheets/EditProfileSheet.swift:154` |

### 1.21 Profile › Universe

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T286 | done ✓ | `var body: some View` | Saved to Photos | Salvo no Fotos | — | 2,4 s | `Screens/Profile/Universe/UniverseShareSheet.swift:64` |
| T287 | problem ! | `var body: some View` | Couldn't save · Try again | Não foi possível salvar · Tente de novo | — | 2,4 s | `Screens/Profile/Universe/UniverseShareSheet.swift:65` |
| T288 | problem ! | `openReview` | Share 3 videos to unlock it | Compartilhe 3 vídeos para liberar | — | 2,4 s | `Screens/Profile/Universe/YourUniverseView.swift:199` |

### 1.22 Profile › Voice

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T289 | problem ! | `var body: some View` | *(variável)* Max %lld %@ / reasons | Máx. %1$lld %2$@ / motivos | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceAudienceField.swift:32` |
| T290 | done ✓ | `add` | Example saved | Exemplo salvo | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceExamplesField.swift:176` |
| T291 | problem ! | `add` | *(variável)* Max %lld %@ / examples / Add 2 to 4 sentences / This has words Apple Intelligence won’t learn from. Bleep them (f***) or pick another example. / Already added. | Máx. %1$lld %2$@ / exemplos / Adicione 2 a 4 frases / Tem palavras com as quais a Apple Intelligence não aprende. Censure-as (f***) ou escolha outro exemplo. / Já adicionado. | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceExamplesField.swift:182` |
| T292 | problem ! | `group` | *(variável)* Max %lld %@ | Máx. %1$lld %2$@ | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceFormatsField.swift:36` |
| T293 | problem ! | `var goals: some View` | *(variável)* Max %lld %@ / goals | Máx. %1$lld %2$@ / objetivos | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceFormatsField.swift:87` |
| T294 | problem ! | `var avoid: some View` | *(variável)* Max %lld %@ | Máx. %1$lld %2$@ | — | 2,4 s | `Screens/Profile/Voice/Editor/VoicePhrasesField.swift:64` |
| T295 | problem ! | `var tones: some View` | Max %lld · tap to remove | Máx. %lld · toque para remover | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceToneField.swift:38` |
| T296 | problem ! | `toggle` | *(variável)* Max %lld %@ / topics | Máx. %1$lld %2$@ / temas | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceTopicsField.swift:97` |
| T297 | problem ! | `subtopics` · More specific: | *(variável)* Max %lld %@ / subtopics | Máx. %1$lld %2$@ / subtópicos | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceTopicsField.swift:138` |
| T298 | problem ! | `add` | *(variável)* Add a word or two. / Keep it under 40 characters. / Apple Intelligence can’t use this word. / Already added. / Did you mean “%@”? | Adicione uma ou duas palavras. / Mantenha abaixo de 40 caracteres. / A Apple Intelligence não pode usar esta palavra. / Já adicionado. / Você quis dizer “%@”? | — | 2,4 s | `Screens/Profile/Voice/Editor/VoiceTypedField.swift:70` |
| T299 | done ✓ | `accept` | Added to My Cue Voice / Excerpts saved | Adicionado ao My Cue Voice / Trechos salvos | — | 2,4 s | `Screens/Profile/Voice/Import/WritingImportSheet.swift:68` |
| T300 | done ✓ | `var body: some View` | Ultra AI writes your next idea | O Ultra AI rascunha sua próxima ideia | — | 2,4 s | `Screens/Profile/Voice/MyCueVoicePage.swift:61` |
| T301 | cue ★ | `soundsLikeMe` · The creator says the sample is them: | Learned from this script | Aprendido com este roteiro | — | 2,4 s | `Screens/Profile/Voice/Preview/VoicePreviewSheet.swift:170` |
| T302 | problem ! | `choose` · A tap on an answer. | *(variável)* Max %lld %@ | Máx. %1$lld %2$@ | — | 2,4 s | `Screens/Profile/Voice/Question/VoiceQuestionSheetModel.swift:88` |
| T303 | problem ! | `addSomethingElse` · "Add" under "+ Something else": | *(variável)* Add a word or two. / Keep it under 40 characters. / Apple Intelligence can’t use this word. / Already added. | Adicione uma ou duas palavras. / Mantenha abaixo de 40 caracteres. / A Apple Intelligence não pode usar esta palavra. / Já adicionado. | — | 2,4 s | `Screens/Profile/Voice/Question/VoiceQuestionSheetModel.swift:124` |
| T304 | done ✓ | `moveOn` · After an answer (or "None of these"): | Cue Voice complete | Cue Voice completo | — | 2,4 s | `Screens/Profile/Voice/Question/VoiceQuestionSheetModel.swift:196` |

### 1.23 Página do roteiro

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T305 | done ✓ | `var body: some View` | *(variável)* Reminder set · %@ / Saved in Cue · notifications are off / Saved · Cue schedules it closer to the time / Pick a time in the future / Couldn’t set the reminder · Try again | Lembrete criado · %@ / Salvo no Cue · notificações desligadas / Salvo · o Cue agenda quando o horário estiver mais perto / Escolha um horário no futuro / Não foi possível criar o lembrete · Tente de novo | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailView.swift:97` |
| T306 | done ✓ | `setType` · "Script type": | Sections: %@ | Seções: %@ | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Details.swift:15` |
| T307 | done ✓ | `commitPage` · Writes what is on the page into the script. | Saved as v%1$lld · Take on v%2$lld / Saved as v%1$lld · %2$lld takes on v%3$lld | Salvo como v%1$lld · Take na v%2$lld / Salvo como v%1$lld · %2$lld takes na v%3$lld | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:65` |
| T308 | cue ★ | `shape` · "✦ Shape": | %lld cues added | %lld marcações adicionadas | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:113` |
| T309 | problem ! | `done` | Nothing to save yet | Nada para salvar ainda | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:130` |
| T310 | done ✓ | `finish` · "Mark ready anyway", or the switch turned on with everything filled in: | Ready to record · Shape adds cues | Pronto para gravar · Shape adiciona marcações | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:147` |
| T311 | problem ! | `rewriteSelection` · Rewrite · Shorter · Punchier · More me change the selected words in place, in violet, and wait for Keep, Undo or Try again; Cut removes them (with Undo). | *(variável)* Apple Intelligence can’t draft in %@ yet. / Apple Intelligence can’t draft in this script’s language yet. / Turned off in Settings › Privacy & AI data. / Requires Apple Intelligence. This device doesn't support it. / Apple Intelligence is still getting ready. Try again in a few minutes. | A Apple Intelligence ainda não rascunha em %@. / A Apple Intelligence ainda não rascunha no idioma deste roteiro. / Desligada em Ajustes › Privacidade e dados de IA. / Requer Apple Intelligence. Este aparelho não é compatível. / A Apple Intelligence ainda está se preparando. Tente de novo em alguns minutos. | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:257` |
| T312 | problem ! | `rewriteSelection` · Rewrite · Shorter · Punchier · More me change the selected words in place, in violet, and wait for Keep, Undo or Try again; Cut removes them (with Undo). | Couldn’t draft it · Try again | Não deu para rascunhar · Tente de novo | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:266` |
| T313 | problem ! | `rewriteSelection` · Rewrite · Shorter · Punchier · More me change the selected words in place, in violet, and wait for Keep, Undo or Try again; Cut removes them (with Undo). | *(variável)* Couldn’t draft it · Try again / Too long for Apple Intelligence on this iPhone. Try a shorter script, or one part at a time. / Apple Intelligence needs a short break. Try again in a few minutes. / Apple Intelligence is taking too long. Try again in a moment. / The result wasn’t in the right language, so your script is unchanged. Try again. / Apple Intelligence won’t work on this text. Try rewording it, or use another tool. | Não deu para rascunhar · Tente de novo / Longo demais para a Apple Intelligence neste iPhone. Tente um roteiro mais curto, ou uma parte de cada vez. / A Apple Intelligence precisa de uma pausa. Tente de novo em alguns minutos. / A Apple Intelligence está demorando demais. Tente de novo daqui a pouco. / O resultado não veio no idioma certo, então o seu roteiro continua como estava. Tente de novo. / A Apple Intelligence não trabalha com este texto. Tente reformular ou use outra ferramenta. | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:273` |
| T314 | done ✓ | `cut` | Cut | Cortar | Undo (Desfazer) | 4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:299` |
| T315 | problem ! | `write` | *(variável)* (idem failureMessage) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:406` |
| T316 | cue ★ | `finishWriting` | Ultra AI draft ready · Check facts / Draft ready · Check facts / Draft ready · Edit anything | Rascunho do Ultra AI pronto · Confira os fatos / Rascunho pronto · Confira os fatos / Rascunho pronto · Edite o que quiser | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:470` |
| T317 | cue ★ | `approveVoice` · "Sounds like me": | Saved · Cue learns from it | Salvo · O Cue aprende com isso | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+VoicePreview.swift:55` |
| T318 | cue ★ | `rewriteVoice` · "Rewrite": | Profile updated · New version / New version | Perfil atualizado · Nova versão / Nova versão | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+VoicePreview.swift:78` |
| T319 | problem ! | `rewriteVoice` · "Rewrite": | *(variável)* (ScriptAIError, ver §4) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel+VoicePreview.swift:82` |
| T320 | done ✓ | `setPlatform` | Create for %@ | Criar para %@ | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:193` |
| T321 | cue ★ | `replaceHook` | Hook replaced · ~%@ | Gancho trocado · ~%@ | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:202` |
| T322 | done ✓ | `markFactChecked` | Marked as fact-checked | Marcado como conferido | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:237` |
| T323 | done ✓ | `run` | Disclosure is already first | O aviso já está no início | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:249` |
| T324 | done ✓ | `run` | Disclosure added up front | Aviso adicionado no começo | Undo (Desfazer) → volta ao que era | 4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:252` |
| T325 | kind | `adopt` · What a tool wrote becomes the script's words, saved at once (a new version when takes were made from the old ones). | Undone | Desfeito | Undo (Desfazer) | 4 | `Screens/ScriptDetail/ScriptDetailViewModel.swift:277` |
| T326 | done ✓ | `adopt` · What a tool wrote becomes the script's words, saved at once (a new version when takes were made from the old ones). | Undone | Desfeito | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:284` |
| T327 | problem ! | `rewrite` | *(variável)* (DraftingAvailability, ver §3.2) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:294` |
| T328 | problem ! | `rewrite` | Write a few lines. Cue builds on them. | Escreva algumas linhas. O Cue parte delas. | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:299` |
| T329 | cue ★ | `rewrite` | *(variável)* Fitted to %@ / In your voice · %@ / More energy / Grammar fixed / Stronger call to action / More natural / Removed defensive lines / Shorter / Done / %lld → %lld words / %lld of %lld parts left as written / Closer to the %@ goal · now %@ | Ajustado para %@ / Na sua voz · %@ / Mais energia / Gramática corrigida / Chamada para ação mais forte / Mais natural / Frases defensivas removidas / Mais curto / Concluir / %lld → %lld palavras / %lld de %lld partes ficaram como você escreveu / Mais perto da meta de %@ · agora %@ | Undo (Desfazer) → volta ao que era | 4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:317` |
| T330 | notice.kind | `rewrite` | *(variável)* No mistakes to fix / Already fits %@ / Couldn’t draft it · Try again | Nenhum erro para corrigir / Já cabe em %@ / Não deu para rascunhar · Tente de novo | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:320` |
| T331 | problem ! | `translate` | *(variável)* (DraftingAvailability) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:331` |
| T332 | problem ! | `translate` | Write a few lines. Cue builds on them. | Escreva algumas linhas. O Cue parte delas. | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:335` |
| T333 | problem ! | `translate` | Couldn’t draft it · Try again | Não deu para rascunhar · Tente de novo | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:345` |
| T334 | cue ★ | `translate` | *(variável)* %@ version saved / %lld of %lld parts left as written | Versão em %@ salva / %lld de %lld partes ficaram como você escreveu | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:359` |
| T335 | problem ! | `makeVersion` · "Make a version for…": | *(variável)* (DraftingAvailability) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:372` |
| T336 | working (anel) | `makeVersion` · "Make a version for…": | Drafting the %@ version… | Rascunhando a versão para %@… | — | até o próximo toast ou endWorking (teto 60 s) | `Screens/ScriptDetail/ScriptDetailViewModel.swift:377` |
| T337 | cue ★ | `makeVersion` · "Make a version for…": | *(variável)* %@ version saved | Versão em %@ salva | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:398` |
| T338 | problem ! | `showFailure` · An AI tool failed: | *(variável)* (ScriptAIError / UltraError, ver §4) |  | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:407` |
| T339 | done ✓ | `duplicate` | Duplicated | Duplicado | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:432` |
| T340 | done ✓ | `move` | Moved to “%@” / Removed from folder | Movido para “%@” / Tirado da pasta | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:437` |
| T341 | problem ! | `confirmNewFolder` | That folder already exists | Essa pasta já existe | — | 2,4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:448` |
| T342 | done ✓ | `delete` · Deletes, with Undo for 4 s as the list does: | Script deleted | Roteiro apagado | Undo (Desfazer) | 4 s | `Screens/ScriptDetail/ScriptDetailViewModel.swift:459` |

### 1.24 Revisão da take

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T343 | done ✓ | `var body: some View` | Saved · post when you’re ready | Salvo · poste quando estiver pronto | — | 2,4 s | `Screens/TakeReview/TakeReviewView.swift:154` |
| T344 | done ✓ | `declineExport` · "Not now", the close button or a swipe down: | Saved in Takes · export with Pro anytime | Salvo em Takes · exporte com o Pro quando quiser | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:202` |
| T345 | done ✓ | `markBest` · "Use take 2": | %@ marked as best | %@ marcado como o melhor | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:264` |
| T346 | done ✓ | `toggleBest` | %@ marked as best | %@ marcado como o melhor | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:271` |
| T347 | done ✓ | `delete` · Deletes this take and returns the one to show next (the newest sibling left), or nil to leave the review. | %@ deleted | %@ apagado | Undo (Desfazer) | 4 s | `Screens/TakeReview/TakeReviewViewModel.swift:283` |
| T348 | problem ! | `report` · A refused Photos permission is a card with the way out; anything else is "Couldn't export · Try again" and the export count stays where it was (04 · F6). | Not enough space on this iPhone. Free about %lld MB and try again. | Falta espaço neste iPhone. Libere uns %lld MB e tente de novo. | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:339` |
| T349 | problem ! | `report` · A refused Photos permission is a card with the way out; anything else is "Couldn't export · Try again" and the export count stays where it was (04 · F6). | iOS stopped the export · Try again | O iOS parou a exportação · Tente de novo | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:341` |
| T350 | problem ! | `report` · A refused Photos permission is a card with the way out; anything else is "Couldn't export · Try again" and the export count stays where it was (04 · F6). | *(variável)* Your iPhone is too warm to finish this video. Let it cool down, then export again. | Seu iPhone está quente demais para terminar este vídeo. Deixe esfriar e exporte de novo. | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:344` |
| T351 | problem ! | `report` · A refused Photos permission is a card with the way out; anything else is "Couldn't export · Try again" and the export count stays where it was (04 · F6). | Couldn't export · Try again | Não deu para exportar · Tente de novo | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:346` |
| T352 | problem ! | `deliver` | Photos is off · the video wasn't saved there | Fotos está desligado · o vídeo não foi salvo lá | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:485` |
| T353 | done ✓ | `deliver` | *(variável)* Saved to Photos / Video and cover saved to Photos / Saved to Photos · %lld of %lld free exports left / No speech to caption, so the video has none. / Couldn’t listen to this take, so the video has no captions. | Salvo no Fotos / Vídeo e capa salvos no Fotos / Salvo no Fotos · restam %1$lld de %2$lld exportações grátis / Não há fala para legendar, então o vídeo fica sem legendas. / Não deu para ouvir este take, então o vídeo está sem legendas. | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:498` |
| T354 | done ✓ | `share` | *(variável)* Saved to Photos · Open %@ to post it / %lld of %lld free exports left | Salvo no Fotos · Abra o %@ para postar / Restam %1$lld de %2$lld exportações grátis | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:531` |
| T355 | done ✓ | `finishHandoff` · What the hand-off came to, now or when the platform called back. | *(variável)* Shared with %@ / Shared | Compartilhado com o %@ / Compartilhado | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:555` |
| T356 | done ✓ | `finishHandoff` · What the hand-off came to, now or when the platform called back. | *(variável)* Ready to post on %@ / %lld of %lld free exports left | Pronto para postar no %@ / Restam %1$lld de %2$lld exportações grátis | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:563` |
| T357 | done ✓ | `finishHandoff` · What the hand-off came to, now or when the platform called back. | *(variável)* Opened %@ with your video · Cue can’t see if you post it / %lld of %lld free exports left | O %@ foi aberto com o seu vídeo · O Cue não sabe se você postou / Restam %1$lld de %2$lld exportações grátis | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:570` |
| T358 | done ✓ | `finishHandoff` · What the hand-off came to, now or when the platform called back. | Sharing cancelled | Compartilhamento cancelado | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:574` |
| T359 | problem ! | `finishHandoff` · What the hand-off came to, now or when the platform called back. | %@ isn’t on this iPhone · Pick another app | O %@ não está neste iPhone · Escolha outro app | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:577` |
| T360 | problem ! | `finishHandoff` · What the hand-off came to, now or when the platform called back. | %@ didn’t take the video | O %@ não aceitou o vídeo | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:581` |
| T361 | done ✓ | `activityFinished` · How the system share sheet ended. | *(variável)* Shared with %@ | Compartilhado com o %@ | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:603` |
| T362 | done ✓ | `activityFinished` · How the system share sheet ended. | *(variável)* Shared | Compartilhado | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:606` |
| T363 | problem ! | `activityFinished` · How the system share sheet ended. | Couldn’t share · Try again | Não deu para compartilhar · Tente de novo | — | 2,4 s | `Screens/TakeReview/TakeReviewViewModel.swift:612` |

### 1.25 Revisão da take › Share

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T364 | done ✓ | `close` · ✕: | Saved · continue anytime | Salvo · continue quando quiser | — | 2,4 s | `Screens/TakeReview/Share/ShareFlow.swift:187` |
| T365 | done ✓ | `finish` · Nothing is waiting: | Saved · continue anytime | Salvo · continue quando quiser | — | 2,4 s | `Screens/TakeReview/Share/ShareFlow.swift:204` |
| T366 | done ✓ | `var postLater: some View` | *(variável)* Reminder set · %@ / Saved in Cue · notifications are off / Saved · Cue schedules it closer to the time / Pick a time in the future / Couldn’t set the reminder · Try again | Lembrete criado · %@ / Salvo no Cue · notificações desligadas / Salvo · o Cue agenda quando o horário estiver mais perto / Escolha um horário no futuro / Não foi possível criar o lembrete · Tente de novo | — | 2,4 s | `Screens/TakeReview/Share/ShareQueueStep.swift:75` |
| T367 | done ✓ | `remind` · The network waits for later, and the reminder is set for it (the toast says whether iOS took it). | *(variável)* (idem ReminderFeedback) |  | — | 2,4 s | `Screens/TakeReview/Share/ShareQueueStep.swift:91` |

### 1.26 Scripts

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T368 | done ✓ | `delete` · Deletes, with Undo for 4 s: | Script deleted | Roteiro apagado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/Scripts/ScriptsViewModel.swift:79` |
| T369 | done ✓ | `remove` | *(variável)* Script deleted / Idea deleted / %@ deleted | Roteiro apagado / Ideia apagada / %@ apagado | Undo (Desfazer) | 4 s | `Screens/Scripts/ScriptsViewModel.swift:85` |
| T370 | done ✓ | `delete` · An idea of the Logbook's, held away from the end of the list: | Idea deleted | Ideia apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/Scripts/ScriptsViewModel.swift:93` |
| T371 | done ✓ | `duplicate` | Duplicated | Duplicado | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:98` |
| T372 | done ✓ | `move` | Moved to “%@” | Movido para “%@” | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:104` |
| T373 | done ✓ | `move` | Removed from folder | Tirado da pasta | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:106` |
| T374 | done ✓ | `deleteSelection` · Deletes what is picked, scripts and ideas together, with one Undo for all of it. | %@ deleted | %@ apagado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/Scripts/ScriptsViewModel.swift:132` |
| T375 | done ✓ | `duplicateSelection` | Duplicated | Duplicado | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:140` |
| T376 | problem ! | `confirmNewFolder` | That folder already exists | Essa pasta já existe | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:161` |
| T377 | done ✓ | `confirmNewFolder` | Folder created | Pasta criada | — | 2,4 s | `Screens/Scripts/ScriptsViewModel.swift:167` |
| T378 | done ✓ | `deleteFolder` · Deletes a folder, with Undo for 4 s: | Folder deleted | Pasta apagada | Undo (Desfazer) | 4 s | `Screens/Scripts/ScriptsViewModel.swift:179` |

### 1.27 Scripts › Inspiration

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T379 | done ✓ | `var body: some View` | This idea replaced your draft | Esta ideia substituiu seu rascunho | Undo (Desfazer) | 4 s | `Screens/Scripts/Inspiration/FindInspirationSheet.swift:140` |

### 1.28 Scripts › Logbook

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T380 | done ✓ | `delete` · Swiped or held away: | Idea deleted | Ideia apagada | Undo (Desfazer) → volta ao que era | 4 s | `Screens/Scripts/Logbook/LogbookView.swift:545` |
| T381 | done ✓ | `deleteSelection` · The bar's trash: | %@ deleted | %@ apagado | Undo (Desfazer) → volta ao que era | 4 s | `Screens/Scripts/Logbook/LogbookView.swift:553` |
| T382 | done ✓ | `remove` | *(variável)* Idea deleted / %@ deleted | Ideia apagada / %@ apagado | Undo (Desfazer) | 0.35 | `Screens/Scripts/Logbook/LogbookView.swift:560` |

### 1.29 Serviço · Preferences

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T383 | cue ★ | `tookTake` · A take of `script` was recorded: | Cue learned from this | O Cue aprendeu com isso | Undo (Desfazer) | 4 s | `Managers/Preferences/DraftLearning/DraftLearningService.swift:57` |

### 1.30 Serviço · ScriptAI

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T384 | problem ! | `showUltraUsedUp` · The creator's Ultra AI scripts are used up: | This month’s Ultra AI scripts are used · More next month | Os roteiros do Ultra AI deste mês foram usados · Mais no próximo mês | — | 2,4 s | `Managers/ScriptAI/ScriptStarter.swift:97` |
| T385 | problem ! | `write` · Writes `idea` (the card's own text when nil), for the platform and format chosen on the card. | *(variável)* Allow Ultra AI first · Privacy & AI data | Permita o Ultra AI antes · Privacidade e dados de IA | — | 2,4 s | `Managers/ScriptAI/ScriptStarter.swift:150` |
| T386 | problem ! | `write` · Writes `idea` (the card's own text when nil), for the platform and format chosen on the card. | Write it | Escreva | Write it (Escreva) | 4 s | `Managers/ScriptAI/ScriptStarter.swift:167` |

### 1.31 Settings

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T387 | done ✓ | `var body: some View` | Back to Cue's defaults | De volta ao padrão do Cue | — | 2,4 s | `Screens/Settings/SettingsView.swift:46` |

### 1.32 Settings › Notifications

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T388 | count == 0 ? problem ! : done ✓ | `var body: some View` | *(variável)* (Debug: "Notifications are off for Cue in iOS Settings" / "N notifications, one every 6 s…"; sem tradução por ser só Debug) |  | — | 4 | `Screens/Settings/Notifications/NotificationDiagnosticsSection.swift:34` |

### 1.33 Settings › Personalize

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T389 | problem ! | `choose` | Unlocks at %lld videos shared | Liberado com %lld vídeos compartilhados | — | 2,4 s | `Screens/Settings/Personalize/AppIconPicker.swift:117` |

### 1.34 Settings › Remote

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T390 | problem ! | `join` | Wrong code · Try again | Código errado · Tente de novo | — | 2,4 s | `Screens/Settings/Remote/RemoteJoinFlow.swift:45` |

### 1.35 Settings › Rows

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T391 | done ✓ | `resetToRecommended` · "Reset to recommended": | Back to recommended | Voltou ao recomendado | — | 2,4 s | `Screens/Settings/Rows/PrompterEntryRow.swift:181` |
| T392 | restored ? done ✓ : problem ! | `var content: some View` | Purchases restored / No purchases to restore | Compras restauradas / Nenhuma compra para restaurar | — | 2,4 s | `Screens/Settings/Rows/SettingsRootRow.swift:58` |

### 1.36 Settings › Support

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T393 | done ✓ | `body` | Your Cue data is deleted | Seus dados do Cue foram apagados | — | 2,4 s | `Screens/Settings/Support/DataEraseConfirmation.swift:21` |

### 1.37 Takes

| ID | Tipo | Gatilho (função · doc do código) | EN | PT-BR | Botão → efeito | Duração | Código |
|---|---|---|---|---|---|---|---|
| T394 | done ✓ | `var body: some View` | *(variável)* (idem ReminderFeedback) |  | — | 2,4 s | `Screens/Takes/TakesView.swift:113` |
| T395 | working (anel) | `importVideo` · "Import video": | Importing… | Importando… | — | até o próximo toast ou endWorking (teto 60 s) | `Screens/Takes/TakesViewModel.swift:59` |
| T396 | problem ! | `importVideo` · "Import video": | Can't import this video | Não dá para importar este vídeo | — | 2,4 s | `Screens/Takes/TakesViewModel.swift:74` |
| T397 | done ✓ | `markBest` | %@ marked as best | %@ marcado como o melhor | — | 2,4 s | `Screens/Takes/TakesViewModel.swift:173` |
| T398 | done ✓ | `deleteConfirmed` | Take deleted / %lld takes deleted | Take apagado / %lld takes apagados | — | 2,4 s | `Screens/Takes/TakesViewModel.swift:180` |

**Total de chamadas de toast: 398** (por tipo: cue 18, done 196, kind 1, misto 8, notice.kind 1, outcome.kind 1, problem 169, working 4). As linhas "sayUndoable" de `EditorPart`/`EditorSession` e as de atalhos (`say`, `add`, `finishExtracting`, `sayAfterSheet`, `announce`, `gone`) são o ponto onde o toast nasce; o texto real está nas linhas das chamadas.

## 2. Alertas e diálogos de confirmação

Nenhum `Alert(` legado. 14 `.alert`, 7 `.confirmationDialog`, 2 `CueActionSheet` (§17). Duração: até o criador escolher. Exclusões sem confirmação (com toast + Undo, ver §1): roteiro, ideia, pasta, take na revisão, linha de legenda, kit de marca, mídia/fonte da biblioteca, texto, clipe. Sem confirmação e sem toast: **Disconnect** do remoto, remover lembrete (✕ / deslizar), **Remove Photo** do perfil.

| ID | Tipo | Tela | Gatilho | Título (EN → PT) | Mensagem (EN → PT) | Botões (role) → efeito | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| A001 | CueActionSheet | Settings | Settings › Reset Creator Setup | — →  | Camera, microphone, quality, format and teleprompter go back to Cue's defaults. Your scripts, takes and edits stay. → Câmera, microfone, qualidade, formato e teleprompter voltam ao padrão do Cue. Seus roteiros, takes e edições continuam. | **Reset Creator Setup** (Redefinir configuração de criador) destrutivo (vermelho) → `resetCreatorSetup()` + toast "Back to Cue's defaults"; **Cancel** (Cancelar) fecha | `Screens/Settings/SettingsView.swift:40` | `-uiTestInMemory` |
| A002 | CueActionSheet | Settings › Privacy (linha Delete my Cue data) | toque em Delete my Cue data | — →  | Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone. → Apaga seus roteiros, takes, edições e o My Cue Voice deste iPhone. Não dá para desfazer. | **Delete my Cue data** (Apagar meus dados do Cue) destrutivo → apaga tudo + toast "Your Cue data is deleted"; **Cancel** (Cancelar) fecha | `Screens/Settings/Support/DataEraseConfirmation.swift:15` | `-uiTestInMemory` |
| A003 | .alert | Folha Privacy (PrivacySheet) | Delete all your Cue data na folha de privacidade | Delete all your Cue data? → Apagar todos os seus dados do Cue? | Your scripts, takes, edits and My Cue Voice are removed from this iPhone. This can't be undone. → Seus roteiros, takes, edições e My Cue Voice serão removidos deste iPhone. Isso não pode ser desfeito. | **Delete everything** (Apagar tudo) destructive → apaga + toast + fecha a folha; **Cancel** (Cancelar) cancel | `Screens/Shared/Privacy/PrivacySheet.swift:58` | `-uiTestInMemory` |
| A004 | .confirmationDialog | Takes | apagar um vídeo (menu do cartão) | {título do vídeo} →  | The videos are removed from Cue. Copies you saved to Photos stay there. → Os vídeos saem do Cue. As cópias que você salvou no Fotos continuam lá. | **Delete take** (Apagar take) destructive (1 take); **Delete %lld takes** (Apagar %lld takes) destructive (várias) | `Screens/Takes/TakesView.swift:99` | `-uiTestSeedSamples` |
| A005 | .confirmationDialog | Editor › Cover Studio | Cancelar com mudanças | Discard this cover's changes? → Descartar as alterações desta capa? | — →  | **Discard changes** (Descartar alterações) destructive → descarta; **Keep editing** (Continuar editando) cancel | `Screens/QuickEdit/CoverStudio/CoverStudioView.swift:54` | `-uiTestDemoEdit` |
| A006 | .confirmationDialog | Editor › Cover Studio | Remover capa | Remove the cover? → Remover a capa? | — →  | **Remove cover** (Remover capa) destructive → remove e fecha; **Keep it** (Manter) cancel | `Screens/QuickEdit/CoverStudio/CoverStudioView.swift:58` | `-uiTestDemoEdit` |
| A007 | .confirmationDialog | Editor | vídeo com som próprio adicionado como mídia | This video has its own sound → Este vídeo tem som próprio | You can change it later in Media › Advanced. → Você pode mudar depois em Mídia › Avançado. | **Keep its sound** (Manter o som) mantém; **Mute it** (Silenciar) silencia | `Screens/QuickEdit/QuickEditView.swift:131` | `-uiTestDemoEdit` |
| A008 | .confirmationDialog | Editor | exportar/fechar com área de Blur não conferida | A Blur area may not cover what it hides → Uma área desfocada pode não cobrir o que esconde | For %@ Cue couldn't confirm it covers what it hides. One frame is enough to show someone. → Por %@ o Cue não conseguiu confirmar que ela cobre o que esconde. Um quadro basta para mostrar alguém. | **Go there** (Ir até lá) vai ao trecho; **Continue anyway** (Continuar assim mesmo) segue; **Cancel** (Cancelar) cancel | `Screens/QuickEdit/QuickEditView.swift:145` | `-uiTestDemoEdit` |
| A009 | .confirmationDialog | Editor › Captions | refazer legendas com linhas editadas | Replace your edited captions? → Substituir suas legendas editadas? | New captions from your voice replace the lines you corrected or wrote. → As novas legendas da sua voz substituem as linhas que você corrigiu ou escreveu. | **Replace** (Substituir) destructive → refaz; **Keep mine** (Manter como está) cancel | `Screens/QuickEdit/QuickEditView.swift:158` | `-uiTestDemoEdit` |
| A010 | .confirmationDialog | Editor › Caption translation | traduzir de novo linhas corrigidas | Translate your corrected lines again? → Traduzir de novo as linhas que você corrigiu? | — →  | **Keep my corrections** (Manter minhas correções) traduz o resto; **Translate them again** (Traduzir de novo) destructive → substitui | `Screens/QuickEdit/Sheets/CaptionTranslationSheet.swift:72` | `-uiTestDemoEdit` |
| A011 | .alert | Editor › Text style | copiar estilo de um texto para as legendas | Apply this style to captions? → Aplicar este estilo às legendas? | {captionStyleCopyMessage: ver abaixo} →  | **Cancel** (Cancelar) cancel; **Apply** (Aplicar) aplica + toast "Captions use this style" | `Screens/QuickEdit/Panels/Text/TextStylePanel.swift:69` | `-uiTestDemoEdit` |
| A012 | .alert (campo) | Editor › estilos salvos | Save style / Rename style | Save style → Salvar estilo | Videos already made keep their own look. → Vídeos já feitos mantêm o próprio visual. | **Cancel** (Cancelar) cancel; **Save** (Salvar) salva; **Rename** (Renomear) renomeia (título 'Rename style') | `Screens/QuickEdit/Panels/Controls/StyleNamePrompt.swift:28` | `-uiTestDemoEdit` |
| A013 | .alert (campo) | Editor › Library | Rename no menu de um item | Rename → Renomear | — →  | **Save** (Salvar) renomeia; **Cancel** (Cancelar) cancel | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:82` | `-uiTestSeedLibrary` |
| A014 | .alert (campo) | Página do roteiro | + cue na barra de cues | New cue → Nova marcação | It goes in where the cursor is and stays on the bar for every script. → Ela entra onde está o cursor e fica na barra para todos os roteiros. | **Cancel** (Cancelar) cancel; **Add** (Adicionar) insere | `Screens/ScriptDetail/Page/ScriptPageView.swift:138` | `-uiTestSeedSamples` |
| A015 | .alert | Página do roteiro | Ready com seções vazias | 1 section is still empty. / %lld sections are still empty. → 1 seção ainda está vazia. / %lld seções ainda estão vazias. | — →  | **Mark ready anyway** (Marcar como pronto mesmo assim) marca pronto; **Keep writing** (Continuar escrevendo) cancel → foco no texto | `Screens/ScriptDetail/Page/ScriptPageView.swift:148` | `-uiTestSeedSamples` |
| A016 | .alert | Página do roteiro | o rascunho da IA falhou (`page.writingError`) | Couldn't draft the script → Não deu para rascunhar o roteiro | {texto do erro: ScriptAIError / UltraError} →  | **Try again** (Tentar de novo) repete; **OK** (OK) cancel | `Screens/ScriptDetail/ScriptDetailView.swift:63` | `-uiTestStubAI -uiTestWriterStalls`, `-uiTestUltraReviewFails` |
| A017 | .alert (campo) | Página do roteiro / Scripts | New folder… | New folder → Nova pasta | — →  | **Cancel** (Cancelar) cancel; **Create** (Criar) cria; toast 'Folder created' ou 'That folder already exists' | `Screens/ScriptDetail/ScriptDetailView.swift:72 · Screens/Scripts/ScriptsView.swift:117` | `-uiTestSeedSamples` |
| A018 | .alert | Importar roteiro | arquivo ilegível | Couldn't import → Não deu para importar | {DocumentImportError: "Cue couldn't open this file." / "This file has no text Cue can read. Scanned PDFs need text recognition first."} →  | **OK** (OK) cancel | `Screens/CreateScript/ImportScriptSheet.swift:112` | — |
| A019 | .alert | Pro (ProPlansScreen) | compra falhou / pendente | Purchase → Comprar | {StoreManager.errorMessage, ver §8} →  | **OK** (OK) cancel | `Screens/Shared/Paywall/ProPlansScreen.swift:60` | StoreKit `CueStudio.storekit` |
| A020 | .alert (campo) | Settings › Remote | Enter a code | Enter the code → Digite o código | The six letters and numbers under the QR code on the teleprompter. → As seis letras e números embaixo do QR code no teleprompter. | **Cancel** (Cancelar) cancel; **Connect** (Conectar) entra; erro → toast 'Wrong code · Try again' | `Screens/Settings/Remote/RemoteJoinFlow.swift:22` | `-uiTestRemoteConnects` |
| A021 | .alert (campo) | Slider (qualquer `CueSlider`) | toque duplo / digitar valor | {rótulo do slider} →  | — →  | **OK** (OK) aplica; **Cancel** (Cancelar) cancel | `DesignSystem/Controls/CueSlider.swift:89` | — |
| A022 | .alert (campo) | Onboarding 1.2 (tópicos) | + tópico próprio | Your own topic → Seu próprio tema | — →  | **Add** (Adicionar) adiciona; **Cancel** (Cancelar) cancel | `Screens/Onboarding/Universe/UniverseChapter.swift:117` | `-uiTestOnboarding` |

Texto do alerta de cópia de estilo (`CaptionsViewModel+StyleCopy.swift`):

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| A023 | **captionStyleCopyMessage** · mensagem do alerta · Editor › Text style | montado em partes conforme o estilo atual | Your captions use the %@ preset. This text’s font, colors, background, shadow and glow replace it. | Suas legendas usam a predefinição %@. A fonte, as cores, o fundo, a sombra e o brilho deste texto a substituem. | — | — | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:36` | — |
| A024 | ↑ | ↑ | This text’s font, colors, background, shadow and glow replace your captions’ current style. | A fonte, as cores, o fundo, a sombra e o brilho deste texto substituem o estilo atual das suas legendas. | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:38` | ↑ |
| A025 | ↑ | ↑ | Words, timing, translations, position, size and how lines appear stay the same. Other texts don’t change. | Palavras, tempo, traduções, posição, tamanho e o jeito de as linhas aparecerem continuam iguais. Os outros textos não mudam. | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:40` | ↑ |
| A026 | ↑ | ↑ | The highlight color changes so the word being said stands out: %@. | A cor do destaque muda para a palavra falada aparecer: %@. | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:42` | ↑ |
| A027 | ↑ | ↑ | Captions use this style | Legendas com este estilo | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionsViewModel+StyleCopy.swift:54` | ↑ |

## 3. Avisos dentro das telas: banners, nudges, callouts, linhas de dica e de status

### 3.1 Exportações grátis e Ultra AI (limites mostrados antes do bloqueio) — §11, §57

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B001 | **FreeExportLabels** · rótulo mono (HUD) / medidor · Profile (9.1 plano), medidor 8.1, linha sob Share (6.3) | plano grátis; neutro, amarelo na última, laranja quando acabam | PRO · UNLIMITED | PRO · ILIMITADO | — | — | `Models/FreeExportLabels.swift:23` | `-uiTestExportsLeft <0…3>`, `-uiTestPro` |
| B002 | ↑ | ↑ | LAST FREE EXPORT | ÚLTIMA EXPORTAÇÃO GRÁTIS | ↑ | ↑ | `Models/FreeExportLabels.swift:24` | ↑ |
| B003 | ↑ | ↑ | %1$lld OF %2$lld EXPORTS LEFT | RESTAM %1$lld DE %2$lld EXPORTAÇÕES | ↑ | ↑ | `Models/FreeExportLabels.swift:25` | ↑ |
| B004 | ↑ | ↑ | PRO · UNLIMITED EXPORTS | PRO · EXPORTAÇÕES ILIMITADAS | ↑ | ↑ | `Models/FreeExportLabels.swift:30` | ↑ |
| B005 | ↑ | ↑ | %lld OF %lld LEFT · EXPORT WITH PRO | RESTAM %1$lld DE %2$lld · EXPORTE COM O PRO | ↑ | ↑ | `Models/FreeExportLabels.swift:32` | ↑ |
| B006 | ↑ | ↑ | %lld OF %lld LEFT | RESTAM %1$lld DE %2$lld | ↑ | ↑ | `Models/FreeExportLabels.swift:33` | ↑ |
| B007 | ↑ | ↑ | READY · EXPORT WITH PRO | PRONTO · EXPORTE COM O PRO | ↑ | ↑ | `Models/FreeExportLabels.swift:42` | ↑ |
| B008 | ↑ | ↑ | %lld OF %lld FREE EXPORTS LEFT | RESTAM %lld DE %lld EXPORTAÇÕES GRÁTIS | ↑ | ↑ | `Models/FreeExportLabels.swift:42` | ↑ |
| B009 | **Linha de cota no Share** · linha sob o botão · Revisão › Share (ShareFlow) | estado do plano e da cota | Pro · unlimited exports | Pro · exportações ilimitadas | — | — | `Screens/TakeReview/Share/ShareFlow.swift:85` | `-uiTestExportsLeft 0\|1` |
| B010 | ↑ | ↑ | This video's export is already counted | A exportação deste vídeo já foi contada | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:86` | ↑ |
| B011 | ↑ | ↑ | No free exports left · see Pro | Sem exportações grátis · veja o Pro | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:87` | ↑ |
| B012 | ↑ | ↑ | Uses 1 free export · %lld left after this | Usa 1 exportação grátis · restam %lld depois | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:88` | ↑ |
| B013 | **Pronto para viajar (cota)** · cartão de celebração (rodapé) · ReadyToTravelView | após entrega sem prova de postagem | EXPORTED · %@ | EXPORTADO · %@ | — | — | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:62` | `-uiTestFakeShareSheet` |
| B014 | ↑ | ↑ | FREE EXPORTS | EXPORTAÇÕES GRÁTIS | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:117` | ↑ |
| B015 | ↑ | ↑ | Unlimited exports | Exportações ilimitadas | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:142` | ↑ |
| B016 | ↑ | ↑ | Free exports left | Exportações grátis restantes | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:142` | ↑ |
| B017 | ↑ | ↑ | %1$@ of %2$@ | %@ de %@ | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:143` | ↑ |
| B018 | **UltraAllowanceLabels** · rótulo / linha / HUD · Dock de Scripts, Find inspiration, consentimento, Pro | Ultra AI ligado; conta do mês ou das 3 grátis | [one] Ultra AI · %lld left this month / [other] Ultra AI · %lld left this month | [one] Ultra AI · resta %lld este mês / [other] Ultra AI · restam %lld este mês | — | — | `Models/UltraAllowanceLabels.swift:14` | `-uiTestUltra -uiTestUltraAllowed -uiTestUltraScriptsLeft <0…3>` |
| B019 | ↑ | ↑ | Ultra AI · %lld of %lld free left | Ultra AI · restam %1$lld de %2$lld grátis | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:15` | ↑ |
| B020 | ↑ | ↑ | [one] %lld script left this month. / [other] %lld scripts left this month. | [one] Resta %lld roteiro este mês. / [other] Restam %lld roteiros este mês. | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:20` | ↑ |
| B021 | ↑ | ↑ | [one] Your first %lld script is free. / [other] Your first %lld scripts are free. | [one] %lld roteiro grátis para começar. / [other] Seus primeiros %lld roteiros são grátis. | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:22` | ↑ |
| B022 | ↑ | ↑ | %lld of %lld free scripts left. | Restam %1$lld de %2$lld roteiros grátis. | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:24` | ↑ |
| B023 | ↑ | ↑ | ULTRA AI · %lld LEFT THIS MONTH | ULTRA AI · RESTAM %lld ESTE MÊS | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:30` | ↑ |
| B024 | ↑ | ↑ | ULTRA AI · %lld OF %lld FREE LEFT | ULTRA AI · RESTAM %1$lld DE %2$lld GRÁTIS | ↑ | ↑ | `Models/UltraAllowanceLabels.swift:31` | ↑ |

### 3.2 Apple Intelligence, idiomas e fala (§8)

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B025 | **DraftingAvailability · AIModelStatus · AIAvailability** · motivo (vira nota, subtítulo ou toast) · Dock, Logbook, Find inspiration, página do roteiro, notificações | ordem: interruptor do Cue › aparelho › iOS › idioma › modelo se preparando | Apple Intelligence can’t draft in %@ yet. | A Apple Intelligence ainda não rascunha em %@. | — | — | `Managers/ScriptAI/DraftingAvailability.swift:45` | `-uiTestAIUnavailable <language\|device\|off\|preparing\|cue>`, `-uiTestScriptLanguage th-TH` |
| B026 | ↑ | ↑ | Apple Intelligence can’t draft in this script’s language yet. | A Apple Intelligence ainda não rascunha no idioma deste roteiro. | ↑ | ↑ | `Managers/ScriptAI/DraftingAvailability.swift:46` | ↑ |
| B027 | ↑ | ↑ | Write it yourself or import a script. | Escreva você mesmo ou importe um roteiro. | ↑ | ↑ | `Managers/ScriptAI/DraftingAvailability.swift:85` | ↑ |
| B028 | ↑ | ↑ | Apple Intelligence isn't available right now. | A Apple Intelligence não está disponível agora. | ↑ | ↑ | `Managers/ScriptAI/AIModelStatus.swift:26` | ↑ |
| B029 | ↑ | ↑ | Requires Apple Intelligence. This device doesn't support it. | Requer Apple Intelligence. Este aparelho não é compatível. | ↑ | ↑ | `Managers/ScriptAI/AIModelStatus.swift:28` | ↑ |
| B030 | ↑ | ↑ | Requires Apple Intelligence. Turn it on in Settings to use AI tools. | Requer Apple Intelligence. Ative em Ajustes para usar as ferramentas de IA. | ↑ | ↑ | `Managers/ScriptAI/AIModelStatus.swift:30` | ↑ |
| B031 | ↑ | ↑ | Apple Intelligence is still getting ready. Try again in a few minutes. | A Apple Intelligence ainda está se preparando. Tente de novo em alguns minutos. | ↑ | ↑ | `Managers/ScriptAI/AIModelStatus.swift:32` | ↑ |
| B032 | ↑ | ↑ | Turned off in Settings › Privacy & AI data. | Desligada em Ajustes › Privacidade e dados de IA. | ↑ | ↑ | `Managers/ScriptAI/AIAvailability.swift:19` | ↑ |
| B033 | ↑ | ↑ | Requires Apple Intelligence. | Requer Apple Intelligence. | ↑ | ↑ | `Managers/ScriptAI/AIAvailability.swift:23` | ↑ |
| B034 | **AIUnavailableNote** · nota (ícone ✦ + texto) · Dock de Scripts, + › Let Cue draft it, Answer a comment, Sponsored ad | IA indisponível | Write it yourself or import a script. | Escreva você mesmo ou importe um roteiro. | — | — | `Managers/ScriptAI/DraftingAvailability.swift:85` | `-uiTestNoAI` |
| B035 | ↑ | ↑ | Write your reply yourself. | Escreva sua resposta você mesmo. | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:56` | ↑ |
| B036 | **Language & Region / Script language** · rodapé de seção e legenda de linha · Settings › Language & Region | idioma que o modelo não escreve; capacidade de Voice Following | New scripts start in it. Scripts are never translated. | Roteiros novos começam nele. Roteiros nunca são traduzidos. | — | — | `Screens/Settings/LanguageRegion/LanguageRegionView.swift:22` | `-uiTestScriptLanguage th-TH` |
| B037 | ↑ | ↑ | Apple Intelligence can’t draft in %@ yet. | A Apple Intelligence ainda não rascunha em %@. | ↑ | ↑ | `Screens/Settings/LanguageRegion/LanguageRegionView.swift:24` | ↑ |
| B038 | ↑ | ↑ | Opens iPhone Settings › Cue › Language. | Abre Ajustes do iPhone › Cue › Idioma. | ↑ | ↑ | `Screens/Settings/LanguageRegion/LanguageRegionView.swift:32` | ↑ |
| B039 | ↑ | ↑ | The language Cue listens for while you speak. | O idioma que o Cue escuta enquanto você fala. | ↑ | ↑ | `Screens/Settings/LanguageRegion/LanguageRegionView.swift:37` | ↑ |
| B040 | ↑ | ↑ | Language & Region | Idioma e região | ↑ | ↑ | `Screens/Settings/LanguageRegion/LanguageRegionView.swift:54` | ↑ |
| B041 | ↑ | ↑ | iPhone Language | Idioma do iPhone | ↑ | ↑ | `Screens/Settings/Rows/LanguageEntryRow.swift:36` | ↑ |
| B042 | ↑ | ↑ | Same as script | Igual ao roteiro | ↑ | ↑ | `Screens/Settings/Rows/LanguageEntryRow.swift:45` | ↑ |
| B043 | ↑ | ↑ | Auto-detect | Detectar automaticamente | ↑ | ↑ | `Screens/Settings/Rows/LanguageEntryRow.swift:51` | ↑ |
| B044 | ↑ | ↑ | Apple Intelligence can’t draft in it yet | A Apple Intelligence ainda não rascunha neste idioma | ↑ | ↑ | `Screens/Settings/Rows/LanguageEntryRow.swift:108` | ↑ |
| B045 | ↑ | ↑ | Ready on this iPhone | Pronto neste iPhone | ↑ | ↑ | `Models/VoiceFollowingAvailability.swift:28` | ↑ |
| B046 | ↑ | ↑ | Downloads the first time you use it | Baixa na primeira vez que você usar | ↑ | ↑ | `Models/VoiceFollowingAvailability.swift:29` | ↑ |
| B047 | ↑ | ↑ | Not available on this iPhone | Indisponível neste iPhone | ↑ | ↑ | `Models/VoiceFollowingAvailability.swift:30` | ↑ |
| B048 | **SpeechUnavailableReason** · motivo (toast no gravador; nota em Legendas e no ditado) · Gravador, Legendas, Ditado | idioma sem reconhecimento, sem rede para baixar, sem permissão | Can't follow %@ · Scrolling | Não segue a voz em %@ · Rolando | — | — | `Models/SpeechUnavailableReason.swift:27` | `-uiTestPermissions denied` |
| B049 | ↑ | ↑ | Can't follow %@ · Scrolling | Não segue a voz em %@ · Rolando | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:29` | ↑ |
| B050 | ↑ | ↑ | Set a script language first | Defina o idioma do roteiro primeiro | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:31` | ↑ |
| B051 | ↑ | ↑ | Go online to get %@ | Conecte-se à internet para baixar %@ | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:33` | ↑ |
| B052 | ↑ | ↑ | Go online to get this language | Conecte-se à internet para baixar o idioma | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:35` | ↑ |
| B053 | ↑ | ↑ | No speech recognition here | Sem reconhecimento de fala aqui | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:37` | ↑ |
| B054 | ↑ | ↑ | Couldn't start listening | Não deu para começar a ouvir | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:39` | ↑ |
| B055 | ↑ | ↑ | Captions can’t listen in %@ on this iPhone. Pick the language spoken or write the lines yourself. | As legendas não conseguem ouvir em %@ neste iPhone. Escolha o idioma falado ou escreva as linhas você mesmo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:48` | ↑ |
| B056 | ↑ | ↑ | Captions can’t listen in %@ on this iPhone. Pick the language spoken or write the lines yourself. | As legendas não conseguem ouvir em %@ neste iPhone. Escolha o idioma falado ou escreva as linhas você mesmo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:50` | ↑ |
| B057 | ↑ | ↑ | Pick the language spoken in this take to caption it. | Escolha o idioma falado neste take para legendá-lo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:52` | ↑ |
| B058 | ↑ | ↑ | Captions need to download %@. Connect to the internet and try again. | As legendas precisam baixar %@. Conecte-se à internet e tente de novo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:54` | ↑ |
| B059 | ↑ | ↑ | Captions need to download this language. Connect to the internet and try again. | As legendas precisam baixar este idioma. Conecte-se à internet e tente de novo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:56` | ↑ |
| B060 | ↑ | ↑ | Captions need speech recognition. You can still write the lines yourself. | As legendas precisam de reconhecimento de fala. Você ainda pode escrever as linhas. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:58` | ↑ |
| B061 | ↑ | ↑ | Captions couldn’t start listening. Try again. | As legendas não conseguiram começar a ouvir. Tente de novo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:60` | ↑ |
| B062 | ↑ | ↑ | Dictation can’t listen in %@ on this iPhone. You can type your idea instead. | O ditado não consegue ouvir em %@ neste iPhone. Você pode digitar sua ideia. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:68` | ↑ |
| B063 | ↑ | ↑ | Dictation can’t listen in %@ on this iPhone. You can type your idea instead. | O ditado não consegue ouvir em %@ neste iPhone. Você pode digitar sua ideia. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:70` | ↑ |
| B064 | ↑ | ↑ | Cue couldn’t tell which language to listen in. You can type your idea instead. | O Cue não conseguiu saber em que idioma ouvir. Você pode digitar sua ideia. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:72` | ↑ |
| B065 | ↑ | ↑ | Dictation needs to download %@. Connect to the internet and try again. | O ditado precisa baixar %@. Conecte-se à internet e tente de novo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:74` | ↑ |
| B066 | ↑ | ↑ | Dictation needs to download this language. Connect to the internet and try again. | O ditado precisa baixar este idioma. Conecte-se à internet e tente de novo. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:76` | ↑ |
| B067 | ↑ | ↑ | This iPhone can’t turn speech into text here. You can type your idea instead. | Este iPhone não consegue transformar fala em texto aqui. Você pode digitar sua ideia. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:78` | ↑ |
| B068 | ↑ | ↑ | Dictation couldn’t start listening. You can type your idea instead. | O ditado não conseguiu começar a ouvir. Você pode digitar sua ideia. | ↑ | ↑ | `Models/SpeechUnavailableReason.swift:80` | ↑ |
| B069 | ↑ | ↑ | Voice Following listens in %1$@. Captions listen in the script’s language, %2$@. Pick the language spoken if it’s different. | Seguir voz ouve em %1$@. As legendas ouvem no idioma do roteiro, %2$@. Escolha o idioma falado se for outro. | ↑ | ↑ | `Models/SpeechLanguageConflict.swift:16` | ↑ |
| B070 | ↑ | ↑ | The microphone is off for Cue. Turn it on in Settings to dictate, or type your idea. | O microfone está desativado para o Cue. Ative em Ajustes para ditar ou digite sua ideia. | ↑ | ↑ | `Managers/Speech/DictationNotice.swift:23` | ↑ |
| B071 | ↑ | ↑ | Dictation stopped. What you said so far is kept. | O ditado parou. O que você disse até agora foi mantido. | ↑ | ↑ | `Managers/Speech/DictationNotice.swift:27` | ↑ |
| B072 | ↑ | ↑ | Didn’t catch anything. Try again, or type your idea. | Não captei nada. Tente de novo ou digite sua ideia. | ↑ | ↑ | `Managers/Speech/DictationNotice.swift:29` | ↑ |
| B073 | **DictationNoticeView / DictationStatusRow** · nota com botão / linha de status · Campo de ideia (dock, Logbook) | ditado | Open Settings | Abrir Ajustes | Open Settings → Ajustes do iOS | — | `Screens/Shared/PromptCard/DictationNoticeView.swift:26` | `-uiTestDictation`, `-uiTestDictationText` |
| B074 | ↑ | ↑ | Downloading %@ | Baixando %@ | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:41` | ↑ |
| B075 | ↑ | ↑ | Downloading | Baixando | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:42` | ↑ |
| B076 | ↑ | ↑ | Getting ready | Preparando | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:43` | ↑ |
| B077 | ↑ | ↑ | Listening… | Ouvindo… | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:44` | ↑ |
| B078 | ↑ | ↑ | Finishing… | Finalizando… | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:45` | ↑ |
| B079 | ↑ | ↑ | Stop dictation | Parar o ditado | ↑ | ↑ | `Screens/Shared/PromptCard/DictationButton.swift:44` | ↑ |
| B080 | ↑ | ↑ | Dictate your idea | Dite sua ideia | ↑ | ↑ | `Screens/Shared/PromptCard/DictationButton.swift:44` | ↑ |
| B081 | ↑ | ↑ | Your words appear here to review before you send. | Suas palavras aparecem aqui para você revisar antes de enviar. | ↑ | ↑ | `Screens/Shared/PromptCard/DictationButton.swift:45` | ↑ |
| B082 | **Estados de legenda e tradução** · linha de status (CaptionStatusRow) · Editor › Captions / Translation | fazer legendas / traduzir | Getting ready to listen… | Preparando para ouvir… | Stop / Try again (Retry quando falta idioma) | — | `Screens/QuickEdit/Support/CaptionState.swift:32` | `-uiTestDemoEdit` |
| B083 | ↑ | ↑ | Finding the language you speak… | Descobrindo o idioma que você fala… | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:33` | ↑ |
| B084 | ↑ | ↑ | Downloading the speech model… %@ | Baixando o modelo de fala… %@ | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:35` | ↑ |
| B085 | ↑ | ↑ | Downloading the speech model… | Baixando o modelo de fala… | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:36` | ↑ |
| B086 | ↑ | ↑ | Listening to your take… %@ | Ouvindo seu take… %@ | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:38` | ↑ |
| B087 | ↑ | ↑ | Stopped. Your captions are as they were. | Parado. Suas legendas ficaram como estavam. | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:39` | ↑ |
| B088 | ↑ | ↑ | This take has no sound to caption. | Este take não tem som para legendar. | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:40` | ↑ |
| B089 | ↑ | ↑ | No speech found in this take. | Nenhuma fala encontrada neste take. | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:41` | ↑ |
| B090 | ↑ | ↑ | Couldn’t listen to this take. | Não deu para ouvir este take. | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:43` | ↑ |
| B091 | ↑ | ↑ | Captions couldn’t listen for %@ in this take, so those parts may be missing. Check the lines or write them yourself. | As legendas não conseguiram ouvir %@ neste take, então essas partes podem estar faltando. Confira as linhas ou escreva você mesmo. | ↑ | ↑ | `Screens/QuickEdit/Support/CaptionState.swift:45` | ↑ |
| B092 | ↑ | ↑ | Checking this iPhone can translate… | Verificando se este iPhone consegue traduzir… | ↑ | ↑ | `Screens/QuickEdit/Support/TranslationState.swift:25` | ↑ |
| B093 | ↑ | ↑ | Translating on your iPhone… | Traduzindo no seu iPhone… | ↑ | ↑ | `Screens/QuickEdit/Support/TranslationState.swift:26` | ↑ |
| B094 | ↑ | ↑ | This iPhone can’t translate %1$@ to %2$@. You can write the translation yourself. | Este iPhone não consegue traduzir de %1$@ para %2$@. Você pode escrever a tradução. | ↑ | ↑ | `Screens/QuickEdit/Support/TranslationState.swift:28` | ↑ |
| B095 | ↑ | ↑ | Pick the language spoken in Captions first. | Primeiro escolha o idioma falado em Legendas. | ↑ | ↑ | `Screens/QuickEdit/Support/TranslationState.swift:29` | ↑ |
| B096 | ↑ | ↑ | Couldn’t translate the captions. Try again. | Não deu para traduzir as legendas. Tente de novo. | ↑ | ↑ | `Screens/QuickEdit/Support/TranslationState.swift:30` | ↑ |
| B097 | ↑ | ↑ | Stop | Parar | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionStatusRow.swift:26` | ↑ |
| B098 | ↑ | ↑ | Try again | Tentar de novo | ↑ | ↑ | `Screens/QuickEdit/Panels/Captions/CaptionStatusRow.swift:28` | ↑ |

### 3.3 Compartilhar e entregar (§9, SHARING.md)

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B099 | **Fluxo de compartilhar** · folha + linhas de status · Revisão › Share | escolher redes, postar em fila | Pick a network | Escolha uma rede | — | — | `Screens/TakeReview/Share/ShareFlow.swift:76` | `-uiTestFakeShareSheet`, `-uiTestAppsInstalled` |
| B100 | ↑ | ↑ | Share to %@ | Compartilhar no %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:77` | ↑ |
| B101 | ↑ | ↑ | Share to %lld networks | Compartilhar em %lld redes | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:78` | ↑ |
| B102 | ↑ | ↑ | Pro · unlimited exports | Pro · exportações ilimitadas | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:85` | ↑ |
| B103 | ↑ | ↑ | This video's export is already counted | A exportação deste vídeo já foi contada | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:86` | ↑ |
| B104 | ↑ | ↑ | No free exports left · see Pro | Sem exportações grátis · veja o Pro | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:87` | ↑ |
| B105 | ↑ | ↑ | Uses 1 free export · %lld left after this | Usa 1 exportação grátis · restam %lld depois | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:88` | ↑ |
| B106 | ↑ | ↑ | Saved · continue anytime | Salvo · continue quando quiser | ↑ | ↑ | `Screens/TakeReview/Share/ShareFlow.swift:187` | ↑ |
| B107 | ↑ | ↑ | Share to universe | Compartilhar no universo | ↑ | ↑ | `Screens/TakeReview/Share/ShareNetworkPicker.swift:22` | ↑ |
| B108 | ↑ | ↑ | Export options | Opções de exportação | ↑ | ↑ | `Screens/TakeReview/Share/ShareNetworkPicker.swift:27` | ↑ |
| B109 | ↑ | ↑ | Also save to Photos | Salvar também em Fotos | ↑ | ↑ | `Screens/TakeReview/Share/ShareNetworkPicker.swift:50` | ↑ |
| B110 | ↑ | ↑ | ✓ CLEAN FILE FOR EVERY NETWORK · NO WATERMARKS | ✓ ARQUIVO LIMPO PARA TODAS AS REDES · SEM MARCA D’ÁGUA | ↑ | ↑ | `Screens/TakeReview/Share/ShareNetworkPicker.swift:88` | ↑ |
| B111 | ↑ | ↑ | · from your script | · do seu roteiro | ↑ | ↑ | `Screens/TakeReview/Share/ShareNetworkRow.swift:31` | ↑ |
| B112 | ↑ | ↑ | Export options | Opções de exportação | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:15` | ↑ |
| B113 | ↑ | ↑ | Burn in captions | Embutir legendas | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:17` | ↑ |
| B114 | ↑ | ↑ | Captions | Legendas | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:23` | ↑ |
| B115 | ↑ | ↑ | Original | Original | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:24` | ↑ |
| B116 | ↑ | ↑ | Both · %@ | Ambos · %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:27` | ↑ |
| B117 | ↑ | ↑ | Quality | Qualidade | ↑ | ↑ | `Screens/TakeReview/Share/ShareExportOptions.swift:35` | ↑ |
| B118 | **Fila de postagem** · passo da folha · Revisão › Share (fila) | várias redes; volta ao Cue | Send to %@ | Enviar para %@ | Send to X, Edit first, Post later, Copy again, Yes it's live / Not yet | — | `Screens/TakeReview/Share/ShareQueueStep.swift:32` | `-uiTestShareQueue` |
| B119 | ↑ | ↑ | Edit first | Editar antes | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:36` | ↑ |
| B120 | ↑ | ↑ | Tonight · %@ | Hoje à noite · %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:56` | ↑ |
| B121 | ↑ | ↑ | Tomorrow · %@ | Amanhã · %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:60` | ↑ |
| B122 | ↑ | ↑ | Pick a date and time… | Escolher data e hora… | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:63` | ↑ |
| B123 | ↑ | ↑ | No reminder | Sem lembrete | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:66` | ↑ |
| B124 | ↑ | ↑ | Post later | Postar depois | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:69` | ↑ |
| B125 | ↑ | ↑ | %1$lld OF %2$lld | %lld DE %lld | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:97` | ↑ |
| B126 | ↑ | ↑ | Post to %@ | Postar no %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:100` | ↑ |
| B127 | ↑ | ↑ | Caption copied · paste it in %@ | Legenda copiada · cole no %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:108` | ↑ |
| B128 | ↑ | ↑ | Copy again | Copiar de novo | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:111` | ↑ |
| B129 | ↑ | ↑ | Post caption | Legenda da publicação | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:115` | ↑ |
| B130 | ↑ | ↑ | Your captions are in the video · keep auto captions off | Suas legendas estão no vídeo · deixe as automáticas desligadas | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:123` | ↑ |
| B131 | ↑ | ↑ | In the share sheet, tap %@ | Na folha de compartilhamento, toque em %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:125` | ↑ |
| B132 | ↑ | ↑ | ◀ Cue | ◀ Cue | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:143` | ↑ |
| B133 | ↑ | ↑ | After posting, tap ◀ Cue at the top left. We'll open %@ next. | Depois de postar, toque em ◀ Cue no canto superior esquerdo. Abriremos %@ em seguida. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:149` | ↑ |
| B134 | ↑ | ↑ | After posting, tap ◀ Cue at the top left. We'll come back to finish. | Depois de postar, toque em ◀ Cue no canto superior esquerdo. Vamos voltar para terminar. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueStep.swift:151` | ↑ |
| B135 | ↑ | ↑ | %1$lld OF %2$lld | %lld DE %lld | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:18` | ↑ |
| B136 | ↑ | ↑ | Post to %@ | Postar no %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:20` | ↑ |
| B137 | ↑ | ↑ | Posted on %@? | Postou no %@? | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:24` | ↑ |
| B138 | ↑ | ↑ | Welcome back. Cue lights its planet once it’s live. | Que bom ter você de volta. O Cue acende o planeta quando o vídeo estiver no ar. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:25` | ↑ |
| B139 | ↑ | ↑ | Not yet | Ainda não | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:31` | ↑ |
| B140 | ↑ | ↑ | Yes, it’s live | Sim, já está no ar | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueConfirm.swift:34` | ↑ |
| B141 | ↑ | ↑ | Posting to %lld networks | Postando em %lld redes | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:16` | ↑ |
| B142 | ↑ | ↑ | Cue opens each app | O Cue abre cada app | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:17` | ↑ |
| B143 | ↑ | ↑ | Your video is already loaded and the post text is copied. | Seu vídeo já está carregado e o texto está copiado. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:17` | ↑ |
| B144 | ↑ | ↑ | You post there | Você posta lá | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:18` | ↑ |
| B145 | ↑ | ↑ | Paste the text, pick the cover, tap Post. | Cole o texto, escolha a capa e toque em Postar. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:18` | ↑ |
| B146 | ↑ | ↑ | Tap ◀ Cue to come back | Toque em ◀ Cue para voltar | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:19` | ↑ |
| B147 | ↑ | ↑ | Top left of the screen. Cue takes you to the next network. | No canto superior esquerdo da tela. O Cue leva você à próxima rede. | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:19` | ↑ |
| B148 | ↑ | ↑ | Start with %@ | Começar pelo %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:33` | ↑ |
| B149 | ↑ | ↑ | %@ | %@ | ↑ | ↑ | `Screens/TakeReview/Share/ShareQueueExplainer.swift:45` | ↑ |
| B150 | **Linha de rede (ShareNetworkLine)** · rótulo mono · Share / Pick best take | duração vs. ideal da rede | %@ · POSTS AS A SHORT | %@ · POSTA COMO SHORT | — | — | `Models/ShareNetworkLine.swift:15` | — |
| B151 | ↑ | ↑ | %1$@ · %2$@ FITS | %@ · %@ IDEAL | ↑ | ↑ | `Models/ShareNetworkLine.swift:18` | ↑ |
| B152 | ↑ | ↑ | %1$@ · %2$@ · %3$@ UNDER | %@ · %@ · %@ A MENOS | ↑ | ↑ | `Models/ShareNetworkLine.swift:19` | ↑ |
| B153 | ↑ | ↑ | %1$@ · %2$@ · %3$@ OVER | %@ · %@ · %@ A MAIS | ↑ | ↑ | `Models/ShareNetworkLine.swift:20` | ↑ |
| B154 | ↑ | ↑ | ✓ Fits %@ | ✓ Cabe em %@ | ↑ | ↑ | `Models/LengthFit.swift:34` | ↑ |
| B155 | ↑ | ↑ | %@ under %@ | %1$@ abaixo de %2$@ | ↑ | ↑ | `Models/LengthFit.swift:35` | ↑ |
| B156 | ↑ | ↑ | %@ over %@ | %1$@ acima de %2$@ | ↑ | ↑ | `Models/LengthFit.swift:36` | ↑ |
| B157 | **Ready to travel** · tela de resultado · Revisão | o app abriu sem prova de entrega | Ready to travel. | Pronto para viajar. | Share, Share to universe, Save video, Close | — | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:21` | — |
| B158 | ↑ | ↑ | CAPTIONS ON | LEGENDAS ATIVAS | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:53` | ↑ |
| B159 | ↑ | ↑ | NO WATERMARK | SEM MARCA D’ÁGUA | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:54` | ↑ |
| B160 | ↑ | ↑ | Close | Fechar | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:69` | ↑ |
| B161 | ↑ | ↑ | Share | Compartilhar | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:74` | ↑ |
| B162 | ↑ | ↑ | · | · | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:118` | ↑ |
| B163 | ↑ | ↑ | Share to universe | Compartilhar no universo | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:150` | ↑ |
| B164 | ↑ | ↑ | Saved to Photos | Salvo no Fotos | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:155` | ↑ |
| B165 | ↑ | ↑ | Save video | Salvar vídeo | ↑ | ↑ | `Screens/TakeReview/Celebration/ReadyToTravelView.swift:160` | ↑ |

### 3.4 Exportação confiável (§38) e avisos do aparelho

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B166 | **ExportProgressCard** · cartão com barra · Revisão | exportando | Exporting | Exportando | — | — | `Screens/TakeReview/Sections/ExportProgressCard.swift:19` | `-uiTestSlowExport` |
| B167 | ↑ | ↑ | You can leave Cue. The export goes on. | Pode sair do Cue. A exportação continua. | ↑ | ↑ | `Screens/TakeReview/Sections/ExportProgressCard.swift:32` | ↑ |
| B168 | ↑ | ↑ | Keep Cue open until it’s done. | Deixe o Cue aberto até terminar. | ↑ | ↑ | `Screens/TakeReview/Sections/ExportProgressCard.swift:32` | ↑ |
| B169 | ↑ | ↑ | The iPhone is hot, so the export takes longer. Let it cool down if you can. | O iPhone está quente, então a exportação demora mais. Deixe esfriar se puder. | ↑ | ↑ | `Managers/Device/DeviceHeat.swift:15` | ↑ |
| B170 | **ExportStoppedCard** · cartão de aviso · Revisão | o Cue fechou durante a exportação anterior | The last export stopped | A última exportação parou | Save video → exporta de novo; ✕ fecha | — | `Screens/TakeReview/Sections/ExportStoppedCard.swift:20` | `-uiTestStoppedExport` |
| B171 | ↑ | ↑ | Close | Fechar | ↑ | ↑ | `Screens/TakeReview/Sections/ExportStoppedCard.swift:31` | ↑ |
| B172 | ↑ | ↑ | Cue closed before it finished. Export again to get the video. | O Cue fechou antes de terminar. Exporte de novo para ter o vídeo. | ↑ | ↑ | `Screens/TakeReview/Sections/ExportStoppedCard.swift:34` | ↑ |
| B173 | ↑ | ↑ | Save video | Salvar vídeo | ↑ | ↑ | `Screens/TakeReview/Sections/ExportStoppedCard.swift:38` | ↑ |
| B174 | **PhotosDeniedCard** · cartão de aviso · Revisão | salvar em Fotos sem permissão | Photos is off for Cue | Fotos está desativado para o Cue | Open Settings; ✕ | — | `Screens/TakeReview/Sections/PhotosDeniedCard.swift:21` | `-uiTestPermissions denied` |
| B175 | ↑ | ↑ | Allow it to save your video. | Permita o acesso para salvar seu vídeo. | ↑ | ↑ | `Screens/TakeReview/Sections/PhotosDeniedCard.swift:24` | ↑ |
| B176 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/TakeReview/Sections/PhotosDeniedCard.swift:29` | ↑ |
| B177 | ↑ | ↑ | Close | Fechar | ↑ | ↑ | `Screens/TakeReview/Sections/PhotosDeniedCard.swift:39` | ↑ |
| B178 | **LowPowerNoticeBanner** · cartão sobre a prévia · Editor | Modo Pouca Energia ligado | Low Power Mode is on | O Modo de Pouca Energia está ativado | ✕ (Close) | — | `Screens/QuickEdit/Player/LowPowerNoticeBanner.swift:21` | `-uiTestLowPower` |
| B179 | ↑ | ↑ | Editing runs at 60 frames per second and exports take longer. Turn it off in Control Center for smoother editing. | A edição roda a 60 quadros por segundo e as exportações demoram mais. Desative-o na Central de Controle para editar com mais fluidez. | ↑ | ↑ | `Screens/QuickEdit/Player/LowPowerNoticeBanner.swift:24` | ↑ |
| B180 | ↑ | ↑ | Close | Fechar | ↑ | ↑ | `Screens/QuickEdit/Player/LowPowerNoticeBanner.swift:42` | ↑ |
| B181 | **MotionAnalysisNote** · linha de status · Editor › Auto, Stabilize, Face follow | análise de movimento | Finding your face · %lld%% | Encontrando seu rosto · %lld%% | — | — | `Screens/QuickEdit/Support/MotionAnalysisNote.swift:27` | — |
| B182 | ↑ | ↑ | Measuring the shake · %lld%% | Medindo o tremor · %lld%% | ↑ | ↑ | `Screens/QuickEdit/Support/MotionAnalysisNote.swift:28` | ↑ |
| B183 | ↑ | ↑ | Waiting for the iPhone to cool down · %lld%% | Esperando o iPhone esfriar · %lld%% | ↑ | ↑ | `Screens/QuickEdit/Support/MotionAnalysisNote.swift:31` | ↑ |
| B184 | ↑ | ↑ | Goes on when Cue is open · %lld%% | Continua quando o Cue estiver aberto · %lld%% | ↑ | ↑ | `Screens/QuickEdit/Support/MotionAnalysisNote.swift:33` | ↑ |
| B185 | ↑ | ↑ | This video couldn’t be read | Não foi possível ler este vídeo | ↑ | ↑ | `Screens/QuickEdit/Support/MotionAnalysisNote.swift:35` | ↑ |
| B186 | **Abrindo a edição** · sobreposição · Editor | abrir uma take | OPENING YOUR EDIT | ABRINDO SUA EDIÇÃO | — | — | `Screens/QuickEdit/Support/EditorOpeningOverlay.swift:17` | — |
| B187 | ↑ | ↑ | Your take is read and put on the timeline in a moment. | Seu take é lido e colocado na linha do tempo em instantes. | ↑ | ↑ | `Screens/QuickEdit/Support/EditorOpeningOverlay.swift:31` | ↑ |
| B188 | ↑ | ↑ | Opening your edit | Abrindo sua edição | ↑ | ↑ | `Screens/QuickEdit/Support/EditorOpeningOverlay.swift:40` | ↑ |
| B189 | ↑ | ↑ | ✦ | ✦ | ↑ | ↑ | `Screens/QuickEdit/Support/EditorOpeningOverlay.swift:48` | ↑ |
| B190 | ↑ | ↑ | Getting your take ready | Preparando seu take | ↑ | ↑ | `Screens/QuickEdit/Support/EditorOpeningOverlay.swift:49` | ↑ |

### 3.5 Gravador: recomendação de setup, conflitos, monetização (SetupConflict, SetupRecommendation)

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B191 | **SetupRecommendationCard** · cartão sobre a câmera · Gravador | plataforma recomenda outro setup | Your usual setup is %@. | Sua configuração de sempre é %@. | Use Recommended → toast 'Using X'; Keep My Setup → toast 'Keeping your setup' | — | `Screens/Prompter/Controls/SetupRecommendationCard.swift:69` | `-uiTestInMemory` |
| B192 | ↑ | ↑ | Use %@ | Usar %@ | ↑ | ↑ | `Screens/Prompter/Controls/SetupRecommendationCard.swift:73` | ↑ |
| B193 | ↑ | ↑ | Use Recommended | Usar o recomendado | ↑ | ↑ | `Screens/Prompter/Controls/SetupRecommendationCard.swift:74` | ↑ |
| B194 | ↑ | ↑ | Keep %@ | Manter %@ | ↑ | ↑ | `Screens/Prompter/Controls/SetupRecommendationCard.swift:78` | ↑ |
| B195 | ↑ | ↑ | Keep My Setup | Manter minha configuração | ↑ | ↑ | `Screens/Prompter/Controls/SetupRecommendationCard.swift:79` | ↑ |
| B196 | ↑ | ↑ | %1$@ instead of your usual %2$@. | %1$@ em vez do seu %2$@ de sempre. | ↑ | ↑ | `Models/SetupConflict.swift:20` | ↑ |
| B197 | ↑ | ↑ | Recommended for %@ | Recomendado para %@ | ↑ | ↑ | `Models/SetupRecommendation.swift:54` | ↑ |
| B198 | ↑ | ↑ | %@ safe zone | Zona segura do %@ | ↑ | ↑ | `Models/SetupRecommendation.swift:61` | ↑ |
| B199 | ↑ | ↑ | %@ setup | Configuração do %@ | ↑ | ↑ | `Models/SetupRecommendation.swift:66` | ↑ |
| B200 | **RecordingSetupSheet** · folha · Gravador › This take | toque na pílula de setup | This take | Este take | Back to my setup → toast 'Back to your setup' | — | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:22` | — |
| B201 | ↑ | ↑ | What Cue records with, and why. | Com o que o Cue grava, e por quê. | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:23` | ↑ |
| B202 | ↑ | ↑ | Back to my setup | Voltar à minha configuração | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:39` | ↑ |
| B203 | ↑ | ↑ | Changes here apply to this video only. | As mudanças aqui valem só para este vídeo. | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:48` | ↑ |
| B204 | ↑ | ↑ | Your setup already matches it. | Sua configuração já é igual. | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:70` | ↑ |
| B205 | ↑ | ↑ | Your usual setup is %@. | Sua configuração de sempre é %@. | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:74` | ↑ |
| B206 | ↑ | ↑ | Use Recommended | Usar o recomendado | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:78` | ↑ |
| B207 | ↑ | ↑ | Keep My Setup | Manter minha configuração | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:81` | ↑ |
| B208 | ↑ | ↑ | Remote Control | Controle remoto | ↑ | ↑ | `Screens/Prompter/Sheets/RecordingSetupSheet.swift:143` | ↑ |
| B209 | ↑ | ↑ | · | · | ↑ | ↑ | `Screens/Prompter/Controls/SetupSummaryPill.swift:25` | ↑ |
| B210 | ↑ | ↑ | › | › | ↑ | ↑ | `Screens/Prompter/Controls/SetupSummaryPill.swift:30` | ↑ |
| B211 | ↑ | ↑ | Recording setup | Configuração de gravação | ↑ | ↑ | `Screens/Prompter/Controls/SetupSummaryPill.swift:43` | ↑ |
| B212 | ↑ | ↑ | %1$@, %2$@ | %1$@, %2$@ | ↑ | ↑ | `Screens/Prompter/Controls/SetupSummaryPill.swift:44` | ↑ |
| B213 | ↑ | ↑ | Shows what this take records with and where it comes from | Mostra com o que este take grava e de onde vem cada valor | ↑ | ↑ | `Screens/Prompter/Controls/SetupSummaryPill.swift:45` | ↑ |
| B214 | **StopWarningCard + MonetizationCheck** · cartão de aviso · Gravador | parar antes de 1:00 (TikTok Creator Rewards) | Stop anyway | Parar mesmo assim | Stop anyway / Keep going | — | `Screens/Prompter/Controls/StopWarningCard.swift:29` | — |
| B215 | ↑ | ↑ | Keep going | Continuar | ↑ | ↑ | `Screens/Prompter/Controls/StopWarningCard.swift:32` | ↑ |
| B216 | ↑ | ↑ | %1$@ to %2$@ | %1$@ para %2$@ | ↑ | ↑ | `Screens/Prompter/Support/MonetizationCheck.swift:20` | ↑ |
| B217 | ↑ | ↑ | ✓ Monetizable | ✓ Monetizável | ↑ | ↑ | `Screens/Prompter/Support/MonetizationCheck.swift:22` | ↑ |
| B218 | ↑ | ↑ | %1$@ short of %2$@ | Faltam %1$@ para %2$@ | ↑ | ↑ | `Screens/Prompter/Support/MonetizationCheck.swift:28` | ↑ |
| B219 | **Linha de tempo do Studio** · HUD mono · Gravador Studio | lendo | %@ LEFT | %@ RESTANTES | — | — | `Screens/Prompter/Studio/StudioTimeLine.swift:19` | — |
| B220 | ↑ | ↑ | %@ · IDEAL %@ | %1$@ · IDEAL %2$@ | ↑ | ↑ | `Screens/Prompter/Studio/StudioTimeLine.swift:39` | ↑ |
| B221 | ↑ | ↑ | %@ · %lld OF %lld | %1$@ · %2$lld DE %3$lld | ↑ | ↑ | `Screens/Prompter/Support/PrompterSections.swift:38` | ↑ |

### 3.6 Roteiro: duração, ferramentas, fatos, achados de escrita

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B222 | **LengthNudgeSheet** · folha curta · Página do roteiro | Record com roteiro longo para a rede | ~%@ | ~%@ | Record anyway; Make it shorter (IA) | — | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift:20` | `-uiTestLongScript` |
| B223 | ↑ | ↑ | A bit long for %@ | Um pouco longo para %@ | ↑ | ↑ | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift:21` | ↑ |
| B224 | ↑ | ↑ | Make it shorter, or record as is. You can trim later. | Deixe mais curto ou grave assim. Dá para aparar depois. | ↑ | ↑ | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift:24` | ↑ |
| B225 | ↑ | ↑ | Record anyway | Gravar mesmo assim | ↑ | ↑ | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift:30` | ↑ |
| B226 | ↑ | ↑ | Make it shorter | Deixar mais curto | ↑ | ↑ | `Screens/ScriptDetail/Page/LengthNudgeSheet.swift:39` | ↑ |
| B227 | **FactCheckBanner** · faixa de aviso · Página do roteiro | rascunho com fatos (Ultra/IA) | Ultra AI can get facts wrong · Check before you record | O Ultra AI pode errar fatos · Confira antes de gravar | Checked → toast 'Marked as fact-checked' | — | `Screens/ScriptDetail/Structure/FactCheckBanner.swift:22` | `-uiTestUltra` |
| B228 | ↑ | ↑ | AI can get facts wrong · Check before you record | A IA pode errar fatos · Confira antes de gravar | ↑ | ↑ | `Screens/ScriptDetail/Structure/FactCheckBanner.swift:23` | ↑ |
| B229 | ↑ | ↑ | Checked | Conferido | ↑ | ↑ | `Screens/ScriptDetail/Structure/FactCheckBanner.swift:28` | ↑ |
| B230 | ↑ | ↑ | Hides this reminder | Oculta este lembrete | ↑ | ↑ | `Screens/ScriptDetail/Structure/FactCheckBanner.swift:32` | ↑ |
| B231 | **Achados de Import my writing (WritingFinding)** · linhas de revisão · Profile › My Cue Voice › Import my writing | leitura dos textos | Voice | Voz | — | — | `Managers/WritingImport/WritingFinding+Display.swift:12` | — |
| B232 | ↑ | ↑ | Topics | Temas | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:13` | ↑ |
| B233 | ↑ | ↑ | Audience | Público | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:14` | ↑ |
| B234 | ↑ | ↑ | Sentences | Frases | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:15` | ↑ |
| B235 | ↑ | ↑ | Words | Palavras | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:16` | ↑ |
| B236 | ↑ | ↑ | Energy | Energia | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:17` | ↑ |
| B237 | ↑ | ↑ | Humor | Humor | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:18` | ↑ |
| B238 | ↑ | ↑ | Swearing | Palavrões | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:19` | ↑ |
| B239 | ↑ | ↑ | Scripts say | Os roteiros dizem | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:20` | ↑ |
| B240 | ↑ | ↑ | Usual length | Duração habitual | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:21` | ↑ |
| B241 | ↑ | ↑ | My phrases | Minhas frases | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:22` | ↑ |
| B242 | ↑ | ↑ | Opens with | Abre com | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:23` | ↑ |
| B243 | ↑ | ↑ | Ends with | Termina com | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:24` | ↑ |
| B244 | ↑ | ↑ | “%@” | “%@” | ↑ | ↑ | `Managers/WritingImport/WritingFinding+Display.swift:44` | ↑ |
| B245 | ↑ | ↑ | Texts with it: %lld of %lld | Textos com isso: %lld de %lld | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingFindingRow.swift:28` | ↑ |
| B246 | ↑ | ↑ | Replaces: %@ | Substitui: %@ | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingFindingRow.swift:33` | ↑ |
| B247 | ↑ | ↑ | Add to My Cue Voice | Adicionar ao My Cue Voice | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:24` | ↑ |
| B248 | ↑ | ↑ | Nothing found yet. Add more texts and try again. | Nada encontrado ainda. Adicione mais textos e tente de novo. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:28` | ↑ |
| B249 | ↑ | ↑ | Back to my texts | Voltar aos meus textos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:33` | ↑ |
| B250 | ↑ | ↑ | Texts: %lld · Words: %lld | Textos: %lld · Palavras: %lld | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:43` | ↑ |
| B251 | ↑ | ↑ | Only the main language was read. | Só o idioma principal foi lido. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:48` | ↑ |
| B252 | ↑ | ↑ | Some texts were left out of the excerpts: words Apple Intelligence won’t learn from. | Alguns textos ficaram de fora dos trechos: palavras com as quais a Apple Intelligence não aprende. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:53` | ↑ |
| B253 | ↑ | ↑ | Kept to learn from | Guardado para aprender | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:70` | ↑ |
| B254 | ↑ | ↑ | Excerpts: %lld | Trechos: %lld | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:70` | ↑ |
| B255 | ↑ | ↑ | Teaches how you talk. Never reused for stories, opinions or results. Stays on this iPhone. | Ensina como você fala. Nunca é reaproveitado para histórias, opiniões ou resultados. Fica neste iPhone. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReviewView.swift:74` | ↑ |
| B256 | ↑ | ↑ | Bring scripts, captions or notes you wrote. Cue learns how you write from them, on this iPhone. | Traga roteiros, legendas ou notas que você escreveu. O Cue aprende com eles como você escreve, neste iPhone. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:16` | ↑ |
| B257 | ↑ | ↑ | I wrote these myself | Fui eu que escrevi estes textos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:21` | ↑ |
| B258 | ↑ | ↑ | Read my writing | Ler meus textos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:25` | ↑ |
| B259 | ↑ | ↑ | Apple Intelligence can use this iPhone or Private Cloud Compute. Your request and voice preferences may be sent to Apple. Writing examples and imported excerpts stay on this iPhone. | O Apple Intelligence pode usar este iPhone ou o Private Cloud Compute. Seu pedido e suas preferências de estilo podem ser enviados à Apple. Exemplos de escrita e trechos importados ficam neste iPhone. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:29` | ↑ |
| B260 | ↑ | ↑ | Paste your texts here. Put a line of --- between them. | Cole seus textos aqui. Coloque uma linha com --- entre eles. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:44` | ↑ |
| B261 | ↑ | ↑ | Nothing Cue could read in that. Texts need a dozen words or more. | O Cue não conseguiu ler nada aí. Os textos precisam de uma dúzia de palavras ou mais. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:50` | ↑ |
| B262 | ↑ | ↑ | Pasted | Colado | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:67` | ↑ |
| B263 | ↑ | ↑ | Add text | Adicionar texto | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:67` | ↑ |
| B264 | ↑ | ↑ | Paste | Colar | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:76` | ↑ |
| B265 | ↑ | ↑ | Choose files | Escolher arquivos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:84` | ↑ |
| B266 | ↑ | ↑ | Texts: %lld · Words: %lld | Textos: %lld · Palavras: %lld | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:94` | ↑ |
| B267 | ↑ | ↑ | %@ | %@ | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:98` | ↑ |
| B268 | ↑ | ↑ | Remove | Remover | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:106` | ↑ |
| B269 | ↑ | ↑ | Some files had no text Cue could read. | Alguns arquivos não tinham texto que o Cue conseguisse ler. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:113` | ↑ |
| B270 | ↑ | ↑ | Add at least 3 texts to find your phrases and how you open and close. | Adicione pelo menos 3 textos para achar suas frases e como você abre e fecha. | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:118` | ↑ |
| B271 | ↑ | ↑ | Apple Intelligence · on this iPhone | Apple Intelligence · neste iPhone | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReadingView.swift:17` | ↑ |
| B272 | ↑ | ↑ | Reading your texts | Lendo seus textos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReadingView.swift:17` | ↑ |
| B273 | ↑ | ↑ | Cancel | Cancelar | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReadingView.swift:21` | ↑ |
| B274 | **Validação de campos da voz** · texto sob o campo / toast · My Cue Voice (editores) | digitar | Add a word or two. | Adicione uma ou duas palavras. | — | — | `Models/VoiceTextCheck.swift:27` | — |
| B275 | ↑ | ↑ | Keep it under 40 characters. | Mantenha abaixo de 40 caracteres. | ↑ | ↑ | `Models/VoiceTextCheck.swift:28` | ↑ |
| B276 | ↑ | ↑ | Apple Intelligence can’t use this word. | A Apple Intelligence não pode usar esta palavra. | ↑ | ↑ | `Models/VoiceTextCheck.swift:29` | ↑ |
| B277 | ↑ | ↑ | Already added. | Já adicionado. | ↑ | ↑ | `Models/VoiceTextCheck.swift:30` | ↑ |
| B278 | ↑ | ↑ | Did you mean “%@”? | Você quis dizer “%@”? | ↑ | ↑ | `Models/VoiceTextCheck.swift:31` | ↑ |
| B279 | ↑ | ↑ | Add 2 to 4 sentences | Adicione 2 a 4 frases | ↑ | ↑ | `Models/VoiceTextValidator.swift:42` | ↑ |
| B280 | ↑ | ↑ | This has words Apple Intelligence won’t learn from. Bleep them (f***) or pick another example. | Tem palavras com as quais a Apple Intelligence não aprende. Censure-as (f***) ou escolha outro exemplo. | ↑ | ↑ | `Models/VoiceTextValidator.swift:43` | ↑ |
| B281 | ↑ | ↑ | Max %lld %@ | Máx. %1$lld %2$@ | ↑ | ↑ | `Models/VoiceLimits.swift:28` | ↑ |

### 3.7 Editor: sugestões, melhor take e notas de painel

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| B282 | **Clean up (CleanUpSuggestion)** · cartões no painel · Editor › Clean up / Pauses | ouvir a take | Pause | Pausar | — | — | `Models/CleanUpKind.swift:20` | `-uiTestDemoEdit -uiTestDemoTranscript` |
| B283 | ↑ | ↑ | Filler word | Vício de linguagem | ↑ | ↑ | `Models/CleanUpKind.swift:21` | ↑ |
| B284 | ↑ | ↑ | Possible retake | Possível regravação | ↑ | ↑ | `Models/CleanUpKind.swift:22` | ↑ |
| B285 | ↑ | ↑ | Long pause | Pausa longa | ↑ | ↑ | `Models/CleanUpSuggestion.swift:47` | ↑ |
| B286 | ↑ | ↑ | Short pause | Pausa curta | ↑ | ↑ | `Models/CleanUpSuggestion.swift:47` | ↑ |
| B287 | ↑ | ↑ | “%@” | “%@” | ↑ | ↑ | `Models/CleanUpSuggestion.swift:48` | ↑ |
| B288 | ↑ | ↑ | May be intentional, for emphasis | Pode ser de propósito, para dar ênfase | ↑ | ↑ | `Models/CleanUpSuggestion.swift:56` | ↑ |
| B289 | ↑ | ↑ | Might carry meaning · listen first | Pode ter sentido. Ouça antes | ↑ | ↑ | `Models/CleanUpSuggestion.swift:57` | ↑ |
| B290 | ↑ | ↑ | Pauses longer than | Pausas maiores que | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:38` | ↑ |
| B291 | ↑ | ↑ | Listening for pauses… | Procurando pausas… | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:48` | ↑ |
| B292 | ↑ | ↑ | Couldn't listen to this take | Não deu para ouvir este take | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:55` | ↑ |
| B293 | ↑ | ↑ | Try again | Tentar de novo | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:56` | ↑ |
| B294 | ↑ | ↑ | No long pauses | Nenhuma pausa longa | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:66` | ↑ |
| B295 | ↑ | ↑ | Your take flows. Try a shorter length. | Seu take flui. Tente um tempo menor. | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:67` | ↑ |
| B296 | ↑ | ↑ | pause | pausa | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:74` | ↑ |
| B297 | ↑ | ↑ | Filler words and retakes | Vícios de linguagem e regravações | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/PausesPanel.swift:77` | ↑ |
| B298 | ↑ | ↑ | Remove | Remover | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/CleanUpCard.swift:32` | ↑ |
| B299 | ↑ | ↑ | Keep | Manter | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/CleanUpCard.swift:32` | ↑ |
| B300 | ↑ | ↑ | %1$@, %2$@ | %1$@, %2$@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/CleanUpCard.swift:55` | ↑ |
| B301 | ↑ | ↑ | Listen | Ouvir | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/CleanUpCard.swift:77` | ↑ |
| B302 | ↑ | ↑ | Playing… | Tocando… | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/CleanUpCard.swift:78` | ↑ |
| B303 | ↑ | ↑ | Couldn't listen to this take | Não deu para ouvir este take | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:67` | ↑ |
| B304 | ↑ | ↑ | Couldn't listen to every clip | Não deu para ouvir todos os clipes | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:71` | ↑ |
| B305 | ↑ | ↑ | This take | Este take | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:97` | ↑ |
| B306 | ↑ | ↑ | Video | Vídeo | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+CleanUp.swift:98` | ↑ |
| B307 | ↑ | ↑ | %@ → %@ | %1$@ → %2$@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:72` | ↑ |
| B308 | ↑ | ↑ | Nothing selected | Nada selecionado | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:78` | ↑ |
| B309 | ↑ | ↑ | [one] Remove %lld pause / [other] Remove %lld pauses | [one] Remover %lld pausa / [other] Remover %lld pausas | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:80` | ↑ |
| B310 | ↑ | ↑ | Remove %@ | Remover %@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:82` | ↑ |
| B311 | ↑ | ↑ | Keep at least one clip | Mantenha pelo menos um clipe | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:95` | ↑ |
| B312 | ↑ | ↑ | [one] Removed %1$lld pause · %2$@ / [other] Removed %1$lld pauses · %2$@ | [one] %1$lld pausa removida · %2$@ / [other] %1$lld pausas removidas · %2$@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:111` | ↑ |
| B313 | ↑ | ↑ | Removed %1$lld · %2$@ | [one] %1$lld removido · %2$@ / [other] %1$lld removidos · %2$@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:112` | ↑ |
| B314 | ↑ | ↑ | Playing without this pause | Tocando sem esta pausa | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:124` | ↑ |
| B315 | ↑ | ↑ | Hearing the pause as it is | Ouvindo a pausa como está | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:124` | ↑ |
| B316 | ↑ | ↑ | %@ · %@ | %1$@ · %2$@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Pauses.swift:152` | ↑ |
| B317 | **Pick best take (BestTakeProposal)** · tela de escolha · Revisão › Pick your best take | 2+ takes | Pick your best take | Escolha seu melhor take | — | — | `Screens/TakeReview/Pick/PickBestTakeView.swift:50` | `-uiTestSeedSamples` |
| B318 | ↑ | ↑ | TO PICK · %lld TAKES | PARA ESCOLHER · %lld TAKES | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:51` | ↑ |
| B319 | ↑ | ↑ | Watch %@ | Assistir %@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:114` | ↑ |
| B320 | ↑ | ↑ | %1$@, %2$@ | %1$@, %2$@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:139` | ↑ |
| B321 | ↑ | ↑ | ✦ | ✦ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:146` | ↑ |
| B322 | ↑ | ↑ | Best take | Melhor take | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:147` | ↑ |
| B323 | ↑ | ↑ | ✦ WHY CUE PICKED %@ | ✦ POR QUE O CUE ESCOLHEU %@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:191` | ↑ |
| B324 | ↑ | ↑ | ✦ %@ · CUE PICKED %@ | ✦ %1$@ · O CUE ESCOLHEU %2$@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:191` | ↑ |
| B325 | ↑ | ↑ | ✓ Fits %@ · %@ | ✓ Cabe no %1$@ · %2$@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:224` | ↑ |
| B326 | ↑ | ↑ | Read the whole script | Leu o roteiro inteiro | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:225` | ↑ |
| B327 | ↑ | ↑ | Closest to your script’s length | Mais próximo da duração do roteiro | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:226` | ↑ |
| B328 | ↑ | ↑ | Your best fit so far | O que melhor se encaixa até agora | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:229` | ↑ |
| B329 | ↑ | ↑ | Record again | Gravar de novo | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:256` | ↑ |
| B330 | ↑ | ↑ | Use %@ | Usar %@ | ↑ | ↑ | `Screens/TakeReview/Pick/PickBestTakeView.swift:261` | ↑ |
| B331 | **Painel de informações da take** · linhas · Revisão | sempre | Edited | Editado | — | — | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:55` | — |
| B332 | ↑ | ↑ | Freestyle | Livre | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:71` | ↑ |
| B333 | ↑ | ↑ | %@ · %@ | %1$@ · %2$@ | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:84` | ↑ |
| B334 | ↑ | ↑ | Hides the details | Oculta os detalhes | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:97` | ↑ |
| B335 | ↑ | ↑ | Shows the details | Mostra os detalhes | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:97` | ↑ |
| B336 | ↑ | ↑ | From script %@ | Do roteiro %@ | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:105` | ↑ |
| B337 | ↑ | ↑ | Fits %@ | Ideal para %@ | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:116` | ↑ |
| B338 | ↑ | ↑ | %@ shorter than %@’s sweet spot | %1$@ abaixo do ideal para %2$@ | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:117` | ↑ |
| B339 | ↑ | ↑ | %@ longer than %@’s sweet spot | %1$@ acima do ideal para %2$@ | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:118` | ↑ |
| B340 | ↑ | ↑ | Stage | Etapa | ↑ | ↑ | `Screens/TakeReview/Sections/ReviewInfoPanel.swift:162` | ↑ |
| B341 | **BlurStatusCard** · cartão do painel · Editor › Blur area | seguir uma área | Tracked the whole time | Seguido o tempo todo | — | — | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:26` | — |
| B342 | ↑ | ↑ | Track again | Seguir de novo | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:30` | ↑ |
| B343 | ↑ | ↑ | Stays in place | Fica parada | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:45` | ↑ |
| B344 | ↑ | ↑ | Track it if what it hides moves. | Siga se o que ela esconde se mexe. | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:46` | ↑ |
| B345 | ↑ | ↑ | Track | Seguir | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:49` | ↑ |
| B346 | ↑ | ↑ | Cancel | Cancelar | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:68` | ↑ |
| B347 | ↑ | ↑ | Keeps what was tracked | Mantém o que já foi seguido | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:72` | ↑ |
| B348 | ↑ | ↑ | Not tracked %@ · %@ | Não seguido %@ · %@ | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:85` | ↑ |
| B349 | ↑ | ↑ | [one] %lld part to check. It may not cover what it hides there: look, then fix it or say it's right. / [other] %lld parts to check. It may not cover what it hides there: look, then fix it or say it's right. | [one] %lld trecho para conferir. Ali ela pode não cobrir o que esconde: olhe e corrija ou diga que está certo. / [other] %lld trechos para conferir. Ali ela pode não cobrir o que esconde: olhe e corrija ou diga que está certo. | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:87` | ↑ |
| B350 | ↑ | ↑ | It may not cover what it hides there: look, then fix it or say it's right. | Ali ela pode não cobrir o que esconde: olhe e corrija ou diga que está certo. | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:88` | ↑ |
| B351 | ↑ | ↑ | Go there | Ir até lá | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:92` | ↑ |
| B352 | ↑ | ↑ | Track from here | Seguir daqui | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:93` | ↑ |
| B353 | ↑ | ↑ | End here | Terminar aqui | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:94` | ↑ |
| B354 | ↑ | ↑ | It's right | Está certo | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurStatusCard.swift:95` | ↑ |

Todas as **notas de painel** do editor (`PanelNote`, 72 usos; dicas e motivos fixos dentro dos painéis):

| ID | Painel | EN | PT-BR | Código |
|---|---|---|---|---|
| N001 | PasteLookSheet | Turn on a part to paste it. | Ative uma parte para colar. | `Screens/QuickEdit/Sheets/PasteLookSheet.swift:33` |
| N002 | TranscriptEditSheet | Tap the first word of the part to cut, then its last word. Undo brings back what you cut. | Toque na primeira palavra do trecho que quer cortar e depois na última. Desfazer traz de volta o que você cortou. | `Screens/QuickEdit/Sheets/TranscriptEditSheet.swift:80` |
| N003 | TranscriptEditSheet | Tap the first word of the part to cut, then its last word. Crossed-out words were cut. | Toque na primeira palavra do trecho que quer cortar e depois na última. Palavras riscadas foram cortadas. | `Screens/QuickEdit/Sheets/TranscriptEditSheet.swift:80` |
| N004 | TranscriptEditSheet | Cut removes the words from the video. Fix caption text only changes what the caption says. | Cortar tira as palavras do vídeo. Corrigir legenda só muda o que a legenda diz. | `Screens/QuickEdit/Sheets/TranscriptEditSheet.swift:100` |
| N005 | TranscriptEditSheet | *(variável: `PanelNote(text: message, tint: Palette.warnText)`)* | | `Screens/QuickEdit/Sheets/TranscriptEditSheet.swift:147` |
| N006 | BrandKitEditorSheet | Add your logo to your library in Media › Your library, then pick it here. | Adicione seu logo à biblioteca em Mídia › Sua biblioteca e depois escolha aqui. | `Screens/QuickEdit/Sheets/Brand/BrandKitEditorSheet.swift:145` |
| N007 | MediaLibrarySection | Nothing here matches. Try another word or filter. | Nada aqui corresponde. Tente outra palavra ou filtro. | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:55` |
| N008 | TextToSpeechSheet | For a more natural voice, download an Enhanced or Premium one in Settings › Accessibility › Spoken Content › Voices. | Para uma voz mais natural, baixe uma Melhorada ou Premium em Ajustes › Acessibilidade › Conteúdo Falado › Vozes. | `Screens/QuickEdit/Sheets/TextToSpeech/TextToSpeechSheet.swift:125` |
| N009 | AutoCaptionsPanel | *(variável: `PanelNote(text: conflict.message, tint: Palette.warnText)`)* | | `Screens/QuickEdit/Panels/Captions/AutoCaptionsPanel.swift:31` |
| N010 | CaptionAdjustTab | Hard to read on bright scenes. Add a background, a thick outline or a halo. | Difícil de ler em cenas claras. Adicione um fundo, um contorno grosso ou um halo. | `Screens/QuickEdit/Panels/Captions/CaptionAdjustTab.swift:27` |
| N011 | CaptionAdjustTab | Pick a style in Styles to adjust it. | Escolha um estilo em Estilos para ajustar. | `Screens/QuickEdit/Panels/Captions/CaptionAdjustTab.swift:53` |
| N012 | CaptionAdjustTab | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Captions/CaptionAdjustTab.swift:68` |
| N013 | CaptionAdjustTab | The word being said is the same color as the others: pick another highlight color. | A palavra falada está da mesma cor das outras: escolha outra cor de destaque. | `Screens/QuickEdit/Panels/Captions/CaptionAdjustTab.swift:100` |
| N014 | CaptionAdjustTab | To emphasize a word, open its line in Captions › More › Emphasis. | Para dar ênfase a uma palavra, abra a linha em Legendas › Mais › Ênfase. | `Screens/QuickEdit/Panels/Captions/CaptionAdjustTab.swift:163` |
| N015 | CaptionAnimationTab | One word already shows the words one at a time. | Com Uma palavra, as palavras já aparecem uma por vez. | `Screens/QuickEdit/Panels/Captions/CaptionAnimationTab.swift:35` |
| N016 | CaptionAnimationTab | The word being said is the same color as the others: pick another highlight color. | A palavra falada está da mesma cor das outras: escolha outra cor de destaque. | `Screens/QuickEdit/Panels/Captions/CaptionAnimationTab.swift:51` |
| N017 | CaptionAnimationTab | [one] %lld line follows the voice approximately. / [other] %lld lines follow the voice approximately. | [one] %lld linha segue a voz de forma aproximada. / [other] %lld linhas seguem a voz de forma aproximada. | `Screens/QuickEdit/Panels/Captions/CaptionAnimationTab.swift:55` |
| N018 | CaptionAnimationTab | Tap a choice to preview it on the current line. | Toque numa opção para ver na linha atual. | `Screens/QuickEdit/Panels/Captions/CaptionAnimationTab.swift:57` |
| N019 | CaptionAnimationTab | Tap a style to preview it on the current line. | Toque em um estilo para ver na linha atual. | `Screens/QuickEdit/Panels/Captions/CaptionAnimationTab.swift:69` |
| N020 | CaptionEmphasisStrip | Emphasis reads best on one or two words a line. | A ênfase funciona melhor em uma ou duas palavras por linha. | `Screens/QuickEdit/Panels/Captions/CaptionEmphasisStrip.swift:26` |
| N021 | CaptionFormatTab | [one] %lld line stays as a short phrase: its words aren't timed to the voice. Set them in its More › Word timing. / [other] %lld lines stay as short phrases: their words aren't timed to the voice. Set them in a line's More › Word timing. | [one] %lld linha fica como frase curta: as palavras dela não têm o tempo da voz. Ajuste em Mais › Tempo das palavras. / [other] %lld linhas ficam como frases curtas: as palavras delas não têm o tempo da voz. Ajuste em Mais › Tempo das palavras de cada linha. | `Screens/QuickEdit/Panels/Captions/CaptionFormatTab.swift:24` |
| N022 | CaptionFormatTab | You can also drag the caption in the video. Another style keeps all of this. | Você também pode arrastar a legenda no vídeo. Com outro estilo, tudo isso continua. | `Screens/QuickEdit/Panels/Captions/CaptionFormatTab.swift:49` |
| N023 | CaptionPickTools | Tap the lines to change together. | Toque nas linhas que quer mudar juntas. | `Screens/QuickEdit/Panels/Captions/CaptionPickTools.swift:46` |
| N024 | CaptionPickTools | Pick a look in Style to style lines on their own. | Escolha um visual em Estilo para estilizar linhas separadamente. | `Screens/QuickEdit/Panels/Captions/CaptionPickTools.swift:50` |
| N025 | CaptionStylesTab | Your size, position and format stayed. | Seu tamanho, posição e formato continuam iguais. | `Screens/QuickEdit/Panels/Captions/CaptionStylesTab.swift:52` |
| N026 | CaptionStylesTab | No favorites yet. Hold a style to add it. | Nenhum favorito ainda. Toque e segure um estilo para adicionar. | `Screens/QuickEdit/Panels/Captions/CaptionStylesTab.swift:129` |
| N027 | CaptionStylesTab | Your styles go here. Style the captions, then Save style. | Seus estilos ficam aqui. Estilize as legendas e toque em Salvar estilo. | `Screens/QuickEdit/Panels/Captions/CaptionStylesTab.swift:130` |
| N028 | CaptionsPanel | *(variável: `PanelNote(text: conflict.message, tint: Palette.warnText)`)* | | `Screens/QuickEdit/Panels/Captions/CaptionsPanel.swift:39` |
| N029 | BeatsPanel | Found on your iPhone in the music you added from Files. | Encontradas no seu iPhone, na música que você adicionou do app Arquivos. | `Screens/QuickEdit/Panels/Layers/BeatsPanel.swift:36` |
| N030 | MaskPanel | Pick a shape: only the part of the photo or video inside it shows, with the video under it around it. | Escolha uma forma: só a parte da foto ou do vídeo dentro dela aparece, com o vídeo de baixo em volta. | `Screens/QuickEdit/Panels/Layers/MaskPanel.swift:28` |
| N031 | MaskPanel | It moves by keyframes: a change to the mask is kept on the keyframe at the playhead, so the mask can change over time. | Ela se move por keyframes: uma mudança na máscara fica no keyframe do cursor, para a máscara mudar ao longo do vídeo. | `Screens/QuickEdit/Panels/Layers/MaskPanel.swift:76` |
| N032 | MaskPanel | Drag the mask on the video to show another part; pinch to resize it, turn with two fingers. | Arraste a máscara no vídeo para mostrar outra parte; pince para mudar o tamanho e gire com dois dedos. | `Screens/QuickEdit/Panels/Layers/MaskPanel.swift:79` |
| N033 | MaskPanel | Drag the picture under the mask to reframe it; pinch to bring it closer. | Arraste a imagem sob a máscara para reenquadrar; pince para aproximar. | `Screens/QuickEdit/Panels/Layers/MaskPanel.swift:79` |
| N034 | MotionKeyframeControls | Add a keyframe, move the playhead, then drag the text in the video. Cue moves it between keyframes. | Adicione um quadro-chave, mova o cursor e arraste o texto no vídeo. O Cue faz o movimento entre os quadros-chave. | `Screens/QuickEdit/Panels/Layers/MotionKeyframeControls.swift:62` |
| N035 | MotionKeyframeControls | Add a keyframe, move the playhead, then drag the photo or video. Cue moves it between keyframes. | Adicione um quadro-chave, mova o cursor e arraste a foto ou o vídeo. O Cue faz o movimento entre os quadros-chave. | `Screens/QuickEdit/Panels/Layers/MotionKeyframeControls.swift:62` |
| N036 | MotionKeyframeControls | Put it on what it should follow at the playhead, then tap Track. Cue makes keyframes you can adjust. | Coloque sobre o que ele deve seguir no cursor e toque em Seguir. O Cue cria quadros-chave que você pode ajustar. | `Screens/QuickEdit/Panels/Layers/MotionKeyframeControls.swift:92` |
| N037 | MotionPresetPicker | The effect keeps its finish; this Motion plays instead of its own way in and out. | O efeito mantém o acabamento; este Movimento toca no lugar da entrada e saída dele. | `Screens/QuickEdit/Panels/Layers/MotionPresetPicker.swift:42` |
| N038 | SplitFramingTab | Drag and pinch it on the video. Every clip of this recording sits the same way; on the whole frame it stays as it is. | Arraste e faça pinça no vídeo. Todos os clipes desta gravação ficam do mesmo jeito; quando ele ocupa todo o quadro, fica como está. | `Screens/QuickEdit/Panels/Layers/Split/SplitFramingTab.swift:47` |
| N039 | SplitFramingTab | Drag and pinch it on the video. | Arraste e faça pinça no vídeo. | `Screens/QuickEdit/Panels/Layers/Split/SplitFramingTab.swift:47` |
| N040 | SplitLayoutTab | Every split screen in this video uses this layout. | Todas as telas divididas deste vídeo usam este layout. | `Screens/QuickEdit/Panels/Layers/Split/SplitLayoutTab.swift:48` |
| N041 | SplitPartTab | %@ before it without a support: the main video takes the whole frame there. | %@ antes dele sem apoio: ali o vídeo principal ocupa todo o quadro. | `Screens/QuickEdit/Panels/Layers/Split/SplitPartTab.swift:37` |
| N042 | SplitPartTab | Moves this support back to meet the one before. Your speech doesn’t change. | Move este apoio para trás até encostar no anterior. Sua fala não muda. | `Screens/QuickEdit/Panels/Layers/Split/SplitPartTab.swift:41` |
| N043 | SplitSoundTab | A photo has no sound. | Uma foto não tem som. | `Screens/QuickEdit/Panels/Layers/Split/SplitSoundTab.swift:40` |
| N044 | SplitSoundTab | This video has no sound. | Este vídeo não tem som. | `Screens/QuickEdit/Panels/Layers/Split/SplitSoundTab.swift:40` |
| N045 | SplitSoundTab | Only while this support shows. Outside it, the main video plays as it is. | Só enquanto este apoio aparece. Fora dele, o vídeo principal toca como está. | `Screens/QuickEdit/Panels/Layers/Split/SplitSoundTab.swift:46` |
| N046 | ClipCropPanel | Drag the box or pull its corners on the video. | Arraste a caixa ou puxe os cantos no vídeo. | `Screens/QuickEdit/Panels/Clip/ClipCropPanel.swift:33` |
| N047 | SpeedCurvePanel | Drag a point up to speed up, down to slow down. | Arraste um ponto para cima para acelerar e para baixo para desacelerar. | `Screens/QuickEdit/Panels/Clip/SpeedCurvePanel.swift:33` |
| N048 | StabilizePanel | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Clip/StabilizePanel.swift:29` |
| N049 | TransitionPanel | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Clip/TransitionPanel.swift:29` |
| N050 | VolumePanel | 0% keeps it muted under your voice. Turn it up to hear it. | Em 0% fica mudo sob a sua voz. Aumente para ouvir. | `Screens/QuickEdit/Panels/Clip/VolumePanel.swift:32` |
| N051 | BrandKitsSection | A brand kit keeps your colors, fonts, logo and styles together, to put on any video in one step. | Um kit de marca guarda suas cores, fontes, logo e estilos juntos, para usar em qualquer vídeo de uma vez. | `Screens/QuickEdit/Panels/Brand/BrandKitsSection.swift:19` |
| N052 | VoiceEffectsPanel | Studio Voice keeps working underneath. | A Voz de estúdio continua agindo por baixo. | `Screens/QuickEdit/Panels/Audio/VoiceEffectsPanel.swift:37` |
| N053 | VoiceEffectsPanel | This clip is muted: turn its sound on to hear an effect. | Este clipe está mudo: ligue o som dele para ouvir um efeito. | `Screens/QuickEdit/Panels/Audio/VoiceEffectsPanel.swift:37` |
| N054 | AdjustPanel | Auto fixes light and color · Your edits stay on top | Auto corrige luz e cor · Seus ajustes ficam por cima | `Screens/QuickEdit/Panels/Take/AdjustPanel.swift:45` |
| N055 | BackgroundPanel | Changes show in the preview and are saved as you make them. ✓ closes the panel. | As mudanças aparecem na prévia e são salvas na hora. ✓ fecha o painel. | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:28` |
| N056 | BackgroundPanel | Your video as you recorded it. Pick Blur, Color or Image to change what's behind you. | Seu vídeo como você gravou. Escolha Desfoque, Cor ou Imagem para mudar o que está atrás de você. | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:78` |
| N057 | BackgroundPanel | Cue finds you in every frame, on this iPhone, and changes everything around you. | O Cue encontra você em cada quadro, neste iPhone, e muda tudo ao seu redor. | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:118` |
| N058 | BackgroundPanel | Can't find people here · Use a green or blue screen | Não achei pessoas · Use fundo verde ou azul | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:120` |
| N059 | BackgroundPanel | For a video recorded in front of a green or blue screen: only the screen's color is replaced. | Para um vídeo gravado na frente de uma tela verde ou azul: só a cor da tela é substituída. | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:124` |
| N060 | BackgroundPanel | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:192` |
| N061 | CropPanel | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Take/CropPanel.swift:35` |
| N062 | SkinPanel | *(variável: `PanelNote(text: textureNote)`)* | | `Screens/QuickEdit/Panels/Take/SkinPanel.swift:236` |
| N063 | SmartPanel | No captions yet. Make them and the template styles them too. | Ainda sem legendas. Crie as legendas e o template aplica o estilo nelas também. | `Screens/QuickEdit/Panels/Take/SmartPanel.swift:79` |
| N064 | VoicePanel | Music and the sound of photos or videos on top stay as they are. | A música e o som das fotos ou vídeos por cima ficam como estão. | `Screens/QuickEdit/Panels/Take/VoicePanel.swift:52` |
| N065 | BlurPanel | Hides a face, a plate or a name | Esconde um rosto, uma placa ou um nome | `Screens/QuickEdit/Panels/Blur/BlurPanel.swift:31` |
| N066 | BlurPanel | For text, plates and screens, Solid hides completely. | Para textos, placas e telas, a Tarja esconde por completo. | `Screens/QuickEdit/Panels/Blur/BlurPanel.swift:70` |
| N067 | BlurPanel | *(variável: `PanelNote(text: Self.note(for: region.style))`)* | | `Screens/QuickEdit/Panels/Blur/BlurPanel.swift:82` |
| N068 | BlurPanel | Drag the box in the video to move it, pull a corner to resize it. Where it slipped, drag it back at that moment: that spot is yours, and tracking again keeps it. | Arraste a caixa no vídeo para mover e puxe um canto para mudar o tamanho. Onde ela escorregou, arraste de volta naquele momento: esse ponto é seu, e seguir de novo o mantém. | `Screens/QuickEdit/Panels/Blur/BlurPanel.swift:115` |
| N069 | TextStylePanel | Words, timing and motion stay with each text. | Palavras, tempo e movimento continuam próprios de cada texto. | `Screens/QuickEdit/Panels/Text/TextStylePanel.swift:156` |
| N070 | TextStylePanel | *(variável: `PanelNote(text: note)`)* | | `Screens/QuickEdit/Panels/Text/TextStylePanel.swift:308` |
| N071 | TextStylePanel | The effect makes its own light and shadow. Remove it in Animated to use a background or an outline. | O efeito cria a própria luz e sombra. Remova-o em Animados para usar um fundo ou contorno. | `Screens/QuickEdit/Panels/Text/TextStylePanel.swift:352` |
| N072 | CoverFinishStep | Your styles are first in Template. | Seus estilos aparecem primeiro em Modelo. | `Screens/QuickEdit/CoverStudio/Steps/CoverFinishStep.swift:51` |
| N073 | CoverFinishStep | Cue couldn't find a person in this picture, so nothing goes in front of the words. Try a frame where you're clearly visible. | O Cue não encontrou ninguém nesta imagem, então nada fica na frente das palavras. Tente um quadro em que você apareça bem. | `Screens/QuickEdit/CoverStudio/Steps/CoverFinishStep.swift:68` |
| N074 | CoverFinishStep | Finding you in the picture… | Encontrando você na imagem… | `Screens/QuickEdit/CoverStudio/Steps/CoverFinishStep.swift:70` |
| N075 | CoverFinishStep | Done on your iPhone. Move the title behind you to see it. | Feito no seu iPhone. Leve o título para trás de você para ver. | `Screens/QuickEdit/CoverStudio/Steps/CoverFinishStep.swift:72` |
| N076 | CoverGraphicsStep | Tap a graphic on the cover to change it. Drag to move, pinch or use the corner to resize and turn. | Toque num gráfico da capa para mudá-lo. Arraste para mover; faça pinça ou use o canto para redimensionar e girar. | `Screens/QuickEdit/CoverStudio/Steps/CoverGraphicsStep.swift:35` |
| N077 | CoverPictureStep | Drag the cover to move the picture, pinch to zoom. | Arraste a capa para mover a imagem, faça pinça para dar zoom. | `Screens/QuickEdit/CoverStudio/Steps/CoverPictureStep.swift:85` |
| N078 | CoverTitleStep | Too long to fit. Shorten the title or make the block wider. | Longo demais. Encurte o título ou alargue o bloco. | `Screens/QuickEdit/CoverStudio/Steps/CoverTitleStep.swift:24` |

## 4. Erros mostrados ao criador

Quase todo erro chega como **toast !** (§1). Os textos vêm destes tipos `LocalizedError` / mensagens. Registro: `AIFailureReport` (Console `studio.cue`/`ScriptAI` + non-fatal no Crashlytics quando chega ao criador) e `EditorFailureReport` (`noteFailure` em 28 operações do editor: open, save, draft, captions, translate, importMedia, replaceMedia, track, addTake, freezeFrame, reverse, cleanUp, replaceClip, addToLibrary, addFileToLibrary, saveToLibrary, voiceOverStart, voiceOverRecord, extractAudio, importMusic, addLibraryTrack, addSound, importBackground, autoLook, blurFollow; `reportFailure` na exportação da revisão). Nenhum desses registros muda o que o criador vê.

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| E001 | **ScriptAIError** · toast ! / alerta 'Couldn't draft the script' · Página do roteiro, Scripts | falha do Apple Intelligence | The model didn't return any text. Try again. | O modelo não devolveu nenhum texto. Tente de novo. | — | — | `Managers/ScriptAI/ScriptAIError.swift:44` | `-uiTestStubAI -uiTestWriterStalls` |
| E002 | ↑ | ↑ | The script did not keep your required wording. Try again or edit your request. | O roteiro não manteve o texto que você exigiu. Tente novamente ou edite seu pedido. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:45` | ↑ |
| E003 | ↑ | ↑ | Too long for Apple Intelligence on this iPhone. Try a shorter script, or one part at a time. | Longo demais para a Apple Intelligence neste iPhone. Tente um roteiro mais curto, ou uma parte de cada vez. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:46` | ↑ |
| E004 | ↑ | ↑ | Apple Intelligence can’t draft in this script’s language yet. | A Apple Intelligence ainda não rascunha no idioma deste roteiro. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:47` | ↑ |
| E005 | ↑ | ↑ | Apple Intelligence can’t translate between %1$@ and %2$@ yet. | A Apple Intelligence ainda não traduz entre %1$@ e %2$@. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:49` | ↑ |
| E006 | ↑ | ↑ | Apple Intelligence is still getting ready. Try again in a few minutes. | A Apple Intelligence ainda está se preparando. Tente de novo em alguns minutos. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:50` | ↑ |
| E007 | ↑ | ↑ | Apple Intelligence needs a short break. Try again in a few minutes. | A Apple Intelligence precisa de uma pausa. Tente de novo em alguns minutos. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:51` | ↑ |
| E008 | ↑ | ↑ | Apple Intelligence is taking too long. Try again in a moment. | A Apple Intelligence está demorando demais. Tente de novo daqui a pouco. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:52` | ↑ |
| E009 | ↑ | ↑ | The result wasn’t in the right language, so your script is unchanged. Try again. | O resultado não veio no idioma certo, então o seu roteiro continua como estava. Tente de novo. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:53` | ↑ |
| E010 | ↑ | ↑ | Apple Intelligence won’t work on this text. Try rewording it, or use another tool. | A Apple Intelligence não trabalha com este texto. Tente reformular ou use outra ferramenta. | ↑ | ↑ | `Managers/ScriptAI/ScriptAIError.swift:54` | ↑ |
| E011 | ↑ | ↑ | Couldn’t draft it · Try again | Não deu para rascunhar · Tente de novo | ↑ | ↑ | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:428` | ↑ |
| E012 | **UltraError** · toast ! · Scripts, página | falha / limite / rede da Ultra AI | Ultra AI isn’t set up on this iPhone | O Ultra AI não está configurado neste iPhone | — | — | `Managers/ScriptAI/Ultra/UltraError.swift:30` | `-uiTestUltra -uiTestUltraReviewFails`, `-uiTestUltraScriptsLeft 0` |
| E013 | ↑ | ↑ | Allow Ultra AI first · Privacy & AI data | Permita o Ultra AI antes · Privacidade e dados de IA | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:31` | ↑ |
| E014 | ↑ | ↑ | Ultra AI was turned off · Nothing more was sent | O Ultra AI foi desativado · Nada mais foi enviado | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:32` | ↑ |
| E015 | ↑ | ↑ | Ultra AI’s test calls are used up | As chamadas de teste do Ultra AI acabaram | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:33` | ↑ |
| E016 | ↑ | ↑ | Your Ultra AI scripts are used up | Seus roteiros do Ultra AI acabaram | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:34` | ↑ |
| E017 | ↑ | ↑ | Ultra AI needs the internet · Try again | O Ultra AI precisa de internet · Tente de novo | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:35` | ↑ |
| E018 | ↑ | ↑ | Ultra AI couldn’t draft it · Try again | O Ultra AI não conseguiu rascunhar · Tente de novo | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:36` | ↑ |
| E019 | ↑ | ↑ | Ultra AI couldn’t polish the draft · Try again | O Ultra AI não conseguiu refinar o rascunho · Tente de novo | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:37` | ↑ |
| E020 | ↑ | ↑ | Ultra AI couldn’t fit it to the time · Try again | O Ultra AI não conseguiu ajustar ao tempo · Tente de novo | ↑ | ↑ | `Managers/ScriptAI/Ultra/UltraError.swift:39` | ↑ |
| E021 | **VideoExportError / PhotoLibraryError / espaço** · toast ! ou cartão · Revisão | exportar | This take has no video. | Este take não tem vídeo. | — | — | `Managers/Export/VideoExportError.swift:18` | `-uiTestSlowExport` |
| E022 | ↑ | ↑ | This take can't be exported on this device. | Não dá para exportar este take neste aparelho. | ↑ | ↑ | `Managers/Export/VideoExportError.swift:19` | ↑ |
| E023 | ↑ | ↑ | The export stopped while Cue was in the background. | A exportação parou enquanto o Cue estava em segundo plano. | ↑ | ↑ | `Managers/Export/VideoExportError.swift:20` | ↑ |
| E024 | ↑ | ↑ | Your iPhone is too warm to finish this video. Let it cool down, then export again. | Seu iPhone está quente demais para terminar este vídeo. Deixe esfriar e exporte de novo. | ↑ | ↑ | `Managers/Export/VideoExportError.swift:21` | ↑ |
| E025 | ↑ | ↑ | Cue can't save to Photos. Allow access in Settings › Privacy › Photos. | O Cue não consegue salvar no Fotos. Permita o acesso em Ajustes › Privacidade › Fotos. | ↑ | ↑ | `Managers/Export/PhotoLibraryError.swift:12` | ↑ |
| E026 | ↑ | ↑ | Not enough space on this iPhone. Free about %lld MB and try again. | Falta espaço neste iPhone. Libere uns %lld MB e tente de novo. | ↑ | ↑ | `Screens/TakeReview/TakeReviewViewModel.swift:339` | ↑ |
| E027 | ↑ | ↑ | iOS stopped the export · Try again | O iOS parou a exportação · Tente de novo | ↑ | ↑ | `Screens/TakeReview/TakeReviewViewModel.swift:341` | ↑ |
| E028 | ↑ | ↑ | Couldn't export · Try again | Não deu para exportar · Tente de novo | ↑ | ↑ | `Screens/TakeReview/TakeReviewViewModel.swift:346` | ↑ |
| E029 | **Erros do editor** · toast ! · Editor | importar, gravar narração, capa… | Not enough space on this iPhone · Free some and try again | Falta espaço neste iPhone · Libere um pouco e tente de novo | — | — | `Screens/QuickEdit/Support/EditorErrorMessage.swift:19` | — |
| E030 | ↑ | ↑ | Another app is using the microphone · Close it and try again | Outro app está usando o microfone · Feche-o e tente de novo | ↑ | ↑ | `Screens/QuickEdit/Support/EditorErrorMessage.swift:22` | ↑ |
| E031 | ↑ | ↑ | Photos couldn't hand this over · Check your connection and try again | O Fotos não conseguiu entregar este arquivo · Confira a conexão e tente de novo | ↑ | ↑ | `Screens/QuickEdit/Support/EditorErrorMessage.swift:25` | ↑ |
| E032 | ↑ | ↑ | Can't add this file | Não dá para adicionar o arquivo | ↑ | ↑ | `Managers/Editing/Layers/EditMediaImportError.swift:14` | ↑ |
| E033 | ↑ | ↑ | Couldn't start recording | Não deu para começar a gravar | ↑ | ↑ | `Managers/Editing/Layers/VoiceOverError.swift:15` | ↑ |
| E034 | ↑ | ↑ | Couldn't record the voice-over · Try again | Não deu para gravar a narração · Tente de novo | ↑ | ↑ | `Managers/Editing/Layers/VoiceOverError.swift:16` | ↑ |
| E035 | ↑ | ↑ | Couldn't draw the cover | Não deu para desenhar a capa | ↑ | ↑ | `Managers/Editing/Layers/CoverError.swift:13` | ↑ |
| E036 | **Câmera** · toast ! / fundo da câmera · Gravador | câmera indisponível ou negada | This device has no camera Cue can use. | Este aparelho não tem uma câmera que o Cue possa usar. | Open Settings | — | `Managers/Camera/CaptureEngineError.swift:15` | `-uiTestPermissions denied` |
| E037 | ↑ | ↑ | Cue couldn't switch to this camera. | O Cue não conseguiu trocar para esta câmera. | ↑ | ↑ | `Managers/Camera/CaptureEngineError.swift:16` | ↑ |
| E038 | ↑ | ↑ | The camera isn't ready yet. | A câmera ainda não está pronta. | ↑ | ↑ | `Managers/Camera/CaptureEngineError.swift:17` | ↑ |
| E039 | ↑ | ↑ | Camera access is off | O acesso à câmera está desligado | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:40` | ↑ |
| E040 | ↑ | ↑ | Allow Camera and Microphone in Settings to record. | Permita Câmera e Microfone em Ajustes para gravar. | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:41` | ↑ |
| E041 | ↑ | ↑ | No camera here | Sem câmera aqui | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:46` | ↑ |
| E042 | ↑ | ↑ | No camera found · Studio mode still works | Nenhuma câmera encontrada · O modo Studio ainda funciona | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:47` | ↑ |
| E043 | ↑ | ↑ | The camera stopped | A câmera parou | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:51` | ↑ |
| E044 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/Prompter/Camera/CameraBackdrop.swift:99` | ↑ |
| E045 | ↑ | ↑ | Cue needs the microphone | O Cue precisa do microfone | ↑ | ↑ | `Screens/Prompter/Controls/MicrophoneNeededCard.swift:20` | ↑ |
| E046 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/Prompter/Controls/MicrophoneNeededCard.swift:23` | ↑ |
| E047 | ↑ | ↑ | Audio Input | Entrada de áudio | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:21` | ↑ |
| E048 | ↑ | ↑ | Where Cue hears you in this take. | Onde o Cue te ouve neste take. | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:22` | ↑ |
| E049 | ↑ | ↑ | No microphone found. Connect one and it shows up here. | Nenhum microfone encontrado. Conecte um e ele aparece aqui. | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:30` | ↑ |
| E050 | ↑ | ↑ | Plug in or pair a mic and it shows up here. | Conecte ou emparelhe um microfone e ele aparece aqui. | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:38` | ↑ |
| E051 | ↑ | ↑ | Cue can't hear you. Allow the microphone in Settings to record sound. | O Cue não consegue te ouvir. Permita o microfone em Ajustes para gravar o som. | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:78` | ↑ |
| E052 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/Prompter/Sheets/AudioInputSheet.swift:82` | ↑ |
| E053 | **Importar roteiro / comentário** · alerta / nota · Import, Answer a comment | arquivo, foto ou colagem | Cue couldn't open this file. | O Cue não conseguiu abrir este arquivo. | — | — | `Managers/Import/DocumentImportError.swift:14` | — |
| E054 | ↑ | ↑ | This file has no text Cue can read. Scanned PDFs need text recognition first. | Este arquivo não tem texto que o Cue consiga ler. PDFs escaneados precisam de reconhecimento de texto antes. | ↑ | ↑ | `Managers/Import/DocumentImportError.swift:15` | ↑ |
| E055 | ↑ | ↑ | Paste | Colar | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:22` | ↑ |
| E056 | ↑ | ↑ | Scan | Escanear | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:23` | ↑ |
| E057 | ↑ | ↑ | Photo | Foto | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:24` | ↑ |
| E058 | ↑ | ↑ | File | Arquivo | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:25` | ↑ |
| E059 | ↑ | ↑ | Import | Importar | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:55` | ↑ |
| E060 | ↑ | ↑ | Bring a script in | Traga um roteiro | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:58` | ↑ |
| E061 | ↑ | ↑ | Reading the text… | Lendo o texto… | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:75` | ↑ |
| E062 | ↑ | ↑ | Use this script | Usar este roteiro | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:80` | ↑ |
| E063 | ↑ | ↑ | Couldn't import | Não deu para importar | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:112` | ↑ |
| E064 | ↑ | ↑ | OK | OK | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:113` | ↑ |
| E065 | ↑ | ↑ | Script text | Texto do roteiro | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:154` | ↑ |
| E066 | ↑ | ↑ | Paste, scan or pick a script. You can fix it before you use it. | Cole, escaneie ou escolha um roteiro. Você pode corrigir antes de usar. | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:157` | ↑ |
| E067 | ↑ | ↑ | Allow camera in Settings | Permita a câmera em Ajustes | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:173` | ↑ |
| E068 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:177` | ↑ |
| E069 | ↑ | ↑ | Copy your script first | Copie seu roteiro primeiro | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:206` | ↑ |
| E070 | ↑ | ↑ | Pasted text | Texto colado | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:211` | ↑ |
| E071 | ↑ | ↑ | Write your reply yourself. | Escreva sua resposta você mesmo. | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:56` | ↑ |
| E072 | ↑ | ↑ | That picture can’t be opened. | Não foi possível abrir essa imagem. | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:66` | ↑ |
| E073 | ↑ | ↑ | Cue couldn’t find any words in that picture. You can paste the comment instead. | O Cue não encontrou palavras nessa imagem. Você pode colar o comentário. | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:73` | ↑ |
| E074 | ↑ | ↑ | Copy the comment first, then paste it here. | Copie o comentário primeiro e cole aqui. | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:81` | ↑ |
| E075 | ↑ | ↑ | @ | @ | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentViewModel.swift:108` | ↑ |
| E076 | **Remoto** · painel / toast · Settings › Remote, gravador | parear | Cue can't reach nearby devices. Turn on Local Network for Cue in Settings. | O Cue não alcança aparelhos por perto. Ative Rede Local para o Cue em Ajustes. | — | — | `Managers/Remote/NearbyLink.swift:270` | `-uiTestRemoteConnects` |
| E077 | ↑ | ↑ | Can't scan here | Não dá para escanear aqui | ↑ | ↑ | `Screens/Shared/RemoteControl/QRScannerSheet.swift:24` | ↑ |
| E078 | ↑ | ↑ | Scan the code with the Camera app, or enter the letters under it. | Escaneie o código com o app Câmera ou digite as letras abaixo dele. | ↑ | ↑ | `Screens/Shared/RemoteControl/QRScannerSheet.swift:25` | ↑ |
| E079 | ↑ | ↑ | Scan the code | Escanear o código | ↑ | ↑ | `Screens/Shared/RemoteControl/QRScannerSheet.swift:29` | ↑ |
| E080 | **StoreKit** · alerta 'Purchase' / toast · Pro, Settings | compra / restaurar | Couldn't reach the App Store. Check your connection and try again. | Não deu para falar com a App Store. Confira sua conexão e tente de novo. | — | — | `Managers/Store/StoreManager.swift:75` | `CueStudio.storekit` |
| E081 | ↑ | ↑ | Can't reach the App Store | Não foi possível acessar a App Store | ↑ | ↑ | `Managers/Store/StoreManager.swift:108` | ↑ |
| E082 | ↑ | ↑ | The App Store couldn't verify this purchase. | A App Store não conseguiu verificar esta compra. | ↑ | ↑ | `Managers/Store/StoreManager.swift:117` | ↑ |
| E083 | ↑ | ↑ | Your purchase is waiting for approval. | Sua compra está aguardando aprovação. | ↑ | ↑ | `Managers/Store/StoreManager.swift:124` | ↑ |
| E084 | ↑ | ↑ | Purchase didn't go through | A compra não foi concluída | ↑ | ↑ | `Managers/Store/StoreManager.swift:143` | ↑ |

## 5. Estados vazios e placeholders

| ID | Tipo visual | Tela | Condição | EN | PT-BR | Ação → efeito | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| V001 | EmptyLibraryView (primeiro uso) | Scripts | nunca teve roteiro | No scripts yet | Ainda sem roteiros | cartões Write / Import | `Screens/Scripts/Empty/EmptyLibraryView.swift:43` | `-uiTestInMemory` sem `-uiTestSeedSamples` |
| V002 | EmptyLibraryView (de volta) | Scripts | apagou todos | No scripts right now | Nenhum roteiro agora | idem, sem ilustração | `Screens/Scripts/Empty/EmptyLibraryView.swift:43` | — |
| V003 | EmptyState | Scripts (busca) | busca sem resultado | No matches / Try another word. / Clear search | Nada encontrado / Tente outra palavra. / Limpar busca | limpa a busca | `Screens/Scripts/ScriptsView.swift:484` | `-uiTestSeedSamples` |
| V004 | EmptyState | Scripts (filtro de rede) | filtro sem roteiros | No %@ scripts yet / Your next idea can start one. / Create for %@ | Ainda sem roteiros de %@ / Sua próxima ideia pode começar um. / Criar para %@ | foca o dock na rede | `Screens/Scripts/ScriptsView.swift:489` | — |
| V005 | EmptyState | Scripts (pasta) | pasta vazia | “%@” is empty / Move a script here from its menu. / Show all scripts | “%@” está vazia / Mova um roteiro para cá pelo menu dele. / Mostrar todos os roteiros | mostra todos | `Screens/Scripts/ScriptsView.swift:500` | — |
| V006 | EmptyState (icon .takes) | Takes | sem takes | No takes yet / Record a script. Every take lands here. / Record / Pick a script › | Nenhum take ainda / Grave um roteiro. Cada take chega aqui. / Gravar / Escolher um roteiro › | ● Record abre o gravador; link vai a Scripts | `Screens/Takes/TakesView.swift:130` | `-uiTestInMemory` |
| V007 | texto | Takes (filtro) | filtro sem resultado | No videos for %@ here / Pick another stage or platform, or show every video. / No takes here yet. | Nenhum vídeo para %@ aqui / Escolha outra etapa ou plataforma, ou mostre todos os vídeos. / Nenhum take aqui ainda. | botão de limpar filtro | `Screens/Takes/TakesView.swift:178` | — |
| V008 | texto (por etapa) | Takes (etapa) | etapa vazia | Nothing ready yet / Nothing here yet / No edits waiting. / Nothing shared yet. | Nada pronto ainda / Ainda não há nada aqui / Nenhuma edição pendente. / Nada compartilhado ainda. | — | `Models/TakeStage.swift:87` | — |
| V009 | EmptyStateMark + texto | Logbook | sem ideias | Your Logbook is empty / Hold the mic to catch an idea. Write it later. | Seu Diário de bordo está vazio / Segure o microfone para captar uma ideia. Escreva depois. | o campo embaixo é a ação | `Screens/Scripts/Logbook/LogbookView.swift:353` | — |
| V010 | texto | Find inspiration | sem ideias / falhou | No ideas here right now / Couldn’t get new ideas | Nenhuma ideia aqui agora / Não foi possível obter novas ideias | ↻ | `Screens/Scripts/Inspiration/FindInspirationSheet.swift:315` | `-uiTestIdeasFail` |
| V011 | texto | Editor › Library | biblioteca vazia | Your library is empty / Keep your logo, photos and videos here to use them in any video. Videos you make keep their own copy. | Sua biblioteca está vazia / Guarde aqui seu logo, fotos e vídeos para usar em qualquer vídeo. Os vídeos que você faz guardam a própria cópia. | Add from Photos / Files | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:165` | `-uiTestSeedLibrary` |
| V012 | PanelNote | Editor › Library (busca) | sem resultado | Nothing here matches. Try another word or filter. | Nada aqui corresponde. Tente outra palavra ou filtro. | — | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:55` | — |
| V013 | texto | Editor › Add music | busca sem faixa | No track matches · Try another word or filter | Nenhuma faixa encontrada · Tente outra palavra ou filtro | — | `Screens/QuickEdit/Sheets/Music/AddMusicSheet.swift:96` | — |
| V014 | PanelNote | Editor › Caption styles | sem favoritos / estilos | No favorites yet. Hold a style to add it. / Your styles go here. Style the captions, then Save style. | Nenhum favorito ainda. Toque e segure um estilo para adicionar. / Seus estilos ficam aqui. Estilize as legendas e toque em Salvar estilo. | — | `Screens/QuickEdit/Panels/Captions/CaptionStylesTab.swift:129` | — |
| V015 | PanelNote | Editor › Brand | sem kits | A brand kit keeps your colors, fonts, logo and styles together, to put on any video in one step. | Um kit de marca guarda suas cores, fontes, logo e estilos juntos, para usar em qualquer vídeo de uma vez. | New kit | `Screens/QuickEdit/Panels/Brand/BrandKitsSection.swift:19` | — |
| V016 | texto | Editor › Find in captions | nada encontrado | No line says “%@” | Nenhuma linha diz “%@” | — | `Screens/QuickEdit/Sheets/CaptionFindSheet.swift:119` | — |
| V017 | texto | Editor › barra superior | sem mudanças | No changes yet | Sem mudanças ainda | — | `Screens/QuickEdit/Bars/EditorTopBar.swift:47` | — |
| V018 | texto | Editor › Compare | nada mudou | Nothing changed yet | Nada mudou ainda | — | `Screens/QuickEdit/Panels/Controls/PanelCompareButton.swift:31` | — |
| V019 | texto | Editor › Smart | sem legendas | No captions yet. Make them and the template styles them too. | Ainda sem legendas. Crie as legendas e o template aplica o estilo nelas também. | — | `Screens/QuickEdit/Panels/Take/SmartPanel.swift:79` | — |
| V020 | texto | Editor › Text to speech | sem voz no idioma | No voice for this language on this iPhone. | Não há voz para este idioma neste iPhone. | — | `Screens/QuickEdit/Sheets/TextToSpeech/TextToSpeechSheet.swift:111` | — |
| V021 | ContentUnavailableView | Editor › Cover | imagem ilegível | Can't read this picture | Não dá para ler esta imagem | — | `Screens/QuickEdit/CoverStudio/Canvas/CoverCanvas.swift:76` | — |
| V022 | ContentUnavailableView | Página do roteiro | roteiro apagado (deep link, outra aba) | This script was deleted | Este roteiro foi apagado | — | `Screens/ScriptDetail/ScriptDetailView.swift:52` | `-uiTestNotificationTap` |
| V023 | ContentUnavailableView | Revisão | take apagada | This take was deleted | Este take foi apagado | — | `Screens/TakeReview/TakeReviewView.swift:124` | — |
| V024 | ContentUnavailableView | Settings (busca) | sem resultado | No results for “%@” / Try another word, like speed or mirror. | Nenhum resultado para “%@” / Tente outra palavra, como velocidade ou espelhar. | — | `Screens/Settings/Home/SettingsSearchResults.swift:18` | — |
| V025 | ContentUnavailableView | Scanner QR | câmera indisponível | Can't scan here / Scan the code with the Camera app, or enter the letters under it. | Não dá para escanear aqui / Escaneie o código com o app Câmera ou digite as letras abaixo dele. | — | `Screens/Shared/RemoteControl/QRScannerSheet.swift:23` | — |
| V026 | texto | Settings › Notifications | sem lembretes | No reminders. Set one from a script, a recording, or Post later. | Nenhum lembrete. Crie um a partir de um roteiro, uma gravação ou Postar depois. | — | `Screens/Settings/Notifications/NotificationsSettingsView.swift:201` | `-uiTestNotificationAuth` |
| V027 | texto | Settings › Remote | sem remoto | No remote yet / No remote connected | Nenhum controle remoto ainda / Nenhum controle conectado | — | `Screens/Settings/Pages/SettingsRemoteView.swift:83` | — |
| V028 | texto | Settings › Personalize | sem tópicos | No topics yet | Nenhum tema ainda | — | `Screens/Settings/Personalize/PersonalizeTopics.swift:25` | — |
| V029 | texto | Gravador › Audio input | sem microfone externo | No microphone found. Connect one and it shows up here. / Plug in or pair a mic and it shows up here. | Nenhum microfone encontrado. Conecte um e ele aparece aqui. / Conecte ou emparelhe um microfone e ele aparece aqui. | — | `Screens/Prompter/Sheets/AudioInputSheet.swift:30` | — |
| V030 | texto | Gravador › Camera settings | câmera ainda não ligou | Cameras appear here once the camera is running. | As câmeras aparecem aqui quando a câmera estiver ligada. | — | `Screens/Prompter/Sheets/CameraSettingsSheet.swift:73` | — |
| V031 | texto | Relógio | nada na tela do iPhone | No script on screen / Prepare on your iPhone / Open Cue on your iPhone and pick a script or a freestyle recording. | Sem roteiro na tela / Prepare no iPhone / Abra o Cue no iPhone e escolha um roteiro ou a gravação livre. | — | `Watch/Screens/WatchReadyView.swift:29` | — |
| V032 | texto | Profile › Your universe | ano sem dados | Not available yet | Ainda não disponível | — | `Screens/Profile/Universe/UniverseReviewRowView.swift:41` | `-uiTestUniverse newAccount` |
| V033 | texto | Página do roteiro › Hooks | sem frase de abertura | No opening line yet | Ainda sem frase de abertura | — | `Screens/ScriptDetail/Sheets/HooksSheet.swift:37` | — |
| V034 | texto | Página do roteiro | nada a salvar | Nothing to save yet | Nada para salvar ainda | — | `Screens/ScriptDetail/ScriptDetailViewModel+Page.swift:130` | — |
| V035 | texto (linha da lista) | Scripts | roteiro sem cues | No cues | Sem marcações | — | `Screens/Scripts/Support/ScriptRowLine.swift:31` | — |

**Placeholders de campos** (o texto cinza que diz o que escrever):

| ID | Campo | EN | PT-BR | Código |
|---|---|---|---|---|
| P001 | SettingsSearchField | Search | Buscar | `Screens/Settings/Home/SettingsSearchField.swift:16` |
| P002 | RemoteJoinFlow | ABC 234 | ABC 234 | `Screens/Settings/Remote/RemoteJoinFlow.swift:23` |
| P003 | BrandKitEditorSheet | Kit name | Nome do kit | `Screens/QuickEdit/Sheets/Brand/BrandKitEditorSheet.swift:24` |
| P004 | MediaLibrarySection | Name | Nome | `Screens/QuickEdit/Sheets/Library/MediaLibrarySection.swift:83` |
| P005 | TextToSpeechSheet | Type what the voice will say | Digite o que a voz vai falar | `Screens/QuickEdit/Sheets/TextToSpeech/TextToSpeechSheet.swift:68` |
| P006 | CaptionLineCard | What's said here | O que é dito aqui | `Screens/QuickEdit/Panels/Captions/CaptionLineCard.swift:107` |
| P007 | StyleNamePrompt | Name | Nome | `Screens/QuickEdit/Panels/Controls/StyleNamePrompt.swift:33` |
| P008 | GraphicStylePanel | Tag | Etiqueta | `Screens/QuickEdit/Panels/Text/GraphicStylePanel.swift:19` |
| P009 | CoverGraphicsStep | yourname | seunome | `Screens/QuickEdit/CoverStudio/Steps/CoverGraphicsStep.swift:43` |
| P010 | CoverTitleStep | EP 03, HOW TO, PART 2… | EP 03, COMO FAZER, PARTE 2… | `Screens/QuickEdit/CoverStudio/Steps/CoverTitleStep.swift:88` |
| P011 | CoverTitleStep | Title on the cover | Título na capa | `Screens/QuickEdit/CoverStudio/Steps/CoverTitleStep.swift:102` |
| P012 | TranslatedLineRow | Translation | Tradução | `Screens/QuickEdit/Rows/TranslatedLineRow.swift:25` |
| P013 | ScriptDetailView | Folder name | Nome da pasta | `Screens/ScriptDetail/ScriptDetailView.swift:73` |
| P014 | ScriptPageHeader | Untitled | Sem título | `Screens/ScriptDetail/Page/ScriptPageHeader.swift:23` |
| P015 | ScriptPageView | laugh | ria | `Screens/ScriptDetail/Page/ScriptPageView.swift:139` |
| P016 | CreatorTypePicker | Podcaster, chef, gamer… | Podcaster, chef, gamer… | `Screens/Profile/Sheets/CreatorTypePicker.swift:112` |
| P017 | EditProfileSheet | Your name | Seu nome | `Screens/Profile/Sheets/EditProfileSheet.swift:74` |
| P018 | EditProfileSheet | username | usuário | `Screens/Profile/Sheets/EditProfileSheet.swift:87` |
| P019 | VoiceQuestionSheet | Type yours | Digite o seu | `Screens/Profile/Voice/Question/VoiceQuestionSheet.swift:141` |
| P020 | WritingImportCollectView | Paste your texts here. Put a line of --- between them. | Cole seus textos aqui. Coloque uma linha com --- entre eles. | `Screens/Profile/Voice/Import/WritingImportCollectView.swift:44` |
| P021 | VoiceExamplesField | Add 2 to 4 sentences | Adicione 2 a 4 frases | `Screens/Profile/Voice/Editor/VoiceExamplesField.swift:127` |
| P022 | ScriptsView | Folder name | Nome da pasta | `Screens/Scripts/ScriptsView.swift:118` |
| P023 | LogbookView | Type, or hold the mic to talk | Digite ou segure o microfone para falar | `Screens/Scripts/Logbook/LogbookView.swift:187` |
| P024 | AnswerCommentSheet | @name | @nome | `Screens/CreateScript/Answer/AnswerCommentSheet.swift:92` |
| P025 | AnswerCommentSheet | What they asked | O que perguntaram | `Screens/CreateScript/Answer/AnswerCommentSheet.swift:101` |
| P026 | ShareQueueStep | Post caption | Legenda da publicação | `Screens/TakeReview/Share/ShareQueueStep.swift:115` |
| P027 | UniverseChapter | Budget travel | Viagem econômica | `Screens/Onboarding/Universe/UniverseChapter.swift:118` |

Outros placeholders (vazios de editor de texto): "Say it or type your idea…" / "Type or say a title…" (dock, `Screens/Scripts/Dock/ScriptsDock.swift:693`), "Just start talking…" (`Screens/ScriptDetail/Page/ScriptTextEditor.swift:51`), "Your words appear here to review before you send." (`Screens/Shared/PromptCard/DictationButton.swift:45`).

## 6. Progresso e espera

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| W001 | **Estrela / espera da IA** · sobreposição com frase que troca · Scripts → página (transição da estrela) | enviar uma ideia; Ultra: fases | Drafting with Ultra AI | Rascunhando com o Ultra AI | Cancel → para; a ideia fica no campo | — | `Screens/Scripts/Transition/StarTransitionOverlay.swift:208` | `-uiTestStarTransition`, `-uiTestSlowWriting`, `-uiTestUltra -uiTestUltraPaced(Long)` |
| W002 | ↑ | ↑ | Drafting in your voice | Rascunhando na sua voz | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:208` | ↑ |
| W003 | ↑ | ↑ | “%@” | “%@” | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:213` | ↑ |
| W004 | ↑ | ↑ | Writing the draft | Escrevendo o rascunho | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:252` | ↑ |
| W005 | ↑ | ↑ | Checking the facts | Conferindo os fatos | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:253` | ↑ |
| W006 | ↑ | ↑ | Polishing in your voice | Lapidando na sua voz | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:254` | ↑ |
| W007 | ↑ | ↑ | Cancel | Cancelar | ↑ | ↑ | `Screens/Scripts/Transition/StarTransitionOverlay.swift:280` | ↑ |
| W008 | **Pílula de escrita da página** · pílula · Página do roteiro | IA escrevendo / reescrevendo | ✦ | ✦ | — | — | `Screens/ScriptDetail/Page/ScriptWritingPill.swift:28` | `-uiTestSlowWriting` |
| W009 | ↑ | ↑ | Drafting with Ultra AI | Rascunhando com o Ultra AI | ↑ | ↑ | `Screens/ScriptDetail/Page/ScriptWritingPill.swift:51` | ↑ |
| W010 | ↑ | ↑ | Drafting in your voice | Rascunhando na sua voz | ↑ | ↑ | `Screens/ScriptDetail/Page/ScriptWritingPill.swift:51` | ↑ |
| W011 | ↑ | ↑ | Drafting… | Rascunhando… | ↑ | ↑ | `Screens/ScriptDetail/Page/ScriptWritingPill.swift:51` | ↑ |
| W012 | ↑ | ↑ | Drafting… | Rascunhando… | ↑ | ↑ | `Screens/ScriptDetail/Page/AISelectionBar.swift:47` | ↑ |
| W013 | ↑ | ↑ | Keep | Manter | ↑ | ↑ | `Screens/ScriptDetail/Page/AISelectionBar.swift:57` | ↑ |
| W014 | ↑ | ↑ | Undo | Desfazer | ↑ | ↑ | `Screens/ScriptDetail/Page/AISelectionBar.swift:58` | ↑ |
| W015 | ↑ | ↑ | Try again | Tentar de novo | ↑ | ↑ | `Screens/ScriptDetail/Page/AISelectionBar.swift:59` | ↑ |
| W016 | ↑ | ↑ | Written so far | Escrito até agora | ↑ | ↑ | `Screens/Shared/Writing/WritingProgressLabel.swift:29` | ↑ |
| W017 | ↑ | ↑ | Motion | Movimento | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:107` | ↑ |
| W018 | ↑ | ↑ | Drafting a hook… | Rascunhando um gancho… | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:237` | ↑ |
| W019 | ↑ | ↑ | Lining up the stars | Alinhando as estrelas | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:238` | ↑ |
| W020 | ↑ | ↑ | Shaping it your way | Moldando do seu jeito | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:239` | ↑ |
| W021 | ↑ | ↑ | Saving room for your pause | Deixando espaço para sua pausa | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:240` | ↑ |
| W022 | ↑ | ↑ | Trimming the extra words | Cortando palavras desnecessárias | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:241` | ↑ |
| W023 | ↑ | ↑ | Warming up the prompter | Aquecendo o teleprompter | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:242` | ↑ |
| W024 | ↑ | ↑ | Shaping it for %@ | Adaptando para %@ | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:243` | ↑ |
| W025 | ↑ | ↑ | Draft almost ready | Rascunho quase pronto | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:247` | ↑ |
| W026 | ↑ | ↑ | Still drafting · taking a little longer | Ainda rascunhando · está demorando um pouco mais | ↑ | ↑ | `Managers/ScriptAI/IdeaTransitionService.swift:255` | ↑ |
| W027 | **Versão para outra rede / hooks** · toast working / folha · Página do roteiro | Make a version for… / Hooks | Drafting the %@ version… | Rascunhando a versão para %@… | — | — | `Screens/ScriptDetail/ScriptDetailViewModel.swift:377` | — |
| W028 | ↑ | ↑ | Drafting hooks… | Rascunhando ganchos… | ↑ | ↑ | `Screens/ScriptDetail/Sheets/HooksSheet.swift:49` | ↑ |
| W029 | **Find inspiration (esqueleto)** · cartões fantasma · Find inspiration | buscando ideias | Finding ideas about %@… | Buscando ideias sobre %@… | — | — | `Screens/Scripts/Inspiration/InspirationCardSkeleton.swift:20` | `-uiTestIdeasSlow` |
| W030 | ↑ | ↑ | Finding ideas from your topics… | Buscando ideias dos seus temas… | ↑ | ↑ | `Screens/Scripts/Inspiration/InspirationCardSkeleton.swift:22` | ↑ |
| W031 | ↑ | ↑ | Finding more ideas… | Buscando mais ideias… | ↑ | ↑ | `Screens/Scripts/Inspiration/FindInspirationSheet.swift:401` | ↑ |
| W032 | **Importação** · texto de espera · Import, Answer a comment, Import my writing, Takes | lendo arquivo/foto/vídeo | Import | Importar | — | — | `Screens/CreateScript/ImportScriptSheet.swift:55` | — |
| W033 | ↑ | ↑ | Reading the text… | Lendo o texto… | ↑ | ↑ | `Screens/CreateScript/ImportScriptSheet.swift:75` | ↑ |
| W034 | ↑ | ↑ | Reading the comment… | Lendo o comentário… | ↑ | ↑ | `Screens/CreateScript/Answer/AnswerCommentSheet.swift:83` | ↑ |
| W035 | ↑ | ↑ | Reading your texts | Lendo seus textos | ↑ | ↑ | `Screens/Profile/Voice/Import/WritingImportReadingView.swift:17` | ↑ |
| W036 | ↑ | ↑ | Importing… | Importando… | ↑ | ↑ | `Screens/Takes/TakesViewModel.swift:59` | ↑ |
| W037 | **Trabalho do editor** · EditorWorkPill / toast working · Editor | importar, inverter, extrair som, congelar quadro, batidas, rostos | Reversing · %lld%% | Invertendo · %lld%% | Cancel (na pílula) | — | `Screens/QuickEdit/Support/EditorWork.swift:25` | — |
| W038 | ↑ | ↑ | Reversing… | Invertendo… | ↑ | ↑ | `Screens/QuickEdit/Support/EditorWork.swift:26` | ↑ |
| W039 | ↑ | ↑ | Importing · %lld%% | Importando · %lld%% | ↑ | ↑ | `Screens/QuickEdit/Support/EditorWork.swift:27` | ↑ |
| W040 | ↑ | ↑ | Importing… | Importando… | ↑ | ↑ | `Screens/QuickEdit/Support/EditorWork.swift:28` | ↑ |
| W041 | ↑ | ↑ | Finding the beats… | Encontrando as batidas… | ↑ | ↑ | `Screens/QuickEdit/Panels/Audio/AudioViewModel+Beats.swift:60` | ↑ |
| W042 | ↑ | ↑ | Extracting the sound… | Extraindo o som… | ↑ | ↑ | `Screens/QuickEdit/Panels/Audio/AudioViewModel+ExtractAudio.swift:103` | ↑ |
| W043 | ↑ | ↑ | Freezing the frame… | Congelando o quadro… | ↑ | ↑ | `Screens/QuickEdit/Panels/Clip/ClipsViewModel+Montage.swift:208` | ↑ |
| W044 | ↑ | ↑ | Looking for faces… | Procurando rostos… | ↑ | ↑ | `Screens/QuickEdit/Panels/Blur/BlurPanel.swift:47` | ↑ |
| W045 | ↑ | ↑ | Tracking · %lld%% | Seguindo · %lld%% | ↑ | ↑ | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Track.swift:21` | ↑ |
| W046 | ↑ | ↑ | Measuring… | Medindo… | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/AdjustPanel.swift:248` | ↑ |
| W047 | ↑ | ↑ | Adding… | Adicionando… | ↑ | ↑ | `Screens/QuickEdit/Panels/Take/BackgroundPanel.swift:91` | ↑ |
| W048 | ↑ | ↑ | Making the voice-over… | Criando a narração… | ↑ | ↑ | `Screens/QuickEdit/Sheets/TextToSpeech/TextToSpeechSheet.swift:145` | ↑ |
| W049 | ↑ | ↑ | Finding you in the picture… | Encontrando você na imagem… | ↑ | ↑ | `Screens/QuickEdit/CoverStudio/Steps/CoverFinishStep.swift:70` | ↑ |
| W050 | **Exportação** · cartão + Live Activity · Revisão | exportar | Exporting | Exportando | — | — | `Screens/TakeReview/Sections/ExportProgressCard.swift:19` | `-uiTestSlowExport`, `-uiTestContinuedTasks` |
| W051 | ↑ | ↑ | You can leave Cue. The export goes on. | Pode sair do Cue. A exportação continua. | ↑ | ↑ | `Screens/TakeReview/Sections/ExportProgressCard.swift:32` | ↑ |
| W052 | ↑ | ↑ | Keep Cue open until it’s done. | Deixe o Cue aberto até terminar. | ↑ | ↑ | `Screens/TakeReview/Sections/ExportProgressCard.swift:32` | ↑ |
| W053 | ↑ | ↑ | Exporting your video | Exportando seu vídeo | ↑ | ↑ | `Screens/TakeReview/TakeReviewViewModel.swift:417` | ↑ |
| W054 | **Voice Following / ditado (estados)** · chip / linha · Gravador, prática, campo de ideia | preparar o reconhecimento | Listening | Ouvindo | — | — | `Screens/Prompter/Support/VoiceFollowStatus.swift:34` | `-uiTestVoiceFollowing` |
| W055 | ↑ | ↑ | While you talk | Enquanto você fala | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:35` | ↑ |
| W056 | ↑ | ↑ | Paused | Pausado | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:36` | ↑ |
| W057 | ↑ | ↑ | Getting ready | Preparando | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:37` | ↑ |
| W058 | ↑ | ↑ | Downloading %@ | Baixando %@ | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:38` | ↑ |
| W059 | ↑ | ↑ | Downloading | Baixando | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:39` | ↑ |
| W060 | ↑ | ↑ | Follows your words | Segue suas palavras | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:47` | ↑ |
| W061 | ↑ | ↑ | Scrolls at %@ while you talk | Rola a %@ enquanto você fala | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:49` | ↑ |
| W062 | ↑ | ↑ | Getting ready to follow your words. Scrolls at %@ while you talk. | Preparando para seguir suas palavras. Rola a %@ enquanto você fala. | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:51` | ↑ |
| W063 | ↑ | ↑ | Downloading %1$@ · %2$@. Scrolls at %3$@ while you talk. | Baixando %1$@ · %2$@. Rola a %3$@ enquanto você fala. | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:53` | ↑ |
| W064 | ↑ | ↑ | Downloading this language · %1$@. Scrolls at %2$@ while you talk. | Baixando este idioma · %1$@. Rola a %2$@ enquanto você fala. | ↑ | ↑ | `Screens/Prompter/Support/VoiceFollowStatus.swift:55` | ↑ |
| W065 | ↑ | ↑ | Getting ready to follow your voice | Preparando para seguir a sua voz | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:35` | ↑ |
| W066 | ↑ | ↑ | Getting Voice Following ready · %@ | Preparando o Seguir voz · %@ | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:37` | ↑ |
| W067 | ↑ | ↑ | Getting Voice Following ready | Preparando o Seguir voz | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:39` | ↑ |
| W068 | ↑ | ↑ | Voice Following is on | O Seguir voz está ativado | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:41` | ↑ |
| W069 | ↑ | ↑ | Following your voice | Seguindo a sua voz | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:43` | ↑ |
| W070 | ↑ | ↑ | Waiting for your voice | Esperando a sua voz | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:45` | ↑ |
| W071 | ↑ | ↑ | Moves while you talk | Rola enquanto você fala | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:49` | ↑ |
| W072 | ↑ | ↑ | Microphone off · Steady scroll | Microfone desligado · Rolagem constante | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:51` | ↑ |
| W073 | ↑ | ↑ | Tap play and wait for the count. Then read out loud: the text follows your voice. | Toque no play e espere a contagem. Depois leia em voz alta: o texto segue a sua voz. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:68` | ↑ |
| W074 | ↑ | ↑ | Tap play and wait for the count. Then read out loud: the text moves while you talk. | Toque no play e espere a contagem. Depois leia em voz alta: o texto anda enquanto você fala. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:69` | ↑ |
| W075 | ↑ | ↑ | Tap play and wait for the count. Then read: the text scrolls at a steady pace. | Toque no play e espere a contagem. Depois leia: o texto rola num ritmo constante. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeVoice.swift:70` | ↑ |
| W076 | ↑ | ↑ | Downloading %@ | Baixando %@ | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:41` | ↑ |
| W077 | ↑ | ↑ | Downloading | Baixando | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:42` | ↑ |
| W078 | ↑ | ↑ | Getting ready | Preparando | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:43` | ↑ |
| W079 | ↑ | ↑ | Listening… | Ouvindo… | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:44` | ↑ |
| W080 | ↑ | ↑ | Finishing… | Finalizando… | ↑ | ↑ | `Screens/Shared/PromptCard/DictationStatusRow.swift:45` | ↑ |

## 7. Retorno durante a gravação (gravador, remoto, relógio)

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| R001 | **Contagem e gravação** · número na tela / selo · Gravador | Record | Recording in %lld | Gravando em %lld | toque cancela a contagem | — | `Screens/Prompter/Camera/CountdownOverlay.swift:22` | — |
| R002 | ↑ | ↑ | Cancels the countdown | Cancela a contagem regressiva | ↑ | ↑ | `Screens/Prompter/Camera/CountdownOverlay.swift:24` | ↑ |
| R003 | ↑ | ↑ | %@ | %@ | ↑ | ↑ | `Screens/Prompter/Camera/CountdownOverlay.swift:36` | ↑ |
| R004 | ↑ | ↑ | Stop recording | Parar gravação | ↑ | ↑ | `Screens/Prompter/Controls/RecordButton.swift:28` | ↑ |
| R005 | ↑ | ↑ | Cancel countdown | Cancelar contagem | ↑ | ↑ | `Screens/Prompter/Controls/RecordButton.swift:28` | ↑ |
| R006 | ↑ | ↑ | Record | Gravar | ↑ | ↑ | `Screens/Prompter/Controls/RecordButton.swift:28` | ↑ |
| R007 | ↑ | ↑ | Recording | Gravando | ↑ | ↑ | `Screens/Prompter/Controls/RecordingBadge.swift:39` | ↑ |
| R008 | ↑ | ↑ | Take %lld | Take %lld | ↑ | ↑ | `Screens/Prompter/Controls/RecordingTakeTitle.swift:41` | ↑ |
| R009 | ↑ | ↑ | Freestyle | Livre | ↑ | ↑ | `Screens/Prompter/Controls/RecordingTakeTitle.swift:45` | ↑ |
| R010 | ↑ | ↑ | ✦ FOLLOWING YOUR VOICE | ✦ SEGUINDO SUA VOZ | ↑ | ↑ | `Screens/Prompter/Controls/FollowingVoiceChip.swift:11` | ↑ |
| R011 | ↑ | ↑ | Voice Following | Seguir voz | ↑ | ↑ | `Screens/Prompter/Controls/VoiceIndicator.swift:43` | ↑ |
| R012 | ↑ | ↑ | Scrolls when you talk, waits when you stop. | Rola quando você fala e espera quando você para. | ↑ | ↑ | `Screens/Prompter/Controls/VoiceIndicator.swift:51` | ↑ |
| R013 | **Toasts do gravador** · toast · Gravador | ver §1 (Gravador) | Storage full · Take saved | Armazenamento cheio · Take salvo | — | — | `Models/RecordingEndReason.swift:27` | — |
| R014 | ↑ | ↑ | Interrupted · Take saved | Interrompido · Take salvo | ↑ | ↑ | `Models/RecordingEndReason.swift:28` | ↑ |
| R015 | ↑ | ↑ | Recording stopped · Take saved | Gravação parada · Take salvo | ↑ | ↑ | `Models/RecordingEndReason.swift:29` | ↑ |
| R016 | ↑ | ↑ | No %1$@ · Using %2$@ | Sem %1$@ · Usando %2$@ | ↑ | ↑ | `Screens/Prompter/Support/MicrophoneFallback.swift:18` | ↑ |
| R017 | **Prática do onboarding no gravador** · caixa / barra / cartão · Gravador (prática) | primeira prática | GET READY | PREPARE-SE | — | — | `Screens/Prompter/Practice/PracticeBoxOverlay.swift:55` | `-uiTestOnboarding` |
| R018 | ↑ | ↑ | READ! | LEIA! | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBoxOverlay.swift:93` | ↑ |
| R019 | ↑ | ↑ | Start practice | Começar a prática | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBoxOverlay.swift:120` | ↑ |
| R020 | ↑ | ↑ | TAP TO START | TOQUE PARA COMEÇAR | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBoxOverlay.swift:122` | ↑ |
| R021 | ↑ | ↑ | Your teleprompter practice. | Sua prática no teleprompter. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeMessageCard.swift:19` | ↑ |
| R022 | ↑ | ↑ | Nothing is recorded. | Nada é gravado. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeMessageCard.swift:20` | ↑ |
| R023 | ↑ | ↑ | You’ve got it. Ready to record? | Mandou bem. Vamos gravar? | ↑ | ↑ | `Screens/Prompter/Practice/PracticeMessageCard.swift:24` | ↑ |
| R024 | ↑ | ↑ | Record this script for real, or start with your own. | Grave este roteiro de verdade ou comece com o seu. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeMessageCard.swift:25` | ↑ |
| R025 | ↑ | ↑ | ✦ | ✦ | ↑ | ↑ | `Screens/Prompter/Practice/PracticeTopBar.swift:24` | ↑ |
| R026 | ↑ | ↑ | PRACTICE · NOT RECORDING | PRÁTICA · SEM GRAVAR | ↑ | ↑ | `Screens/Prompter/Practice/PracticeTopBar.swift:25` | ↑ |
| R027 | ↑ | ↑ | Record my first video | Gravar meu primeiro vídeo | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBottomBar.swift:43` | ↑ |
| R028 | ↑ | ↑ | Explore Cue first | Explorar o Cue primeiro | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBottomBar.swift:57` | ↑ |
| R029 | ↑ | ↑ | Turn on the microphone so the text can follow your voice. | Ative o microfone para o texto seguir a sua voz. | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBottomBar.swift:72` | ↑ |
| R030 | ↑ | ↑ | Open Settings | Abrir Ajustes | ↑ | ↑ | `Screens/Prompter/Practice/PracticeBottomBar.swift:78` | ↑ |
| R031 | **Dicas fixas do gravador** · texto · Gravador Selfie/Studio | controles escondidos / ainda não tocou | Tap the screen for controls | Toque na tela para ver os controles | — | — | `Screens/Prompter/Selfie/SelfieModeView.swift:36` | — |
| R032 | ↑ | ↑ | Tap play, then start reading | Toque em reproduzir e comece a ler | ↑ | ↑ | `Screens/Prompter/Studio/StudioControlPanel.swift:180` | ↑ |
| R033 | ↑ | ↑ | Freestyle | Livre | ↑ | ↑ | `Screens/Prompter/Selfie/SelfieControlParts.swift:63` | ↑ |
| R034 | ↑ | ↑ | Freestyle · Add a script anytime | Livre · Adicione um roteiro quando quiser | ↑ | ↑ | `Screens/Prompter/Selfie/SelfieControlParts.swift:64` | ↑ |
| R035 | **Estado do remoto (RemoteConnectionState)** · herói / linha / painel · Settings › Remote, gravador | parear / conectar | Not connected | Não conectado | Disconnect (sem confirmação), Try again, Open remote, Stop | — | `Models/RemoteConnectionState.swift:32` | `-uiTestRemoteConnects` |
| R036 | ↑ | ↑ | Waiting for your other device… | Esperando seu outro aparelho… | ↑ | ↑ | `Models/RemoteConnectionState.swift:33` | ↑ |
| R037 | ↑ | ↑ | Looking for the teleprompter… | Procurando o teleprompter… | ↑ | ↑ | `Models/RemoteConnectionState.swift:34` | ↑ |
| R038 | ↑ | ↑ | Remote Connected | Controle remoto conectado | ↑ | ↑ | `Models/RemoteConnectionState.swift:35` | ↑ |
| R039 | ↑ | ↑ | No remote connected | Nenhum controle conectado | ↑ | ↑ | `Screens/Settings/Remote/RemoteHero.swift:75` | ↑ |
| R040 | ↑ | ↑ | Waiting for your other device… | Esperando seu outro aparelho… | ↑ | ↑ | `Screens/Settings/Remote/RemoteHero.swift:76` | ↑ |
| R041 | ↑ | ↑ | Remote connected | Controle remoto conectado | ↑ | ↑ | `Screens/Settings/Remote/RemoteHero.swift:77` | ↑ |
| R042 | ↑ | ↑ | Open Cue | Abra o Cue | ↑ | ↑ | `Screens/Settings/Remote/RemoteWaitingSteps.swift:15` | ↑ |
| R043 | ↑ | ↑ | Settings › Remote | Ajustes › Controle remoto | ↑ | ↑ | `Screens/Settings/Remote/RemoteWaitingSteps.swift:15` | ↑ |
| R044 | ↑ | ↑ | Scan the code, or type the letters | Escaneie o código ou digite as letras | ↑ | ↑ | `Screens/Settings/Remote/RemoteWaitingSteps.swift:15` | ↑ |
| R045 | ↑ | ↑ | On the other iPhone or iPad | No outro iPhone ou iPad | ↑ | ↑ | `Screens/Settings/Remote/RemoteWaitingSteps.swift:20` | ↑ |
| R046 | ↑ | ↑ | %@ | %@ | ↑ | ↑ | `Screens/Settings/Remote/RemoteWaitingSteps.swift:39` | ↑ |
| R047 | ↑ | ↑ | Play, pause, change speed and move through the script from a second iPhone or iPad. Both need Cue, and Wi-Fi on. | Reproduza, pause, mude a velocidade e navegue pelo roteiro a partir de um segundo iPhone ou iPad. Os dois precisam do Cue e do Wi-Fi ligado. | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:37` | ↑ |
| R048 | ↑ | ↑ | Connect a Device | Conectar um dispositivo | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:44` | ↑ |
| R049 | ↑ | ↑ | Pairing QR code | QR code de pareamento | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:56` | ↑ |
| R050 | ↑ | ↑ | Code %@ | Cupom %@ | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:61` | ↑ |
| R051 | ↑ | ↑ | Scan this on the other device with the Camera. | Escaneie com a Câmera do outro aparelho. | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:64` | ↑ |
| R052 | ↑ | ↑ | Cancel | Cancelar | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:77` | ↑ |
| R053 | ↑ | ↑ | Remote Connected | Controle remoto conectado | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:90` | ↑ |
| R054 | ↑ | ↑ | Disconnect | Desconectar | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:96` | ↑ |
| R055 | ↑ | ↑ | Try again | Tentar de novo | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:112` | ↑ |
| R056 | ↑ | ↑ | This device is a remote right now. | Este aparelho está funcionando como controle remoto agora. | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:121` | ↑ |
| R057 | ↑ | ↑ | Open remote | Abrir controle remoto | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:125` | ↑ |
| R058 | ↑ | ↑ | Stop | Parar | ↑ | ↑ | `Screens/Shared/RemoteControl/RemotePairingPanel.swift:127` | ↑ |
| R059 | ↑ | ↑ | Close remote | Fechar controle remoto | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:53` | ↑ |
| R060 | ↑ | ↑ | Remote | Controle remoto | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:57` | ↑ |
| R061 | ↑ | ↑ | Keep both devices close, with Wi-Fi on. | Deixe os dois aparelhos perto, com o Wi-Fi ligado. | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:86` | ↑ |
| R062 | ↑ | ↑ | Open a script on the teleprompter | Abra um roteiro no teleprompter | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:97` | ↑ |
| R063 | ↑ | ↑ | Recording | Gravando | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:105` | ↑ |
| R064 | ↑ | ↑ | Playing | Reproduzindo | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:108` | ↑ |
| R065 | ↑ | ↑ | Paused | Pausado | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:108` | ↑ |
| R066 | ↑ | ↑ | Voice Following | Seguir voz | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:112` | ↑ |
| R067 | ↑ | ↑ | Pause | Pausar | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:133` | ↑ |
| R068 | ↑ | ↑ | Play | Reproduzir | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:133` | ↑ |
| R069 | ↑ | ↑ | Speed | Velocidade | ↑ | ↑ | `Screens/RemoteControl/RemoteControllerView.swift:145` | ↑ |
| R070 | **Apple Watch** · telas e avisos do watchOS · Cue Studio Watch | estado do iPhone | Prepare on your iPhone | Prepare no iPhone | Try again, Refresh, OK, Cancel, End, Record another, Done | — | `Watch/Screens/WatchNotice.swift:22` | — |
| R071 | ↑ | ↑ | Open Cue on your iPhone and pick a script or a freestyle recording. | Abra o Cue no iPhone e escolha um roteiro ou a gravação livre. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:22` | ↑ |
| R072 | ↑ | ↑ | No connection | Sem conexão | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:24` | ↑ |
| R073 | ↑ | ↑ | Recording may go on on your iPhone. Check there. | A gravação pode continuar no iPhone. Confira por lá. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:24` | ↑ |
| R074 | ↑ | ↑ | Try again | Tentar de novo | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:24` | ↑ |
| R075 | ↑ | ↑ | No response | Sem resposta | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:26` | ↑ |
| R076 | ↑ | ↑ | Check on your iPhone that it was done. | Confira no iPhone se o comando foi feito. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:26` | ↑ |
| R077 | ↑ | ↑ | Refresh | Atualizar | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:26` | ↑ |
| R078 | ↑ | ↑ | Didn't start recording | Não começou a gravar | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:28` | ↑ |
| R079 | ↑ | ↑ | Check the camera on your iPhone. | Confira a câmera no iPhone. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:28` | ↑ |
| R080 | ↑ | ↑ | Save not confirmed | Salvamento não confirmado | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:30` | ↑ |
| R081 | ↑ | ↑ | Check on your iPhone that the take was saved. | Confira no iPhone se o take foi salvo. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:30` | ↑ |
| R082 | ↑ | ↑ | OK | OK | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:30` | ↑ |
| R083 | ↑ | ↑ | Unavailable now | Indisponível agora | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:32` | ↑ |
| R084 | ↑ | ↑ | Go back to the recording screen on your iPhone. | Volte à tela de gravação no iPhone. | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:32` | ↑ |
| R085 | ↑ | ↑ | Last state at %@: %@ | Último estado às %@: %@ | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:51` | ↑ |
| R086 | ↑ | ↑ | recording, %@ | gravando, %@ | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:58` | ↑ |
| R087 | ↑ | ↑ | counting down | contagem regressiva | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:59` | ↑ |
| R088 | ↑ | ↑ | saving | salvando | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:60` | ↑ |
| R089 | ↑ | ↑ | take %lld saved | take %lld salvo | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:61` | ↑ |
| R090 | ↑ | ↑ | rehearsing | ensaiando | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:62` | ↑ |
| R091 | ↑ | ↑ | ready | pronto | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:63` | ↑ |
| R092 | ↑ | ↑ | not recording | sem gravar | ↑ | ↑ | `Watch/Screens/WatchNotice.swift:64` | ↑ |
| R093 | ↑ | ↑ | iPhone connected | iPhone conectado | ↑ | ↑ | `Watch/Screens/WatchNoticeView.swift:44` | ↑ |
| R094 | ↑ | ↑ | Checking your iPhone | Verificando o iPhone | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:37` | ↑ |
| R095 | ↑ | ↑ | The state appears when your iPhone answers. | O estado aparece quando o iPhone responder. | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:37` | ↑ |
| R096 | ↑ | ↑ | Asking your iPhone | Pedindo ao iPhone | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:39` | ↑ |
| R097 | ↑ | ↑ | It isn't recording yet. | Ainda não está gravando. | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:39` | ↑ |
| R098 | ↑ | ↑ | Ending on your iPhone | Encerrando no iPhone | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:41` | ↑ |
| R099 | ↑ | ↑ | Wait for the confirmation. | Aguarde a confirmação. | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:41` | ↑ |
| R100 | ↑ | ↑ | Saving on your iPhone | Salvando no iPhone | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:43` | ↑ |
| R101 | ↑ | ↑ | Sending to your iPhone | Enviando ao iPhone | ↑ | ↑ | `Watch/Screens/WatchRootView.swift:45` | ↑ |
| R102 | ↑ | ↑ | iPhone | iPhone | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:26` | ↑ |
| R103 | ↑ | ↑ | ● REC | ● REC | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:34` | ↑ |
| R104 | ↑ | ↑ | GETTING READY | PREPARANDO | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:41` | ↑ |
| R105 | ↑ | ↑ | REHEARSAL | ENSAIO | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:45` | ↑ |
| R106 | ↑ | ↑ | Connecting | Conectando | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:55` | ↑ |
| R107 | ↑ | ↑ | No connection | Sem conexão | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:56` | ↑ |
| R108 | ↑ | ↑ | No response | Sem resposta | ↑ | ↑ | `Watch/Screens/WatchStatusLabel.swift:57` | ↑ |
| R109 | ↑ | ↑ | Recording in %lld | Gravando em %lld | ↑ | ↑ | `Watch/Screens/WatchCountdownView.swift:21` | ↑ |
| R110 | ↑ | ↑ | Not recording yet | Ainda não grava | ↑ | ↑ | `Watch/Screens/WatchCountdownView.swift:22` | ↑ |
| R111 | ↑ | ↑ | Your iPhone records when it reaches zero. | O iPhone grava ao chegar a zero. | ↑ | ↑ | `Watch/Screens/WatchCountdownView.swift:26` | ↑ |
| R112 | ↑ | ↑ | Cancel | Cancelar | ↑ | ↑ | `Watch/Screens/WatchCountdownView.swift:32` | ↑ |
| R113 | ↑ | ↑ | Recording | Gravando | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:15` | ↑ |
| R114 | ↑ | ↑ | Freestyle recording | Gravação livre | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:23` | ↑ |
| R115 | ↑ | ↑ | Tap again to end | Toque de novo para encerrar | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:32` | ↑ |
| R116 | ↑ | ↑ | End | Encerrar | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:34` | ↑ |
| R117 | ↑ | ↑ | Ends the take on your iPhone | Encerra o take no iPhone | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:38` | ↑ |
| R118 | ↑ | ↑ | Tap twice to end the take | Toque duas vezes para encerrar o take | ↑ | ↑ | `Watch/Screens/WatchRecordingPage.swift:38` | ↑ |
| R119 | ↑ | ↑ | Take saved | Take salvo | ↑ | ↑ | `Watch/Screens/WatchSavedView.swift:22` | ↑ |
| R120 | ↑ | ↑ | Take %lld · %@ | Take %lld · %@ | ↑ | ↑ | `Watch/Screens/WatchSavedView.swift:26` | ↑ |
| R121 | ↑ | ↑ | Record another | Gravar outro | ↑ | ↑ | `Watch/Screens/WatchSavedView.swift:31` | ↑ |
| R122 | ↑ | ↑ | Done | Concluir | ↑ | ↑ | `Watch/Screens/WatchSavedView.swift:33` | ↑ |
| R123 | ↑ | ↑ | SCRIPT | ROTEIRO | ↑ | ↑ | `Watch/Screens/WatchReadyView.swift:16` | ↑ |
| R124 | ↑ | ↑ | Freestyle recording | Gravação livre | ↑ | ↑ | `Watch/Screens/WatchReadyView.swift:26` | ↑ |
| R125 | ↑ | ↑ | No script on screen | Sem roteiro na tela | ↑ | ↑ | `Watch/Screens/WatchReadyView.swift:29` | ↑ |
| R126 | ↑ | ↑ | Record | Gravar | ↑ | ↑ | `Watch/Screens/WatchReadyView.swift:37` | ↑ |
| R127 | ↑ | ↑ | Rehearse | Ensaiar | ↑ | ↑ | `Watch/Screens/WatchReadyView.swift:41` | ↑ |

## 8. Pro e limites: reações a uma ação bloqueada

Entradas para o Pro (`PresentationService.paywall` / `viewModel.paywall`, `PaywallContext` `.profile` · `.export` · `.ultra`):

| ID | De onde | Gatilho | Contexto | Código |
|---|---|---|---|---|
| L001 | Revisão › Share/Save com 0 exportações | toque com cota zerada → ExportReadySheet → Export with Cue Pro | .export | `Screens/TakeReview/TakeReviewViewModel.swift:210` |
| L002 | Revisão › Go Pro | botão Go Pro da linha de cota | .export ou .profile | `Screens/TakeReview/TakeReviewView.swift:390` |
| L003 | Revisão › ícone de marco Pro | ícone que precisa de Pro | .profile | `Screens/TakeReview/TakeReviewView.swift:624` |
| L004 | Settings › linha do plano | toque | .profile | `Screens/Settings/Rows/SettingsRootRow.swift:50` |
| L005 | Settings › App icon | ícone Pro no plano grátis | .profile (ícone bloqueado por marco: toast 'Unlocks at N videos shared') | `Screens/Settings/Personalize/AppIconPicker.swift:121` |
| L006 | Profile › cartão do plano | Try Pro › | .profile | `Screens/Profile/ProfileView.swift:59` |
| L007 | Scripts › ideia com Ultra sem cota | enviar no plano grátis com 0 | .ultra (no Pro: toast 'This month’s Ultra AI scripts are used · More next month') | `Managers/ScriptAI/ScriptStarter.swift:99` |
| L008 | Find inspiration › Ultra sem cota | idem | .ultra / toast | `Screens/Scripts/Inspiration/FindInspirationSheet.swift:496` |

| ID | Componente · tipo visual · tela | Gatilho e condições | EN | PT-BR | Botões → efeito | Duração / dispensa | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| L009 | **ExportReadySheet** · folha · Revisão | exportar com 0 grátis | ✓ READY | ✓ PRONTO | Export with Cue Pro → Pro calmo (.export); Not now → toast 'Saved in Takes · export with Pro anytime' | — | `Screens/TakeReview/Share/ExportReadySheet.swift:22` | `-uiTestExportsLeft 0` |
| L010 | ↑ | ↑ | Your video is ready | Seu vídeo está pronto | ↑ | ↑ | `Screens/TakeReview/Share/ExportReadySheet.swift:33` | ↑ |
| L011 | ↑ | ↑ | Saved in Takes · nothing is lost. You've used your %lld free exports. | Salvo em Takes · nada se perde. Você usou suas %lld exportações grátis. | ↑ | ↑ | `Screens/TakeReview/Share/ExportReadySheet.swift:37` | ↑ |
| L012 | ↑ | ↑ | Export with Cue Pro | Exportar com o Cue Pro | ↑ | ↑ | `Screens/TakeReview/Share/ExportReadySheet.swift:43` | ↑ |
| L013 | ↑ | ↑ | Not now | Agora não | ↑ | ↑ | `Screens/TakeReview/Share/ExportReadySheet.swift:46` | ↑ |
| L014 | **PaywallCopy / ProPlansScreen / ProHighlightCard** · tela Pro · Pro | qualquer entrada acima | Keep sharing your universe. | Continue compartilhando seu universo. | Subscribe…, Restore → toast, Terms, Privacy, Close | — | `Screens/Shared/Paywall/PaywallCopy.swift:12` | `-uiTestProAt <s>`, `CueStudio.storekit` |
| L015 | ↑ | ↑ | Take your universe further. | Leve seu universo mais longe. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:13` | ↑ |
| L016 | ↑ | ↑ | Keep writing with Ultra AI. | Continue rascunhando com o Ultra AI. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:14` | ↑ |
| L017 | ↑ | ↑ | YOUR VIDEO IS READY | SEU VÍDEO ESTÁ PRONTO | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:21` | ↑ |
| L018 | ↑ | ↑ | CUE PRO | CUE PRO | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:22` | ↑ |
| L019 | ↑ | ↑ | ULTRA AI | ULTRA AI | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:23` | ↑ |
| L020 | ↑ | ↑ | Subscribe and export it now. | Assine e exporte agora. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:31` | ↑ |
| L021 | ↑ | ↑ | Your %lld free scripts are written. Cue Pro adds %lld a month. | Seus %1$lld roteiros grátis já foram rascunhados. O Cue Pro dá %2$lld por mês. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:35` | ↑ |
| L022 | ↑ | ↑ | Full My Cue Voice and ad drafts | My Cue Voice completo e rascunhos de publicidade | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:41` | ↑ |
| L023 | ↑ | ↑ | Hook and platform versions | Versões de gancho e por plataforma | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:42` | ↑ |
| L024 | ↑ | ↑ | Covers, series tags and “Text behind me” | Capas, tags de série e “Texto atrás de mim” | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:43` | ↑ |
| L025 | ↑ | ↑ | Remote from Apple Watch, iPad & Mac sync | Controle remoto pelo Apple Watch, iPad e sincronização com o Mac | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:44` | ↑ |
| L026 | ↑ | ↑ | Every milestone app icon | Todos os ícones de marcos | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:45` | ↑ |
| L027 | ↑ | ↑ | Free to try · %lld exports included. | Grátis para testar · %lld exportações incluídas. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:56` | ↑ |
| L028 | ↑ | ↑ | Free to try · %lld exports and %lld Ultra AI scripts included. | Grátis para testar · %1$lld exportações e %2$lld roteiros do Ultra AI incluídos. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:61` | ↑ |
| L029 | ↑ | ↑ | Welcome to Cue Pro · video exported | Boas-vindas ao Cue Pro · vídeo exportado | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:66` | ↑ |
| L030 | ↑ | ↑ | Welcome to Cue Pro | Boas-vindas ao Cue Pro | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:67` | ↑ |
| L031 | ↑ | ↑ | [one] Welcome to Cue Pro · %lld Ultra AI script this month / [other] Welcome to Cue Pro · %lld Ultra AI scripts this month | [one] Boas-vindas ao Cue Pro · %lld roteiro do Ultra AI este mês / [other] Boas-vindas ao Cue Pro · %lld roteiros do Ultra AI este mês | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:68` | ↑ |
| L032 | ↑ | ↑ | %@ / year | %@ / ano | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:78` | ↑ |
| L033 | ↑ | ↑ | %@ / month | %@ / mês | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:79` | ↑ |
| L034 | ↑ | ↑ | Subscribe · export now | Assinar · exportar agora | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:84` | ↑ |
| L035 | ↑ | ↑ | Subscribe for %@/year | Assinar por %@/ano | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:87` | ↑ |
| L036 | ↑ | ↑ | Subscribe for %@/month | Assinar por %@/mês | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:88` | ↑ |
| L037 | ↑ | ↑ | Renews yearly at %@. Cancel anytime in Settings. | Renova todo ano por %@. Cancele quando quiser em Ajustes. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:95` | ↑ |
| L038 | ↑ | ↑ | Renews monthly at %@. Cancel anytime in Settings. | Renova todo mês por %@. Cancele quando quiser em Ajustes. | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:96` | ↑ |
| L039 | ↑ | ↑ | SAVE %lld%% | ECONOMIZE %lld%% | ↑ | ↑ | `Screens/Shared/Paywall/PaywallCopy.swift:102` | ↑ |
| L040 | ↑ | ↑ | Purchase | Comprar | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:60` | ↑ |
| L041 | ↑ | ↑ | OK | OK | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:61` | ↑ |
| L042 | ↑ | ↑ | Restore | Restaurar | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:117` | ↑ |
| L043 | ↑ | ↑ | Terms | Termos | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:118` | ↑ |
| L044 | ↑ | ↑ | Privacy | Privacidade | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:121` | ↑ |
| L045 | ↑ | ↑ | %1$@ · %2$@/mo | %@ · %@/mês | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:139` | ↑ |
| L046 | ↑ | ↑ | Purchases restored | Compras restauradas | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:169` | ↑ |
| L047 | ↑ | ↑ | No purchases to restore | Nenhuma compra para restaurar | ↑ | ↑ | `Screens/Shared/Paywall/ProPlansScreen.swift:172` | ↑ |
| L048 | ↑ | ↑ | Unlimited | Ilimitadas | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:28` | ↑ |
| L049 | ↑ | ↑ | [one] %lld script / [other] %lld scripts | [one] %lld roteiro / [other] %lld roteiros | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:28` | ↑ |
| L050 | ↑ | ↑ | up to 4K | até 4K | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:32` | ↑ |
| L051 | ↑ | ↑ | every month | todo mês | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:32` | ↑ |
| L052 | ↑ | ↑ | ✦ | ✦ | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:62` | ↑ |
| L053 | ↑ | ↑ | EXPORTS | EXPORTAÇÕES | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:68` | ↑ |
| L054 | ↑ | ↑ | ULTRA AI | ULTRA AI | ↑ | ↑ | `Screens/Shared/Paywall/ProHighlightCard.swift:68` | ↑ |
| L055 | ↑ | ↑ | Yearly | Anual | ↑ | ↑ | `Screens/Shared/Paywall/ProPlanCard.swift:29` | ↑ |
| L056 | ↑ | ↑ | Close | Fechar | ↑ | ↑ | `Screens/Shared/Paywall/PaywallView.swift:46` | ↑ |
| L057 | **StoreManager (resultado da compra)** · alerta 'Purchase' / toast · Pro, Settings | compra, pendente, verificação, restaurar | Couldn't reach the App Store. Check your connection and try again. | Não deu para falar com a App Store. Confira sua conexão e tente de novo. | — | — | `Managers/Store/StoreManager.swift:75` | — |
| L058 | ↑ | ↑ | Can't reach the App Store | Não foi possível acessar a App Store | ↑ | ↑ | `Managers/Store/StoreManager.swift:108` | ↑ |
| L059 | ↑ | ↑ | The App Store couldn't verify this purchase. | A App Store não conseguiu verificar esta compra. | ↑ | ↑ | `Managers/Store/StoreManager.swift:117` | ↑ |
| L060 | ↑ | ↑ | Your purchase is waiting for approval. | Sua compra está aguardando aprovação. | ↑ | ↑ | `Managers/Store/StoreManager.swift:124` | ↑ |
| L061 | ↑ | ↑ | Purchase didn't go through | A compra não foi concluída | ↑ | ↑ | `Managers/Store/StoreManager.swift:143` | ↑ |
| L062 | **Cartão do plano no Profile** · cartão · Profile | sempre | Cue Pro | Cue Pro | Try Pro › / Manage › | — | `Screens/Profile/Sections/ProfilePlanCard.swift:23` | — |
| L063 | ↑ | ↑ | Free plan | Plano grátis | ↑ | ↑ | `Screens/Profile/Sections/ProfilePlanCard.swift:23` | ↑ |
| L064 | ↑ | ↑ | Manage › | Gerenciar › | ↑ | ↑ | `Screens/Profile/Sections/ProfilePlanCard.swift:28` | ↑ |
| L065 | ↑ | ↑ | Try Pro › | Testar o Pro › | ↑ | ↑ | `Screens/Profile/Sections/ProfilePlanCard.swift:28` | ↑ |
| L066 | ↑ | ↑ | Active | Ativo | ↑ | ↑ | `Screens/Profile/Sections/ProfilePlanCard.swift:80` | ↑ |
| L067 | **Limites de My Cue Voice** · toast ! 'Max N …' · My Cue Voice | passar do máximo | Max %lld %@ | Máx. %1$lld %2$@ | — | — | `Models/VoiceLimits.swift:28` | — |
| L068 | ↑ | ↑ | topics | temas | ↑ | ↑ | `Managers/Preferences/CreatorProfileService+VoiceDetails.swift:39` | ↑ |
| L069 | ↑ | ↑ | subtopics | subtópicos | ↑ | ↑ | `Managers/Preferences/CreatorProfileService+VoiceDetails.swift:73` | ↑ |
| L070 | ↑ | ↑ | reasons | motivos | ↑ | ↑ | `Managers/Preferences/CreatorProfileService+VoiceDetails.swift:138` | ↑ |
| L071 | ↑ | ↑ | goals | objetivos | ↑ | ↑ | `Managers/Preferences/CreatorProfileService+VoiceDetails.swift:157` | ↑ |

## 9. Anúncios de acessibilidade

Todo toast é anunciado (`ToastService.show`, linha 47) — os textos de §1 valem aqui também. Além dele:

| ID | Onde | Quando | EN | PT-BR | Código |
|---|---|---|---|---|---|
| X001 | Editor | Desfazer / Refazer (sem toast) | Undone / Redone | Desfeito / Refeito | `Screens/QuickEdit/QuickEditViewModel.swift:487` |
| X002 | Editor › timeline | mudança de seleção/zoom do clipe | (valor da timeline: clips.timelineAccessibilityValue) |  | `Screens/QuickEdit/QuickEditViewModel+Timeline.swift:257` |
| X003 | Editor › timeline | pinça de zoom | Zoom %@× | Zoom %@× | `Screens/QuickEdit/Timeline/TimelineScrollingView.swift:811` |
| X004 | Editor › texto/mídia (ações do VoiceOver) | mover / tamanho / girar | %lld%% across, %lld%% down / Bigger / Smaller / Turned %lld° | %lld%% na horizontal, %lld%% na vertical / Maior / Menor / Girado %lld° | `Screens/QuickEdit/Panels/Layers/OverlaysViewModel+Accessibility.swift:27` |
| X005 | Editor › Blur | área adicionada com o painel aberto (no lugar do toast) | Face hidden · Tracking it / Drag it onto what to hide | Rosto escondido · Seguindo / Arraste sobre o que quer esconder | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Adding.swift:155` |
| X006 | Editor › Blur | seguir terminou com o cartão à vista (no lugar do toast, + success/warning) | Tracked the whole time / Not tracked for %@ · Check the marked part | Seguido o tempo todo / Não seguido por %@ · Confira o trecho marcado | `Screens/QuickEdit/Panels/Blur/BlurViewModel+Following.swift:167` |
| X007 | Scripts › estrela | frase atual da espera (troca) | Drafting in your voice / Drafting with Ultra AI / Writing the draft / Checking the facts / Polishing in your voice | Rascunhando na sua voz / Rascunhando com o Ultra AI / Escrevendo o rascunho / Conferindo os fatos / Lapidando na sua voz | `Screens/Scripts/Transition/StarTransitionOverlay.swift:605` |
| X008 | Scripts › dock | começou a ouvir o ditado | Listening… | Ouvindo… | `Screens/Scripts/Dock/ScriptsDock.swift:237` |

Não há `.accessibilityAnnouncement` nem `AccessibilityNotification.ScreenChanged/LayoutChanged` no app. Alertas e folhas usam o anúncio do sistema.

## Observações

Problemas concretos encontrados no levantamento, do mais importante ao menos. "Verificar no aparelho" quando a conclusão depende de como o iOS desenha.

1. **Toasts disparados dentro de folhas grandes provavelmente não aparecem.** Só o Logbook declara `toastHost(inSheet: true)` (`Screens/Scripts/Logbook/LogbookView.swift:138`); o resto do app usa o host da raiz (`Screens/Main/RootView.swift:31`), que desenha **sob** a folha. Toasts que nascem com a folha ainda aberta (sem `dismiss()` logo depois): "Copy your script first" (`Screens/CreateScript/ImportScriptSheet.swift:206`, folha `.large`), "Add brand and product" (`Screens/CreateScript/Brand/BrandBriefSheet.swift:165`), "Signed out" / "Signed in with Apple" / "Couldn't sign in · Try again" (`Screens/Profile/Sheets/EditProfileAccount.swift:31,65,67`, dentro de `EditProfileSheet` `.large`), "Saved to Photos" / "Couldn't save · Try again" (`Screens/Profile/Universe/UniverseShareSheet.swift:64-65`), os limites "Max N …" e "Already added." de My Cue Voice (`VoiceQuestionSheetModel.swift:88,124`, campos de `VoiceEditorSheet`). O VoiceOver ainda anuncia, mas quem vê não recebe nada (num detent `.medium` o topo fica à vista). Verificar no aparelho; a correção é dar `toastHost(inSheet: true)` a essas folhas.

2. **A mesma ação destrutiva tem duas confirmações diferentes.** Apagar todos os dados: `CueActionSheet` em Settings (`Screens/Settings/Support/DataEraseConfirmation.swift:15`: "Deletes your scripts, takes, edits and My Cue Voice from this iPhone. This can't be undone." · **Delete my Cue data**) e `.alert` nativo na folha Privacy (`Screens/Shared/Privacy/PrivacySheet.swift:58`: "Delete all your Cue data?" · "Your scripts, takes, edits and My Cue Voice are removed from this iPhone. This can't be undone." · **Delete everything**). §17 diz que o `CueActionSheet` é o padrão para isso.

3. **Traduções erradas ou que trocam o sentido.** "Code %@" → **"Cupom %@"** no pareamento do remoto (`Screens/Shared/RemoteControl/RemotePairingPanel.swift:61`; deveria ser "Código %@"). "Pause" como **tipo** de sugestão do Clean up (`Models/CleanUpKind.swift:20`) divide a chave com o botão e sai **"Pausar"** (verbo; deveria ser "Pausa"). "Purchase" como título do alerta de erro de compra → **"Comprar"** (`Screens/Shared/Paywall/ProPlansScreen.swift:60`). "Back to your setup" (toast, `Screens/Prompter/PrompterViewModel+Setup.swift:34`) → "Voltar à sua configuração", lido como ordem, não como confirmação ("De volta à sua configuração"); o mesmo vale para "Back to the top" → "Voltar ao início" (toast em `PrompterViewModel.swift:476`, mesma chave do botão em `SelfieControlParts.swift:24`). "Done" como resultado de ferramenta (`Screens/ScriptDetail/ScriptDetailViewModel.swift:424`) divide a chave com o botão e sairia "Concluir" (ramo provavelmente inalcançável: hooks, aviso e tradução têm toasts próprios). Gênero de Apple Intelligence: 19 traduções usam "a Apple Intelligence" e 5 "o Apple Intelligence" (ex.: `Screens/Shared/Ultra/UltraConsentSheet.swift:50`, "O Apple Intelligence continua funcionando").

4. **Toasts longos demais para duas linhas e 2,4 s.** `TakeReviewViewModel.announce` (`Screens/TakeReview/TakeReviewViewModel.swift:682`) junta o resultado + a cota + o motivo das legendas: "Saved to Photos · 2 of 3 free exports left · Couldn’t listen to this take, so the video has no captions." (~100 caracteres). `ToastView` corta em 2 linhas com 85% de encolhimento (`DesignSystem/Components/ToastView.swift:28-29`) e some em 2,4 s. O mesmo risco em "Opened Instagram with your video · Cue can’t see if you post it · 2 of 3 free exports left" (:695) e nas notas de reescrita ("Shorter · 132 → 53 words · 2 of 5 parts left as written", `RewriteNotice.swift:36-41`), em português ainda mais longas. A informação de legendas faltando merece outro lugar (cartão na revisão).

5. **"· Try again" sem botão de tentar de novo.** Muitos toasts ! terminam pedindo para tentar de novo, mas não trazem `ToastAction`: "Couldn't export · Try again" (`TakeReviewViewModel.swift:346`), "iOS stopped the export · Try again" (:341), "Couldn’t share · Try again" (:612), "Couldn’t draft it · Try again" (`ScriptDetailViewModel+Page.swift:428`, `RewriteNotice.swift:71`), "Ultra AI needs the internet · Try again" e os outros de `Managers/ScriptAI/Ultra/UltraError.swift:35-39`, "Wrong code · Try again" (`RemoteJoinFlow.swift:45`), "Couldn't sign in · Try again", "Couldn't save · Try again", "Couldn’t set the reminder · Try again" (`ReminderFeedback.swift:27`), "Couldn't record the voice-over · Try again" (`VoiceOverError.swift:16`). O botão Undo já existe no sistema; um **Try again** no toast (4 s) fecharia o ciclo.

6. **O mesmo evento em estilos diferentes.** Falha de rascunho da IA: **alerta** "Couldn't draft the script" com Try again no primeiro rascunho (`ScriptDetailView.swift:63`) e **toast** "Couldn’t draft it · Try again" (sem botão) nas ferramentas. Falha de importação: **alerta** "Couldn't import" (`ImportScriptSheet.swift:112`), **toast** "Can't add this file" no editor (`EditMediaImportError.swift:14`), **texto inline** em Import my writing (`WritingImportCollectView.swift:50`). Compra: erro em **alerta** "Purchase", restaurar em **toast**. Desfazer: a página do roteiro mostra o toast "Undone" (`ScriptDetailViewModel.swift:284`), o editor só anuncia ao VoiceOver (`QuickEditViewModel.swift:487`). Permissão negada: cartão com **Open Settings** na revisão (`PhotosDeniedCard`), fundo de câmera com botão no gravador, mas toast sem botão "Mic is off for Cue" no editor (`AudioViewModel+VoiceOver.swift:35`; o `ReminderFeedback` tem **Settings** no toast).

7. **Mensagens que não dizem o que fazer.** "The take couldn't be saved" (`PrompterViewModel.swift:685,700`) — sem motivo (espaço?) nem saída; "The camera isn't ready" (:553); "Couldn't start listening" (`SpeechUnavailableReason.swift:39`); "This video couldn’t be read" (`MotionAnalysisNote.swift:35`); "Couldn't draw the cover" (`CoverError.swift:13`); "Can't add this file" (`EditMediaImportError.swift:14`, não diz quais formatos servem); "Ultra AI isn’t set up on this iPhone" (`UltraError.swift:30`). Também: `RewriteNotice.nothingChanged` cai em "Couldn’t draft it · Try again" (`RewriteNotice.swift:71`) quando o modelo devolveu o mesmo texto, não quando falhou.

8. **Copy que promete o que o produto não tem.** "Try Pro ›" → "Testar o Pro ›" no cartão do plano (`Screens/Profile/Sections/ProfilePlanCard.swift:28`), com a decisão de 30/10 de **não** haver teste grátis (§11, §12). A lista de benefícios do Pro (`PaywallCopy.swift:41-45`: Apple Watch, iPad & Mac sync, ad drafts…) já foi apontada como não verdadeira (memória `pro-benefits-not-true`).

9. **Ações sem nenhum retorno.** **Disconnect** do remoto (`Screens/Settings/Rows/RemoteEntryRow.swift:71`, `RemotePairingPanel.swift:96`): sem confirmação e sem toast. Remover lembrete (deslizar em `NotificationsSettingsView.swift:213`, ✕ em `ReminderSheet.swift:136`): some sem Undo. **Remove Photo** do perfil (`EditProfilePhoto.swift:106`). **Rename** na biblioteca (`MediaLibrarySection.swift:82`) e criar cue (`ScriptPageView.swift:138`) não confirmam. Parar a gravação pelo botão não diz nada (a revisão abre, `PrompterViewModel.swift:657`) — coerente, mas a contagem cancelada também é silenciosa.

10. **Um toast por vez: substituição silenciosa.** `ToastService.show` troca o toast na hora (`Managers/ToastService.swift:39-55`): um toast com "Undo" (4 s) some assim que outro chega. Há proteções pontuais (`sayAfterSheet` espera 0,35 s, `LookViewModel+CopyLook.swift:59`; `VoyageAnnouncer` espera não haver toast, `VoyageAnnouncer.swift:30`), mas nenhuma fila. Onde o Undo do toast é o único desfazer (reescrita na página, `ScriptDetailViewModel.swift:277`; apagar roteiro/ideia, `ScriptsViewModel.swift:85`, `LogbookView.swift:560`; biblioteca, kits e fontes, `BrandViewModel+Library.swift:123`, `BrandViewModel+Kits.swift:231`, `BrandViewModel+Fonts.swift:33`), o próximo toast leva o Undo embora. No editor o desfazer continua na barra. Não há pilha visual — mas há perda.

11. **Terminologia e tom.** "Fits" tem três traduções: "Ideal para %@" (`ReviewInfoPanel.swift:116`), "✓ Cabe em %@" (`LengthFit.swift:34`), "✓ Cabe no %1$@" (`PickBestTakeView.swift:224`), e "FITS" → "IDEAL" (`ShareNetworkLine.swift:18`). "Mic" vs "Microphone" ("Mic is off for Cue" × "The microphone is off for Cue" × "Microphone off"). "off" → "desligado" e "desativado" alternados ("Photos is off for Cue" → "desativado"; "Notifications are off" → "desligadas"; "Camera access is off" → "desligado"). "Saved" em seis formas para o mesmo tipo de evento ("Saved · post when you’re ready", "Saved · continue anytime", "Saved in Takes · export with Pro anytime", "Saved · Cue learns from it", "Saved · Cue schedules it closer to the time", "Saved to Logbook"). Apóstrofo reto e curvo misturados nas chaves (125 com ' reto, 166 com ’ curvo), o que já duplicou mensagens: "Couldn't listen to this take" (`PausesPanel.swift:55`, `ClipsViewModel+CleanUp.swift:67`) e "Couldn’t listen to this take." (`CaptionState.swift:43`).

12. **Tipografia fora do sistema nos avisos do editor.** `PanelNote` (72 notas, `Screens/QuickEdit/Panels/Controls/PanelNote.swift`) e o vazio da biblioteca (`MediaLibrarySection.swift:165`) usam `.font(.system(...))` em vez de `cueFont`, enquanto o resto dos avisos usa `cueFont` (proporção de tela de `ScreenProportion`).

13. **Traduções e copy morta.** Todas as 4.247 chaves têm `pt` traduzido; o único texto de interface sem chave é de preview (`StopWarningCard.swift:48`) e o diagnóstico de notificações, que é só Debug (`NotificationDiagnosticsSection.swift:34`). 49 chaves não aparecem literalmente no código; quase todas são pedaços de modelo (`ScriptType+Brief.swift`) ou formatos, mas "Up next", "Remove %lld", "Removed %@", "Removed %lld", "%lld deleted", "%@ OVER", "%@ UNDER", "IDEAL" e "%@/mo" parecem órfãs — conferir com `scripts/strings.py stale`.

14. **Duas cores para o mesmo "feito".** Ações que o criador fez e que dão certo saem ✓ (padrão), mas algumas confirmações de escolha do criador saem ★ (Cue decidiu) e vice-versa: "Learned from this script" é ★ (`VoicePreviewSheet.swift:170`), "Saved · Cue learns from it" é ✓ (`ScriptDetailViewModel+VoicePreview.swift:55`); "Cue Voice complete" ✓ (`VoiceQuestionSheetModel.swift:196`). O tipo é escolhido em cada chamada, sem regra no código além do comentário de `ToastKind`.

### Contagens

- Toasts: 398 chamadas (§1). Alertas/diálogos: 14 `.alert`, 7 `.confirmationDialog`, 2 `CueActionSheet` (§2). Notas de painel do editor: 78. Linhas de aviso/banners/estados (§3): 354. Erros (§4): 84. Estados vazios (§5): 35 + 27 placeholders. Progresso (§6): 80. Gravação/remoto/relógio (§7): 127. Pro e limites (§8): 71. Anúncios de acessibilidade além dos toasts (§9): 8.