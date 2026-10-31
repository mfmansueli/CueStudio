# Cue Studio — sistema de comunicação proativo (inventário)

Inventário só de leitura, 30/10/2026, de `main` (1f62fb24). Cobre o lado **proativo/guia**: notificações locais, convites e introduções, TipKit,
primeira viagem, onboarding, celebrações e o resto (atalhos, Watch, selos). O lado reativo (toasts, alertas, erros, vazios, progresso) está noutro inventário.
Nada foi compilado, rodado ou medido: contraste e aparência descritos a partir do código e dos tokens.

Convenções: caminhos relativos a `Cue Studio/` salvo indicação; inglês = chave do String Catalog; PT-BR = localização `pt` de
`SupportFiles/Localizable.xcstrings` (o app só tem esse português); "19/19" = traduzido em todos os idiomas. O app é só escuro.

Índice: 1. Notificações locais · 2. Folhas e cartões que convidam · 3. TipKit · 4. Primeira viagem · 5. Onboarding · 6. Celebrações e marcos ·
7. Outros proativos · Observações (consolidado no fim; cada seção tem as suas).

## 1. Notificações locais (UserNotifications)

Fonte de verdade de produto: `NOTIFICATIONS.md` e `DESIGN_PROJECT.md` §27. Tudo abaixo foi conferido no código (as divergências estão marcadas ⚠ e
repetidas em Observações). Todos os textos existem nos 19 idiomas do catálogo (`pt` = português do Brasil, único português do app).

### 1.0 Regras gerais (valem para todas)

| Regra | Valor no código | Onde |
|---|---|---|
| Só notificações locais; pedido ao iOS só com `[.alert, .sound]` (sem `.badge`, sem `.provisional`) | — | `Managers/Notifications/Center/SystemNotificationCenter.swift:24-26` |
| Nenhuma ação/botão na notificação: não há `UNNotificationCategory`, nem `categoryIdentifier`; só o toque padrão abre algo; dispensar não é informado | — | `Center/NotificationCenterDelegate.swift:22-26`, `SystemNotificationCenter.swift:28-45` |
| Agrupamento na Central: `threadIdentifier = "cue.<categoria>"` (reminders, projects, routine, discovery, whatsNew) | — | `Models/Notifications/NotificationCategory.swift` (`threadIdentifier`), `SystemNotificationCenter.swift:32` |
| Som / nível: Tools and news (`discovery`, `whatsNew`) chegam `.passive` sem som; o resto `.active` com som padrão | — | `Models/Notifications/LocalNotificationRequest.swift:26`, `SystemNotificationCenter.swift:34-35` |
| Sem badge no ícone do app | — | (nenhum `setBadgeCount`/`.badge` no app) |
| Títulos de projeto nunca entram (`showsTitles` sempre `false`, sem ajuste que o ligue) | `NotificationState.showsTitles = false` | `Models/Notifications/NotificationState.swift:29`, `Managers/Notifications/NotificationCopy.swift:8-10` |
| Quiet hours fixas 21:00–09:00 (só para automáticas; lembretes e rotina tocam mesmo dentro) | `QuietHours.standard` | `Models/Notifications/QuietHours.swift:15` |
| 1 automática em 24 h; 2 em 7 dias (todas as categorias automáticas somadas) | `dailyCap 1`, `weeklyCap 2` | `Planning/NotificationPolicy.swift:13-17` |
| 1 ferramenta/ideia em 7 dias; nunca no dia de uma dica do My Cue Voice | `discoveryWeeklyCap 1` | `NotificationPolicy.swift:19`, `NotificationPlanner.swift:117-129` |
| A mesma ferramenta no máx. 2× em 90 dias, 30 dias entre elas; nunca depois de usada; "Not now" = 30 dias; "Don’t suggest this" = para sempre | `featureCap 2`, `featureWindow 90d`, `featureCooldown 30d` | `NotificationPolicy.swift:21-23`, `NotificationService+Discovery.swift:86-100` |
| Nada automático a menos de 12 h de um lembrete ou da rotina | `userTimeExclusion 12h` | `NotificationPolicy.swift:25`, `NotificationPlanner.swift:89-90` |
| Nada automático antes de 15 min do planejamento; horizonte de 23 dias | `minimumLead`, `horizon` | `NotificationPolicy.swift:43-45` |
| Volta após inatividade (7 e 21 dias) substitui todas as outras automáticas a partir da 1ª tentativa | `returnAttempts`, `.replacedByReturn` | `NotificationPolicy.swift:39`, `NotificationPlanner.swift:69-71` |
| Capacidade: 32 pendentes = 7 rotina + 4 automáticas + 21 lembretes | `maxPending 32` | `NotificationPolicy.swift:50-56` |
| Prioridade (1 primeiro): reminder 1 · exportReady 2 · incompleteSharing 3 · projetos/savedIdea/return 4 · routine 5 · feature/availableIdea 6 · whatsNew/yearInReview 7 | — | `Models/Notifications/NotificationCampaign.swift` (`priority`) |
| Um passo por projeto (script + takes = 1 projeto; vale o mais adiantado: fila > takes > pronto > rascunho) | `.sameProject` | `Planning/ProjectCampaigns.swift:34-59`, `NotificationPlanner.swift:35-38` |
| Planejamento: ao ficar ativo, ao ir para o fundo e quando muda scripts, takes, filas, Logbook, conta, idioma, fuso (debounce 400 ms) | — | `Screens/Main/Support/NotificationTriggers.swift:20-47`, `NotificationService.swift:95-116` |
| Motivos de supressão medidos (nunca mostrados): categoryOff, notAuthorized, paused, quietHours, dailyCap, weeklyCap, discoveryWeeklyCap, featureCap, featureCooldown, nearUserReminder, voiceTipSameDay, replacedByReturn, sameProject, capacity, beyondHorizon, notInterested, snoozed, adopted, unavailable, foregroundBusy | — | `Models/Notifications/SuppressionReason.swift` |
| Com `.notDetermined` nada é agendado; o Cue pede ao iOS só ao criar lembrete, ligar categoria/rotina, ligar o interruptor ou dizer sim ao convite; recusado, nunca pede de novo | — | `NotificationService.swift:84-90`, `+Plan.swift:17` |
| **Em primeiro plano** (`willPresent`): objeto apagado → `.hidden`; ocupado (prompter/gravação/editor/exportação/remoto/transição da estrela) → `.listOnly` silencioso, e ferramenta → `.hidden` + vira introdução depois (`deferredIntro`); fora disso discovery/whatsNew → `.listOnly`, o resto → banner + lista + som | — | `NotificationService+Opening.swift:68-79`, `NotificationCenterDelegate.swift:39-54`, ocupado: `SupportFiles/AppServices.swift:381-383` |
| **Toque**: espera onboarding, prompter (que contém revisão e editor) e controle remoto fecharem; cada entrega só uma vez (memória de 50); payload validado (prefixo `cue.`); abre o destino checado de novo (`NotificationNavigator`); feature abre primeiro a `FeatureIntroSheet` | — | `Screens/Main/RootView.swift:114-135`, `NotificationService+Opening.swift:19-47` |
| Atribuição 24 h após abrir (feature_completed / next_action_completed) | `AttributionContext` | `NotificationService+Reconcile.swift:85-100` |
| "Delete my Cue data" apaga pendentes, entregues, lembretes, rotina, histórico; mantém consentimento, quiet hours, "não sugerir" e as datas do convite | — | `NotificationService.swift:122-137` |

**Ver tudo de uma vez (Debug, aparelho):** Settings › Notifications › DEBUG › **Preview every notification** (`NotificationService+DebugPreview.swift:13-41`): uma de
cada tipo, 5 s depois e a cada 6 s, com os textos reais (ignora limites e consentimento). Em UI test: `-uiTestInMemory -uiTestSeedSamples
-uiTestNotificationAuth authorized` + `-uiTestNotificationTap <script|cleanUp|share|deletedScript|invalid|duplicate|routine|logbook|universe>`
(`SupportFiles/Debug/DebugNotificationTaps.swift:24-47`).

### 1.1 Notificações que o criador marca (fora dos limites)

| ID / campanha | Identificador do sistema | Gatilho e condições | Frequência / limites | EN (título / corpo) | PT-BR (título / corpo) | Toque → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| `reminder` (script) | `cue.reminder.<uuid>` | Página do script › ••• › **Remind me…** › Tonight 20:00 (oferecido até 19:30) / Tomorrow 10:00 / data e hora | 1 por pedido; tocam na hora escolhida, mesmo em quiet hours; até 21 agendados, o resto "Kept in Cue"; vencido fica 7 dias como "Due" | "Your script is waiting" / "Open it to keep going. Record it when you’re ready." (variante com título "%@ is waiting" nunca usada) | "Seu roteiro está esperando" / "Abra para continuar. Grave quando estiver pronto." | página do script (`.script`) | `NotificationCopy.swift:92-96`; `ReminderSheet.swift`; `ScriptPageMenu.swift:24`; `ScriptDetailView.swift:95-98` | `-uiTestNotificationTap script` |
| `reminder` (take) | `cue.reminder.<uuid>` | Takes › menu do vídeo › **Remind me…** | idem | "Your recording is waiting" / "Pick up the edit, or share it when you’re ready." | "Sua gravação está esperando" / "Retome a edição ou compartilhe quando estiver pronto." | revisão da take (`.takeReview`) | `NotificationCopy.swift:97-101`; `TakesView.swift:113, 298` | — |
| `reminder` (Post later) | `cue.reminder.<uuid>` | Fila "Share to universe" › **Post later** (menu: Tonight · hora / Tomorrow · hora / Pick a date and time… / No reminder) | idem; cancelado sozinho quando a rede é postada ou a fila termina | "Ready to post on %@" / "Your video is saved in Cue. Open it to continue sharing." | "Pronto para postar no %@" / "Seu vídeo está salvo no Cue. Abra para continuar compartilhando." | passo daquela rede na fila (`.shareQueue(take, rede)` → `.postLater(rede)`) | `NotificationCopy.swift:102-107`; `ShareQueueStep.swift:54-91` | `-uiTestNotificationTap share`, `-uiTestShareQueue` |
| `routine` | `cue.routine.<1…7>` (1 = domingo) | Settings › Notifications › **Remind me to create** (dias + hora); ou ligado sozinho com Seg/Qua/Sex 18:00 quando o iOS diz sim pelo interruptor da página | semanal, repetida por dia escolhido; fora dos limites; automáticas ficam a ±12 h | "Your creation time" / "Your next video starts here. Cue opens on the step that’s next." | "Sua hora de criar" / "Seu próximo vídeo começa aqui. O Cue abre no próximo passo." | `.nextAction`: o projeto mais adiantado na hora do toque, senão "+" (New script) | `NotificationCopy.swift:111-116`; `+Reconcile.swift:141-150`; `+Opening.swift:50-55`; `CreationRoutine.swift:16` | `-uiTestNotificationTap routine` |

### 1.2 Operação terminada

| ID | Identificador | Gatilho | Limites | EN | PT-BR | Destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| `exportReady` | `cue.done.export.<take>` | Exportação terminou com o app fora da tela, "Help me finish what I start" ligado e iOS permitindo; gatilho de 1 s | nenhum (não é automática); nunca com o app na tela | "Your video is ready" / "It’s saved to Photos. Open Cue to share it." (sem Fotos: "Open Cue to share it.") | "Seu vídeo está pronto" / "Está salvo em Fotos. Abra o Cue para compartilhar." (sem Fotos: "Abra o Cue para compartilhar.") | revisão da take | `NotificationCopy.swift:118-125`; `+Opening.swift:86-101`; chamada em `TakeReviewView.swift:97` | só no aparelho (sair do app exportando) |

### 1.3 Automáticas de projeto (categoria `projects` = interruptor "Help me finish what I start", ligado por padrão)

Todas: sob quiet hours, 1/dia, 2/semana, ±12 h de lembrete/rotina, um passo por projeto; esperas contadas da última mudança do projeto e nunca de antes de
`startedAt` (primeira execução deste sistema). Identificador `cue.auto.<campanha>.-.<projectKey>`.

| Campanha | Gatilho e condições (estado real) | Espera | EN (título / corpo) | PT-BR | Destino | Código |
|---|---|---|---|---|---|---|
| `firstRecording` | O script READY mais antigo e **nenhuma take no app** | 48 h após `updatedAt` | "Your first script is ready" / "Try recording it with the teleprompter. Your first star is one take away." | "Seu primeiro roteiro está pronto" / "Experimente gravar com o teleprompter. Sua primeira estrela está a um take." | página do script (Record no pé; nada liga a câmera) | `ProjectCampaigns.swift:16, 41-48`; `NotificationCopy.swift:51-55` |
| `readyToRecord` | Script READY sem take (o criador já gravou antes) | 48 h | "Turn your script into a video" / "Your next recording is one tap away." | "Transforme seu roteiro em vídeo" / "Sua próxima gravação está a um toque." | página do script | `ProjectCampaigns.swift:42-48`; `NotificationCopy.swift:61-66` |
| `unfinishedScript` | Rascunho com ≥ 8 palavras | 72 h após `updatedAt` | "Your idea has already started" / "Continue where you left off." | "Sua ideia já começou" / "Continue de onde parou." | página do script editando (`.scriptEditor`) | `ProjectCampaigns.swift:49-55`; `NotificationCopy.swift:56-60` |
| `recordingToFinish` | Take(s) com estágio ≠ shared e nada exportado | 48 h após a gravação | "Your recording is saved" / "Continue editing whenever you’re ready." | "Sua gravação está salva" / "Continue editando quando quiser." | estágio edit → Quick edit; senão revisão | `ProjectCampaigns.swift:84-95`; `NotificationCopy.swift:67-71` |
| `incompleteSharing` (prior. 3) | Fila "Share to universe" com redes pendentes/later | 24 h após `ShareQueue.updatedAt` | "Next stop: %@" (rede) / "Continue sharing your video on the networks you selected." (sem rede: título "Continue sharing your video") | "Próxima parada: %@" / "Continue compartilhando seu vídeo nas redes que você escolheu." ("Continue compartilhando seu vídeo") | próximo passo da fila (`.continueQueue`); fila já terminada → revisão + toast "Already shared on the networks you chose" | `ProjectCampaigns.swift:69-81`; `NotificationCopy.swift:72-76`; `NotificationNavigator.swift:106-118` |
| `savedIdea` | A nota mais antiga do Logbook ainda esperando | 7 dias após a nota (e ≥ 24 h após `startedAt`) | "An idea is waiting in your Logbook" / "One of your ideas is waiting to become a video. Want to develop it?" | "Uma ideia está esperando no seu Diário de bordo" / "Uma das suas ideias está esperando para virar vídeo. Quer desenvolvê-la?" | Logbook com a nota em destaque | `ProjectCampaigns.swift:98-105`; `NotificationCopy.swift:77-81`; `NotificationNavigator.swift:63-66` |
| `returnAfterInactivity` (2 tentativas) | Sempre planejada: 7 e 21 dias após a última atividade (`lastActivity` = última vez que o app ficou ativo); usa o texto/destino do melhor projeto real, senão o "entryPoint" | 7 d e 21 d; a partir da 1ª, nenhuma outra automática | do projeto, ou "Ready for your next video?" / "Start from an idea, a format or a blank page. Your universe has room for one more star." | "Pronto para o próximo vídeo?" / "Comece com uma ideia, um formato ou uma página em branco. Seu universo tem espaço para mais uma estrela." | destino do projeto, ou "+" (New script) | `ProjectCampaigns.swift:112-122`; `NotificationCopy.swift:18-22, 82-83`; `+Plan.swift:19-23` |

Launch arg (todas acima): Settings › Notifications › DEBUG › Preview every notification; em UI test `-uiTestNotificationTap script|logbook`. As
variantes com título entre aspas (`"%@ has already started"`, `"%@ is ready. Your next recording is one tap away."`, `"%@ is waiting"`, `"%@ is saved in Cue…"`)
estão traduzidas mas **nunca aparecem** (ver Observações).

### 1.4 Descoberta (categoria `discovery` = metade do interruptor "Tools and news", **desligado por padrão**)

Chegam `.passive` (sem som, sem acender a tela). Espera: 24 h após a última atividade. O plano oferece as 3 primeiras ferramentas que cabem (ordem: menos
mostradas primeiro, depois a ordem do catálogo) + uma ideia; o planejador coloca no máximo 1 por semana. Identificador
`cue.auto.feature.<ferramenta>.discover.<projectKey>`. **O toque nunca abre a ferramenta direto: abre a `FeatureIntroSheet` (§2.2).** Uso de verdade
(`FeatureAdoption.swift`) para de oferecer. Ícone = SF Symbol da introdução. `campaignID` = `discover.<id>.v1`.

| FeatureID | Requisitos | Alvo / destino do "Try it" | Para de oferecer quando | Notificação EN (título / corpo) | Notificação PT-BR | Ícone | Nota da intro | Código |
|---|---|---|---|---|---|---|---|---|
| `myCueVoice` | Apple Intelligence; ≥ 2 scripts; voz sem resposta | `VoiceSetupSheet` (4 perguntas); sem IA → Scripts + toast com o motivo | voz configurada | "Want scripts that sound more like you?" / "Four quick questions. Cue's drafts start closer to you." | "Quer roteiros com mais a sua cara?" / "Quatro perguntas rápidas. Os rascunhos do Cue começam mais perto de você." | `sparkle` | appleIntelligence | `FeatureCatalog.swift:15-19`; `FeatureID+Copy.swift:14, 36` |
| `importWriting` | Apple Intelligence; voz configurada; nada importado | `WritingImportSheet` | algo importado | "Show Cue something you wrote" / "Refine your writing style from texts you wrote. It stays on this iPhone." | "Mostre ao Cue algo que você escreveu" / "Refine seu estilo de escrita a partir de textos seus. Tudo fica neste iPhone." | `doc.text` | appleIntelligence | `FeatureCatalog.swift:20-24`; `+Copy.swift:15, 37` |
| `ideas` | Apple Intelligence; tem temas | Find inspiration | uma ideia usada (`recordUse(.ideas)` em `FindInspirationSheet.swift:530, 542`, `ScriptsDock.swift:818`) | "Not sure what to record?" / "Explore ideas for your topics." | "Sem ideia do que gravar?" / "Explore ideias para os seus temas." | `CueIcon.findInspiration` | appleIntelligence | `FeatureCatalog.swift:25-28`; `+Copy.swift:16, 38` |
| `logbook` | ≥ 1 script | Logbook | qualquer nota já anotada | "Save an idea before it disappears" / "Catch it in the Logbook now. Develop it later." | "Salve uma ideia antes que ela escape" / "Anote agora no Diário de bordo. Desenvolva depois." | `book.closed` | nothingChanges | `FeatureCatalog.swift:29-32`; `+Copy.swift:17, 39` |
| `voiceFollowing` | prompter em Steady; script READY sem take num idioma que o iPhone ouve | página do script (`.voiceFollowing(scriptID:)` = só `openScript`) | prompter guardado em Voice | "Read at your own pace" / "The teleprompter can follow your voice." | "Leia no seu ritmo" / "O teleprompter pode seguir a sua voz." | `waveform` | speechModel | `FeatureCatalog.swift:33-36`; `+Copy.swift:18, 40`; `DiscoveryRules.swift:84-90`; `NotificationNavigator.swift:41-43` |
| `cleanUp` | gravou; take ≥ 10 s, não analisada, idioma ouvido | Quick edit › Pauses | uma sugestão decidida | "Review pauses and repetitions" / "Without finding every section by hand. You choose what stays." | "Revise pausas e repetições" / "Sem caçar cada trecho na mão. Você escolhe o que fica." | `scissors` | speechModel | `FeatureCatalog.swift:37-40`; `+Copy.swift:19, 41` |
| `autoCaptions` | take sem legendas, idioma ouvido | Quick edit › Auto captions | legendas na edição | "Captions for watching without sound" / "Give your audience a way to follow your video without sound." | "Legendas para assistir sem som" / "Dê ao seu público um jeito de acompanhar o vídeo sem som." | `captions.bubble` | speechModel | `FeatureCatalog.swift:41-44`; `+Copy.swift:20, 42` |
| `captionTranslation` | take com legendas; par de tradução existe | Captions + folha de tradução | uma tradução salva | "Captions in another language" / "Try presenting your video with captions in another language." | "Legendas em outro idioma" / "Experimente apresentar seu vídeo com legendas em outro idioma." | `character.bubble` | translationDownload | `FeatureCatalog.swift:45-49`; `+Copy.swift:21, 43` |
| `studioVoice` | take ≥ 3 s | Quick edit › Studio Voice | nível ≠ padrão | "Explore a clearer sound for your voice" / "Studio Voice works on your recording. You hear it before you keep it." | "Experimente um som mais claro para a sua voz" / "A Voz de estúdio trabalha na sua gravação. Você ouve antes de manter." | `waveform.and.mic` | nothingChanges | `FeatureCatalog.swift:50-53`; `+Copy.swift:22, 44` |
| `covers` | take não exportada | Quick edit › Cover | capa escolhida | "Choose the first image of your video" / "Pick the cover that introduces your video." | "Escolha a primeira imagem do seu vídeo" / "Escolha a capa que apresenta o seu vídeo." | `photo.artframe` | nothingChanges | `FeatureCatalog.swift:54-57`; `+Copy.swift:25, 51` |
| `layers` | ≥ 1 vídeo exportado **e** uma take não exportada | Quick edit › mídia | uma mídia sobre a take | "Show examples while you speak" / "Add images to your video while you talk about them." | "Mostre exemplos enquanto fala" / "Adicione imagens ao vídeo enquanto fala delas." | `photo.badge.plus` | nothingChanges | `FeatureCatalog.swift:58-61`; `+Copy.swift:26, 52` |
| `voiceOver` | idem | Quick edit › Voice-over | um voice-over | "Add a voice-over" / "Narrate over your edit. Cue explains it before you record." | "Adicione uma narração" / "Narre por cima da sua edição. O Cue explica antes de você gravar." | `mic` | nothingChanges | `FeatureCatalog.swift:62-65`; `+Copy.swift:27, 53` |
| `backgrounds` | gravou; segmentação de pessoa roda | Quick edit › Background | um fundo | "Want a different setting?" / "Explore your editor’s backgrounds." | "Quer outro cenário?" / "Explore os fundos do editor." | `person.and.background.dotted` | nothingChanges | `FeatureCatalog.swift:66-69`; `+Copy.swift:24, 50` |
| `skinSmoothing` | ≥ 1 vídeo exportado e take não exportada | Quick edit › Skin (abre em Smooth) | qualquer controle > 0 | "Try a subtle finish" / "Smooth the skin, light the face or take off shine, in Skin. Each starts at zero." | "Experimente um acabamento sutil" / "Suavize a pele, ilumine o rosto ou tire o brilho, em Pele. Tudo começa do zero." | `face.smiling` | nothingChanges | `FeatureCatalog.swift:70-73`; `+Copy.swift:23, 45-49` |
| `safeZones` | gravou; vídeo ou script para TikTok/Reels/Shorts/Stories | Settings › Prompter › Social safe zone | zona ligada | "Keep your words clear of the buttons" / "Check that your captions stay clear of the network’s buttons." | "Mantenha suas palavras longe dos botões" / "Confira se suas legendas ficam longe dos botões da rede." | `rectangle.dashed` | nothingChanges | `FeatureCatalog.swift:74-77`; `+Copy.swift:29, 55` |
| `remoteControl` | gravou — **só no app** (nunca notificação), só depois de sair do teleprompter | Settings › Remote | um controle conectado (`NotificationTriggers.swift:39-41`) | (título/corpo existem mas não são enviados) "Record from a distance" / "Control the teleprompter from your other iPhone or iPad." | "Grave a distância" / "Controle o teleprompter pelo seu outro iPhone ou iPad." | `iphone.radiowaves.left.and.right` | secondDevice | `FeatureCatalog.swift:78-82`; `+Copy.swift:28, 54` |
| `yourUniverse` | ≥ 3 vídeos compartilhados | Profile › Your universe | visita (`YourUniverseView.swift:87`) | "See how your videos are shaping your universe" / "Every video you share becomes a star in it." | "Veja como seus vídeos estão formando o seu universo" / "Cada vídeo que você compartilha vira uma estrela nele." | `sparkles` | nothingChanges | `FeatureCatalog.swift:83-86`; `+Copy.swift:30, 56` |

