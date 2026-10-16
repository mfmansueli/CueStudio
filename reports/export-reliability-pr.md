# Exportação confiável: fora do Cue, progresso, espaço, calor e exportação interrompida

Branch `feature/export-reliability` → `main` (parte de `feature/editor-award`: abrir depois do PR dela). Detalhes em
`reports/export-reliability-report.md` e `DESIGN_PROJECT.md` §38.

## O que muda para o criador

- **Progresso na revisão:** "Exporting · N%", com uma barra, em Save, Share to universe, Share e no Download video do editor.
- **Sair do Cue:**
  - nos iPhones que dão GPU a tarefas em segundo plano, a exportação vira uma tarefa contínua do iOS (Live Activity) e o cartão diz "You can leave
    Cue. The export goes on.";
  - nos outros, como o iPhone 15 Pro, "Keep Cue open until it’s done.".
- **Avisos:**
  - iPhone quente durante a exportação;
  - falta de espaço antes de começar;
  - "iOS stopped the export · Try again" quando o iOS a interrompe.
- **Exportação que parou com o Cue:** a take avisa "The last export stopped", com **Save video**.

## Por dentro

- `Managers/Export/Background/`: `BackgroundExportRunner` e `SystemContinuedTaskScheduler` (iOS 27 `submitTaskRequest`, `.fail`, GPU obrigatória).
- Entitlement `com.apple.developer.background-tasks.continued-processing.gpu` (perfil novo de 16/10/2026), identificador
  `com.cuestudioteleprompter.export.*` e `UIBackgroundModes` `processing`.
- A folha de exportação do editor, que nada abria, saiu, com 18 textos; os avisos dela agora estão na exportação real.
- O arquivo parcial é apagado em qualquer falha.

## Validação

- Unidade, UI (cartões com contraste medido), `check-warnings.sh` e Full: números no relatório.
- **No iPhone 15 Pro:**
  - sem GPU em segundo plano (`supportedResources` vazio);
  - uma tarefa só de CPU travava a exportação, por isso nunca é pedida;
  - sem tarefa, uma take de 6:40 seguiu exportando com o Cue fora por 60 s e terminou no mesmo tempo.
- **Não validado:**
  - o caminho com GPU e Live Activity (nenhum aparelho testado tem GPU em segundo plano);
  - o iPhone 15 comum (A16);
  - o uso à mão pelo dono (roteiro enviado).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
