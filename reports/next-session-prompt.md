# Prompt para a próxima sessão (Cue Studio · editor)

Cole o bloco abaixo como primeira mensagem da sessão nova.

```
Continue o trabalho do editor do Cue Studio (Quick edit) iniciado na sessão de 16/10/2026. Responda e escreva os relatórios em português.

ONDE ESTÁ
- Worktree: /Users/iagoxavierdelima/Desktop/Projects/CueStudio/.claude/worktrees/editor-award, branch feature/editor-award (a partir de main 4653ecc).
- A branch foi enviada (push) no fim da sessão. O último commit ("WIP …") tem código ainda NÃO compilado: a seleção nova do Edit by text,
  o modo device-ui e três testes novos. Rode `git status` e `git log --oneline main..HEAD` primeiro.
- Leia antes de tudo: CLAUDE.md; reports/editor-award-report.md (relatório); reports/editor-award-checklist.md (progresso);
  reports/editor-award-pr.md (descrição do PR); reports/next-export-reliability-plan.md (plano da próxima etapa); DESIGN_PROJECT.md §37
  (estado do editor); reports/editor-references.md (referências e licenças).
- A memória da tarefa está em editor-award-task.md (MEMORY.md).

O QUE FICOU EM ANDAMENTO NO FIM DA SESSÃO ANTERIOR (confira o estado de cada um)
1. Código do último commit WIP, que ainda precisa compilar e passar nos testes:
   - Edit by text com início/fim explícitos: seta na 1ª palavra, "Start: “x”. Now tap the last word…", "From “x” to “y”", botão Pick again; dica nova.
   - scripts/test.sh com o modo `device-ui <Classe>` e EditByTextDeviceTests registrado.
   - Testes novos: Cue StudioTests/Language/EditByTextDeviceTests.swift, Cue StudioUITests/RealTakeWorkflowUITests.swift e
     Cue StudioTests/Managers/TemplateCaptionOptionsCaptureTests.swift (este escrito por um agente).
   - Compile (`scripts/build.sh tests`), rode QuickEditTranscriptEditTests e QuickEditAuditFixTests, corrija o que quebrar e faça o commit.
2. Testes interrompidos ao fechar a sessão; nenhum chegou ao fim, rode todos de novo:
   - `scripts/test.sh ui`: o plano de UI inteiro. Na última rodada parcial: 235 aprovados, 0 falhas.
   - `CUE_DEVICE="iago Lima iphone" TEST_RUNNER_CUE_REAL_TAKES=pt-BR scripts/test.sh device EditByTextDeviceTests`:
     Edit by text com fala real, fixtures pt-BR/en e cópias das takes de Paris do dono.
   - `CUE_DEVICE="iago Lima iphone" TEST_RUNNER_CUE_REAL_TAKE_UI=1 scripts/test.sh device-ui RealTakeWorkflowUITests`:
     o dia de criador inteiro numa take real. Ele edita essa take e manda um vídeo ao Fotos; o dono autorizou. Diga a ele qual take foi.
     Ainda não rodou: a take do dono não foi alterada.
3. Estilos de legenda dos templates:
   - O dono achou as legendas dos templates "feinhas" e pediu os recursos mais estilizados do app.
   - Um agente começou a renderizar as opções (atual + A/B/C por template) e foi interrompido. Há uma primeira rodada parcial (round1) em
     /private/tmp/claude-502/-Users-iagoxavierdelima-Desktop-Projects-CueStudio/b9e74f95-a121-4460-a872-c993a3ccd67a/scratchpad/caption-options/
     (se a pasta não existir, gere de novo com TemplateCaptionOptionsCaptureTests).
   - Monte uma página de opções (Artifact) para o dono escolher, aplique em Models/VideoTemplate.swift, teste e atualize DESIGN_PROJECT.
4. Finalizar a branch:
   - check-warnings.sh, plano Full, instalação no iago Lima iphone (`CUE_DEVICE="iago Lima iphone" scripts/build.sh install`);
   - commit, push (gh não está autenticado: dê ao dono o link de compare para abrir o PR no site, com a descrição de reports/editor-award-pr.md);
   - relatório final em português; limpar o scratchpad.

GUIA DE TESTE DO DONO
- Página "Roteiro de teste do editor": https://claude.ai/artifact/PCbfSo3E24EisENwd1pzZG. Leia as marcações dele com ArtifactData,
  coleção "results", docs t1..t6.
- Já testado por ele:
  - Templates: legendas feias (item 3 acima).
  - Edit by text: seleção confusa (corrigido, item 1).
  - Transições somem ao reordenar clipes: é o comportamento atual (a transição anda com o clipe que vem depois do corte); ele aceitou.

PRÓXIMAS TAREFAS (depois de fechar a branch, numa branch nova)
A. Exportação confiável (plano em reports/next-export-reliability-plan.md):
   - exportação que continua fora do app com BGContinuedProcessingTask;
   - GPU em segundo plano: o dono JÁ ATIVOU "Background GPU Access" no portal; acrescente o entitlement
     com.apple.developer.background-tasks.continued-processing.gpu, confirme no perfil novo e em BGTaskScheduler.supportedResources;
   - retomar a exportação depois de fechar o app;
   - aviso de iPhone quente (o aviso já existe na folha de exportação: DeviceHeat);
   - medição num iPhone 15 comum (A16), o piso do público.
B. Funções novas, nesta ordem, cada uma começando por um protótipo medido no aparelho:
   - análise de movimento em segundo plano (Vision, salva por gravação);
   - Seguir rosto no Format/Crop;
   - rastreamento ("Seguir" em texto, gráfico ou mídia);
   - estabilização;
   - tempo variável por clipe: curvas de velocidade e reverso;
   - cortes nas batidas, só para faixas dos Files (o app não tem biblioteca de música por decisão do dono).
C. Pendências da comparação com o CapCut: localizar e trocar nas legendas, seleção de várias linhas, Replace clip, Extract audio.
D. Pendências técnicas:
   - plural nas strings (o catálogo não usa variações; foi contornado reescrevendo as frases);
   - congelar quadro em vídeo HDR (sai em SDR 8-bit);
   - o aviso logo depois de fechar uma folha não aparece na árvore de acessibilidade do XCUITest (é visível e anunciado no VoiceOver).

REGRAS DO DONO (memória)
- Até 2 agentes extras ao mesmo tempo, sempre Opus 5.5 com esforço alto. Só um compila por vez; o outro só lê ou trabalha em arquivos
  separados. Quando o trabalho for complexo, pode subir o esforço pontualmente.
- Testes e instalação no "iago Lima iphone" (iPhone 15 Pro, UDID 00008130-001274381451001C). O dono deu permissão total, inclusive para
  usar as takes reais dele (vídeos sobre Paris). Prefira cópias quando elas dão o mesmo resultado, e sempre diga o que mudou no aparelho.
- O dono não edita vídeos: quando pedir teste a ele, escreva um guia passo a passo para iniciante (o que tocar, o que deve ver, o que é
  problema), de preferência numa página com caixas de marcar.
- Ao fim de cada entrega do editor, compare o fluxo com o de editores de celular (CapCut, Edits, InShot); se a diferença importar, mude o
  layout e registre a decisão no DESIGN_PROJECT.
- Ordem de trabalho: diretriz "award winning", público com iPhone 15 ou mais novo (sem rebaixar qualidade por modelo), nada que trave o
  aparelho, tudo no iPhone, sem serviços pagos nem nuvem, projetos e vídeos do usuário nunca perdidos.
- Antes de terminar, rode sempre: zero warnings, Full, contraste medido nos tokens novos, strings nos 20 idiomas (scripts/strings.py),
  DESIGN_PROJECT atualizado e `xcrun simctl --set testing delete all` depois dos testes.

COMECE POR: `git status`; terminar o item 1 e commitar; ver os resultados (ou rodar de novo) do item 2; o item 3 com o dono; e o item 4.
```
