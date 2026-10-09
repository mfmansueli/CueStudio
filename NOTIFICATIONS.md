# Cue Studio — Notificações e descoberta de ferramentas

Como o Cue chama o criador de volta para terminar um trabalho de verdade e conhecer ferramentas que ele ainda não usou. Só **notificações
locais** (`UserNotifications`): nada de servidor, push, APNs, chave de API ou SDK novo. Leia com `ARCHITECTURE.md`, `SHARING.md` (o que
"compartilhado" e "postado" significam) e `DESIGN_PROJECT.md` §27 (as telas).

Toda notificação tem um motivo real, um benefício claro, uma ação e um destino específico. Nada de culpa, urgência falsa, "sentimos sua
falta", comentário sobre aparência ou promessa de views e seguidores.

## 1. Onde está o código

| Parte | Onde |
|---|---|
| Valores (categoria, campanha, destino, payload, lembrete, rotina, estado…) | `Models/Notifications/` |
| Regras puras: `ProjectCampaigns`, `NotificationPlanner`, `NotificationPolicy`, `PlanningContext` | `Managers/Notifications/Planning/` |
| Descoberta: `FeatureCatalog` (dados), `DiscoveryRules`, `FeatureAdoption`, `FeatureID+Copy`, `WhatsNewCatalog` | `Managers/Notifications/Discovery/` |
| Serviço: `NotificationService` (+`Reconcile`, `+Plan`, `+Reminders`, `+Discovery`, `+Opening`, `+Metrics`) | `Managers/Notifications/` |
| Fatos lidos do app: `AppNotificationFacts` (atrás de `NotificationFactsSource`) | `Managers/Notifications/` |
| Sistema: `NotificationCenterClient` → `SystemNotificationCenter`; `NotificationCenterDelegate`; `NotificationRouter` | `Managers/Notifications/Center/` |
| Textos: `NotificationCopy`, `FeatureID+Copy`, `FeatureIntro.Note.text` | idem |
| Navegação: `NotificationNavigator`; gatilhos: `NotificationTriggers` | `Screens/Main/Support/` |
| Telas: Settings › Notifications, `ReminderSheet`, `FeatureIntroSheet`, menu "Post later" | `Screens/Settings/Notifications/`, `Screens/Shared/{Reminders,Discovery}/`, `ShareQueueStep` |

O serviço é criado em `AppServices.makeNotifications` e injetado no ambiente; o delegate do sistema é registrado em `CueStudioApp.init`, antes do
fim do lançamento, para um toque que abriu o app chegar.

## 2. Campanhas

Prioridade 1 é a primeira. "Automática" = o Cue decide a hora, sob os limites (§6).