| Outra de descoberta | Gatilho | Limites | EN | PT-BR | Destino | Código |
|---|---|---|---|---|---|---|
| `availableIdea` | Uma ideia do modelo guardada e ainda não vista (`IdeaSuggestionService.unseenModelIdeas`) | 24 h após a última atividade; conta no 1/semana de descoberta | "An idea for your next video" / "A starting point for your topics is waiting." (a versão com tema "Explore an idea for your next video about %@." exige `showsTitles` e nunca aparece) | "Uma ideia para o seu próximo vídeo" / "Um ponto de partida para os seus temas está esperando." | a ideia entra no campo do dock (nada é escrito); sumiu → toast "That idea isn’t here any more · try ↻ for another" | `+Plan.swift:71-76`; `NotificationCopy.swift:23-33`; `NotificationNavigator.swift:121-136` |

Launch arg: `-uiTestNotificationTap cleanUp` (abre a introdução de Clean Up na take de exemplo). Para planejar de verdade num teste é preciso ligar
"Tools and news" (está desligado por padrão).

### 1.5 Novidades (categoria `whatsNew` = outra metade de "Tools and news", desligada por padrão)

| Campanha | Gatilho | Limites | EN | PT-BR | Destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|
| `yearInReview` | Year in Review pronto (regras do universo: linha de retrospectiva desbloqueada, 3+ vídeos, a partir de 1º/dez), uma vez por ano | imediata, mas conta nos limites diário/semanal e quiet hours; passiva | "Your year in review is ready" / "See the videos that shaped your universe this year." | "Sua retrospectiva do ano está pronta" / "Veja os vídeos que formaram o seu universo este ano." | Profile › Your universe com a história do ano | `+Plan.swift:83-88`; `NotificationCopy.swift:36-40`; `AppServices.swift:362-369` | `-uiTestNotificationTap universe`; `-uiTestUniverse sample` |
| `whatsNew` | Uma entrada de `WhatsNewCatalog` da versão instalada, só para quem **atualizou** | 24 h; passiva | "New in Cue" / "A new tool arrived with this version. Open Cue to see it." | "Novo no Cue" / "Uma ferramenta nova chegou com esta versão. Abra o Cue para ver." | o destino da entrada | `WhatsNewCatalog.swift:20` (**`all = []`**); `NotificationCopy.swift:41-45` | só pelo Preview (Debug) |

### 1.6 Outros textos que o sistema de notificações mostra ao abrir

| Situação | EN | PT-BR | Código |
|---|---|---|---|
| Script apagado | "That script is no longer in Cue" (toast 5 s, Scripts) | "Esse roteiro não está mais no Cue" | `NotificationNavigator.swift:42, 45, 164-168` |
| Take apagada | "That recording is no longer in Cue" (Takes) | "Essa gravação não está mais no Cue" | `NotificationNavigator.swift:170-173` |
| Fila já terminada | "Already shared on the networks you chose" | "Já compartilhado nas redes que você escolheu" | `NotificationNavigator.swift:110` |
| Ideia sumiu | "That idea isn’t here any more · try ↻ for another" | "Essa ideia não está mais aqui · toque em ↻ para outra" | `NotificationNavigator.swift:125` |
| Sem Apple Intelligence (Ideas, My Cue Voice, Import) | o motivo real do escritor, senão "Apple Intelligence isn’t available on this iPhone right now" | "A Apple Intelligence não está disponível neste iPhone agora" | `NotificationNavigator.swift:139-147` |

---

## 2. Folhas e cartões que convidam ou apresentam

### 2.1 `NotificationInviteSheet` — convite antes da pergunta do iOS

| Item | Valor |
|---|---|
| Visual | folha ajustada ao conteúdo (`fittedSheet`), sem barra de título, X nativo |
| Onde / gatilho | `.firstRecording`: ao **fechar o prompter** (gravador/revisão/editor) com ≥ 1 take, em `MainView.offerIntroduction` (`MainView.swift:66-69, 340-352`). `.readyScript`: ao **sair da página** de um script pronto sem take (`ScriptDetailView.swift:62, 104-112`) |
| Condições | `invitesEnabled` (UI tests só com `-uiTestNotificationInvite`); não ocupado; nenhuma introdução nesta sessão; < 2 convites na vida do app; ≥ 14 dias desde o anterior; nenhuma ferramenta apresentada hoje; não é dia de dica do My Cue Voice; iOS ainda `.notDetermined`. 1º só se nunca houve convite; 2º só se já houve exatamente 1 (`NotificationService+Invite.swift:17-31`) |
| Frequência | no máximo 2 vezes na vida (sobrevive a "Delete my Cue data") |
| EN | título `.firstRecording`: "Want Cue to remind you to finish this video?" · `.readyScript`: "Want a reminder to record this script?" · subtítulo: "One notification when something is waiting, at most one a day. You can change it in Settings." · botões **Allow notifications** / **Not now** |
| PT-BR | "Quer que o Cue te lembre de terminar este vídeo?" · "Quer um lembrete para gravar este roteiro?" · "Uma notificação quando algo estiver esperando, no máximo uma por dia. Você pode mudar isso em Ajustes." · **Permitir notificações** / **Agora não** |
| Ações | Allow → fecha a folha e pede ao iOS (não liga Tools and news); Not now → mede `snoozed`, nada mais; X/arrastar → só fecha (conta como mostrado, nada medido) |
| Código | `Screens/Shared/Notifications/NotificationInviteSheet.swift:10-43`; `Models/Notifications/NotificationInviteReason.swift:16-21`; `MainView.swift:355-369` |
| Launch arg | `-uiTestInMemory -uiTestSeedSamples -uiTestNotificationInvite` (com `-uiTestNotificationAuth notDetermined`, o padrão), gravar e fechar o gravador |

### 2.2 `FeatureIntroSheet` — introdução de uma ferramenta

| Item | Valor |
|---|---|
| Visual | mesmo desenho do convite (folha ajustada, azulejo de ícone, `SheetHeader`, 2 botões cápsula + link) |
| Gatilhos | (a) toque numa notificação de ferramenta (`RootView.swift:126-130`); (b) "Tools and news" ligado e o criador **acabou de sair do teleprompter/editor**, se não houve convite (`MainView.swift:348-351`, `NotificationService+Discovery.swift:34-56`); (c) uma notificação de ferramenta que chegou com o criador ocupado (`deferredIntro`) |
| Limites | 1 introdução por sessão (o convite conta); nunca no dia de uma dica do My Cue Voice; 1 por semana (notificações e app juntos); a mesma ferramenta 2× em 90 dias, 30 dias entre elas; nunca depois de usada ou recusada |
| Copy | título = `FeatureID.name`, subtítulo = `FeatureID.benefit`, nota com ícone `info.circle` = `FeatureIntro.Note.text` — ver tabela abaixo; botões **Try it** / **Not now** / "Don’t suggest this" |
| PT-BR botões | **Experimentar** / **Agora não** / "Não sugerir isso" |
| Ações | Try it → abre o destino (Quick edit no painel, folha, Settings…) e começa a atribuição de 24 h; Not now → 30 dias; Don’t suggest this → nunca mais; X → só fecha (a exposição já contou) |
| Código | `Screens/Shared/Discovery/FeatureIntroSheet.swift:10-62`; `MainView.swift:318-336`; `Managers/Notifications/Discovery/FeatureIntro.swift:54-62` |
| Launch arg | `-uiTestInMemory -uiTestSeedSamples -uiTestNotificationAuth authorized -uiTestNotificationTap cleanUp` |

| FeatureID | Nome EN → PT-BR | Benefício EN | Benefício PT-BR |
|---|---|---|---|
| myCueVoice | My Cue Voice → My Cue Voice | Scripts that sound more like you. Four questions, and you can change any answer. | Roteiros com mais a sua cara. Quatro perguntas, e você pode mudar qualquer resposta. |
| importWriting | Import my writing → Importar meus textos | Show Cue something you wrote, and it learns how you put things. | Mostre ao Cue algo que você escreveu, e ele aprende o seu jeito de dizer as coisas. |
| ideas | Ideas for your topics → Ideias para os seus temas | Ideas for the topics you make videos about. Nothing is written until you pick one. | Ideias para os temas dos seus vídeos. Nada é escrito até você escolher uma. |
| logbook | Logbook → Diário de bordo | Save an idea before it disappears, and develop it later. | Salve uma ideia antes que ela escape e desenvolva depois. |
| voiceFollowing | Voice Following → Seguir voz | Read at your own pace: the text moves when you speak and waits when you pause. | Leia no seu ritmo: o texto anda quando você fala e espera quando você pausa. |
| cleanUp | Clean Up → Limpeza | Find pauses and repetitions. You choose what stays. | Encontre pausas e repetições. Você escolhe o que fica. |
| autoCaptions | Auto captions → Legendas automáticas | Drafted from your voice, so people can follow muted. | Rascunhadas a partir da sua voz, para acompanhar sem som. |
| captionTranslation | Translated captions → Legendas traduzidas | Your captions in another language, next to the originals. | Suas legendas em outro idioma, ao lado das originais. |
| studioVoice | Studio Voice → Voz de estúdio | Explore a clearer sound for your voice. Nothing changes until you choose a level. | Experimente um som mais claro para a sua voz. Nada muda até você escolher um nível. |
| skinSmoothing | Skin → Pele | Smoother skin, a soft light on the face or less shine, if you want them. Each starts at zero and you choose how much. | Pele mais lisa, uma luz suave no rosto ou menos brilho, se você quiser. Cada um começa do zero e você escolhe quanto. |
| backgrounds | Background → Fundo | Blur or change the background behind you. | Desfoque ou troque o fundo atrás de você. |
| covers | Cover → Capa | Choose the first image that introduces your video. | Escolha a primeira imagem que apresenta o seu vídeo. |
| layers | Photo or video → Foto ou vídeo | Show examples while you speak: add a photo or a clip over your video. | Mostre exemplos enquanto fala: adicione uma foto ou um clipe por cima do vídeo. |
| voiceOver | Voice-over → Narração | Record a narration over your edit. Nothing records until you press the button. | Grave uma narração por cima da edição. Nada é gravado até você apertar o botão. |
| remoteControl | Remote Control → Controle remoto | Start, pause and scroll the teleprompter from another iPhone or iPad. | Inicie, pause e role o teleprompter por outro iPhone ou iPad. |
| safeZones | Social safe zone → Zona segura social | See where TikTok, Reels and Shorts put their buttons while you record. | Veja onde TikTok, Reels e Shorts colocam os botões enquanto você grava. |
| yourUniverse | Your universe → Seu universo | See how the videos you share are shaping your universe. | Veja como os vídeos que você compartilha estão formando o seu universo. |

| Nota (`FeatureIntro.Note`) | EN | PT-BR |
|---|---|---|
| appleIntelligence | Uses Apple Intelligence on this iPhone. | Usa a Apple Intelligence neste iPhone. |
| speechModel | Listens on this iPhone. Some languages download a model the first time. | Escuta neste iPhone. Alguns idiomas baixam um modelo na primeira vez. |
| translationDownload | Some languages download before the first translation. | Alguns idiomas são baixados antes da primeira tradução. |
| secondDevice | Needs another iPhone or iPad with Cue, nearby. | Precisa de outro iPhone ou iPad com o Cue, por perto. |
| nothingChanges | Free. Nothing changes until you choose. | Grátis. Nada muda até você escolher. |

### 2.3 `ReminderSheet` — "Remind me" (escolhas de lembrete)

| Item | EN | PT-BR | Notas / código |
|---|---|---|---|
| Entradas | ••• da página do script "Remind me…"; menu do vídeo em Takes "Remind me…"; Post later › "Pick a date and time…" (abre já no seletor); toque num lembrete em Settings (edição) | "Lembrar depois…" | `ScriptPageMenu.swift:24`, `TakesView.swift:298`, `ShareQueueStep.swift:63-75`, `NotificationsSettingsView.swift:79-81` |
| Título | "Remind me" / editando "Change reminder"; subtítulo = título do projeto | "Lembrar depois" / "Alterar lembrete" | `ReminderSheet.swift:38-41` |
| Escolhas | "Tonight" (20:00, some a partir das 19:30, ícone `bell`) · "Tomorrow" (10:00) · "Pick a date and time" (`calendar`) → DatePicker "Date and time" (só futuro) + **Set reminder** | "Hoje à noite" · "Amanhã" · "Escolher data e hora" · "Data e hora" · **Criar lembrete** | `ReminderSheet.swift:42-55, 104-122`; `ReminderChoice.swift:10-13` |
| Nota quiet hours (só no seletor) | "This is during your quiet hours. Cue will remind you anyway, since you chose this time." | "Isso fica dentro do seu horário de silêncio. O Cue vai lembrar mesmo assim, porque você escolheu esse horário." | `ReminderSheet.swift:110-116` |
| iOS recusou | "Notifications are off for Cue in iOS Settings. The reminder is kept here in Cue." (ícone `bell.slash`) | "As notificações do Cue estão desligadas nos Ajustes do iOS. O lembrete fica guardado aqui no Cue." | `ReminderSheet.swift:59-64` |
| Já marcados | "Already set" + data + ✕ ("Remove reminder") | "Já criados" / "Remover lembrete" | `ReminderSheet.swift:126-145` |
| Erro | "Pick a time in the future" (em `warnText`) | "Escolha um horário no futuro" | `ReminderSheet.swift:150-162` |
| Toasts depois (`ReminderFeedback`) | "Reminder set · Today 8:00 PM / Tomorrow 10:00 AM / Oct 12, 6:00 PM" · "Saved in Cue · notifications are off" + ação **Settings** · "Saved · Cue schedules it closer to the time" · "Couldn’t set the reminder · Try again" | "Lembrete criado · Hoje …/Amanhã …" · "Salvo no Cue · notificações desligadas" + **Ajustes** · "Salvo · o Cue agenda quando o horário estiver mais perto" · "Não foi possível criar o lembrete · Tente de novo" | `ReminderFeedback.swift:11-39` |
| Pedido ao iOS | o 1º lembrete traz a pergunta do sistema (sem convite antes) | — | `NotificationService+Reminders.swift:26-59` |

Launch arg: `-uiTestInMemory -uiTestSeedSamples` (+ `-uiTestNotificationAuth denied` para o estado "Kept in Cue").

### 2.4 "Post later" e o cartão "Continue posting"

| Item | Visual | Gatilho | EN | PT-BR | Ações | Código | Launch arg |
|---|---|---|---|---|---|---|---|
| Menu **Post later** (passo de uma rede na fila) | `Menu` do sistema | o criador está postando numa fila "Share to universe" | "Tonight · %@" (`moon`) · "Tomorrow · %@" (`sunrise`) · "Pick a date and time…" (`calendar`) · "No reminder" (`bell.slash`) | "Hoje à noite · %@" · "Amanhã · %@" · "Escolher data e hora…" · "Sem lembrete" · rótulo "Postar depois" | a rede fica para depois + lembrete (toast diz se o iOS aceitou) | `ShareQueueStep.swift:54-91` | `-uiTestInMemory -uiTestSeedSamples -uiTestFakeShareSheet` |
| Linha-guia "◀ Cue" no passo | cápsula `surface3` "◀ Cue" + frase | cada passo da fila | "After posting, tap ◀ Cue at the top left. We'll open %@ next." (no último: "… to finish.") | "Depois de postar, toque em ◀ Cue no canto superior esquerdo. Abriremos %@ em seguida." | — | `ShareQueueStep.swift:139-150` | idem |
| **ContinuePostingCard** | cápsula de vidro (`glassEffect(.regular)`, raio 22, 60 pt de altura, 16 pt das laterais, 104 pt acima do fundo) | aparece sozinho em Scripts (raiz) e Takes enquanto existe uma fila com redes pendentes (`shareQueue.pending`) e a tab bar está visível | "CONTINUE POSTING · %lld OF %lld" (mono 10 bold, `accText`) / "Next: %@ · %@" (rede · título; 15 semibold `ink`) / **Continue** / ✕ ("Leave the rest for later") | "CONTINUAR POSTANDO · %lld DE %lld" / "Próximo: %@ · %@" / **Continuar** / "Deixar o resto para depois" | Continue → revisão + `.continueQueue`; ✕ → resto para depois + toast "Saved · post when you’re ready" ("Salvo · poste quando estiver pronto") | `Screens/Shared/Share/ContinuePostingCard.swift:10-49`; `MainView.swift:78-100` | `-uiTestInMemory -uiTestSeedSamples -uiTestShareQueue` |
| **ShareQueueExplainer** (explicação de fila, 2 primeiras vezes) | folha: título, 3 passos numerados (círculo `accWashFaint` + número mono `accText`), trilho de redes em cápsulas `surface3` sobre `surface2` raio 22, **Start with %@** primário grande | 1ª e 2ª vez que uma fila tem ≥ 2 redes (`DefaultsKey.queueExplainerShown < explainerTimes`) | "Posting to %lld networks" · 1 "Cue opens each app" / "Your video is already loaded and the post text is copied." · 2 "You post there" / "Paste the text, pick the cover, tap Post." · 3 "Tap ◀ Cue to come back" / "Top left of the screen. Cue takes you to the next network." · **Start with %@** | "Postando em %lld redes" · "O Cue abre cada app" / "Seu vídeo já está carregado e o texto está copiado." · "Você posta lá" / "Cole o texto, escolha a capa e toque em Postar." · "Toque em ◀ Cue para voltar" / "No canto superior esquerdo da tela. O Cue leva você à próxima rede." · **Começar pelo %@** | abre a 1ª rede | `ShareQueueExplainer.swift:10-60`; `ShareFlow.swift:120-130` | `-uiTestInMemory -uiTestSeedSamples -uiTestFakeShareSheet` (escolher 2 redes) |

### 2.5 Settings › Notifications (estados do interruptor do iOS e das categorias)

`NotificationsSettingsView.swift` (lista agrupada `cueGroupedList`, cartões `surface`; título inline "Notifications" / "Notificações"). Valor na raiz de
Settings: "Off" quando o iOS negou, "Reminders: %lld" quando há lembretes, nada nos outros casos (`SettingsRootRow.swift:101-105`).

| Parte | Estado | EN | PT-BR | Comportamento | Código |
|---|---|---|---|---|---|
| `NotificationPermissionRow` (topo) | notAsked (`.notDetermined`, ou perguntando) | "Notifications are off" / "Cue can’t remind you yet." | "As notificações estão desligadas" / "O Cue ainda não pode te lembrar." | interruptor desligado; ligar → pergunta do iOS; o sim **liga tudo** (Tools and news inclusive, e rotina Seg/Qua/Sex 18:00 se não havia), sino toca, ✓ verde, interruptores acendem em cascata com háptico | `NotificationPermissionRow.swift:88-104`; `NotificationsSettingsView.swift:39-47, 152-188`; `NotificationService+Groups.swift:33-46` |
| | refused (`.denied`) | "Notifications are off in iOS" / "Allow Cue in iOS Settings." | "As notificações estão desligadas no iOS" / "Permita o Cue nos Ajustes do iOS." | qualquer toque abre a página do Cue nos Ajustes; voltar liberado → liga tudo e celebra | `NotificationsSettingsView.swift:72-78, 190-192` |
| | quiet (`.provisional`) | "Notifications arrive quietly" / "Without a banner or a sound." | "As notificações chegam em silêncio" / "Sem banner nem som." | (ver Observações: provavelmente inalcançável) | idem |
| | allowed (`.authorized`/`.ephemeral`) | "Notifications are on" / "Cue only reaches out when it helps." | "As notificações estão ligadas" / "O Cue só aparece quando ajuda." | desligar abre os Ajustes do iOS | idem |
| Seção "From Cue" | 2 interruptores | "Help me finish what I start" / "When a script or video is waiting." · "Tools and news" / "Now and then, something new for you." · rodapé "At most one a day, never at night. Your reminders always arrive." | "Me ajude a terminar o que eu começo" / "Quando um roteiro ou vídeo estiver esperando." · "Ferramentas e novidades" / "De vez em quando, algo novo para você." · "No máximo uma por dia, nunca à noite. Seus lembretes sempre chegam." | com iOS não perguntado: qualquer interruptor pede e liga tudo; negado: abre Ajustes; ligar toca `HapticPatterns.playChime()` | `NotificationGroup.swift:29-42`; `NotificationsSettingsView.swift:90-103, 130-147` |
| Seção "Creation routine" | "Remind me to create" + editor | "Remind me to create" · chips de dias (letra única) · "Time" | "Me lembrar de criar" · "Tempo" ⚠ | ligar sem rotina cria Seg/Qua/Sex 18:00; o último dia não sai (toque rígido) | `NotificationRoutineEditor.swift:34-84` |
| Seção "Your reminders" | vazia | "No reminders. Set one from a script, a recording, or Post later." | "Nenhum lembrete. Crie um a partir de um roteiro, uma gravação ou Postar depois." | — | `NotificationsSettingsView.swift:196-221` |
| | linha | título (ou "Script"/"Take"/"Post on %@") · "tipo · quando" · estado "Set"/"Kept in Cue"/"Due"; deslizar "Remove" | "Roteiro"/"Take"/"Postar no %@" · "Criado"/"Guardado no Cue"/"Já passou"; "Remover" | toque edita (sem toast de confirmação) | `NotificationReminderRow.swift:15-48` |
| DEBUG | só Debug | "Plan again", "Preview every notification", pendentes, contadores | (verbatim, sem tradução) | — | `NotificationDiagnosticsSection.swift` |

