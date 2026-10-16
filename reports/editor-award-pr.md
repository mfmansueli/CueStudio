# Quick edit: editor de celular de alto nível, capa nova e montagens confiáveis

Branch `feature/editor-award` → `main`. Detalhes: `reports/editor-award-report.md` (relatório), `reports/editor-award-checklist.md` (progresso),
`DESIGN_PROJECT.md` §37 (estado atual do editor), `reports/editor-references.md` (referências e licenças).

## O que muda para o criador

- **Montagens confiáveis:**
  - capa da gravação certa;
  - Studio Voice e Clean Up em cada gravação;
  - mídias sobrepostas alcançáveis;
  - legendas que não misturam gravações;
  - exportação da capa separada do vídeo.
- **Cover Studio:** capa em 5 etapas e 6 modelos, com:
  - texto que sempre cabe (RTL, CJK, tailandês, emoji);
  - gráficos editáveis;
  - antes/depois com duas imagens;
  - estilo salvo.
- **Editor no jeito do celular** (comparado com CapCut, Edits e InShot):
  - **Barras:** a principal na ordem de uso, com **Format**; a do clipe só com o que é do clipe, as mais usadas primeiro.
  - **Reordenar:** segurar um clipe na timeline, ou o botão **Reorder**.
  - **Mover no tempo:** arrastar o bloco de um texto, B-roll, legenda ou som, com ímã nos cortes.
  - **Edit by text à vista:** primeiro bloco do ✦ Smart e botão no painel de Legendas.
  - **Templates:** aba própria no ✦ Smart.
- **Novidades:**
  - animações prontas sobre os keyframes;
  - copiar/colar look;
  - trecho do B-roll;
  - 11 efeitos sonoros feitos pelo Cue;
  - gráficos no vídeo;
  - Edit by text: cortar o vídeo pelas palavras, com início e fim marcados e Pick again;
  - 5 templates, com legendas escolhidas pelo dono (todas sobre placa ou cartão, medidas no contraste);
  - 6 transições com duração ajustável, adaptadas do GL Transitions (MIT, atribuído);
  - congelar quadro.
- **Robustez:**
  - limpeza dos sons temporários;
  - MetricKit no Crashlytics;
  - bibliotecas de takes, roteiros e marcas protegidas contra um item corrompido, sem nunca gravar por cima de uma biblioteca ilegível.

## Validação

- Testes de unidade, exportação real, prévia × exportação de uma montagem com todos os recursos, UI, roteiros de criador (iPhone 17 e SE com texto
  grande), contraste e `check-warnings.sh`. Os números estão no relatório.
- No iPhone 15 Pro:
  - exportação 1080p 0,75× a duração e 4K 1,03×;
  - transições de 2 a 13 ms por quadro em 4K;
  - latência da prévia igual à da `main`.
- No iPhone, com fala real: Edit by text cortou a frase certa nas fixtures pt-BR/en e em cópias de 3 takes do dono; o dia de criador
  inteiro numa take real (pausas, legendas, corte pelo texto, Bold hook, capa, Download video) passou.
- Full: 3.763 testes. As 2 falhas da rodada eram dos testes e foram corrigidas: as comparações prévia × exportação agora gravam a
  legenda, e os textos de `VoiceBriefSnapshotTests` (desatualizados na `main`) foram regravados e são lidos do pacote de testes.
- **Não validado:** uso com o dedo pelo dono, congelar quadro em gravação HDR real e iPhone 15 comum (A16; o dono não tem um).

## Fora desta entrega

- Reverso, curvas de velocidade, cortes nas batidas, Seguir rosto, estabilização e rastreamento.
- Localizar e trocar nas legendas, Replace clip e Extract audio.
- **Avisos de falta de espaço e de iPhone quente, e a capa exportada à parte:** foram feitos na `QuickEditExportSheet`, mas nada no app abre
  essa folha (a exportação real é a da revisão da take, depois de Done › Download video). Não chegam ao criador nesta entrega; a branch
  `feature/export-reliability` os leva para o caminho real e apaga a folha.
- Exportação que continua fora do app: plano em `reports/next-export-reliability-plan.md`. Depende da capability Background GPU, já ativada no portal.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