| Campanha (`NotificationCampaign`) | Categoria | Prior. | Elegibilidade (estado real) | Espera | Destino | Texto (chaves) |
|---|---|---|---|---|---|---|
| `reminder` | My reminders | 1 | O criador escolheu Tonight / Tomorrow / data e hora (script, take, ou rede deixada para depois) | a hora escolhida | script → página; take → revisão; rede → passo da fila daquela rede | "Your script is waiting" / "%@ is waiting", "Your recording is waiting", "Ready to post on %@" + corpo |
| `exportReady` | Continue my projects | 2 | Uma exportação terminou com o app fora da tela | imediata (1 s) | revisão da take | "Your video is ready" / "It’s saved to Photos. Open Cue to share it." |
| `incompleteSharing` | Continue my projects | 3 | Uma `ShareQueue` com redes `pending` ou `later` | 24 h desde `ShareQueue.updatedAt` | próximo passo da fila (`.continueQueue` / `.postLater(rede)`) | "Next stop: %@" / "Continue sharing your video on the networks you selected." |
| `firstRecording` | Continue my projects | 4 | O primeiro script pronto (READY) e nenhuma take no app | 48 h | página do script (botão Record; nada liga a câmera) | "Your first script is ready" / "Try recording it with the teleprompter. Your first star is one take away." |
| `readyToRecord` | Continue my projects | 4 | Script READY sem take (o criador já gravou antes) | 48 h | página do script | "Turn your script into a video" / "Your next recording is one tap away." |
| `unfinishedScript` | Continue my projects | 4 | Rascunho com ≥ 8 palavras (`meaningfulWords`) | 72 h desde `updatedAt` | página do script, editando | "Your idea has already started" / "Continue where you left off." |
| `recordingToFinish` | Continue my projects | 4 | Take(s) com trabalho restante (estágio ≠ shared) e nada exportado | 48 h desde a gravação | estágio edit → Quick edit; senão revisão | "Your recording is saved" / "Continue editing whenever you’re ready." |
| `savedIdea` | Continue my projects | 4 | A nota mais antiga do Logbook ainda esperando | 7 dias | Logbook, com a nota em destaque | "An idea is waiting in your Logbook" / "One of your ideas is waiting to become a video. Want to develop it?" |
| `returnAfterInactivity` | Continue my projects | 4 | Sempre planejada: 7 e 21 dias após a última atividade, sobre o melhor projeto real (ou "+") | 7 d e 21 d | o do projeto, ou "+" | os do projeto, ou "Ready for your next video?" |
| `routine` | My creation routine | 5 | O criador escolheu dias e hora | semanal, repetida | o próximo passo decidido no toque (`.nextAction`) | "Your creation time" / "Your next video starts here. Cue opens on the step that’s next." |
| `feature` | Discover tools and ideas | 6 | `FeatureCatalog` (§4) | 24 h após a última atividade | a introdução da ferramenta, depois a ferramenta | `FeatureID.notificationTitle` / `.notificationBody` |
| `availableIdea` | Discover tools and ideas | 6 | Uma ideia do modelo guardada e ainda não vista (`IdeaSuggestionService.unseenModelIdeas`) | 24 h | a ideia no campo do dock (`IdeaKey`), nada é escrito | "An idea for your next video" / "Explore an idea for your next video about %@." (tema só com títulos permitidos e só nome do Cue) |
| `yearInReview` | What’s new in Cue | 7 | O Year in Review está pronto (regras do universo: 3+ vídeos, a partir de 1º de dezembro), uma vez por ano | imediata | Your universe com a história aberta | "Your year in review is ready" / "See the videos that shaped your universe this year." |
| `whatsNew` | What’s new in Cue | 7 | Uma entrada de `WhatsNewCatalog` da versão instalada, só para quem **atualizou** | 24 h | o destino da entrada | "New in Cue" / … |

**Um passo por projeto:** um script e suas takes são um projeto (`ProjectKey`); vale o passo mais adiantado (fila > takes > pronto > rascunho).
**Registros de demonstração:** em produção não existem; os de exemplo só existem com `-uiTestSeedSamples` (Debug).

## 3. Consentimento e permissão

- **Categorias** (Settings › Notifications): *My reminders*, *Continue my projects* e *My creation routine* começam ligadas; **Discover tools
  and ideas** e **What’s new in Cue** começam **desligadas** e só ligam com um sim. O consentimento de descoberta vale também para as
  introduções dentro do app.
- **Permissão do iOS é separada** e nunca é consentimento para promoções. O Cue **não pede no lançamento**: pede ao criar o primeiro lembrete, ao
  ligar uma categoria ou ao configurar a rotina. Com `.notDetermined`, nada é agendado. Recusada: o app segue igual, o lembrete fica em Cue
  ("Kept in Cue"), a página mostra **Open Settings** (toque do criador) e o Cue **nunca pergunta de novo**. `.provisional` agenda (entrega
  silenciosa) e a página explica. O estado é relido quando o app fica ativo e ao voltar dos Ajustes.