Launch arg: `-uiTestInMemory -uiTestNotificationAuth <notDetermined|refuses|authorized|denied|provisional>` e ir a Settings › Notifications.

### 2.6 Convite da Ultra AI (`UltraInviteCard`, DESIGN_PROJECT §57)

| Item | Valor |
|---|---|
| Gatilho | a partir do **2º uso** da IA (conta 1 roteiro escrito pelo Apple Intelligence ou 1 visita ao Find inspiration com Apple Intelligence: `UltraInviteService.usesBefore = 1`), Ultra oferecida, ainda não permitida, scripts grátis restantes > 0 e convite não fechado (`UltraScriptService.showsInvite`, `UltraScriptService.swift:70-73`; `UltraInviteService.swift:33`) |
| Lugares | **Dock de Scripts** (linha sob o campo, escondida com o campo aberto: `ScriptsDock.swift:153, 186-191`); **Find inspiration** (cartão acima da ideia, decidido ao abrir, antes de contar a visita: `FindInspirationSheet.swift:96-133`); **My Cue Voice** (cartão sob a voz: `MyCueVoicePage.swift:34-35`) |
| Frequência | um convite só para os três: ✕ em qualquer um fecha todos **para sempre** (`close()` grava `ultraInvite.closed.v1`); permitir a Ultra ou gastar os grátis também encerra. Acende (animação) 1× por lugar por sessão |
| EN dock | "✦ Meet Ultra AI · %lld free scripts" · **Try it** · ✕ |
| PT-BR dock | "Conheça o Ultra AI · %lld roteiros grátis" (plural) · **Experimentar** |
| EN Find inspiration | "Draft this idea with Ultra AI" / "A second writer that develops the idea further, in your voice. Your first %lld scripts are free." / **Draft it with Ultra AI** |
| PT-BR | "Rascunhe esta ideia com o Ultra AI" / "Um segundo redator que desenvolve mais a ideia, na sua voz. …" (plural) / **Rascunhar com o Ultra AI** |
| EN My Cue Voice | "Your voice, with Ultra AI" / "Ultra AI writes in this voice too, and develops each idea further. Your first %lld scripts are free." / **Try Ultra AI free**; ao permitir, toast "Ultra AI writes your next idea" |
| PT-BR | "Sua voz, com o Ultra AI" / "O Ultra AI também rascunha nesta voz e desenvolve mais cada ideia. …" / **Testar o Ultra AI grátis** / "O Ultra AI rascunha sua próxima ideia" |
| ✕ (VoiceOver) | rótulo "Not now" / dica "Closes the invitation to Ultra AI." ("Agora não" / "Fecha o convite para o Ultra AI.") |
| Ações | qualquer botão passa pela folha de permissão do Google; no dock, permitir → ✦ voa em arco até o chip do escritor (`HapticPatterns.ultraOn`) |
| Código | `Managers/ScriptAI/Ultra/UltraInviteService.swift:14-59`; `Screens/Shared/Ultra/UltraInviteCard.swift:13-200` |
| Launch arg | `-uiTestInMemory -uiTestStubAI -uiTestUltra -uiTestUltraInvite` (sem `-uiTestUltraAllowed`); `-uiTestUltraScriptsLeft 0` mostra que ele some |

### 2.7 Convites para o Pro que aparecem sem bloqueio

Não há paywall que abra sozinho (sem teste grátis, decisão do dono 30/10). O que aparece sem o criador pedir são **rótulos permanentes**:

| Item | Onde | EN | PT-BR | Ação | Código |
|---|---|---|---|---|---|
| Contador + **Go Pro** sob Share | revisão da take, plano grátis | "%lld OF %lld FREE EXPORTS LEFT" / "LAST FREE EXPORT" (amarelo) / "READY · EXPORT WITH PRO" · "Go Pro" | "… DE … EXPORTAÇÕES GRÁTIS" · "Assinar o Pro" | Pro calmo (`.export` sem exportações, senão `.profile`) | `ReviewExportFooter.swift:47-58`; `Models/FreeExportLabels.swift:21-45`; `TakeReviewView.swift:385-391` |
| Medidor em "Ready to travel" (8.1) | celebração da exportação | "FREE EXPORTS" + "%lld OF %lld LEFT" / "LAST FREE EXPORT" / "0 OF 3 LEFT · EXPORT WITH PRO" | — | — | `ReadyToTravelView.swift:103-120` |
| Cartão do plano no Profile | Profile | "%lld OF %lld EXPORTS LEFT", "ULTRA AI · 2 OF 3 FREE LEFT" | — | Pro | `ProfilePlanCard.swift` |
| Ícone de marco que exige Pro | celebração de marco | (escolher um ícone Pro sem Pro abre o Pro) | — | Pro `.profile` | `TakeReviewView.swift:620-626` |

---


## 3. TipKit

O app tem **um único** `Tip` do TipKit: a dica de perguntas do My Cue Voice. Não há `.popoverTip`, `TipGroup`, `@Parameter`, `Tips.Event`,
`MaxDisplayCount` nem regras do TipKit: toda a lógica de quando e qual pergunta é do `VoiceQuestionScheduler` (UserDefaults), e o TipKit só guarda
o "invalidado". A primeira viagem (seção 4) **não** usa TipKit, por decisão (`DESIGN_PROJECT.md:1269`).

Configuração: `Cue Studio/SupportFiles/CueStudioApp.swift:49-52` (`configureTips`, chamado na `init` do app, linha 38):
`if inMemory { try? Tips.resetDatastore() }` e `try? Tips.configure([.displayFrequency(.immediate)])`. Sem `datastoreLocation`, sem
`showAllTipsForTesting`. O tip ainda declara `Tips.IgnoresDisplayFrequency(true)` (`VoiceQuestionTip.swift:26`), redundante com `.immediate`.
Erros de `configure` são engolidos pelo `try?`.

| ID/nome | Tipo visual | Tela / âncora | Gatilho e condições | Frequência / limites | EN | PT-BR | Botões → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|---|
| `VoiceQuestionTip` (id `vq.tip.<pergunta>.<rodada>`) | `TipView` inline com `VoiceTipViewStyle` (vidro, ✦ num círculo violeta, ✕) | **Scripts**: `safeAreaInset(.bottom)`, num `VStack(spacing:10)` logo abaixo da dica da viagem e 10 pt acima do `ScriptsDock` (`ScriptsView.swift:80-81`). **Takes**: mesmo empilhamento, 10 pt acima da tab bar (`TakesView.swift:63-64`) | `VoiceQuestionTipHost.evaluate()` (`VoiceQuestionTipHost.swift:63-74`): tela quieta (`isQuiet` + `voyage.floatingStep == nil`), espera **1,2 s**, e `scheduler.tipQuestion` passa: Apple Intelligence disponível, `usesVoiceInAI`, voz < 100%, ≥ 1 roteiro, app aberto em **2 dias diferentes**, nenhuma apresentação de ferramenta hoje (`NotificationService.introducedToday`), sem pausa (`VoiceQuestionScheduler.swift:95-103`). Pergunta = primeira de `remaining` não adiada | 1 por dia, 3 em 7 dias corridos; ✕ (ou fechar a folha sem responder) adia a pergunta **3 dias**; 2 dispensas mandam a pergunta para o fim; 3 dispensas seguidas pausam tudo **14 dias**; "None of these" pula para sempre; para em 100% (toast "Cue Voice complete"). Momentos que puxam uma pergunta para a frente (uma vez cada, `VoiceTrigger`): 1ª exportação → Where do you post; 2ª edição de roteiro na voz → How technical; 3º roteiro gravado → exemplo | título "Make scripts sound more like you" · mensagem "One quick question · voice %lld%%" · ✕ a11y "Close tip" | "Faça os roteiros soarem mais como você" · "Uma pergunta rápida · voz %lld%%" · "Fechar dica" (19 idiomas cada) | Toque no corpo → `tip.invalidate(.actionPerformed)` e abre `VoiceQuestionSheet` (folha `.medium/.large`, título "My Cue Voice", subtítulo "✦ nn%") · ✕ → `invalidate(.tipClosed)` → `scheduler.dismissed` | `Screens/Shared/VoiceStyle/VoiceQuestionTip.swift:12-28`, `VoiceQuestionTipHost.swift:13-100`, `VoiceTipViewStyle.swift:11-66`, `Managers/Preferences/VoiceQuestionScheduler.swift` | `-uiTestInMemory -uiTestStubAI -uiTestVoiceTip` (abre todos os portões menos a fila; em memória a viagem fica desligada, então não bloqueia). Sem `-uiTestVoiceTip` a dica não aparece em testes de UI (precisa de 2 dias) |

