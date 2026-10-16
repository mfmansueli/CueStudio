# Próxima branch: exportação confiável fora do app e com o aparelho quente

Desenho técnico para começar a branch seguinte (depois de `feature/editor-award`). As APIs foram conferidas nos headers do SDK do iOS 27
instalado (`BackgroundTasks.framework/Headers/BGTaskRequest.h`, `BGTask.h`, `BGTaskScheduler.h`). Os passos marcados **(confirmar no aparelho)**
dependem do sistema e só se provam no iPhone.

## 1. Exportação que continua fora do app (`BGContinuedProcessingTask`, iOS 26+)

**O que a API garante, segundo os headers:**
- **Pedido:** `BGContinuedProcessingTaskRequest(identifier:title:subtitle:)`.
  - Começa já, ou logo depois de enviado, e continua com o app em segundo plano.
  - O sistema mostra uma **Live Activity** com o título, o subtítulo e o progresso.
  - O `earliestBeginDate` é ignorado.
- **Identificador:** precisa terminar em `.*` no Info.plist (`BGTaskSchedulerPermittedIdentifiers`), com o bundle ID como prefixo. Para o Cue:
  - no Info.plist: `com.cuestudioteleprompter.export.*`;
  - em cada envio: `com.cuestudioteleprompter.export.<id da operação>`.
- **`strategy`:**
  - `.queue` é o padrão: entra numa fila se o sistema estiver ocupado, e a fila é cancelada se a pessoa fechar o app pelo seletor de apps;
  - `.fail` falha na hora (`immediateRunIneligible`);
  - o Cue usa `.fail` e, se falhar, exporta como hoje, com o app aberto, para nunca ficar "na fila" sem a pessoa saber.
- **Progresso obrigatório:** a tarefa **precisa** informar progresso (`NSProgressReporting`). Uma tarefa que parece parada é encerrada pelo sistema.
  O progresso do `VideoExportService`, de 0 a 1, vai para `task.progress.completedUnitCount`.
- **Título durante o trabalho:** `task.updateTitle(_:subtitle:)` muda o que a Live Activity mostra, por exemplo "Exportando 1080p · 42%".
- **Registro:** `BGTaskScheduler.shared.register(forTaskWithIdentifier:using:launchHandler:)`.
  - Para esta tarefa, o registro pode ser feito **depois** do lançamento (os headers a isentam da regra geral). Registra-se uma vez, no `AppServices`; registrar duas vezes encerra o app.
- **Erros ao enviar:** `notPermitted` aparece quando:
  - falta o identificador no Info.plist;
  - falta o modo de segundo plano;
  - foi pedido um recurso indisponível;
  - a pessoa negou atividade em segundo plano.
- **GPU — o ponto mais importante:**
  - Por padrão, a tarefa só tem **CPU e rede** em segundo plano.
  - Usar a GPU exige `requiredResources = .gpu` **e** o entitlement `com.apple.developer.background-tasks.continued-processing.gpu`.
  - Nem todo aparelho suporta: consultar `BGTaskScheduler.supportedResources`.
  - Mesmo com o entitlement, a GPU pode ser negada se estiver disputada.
  - O compositor do Cue (`CueVideoCompositor`, Core Image) e a codificação dependem dela.

**Desenho:**
1. **Configuração (texto, nunca no `project.pbxproj`):**
   - `Config/App.xcconfig` e o Info.plist ganham o identificador e o modo de segundo plano;
   - o entitlement de GPU entra em `Cue Studio.entitlements`;
   - o **perfil de provisionamento** precisa da capability, o que exige ação do dono no portal Apple Developer, **a pedir antes de começar**.