- **Quiet hours** (21:00–09:00 por padrão, editáveis), **pausa** de 7 ou 30 dias (só automáticas) e **Show titles in previews** (desligado: "your
  script"). Script, comentário e texto importado **nunca** entram numa notificação; o payload só tem tipos e IDs.

## 4. Descoberta (`FeatureCatalog`)

Cada entrada tem: `FeatureID`, `campaignID` versionado (`discover.cleanUp.v1`), ícone, requisitos (`FeatureRequirement`), alvo
(`DiscoveryTarget`: um lugar, um script pronto, uma take adequada ou um vídeo para rede social), canais (notificação / app) e a nota mostrada
antes de "Try it". O cooldown e o limite são os de `NotificationPolicy`; "Not now" adia 30 dias; "Don’t suggest this" é para sempre.

| Ferramenta | Requisitos | Alvo → destino | Uso de verdade (para de oferecer) |
|---|---|---|---|
| My Cue Voice | Apple Intelligence, ≥ 2 scripts, voz ainda sem o mínimo | as 4 perguntas (`VoiceSetupSheet`) | `hasMinimumVoice` |
| Import my writing | Apple Intelligence, voz configurada, nada importado | `WritingImportSheet` | trechos ou fingerprint salvos |
| Ideas | Apple Intelligence, temas | "Need an idea?" | uma ideia sugerida enviada ou usada (evento) |
| Logbook | ≥ 1 script | Logbook | qualquer nota já anotada |
| Voice Following | prompter em Steady; script pronto num idioma que o iPhone ouve | página do script (Record) | o prompter guardado em Voice |
| Clean Up | take ≥ 10 s, não analisada, idioma ouvido | Quick edit › Pauses (a análise começa só depois do "Try it") | uma sugestão decidida (Keep/Remove) |
| Auto captions | take sem legendas, idioma ouvido | Quick edit › Auto captions (nada é gerado sem "Generate") | legendas na edição |
| Caption translation | take com legendas, par de idiomas suportado (`LanguageCapabilityService.translation`) | Captions + folha de tradução (escolher idioma) | uma tradução salva |
| Studio Voice | take ≥ 3 s | Quick edit › Studio Voice | nível ≠ padrão |
| Covers | take ainda não exportada | Quick edit › Cover | capa escolhida |
| Layers (B-roll) | um vídeo já terminado | folha de mídia (nada entra sem escolher) | uma mídia sobre a take |
| Voice-over | um vídeo já terminado | Quick edit › Voice-over (gravar exige o botão) | um voice-over |
| Backgrounds | gravou; segmentação suportada | Quick edit › Background | um fundo |
| Skin Smoothing | um vídeo já terminado | Adjust no dial Skin Smoothing (começa em 0) | valor > 0 |
| Safe zones | vídeo ou script para TikTok/Reels/Shorts/Stories | Settings › Prompter › Social safe zone | zona ligada |
| Remote Control | gravou; **só no app** (sem sinal de segundo aparelho) | Settings › Remote | conexão de controle (evento) |
| Your universe | ≥ 3 vídeos compartilhados | Your universe | visita (evento) |

Nenhuma é paga: as ferramentas do editor são grátis, e nenhuma notificação abre exportação, paywall ou "Your video is ready". Ferramentas
planejadas (correção de olhar, Radar de tendências) **não** estão no catálogo. `WhatsNewCatalog` está **vazio na 1.0** (não há versão anterior
para alguém atualizar); cada versão nova acrescenta só o que é real e usável nela.

**Depois do toque** vem a introdução (`FeatureIntroSheet`: nome, um benefício, a nota — Apple Intelligence, modelo de fala, download de
tradução, segundo aparelho, "Free. Nothing changes until you choose." — **Try it**, **Not now**, **Don’t suggest this**). Nada liga câmera ou
microfone, gera texto, baixa modelo, analisa, traduz, exporta, gasta cota ou posta sozinho.

**No app** (com a categoria ligada): no máximo uma introdução por sessão, depois de sair do teleprompter/editor, ou a de uma notificação que
chegou enquanto o criador estava ocupado; nunca no dia de uma dica do My Cue Voice e no máximo uma descoberta por semana.

## 5. Lembretes, rotina e relógio

- **Hora de parede flutuante** (`LocalDateTime`): "amanhã às 10:00" toca às 10:00 no fuso em que o iPhone estiver. Ao mudar o fuso
  (`.NSSystemTimeZoneDidChange`) tudo é reagendado. Horário de verão: um horário que **não existe** toca no primeiro minuto depois do salto
  (02:30 → 03:00); um que **acontece duas vezes** toca na primeira.
- **Passado:** recusado ("Pick a time in the future"). Um lembrete vencido fica na lista como "Due" por 7 dias e some; aberto, some na hora.
- **Sucesso só com o sistema:** "Reminder set · …" aparece só depois de `UNUserNotificationCenter.add` dar certo. Falha: nada fica e o toast
  diz "Couldn’t set the reminder · Try again". Notificações desligadas: fica em Cue e o toast oferece Settings.
- **Quiet hours** não afetam o que o criador escolheu; dentro delas, a folha explica que vai tocar mesmo assim.
- **Rotina:** um pedido semanal repetido por dia escolhido; ao tocar, abre o melhor próximo passo naquele momento.

## 6. Frequência, prioridade e capacidade (`NotificationPolicy`)

Só para automáticas (lembretes e rotina ficam fora dos limites):

- 1 em qualquer janela de 24 h; 2 em qualquer janela de 7 dias, todas as categorias juntas;
- 1 ferramenta/ideia em 7 dias; nenhuma no dia de uma dica do My Cue Voice (e a dica não aparece no dia de uma introdução);
- a mesma ferramenta no máximo 2× em 90 dias e com 30 dias entre elas; nunca depois do uso de verdade;
- nada a menos de 12 h de um lembrete ou da rotina; quiet hours empurram para o fim delas; pausa segura até acabar;
- a volta após uma pausa de atividade (7 e 21 dias) **substitui** as outras automáticas a partir da primeira tentativa, e nada vem depois da
  segunda até o criador voltar.

`NotificationPlanner` é puro e determinístico: candidatos em ordem de prioridade (depois o mais cedo, depois `rank`); cada um pega o primeiro
momento que respeita tudo, contando o que já foi enviado e o que o plano já reservou. Sem candidato que valha, nada é enviado.

**Capacidade:** no máximo 32 pedidos pendentes (o iOS aceita 64): 7 da rotina, 4 automáticas e o resto (21) para os lembretes mais próximos.
Lembretes além disso ficam em Cue ("Kept in Cue", toast "Saved · Cue schedules it closer to the time") e entram quando abre vaga.

## 7. Agendamento, cancelamento e atribuição

- **Reconciliação** (`NotificationService.reconcile`) ao abrir e ao sair do app, e quando muda algo que o plano lê (scripts, takes, filas,
  Logbook, conta, idioma, fuso, consentimento, pausa, lembretes). Sem polling, sem timer, sem análise de vídeo, sem chamada ao modelo.
- **IDs determinísticos** (`NotificationIdentifier`: `cue.reminder.<id>`, `cue.routine.<dia>`, `cue.auto.<campanha>.<ferramenta>.<projeto>`,
  `cue.done.export.<take>`): o mesmo pedido substitui o anterior; um pedido igual (mesmo texto, hora e payload — JSON com chaves ordenadas) não é
  reenviado; o que não é mais desejado é cancelado.
- **Cancela quando:** o script ou a take somem; o projeto muda de passo; a rede é confirmada ou a fila termina/é descartada (lembrete de Post
  later); o criador cancela ou edita; a categoria é desligada; a ferramenta deixa de estar disponível; idioma ou fuso mudam (reescreve);
  "Delete my Cue data" (`DataEraserService` → `eraseAll`: lembretes, rotina, histórico; ficam as escolhas de consentimento, quiet hours e
  "não sugerir"); a conta muda.
- **Enviado ≠ entregue:** um pedido automático cuja hora passou conta como **enviado** para os limites (leitura conservadora) e nunca é chamado
  de entregue ou visto. Ausência de toque não é dispensa.
- **Toque** (`NotificationRouter` → `RootView`): espera o primeiro voo terminar e o criador sair da câmera/editor/controle remoto; cada entrega é
  tratada uma vez (memória das últimas 50); payload validado (versão 1, prefixo `cue.`); o objeto é verificado de novo
  (`NotificationNavigator`): script apagado → Scripts + "That script is no longer in Cue"; take apagada → Takes; fila já terminada → revisão +
  "Already shared on the networks you chose"; ideia que sumiu → toast; sem Apple Intelligence → Scripts + motivo.
- **Em primeiro plano:** gravando, no teleprompter, editando, exportando ou no controle remoto → só na Central de Notificações, sem som; uma
  ferramenta fica para uma introdução depois. Ferramentas e novidades chegam como `.passive` (sem som, sem acender a tela).
- **Atribuição:** abrir grava um `AttributionContext` por **24 h**. Nesse período, a ferramenta usada de verdade conta `feature_completed` e o
  projeto que mudou de passo conta `next_action_completed`. Depois, nada é atribuído.

## 8. Limites do segundo plano

Notificações locais são agendadas enquanto o Cue roda e entregues pelo iOS depois. O Cue **não** roda em segundo plano para planejar: o plano é
feito ao sair do app e vale até a próxima abertura. Uma exportação pode terminar com o app fora da tela (o editor pede tempo ao sistema) e só
então é notificada; o Cue não promete que exportação ou IA continuem indefinidamente em segundo plano.

## 9. Medição

`NotificationService+Metrics`: contador local por campanha e resultado (`eligible`, `suppressed` + motivo, `scheduled`, `scheduling_failed`,
`cancelled`, `opened`, `snoozed`, `opted_out`, `feature_started`, `feature_completed`, `next_action_completed`), lido em Settings ›
Notifications › DEBUG. Com **Help improve Cue** ligado, o mesmo evento vai ao Firebase Analytics já existente (`cue_notification`: campanha,
categoria, resultado, motivo). Nunca título, texto, escrita importada, áudio ou identidade social. *Eligible* e *suppressed* contam uma vez por
dia por pedido. Não há contagem de entrega ou impressão (o iOS não informa).

## 10. Persistência

`NotificationState` (JSON em `DefaultsKey.notificationState`), com `schema` e todos os campos lidos com valor padrão; uma entrada ilegível de uma
lista cai sozinha. Estado danificado → recomeça (`.damaged`) sem inventar histórico. **Primeira execução após atualizar:** `startedAt` = agora,
e todo projeto espera a partir daí (ninguém recebe todos os rascunhos antigos de uma vez). `ShareQueue.updatedAt` é novo e opcional.

## 11. Futuro (desligado)

Radar de tendências e qualquer notificação de servidor ficam **fora** até existir fonte de dados e infraestrutura reais: não há Firebase
Messaging, APNs nem backend nesta versão.

## 12. Testes

**Unidade (Swift Testing), `Cue StudioTests/Notifications/`:** `NotificationPlannerTests` (limites diário/semanal/descoberta, histórico,
cooldown e limite por ferramenta, quiet hours, ±12 h, dia da dica, pausa, retorno substitui, um por projeto, prioridade, `rank`, capacidade,
horizonte, determinismo), `ProjectCampaignsTests`, `DiscoveryRulesTests` (requisitos, IA, idioma, par de tradução, canal só-app, uso/recusa/
adiamento, ordem), `FeatureAdoptionTests` (abrir não é usar), `NotificationTimeTests` (salto e repetição do horário de verão, fuso, Tonight/
Tomorrow, passado, quiet hours, rotina), `NotificationStorageTests` (ida e volta, estado antigo/parcial, entrada desconhecida, estado danificado,
payload versionado e estável, What’s new só em atualização, roteador sem duplicata), `NotificationServiceTests` (sem pedido de permissão ao
planejar, padrões, negado nunca pergunta de novo, lembrete agendado/mantido/falha/passado/edição/cancelamento/capacidade, assunto apagado,
Post later cancelado ao postar, rotina, descoberta só com sim, categoria desligada cancela, pausa, reenvio só quando muda e com idioma novo,
exportação só fora da tela, apagar dados), `NotificationServiceOpeningTests` (uma abertura por entrega, payload inválido/alheio, introdução
antes da ferramenta, lembrete aberto some, crédito em 24 h e expiração, próximo passo concluído, primeiro plano ocupado, objeto apagado,
introdução no app uma por sessão, Not now/Don’t suggest, Try it ≠ concluído, eventos), e em `VoiceQuestionSchedulerTests` /
`ShareQueueServiceTests` a coordenação com a dica e o carimbo da fila.

**UI (XCUITest), `NotificationsUITests`:** padrões da página, permissão negada, lembrete pelo script (e listado), lembrete guardado com
notificações desligadas, toque frio abre o script, introdução da ferramenta e Not now, Try it abre Clean Up na take, script apagado, payload
ilegível, toque repetido; `ShareToUITests.testPostLaterCanRemindTheCreatorTomorrow`. Ganchos Debug: `-uiTestNotificationAuth
<notDetermined|refuses|authorized|denied|provisional>` (central em memória, sem prompt do sistema) e `-uiTestNotificationTap
<script|cleanUp|share|deletedScript|invalid|duplicate|routine|logbook|universe>`.

Resultados desta entrega: ver o relatório final do PR (suíte completa e `check-warnings.sh`).

## 13. Conferir num iPhone de verdade

O Simulator agenda, mas a entrega, o Foco e a abertura a frio só se confirmam no aparelho. Para ver **todas** sem esperar o plano (que espalha
as automáticas por dias), um build Debug tem em Settings › Notifications › DEBUG o botão **Preview every notification**: uma de cada tipo, com os
textos reais e apontando para os scripts, takes e ferramentas do aparelho, a cada 6 s a partir de 5 s (limites e consentimento ignorados só
aqui; nada é contado). Ligue antes "Discover tools and ideas" e "What's new" se quiser vê-las com a permissão já dada, toque no botão e bloqueie o
iPhone.


1. Primeiro lembrete (página do script › ••• › Remind me… › Tomorrow): o prompt do iOS aparece **só agora**; aceitar → "Reminder set";
   recusar → "Saved in Cue · notifications are off" e a página mostra Open Settings.
2. Lembrete para daqui a 2 minutos (Pick a date and time): com o app fechado e o iPhone bloqueado, chega; tocar abre a página do script
   (abertura a frio). Com o app aberto em Scripts, aparece como banner.
3. Gravando ou no editor quando um lembrete chega: sem som, só na Central; nada interrompe a take.
4. Foco ativo (ex.: Não Perturbe): lembretes respeitam o Foco do sistema; ferramentas chegam como passivas.
5. Ligar Settings › Notifications › Discover tools and ideas, ter uma take sem legendas e esperar o plano (ou mudar o relógio): a introdução abre
   antes da ferramenta; Not now não abre nada.
6. Mudar o fuso horário do iPhone com um lembrete "amanhã 10:00": continua às 10:00 no novo fuso.
7. Exportar no Quick edit e sair do app antes de terminar: chega "Your video is ready" (se a exportação terminar no tempo que o iOS dá).
8. Delete my Cue data com um lembrete marcado para dali a 2 minutos: ele não chega, e Settings › Notifications fica sem lembretes.