**O que a dica abre (folha `VoiceQuestionSheet`)**, para referência do redesenho: uma pergunta por vez (17 em `VoiceQuestion.swift`, todas com 19
idiomas: "What kind of creator are you?", "What do you talk about?", "Who’s watching?" + "How much do they already know?", "How do you talk on
camera?", "How do you usually end a video?", "How do you like to open?", "What do you film most?", "How long are your videos, usually?", "How much
humor in your videos?", "Where do you post most?", "What’s your energy on camera?", "Short sentences or longer ones?", "How technical are your
words?", "Any swearing?", "A phrase you always say?", "Anything Cue should never write?", "Paste something you wrote or said"). Toque = resposta;
listas múltiplas têm **Save** na barra; "+ Something else", "None of these", "Saved · voice nn%" e **One more question** (no máximo 3 seguidas),
fecha sozinha 0,9 s depois do último "Saved" (`VoiceQuestionSheet.swift:49-57, 214-230`). Fechar sem resposta = dispensa
(`VoiceQuestionSheetModel.swift:162-165`).

Persistência: `DefaultsKey.voiceQuestionState` (JSON `VoiceQuestionState`: dias abertos, datas mostradas, adiamentos, contagem de dispensas,
pausa, puladas, puxadas, toast final, roteiros na voz, edições). O TipKit guarda só o status de cada id no datastore padrão.
"Delete my Cue data" chama `VoiceQuestionScheduler.reset()` (`DataEraserService.swift:113`), **mas não** `Tips.resetDatastore()`.

Coordenação com outros sistemas: a dica espera enquanto a viagem tem dica flutuante (`voyage.floatingStep == nil`); não aparece num dia em que uma
notificação/apresentação de ferramenta já apresentou algo (`AppServices.swift:384`); quando aparece, avisa as notificações para mover uma
apresentação de hoje (`AppServices.swift:385`, `NotificationPlanner.swift:128` `.voiceTipSameDay`).

### Componentes visuais

**`VoiceTipViewStyle`** (`Cue Studio/Screens/Shared/VoiceStyle/VoiceTipViewStyle.swift`)
- Superfície: `glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))` (Liquid Glass do sistema, sem tint), sem sombra
  nem borda própria. Largura total da tela menos 12 pt de cada lado (padding do contêiner em Scripts/Takes).
- Layout: `HStack(spacing: 0)` = [botão com o conteúdo] + [✕]. Padding: leading 14, trailing 2, vertical 6.
- Conteúdo: `HStack(spacing: 12)`: glifo "✦" (texto, `cueFont(15, .semibold)`, cor `Palette.Scripts.tipGlyph` = #C4B8FF) num círculo de 30×30
  preenchido com `Palette.Scripts.tipGlyphFill` = #9D8CFF a 22%; ao lado `VStack(alignment: .leading, spacing: 2)`: título `cueFont(15,
  .semibold)` em `Palette.ink` (#FFFFFF), mensagem `cueFont(13)` em `Palette.inkSoft` (branco 80%; 92% com Aumentar Contraste). `cueFont` cresce
  com Dynamic Type (curva subheadline/footnote) e com a largura do iPhone; o contêiner limita em `.xxxLarge` em Scripts.
- ✕: SF Symbol `xmark`, `Font.fixed(12, .bold)`, `Palette.ink2` (#E1E4F5 a 62%; 80% com Aumentar Contraste), alvo 44×44 (`Metrics.hitTarget`).
- Movimento: entra em 0,40 s com `CueMotion.tipEnter` = `timingCurve(0.2, 0.9, 0.25, 1)`, opacidade + 10 pt para cima + escala 0,97 → 1; sai em
  fade de 0,20 s (`easeOut`). Reduzir Movimento: só fade 0,2 s. Sem háptico.
- Acessibilidade: o corpo é um botão com filhos combinados (lê título + mensagem), ✕ "Close tip"; ids `voice.tip`, `voice.tip.open`,
  `voice.tip.close`. **Nenhum anúncio** de VoiceOver quando a dica aparece.

### Observações (3)

1. **"Delete my Cue data" pode deixar a dica invisível e ainda assim gastando a cota.** O id do tip usa a rodada = `dismissCount`
   (`VoiceQuestionTipHost.swift:69-71`); o reset zera `dismissCount` (`VoiceQuestionScheduler.swift:184-187`), mas o datastore do TipKit só é limpo
   em memória (`CueStudioApp.swift:50`). Uma pergunta cujo `vq.tip.X.0` já foi invalidado volta com o mesmo id: o `TipView` não desenha nada, mas
   `shown` fica preenchido e `scheduler.tipShown()` conta o dia e a semana e avisa as notificações (`:73`). Se o motivo antigo era
   `.actionPerformed` (tocou na dica), o `watchClose` nunca encerra (`:83-91`): o espaço fica "ocupado" até a tela ser recriada, todo dia.
2. **A pergunta de exemplo (`.example`) aberta pela dica sempre conta como dispensa.** A folha mostra `VoiceExamplesField`
   (`VoiceQuestionSheet.swift:24`), que não avisa o modelo; ao fechar, `dismissedWithoutAnswer()` vê `answeredCurrent == false` e chama
   `scheduler.dismissed` (`VoiceQuestionSheetModel.swift:162-165`): soma em `consecutiveDismissals`, e três seguidas pausam tudo por 14 dias, mesmo
   que o criador tenha colado um exemplo.
3. **A dica não diz qual é a pergunta.** "One quick question · voice nn%" é a mesma linha para as 17; o criador só descobre o assunto depois de tocar.
   (Vem do quadro, 09 §3, mas vale levar ao dono.)
4. **"Quieto" não é igual nos dois lugares.** Em Takes a dica do Voice não espera o toast (`TakesView.swift:41-43, 64`), enquanto a da viagem, logo
   acima, espera (`:63`); em Scripts os dois esperam (`ScriptsView.swift:139-143`). O comentário do host promete "no sheet, toast, keyboard,
   scrolling or open dock" (`VoiceQuestionTipHost.swift:14`), mas rolagem não é checada em nenhuma tela.
5. **Contraste sem medição.** Texto `inkSoft` de 13 pt e ✕ `ink2` sobre vidro `.regular` por cima do céu/aurora não estão em
   `PaletteContrastTests` nem nas capturas (`HandoffCaptureTests`/`UserReportCaptureTests` não abrem `-uiTestVoiceTip`). CLAUDE.md exige medir
   texto sobre vidro no pior ponto.
6. Pequenos: `reduceMotion ? 1200 : 1200` (`VoiceQuestionTipHost.swift:65`, ternário morto); o comentário do style diz "message in 13 pt at 70%"
   e o código usa `inkSoft` (80%) (`VoiceTipViewStyle.swift:9, 46`); `DESIGN_PROJECT.md:170` fala em "Not now adia 3 dias", mas a folha não tem
   "Not now" (só ✕, arrastar ou tocar fora).
7. Duas linguagens visuais para "dica" no **mesmo lugar**: a do Voice é vidro, 22 pt, uma linha, sem botão; a da viagem logo acima é superfície
   sólida com tint violeta, 20 pt, com olho "★ n OF 6" e botão (seção 4). Mesma animação de entrada, aparência diferente.

## 4. Primeira viagem (First Voyage)

Guia de 6 passos do primeiro roteiro ao primeiro vídeo compartilhado, **uma dica por vez** (a do primeiro passo que falta), em vistas próprias
(sem TipKit). Fonte: `DESIGN_PROJECT.md` §32 (linhas 1249-1271); §35 (1324+) é o texto do primeiro voo (onboarding), que alimenta a viagem: o
roteiro fixo "From idea to video" vira um roteiro real na biblioteca (`OnboardingView.swift:116-120`) e tocar o teleprompter na prática do
onboarding conta como "practiced" (`PrompterView.swift:115-117`).

**Estado e persistência.** `FirstVoyageService` (`Managers/FirstVoyage/FirstVoyageService.swift`), `@Observable`, em `AppServices.swift:129-132`.
Marcas em `UserDefaults` `DefaultsKey.firstVoyage` = "firstVoyage" (JSON `VoyageMarks`: `stage`, `practiced`, `skippedPolish`, `sawDraftTip`,
`announced`, gravado como "celebrated"). `VoyageStage`: `active` · `hidden` ("Hide guide") · `finished` (primeiro compartilhamento anunciado) ·
`notNeeded` (já tinha compartilhado antes: decidido na primeira execução, `:49-55`). O ✕ de um passo vale **pela sessão** (`closedThisSession`, só
em memória: até o processo morrer). Progresso é **lido do que existe** (`VoyageProgress`), nada travado:

| Passo | Feito quando (`VoyageProgress.swift:19-25`) |
|---|---|
| 1 write | ≥ 1 roteiro, ou algum take, ou compartilhou |
| 2 practice | `marks.practiced` (teleprompter tocou com roteiro, inclusive a prática do onboarding), ou algum take, ou compartilhou |
| 3 record | algum take, ou compartilhou |
| 4 pick | algum take com ★ (`isBest`) **ou com edição** (`edit != nil`), ou compartilhou |
| 5 polish | "Skip", ou algum take com legendas ou com corte do Clean Up, ou compartilhou |
| 6 share | `milestones.shares > 0` (só depois de "Yes, it's live" no fluxo de envio, `SHARING.md` §1.1) |

Liga/desliga: em produção sempre ligado (`isEnabled: !options.isInMemory || options.showsVoyage`); em testes de UI só com `-uiTestVoyage`
(`LaunchOptions.swift:51, 358`). "Delete my Cue data" recomeça (`DataEraserService.swift:115`, `FirstVoyageService.reset()`).
Telemetria: `cue_voyage` (`tip`, `place`, `outcome` = shown/acted/closed/stepDone), só com "Help improve Cue" (`AppServices.swift:232-234`,
`TelemetryManager.swift:69-72`).

### 4.1 Os passos e as dicas

Copy dos passos em `Models/VoyageStep.swift` (título da lista 24-29, detalhe 36-41, símbolo 48-53, título da dica 60-66, linha 73-82, botão
89-95). Todas as chaves com 19 idiomas, salvo nota.

| ID | Tipo visual | Tela / âncora | Gatilho e condições | Frequência / limites | EN | PT-BR | Botões → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|---|
| **Dica flutuante** (qualquer passo) `voyage.tip.<n>` | `VoyageTipCard` + `cardDepth` | **Scripts**: 10 pt acima do dock, no `safeAreaInset(.bottom)` (`ScriptsView.swift:80`), escondida durante seleção. **Takes**: 10 pt acima da tab bar (`TakesView.swift:63`) | `floatingStep` = passo atual, viagem `active`, não fechado na sessão (`FirstVoyageService.swift:67-75`); tela quieta (Scripts: sem sheet, prompter, outra aba, página aberta, dock editando, seleção, busca, toast; Takes: sem sheet, prompter, outra aba, toast) por **1,2 s** (`VoyageFloatingTip.swift:48-59`). Uma vez de pé, fica mesmo que um toast/sheet passe | Até o passo mudar ou ✕ (volta na próxima sessão) | por passo, abaixo | por passo, abaixo | botão primário do passo → `VoyageNavigator.start` (`Support/VoyageNavigator.swift:17-38`); "★ n OF 6" → `VoyageStepsSheet`; ✕ → `closeTip` (sessão) | `Screens/FirstVoyage/VoyageFloatingTip.swift:12-85` | `-uiTestInMemory -uiTestStubAI -uiTestVoyage` (biblioteca vazia → passo 1) |
| 1 · write (flutuante) | idem, símbolo `sparkles` | Scripts / Takes | biblioteca vazia, sem takes | idem | "Your idea, Cue's draft." · "Make it yours. Cue learns as you write." | "Sua ideia, o rascunho do Cue." · "Deixe do seu jeito. O Cue aprende enquanto você escreve." | **Get an idea** ("Buscar ideia") → aba Scripts + sheet `.ideas` (Find inspiration) | `VoyageStep.swift:60,73,89`; `VoyageNavigator.swift:19-23` | `-uiTestInMemory -uiTestStubAI -uiTestVoyage` |
| Dica do primeiro rascunho `voyage.tip.draft` | `VoyageTipCard`, símbolo `pencil.line`, olho conta o passo atual (2 ou 3 de 6) | **Página do roteiro**, acima do botão Record, fora da escrita e sem teclado de cues (`ScriptPageView.swift:469-474`) | Viagem ativa, roteiro é rascunho do Cue (`DraftLearningService.isCueDraft`), `!sawDraftTip`, passo atual = practice ou record (`FirstVoyageService.swift:78-81`). Tem prioridade sobre a dica de prática | **Uma vez na vida**: Edit ou ✕ gravam `sawDraftTip` | "A first draft. Yours to change." · "Rewrite freely. Tap Sounds like me and Cue learns from it." | "Um primeiro rascunho. Seu para mudar." · "Reescreva à vontade. Toque em Soa como eu e o Cue aprende com isso." | **Edit** ("Editar") → foco no texto (`focus = .text`) · ✕ | `ScriptPageView.swift:519-531` | idem + escrever um roteiro pelo dock ou Get an idea (stub AI) |
| 2 · practice (flutuante) | símbolo `text.alignleft` | Scripts / Takes | roteiro existe, nunca tocou o teleprompter, sem takes | idem | "Read it out loud once" · "The text follows your voice. %@, nothing recorded." (com duração "0:44" do roteiro mais recente) ou "… Nothing is recorded." | "Leia em voz alta uma vez" · "O texto segue a sua voz. %@, nada é gravado." / "… Nada é gravado." | **Try it** ("Experimentar") → prompter modo **Studio** com o roteiro alterado por último | `VoyageStep.swift:61,74-76,90`; `VoyageNavigator.swift:24-25` | idem + criar um roteiro à mão |
| 2 · practice (no lugar) `voyage.tip.2` | `VoyageTipCard` | Página do roteiro, acima do Record (`ScriptPageView.swift:475-478`) | `showsTip(for: .practice)` e não há dica de rascunho | sessão | idem, duração do texto da página | idem | **Try it** → `commitPage()` + `actions.studio(script)` (este roteiro) | `ScriptPageView.swift:534-547` | idem |
| 3 · record (flutuante) | símbolo `record.circle` | Scripts / Takes | praticou, sem takes | idem | "Now, for real" · "Redo it as often as you like. You pick the take that's posted." | "Agora, para valer" · "Refaça quantas vezes quiser. Você escolhe o take que vai ao ar." | **Record** ("Gravar") → prompter modo **Selfie** com o roteiro mais recente | `VoyageStep.swift:62,77,91`; `VoyageNavigator.swift:26-27` | idem + tocar play no teleprompter |
| 4 · pick (flutuante) | símbolo `star` | Scripts / Takes | há take, nenhum ★ nem edição | idem | "Which take is the one?" · "Star your favorite. The others stay in Takes." | "Qual é o take?" · "Marque seu favorito com uma estrela. Os outros ficam em Takes." | **Compare** ("Comparar", se o último take tem irmãos e nenhum ★) → revisão + "Pick the best take"; senão **Watch** ("Assistir") → revisão do último take | `VoyageStep.swift:63,78,92-93`; `VoyageNavigator.swift:28-30, 41-45` | sem argumento direto: gravar um take (aparelho) ou Takes › Import video, com `-uiTestVoyage` |
| 4 · pick (no lugar) `voyage.tip.4` | `VoyageTipCard` | **Revisão do take**, `overlay(alignment: .top)`, 16 pt dos lados, 8 pt do topo (`TakeReviewView.swift:134-141`) | `showsTip(.pick)`, take na tela, sem história da primeira estrela, sem editor aberto, sem celebração (`:557-559`) | sessão | idem | idem | **Compare** só se o take tem > 1 irmão → `suggestBest()` ("Pick your best take" com sugestão do Cue); com 1 take, **sem botão** (o ★ fica na barra da revisão) | `TakeReviewView.swift:567-579` | idem |
| 5 · polish (flutuante) | símbolo `captions.bubble` | Scripts / Takes | take escolhido/editado, sem legendas, sem corte, sem Skip | idem | "Make it work muted" · "Cue drafts captions from your voice. Fix any word." | "Faça funcionar sem som" · "O Cue rascunha as legendas pela sua voz. Corrija qualquer palavra." | **Add captions** ("Adicionar legendas") → revisão do take do vídeo + `.edit` (abre o Quick edit, **não** as legendas) | `VoyageStep.swift:64,79,94`; `VoyageNavigator.swift:31-33` | `-uiTestInMemory -uiTestSeedSamples -uiTestSampleVideo -uiTestVoyage` (amostras: 4 passos feitos) |
| 5 · polish (no lugar) `voyage.tip.5` | `VoyageTipCard` com 2 botões | **Quick edit**, sobre a parte de baixo da timeline, logo acima da barra de ferramentas, 16 pt dos lados, 8 pt de baixo (`QuickEditView.swift:304-312`) | `showsTip(.polish)`, sem painel, sem menu de ferramenta, sem tela cheia, com barra de ferramentas visível (`:330-332`) | sessão | idem | idem | **Add captions** → `openCaptions()` (painel Auto captions se não houver legendas) · **Skip** ("Pular") → `skipPolish` (passo feito) · ✕ | `QuickEditView.swift:334-345` | idem |
| 6 · share (flutuante) | símbolo `paperplane` | Scripts / Takes | tudo feito menos compartilhar | idem | "Ready for %@" (rede do take) / "Ready to share" · "Cue opens %@ with your video and caption. You post." / "Cue opens the app with your video and caption. You post." | "Pronto para o %@" / "Pronto para compartilhar" · "O Cue abre o %@ com o vídeo e a legenda. Você posta." / "O Cue abre o app com o vídeo e a legenda. Você posta." | **Share** ("Compartilhar") → revisão + `.share` ("Share to universe") | `VoyageStep.swift:65-66,80-82,95`; `VoyageNavigator.swift:34-36` | idem + Skip no editor |
| 6 · share (no lugar) `voyage.tip.6` | `VoyageTipCard` **sem botão** | Folha "Share to universe" (`ShareNetworkPicker`), entre o cabeçalho e a lista de redes (`ShareNetworkPicker.swift:31-39`) | `showsTip(.share)` | sessão | idem | idem | só ✕ e "★ 6 OF 6" | `ShareNetworkPicker.swift:33-38` | idem |

### 4.2 Avisos de passo feito (toast ✓)

`VoyageAnnouncer` (`Screens/FirstVoyage/VoyageAnnouncer.swift`), vive uma vez em `MainView.swift:55` (`.background`). Quando `stepsToAnnounce`
muda e o app está "livre" (`presentation.prompter == nil` e nenhum toast), espera **0,7 s**, `Haptics.soft()` e `toast.show(message)` (✓ padrão).
O texto vem de `VoyageNotice.message` (`Managers/FirstVoyage/VoyageNotice.swift:14-23`): só quando o "Next" é verdade (o passo seguinte é o atual);
cada passo uma vez (`announced`). Write, Pick e Polish sem legenda passam calados.

| Quando | EN | PT-BR |
|---|---|---|
| Practice feito e Record é o próximo | "Rehearsed · Next: record" | "Ensaiado · Próximo: gravar" |
| Record feito e Pick é o próximo | "Recorded · Next: pick a take" | "Gravado · Próximo: escolher o take" |
| Polish feito com legendas e Share é o próximo | "Captions on · Next: share" | "Legendas prontas · Próximo: compartilhar" |
| Primeiro compartilhamento (encerra: `stage = .finished`) | "Your first star is out there" | "Sua primeira estrela está no mundo" |

### 4.3 Lista de passos e Ajustes

| ID | Tipo visual | Tela / âncora | Gatilho | EN | PT-BR | Ações | Código |
|---|---|---|---|---|---|---|---|
| `VoyageStepsSheet` `voyage.steps` | Folha ajustada ao conteúdo (`fittedSheet`, fundo `sheetNight`, botão de fechar do sistema) | Aberta de qualquer `VoyageTipCard` (toque em "★ n OF 6"), inclusive dentro da revisão, do editor e da folha de envio | toque no olho | título "Your first voyage" · "Six steps from an idea to your first star. Go at your own pace; nothing here is locked." · "Hide guide" · "You can bring it back in Settings › Personalize." | "Sua primeira viagem" · "Seis passos de uma ideia até sua primeira estrela. No seu ritmo; nada aqui é bloqueado." · "Ocultar guia" · "Você pode trazer de volta em Ajustes › Personalizar." | **Start** na linha do próximo → fecha, espera 350 ms, `VoyageNavigator.start` · **Hide guide** → `setOn(false)` (`stage = .hidden`) e fecha | `VoyageStepsSheet.swift:17-71` |
| `VoyageStepRow` `voyage.step.<n>` | linha de 56 pt | dentro da folha | estado done / next / ahead | título do passo · detalhe: "Done" / "Next · %@" / detalhe do passo (ver abaixo) · a11y value "Done" / "Next" (`step.next`) / "Not done yet" · botão "Start" | "OK" (!) / "Próximo · %@" / … · "OK" / "Próximo" / "Ainda não concluído" · "Início" (!) | Start (`cuePrimary(.compact)`) | `VoyageStepRow.swift:18-91` |
| Ajustes › Personalize › Getting started › "First video guide" | `SettingsListToggle` | `PersonalizeView.swift:44-51` (só se `canBeTurnedOn`: active ou hidden); também na **busca** de Ajustes (sempre, `SettingsSearchResults.swift:15`) | — | "First video guide" · "Your next step, until your first video is out" · seção "Getting started" · desabilitado: "You finished your first voyage" | "Guia do primeiro vídeo" · "Seu próximo passo, até o primeiro vídeo sair" · "Primeiros passos" · "Você concluiu sua primeira viagem" | toggle → `setOn(_:)` (ligar também zera os ✕ da sessão) | `SettingsEntry.swift:92,116,149,199`; `PersonalizeEntryRow.swift:64-69` |

Títulos e detalhes da lista (`VoyageStep.swift:24-41`): 1 "Write your first script" / "An idea is enough. You make it yours." (PT "Escreva seu
primeiro roteiro" / "Uma ideia basta. Você deixa do seu jeito.") · 2 "Practice with the teleprompter" / "Read it once; nothing is recorded" ("Pratique
com o teleprompter" / "Leia uma vez; nada é gravado") · 3 "Record a take" / "About a minute" ("Gravar um take" / "Cerca de um minuto"; a chave
"Record a take" está marcada `stale` no catálogo, embora usada) · 4 "Pick your best take" / "Mark the one you'll post with a star" ("Escolha seu
melhor take" / "Marque com uma estrela o que você vai postar") · 5 "Polish it" / "Captions and Clean Up · optional" ("Dê o acabamento" / "Legendas
e Limpeza · opcional") · 6 "Share to your universe" / "Lights your first star" ("Compartilhe no seu universo" / "Acende sua primeira estrela").
Olho: "%lld OF %lld" ("%lld DE %lld", 20 locs), a11y "Step %lld of %lld" ("Passo %1$lld de %2$lld"), dica a11y "Shows every step" ("Mostra todos
os passos"), ✕ "Close tip" ("Fechar dica").

**Ordem real para quem passa pelo onboarding:** o 1.4 já cria o roteiro (passo 1 feito) e a prática do 1.6 toca o teleprompter (passo 2 feito);
se a pessoa grava no 1.6 ("Record my first video"), o passo 3 também. Na prática a primeira dica que um criador novo vê é **"3 OF 6 · Now, for
real"** ("Explore Cue first") ou **"4 OF 6 · Which take is the one?"**.

**Pular / fechar:** ✕ esconde o passo até a próxima sessão (todas as instâncias daquele passo, em qualquer tela); "Skip" só existe no Polish (marca
feito); "Hide guide" esconde tudo até o toggle de Ajustes; fazer o passo em outro lugar conta igual; compartilhar encerra para sempre.

### Componentes visuais

**`VoyageTipCard`** (`Cue Studio/Screens/FirstVoyage/VoyageTipCard.swift`)
- Superfície sólida: `Palette.surface` #161826 + camada `Palette.aiFill` (#9D8CFF a 17%) + borda 1 pt `Palette.aiBorder` (#B4A7FF a 30%), cantos
  20 pt contínuos. Na versão flutuante, `cardDepth` (sombras pretas a 50%: raio 14/y 8 e raio 2/y 1,5; luz no topo em gradiente
  `Palette.Depth.rim` #B4A7FF a 38% → transparente até 60% da altura; sem hairline, `edge: nil`). Nas versões no lugar, sem profundidade. Sem vidro.
- Padding: top 14, leading 16, trailing 14, bottom 14 (sem botões) ou 8 (com botões). `VStack(spacing: 10)`.
- Linha de cima `HStack(alignment: .top, spacing: 12)`: azulejo 36×36 (cantos 11) em `aiFill` com SF Symbol do passo (`sparkles`,
  `text.alignleft`, `record.circle`, `star`, `captions.bubble`, `paperplane`; rascunho `pencil.line`), `Font.fixed(17, .semibold)`, cor
  `Palette.aiText` (#B4A7FF; #CFC6FF com Aumentar Contraste). Coluna (spacing 4): olho = `star.fill` `cueFont(9, .bold)` em `Palette.acc` #FFD60A
  + "3 OF 6" em mono 10,5 pt semibold, tracking 1,2, `aiText` (alvo de toque ampliado para 44 pt); título `cueFont(.body, .semibold)` (17 pt) em
  `ink` #FFFFFF; linha `cueFont(.subheadline)` (15 pt) em `ink2` (#E1E4F5 a 62%). ✕ `xmark` fixo 12 pt bold `ink2`, 44×44, deslocado −10 pt
  para cima e para a direita.
- Botões (direita, `HStack(spacing: 6)`): secundário em texto (`subheadline` semibold, `ink2`, 44 pt de altura, 8 pt de lado: só "Skip");
  primário `cueSecondary(.compact)` = cápsula de 34 pt, Liquid Glass `.regular.interactive()`, texto `subheadline` semibold `ink`, 14 pt de lado.
- Movimento: flutuante igual à dica do Voice (0,40 s `CueMotion.tipEnter`, opacidade + 10 pt + 0,97; sai em 0,20 s; Reduzir Movimento só fade).
  No lugar: `.opacity + .move(edge:)` (bottom na página/editor, top na revisão), com `.smooth(0.25)` ao fechar. Sem háptico na dica.
- Acessibilidade: contêiner `.contain`; título+linha combinados; olho com rótulo "Step n of 6" e dica "Shows every step". **Sem anúncio** quando
  aparece.

**`VoyageFloatingTip`** (`Screens/FirstVoyage/VoyageFloatingTip.swift`): só o "onde/quando" do cartão acima (um `VStack` de altura zero que
sempre existe; espera 1,2 s de quietude; troca de passo tira a dica na hora). Fica dentro do `safeAreaInset` com 12 pt de lado; em Takes 10 pt
acima da tab bar.

**`VoyageStepsSheet`** (`Screens/FirstVoyage/VoyageStepsSheet.swift`): folha do tamanho do conteúdo, fundo `Palette.sheetNight` (#14162A a 96%),
cantos 38 (`Metrics.sheetRadius`), alça visível, botão fechar de vidro do sistema à esquerda. Gutter 16, bottom 20. Título `cueFont(.title2,
.bold)` (22 pt) `ink`; subtítulo `subheadline` `ink2` 6 pt abaixo; lista `VStack(spacing: 4)` 18 pt abaixo; "Hide guide" `body` semibold `ink2`
(botão em texto, 44 pt) e a nota `caption` (12 pt) `ink2` centralizada, 20 pt abaixo.

**`VoyageStepRow`** (`Screens/FirstVoyage/VoyageStepRow.swift`): `HStack(spacing: 14)`, mínimo 56 pt. Marca 28×28: feito = círculo
`Palette.acc` com `checkmark` 13 pt heavy em `accInk` (preto); próximo = anel 2 pt `acc` com ponto `acc` de 10 pt; adiante = número
`footnote` bold `ink2` dentro de anel 2 pt `ink3` (#E1E4F5 a 45%). Título `body` semibold `ink`; detalhe `footnote` (13 pt) em `aiText` no próximo,
`ink2` nos outros. O próximo ganha fundo `aiFill` + borda 1 pt `aiBorder`, cantos 16, 12 pt de respiro lateral que sangra para fora (−12), e
botão **Start** `cuePrimary(.compact)` (cápsula 34 pt, vidro tingido de amarelo, texto preto).

**`VoyageAnnouncer`** (`Screens/FirstVoyage/VoyageAnnouncer.swift`): sem visual próprio; usa o toast ✓ do app (entra descendo 8 pt em 0,25 s, sai
em fade 0,2 s, `DESIGN_PROJECT.md` §34) e `Haptics.soft()`.

### Observações (4)

1. **Os passos 1 e 2 quase nunca aparecem, e a lista diz "Done" para o que o criador não fez.** O onboarding cria o roteiro
   (`OnboardingView.swift:116-120`) e a prática toca o teleprompter (`PrompterView.swift:115-117`), então "Write your first script" fica feito
   sem escrever, e a dica "Your idea, Cue's draft." / "Get an idea" e a de prática só aparecem para quem pulou o play. Também "Pick" conta como
   feito quando o take só foi **aberto no editor** (`edit != nil`, `VoyageProgress.swift:23`), sem ★.
2. **"Estrela" significa duas coisas.** O onboarding 1.7 ("Your first video. Your first star.") e a revisão (`TakeReviewView.swift:581-588`,
   "The first take Cue ever recorded lights the first star") dão a primeira estrela ao **primeiro take gravado**; a viagem diz que ela vem do
   **primeiro compartilhamento** ("Lights your first star", "Six steps from an idea to your first star", "Your first star is out there").
   E "★" no olho da dica é progresso, enquanto no passo 4 "★" é marcar o melhor take. Além disso "voyage" no código também é o capítulo 1.3 do
   onboarding (`Screens/Onboarding/Voyage/`, `-uiTestOnboardingStep voyage`), que nada tem a ver com o guia.
3. **Texto que promete mais que o código.**
   - Share: "Cue opens %@ with your video and caption. You post." (`VoyageStep.swift:81-82`), mas com `integrationsEnabled = false`
     (`ShareIntegrationConfiguration.swift:25`) todo destino vai para a **folha do sistema**, e o LinkedIn só salva em Fotos e não abre o app
     (`SHARING.md` §3).
   - Rascunho: "Tap Sounds like me and Cue learns from it." (`ScriptPageView.swift:522`) é fixo, mas o botão só existe se o rascunho foi escrito
     pela Apple **com** a voz e a voz ainda não foi aprovada (`ScriptDetailViewModel+VoicePreview.swift:12-26`; a prévia nem existe para a Ultra AI,
     `+Page.swift:382`); a prévia também some ao reabrir a página.
   - Write: "Cue learns as you write." (`VoyageStep.swift:73`). O `DraftLearningService` só aprende quando o roteiro é **gravado** com ≥ 20% e 8
     palavras mudadas (§33), o que contraria a regra "aprende com você só onde é verdade".
   - Polish flutuante: o botão "Add captions" abre o editor (`.edit`, `VoyageNavigator.swift:33`), onde outra dica pede "Add captions" de novo.
     Já existe `ReviewLaunchAction.editTool(_)` para abrir direto na ferramenta.
   - Pick com 1 take: "Star your favorite. The others stay in Takes." sem botão e sem "outros".
4. **Sobreposições possíveis:**
   - **Fim da gravação:** ao fechar o prompter, `MainView.offerIntroduction()` apresenta o convite de notificação `.firstRecording` (ou uma
     apresentação de ferramenta) (`MainView.swift:66-68, 340-351`), e 0,7 s depois o `VoyageAnnouncer` mostra "Recorded · Next: pick a take"
     com háptico. O `isFree` olha só `prompter` e toast, não `presentation.sheet` (`VoyageAnnouncer.swift:30-32`). A viagem não conversa com
     `NotificationService.introducedToday`, ao contrário da dica do Voice.
   - **Dica do Voice logo depois do ✕ da viagem:** o ✕ zera `floatingStep`, e a dica do Voice entra 1,2 s depois, se os portões dela passarem
     (`ScriptsView.swift:81`, `TakesView.swift:64`). E as duas se **empilham** se a viagem volta com a dica do Voice já de pé (toggle em Ajustes,
     ou passo novo), porque o host do Voice não recolhe uma dica já mostrada (`VoiceQuestionTipHost.swift:64`).
   - **Cartão "Continue posting"** (`MainView.swift:80-86`, 104 pt acima do fundo em Scripts/Takes) com fila pendente e nenhum envio confirmado
     ("Not yet"/cancelou): a dica "Ready for …" acima do dock pode disputar o mesmo espaço (não conferido na imagem).
   - **Revisão:** a dica Pick e o chip "Take 2 of 3" estão ambos em `overlay(alignment: .top)` (`TakeReviewView.swift:127-141`), e o chip fica
     por baixo durante 1,4 s depois de um deslize.
   - **Start dentro do fluxo:** a folha de passos aberta da dica na revisão, no editor ou no envio chama `openReview` (`VoyageNavigator.swift:30-36`),
     que troca o `prompter` já apresentado. Isso pode fechar e reabrir a capa (não verificado).
5. **Tradução PT-BR com sentido errado:** o botão "Start" da lista é **"Início"** (substantivo, chave compartilhada; deveria ser "Começar"); o
   estado "Done" da linha (texto e VoiceOver) aparece como **"OK"**, porque a chave é a mesma do botão Done. Literais esquisitos: "Um primeiro
   rascunho. Seu para mudar.", "Faça funcionar sem som". Nenhuma tradução falta (todas com 19 idiomas). "Record a take" está `stale` no catálogo,
   embora usada (`VoyageStep.swift:26`): um `strings.py stale --remove` a apagaria.
6. **Ajustes:** a busca mostra "First video guide" sempre (`SettingsSearchResults.swift:15`, sem `isShown`). Para quem é `notNeeded` (já tinha
   compartilhado, nunca viu o guia) aparece "You finished your first voyage", desabilitado (`PersonalizeEntryRow.swift:66`). A folha manda a
   "Settings › Personalize", mas o toggle se chama "First video guide" e fica em "Getting started", não "first voyage".
7. **Onde o criador fica sem guia:** depois de "Hide guide" ou do primeiro envio não há mais nada do guia (só a dica do Voice); o ✕ "pela sessão"
   dura até o processo morrer, então pode sumir por dias; o passo 1 "Get an idea" depende de ideias do Apple Intelligence: sem IA, a dica
   "Your idea, Cue's draft." pode levar a uma tela sem rascunho (não verificado). Nenhuma dica é anunciada ao VoiceOver quando aparece.
8. **Comentários e testes que descrevem um cartão que não existe mais:** `DefaultsKey.swift:82` ("tips closed, segments lit"),
   `VoyageProgress.swift:9` ("the card names…"), `LaunchOptions.swift:51` ("its card, strip or tips"), e `PaletteContrastTests.swift:241-253`
   ainda mede "a done segment" e "its card". A chave de código `celebrated` (`VoyageMarks.swift:29`) é de propósito, por compatibilidade. Não
   achei tipos sem uso: todos os modelos (`VoyageStage`, `VoyageStep`, `VoyageMarks`, `VoyageTipPlace`, `VoyageTipOutcome`,
   `VoyageTelemetryEvent`) são usados.



Caminhos relativos a `/Users/iagoxavierdelima/Desktop/Projects/CueStudio/Cue Studio/` salvo indicação. Cópia em inglês = chave do String Catalog;
PT-BR = localização `pt` de `SupportFiles/Localizable.xcstrings` (ou `InfoPlist.xcstrings`). "19" = traduzida nos 19 idiomas além do inglês (completa).
O app é **só escuro** (`Screens/Main/RootView.swift:34`, `.preferredColorScheme(.dark)`): os tokens abaixo têm um valor só; quando há variante
"Aumentar Contraste" ela vem entre parênteses.

## 5. Onboarding

**Onde e quando.** `OnboardingView` fica por cima do app inteiro (ZStack em `Screens/Main/RootView.swift:21-24`, fade 0,5 s) enquanto
`OnboardingService.isActive` (`Managers/Onboarding/OnboardingService.swift:35`). Aparece **uma vez**, numa instalação nova: `AppServices`
(`SupportFiles/AppServices.swift:264-266`) chama `resolve(hasExistingContent:)`; quem já tem roteiro, take ou tópico no perfil pula a história e
também fica com `firstStarShown = true` (`OnboardingService.swift:38-44`). **Não há Skip nem "I already use Cue"** (decisão do dono), **nem botão
de voltar** entre capítulos. O capítulo atual (`step`) vive só em memória (`OnboardingService.swift:16`). **Não dá para rever**: Settings não tem
"rever introdução"; "Delete my Cue data" (`Managers/Privacy/DataEraserService.swift:90-120`) não apaga `onboardingCompleted` nem `firstStarShown`;
só desinstalar. Settings › Personalize › Getting started só religa o guia do primeiro vídeo (`Screens/Settings/Personalize/PersonalizeView.swift:44-51`).

**Barra de capítulos** (`OnboardingChrome.swift`): 5 cápsulas de 22 × 4 pt, espaço 5; feitas branco 85%, atual `acc`, futuras `fill`. 1.2→seg.1 …
1.5 e 1.6 acendem o 4º; o 5º "é da primeira estrela", que nunca aparece nessa barra (`Models/OnboardingStep.swift:23-29`).

**Transição entre capítulos:** capítulo sai em 0,22 s (`easeIn`, escala 0,97, −8 pt, blur 4) e o próximo entra 0,1 s depois (0,55 s "light", de
1,03, +14 pt, blur 4) (`DesignSystem/Motion/DepthTransition.swift`, `CueMotion.chapterExit/Enter`); névoa troca em 0,8 s, céu desliza −24 pt por
capítulo em 0,95 s (paralaxe). Reduzir Movimento: fade 0,2 s. Háptico `selection` a cada avanço (`OnboardingView.swift:111-114`).

### 5.1 Tabela dos passos

| ID | Tipo visual | Tela/âncora | Gatilho e condições | Frequência | EN | PT-BR | Botões → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|---|
| 1.1 Welcome | Cena em tela cheia (estrela que acende o "C", palavras, botão) | `WelcomeChapter` sobre `BgWash.welcome` | Primeiro lançamento sem conteúdo | Uma vez | Wordmark (a11y "CUE STUDIO"); título **A teleprompter made for your creative universe.**; linha **Write your script, read it while you look at the camera, and record. Then add captions, edit, and share.**; cápsulas **TELEPROMPTER · AUTO CAPTIONS · ✦ AI SCRIPTS** | **Um teleprompter feito para o seu universo criativo.** / **Escreva seu roteiro, leia olhando para a câmera e grave. Depois coloque legendas, edite e compartilhe.** / TELEPROMPTER · LEGENDAS AUTOMÁTICAS · ✦ ROTEIROS COM IA | **Get started** (Começar) → 1.2 | `Screens/Onboarding/Welcome/WelcomeChapter.swift:107-145`, `WelcomeTitle.swift:16,41` | `-uiTestOnboarding` (+ `-uiTestWelcomeOpening` para a abertura real ~8 s; `-uiTestWelcomeAt <s>` congela) |
| 1.2 Topics | Título + universo (YOU + mundos em órbita) + chips + contador | `UniverseChapter` | Depois de 1.1 | Uma vez | **CHAPTER 1 · YOUR TOPICS** · **What do you usually talk about?** · **Pick up to 3. Cue uses them for your video ideas, and each one becomes a world.** · contador: **PICK 1 TO 3 TOPICS** / **%lld OF %lld · ADD MORE OR CONTINUE** (1) / **… ADD ONE MORE OR CONTINUE** (2) / **… TAP ONE TO SWAP** (3, dourado) · chip **+ Your own** → alerta **Your own topic** (campo exemplo "Budget travel", **Add**/**Cancel**) · erros **Already added.**, **Did you mean "%@"?** **Use** / **Keep mine** · a11y do universo "Your universe" | CAPÍTULO 1 · SEUS TEMAS · Sobre o que você costuma falar? · Escolha até 3. O Cue usa esses temas nas suas ideias de vídeo, e cada um vira um mundo. · ESCOLHA DE 1 A 3 TEMAS / %1$lld DE %2$lld · ADICIONE MAIS OU CONTINUE / … ADICIONE MAIS UM OU CONTINUE / … TOQUE EM UM PARA TROCAR · + Seu tema · Seu próprio tema · Já adicionado. · Você quis dizer "%@"? Usar / Manter como está | **Continue** (cinza "Pick a topic"/Escolha um tema até o 1º tema) → 1.3; com 3 escolhidos, tocar outro só dá `Haptics.light` | `Universe/UniverseChapter.swift:76-121,182-235`, `Universe/TopicCounter.swift:17-24` | `-uiTestOnboardingStep universe`, `-uiTestChapterAt <s>`, `-uiTestTopicBirthAt <s>` |
| 1.3 Voyage | Cena de galáxias (redes) + rota + chips de rede | `VoyageChapter` / `VoyageScene` | Depois de 1.2 | Uma vez | **CHAPTER 2 · YOUR FIRST VIDEO** · **Where will you share your videos?** · **Cue sets the frame, the ideal length and the safe zones for that platform.** · **CHOOSE ONE PLATFORM** → **%@ · TAP ANOTHER TO SWITCH** · dica digitada "9:16 · **IDEAL** 1:00–1:30 · **SAFE ZONES ON**/**OFF**" · letras "YOU" na cena | CAPÍTULO 2 · SEU PRIMEIRO VÍDEO · Onde você vai compartilhar seus vídeos? · O Cue define o enquadramento, a duração ideal e as zonas seguras para essa plataforma. · ESCOLHA UMA PLATAFORMA / %@ · TOQUE EM OUTRA PARA TROCAR · ZONAS SEGURAS ATIVAS/DESATIVADAS · (YOU **não traduzido**, ver Obs.) | **Choose a platform** (Escolha uma plataforma, apagado) → **Continue with %@** (Continuar com %@) → 1.4 | `Voyage/VoyageChapter.swift:69-86,119-166`, `VoyageScene.swift:287` | `-uiTestOnboardingStep voyage`, `-uiTestChapterAt`, `-uiTestPlatformAt <s>` |
| 1.4 First script | Console de transmissão (`MessageCard`) com o roteiro chegando palavra a palavra + cápsula | `ScriptChapter` | Depois de 1.3; roteiro fixo `OnboardingScript.practice()` (sem IA) | Uma vez | **CHAPTER 3 · YOUR FIRST SCRIPT** · **Your first script. Ready to read.** · **Read it out loud on the teleprompter.** · card: **✦ PREPARING YOUR SCRIPT** (até 1,9 s) → **✦ PRACTICE SCRIPT · READY**, **VIDEO FOR · %@**, **%lld SEC** (24 em inglês), **HOOK / BODY / CTA** · cápsula **SCRIPT READY · LET'S TRY IT** · nota **It's just practice. Nothing is recorded.** | CAPÍTULO 3 · SEU PRIMEIRO ROTEIRO · Seu primeiro roteiro. Pronto para ler. · Leia em voz alta no teleprompter. · ✦ PREPARANDO SEU ROTEIRO → ✦ ROTEIRO DE PRÁTICA · PRONTO · VÍDEO PARA · %@ · %lld SEG · GANCHO / CORPO / CTA · ROTEIRO PRONTO · VAMOS TESTAR · É só uma prática. Nada é gravado. | **Try the teleprompter** (Testar o teleprompter; brilho a cada 5 s, entra aos 5,9 s) → **cria o roteiro na biblioteca e aplica tópicos + plataforma ao perfil** (`OnboardingView.swift:117-121`, `OnboardingViewModel.swift:117-136`) → 1.5 | `Message/ScriptChapter.swift:48-79`, `Message/MessageCard.swift:94,120-144,185-193` | `-uiTestOnboardingStep script`, `-uiTestChapterAt` |
| Roteiro de prática | Texto lido na 1.6 (e que fica em Scripts) | Biblioteca | Criado na 1.4 (ou na 1.6 se a biblioteca estiver vazia) | Uma vez | Título **From idea to video**; HOOK **An idea is good. Seeing it become a video is even better.**; BODY (com voz) **Cue Studio helps me write it, read it with a teleprompter that follows my voice, and record it right here. I can add automatic captions and edit my take before sharing it.**; BODY (sem voz) **… read it on a teleprompter, and record it right here. …**; CTA **My idea gets to sound like me and reach the people I made it for.** | Da ideia ao vídeo · Uma ideia é boa. Ver essa ideia virar vídeo é ainda melhor. · O Cue Studio me ajuda a escrever, ler com um teleprompter que segue a minha voz e gravar aqui mesmo. Posso colocar legendas automáticas e editar meu take antes de compartilhar. · (sem voz) … ler num teleprompter e gravar aqui mesmo. … · Minha ideia soa do meu jeito e chega às pessoas para quem eu a fiz. | — (troca de versão automática enquanto o texto está escurecido: `PrompterViewModel+Practice.swift:44-51`) | `Models/OnboardingScript.swift:26-35` | — |
| 1.5 Permissions | Arte VOICE/CAMERA + título + cartão com 2 linhas + nota | `VoiceChapter` | Depois de 1.4 | Uma vez | **CHAPTER 4 · CAMERA & VOICE** · **Let the text follow your voice.** (quebrada em 2 linhas) · **The microphone lets the teleprompter follow your words, on this iPhone. The camera shows you while you read.** · linhas **Microphone** / **So the teleprompter follows your voice**; **Camera** / **So you can see yourself while you read** · estado: **Allow** (próximo em amarelo), **Next** (`step.next`), **✓ Allowed**, **Off · Turn on** · nota: **Cue only records when you tap Record.**; recusas (3 textos, abaixo) · arte "VOICE"/"CAMERA" | CAPÍTULO 4 · CÂMERA E VOZ · Deixe o texto seguir a sua voz. · O microfone deixa o teleprompter seguir as suas palavras, neste iPhone. A câmera mostra você enquanto lê. · Microfone / Para o teleprompter seguir a sua voz · Câmera / Para você se ver enquanto lê · Permitir / Próximo / ✓ Permitido / Desligado · Ativar · O Cue só grava quando você toca em Gravar. · (VOICE/CAMERA **não traduzidos**) | Linha não respondida → prompt do sistema; linha negada → Ajustes do iOS; **Continue** pede o que falta (mic + Fala, depois câmera), espera 0,6 s e vai para 1.6; nunca trava | `Voice/VoiceChapter.swift:52-139,194-223`, `OnboardingViewModel.swift:54-112`, `Voice/VoicePermissionsArt.swift:291-293` | `-uiTestOnboardingStep voice`, `-uiTestPermissions granted\|denied`, `-uiTestChapterAt <s>` (a câmera "libera" aos 3,7 s) |
| 1.5 recusa (mic + câmera) | Nota no lugar da nota normal | `VoiceChapter.footnote` | `microphone == .denied && camera == .denied` | Enquanto negado | **No problem, you can still practice. The text will scroll at a steady pace. Turn them on in Settings to follow your voice and record.** | Sem problema, você ainda pode praticar. O texto vai rolar em velocidade constante. Ative nos Ajustes para seguir a sua voz e gravar. | Linhas "Off · Turn on" → Ajustes | `VoiceChapter.swift:130-139` | `-uiTestPermissions denied` |
| 1.5 recusa (só mic) | idem | idem | só mic negado | idem | **No problem, you can still practice. The text will scroll at a steady pace. Turn on the microphone in Settings to follow your voice.** | Sem problema, você ainda pode praticar. O texto vai rolar em velocidade constante. Ative o microfone nos Ajustes para seguir a sua voz. | idem | idem | — |
| 1.5 recusa (só câmera) | idem | idem | só câmera negada | idem | **No problem, you can still practice. Turn on the camera in Settings when you want to record.** | Sem problema, você ainda pode praticar. Ative a câmera nos Ajustes quando quiser gravar. | idem | idem | — |
| 1.6 Practice | Gravador real (`PrompterView`, `isPractice`) com câmera em tela cheia, caixa de 310 pt, cápsula de voz, cartão de vidro, barra inferior | `SelfieModeView` + `Screens/Prompter/Practice/*` | `OnboardingView.startPractice` abre o prompter (`OnboardingView.swift:124-132`) | Uma vez | Etiqueta **✦ PRACTICE · NOT RECORDING**; play **TAP TO START** (a11y **Start practice**); contagem **GET READY · 3 · 2 · 1 · READ!**; cartão antes: **Your teleprompter practice.** + instrução (3 variantes) + **Nothing is recorded.**; cartão no fim: **You've got it. Ready to record?** / **Record this script for real, or start with your own.**; cápsula de voz (7 estados, abaixo) | ✦ PRÁTICA · SEM GRAVAR · TOQUE PARA COMEÇAR · PREPARE-SE · LEIA! · Sua prática no teleprompter. · Nada é gravado. · Mandou bem. Vamos gravar? · Grave este roteiro de verdade ou comece com o seu. | **Explore Cue first** (Explorar o Cue primeiro; sempre) → fecha o prompter, onboarding concluído, aba Scripts; **Record my first video** (Gravar meu primeiro vídeo; amarelo com ponto vermelho, só depois do play) → o mesmo gravador vira o real | `Practice/PracticeTopBar.swift:24-37`, `PracticeBoxOverlay.swift:55-125`, `PracticeMessageCard.swift:18-27`, `PracticeBottomBar.swift:39-87`, `PrompterView.swift:128-137` | `-uiTestOnboardingStep practice`, `-uiTestVoiceFollowing listening\|preparing\|unavailable`, `-uiTestPermissions denied` |
| 1.6 instrução do cartão | Linha no cartão | `PracticeVoice.instruction` | conforme `practiceVoice` | — | voz/preparando: **Tap play and wait for the count. Then read out loud: the text follows your voice.** · sem palavras: **… the text moves while you talk.** · sem mic: **Tap play and wait for the count. Then read: the text scrolls at a steady pace.** | Toque no play e espere a contagem. Depois leia em voz alta: o texto segue a sua voz. / … o texto anda enquanto você fala. / Toque no play e espere a contagem. Depois leia: o texto rola num ritmo constante. | — | `Practice/PracticeVoice.swift:65-72` | idem |
| 1.6 cápsula de voz | Cápsula de vidro 44 pt sob a caixa, onda de 9 barras | `PracticeVoiceStatus` | estado do reconhecimento | contínuo | **Getting ready to follow your voice** · **Getting Voice Following ready · 40%** (ou sem %) · **Voice Following is on** (antes do play) · **Waiting for your voice** · **Following your voice** · **Moves while you talk** · **Microphone off · Steady scroll** (a11y label "Voice Following") | Preparando para seguir a sua voz · Preparando o Seguir voz · %@ · O Seguir voz está ativado · Esperando a sua voz · Seguindo a sua voz · Rola enquanto você fala · Microfone desligado · Rolagem constante | — | `Practice/PracticeVoice.swift:32-53`, `PracticeVoiceStatus.swift:31-54` | `-uiTestVoiceFollowing …` |
| 1.6 sem microfone | Linha + botão de vidro acima dos botões | `PracticeBottomBar.microphoneNote` | `practiceVoice == .steady` (mic negado) | Enquanto negado; ao voltar dos Ajustes relê (`refreshPracticeMicrophone`) | **Turn on the microphone so the text can follow your voice.** | Ative o microfone para o texto seguir a sua voz. | **Open Settings** (Abrir Ajustes) → Ajustes do iOS | `PracticeBottomBar.swift:67-87` | `-uiTestPermissions denied` |
| 1.6/gravador sem câmera | Mensagem no lugar da imagem da câmera | `CameraBackdrop` | `camera.status == .unauthorized` | Enquanto negado | **Camera access is off** / **Allow Camera and Microphone in Settings to record.**; sem câmera: **No camera here** / **No camera found · Studio mode still works**; falha: **The camera stopped** + motivo | O acesso à câmera está desligado / Permita Câmera e Microfone em Ajustes para gravar. · Sem câmera aqui / Nenhuma câmera encontrada · O modo Studio ainda funciona · A câmera parou | **Open Settings** (só no caso negado) | `Screens/Prompter/Camera/CameraBackdrop.swift:38-52,88-104` | `-uiTestPermissions denied` |
| Gravador sem microfone (depois do onboarding) | Cartão de aviso sobre os controles | `MicrophoneNeededCard` | `!audio.isMicrophoneAllowed`, fora da prática e sem gravar | Enquanto negado | **Cue needs the microphone** | O Cue precisa do microfone | **Open Settings** | `Screens/Prompter/Controls/MicrophoneNeededCard.swift:20-27`, `SelfieModeView.swift:226-227` | `-uiTestPermissions denied` |
| Photos negado (exportação) | Cartão na revisão + toast | `PhotosDeniedCard` | Save to Photos recusado (`PHPhotoLibrary.requestAuthorization(.addOnly)` no momento de salvar, sem pré-prompt) | Até fechar ou o próximo save dar certo | **Photos is off for Cue** / **Allow it to save your video.**; toast **Photos is off · the video wasn't saved there** | Fotos está desativado para o Cue / Permita o acesso para salvar seu vídeo. · Fotos está desligado · o vídeo não foi salvo lá | **Open Settings** · ✕ | `Screens/TakeReview/Sections/PhotosDeniedCard.swift:21-35`, `TakeReviewViewModel.swift:485`, `Managers/Export/PhotoLibraryManager.swift:14,29` | — |
| Fim do onboarding | — | — | "Explore Cue first" ou "Record my first video" (`PrompterView.finishPractice` chama `onboarding.complete()`); ou o prompter fechado durante a prática (`OnboardingView.swift:77-79`) | Uma vez | — | — | Explore → aba **Scripts** com "From idea to video" na lista (o guia do primeiro vídeo já conta Write e Practice feitos, então a 1ª dica é Record); Record → gravação real com Voice Following; ao rever o 1º take toca a **1.7 First star** (§6) | `PrompterView.swift:128-137`, `OnboardingViewModel.swift:139-143` | — |

**Quando cada prompt do sistema aparece.** Nenhum antes da 1.5. Na 1.5: tocar a linha **Microphone** (ou **Continue** com algo pendente) → prompt do
**microfone**; se permitido, logo em seguida o prompt de **Reconhecimento de Fala** (sem linha nem explicação próprias; `OnboardingViewModel.swift:96-105`);
depois (linha **Camera** ou o mesmo Continue) → prompt da **câmera**. `Haptics.success()` em cada "permitido". **Fotos** (só adicionar): no primeiro
"Save video"/"Also save to Photos", sem pré-prompt. **Notificações**: fora do onboarding (convite `NotificationInviteSheet` depois da primeira
gravação, `Screens/Main/MainView.swift:340-351`; assunto de outra seção). **Rede local**: quando o Remote é usado. Fotos para importar usam o seletor
do sistema (sem permissão de leitura: não há `NSPhotoLibraryUsageDescription`).

**Textos de permissão do sistema** (`SupportFiles/InfoPlist.xcstrings`, 20 idiomas cada; o inglês também em `Config/App.xcconfig:28-32`):

| Chave | EN | PT-BR |
|---|---|---|
| `NSCameraUsageDescription` | Cue records your takes with the camera while your script scrolls under the lens. | O Cue grava seus takes com a câmera enquanto o roteiro rola logo abaixo da lente. |
| `NSMicrophoneUsageDescription` | Cue records your voice with each take and for voice-overs, can follow your voice to scroll the script, and listens when you dictate an idea. | O Cue grava sua voz em cada take e nas narrações, pode seguir sua voz para rolar o roteiro e ouve você quando dita uma ideia. |
| `NSSpeechRecognitionUsageDescription` | Cue recognizes your speech on this iPhone to keep the script on the line you're reading and to turn an idea you dictate into text. Nothing leaves the device. | O Cue reconhece sua fala neste iPhone para manter o roteiro na linha que você está lendo e transformar em texto uma ideia que você dita. Nada sai do aparelho. |
| `NSPhotoLibraryAddUsageDescription` | Cue saves the takes you export to your photo library. | O Cue salva na sua fototeca os takes que você exporta. |
| `NSLocalNetworkUsageDescription` | Cue connects to your other iPhone or iPad nearby, so one can control the teleprompter on the other. | O Cue se conecta ao seu outro iPhone ou iPad por perto, para que um controle o teleprompter do outro. |

Todas as cópias de onboarding listadas acima têm 19 traduções (nenhuma falta no catálogo); as exceções são textos que **não passam pelo catálogo**
(ver Observações).

### Componentes visuais (5)

- **Fundo do primeiro voo** (`OnboardingView.swift:48-57`, `OnboardingSky.swift`, `BgWash+Presets`): `Palette.Flight.night` #07080E, uma névoa por
  capítulo (`BgWash.welcome/universe/voyage/message/permissions/firstStar`: manchas radiais de luz violeta/dourada), céu estrelado com paralaxe.
  Texto cresce até `accessibility1` (alguns capítulos param em `xxxLarge`).
- **Cabeçalho de capítulo** (`OnboardingHeading.swift`): coluna à esquerda, 20 pt de margem, espaço 10. Rótulo `hudFont` (mono) em maiúsculas,
  tracking 1,4, `accText` #FFD60A; título `cueFont(30, .bold)`, tracking −0,6, `ink` branco, header de VoiceOver; subtítulo `cueFont(15)` `ink2`
  (#E1E4F5 a 62%, 80% em Aumentar Contraste). Cada peça sobe 16 pt saindo de blur 10 em 0,75 s, `cubic-bezier(.16,1,.3,1)`, um pouco defasadas.
- **Botão primário do voo** (`OnboardingPrimaryButton.swift`): cápsula de 54 pt de altura, largura total (16–20 pt de margem), `acc` #FFD60A com
  texto preto (`accInk`) `cueFont(17, .bold)`; brilho branco que cruza a cada 5 s (`shineSweep`). Desabilitado "dimmed": amarelo a 20% com texto
  `quietInk` (= `inkSoft`, branco 80%); "grey" (1.2): `fill` (#6E7496 a 26%) com texto `ink3`. Aperto: `pressResponse`.
- **1.1 Welcome**: quadro de 390 × 844 escalado do topo; estrela com rastro (`StarRibbon`: fita que afina do branco ao dourado em 0,32 s, cabeça branca
  com halo e cruz girando) acende 6 pontos de um "C" (o 6º respira em amarelo), desce às três cápsulas e explode no último ponto. Wordmark letra a letra;
  título `cueFont(34, .bold)`, tracking −0,85, linhas de 40 pt, palavra a palavra (85 ms, saindo do blur); linha `cueFont(16)` `ink2`. Cápsulas
  (`WelcomePill`): mono 10 semibold, tracking 0,8, 26 pt de altura, 9 pt de padding, fundo `fill` (a de IA `aiFill` #9D8CFF 17% com texto
  `aiTextStrong` #E4DEFF); ao serem atingidas pulam 12 pt e viram **amarelo sólido com letras pretas**, oval de luz atravessa, anel `acc` 1,2 pt de 28 pt
  abre, brilho 12 pt. Botão "Get started" 82 pt acima da borda (48 sem Home Indicator). Hápticos: ponto `soft`, palavra `apply`, explosão `success`.
  Reduzir Movimento: estado final parado.
- **1.2 Topics**: universo (`OnboardingUniverseCanvas`, 96–300 pt de altura): estrela branca "YOU" (mono 10) com raios, uma órbita inclinada (−12°,
  achatada a 0,42) por tema, raios 70/108/146 pt, planetas de 18/14/16 pt nas cores `Palette.World`. Ao entrar, a estrela da 1.1 vem do canto
  superior direito e pousa no núcleo (`soft` aos 1,25 s). Chip de tema (`OnboardingTopicChip`): cápsula 32 pt, `cueFont(12.5, .semibold)`, fundo `fill`
  texto `ink2`; escolhido: branco (`chipOn`) com texto preto e uma barra de 3 × 14 pt na cor do mundo; com 3 escolhidos os outros a 40%. "+ Your own":
  contorno tracejado `ink3` (1 pt, 4/3). Contador: 3 barras de 3 × 16 pt (contorno branco 40%, enchem na cor do mundo com mola 0,45 s
  `cubic-bezier(.3,1.5,.5,1)`) + mono 12 semibold tracking 1,2 (`quietInk`; dourado `starGold` #FFE680 com 3). Nascimento do tema (`TopicBirth`): luz sai
  do chip, voa até a órbita, faíscas e anéis, planeta salta, nome chega (~2,6 s). Háptico `apply` ao tocar.
- **1.3 Voyage**: `VoyageScene` (Canvas, tela cheia): a galáxia do criador (×1,12) e cinco galáxias de rede (×1,25) encaixadas entre o título e os chips
  (`VoyageFit`, 14 pt de folga), letras Y·O·U mono 38 bold lilás (`starLilac` #E4DEFF); escolher traça uma rota de luz (2,4 s, `success` na chegada).
  Chips de rede (`VoyageChip`): cápsula 38 pt, `cueFont(14.5, .semibold)`, ponto de 8 pt na cor da rede, fundo `fill`/texto branco; escolhido
  branco/preto com onda. Linha mono 12 (cinza → dourado); dica mono 10 `ink2` revelada da esquerda em 34 passos. Hápticos: `soft` por galáxia que nasce
  (a última `light`), `soft` ao escolher.
- **1.4 Console (`MessageCard`)**: cartão com raio 22 (moldura externa 24), mínimo 327 pt, fundo aurora sobre `nightIndigo` #1B1740, borda externa
  `nightViolet`/`lilac` a 32%, anel de luz que gira na borda (gradiente angular lilás → `acc` → creme, 2 pt, 2,8 s/volta), quatro cantoneiras que fecham
  (×1,5 → 1, 0,8–1,4 s), partículas subindo, linha de varredura no fim. Sombra violeta (`cardShadow` #281478 a 45%, raio 25, y 20). Cabeçalho mono 10,5:
  "✦ PREPARING YOUR SCRIPT" (`aiText` #B4A7FF, brilho e três pontos) → "✦ PRACTICE SCRIPT · READY" (`starLilac`). "VIDEO FOR · TIKTOK" mono 10 com ponto
  da cor da rede; anel de progresso e "24 SEC" em `starGold`. Partes: rótulos mono 10 (HOOK `accText`; BODY/CTA `Flight.ink` a 60%); palavras em
  21/19/17/15/13 pt (o maior que cabe), HOOK/BODY brancas, CTA lilás com cursor. Cápsula "SCRIPT READY · LET'S TRY IT": mono 11,5 dourado sobre `acc`
  10%, borda `acc` 40%, brilho 11; um cometa corre por ela.
- **1.5 Permissões**: arte `VoicePermissionsArt` (390 × 200 escalada até ×1,15): dois orbes VOICE e CAMERA ligados por um feixe com luzes correndo;
  a lente acende quando a câmera é liberada. Cartão de linhas: `surface` #161826, raio 20, borda `separator` 0,5 pt, divisória `separator`. Linha de
  64 pt: ícone SF `mic` / `camera` 16 semibold em azulejo 36 × 36 raio 12 (tinta `accText` a 14% / `aiText` a 18%), título `cueFont(16, .semibold)`
  `ink`, detalhe `cueFont(12.5)` `ink2`; selo à direita (26 pt, 10 pt de padding, `cueFont(12.5, .semibold)`): "Allow"/"Next" com borda (`acc` 60% se
  próximo, senão `glassBorder` #B4A7FF 22%), "✓ Allowed" `successText` #34C759 sobre `success` 16% (entra com escala 0,6), "Off · Turn on" `warnText`
  #FF9F0A sobre `warnSoft`. Nota `cueFont(12.5)` `ink2` centrada.
- **1.6 Prática** (`SelfieModeView` com `isPractice`): câmera em tela cheia (borrada 0,6 + preto 50% atrás do texto), caixa de 310 pt raio 28, texto 24 pt
  borrado 5 pt até o READ!. Topo: barra de segmentos + etiqueta sólida "✦ PRACTICE · NOT RECORDING" (mono 10, `aiTextStrong` sobre `surface3` #2B2F48,
  borda `aiText` 45%, 32 pt). Play: círculo de vidro 76 pt (`glassEffect(.regular.interactive())`), ▶ amarelo, anel `acc` 80% 1,5 pt, brilho;
  "TAP TO START" mono 10,5 `inkSoft`. Contagem: "GET READY" mono 11 dourado, números `cueFont(92, .heavy)` com anéis `acc` 3 pt, "READ!" 44 heavy
  dourado; hápticos `medium` no toque, `rigid` em 3/2/1 (0,6/1,6/2,6 s), `success` no READ! (3,6 s). Cápsula de voz: vidro tingido `Flight.dim` 50%,
  44 pt, ícone (`hourglass`/`waveform`/`mic.slash`) 15 semibold `accText` (ou `warnText` sem mic), texto 15 semibold `ink`, borda `acc` que acende com a
  voz. Cartão: vidro `.regular` raio 22, mínimo 96 pt, título `cueFont(22, .bold)` branco, linhas `cueFont(14)` `quietInk`; o da intro sai 6 pt para
  cima quando o texto anda, o do fim sobe 12 pt (0,6 s). Base: "Record my first video" cápsula 58 pt `acc` com ponto `record` #FF3B30 de 14 pt, brilho
  a cada 5 s e sombra amarela 15; "Explore Cue first" `cueFont(15, .semibold)` `quietInk`, 44 pt; aviso sem mic: `mic.slash.fill` `warnText` + caption
  `ink2` + botão `.cueGlass(.compact)`.
- **VoiceOver**: títulos com `isHeader`; nenhuma mudança de capítulo é anunciada; a contagem GET READY/3/2/1/READ! não é anunciada; cápsula de voz é
  um elemento "Voice Following" com o estado como valor.

### Observações (5)

1. **Sair do app entre a 1.4 e o fim encerra o voo em silêncio.** O roteiro de prática e os tópicos já são gravados na 1.4 (`OnboardingView.swift:117-121`,
   `OnboardingViewModel.swift:117-136`), mas o capítulo atual só existe em memória (`OnboardingService.swift:16`). No próximo lançamento
   `resolve(hasExistingContent:)` vê o roteiro/tópicos e marca o onboarding **e a primeira estrela** como feitos (`OnboardingService.swift:38-44`,
   `AppServices.swift:264-266`): sem permissões pedidas na história, sem prática e sem 1.7. O caso mais provável é o próprio fluxo: a 1.5 e a 1.6
   mandam o criador aos **Ajustes** ("Off · Turn on", "Open Settings") e o iOS costuma encerrar o app quando uma permissão de privacidade muda lá
   (comportamento do sistema; confirmar no aparelho). Ao voltar, ele cai em Scripts sem explicação.
2. **Permissão de Fala sem explicação nem saída.** O prompt de Reconhecimento de Fala vem colado ao do microfone, sem linha própria (`OnboardingViewModel.swift:96-105`).
   Se negado com o mic permitido, `hasDenied` ignora (só mic/câmera, `OnboardingViewModel.swift:60-62`): a 1.5 diz "Cue only records when you tap
   Record." e a prática mostra "Moves while you talk", sem dizer por quê nem onde ligar. O texto da prática troca para a versão sem "follows my voice",
   mas não há caminho de volta aos Ajustes.
3. **Texto fora do catálogo:** "VOICE"/"CAMERA" da arte da 1.5 (`Text(verbatim:)`, `VoicePermissionsArt.swift:291-293`) e as letras "YOU" da 1.3
   (`Text(["Y","O","U"][index])`, String, não chave, `VoyageScene.swift:287`) aparecem em inglês nos 20 idiomas, enquanto a 1.2 mostra "VOCÊ"
   (`OnboardingUniverseCanvas.swift:133`, chave "YOU" = "VOCÊ").
4. **"on this iPhone" num app que voltou ao iPad** (decisão de 26/10, `ipad-support-back`): subtítulo da 1.5 ("…follow your words, on this
   iPhone", `VoiceChapter.swift:54`) e `NSSpeechRecognitionUsageDescription` ("…on this iPhone…"). No iPad, o texto fica errado.
5. **Câmera negada, mensagem errada:** `CameraBackdrop` diz "Allow Camera and Microphone in Settings to record." mesmo quando o microfone está
   permitido (`CameraBackdrop.swift:40-41`); na prática (que não grava) também fala em "to record".
6. **"✦ PREPARING YOUR SCRIPT"** com o ✦ da IA e três pontos por 1,9 s (`MessageCard.swift:94`, `MessageTimeline.swift:12`) sugere que algo está
   sendo escrito/gerado, mas o roteiro é fixo e já está pronto (decisão do dono: "nada de IA no onboarding"). O ✦ promete IA que não existe ali.
7. **Contraste/tokens fora da regra do CLAUDE.md:** rótulos BODY/CTA usam `Palette.Flight.ink.opacity(0.6)` como cor de texto (`MessageCard.swift:189,192`);
   o botão desabilitado cinza "Pick a topic" escreve em `ink3`, que é "só para o que não precisa ser lido" (`OnboardingPrimaryButton.swift:24`,
   `UniverseChapter.swift:103-106`). O §35 diz que BODY foi medido em 4,9:1, mas o padrão é proibido; o `ink3` do botão não está medido.
8. **Terminologia "first video" com dois sentidos:** a 1.3 é "CHAPTER 2 · YOUR FIRST VIDEO" (escolha de rede) e a prática oferece "Record my first video";
   depois, "first video" é o primeiro **take** na 1.7 e o primeiro **compartilhamento** no marco e em Your universe (§6, Obs. 1). Mesma expressão
   para três momentos.
9. **Sem voltar e sem rever:** não há "voltar" entre capítulos (tópico ou rede errada só se corrige em Settings), e o onboarding não pode ser revisto:
   nem Settings nem "Delete my Cue data" apagam `onboardingCompleted` (`DataEraserService.swift:90-120`); este último recomeça só o guia do primeiro vídeo.
10. **Microcópia:** PT da cápsula "Rola enquanto você fala" e do cartão "o texto anda enquanto você fala" para o mesmo estado (`PracticeVoice.swift:49,69`);
    "Off · Turn on" vira "Desligado · Ativar" (no EN é um selo, no PT parece um interruptor).
11. **Código/documentação velhos:** `RootView.swift:9-10` diz "Cue has no onboarding gate: a first run simply shows the empty library" (falso);
    comentários de `VoyageChapter.swift:10-11` e `OnboardingPrimaryButton.swift:11` falam em "Choose a galaxy"/"Head to {platform}"; `PracticeOutcome.swift:10-12`
    cita "Record it for real"/"Not now — take me to my studio" (com travessão). Strings mortas: "CHAPTER 5 · PRACTICE" (`OnboardingStep.swift:39`,
    `.practice.chapterLabel` nunca é usado) e o parâmetro `star` de `OnboardingUniverseCanvas` (`OnboardingUniverseCanvas.swift:15,59,211-238`, com
    "FIRST TAKE · TODAY") nunca é passado: o desenho não é alcançável. O 5º segmento da barra (`OnboardingStep.swift:23-29`) nunca acende.
12. **Possível colisão no fim:** "Explore Cue first" fecha o prompter, e `MainView` oferece logo uma introdução de ferramenta (`MainView.swift:66-69,340-351`,
    `inAppIntro(afterSession: true)`) no mesmo instante em que o criador chega em Scripts e o guia do primeiro vídeo quer mostrar sua dica. Depende das
    regras do `inAppIntro` (outra seção); vale conferir.

## 6. Celebrações e marcos

Interruptor geral: Settings › Personalize › Feel › **Celebrations** ("A moment of light at each milestone" / "Um momento de luz a cada marco",
`PersonalizeView.swift:82-85`); desligado, não tocam First star, send-off nem marco. Rodapé: "With Reduce Motion on, the sky and the celebrations
rest." Haptics tem chave própria ao lado. As histórias em tela cheia (`StoryCover`, `DesignSystem/Motion/StoryCover.swift`) entram em fade de 0,35 s
e saem em 0,25 s, sem o deslize do sistema, com `isModal` para o VoiceOver.

| ID | Tipo visual | Tela/âncora | Gatilho e condições | Frequência | EN | PT-BR | Botões → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|---|
| 1.7 First star | História em tela cheia (`storyCover`), 8 s, segura aos 7,5 s | Sobre a revisão do take (`TakeReviewView`) | No `onAppear` da revisão: onboarding concluído, `!firstStarShown`, Celebrations ligado, **`takes.count == 1`** | **Uma vez na vida** (marca antes de mostrar) | Selo **✓ SAVED** no take; rótulo **FIRST TAKE · TODAY**; **FIRST VIDEO · FIRST STAR**; **Your first video. Your first star.**; **Saved in Takes. Add captions, edit it or share it to light up your %@ universe.** | ✓ SALVO · PRIMEIRO TAKE · HOJE · PRIMEIRO VÍDEO · PRIMEIRA ESTRELA · Seu primeiro vídeo. Sua primeira estrela. · Salvo em Takes. Coloque legendas, edite ou compartilhe para iluminar seu universo de %@. | **Explore Cue** (Explorar o Cue; primário com brilho) → só fecha a história (fica na revisão); **Edit my video** (Editar meu vídeo) → fecha e abre o editor 0,6 s depois | `Screens/TakeReview/TakeReviewView.swift:201-208,582-597`, `Celebration/FirstStar/FirstStarView.swift:128-206`, `FirstStarScene.swift:299` | `-uiTestFirstStar` (+ `-uiTestStoryAt <s>`) |
| Ready to travel | Tela cheia (`fullScreenCover`) depois de um export | Revisão | "Share to universe" renderiza; Save video; ou o app de destino só abriu (`TakeReviewViewModel.swift:474-564`) | Cada export | **EXPORTED · %@** · **Ready to travel.** · título do roteiro · "0:42 · **CAPTIONS ON** · **NO WATERMARK**" · medidor **FREE EXPORTS** | EXPORTADO · %@ · Pronto para viajar. · LEGENDAS ATIVAS · SEM MARCA D'ÁGUA · EXPORTAÇÕES GRÁTIS | **Share to universe** (redes) · **Save video**/**Saved to Photos** · ícone compartilhar (folha do sistema) · ✕ | `Celebration/ReadyToTravelView.swift:21-162` | `-uiTestShareQueue`, `-uiTestFakeShareSheet` |
| 8.2 Send-off "On its way." | Tela cheia (`fullScreenCover`), mapa do universo com estrelas voando | Revisão | `ExportCelebration.sentOff`: fila "Share to universe" terminou com ≥1 rede "Yes, it's live" (`ShareFlow.swift:200-207`), ou entrega comprovada fora da fila (`TakeReviewViewModel.swift:556,604`). Com Celebrations desligado é apagado na hora (`TakeReviewView.swift:195-200`) | A cada envio confirmado | **SHARED TO %@** / **SHARED TO %lld NETWORKS** · **On its way.** · "0:42 · **captions burned in** · **no watermark**" · link **A new star in your %@ universe · %@ %lld** · rótulos do mapa "TIKTOK · 13", "+1 · TIKTOK", "YOU" | COMPARTILHADO NO %@ / COMPARTILHADO EM %lld REDES · A caminho. · legendas embutidas · sem marca d'água · Uma estrela nova no seu universo de %@ · %@ %lld · VOCÊ | **Share again** (Compartilhar de novo) → folha do sistema; **Done** (OK) → fecha e, se houver, abre o marco 0,6 s depois; link → aba Profile e volta da revisão | `Celebration/SendOffView.swift:90-153`, `SendOffMap.swift:72,106,180`, `TakeReviewView.swift:462-475,605-613` | `-uiTestSendOffAt <s>` (+ `-uiTestShareQueue`) |
| 8.3 Milestone | História em tela cheia (`storyCover`), 4,5 s | Revisão, depois do Done do send-off | `MilestoneService.recordShare` devolve 1, 10, 25 ou 50 vídeos compartilhados **no ano** (e o ícone não foi ganho antes) via "Yes, it's live" (`ShareFlow.swift:163-168`); só aparece ao tocar **Done** no send-off | Uma vez por marco (por ano, mas o `alreadyWon` faz cada ícone valer uma vez na vida, `MilestoneService.swift:63-67`) | **MILESTONE · FIRST VIDEO IN %@** / **MILESTONE · %lld VIDEOS IN %@** · **A new icon is yours.** · **1 video in %@ · %@ icon unlocked** / **%lld videos in %@ · %@ icon unlocked** · **ON YOUR HOME SCREEN** · ícones **Aurora** (1), **First Light** (10), **Deep Space** (25), **Constellation** (50) | MARCO · PRIMEIRO VÍDEO EM %@ / MARCO · %lld VÍDEOS EM %@ · Um novo ícone é seu. · 1 vídeo em %@ · ícone %@ liberado · NA SUA TELA DE INÍCIO · Aurora / Primeira Luz / Espaço Profundo / Constelação | **Use %@** (Usar %@) → troca o ícone (alerta do sistema) ou, sem Pro e ícone ≥10, **Get %@ with Pro** (Ter %@ com o Pro) → marca como celebrado e abre o Pro; **Keep my current icon** (Manter meu ícone atual) | `Celebration/MilestoneView.swift:33-97,155-185`, `TakeReviewView.swift:210-217,615-631`, `Models/AppIconChoice.swift:41-69` | `-uiTestMilestone <1\|10\|25\|50>` (+ `-uiTestStoryAt <s>`) |
| Aviso do guia "Your first star is out there" | Toast ✓ com toque suave | Qualquer tela fora do prompter/revisão, sem outro toast | Primeiro compartilhamento confirmado com o guia do primeiro vídeo ativo; 0,7 s depois de sair da revisão | Uma vez (encerra o guia) | **Your first star is out there** | Sua primeira estrela está no mundo | — | `Managers/FirstVoyage/VoyageNotice.swift:15`, `Screens/FirstVoyage/VoyageAnnouncer.swift:31-40` | `-uiTestVoyage` |
| Your universe: cartão do marco | Cartão (`UniverseInfoCard`) + linha mono + botão amarelo | Profile › Your universe | Estado do ano (`UniverseContent`) | Sempre que abre | Conta nova: **NO VIDEOS SHARED YET** · **FIRST STAR · 0 / 1** · **Share your first video** · **It lights the first star of your universe** · legenda **Your universe starts with your first share.** · botão **Record your first video**. Ano novo: **FIRST STAR OF %@ · 0 / 1** · **It starts this year's universe**. Vivo: **NEXT MILESTONE · %lld / %lld** · **Share %lld more videos** · **Unlocks the %@ app icon** · botão **Share my %@ universe**. Selado: **◆ SEALED · DEC 31, %@**, **%@ · YOUR YEAR** | NENHUM VÍDEO COMPARTILHADO · PRIMEIRA ESTRELA · 0 / 1 · Compartilhe seu primeiro vídeo · Acende a primeira estrela do seu universo · Seu universo começa com seu primeiro compartilhamento. · Grave seu primeiro vídeo · PRIMEIRA ESTRELA DE %@ · 0 / 1 · Começa o universo deste ano · PRÓXIMO MARCO · %1$lld / %2$lld · Compartilhe mais %lld vídeos · Libera o ícone %@ · Compartilhar meu universo de %@ | Record → `startRecording`; Share → cartão/vídeo do universo; review travada → toast **Share 3 videos to unlock it** | `Screens/Profile/Universe/YourUniverseView.swift:146-176`, `Screens/Profile/Support/UniverseContent.swift:69-139` | `-uiTestUniverse sample\|newYear\|newAccount` |
| Your universe: abertura | Cena (2,9 s) toda vez que a página abre | Your universe | Ano vivo, sem Reduzir Movimento, fora dos testes | Toda abertura | — (sem texto) | — | — | `UniverseOpening`, §36 do DESIGN_PROJECT | (testes desligam; `playsUniverseOpening`) |
| Your universe: planeta cresce | Animação de 0,6 s `cubic-bezier(.3,1.4,.5,1)` + `soft` ao ganhar detalhe | Your universe | Primeira abertura depois de um share (`seenPlanetCounts`) | Uma vez por novo share | — | — | — | `MilestoneService.swift:78-90` | — |
| Star transition (a estrela da ideia) | Overlay sobre a foto parada do app | `MainView` (`StarTransitionOverlay`) | Enviar uma ideia ao Apple Intelligence / Ultra AI (dock, Logbook ✦ Write…) | Cada envio (≥3 s) | **Drafting in your voice** / **Drafting with Ultra AI** · "“ideia”" · frases a cada 1,6 s: **Drafting a hook… · Lining up the stars · Shaping it your way · Saving room for your pause · Trimming the extra words · Warming up the prompter · Shaping it for %@** · fim **Draft almost ready** · longo (22 s / 45 s Ultra) **Still drafting · taking a little longer** · Ultra: **Writing the draft · Checking the facts · Polishing in your voice** · % (a11y **Written so far**) · erro toast **Couldn't draft it · Try again** | Rascunhando na sua voz / Rascunhando com o Ultra AI · Rascunhando um gancho… · Alinhando as estrelas · Moldando do seu jeito · Deixando espaço para sua pausa · Cortando palavras desnecessárias · Aquecendo o teleprompter · Adaptando para %@ · Rascunho quase pronto · Ainda rascunhando · está demorando um pouco mais · Escrevendo o rascunho · Conferindo os fatos · Lapidando na sua voz · Não deu para rascunhar · Tente de novo | **Cancel** (foco do VoiceOver) → estrela cai 40 pt e some, ideia fica no campo | `Screens/Scripts/Transition/StarTransitionOverlay.swift:206-290,603-611`, `Managers/ScriptAI/IdeaTransitionService.swift:234-255` | `-uiTestStarTransition` (tempos reais), `-uiTestWriterStalls`, `-uiTestCatalogue transition` |
| Pro opening | Cena de abertura do Pro (3,5 s) | `PaywallView` contexto `.profile` | Toda vez que o Pro abre pelo Profile/Try Pro (os contextos `.export` e `.ultra` não têm abertura) | Toda abertura | **CUE PRO** · **Take your universe further.** · **Free to try · %lld exports included.** (ou **… and %lld Ultra AI scripts included.**) · ao assinar toast **Welcome to Cue Pro** | CUE PRO · Leve seu universo mais longe. · Grátis para testar · %lld exportações incluídas. · Boas-vindas ao Cue Pro | Assinar / Restore / ✕ | `Screens/Shared/Paywall/PaywallView.swift:28-35`, `PaywallCopy.swift:56-61`, DESIGN_PROJECT §12 | `-uiTestProAt <s>` |
| Logbook (página) | Folha `.large` com lista por dia + compositor de vidro | Scripts › botão Logbook | Abrir; entradas automáticas: um comentário respondido cujo rascunho falhou durante a estrela (`ScriptStarter.swift:199-205`, `AppServices.swift:220`), "Save to Logbook" do Answer a comment (toast **Saved to Logbook**), Siri (`AddToLogbookIntent`) | — | **Logbook** · subtítulo **Catch it now. Write it later.** · vazio **Your Logbook is empty** / **Hold the mic to catch an idea. Write it later.** · campo **Type, or hold the mic to talk** · **Listening…** / **Tap the button again to finish** · linha da entrada **Spoken · %@ · %@** / **Typed · %@** (mono, "SPOKEN · 0:06 · 2 HR. AGO") · dias **Today**/**Yesterday** (maiúsculas) · ação **✦ Write** / **Write it** · **Idea deleted** + **Undo** | Diário de bordo · Capture agora. Escreva depois. · Seu Diário de bordo está vazio · Segure o microfone para captar uma ideia. Escreva depois. · Digite ou segure o microfone para falar · Ouvindo… · Toque no botão de novo para terminar · Falada · %@ · %@ / Digitada · %@ · Hoje / Ontem · Escrever / Escreva · Ideia apagada · Desfazer | ✦ Write → estrela/rascunho; Write it → rascunho em branco; Done | `Screens/Scripts/Logbook/LogbookView.swift:124-389`, `LogbookDays.swift:34-62`, DESIGN_PROJECT §22 | `-uiTestStubAI` |

"First send": não é uma celebração; é o nome interno do primeiro envio de ideia depois de um lançamento (medição de desempenho,
`Managers/ScriptAI/IdeaSendTimeline.swift:9`).

### Componentes visuais (6)

- **1.7 First star** (`FirstStarView`, `FirstStarScene`, `FirstStarScript`): noite `Flight.nightDeep` #06070D com `BgWash.firstStar` (luz violeta atrás
  do universo) e o céu do criador. Cena de 390 × 520 pt escalada de ×0,96 a ×1,13 pela largura: universo inclinado (−12°, achatado 0,42), YOU no centro
  (195, 262). O take, 70 × 124 pt raio 14, borda `acc` 70% 1,5 pt, selo "✓ SAVED" (mono 8, `successText` sobre preto 80%, cápsula de 18 pt); uma luz
  percorre a borda, ele cresce a 1,05 e dobra em luz até 0,06 (raio 60, brilho ×3) em 1,55 s; um cometa (`StarRibbon`) leva a luz pela rota até a
  estrela (1,6–2,9 s), 5 toques que apertam (1,75/2,2/2,5 `soft`, 2,7/2,83 `light`); a estrela acende aos 2,95 s (`success`) com 10 faíscas, dois
  anéis e cruz de luz, o universo escurece um instante, clarão branco/dourado, onda pelas órbitas; a linha do YOU se desenha (lilás → dourado,
  3,3–4,1 s); "FIRST TAKE · TODAY" mono 9,5 `starGold` sobre a estrela; a cena se aproxima 4%. Textos centrados, 24 pt de margem: "FIRST VIDEO · FIRST
  STAR" mono 12, tracking 1,54, `acc`; título `cueFont(30, .bold)` tracking −0,6, largura máx. 300 pt, palavra a palavra (blur 8 → 0, 14 pt), um brilho
  dourado de 90 pt cruza uma vez; subtítulo `cueFont(17)` `ink2`, entrelinha 3. Botões: **Explore Cue** `.cuePrimary(.large)` com uma faixa branca
  inclinada que cruza (77,5–87,5% do ciclo), **Edit my video** `cueFont(15, .semibold)` `ink2`, 40 pt; 32 pt da borda. Depois de parar: órbitas
  girando, cintilar a cada 3,4 s, estrela cadente a cada 9 s (30 fps). Reduzir Movimento: estado final parado, sem hápticos.
- **8.2 Send-off** (`SendOffView`, `SendOffLayout`, `SendOffMap`, `SendOffScript`): quadro de 390 × 844 escalado à tela, `skyBackground(wash: BgWash.sendOff)`.
  Órbitas de 316 e 220 pt achatadas a 32%, giradas −9°; YOU 56 pt (brilho `sendOffYouGlow` #FFC86E 28%, borda `sendOffYouRim`); planetas 20/18/17/16/14/12
  pt por ordem de vídeos, rótulos "TIKTOK · 13" mono, redes que não receberam a 38%. Miniatura do take 54 × 96 pt (borda branca 25%, sombra preta 50%
  raio 30) sobe e encolhe em luz (0,65 s); uma estrela por rede (sai aos 0,52 s + 0,35 s·i, voo 1,05 s em arco quadrático, rastro de 9 pontos a 38 ms);
  na chegada pulso ×1,35 → ×1,12, anel ×5, "+1 · TIKTOK", contagem sobe; estrela nova perto do YOU 0,3 s depois. Textos fixos desde o início: eyebrow mono
  11 tracking 1,32 `acc`; "On its way." `cueFont(30, .bold)` `ink`; detalhe `cueFont(14)` `ink2`; link `cueFont(15, .semibold)` `acc` + `chevron.forward`.
  Botões lado a lado: "Share again" `.cueSecondary(.large)`, "Done" `.cuePrimary(.large)`. Háptico `success` a cada chegada.
- **8.3 Milestone** (`MilestoneView`, `MilestoneScript`): `BgWash.milestone` sobre `Flight.night`. Espaços ×0,79 (SE) a ×1,13 (Pro Max). Eyebrow mono 11
  tracking 1,3 `accText`; herói de 200 pt: halo radial `aiText` 45%, 12 raios creme a 18% girando (40 s/volta), seis fagulhas (branco/lilás/`acc`) caem
  num ponto (0–1,35 s), ícone de 140 pt raio 32 salta (×0,6 → 1,06 → 1 a partir de 1,17 s; `success` aos 1,62 s), anel `acc` 1,5 pt e anel creme 1 pt por
  cima, cruz de luz dourada (1,55–2,45 s). "A new icon is yours." `cueFont(30, .bold)`; linha `cueFont(15)` `ink2`. Fileira "ON YOUR HOME SCREEN" (mono 10
  `ink2`): cápsula de vidro improvisado (branco 8%, borda branca 14%, raio 28, 76 pt) com quatro azulejos de 50 pt raio 12, o 2º é o ícone novo com dois
  aros `acc`. Botões: primário `.cuePrimary(.large)`, "Keep my current icon" `cueFont(15, .semibold)` `ink2`.
- **Ready to travel** (`ReadyToTravelView`): `BgWash.share`; barra com ✕ e compartilhar; pôster; "Ready to travel." `cueFont(36, .bold)`; título
  `cueFont(19)` `ink2`; linha `hudFont` `ink2`; cartão de exportações grátis; "Share to universe" `.cuePrimary(.large)` com `square.and.arrow.up`, "Save
  video" `.cueSecondary(.large)`.
- **Cartão do universo** (`UniverseInfoCard`): eyebrow mono, título, detalhe, barra de progresso e a miniatura do ícone do marco (Aurora, Deep Space…);
  botão amarelo `.cuePrimary(.large)` com `shineSweep` a cada 4,8 s (`video.fill` ou `square.and.arrow.up`).
- **Star transition**: ver DESIGN_PROJECT §3 (subida de 1,32 s, rastro, 34 pontos de luz, foto do app escurecida −0,4/saturação 0,7/blur 10/escala 0,94,
  órbita de progresso `dockGlow`, anel de saída, cometa até o cursor). Textos: título `cueFont(20, .bold)` branco, ideia `cueFont(15)` `transitionInk`
  (#EBEBF5 86%, 100% em AC), frase `cueFont(16, .medium)` itálico `transitionPhrase` #C4B8FF, % `hudFont` `ink2`, Cancel `cueFont(15, .semibold)`
  `transitionInk` a 118 pt do fundo. VoiceOver anuncia "Drafting in your voice" e foca o Cancel. Hápticos: decolagem, zumbido, ignição, toque a cada 25%,
  pouso (baque + dois brilhos), toque suave no Cancel.
- **Logbook**: DESIGN_PROJECT §22 (linhas 978-1003) descreve tudo: cartão `surface` raio 22 com `cardDepth`, ícone 44 pt (microfone amarelo / lápis),
  texto 16 medium até 3 linhas, linha mono com a bolinha do tópico, ✦ Write violeta; compositor de vidro raio 28 com botão amarelo de 44 pt.

### Observações (6)

1. **"Primeira estrela" quer dizer duas coisas que se contradizem.** A 1.7 diz "Your first video. Your first star." no primeiro **take**, mas Your universe,
   para quem gravou e não compartilhou, mostra "FIRST STAR · 0 / 1 · Share your first video · It lights the first star of your universe" e o botão
   **"Record your first video"** (`YourUniverseView.swift:148-152`, `UniverseContent.swift:121`), a quem já gravou. E o primeiro **compartilhamento**
   ganha outra vez "MILESTONE · FIRST VIDEO IN 2026" + "Your first star is out there" (`VoyageNotice.swift:15`). Para um iniciante, a primeira estrela
   acende, depois volta a valer 0/1, e o app manda gravar o que já foi gravado.
2. **O marco se perde se o criador não tocar "Done".** O marco só é contado depois do **Done** do send-off (`TakeReviewView.swift:605-613`). "Share again"
   (`:470`, `shareAfterClosing`) e o link "A new star in your … universe" (`:472`) fecham o send-off sem chamar `doneWithSendOff`, e com Celebrations
   desligado o send-off é apagado na hora (`:199`). Como `recordShare` devolve o marco **uma vez só** (`MilestoneService.swift:51-68`) e nada fica
   pendente, a história do marco (e o convite para o ícone Aurora/First Light…) nunca aparece. O ícone continua liberado em Personalize, sem aviso.
3. **O marco pode repetir na mesma revisão.** `ShareFlow.reachedMilestone` é escrito (`ShareFlow.swift:26,167`) e nunca zerado. O `ShareFlow` vive
   enquanto a revisão vive (`TakeReviewView.swift:99-102`), e cada novo `.sentOff` relê esse valor (`:198`). Exemplo: "Continue posting" para a rede
   que ficou para depois, ou outro envio confirmado. Depois do Done, o mesmo marco já celebrado volta a aparecer (`MilestoneView` não confere
   `celebrated`).
4. **Três celebrações para um evento e "+1" que não existe.** O primeiro compartilhamento confirmado dispara em sequência o send-off, o marco 1 (Aurora,
   "MILESTONE · FIRST VIDEO") e o toast do guia "Your first star is out there". Mais: os `.sentOff` fora da fila (`TakeReviewViewModel.swift:556,604`)
   mostram a estrela voando, "+1" e "A new star in your universe", mas só a fila chama `recordShare` (`ShareFlow.swift:167`, único chamador). Por esses
   caminhos o universo e os marcos não mudam (hoje com `integrationsEnabled = false` é raro, mas o Share Kit do TikTok cai nesse caminho quando voltar).
5. **"Explore Cue" não leva a lugar nenhum:** na 1.7 ele só fecha a história e o criador continua na revisão do take (`TakeReviewView.swift:205,590-597`).
   O nome promete o mesmo que "Explore Cue first" da prática, que leva a Scripts.
6. **Primeira estrela frágil:** exige `takes.count == 1` no momento em que a revisão abre (`TakeReviewView.swift:584-585`). Quem grava dois takes antes
   de abrir a revisão, quem importa um vídeo antes, quem desligou Celebrations no primeiro take (não marca, então pode tocar meses depois no único take)
   ou quem caiu no caso da Obs. 5.1 (`resolve` marca `firstStarShown`) nunca vê a 1.7 ou a vê fora de hora. "FIRST TAKE · TODAY" diz "today" mesmo quando
   o take é antigo (`FirstStarScene.swift:299`).
7. **Plural quebrado:** "Share %lld more videos" não tem variação de plural (catálogo, EN e PT): em 9/10, 24/25 e 49/50 aparece "Share 1 more videos" /
   "Compartilhe mais 1 vídeos" (`YourUniverseView.swift:168`).
8. **Promessa maior que o código:** a 1.7 diz "Add captions, edit it **or share it** to light up your universe": legendas e edição não acendem nada, e
   compartilhar só acende pela fila "Share to universe" com "Yes, it's live". A folha do sistema (ícone de compartilhar) e "Save video" não contam
   (ver Obs. 4). A chave "Celebrations" diz "at each milestone", mas também desliga a primeira estrela e o send-off; e o rodapé "With Reduce Motion on, the
   sky and the celebrations rest" não é verdade (as histórias aparecem, paradas).
9. **Tom e terminologia diferentes entre telas vizinhas:** Ready to travel diz "CAPTIONS ON · NO WATERMARK" (maiúsculas), o send-off logo depois diz
   "captions burned in · no watermark" (minúsculas, outro termo) (`ReadyToTravelView.swift:53-54`, `SendOffView.swift:131-132`). Em PT: "Celebrações" vs
   "Marco", "Diário de bordo" vs o botão "Logbook" em amarelo; "COMPARTILHADO NO %@" fica estranho com "Reels"/"Shorts" ("NO Reels").
10. **Texto do send-off sem catálogo:** "TIKTOK · 13" e "+1 · TIKTOK" são `Text(verbatim:)` (`SendOffMap.swift:106,180`), aceitável (nome + número), mas
    "+1" não muda de forma em idiomas RTL.
11. **Cor de texto com token de preenchimento:** eyebrow e link do send-off usam `Palette.acc` em vez de `accText` (`SendOffView.swift:95,112`; mesmo valor
    hoje, mas fora da regra); a fileira da tela de início do marco usa `Color.white.opacity` (decorativo, ok).
12. **Comentário guardado no Logbook sem aviso:** quando o rascunho de um comentário falha durante a estrela, o comentário é salvo no Logbook
    (`ScriptStarter.swift:199-205`), mas o toast diz só "Couldn't draft it · Try again", sem contar que ele está no Logbook.
13. **Documentação divergente:** DESIGN_PROJECT §16 diz "Os marcos contam todos os vídeos", mas o código conta o ano vivo e o `alreadyWon` faz cada
    ícone valer uma vez na vida (`MilestoneService.swift:40-67`); o comentário de `MilestoneService.swift:8` ainda fala em "the milestones that count
    opens" sem o ano.

Medido: nada (inventário só de leitura; sem build nem capturas). As traduções foram conferidas no catálogo; todas as chaves citadas têm os 19 idiomas,
exceto os textos fora do catálogo apontados (VOICE/CAMERA, Y·O·U).



## 7. Outros sistemas proativos

| ID | Visual | Onde | Gatilho / frequência | EN | PT-BR | Ação → destino | Código | Launch arg |
|---|---|---|---|---|---|---|---|---|
| Etiqueta **NEW** em Personalize | etiqueta pequena ao lado do título na raiz de Settings | Settings › Personalize | **sempre** (não some depois de visitada) | "NEW" | "NOVO" | — | `SettingsRootRow.swift:42`; `SettingsIconLabel.swift:63-70` | nenhum |
| Atalhos da Siri / Shortcuts | sistema | Siri, Spotlight, Shortcuts | sempre disponíveis | "Record ${script} in ${applicationName}", "Read ${script} with ${applicationName}" (Record script, `video.fill`) · "New script in …", "Write a script with …" (New script, `square.and.pencil`) · "Add an idea to …", "Save an idea in …" (Add to Logbook, `book.closed`) | "Gravar ${script} no …", "Ler ${script} com o …" · "Novo roteiro no …", "Escrever um roteiro com o …" · "Adicionar uma ideia ao …", "Salvar uma ideia no …" | abrem gravação / novo script / salvam no Logbook | `SupportFiles/AppIntents/CueShortcuts.swift`; `AppShortcuts.xcstrings` | — |
| Diálogos das intenções | Siri | Add to Logbook | ao pedir a ideia e ao salvar | "What's the idea?" / "Saved in your Logbook." · descrições: "Saves an idea in your Logbook, to write later.", "Starts a new script from a prompt, a blank page or a document.", "Opens the camera with the script ready to scroll under the lens." | "Qual é a ideia?" / "Salva no seu Diário de bordo." · "Salva uma ideia no seu Diário de bordo para escrever depois." · "Começa um roteiro novo a partir de um prompt, uma página em branco ou um documento." · "Abre a câmera com o roteiro pronto para rolar abaixo da lente." | — | `AddToLogbookIntent.swift:12-30`; `NewScriptIntent.swift:11-12`; `RecordScriptIntent.swift:11-15` | — |
| Aviso de Modo de Pouca Energia | faixa sobre a prévia do editor (ícone `battery.25percent` `accText`, título semibold, texto `ink2`, ✕) | Quick edit | modo ligado; no máximo 1×/dia; some ao desligar o modo ou no ✕ | "Low Power Mode is on" / "Editing runs at 60 frames per second and exports take longer. Turn it off in Control Center for smoother editing." | "O Modo de Pouca Energia está ativado" / "A edição roda a 60 quadros por segundo e as exportações demoram mais. Desative-o na Central de Controle para editar com mais fluidez." | ✕ | `LowPowerNoticeBanner.swift:10-40`; `QuickEditViewModel+LowPower.swift:13-26` | `-uiTestLowPower` |
| Apple Watch: "Prepare on your iPhone" | tela do relógio (ícone `iphone`, título headline, texto footnote, "✓ iPhone connected") | app do Watch (ainda não embutido no iPhone, DESIGN §43) | sem sessão no iPhone | "Prepare on your iPhone" / "Open Cue on your iPhone and pick a script or a freestyle recording." / "iPhone connected" | "Prepare no iPhone" / "Abra o Cue no iPhone e escolha um roteiro ou a gravação livre." / "iPhone conectado" | — | `Cue Studio Watch/Screens/WatchNotice.swift` (`.noSession`); `WatchNoticeView.swift` | `Cue Studio Watch/Debug/WatchDemo.swift` |
| Apple Watch: notificações | — | — | **não existem** (nenhum `UserNotifications` no Watch; só hápticos de troca de tela `WatchHaptics.swift`) | — | — | — | — | — |
| Pedido de avaliação (App Store) | — | — | **não existe** (`requestReview`/`SKStoreReviewController` ausentes) | — | — | — | — | — |
| Live Activities / Dynamic Island | — | — | **não existem** (sem `ActivityKit`) | — | — | — | — | — |
| Widgets | — | — | **não existem** (sem `WidgetKit`) | — | — | — | — | — |
| Badge no ícone | — | — | **não existe** | — | — | — | — | — |
| Tela "What's new" | — | — | **não existe**; só a notificação `whatsNew`, com catálogo vazio | — | — | — | — | — |
| Dica legada da linha de leitura | — | — | removida; só a limpeza da chave `readingLineTipSeen` | — | — | — | `PreferencesService.swift:58` | — |

---


### Componentes visuais (1, 2 e 7)

O app é só escuro (`Palette.bg #0A0B12`); tokens em `Cue Studio/DesignSystem/Tokens/Palette/Palette.swift`. Valores com "Aumentar Contraste" entre parênteses.
Tokens usados aqui: `ink` #FFFFFF · `ink2` #E1E4F5 a 62% (80%) · `ink3` #E1E4F5 a 45% (62%) · `accText`/`acc` #FFD60A · `accInk` #000 · `aiText` #B4A7FF
(#CFC6FF) · `aiTextStrong` #E4DEFF (#F2EEFF) · `aiFill` #9D8CFF a 17% · `aiBorder` #B4A7FF a 30% · `surface` #161826 · `surface2` #1F2236 · `surface3`
#2B2F48 · `separator` #505678 a 50% (#8C92B4 a 80%) · `success` #34C759 · `warnText` #FF9F0A (#FFB340) · `accWashFaint` #FFD60A a 5% · `sheetNight`
#14162A a 96%. Métricas (`Tokens/Metrics.swift`): gutter 16, hitTarget 44, sheetRadius 38, sheetBarHeight 56, botão large 54 / regular 50 / medium 42 /
compact 34, listRowContent 32. Tipos (`InterfaceType.swift`): estilos do iOS no tamanho padrão (title2 22, headline 17 semibold, body 17, subheadline 15,
footnote 13, caption 12), crescendo com Dynamic Type e um pouco com a largura do iPhone.

- **Folha ajustada (`FittedSheet` + `CueSheetChrome` + `SheetHeader`)** — `DesignSystem/Components/FittedSheet.swift`, `CueSheetChrome.swift`,
  `SheetHeader.swift`. Folha do sistema com altura exata do conteúdo + 56 pt, alça visível, fundo `sheetNight` (#14162A 96%), canto 38, X nativo de vidro
  (Liquid Glass) à esquerda. Cabeçalho: título title2 bold `ink`, subtítulo subheadline `ink2`, 5 pt entre eles. Conteúdo com padding 4 topo / 16 laterais /
  16 base.
- **`NotificationInviteSheet`** — `Screens/Shared/Notifications/NotificationInviteSheet.swift`. Linha de topo: azulejo 48×48, raio 14 contínuo, fundo
  `surface2`, sino `bell.badge` 22 semibold `aiText` (violeta); à direita o `SheetHeader`. 16 pt abaixo, dois botões cápsula de largura total, 8 pt entre:
  **Allow notifications** primário grande (54 pt, Liquid Glass tingido `acc` amarelo, texto preto body semibold) e **Not now** secundário grande (vidro,
  fundo `surface2`, texto `ink`). Sem animação própria.
- **`FeatureIntroSheet`** — `Screens/Shared/Discovery/FeatureIntroSheet.swift`. Igual ao convite; o ícone é o SF Symbol da ferramenta (22 semibold) ou o
  `CueIconView` (26) em `aiText`. Entre cabeçalho e botões, `Label` com `info.circle` + nota em footnote `ink2`. Abaixo dos dois botões, link
  "Don’t suggest this" subheadline `ink2`, 44 pt de alvo.
- **`ReminderSheet`** — `Screens/Shared/Reminders/ReminderSheet.swift`. `SheetHeader` + `GroupedCard` com linhas de 52 pt (ícone 22 pt `ink2`, rótulo body
  `ink`, hora à direita `ink2`), 16 pt laterais; "Pick a date and time" expande (`.smooth 0.2 s`) um `DatePicker` compacto tingido `accText`, nota footnote
  `ink2` e botão primário regular "Set reminder". Erro em footnote `warnText`; aviso de negado com `bell.slash`; "Already set" footnote semibold `ink2` + linhas
  com `xmark.circle.fill`.
- **Settings › Notifications** — `Screens/Settings/Notifications/*`. Lista agrupada; cartões `surface` com separador `separator`; cabeçalhos de seção
  footnote semibold MAIÚSCULAS `ink2`. Linha de permissão: sino `bell` 21 regular `accText` num quadro 28×28 que balança (9° amortecido a cada 4,8 s
  enquanto off; ao permitir, 22° amortecido por 1,4 s), selo ✓ 14 pt `success` com borda `surface` 2 pt; título body `ink`, detalhe subheadline `ink2`;
  `Toggle` tingido `success`; padding 16×11. Cascata: interruptores acendem um a um (mola 0,42/0,8) com `HapticPatterns.playNotificationsOn`. Chips de dias:
  círculos, ligados `acc`/`accInk`, desligados `surface3`/`ink`, entrada em cascata (mola 0,42/0,68, 35 ms entre eles); DatePicker de hora tingido
  `accText`.
- **`ContinuePostingCard`** — `Screens/Shared/Share/ContinuePostingCard.swift`. Cápsula retangular de vidro (`glassEffect(.regular)`, raio 22 contínuo),
  60 pt de altura, 16 pt das laterais, 104 pt acima do fundo da tela, entra com `move(edge: .bottom) + opacity`. Esquerda: linha mono 10 bold, tracking 0,8,
  `accText` ("CONTINUE POSTING · 1 OF 3") e linha 15 semibold `ink`. Direita: botão "Continue" 15 bold preto em cápsula `acc` (38 pt) e ✕ 13 semibold `ink2`.
- **`ShareQueueExplainer`** — `Screens/TakeReview/Share/ShareQueueExplainer.swift`. Folha: título headline semibold centralizado; 3 passos com círculo 32 pt
  `accWashFaint` + número mono 13 bold `accText`, título 17 semibold `ink`, detalhe subheadline `ink2`; trilho de redes (cápsulas 28 pt `surface3`, texto mono
  10,5 semibold MAIÚSCULO, chevrons `ink3`) sobre bloco `surface2` raio 22; botão primário grande "Start with …".
- **`UltraInviteCard`** — `Screens/Shared/Ultra/UltraInviteCard.swift`. Fundo `aiFill` (violeta 17%), raio 16 (linha do dock) ou 18 (cartão), borda 0,5 pt
  `aiBorder` só no cartão. Linha: "✦" footnote bold `aiText` + texto footnote semibold `ink` + botão `cueAI` compacto ("Try it", texto `aiTextStrong` sobre
  `aiFill`) + ✕ caption bold `ink2`; 44 pt de altura, 14 pt à esquerda. Cartão: ✦ + título subheadline semibold `ink` + ✕; detalhe footnote `ink2`; botão
  `cueAI` médio; padding 14/16/14/8. Chegada (1× por lugar/sessão): ✦ entra a 20%, girado −70°, mola até 100% com brilho violeta que apaga em 0,9 s; fundo
  sobe de 97%; linhas saem do desfoque 8 pt abaixo, uma após a outra; uma luz (traço 1,2 pt `aiTextStrong` + halo 4 pt `aiText` 45%) dá uma volta na
  borda em 1,2 s depois de 0,18 s. ✕ dobra o cartão (0,32 s) com `Haptics.soft()`. Reduzir Movimento: só fade 0,2 s.
- **`LowPowerNoticeBanner`** — `Screens/QuickEdit/Player/LowPowerNoticeBanner.swift`. Faixa com ícone `battery.25percent` `accText`, título subheadline
  semibold `ink`, texto footnote `ink2`, ✕ footnote bold `ink2`. Usa `.font(.system(...))` em vez de `cueFont` (não cresce com a largura).
- **Notificação do sistema** — sem imagem anexada, sem ações, sem subtítulo; título + corpo + ícone do app; agrupadas por categoria.

### Observações (1, 2 e 7)

1. **Tools and news desligado por padrão esvazia a descoberta inteira.** As introduções no app também exigem `isOn(.discovery)`
   (`NotificationService+Discovery.swift:35`), e o "Allow notifications" do convite não liga a categoria (`NotificationService+Invite.swift:41-47`). Quem
   nunca abre Settings › Notifications **nunca** recebe nenhuma das 17 introduções nem o Year in Review (`.whatsNew`, passivo, também off). Só quem toca o
   interruptor do topo (que liga tudo, `NotificationService+Groups.swift:33-46`) as recebe. O sistema de descoberta mais completo do app fica atrás de um
   interruptor que quase ninguém toca.
2. **O convite de notificações cai em cima da primeira viagem e da primeira estrela.** `offerIntroduction` roda ao fechar o prompter
   (`MainView.swift:66-69, 340-347`) e o 1º convite exige justamente ter uma take — ou seja, sai na primeira gravação, o momento em que a primeira estrela
   (`TakeReviewView.swift:581-588`), o `VoyageAnnouncer` ("Recorded · Next: pick a take", `MainView.swift:54-55`) e as dicas da viagem
   (`services.voyage.tipShown(.pick, at: .review)`, `TakeReviewView.swift:576-578`) estão falando. `isForegroundBusy` não olha a primeira viagem
   (`AppServices.swift:381-383`); `NOTIFICATIONS.md` §3 promete "nunca no primeiro voo", mas no código "primeiro voo" é só o onboarding (`RootView.swift:123`).
3. **Quatro sistemas de "convite/dica", quatro regras de coordenação diferentes.** O convite de notificações olha a dica do My Cue Voice e as introduções
   (`+Invite.swift:18-23`); a dica do My Cue Voice olha só as introduções de ferramenta (`otherIntroductionToday` = `introducedToday` = exposições,
   `AppServices.swift:384`), não o convite; o convite da Ultra AI (`UltraScriptService.swift:70-73`) não olha nenhum dos outros; as dicas da primeira
   viagem também não. No dock de Scripts, a linha da Ultra AI, a dica de voz e uma dica da viagem podem aparecer na mesma sessão.
4. **"Not now" quer dizer três coisas.** Na introdução de ferramenta = 30 dias (`+Discovery.swift:87-91`); no convite de notificações = mais uma chance em
   14 dias (`+Invite.swift:14, 26`); no ✕ da Ultra AI, rotulado "Not now" para o VoiceOver, = **nunca mais**, em todos os lugares
   (`UltraInviteCard.swift` closeButton `accessibilityLabel("Not now")`; `UltraInviteService.swift:48-51`).
5. **Copy que promete o que o destino não faz.**
   - Voice Following: "Read at your own pace: the text moves when you speak…" + **Try it** só abre a página do script (`NotificationNavigator.swift:41-43`);
     nada liga ou aponta o modo Voice no prompter (contraria "Buttons keep their word").
   - Safe zones: a notificação diz "Check that your captions stay clear of the network’s buttons." (`FeatureID+Copy.swift:55`), mas o destino é a zona
     segura **do teleprompter** em Settings › Prompter (benefício: "…put their buttons while you record", `+Copy.swift:105`). Legendas não são o assunto.
   - `firstRecording` "Your first star is one take away" (estrela = 1ª take, `TakeReviewView.swift:581`) vs universo "Every video you share becomes a
     star in it" (`+Copy.swift:56`): "estrela" significa duas coisas.
   - Skin: o corpo ("Smooth the skin, light the face or take off shine") fala da aparência, que `NOTIFICATIONS.md` (topo) e o comentário do próprio
     código (`+Copy.swift:48`) dizem evitar.
6. **Textos e estados que nunca aparecem (código morto traduzido em 19 idiomas).**
   - `showsTitles` é sempre `false` (`NotificationState.swift:29`, sem UI): as variantes "%@ has already started", "%@ is ready. Your next recording is one
     tap away.", "%@ is waiting", "%@ is saved in Cue. Open it to continue sharing." e "Explore an idea for your next video about %@." nunca saem
     (`NotificationCopy.swift:23-28, 58, 64, 94, 99, 105`). `NOTIFICATIONS.md` §2 ainda lista a versão com tema de `availableIdea`.
   - `WhatsNewCatalog.all = []` (`WhatsNewCatalog.swift:20`): a campanha `whatsNew` e o texto "New in Cue / A new tool arrived…" nunca saem; e o texto é
     genérico — quando houver entradas, todas dirão a mesma frase.
   - Estado `.quiet` ("Notifications arrive quietly · Without a banner or a sound.", `NotificationPermissionRow.swift:92, 101`): o Cue só pede
     `[.alert, .sound]` (`SystemNotificationCenter.swift:25`), então o iOS não deve reportar `.provisional`; só aparece com
     `-uiTestNotificationAuth provisional`.
   - `pausedUntil`/pausa e quiet hours editáveis saíram da UI (22/10) mas seguem no estado e no planejador (`NotificationState`, `PlanningContext.swift:14`,
     `NotificationPlanner.swift:86`); `setReminder` grava consentimento de `.reminders`, que `isOn` ignora (`+Reminders.swift:31` vs
     `NotificationState.swift:70-71`). Destino `.notificationSettings` só é usado no tap de Debug (`DebugNotificationTaps.swift:41`).
   - O título e o corpo de `remoteControl` (`+Copy.swift:28, 54`) existem mas a ferramenta é só do app (`FeatureCatalog.swift:78-82`).
7. **Tradução errada por chave compartilhada:** "Time" é o rótulo da hora da rotina (`NotificationRoutineEditor.swift:45`) e o do tempo do player do editor
   (`EditorPlayerBar.swift:25`); a chave não tem comentário e saiu "Tempo" (pt) / "Tiempo" (es) — na rotina devia ser "Horário". Precisa de chave própria
   com comentário. Todas as outras chaves deste escopo estão nos 19 idiomas.
8. **Tom e terminologia.**
   - O Cue fala de si na 3ª pessoa ("Cue opens each app", "Cue takes you to the next network"), mas a linha do passo diz "We'll open %@ next."
     (`ShareQueueStep.swift` reminder) — "Abriremos %@ em seguida".
   - "Ultra AI" é masculino em pt ("o Ultra AI"), enquanto "Apple Intelligence" é feminino ("a Apple Intelligence"); vale decidir de propósito.
   - "Remind me" vira "Lembrar depois" (título da folha) mas o grupo da rotina é "Me lembrar de criar"; "Set" = "Criado" em pt, "Programado" em es.
   - Comentários e documentos com nomes antigos: "Continue my projects" (`NotificationService+Opening.swift:84`), "Discover tools and ideas"
     (`NotificationService+Discovery.swift:9`, `FeatureIntro.swift:12`, `NOTIFICATIONS.md` §13 passo 5), "'Turn on' there, whose card names them"
     (`NotificationCategory.swift`), "unless the creator changes them" (`QuietHours.swift`); `NOTIFICATIONS.md` §2 não traz o corpo real de
     `returnAfterInactivity` ("Start from an idea, a format or a blank page. Your universe has room for one more star.", `NotificationCopy.swift:21`).
9. **O sim do iOS pelo interruptor do topo cria uma rotina que o criador não escolheu** (Seg/Qua/Sex 18:00, `NotificationService+Groups.swift:40-44`): até 3
   notificações por semana fora dos limites. É decisão do dono, mas o rodapé "At most one a day" vale só para as automáticas, e quem só queria lembretes
   ganha também Tools and news.
10. **Sem ação na notificação e sem retorno de dispensa.** Nenhuma categoria/ação é registrada (`NotificationCenterDelegate.swift:22`): um lembrete não
    tem "Snooze"/"Tomorrow" na própria notificação, e uma automática ignorada nunca reduz as próximas.
11. **Fechar pelo X não é medido.** Na `FeatureIntroSheet` e no convite, o X/arrastar só fecha: a exposição/o convite já contou, mas nenhum `snoozed`
    é medido (`MainView.swift:318-369`), então as métricas confundem "ignorou" com "não viu".
12. **Etiqueta "NEW" eterna** em Settings › Personalize (`SettingsRootRow.swift:42`): não há flag de visto; perde o sentido na segunda visita.
13. **Lacunas de orientação:** não há tela "What's new", pedido de avaliação, widget, Live Activity nem badge; o relógio não recebe nada proativo. O
    valor de Notifications na raiz de Settings fica vazio com o iOS não perguntado (`SettingsRootRow.swift:101-105`), quando de fato nada chega.
14. **Editar um lembrete em Settings não confirma nada** (`NotificationsSettingsView.swift:79-81` não passa `onSet`): os outros três lugares mostram o toast
    "Reminder set · …".
15. **`LowPowerNoticeBanner` fora do sistema de tipos** (`.font(.system(...))` em vez de `cueFont`, `LowPowerNoticeBanner.swift:16-26`), e o convite usa
    `.font(.fixed(22))` onde a introdução usa `.cueFont(22)` (`NotificationInviteSheet.swift:19` vs `FeatureIntroSheet.swift:58`).

---

## Observações — consolidado entre sistemas

As observações detalhadas, com arquivo:linha, estão no fim de cada seção (1/2/7, 3, 4, 5, 6). Aqui ficam as que atravessam sistemas, por impacto.

1. **Sem coordenação central: sete fontes proativas, cada uma com sua regra.** O convite de notificações, a introdução de ferramenta, a dica do My Cue Voice
   (TipKit), as dicas da primeira viagem, o convite da Ultra AI, o cartão Continue posting e as celebrações decidem sozinhos. Só os dois primeiros e a dica de
   voz se olham (e de forma assimétrica: a dica de voz não vê o convite, `AppServices.swift:384`). Ultra AI e viagem não olham ninguém. Falta um "porteiro"
   único de "uma mensagem proativa por momento".
2. **O momento da primeira gravação acumula tudo.** Ao fechar o prompter depois da 1ª take: primeira estrela (1.7/`TakeReviewView.swift:581-588`), dica
   Pick da viagem, toast "Recorded · Next: pick a take" (`VoyageAnnouncer`) e o convite de notificações (`MainView.swift:66-69, 340-347`). Ver §1/2/7 obs. 2,
   §4 obs., §6.
3. **"Estrela" tem dois significados.** 1ª take acende a primeira estrela (onboarding 1.7, revisão, notificação `firstRecording`: "Your first star is one
   take away"); o universo e a viagem dizem que a estrela vem do **compartilhamento** ("Every video you share becomes a star", "FIRST STAR · 0 / 1 · Share your
   first video", "Lights your first star"). Ver §1/2/7 obs. 5, §4, §6.
4. **A descoberta de ferramentas não chega a quase ninguém.** "Tools and news" começa desligado e também trava as introduções dentro do app; o convite de
   notificações não liga a categoria. Ver §1/2/7 obs. 1.
5. **Botões que não cumprem a palavra.** Voice Following "Try it" só abre a página do script; Safe zones fala de legendas e abre a zona do prompter; dica
   Polish "Add captions" abre o editor, não as legendas; dica Share "Cue opens %@ with your video and caption" com integrações desligadas; "Explore Cue" da 1.7
   sem destino; "Tap Sounds like me" quando o botão não existe. Ver §1/2/7 obs. 5, §4, §5.
6. **"Not now" e "fechar" significam coisas diferentes em cada sistema** (30 dias, 14 dias e 1 chance, para sempre; X que só fecha sem medir). Ver §1/2/7
   obs. 4 e 11, §3 (dispensa da pergunta de voz pausa 14 dias após três).
7. **Estados que o app guarda mal e a mensagem some ou se repete.** Sair do app entre 1.4 e o fim encerra o onboarding sem prática nem 1.7 (§5); marco
   perdido ou repetido na revisão (§6); "Delete my Cue data" não limpa o datastore do TipKit e a dica de voz pode ficar invisível gastando cota (§3).
8. **Texto morto traduzido em 19 idiomas e estados inalcançáveis:** variantes com título de projeto (`showsTitles` sempre falso), `WhatsNewCatalog` vazio,
   estado provisional, pausa/quiet hours editáveis sem UI, "CHAPTER 5 · PRACTICE", `OnboardingUniverseCanvas.star`. Ver §1/2/7 obs. 6, §5, §6.
9. **Traduções a corrigir** (o catálogo está completo, mas há erros de sentido por chave compartilhada ou sem comentário): "Time" → "Tempo" na hora da
   rotina; "Start" → "Início" no botão da lista de passos; "Done" → "OK" como estado de passo; "Share %lld more videos" sem plural ("Share 1 more videos"); letras
   Y·O·U e VOICE/CAMERA na arte em inglês em todos os idiomas. Ver §1/2/7 obs. 7, §4, §5, §6.
10. **Tom.** O Cue fala de si na 3ª pessoa em quase tudo, mas "We'll open %@ next" no passo da fila; "✦ PREPARING YOUR SCRIPT" sugere IA num roteiro fixo;
    o corpo da notificação de Skin fala de aparência, contra a regra do próprio `NOTIFICATIONS.md`. Gênero de "Ultra AI" (o) vs "Apple Intelligence" (a) em pt.
11. **Acessibilidade e contraste.** Nenhuma dica (TipKit ou viagem) é anunciada ao VoiceOver quando aparece; contraste da dica de voz sobre vidro não é
    medido; textos do onboarding em `Flight.ink.opacity(0.6)` e `ink3` contrariam a regra de contraste do CLAUDE.md. Ver §3, §4, §5.
12. **Lacunas onde o criador não recebe orientação:** permissão de Fala recusada sem aviso nem caminho para os Ajustes (§5); onboarding não pode ser revisto
    nem tem voltar (§5); sem tela "What's new", sem pedido de avaliação, widget, Live Activity, badge; notificações sem ações (Snooze/Amanhã); selo "NEW"
    eterno em Personalize (§1/2/7 obs. 10, 12, 13).