2. **`BackgroundExportRunner`** (serviço novo em `Managers/Export/`):
   - envolve o `VideoExportService` e é o único lugar que importa `BackgroundTasks`;
   - **ao tocar Export:** envia o pedido (`.fail`; `.gpu` se suportado) e roda a exportação dentro do `launchHandler`, informando o progresso;
   - **se o envio falha:** exporta como hoje, com a tarefa de segundo plano curta (`beginBackgroundTask`) e a mensagem atual se o app sair;
   - **`expirationHandler`:** cancela o `AVAssetExportSession`/escritor e apaga o arquivo parcial;
   - **ao terminar:** `setTaskCompleted(success:)`, e o `ExportLedgerService` registra a operação como hoje (a contagem das 5 grátis não muda).
3. **Sem GPU em segundo plano:**
   - Se `supportedResources` não incluir `.gpu`, ou a GPU for negada, a renderização com Core Image em segundo plano não é garantida.
   - Opção segura: só usar o caminho de segundo plano quando `.gpu` for concedido; nos outros casos, manter o comportamento atual ("mantenha o Cue aberto").
   - **(confirmar no aparelho)** se um `CIContext` com Metal falha ou cai para CPU em segundo plano sem o recurso.
4. **Retomar depois de fechar:**
   - O ledger já guarda a operação e reaproveita o arquivo renderizado (`reusableOperation`). Uma exportação interrompida fica marcada como
     **interrompida** no ledger.
   - Ao reabrir a edição, o editor oferece "Continuar exportação", que recomeça. O `AVAssetWriter` não retoma no meio, então recomeçar é o honesto.
5. **Interface:** na folha de exportação, "Pode sair do Cue: a exportação continua" quando o caminho de segundo plano foi aceito. Notificação ao terminar:
   já existe `onFinished` (`NOTIFICATIONS.md`); a Live Activity do sistema substitui o progresso na tela.
6. **Testes:**
   - unidade, com um runner falso (aceito / recusado / expirado): a exportação termina, cai para o modo atual, apaga o arquivo parcial e não conta duas vezes;
   - **(aparelho)** exportar 4K de 60 s, sair para outro app, abrir a Câmera e voltar.
   - Há relatos nos fóruns de que o handler não é chamado em certas versões do iOS 26. Se não rodar, cai no modo atual.

## 2. Aparelho quente

- **Leitura:** `ProcessInfo.processInfo.thermalState` (`.nominal`, `.fair`, `.serious`, `.critical`), observada com
  `ProcessInfo.thermalStateDidChangeNotification`, num serviço pequeno (`ThermalStateService`, `@Observable`).
- **Na exportação:**
  - em `.serious` ou `.critical`, a folha diz "O iPhone está quente. A exportação vai levar mais tempo; deixe-o esfriar se puder.";
  - nada de reduzir a qualidade; o vídeo sai igual.
- **Na prévia:** nenhuma mudança. As animações também não mudam: o dono decidiu que o modo de pouca energia não para animações, e o mesmo vale aqui.
- **Testes:** unidade com estado térmico injetado. No aparelho, só observação, porque não há como forçar o calor.

## 3. Medição no iPhone 15 Pro (o dono não tem um iPhone 15 comum)

O piso do público é o iPhone 15 comum (A16), mas o dono não tem um (16/10/2026): rodar `EditorExportDeviceTests` e
`QuickEditPreviewLatencyTests` no iago Lima iphone (15 Pro, A17 Pro), com o aparelho descansado e um conjunto por vez, e registrar no relatório
que o A16 **não foi validado** (sem estimar números para ele).
- **Metas:** prévia abaixo de 33 ms por quadro em 1080p; exportação 1080p da montagem completa abaixo de 1× a duração.
- **Hoje, no 15 Pro:** 0,75× em 1080p e 1,03× em 4K.

## 4. Pendências herdadas da `feature/editor-award`

- Decodificar textos, mídias e músicas elemento por elemento. Hoje um elemento corrompido descarta a lista inteira ao abrir a edição; isso já
  acontecia antes da branch.
- Plural nas strings com número ("Cut %lld words").
- Diferenças com o CapCut que ficaram para depois:
  - localizar e trocar nas legendas, e seleção de várias linhas;
  - Replace clip;
  - Extract audio.
- HDR no congelar quadro: o quadro sai em SDR, de 8 bits.
