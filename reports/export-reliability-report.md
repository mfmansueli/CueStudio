# Exportação confiável: relatório

Branch `feature/export-reliability`, a partir de `feature/editor-award` (1b02c52). Aparelho: iago Lima iphone (iPhone 15 Pro, iOS 27).
Estado atual da tela e regras: `DESIGN_PROJECT.md` §38. Plano de partida: `reports/next-export-reliability-plan.md`.

## 1. O que o criador ganha

- **Progresso na revisão:** "Exporting · N%" com uma barra, enquanto exporta (antes era só um indicador girando no botão).
- **Saber se pode sair do Cue:** "You can leave Cue. The export goes on." quando o iOS aceita a exportação como tarefa em segundo plano (com GPU), ou
  "Keep Cue open until it’s done." quando não aceita.
- **Exportação fora do Cue** nos iPhones que dão GPU a uma tarefa em segundo plano: o iOS mostra o progresso numa Live Activity e o arquivo e a
  entrega (Fotos, a rede) continuam com o Cue fechado.
- **iPhone quente:** "The iPhone is hot, so the export takes longer. Let it cool down if you can." durante a exportação.
- **Falta de espaço** dita antes de qualquer trabalho, com quanto liberar.
- **Exportação interrompida:** se o Cue fechar no meio (pelo seletor de apps, ou encerrado pelo iOS), a revisão daquela take diz "The last
  export stopped" com **Save video**. Se o iOS parar a exportação, o toast diz "iOS stopped the export · Try again". Nenhum arquivo parcial fica.

## 2. O que foi medido no aparelho e mudou o desenho

| Pergunta | Resposta (iPhone 15 Pro, iOS 27) |
|---|---|
| O perfil tem a capability de GPU em segundo plano? | Sim (perfil gerado em 16/10/2026, `continued-processing.gpu = true`) |
| `BGTaskScheduler.supportedResources` | **vazio**: este iPhone não dá GPU a tarefas em segundo plano |
| Tarefa contínua com GPU | Recusada (erro 1) |
| Tarefa contínua sem GPU (só CPU) | Aceita, mas a exportação **travou**: o Cue ficou acordado sem desenhar quadros e não terminou em 5 min |
| Sem tarefa, take de 2:30 em 1080p com legendas | 37 s com o Cue aberto; com 60 s fora (Home + Câmera), pronta na volta |
| Sem tarefa, take de 6:40 | 60 s fora: na volta estava em 73% e seguiu; terminou em 97 s, o mesmo tempo de com o Cue aberto |

**Decisões tomadas por causa disso:**
- Nunca pedir tarefa só de CPU (era pior do que não pedir).
- Pedir tarefa com GPU só onde `supportedResources` tem `.gpu`; nos outros iPhones, o comportamento de sempre com o aviso "Keep Cue open".
- Não fazer "recomeçar sozinho" na volta ao Cue: a exportação não falhou nem recomeçou ao voltar, então não havia o que recuperar.

**Ressalvas honestas:**
- As medições de segundo plano rodaram sob XCUITest. O iOS pode tratar um app aberto pelo teste de outro jeito; o roteiro do dono confere à mão.
- **Não validados:** o caminho com GPU e Live Activity (nenhum aparelho disponível tem GPU em segundo plano; o Mansuelli iPhone 18 Pro Max
  pode ter, não foi usado sem pedir), o iPhone 15 comum (A16; o dono não tem), um export que passe de vários minutos fora do Cue.
- Os tempos de exportação da branch anterior (1080p 0,75× e 4K 1,03× da duração no 15 Pro) não foram medidos de novo: esta branch não mexe no
  desenho dos quadros nem na codificação.

## 3. Achado e corrigido: a exportação do editor era código morto

A folha `QuickEditExportSheet` (resolução, fps, aviso de espaço, aviso de calor, capa à parte) **não era aberta por nada**: Done › Download video
passa pela revisão da take. Os avisos de espaço e de calor da `feature/editor-award` nunca chegavam ao criador. Eles foram levados para a
revisão, e a folha, o modelo, a capa à parte e 18 textos que só ela usava foram apagados (`DESIGN_PROJECT.md` §37 e o PR da editor-award foram
corrigidos).

## 4. Como funciona (código)

- `Managers/Export/Background/`: `BackgroundExportRunning` / `BackgroundExportRunner` (o trabalho inteiro; tarefa do iOS ou o tempo curto de
  sempre), `ContinuedTaskScheduling` / `SystemContinuedTaskScheduler` (único arquivo que importa `BackgroundTasks`: iOS 27
  `submitTaskRequest` fora da thread principal, `.fail`, identificador por exportação, handler na fila principal, 5 s para começar),
  `ContinuedTaskHandle`, `BackgroundExportMode`, `BackgroundExportError`.
- `TakeReviewViewModel`: `exportProgress`, `exportMode`, `exportStopped`, `ExportPreflightError.notEnoughSpace`; `PreferencesService`
  `exportsInFlight` → `stoppedExports` no lançamento seguinte.
- `VideoExportService`: apaga o arquivo parcial em qualquer falha; `AVError.operationInterrupted` vira `VideoExportError.interrupted`.
- Configuração: entitlement de GPU, `BGTaskSchedulerPermittedIdentifiers` = `com.cuestudioteleprompter.export.*`, `UIBackgroundModes` =
  `processing`.
- Bug encontrado no protótipo e corrigido: o handler da tarefa, escrito no main actor, era chamado pelo iOS em outra fila e fechava o app.

## 5. Comparação com editores de celular

CapCut e InShot mostram a porcentagem numa tela cheia com "não bloqueie a tela nem troque de app". O Cue mostra a porcentagem na tela da take,
sem tirar a pessoa dali, e diz se dá para sair (tarefa aceita pelo iOS) ou não. Nenhuma diferença que peça mudança de layout.

## 6. Testes

- Unidade: `BackgroundExportRunnerTests` (aceito, sem GPU, recusado, encerrado pelo iOS, erro do trabalho), `TakeReviewBackgroundExportTests`
  (tarefa com progresso, marcação, aviso de parada, iOS encerrando, falta de espaço); suítes antigas da revisão, contagem e compartilhamento: 104 ok.
- UI: `ExportProgressUITests` (os dois cartões, com captura e contraste medido: 15,7 / 5,6 / 11,1 : 1).
- Aparelho: `ContinuedTaskDeviceTests`, `BackgroundExportDeviceUITests` (resultados no §2).
- Textos novos nos 20 idiomas (8).
- Fechamento: ver §7.

## 7. Fechamento

(preenchido ao fim: check-warnings, Full, instalação, roteiro do dono)
