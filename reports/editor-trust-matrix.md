# Editor: matriz de acompanhamento

Branch `feature/editor-trust` (a partir de `perf/fluidity-audit`, df0212b6). Fontes: `editor-relatorio-completo-2026-11-06.md` (o relatório) e `editor-plano-implementacao-2026-11-06.md` (o plano do dono). Cada proposta do relatório tem um destino; duplicatas ficam juntas, com as referências originais.

**Destinos:**
- **Resolvido:** o código atual já atende.
- **E1 a E5:** implementar na etapa do plano (§17).
- **Validar:** só entra ativo depois de medir ou ouvir.
- **Adiado:** fica para depois, com motivo.
- **Rejeitado:** não será feito, com motivo.

**Etapas:**
- **E1:** rascunhos, exportação, mídia, fontes e fidelidade.
- **E2:** relações no tempo, gestos, bloqueio e desfazer.
- **E3:** acesso às ferramentas, limpeza revisável e desempenho.
- **E4:** vocabulário, zoom, legendas assistidas e reutilização.
- **E5:** recorte posicionável e edição automática.

Marcos com ⏸ param para a avaliação do dono no iPhone antes de seguir no que depende deles (resposta de 06/11).

**Evidência:**
- **C:** lido no código.
- **A:** reproduzido no app (simulador ou aparelho).
- **M:** medido.
- **P:** validado com pessoas.

O estado de cada linha avança conforme a evidência.

## 1. Melhorias priorizadas (relatório §10)

| # | Proposta | Destino | Evidência hoje | Notas |
|---|---|---|---|---|
| 10.1 | Nunca perder um rascunho (‹ no carregamento, rascunho ilegível, Autosaved sem confirmação) | E1 | C | Inclui: ausente, ilegível e parcialmente recuperado; cópia antes de substituir; selo ligado à versão gravada; falha com recuperação, sem culpar sempre o espaço |
| 10.2 | Exportação que não para nem parece travada | E1 | C | Bloqueio automático só no modo "Keep Cue open", restaurado em todos os finais; etapas reais; cancelar a mixagem; limpar intermediários sem apagar o que outra operação usa |
| 10.3 | Prévia e arquivo iguais (limitador, fontes, mídia faltando) | E1 | C | Áudio comparado no arquivo renderizado, não por gravação de tela; identidade do resultado inclui fontes e mídia |
| 10.4 | Camadas sobre conteúdo apagado + 3 erros pontuais | E2 | C | Regras do plano §6; ver a seção 4 desta matriz |
| 10.5 | Remover pausas revisável e natural | E3 ⏸ | C | Undo no aviso, Put back por item, respiro separado do limite, mensagens distintas; padrão de 0,7 s só muda depois de ouvir |
| 10.6 | Gestos previsíveis e avisos que dizem onde | E2 | C | Reverter nomeia o clipe, Undo nomeia a ação, Delete all distinto, Bloquear na prévia, toque leve não move |
| 10.7 | Pro dito com verdade | E1 | C | 4K só Pro (decisão 06/11); quem não é Pro exporta 1080p com explicação; "última exportação grátis" no momento útil; cota antes do render; sem paywall nas ferramentas |
| 10.8 | Um jeito de repetir o próprio estilo | E4 ⏸ | C | Sem quarto sistema; distinguir estilo, template, kit, copiar ajustes e preferências de limpeza, zoom e áudio |
| 10.9 | Portas repetidas e nomes que colidem | E3 ⏸ | C | Só ajustes pontuais (plano §8); atalhos para o mesmo destino podem ficar |
| 10.10 | Recorte automático estável e com falhas visíveis | E5 (começo) | C | Estabilidade no tempo antes de qualquer régua de borda |

## 2. Funções recomendadas (relatório §12)

| # | Proposta | Destino | Notas |
|---|---|---|---|
| 12.1 | Zoom nos cortes | E4 ⏸ | Opcional, intensidade ajustável, um Undo; nada em trechos muito curtos; preserva zooms manuais. Inclui `red-punch` (uma recomendação de "punch", sem tirar a transição) |
| 12.2 | Tela única para enxugar a fala (`tighten-screen`) | E3 ⏸ | Integra pausas, hesitações e repetições com Editar pelo texto; reaproveita componentes; sem régua única de "intensidade" |
| 12.3 | Repetições pelo roteiro (`retake-picker`) | E3 ⏸ | Sugestões incertas não viram corte; ouvir e escolher a tentativa; não presume a última; vídeos sem roteiro mantêm o fluxo atual; idiomas só anunciados com testes |
| 12.4 | Legendas posicionadas com assistência (`captions-place-themselves`, `caption-per-line-position`) | E4 ⏸ | Ajuste por trecho respeitando posições manuais; estável, sem pular |
| 12.5 | Volume final das redes (`loudness`) | Validar (E4) | Medição apropriada, true peak no arquivo codificado; sem chamar −14 LUFS de padrão oficial; sem medidores obrigatórios (`loudness-readout` rejeitado) |
| 12.6 | Zoom no rosto e zoom numa frase (`face-zoom-sentence`, `face-punch`) | E4 ⏸ | Só com detecção confiável; não troca de pessoa; reaproveita Follow face |
| 12.7 | Começar na primeira palavra (`first-word`) | E3 | Com prévia e Undo, protegendo o começo da fala |
| 12.8 | Ênfase automática (`auto-emphasis`) | E4 ⏸ | Opcional, poucas palavras, corrigível; não só números e nomes |
| 12.9 | Guia das áreas seguras por botão (`safe-zones`) | E4 | Aproximação, não garantia; sem faixa permanente |
| 12.10 | Pessoa recortada posicionável sobre foto ou vídeo (`cutout-layer`, `video-background`) | E5 ⏸ | A simulação confirmou o GAP (R4.3): a pessoa não move nem escala e o fundo não aceita vídeo |

## 3. Demais propostas do painel (relatório §11, rodadas 1 e 2)

| Proposta | Destino | Motivo |
|---|---|---|
| `auto-edit-pass`, `auto-edit-review` | E5 ⏸ | Depois das bases; entrada no Smart, sem cartão obrigatório; etapas revisáveis e desligáveis sem apagar o resto |
| `pause-defaults` | E3 (controle do respiro) + Validar (novo padrão) | O plano proíbe impor 0,4 s sem ouvir |
| `fillers-all` | Validar | "Remover as marcadas" já existe; idiomas além de en/pt/es só com testes |
| `breaths`, `de-esser` | Validar (E4) | Só com benefício audível, sem piorar a voz |
| `split-on-word` | E3 | Assistência discreta; nunca muda corte manual nem impede precisão por quadro |
| `caption-vocabulary` | E4 | Sobre `ScriptSpelling` e Localizar e substituir; não muda o tempo; evita palavras comuns |
| `auto-reframe` | E4 | Conferir Follow face em vídeo horizontal importado; corrigir o existente antes de criar outro sistema |
| `saved-recipe` | E4 (dentro de 10.8) | Preferências de limpeza, zoom e áudio; nunca texto, mídia, capa ou tempos |
| `red-looks` | E4 (dentro de 10.8) | — |
| `preview-equals-export`, `preflight-feed` (parte objetiva) | E1 | Avisos acionáveis para mídia ausente, processamento pendente, fontes, problemas verificáveis; sem prometer equivalência completa |
| `preflight-feed` (simulação de feed) | Adiado | Plano §15: só com benefício demonstrado |
| `visible-recovery` | E1 | "Draft restored" já existe (Resolvido em parte); nomear o estado real ao reabrir |
| `undo-says-what` | E2 | — |
| `one-behaviour`, `red-captions-menu` | E3 | Legendas e Desfoque com o mesmo comportamento por entrada, respeitando o contexto |
| `rename-collisions`, `icon-collisions`, `red-edit-clip` | E3 ⏸ | Só ambiguidades reais: proporção × recorte, dividir × tela dividida, "Remove pauses" × "Pauses", os sentidos de "Edit", ícones iguais. Animação fica |
| `bar-reorder` | E3 ⏸ | Limpeza da fala perto do início; ordem estável e memória de rolagem |
| `scope-split` | E3 ⏸ | Alcance evidente em mudanças do vídeo todo e por clipe (plano §7) |
| `labels-everywhere` | Resolvido em parte; conferir em E3 | As barras já têm nome; conferir com Dynamic Type e alturas |
| `fast-text-pop` | Validar (E3) | Mudar o padrão pede avaliação; o texto invisível em t=0 durante a edição (achado da R1.5) é corrigido em E3 |
| `red-volume` | Rejeitado como proposto | Vários atalhos para o mesmo painel, adequados ao objeto (plano §8); conferir só se o Mudo da barra e o do painel concordam |
| `red-edit-by-text` | Rejeitado como remoção | Fica acessível; a integração acontece em 12.2 |
| `red-track-mirror`, `red-auto-adjust`, `red-add-sequence` | Rejeitado | Atalhos para o mesmo destino; o toque longo não é a única porta |
| `red-animation-transition` | Rejeitado | Plano §8: não eliminar Animação |
| `red-brand`, `item-bars-own-only` | Adiado | O plano adia a retirada dos atalhos das barras de objeto |
| `red-smart-tiles`, `smart-as-auto`, `smart-only-auto` | Adiado | O Smart não é esvaziado antes de existir um fluxo melhor (E5) |
| `bar-8-entries`, `simple-mode` | Adiado | Até uma proposta visual comparável em tarefas reais |
| `rare-behind-more` | Rejeitado | Toque longo como única porta é proibido; não remover por votos |
| `cover-to-export` | Rejeitado | A Capa continua onde está (plano §15) |
| `recent-tools` | Rejeitado | Conflita com ordem estável e vizinhança (plano §8) |
| `tool-hints` | Rejeitado | Mais avisos na primeira abertura; o dono não quer novos pop-ups |
| `loudness-readout` | Rejeitado | Medidores técnicos obrigatórios (plano §13) |
| `caption-emoji` | Rejeitado como padrão; Adiado como opção | Plano §12: não impor emojis |
| `cutout-overlay` | Adiado | Caso raro; depois de 12.10 |
| `multi-format`, `chat-edit`, `desk-roundtrip`, `luts`, `stickers`, `auto-sfx`, `progress-bar`, `loop-helper`, `end-card`, `cadence-strip`, `progress-strip` | Adiado | Lista do plano §15 (nada existente é removido) |
| `edit-history` | Adiado | Cópias recuperáveis de rascunhos entram em E1 |
| `highlight-box`, `lower-third-steps`, `bundles` | Adiado (backlog) | Até mostrar necessidade que os recursos atuais não atendem |
| `jl-cuts`, `beat-snap` | Adiado | Sem necessidade demonstrada em vídeo de uma take |

## 4. Relações no tempo (relatório §8) — todas em E2

| Caso | Hoje | Regra a aplicar |
|---|---|---|
| Texto em trecho apagado (simples) | escondido sem aviso | Some só se todo o trecho dele foi apagado; parcial mantém o que ficou |
| Texto em edição montada com o clipe inicial apagado | some inteiro | Mantém a parte sobre conteúdo mantido |
| Mídia que segue os cortes, clipe inicial apagado | some inteira | Igual ao texto |
| Narração em clipe apagado de outra gravação | pula para o mesmo segundo da take (`VoiceOverClip.swift:52`) | Nunca cai em outra gravação; fica no lugar da edição ou oferece recuperação contextual |
| Narração sob remoção de fala | o conteúdo encolhe sob ela | Não é comprimida nem recortada como o áudio original |
| Efeitos sonoros em clipe apagado | vão para o próximo e se acumulam | Saem junto com o conteúdo apagado; o aviso conta e oferece Undo |
| Texto sobre congelamento ou inserção (`EditTimeline.swift:708`) | cobre o inserido e termina cedo | A duração segue a fala, sem esticar indevidamente |
| Reverter ou duplicar depois de dividir (`ClipsViewModel+Reverse.swift:109-120`) | perde textos | Itens do lado certo da divisão acompanham |
| Substituir ou reverter | legendas somem no revertido (de propósito) | Mantém: legenda da fala original não acompanha conteúdo incompatível |
| Música sob introdução inserida | fica (decisão §37) | Fica por padrão (decisão 06/11); sem seguir clipes calada; o aviso oferece mover junto, sem seleção múltipla genérica |
| Música empurrada para depois do fim | invisível | Visível e recuperável |
| Keyframes depois de mudar velocidade (Risco) | a saída pode ser cortada | Conferir com teste; não esticar animações |
| Mídia sobre um vão (Risco, `EditedComposition.swift:564`) | o movimento desloca | Conferir com teste |
| Transição ao mover o clipe para primeiro (Risco, `EditTimeline.swift:45`) | perdida | Conferir com teste |
| Edição simples × montada (`EditTimeline.swift:721`, Risco) | textos encolhem num caso e deslizam no outro | Uma regra |
| Aviso de remoção | "Clip 2 deleted" | Diz o que foi junto e oferece Undo, sem confirmar cada corte |
| Undo e Redo | — | Recupera mídia, propriedades e sincronia (teste em cada caso) |

### 4.1 Estado da E2 nas relações no tempo (06/11, noite; branch `e2-timing`)

Regras em `CutFollowing` (toda mudança dos cortes, em `EditDocument.commit`) e `TakeEdit.removingClip` (apagar um clipe); descrição em
`DESIGN_PROJECT.md` §37 › Relações no tempo. Evidência C + testes de unidade (nada no aparelho).

| Caso | Estado | Teste |
|---|---|---|
| Vídeo preso a segundos aparados (prévia × arquivo) | Corrigido: o arquivo começa do segundo a que tinha chegado (`MediaOverlay.pieces`) | `PreviewMatchesExportTests` (sem `withKnownIssue`), `MediaPiecesTests` |
| Texto em trecho apagado (simples) | Já mantinha a parte; o que estava só no clipe fica escondido e o aviso conta | `aTextOfOneTakeKeepsWhatIsLeft…` |
| Texto em montagem, clipe inicial apagado | Corrigido: fica a parte sobre o próximo; o que estava só nele sai | `aMontageTextWhoseFirstClipIsDeleted…` |
| Mídia que segue os cortes, clipe inicial apagado | Corrigido, no passo do arquivo | `mediaThatFollowsTheCutsKeepsThePart…` |
| Narração em clipe apagado de outra gravação | Corrigido: começa no corte; o recurso de `VoiceOverClip.swift:52` fica na mesma gravação | `aVoiceOverOnADeletedClipOfAnotherVideo…` |
| Narração sob remoção de fala | Já era assim (toca inteira); teste | `aVoiceOverPlaysWhole…` |
| Efeitos sonoros em clipe apagado | Corrigido: vão junto e o aviso conta | `soundEffectsOnADeletedClipGoWithIt…` |
| Texto sobre congelamento ou inserção | Corrigido: termina com a fala (cobre o inserido) | `aTextOverAFreezeFrameEndsWithItsSpeech` |
| Reverter ou duplicar depois de dividir | Corrigido (`TakeEdit.layersStarting`) | `aSplitsRightPartHoldsWhatIsOnIt`, `duplicatingASplitsRightPart…` |
| Substituir ou reverter (legendas) | Mantido de propósito; teste | `captionsOfTheSpeechStayOffAReversedClip` |
| Música sob introdução inserida | Fica; o toast oferece **Move music along** | `musicStaysUnderAnInsertedIntro…`, `movingTheMusicAlongIsOneStep` |
| Música empurrada para depois do fim | Corrigido: fica à vista no fim (0,5 s) | `musicPastTheNewEndStaysInView` |
| Keyframes depois de mudar velocidade | Já certo (saída no novo fim, keyframes não esticam); teste | `aFasterClipKeepsATextsExitAndKeyframes` |
| Mídia sobre um vão | Corrigido: keyframes ficam nos quadros | `keyframesOfMediaStayOnTheirFramesAcrossAGap` |
| Transição ao mover o clipe para primeiro | Por desenho (o primeiro não tem transição; Undo traz); teste | `aClipMovedFirstPlaysFromAHardCut…` |
| Edição simples × montada | Corrigido: uma regra (pausa sob o texto encurta nas duas) | `aPauseTakenOutUnderATextShortensItInBothKinds` |
| Aviso de remoção | "Clip 2 deleted, with 1 text and 2 sounds" · Undo (20 idiomas) | `deletingAClipSaysWhatWentWithIt…` |
| Undo e Redo | Testado por caso e na exclusão | `undoAndRedoOfADeletedClip…`, `aGestureOutAndBack…` |

Limite: numa montagem, aparar com a alça sob um texto o deixa no que sobrou; arrastar de volta num gesto seguinte não o faz crescer (o Undo faz).

## 5. Confiança, previsibilidade e automação (relatório §7 e §9, itens fora de §10)

| Item | Destino |
|---|---|
| Sair ou tocar Done cancela legendas, tradução, Studio Voice, tracking e análise calados; resultado atrasado altera uma edição fechada | E1 |
| Central de Controle durante a narração | E1 (preservar o trecho gravado e mostrar o estado real) |
| Ligação durante a exportação; expiração em segundo plano | E1 |
| Stabilize e Follow face em análise mostrados como prontos | E1 (mostrar o processamento pendente) |
| Testes de prévia × exportação sem Fundo, Pele, Máscara, tela dividida, curvas e áudio | E1 |
| Exportação bloqueada pela cota mostrando progresso antes | E1 |
| Mesma take × mesma edição na identidade da exportação | E1 |
| `takes.json` codificado na tela principal no Done | E3 (desempenho) |
| Mudanças esperando o Studio Voice de uma take longa | E3 (desempenho) |
| Done apaga o histórico de desfazer | E2 (conferir e documentar; o histórico do rascunho continua) |
| Um arrasto de legenda move todas | E2 (alcance claro antes da mudança) |
| Mover uma legenda na timeline sem "Check timing" | E2 |
| Alongar uma legenda limitado pela vizinha | E4 |
| Sala barulhenta com mensagem enganosa | E3 |
| Template depois de um kit troca o visual calado; música sempre em 0,5; sem salvar template próprio | E4 (dentro de 10.8; salvar template = Validar) |
| Máscara treme no tempo | E5 |

## 6. Achados da simulação das receitas (simulador, 06/11)

| Achado | Destino |
|---|---|
| R4.3: pessoa recortada não move nem escala; fundo sem vídeo | E5 (12.10) |
| R1.3 e R2.1: punch-in alternado custa 9 a 10 toques | E4 (12.1) |
| R1.4 e R2.2: sem rampa de zoom em parte do clipe; o push dura o clipe inteiro | E4 (12.6, zoom em frase) |
| R1.5: com Pop, o gancho fica invisível em t=0 enquanto se edita | E3 |
| R1.5 e R2.4: Ends anda 0,1 s por toque (1 s = 10 toques); Freeze fixo em 2 s | E3 (controle de duração mais direto; Freeze: Validar) |
| R1.6: cores da legenda só aparecem depois de rolar | E4 (conferir com contraste e layout) |
| R1.7: whoosh posto à mão em cada corte | Adiado (`auto-sfx`) |
| R1.8: música em %, ducking em dB | Validar (E4, áudio): uma linguagem só, sem medidores obrigatórios |
| R1.11: sem escolha de quadros por segundo | Rejeitado (mantém o gravado, que é o recomendado) |
| Duração da transição escondida sob "Use on every cut" no iPhone 17 | E3 (erro de layout) |
| Paste look abre uma folha a cada clipe | E4 (10.8) |
| Toque perto do polegar do slider pega o polegar | E3 (gestos) |
| R2.5: sem loop | Adiado (`loop-helper`) |
| R4.4: sem retângulo de destaque | Adiado (`highlight-box`) |
| R4.5: saída da tela dividida para tela cheia é corte seco | Adiado |

## 7. Desempenho e validação (relatório §15 e §16)

| Item | Destino |
|---|---|
| Painel de texto: cada preset cria um texto de verdade | E3 (provar sem criar trabalho definitivo a cada toque; medir antes e depois) |
| Linhas de legenda (88 → 203 ms) e tela cheia (43 → 77 ms) pioraram | E3 (repetições em condições iguais antes de chamar de ruído) |
| Buscar inspiração e gravador e Ajustes sem comparação | Adiado (fora do editor) |
| Método: aparelho, sistema, build, mídia, duração, resolução; primeira vez × com cache; limite por taxa de atualização, não só 16 ms | Todas as etapas |
| Receitas R1, R4, R2 nas takes reais (cópias em memória) | Antes de E1 (linha de base) e no fim de cada etapa que mexe no que elas tocam |
| Receita de vídeo calmo (R3) e montagem com várias fontes | E1 (escrever) e depois em todas as etapas |
| As 9 tarefas completas do plano §16 | Na etapa de cada uma (1, 8, 9 em E1; 4, 5 em E2; 2, 3 em E3; 6, 7 em E4 e E5) |
| Telas diferentes, Dynamic Type, idiomas, RTL | Todas as etapas com interface |
| Teste com pessoas | Pendente do dono em cada ⏸; nada é declarado validado sem isso |

## 8. Correções do relatório (plano §2)

| Item | Destino |
|---|---|
| Percentuais da App Store sem denominador, período e critério verificáveis | E1 (documental): reescrever como qualitativo ou publicar amostra e critério |
| "5/5" dos juízes tratado como demanda | E1 (documental): marcar como hipótese em todo lugar |
| "Achar ferramenta é a queixa menos comum" usado para rebaixar a organização | E1 (documental) |
| B-Script e estudos específicos tratados como prova do fluxo inteiro | E1 (documental) |
| Heurísticas de ritmo, zoom e legenda como regras | E1 (documental) |
| "Nenhum app faz" como exclusividade | E1 (documental): "não encontrado" |

## 9. Revisão interna de todas as ferramentas (acréscimo do dono, plano §18) — E3 ⏸

Cada ferramenta do editor (painéis, folhas, menus e as decisões depois de abrir) percorrida no fluxo inteiro: achar → abrir → entender → ajustar → conferir na prévia → concluir ou cancelar → seguir editando.

| Critério | Destino |
|---|---|
| Agrupamento, ordem e hierarquia das opções (as frequentes primeiro) | E3: correções pontuais |
| Ajustes repetidos, nomes ambíguos, controles que fazem o mesmo | E3: correções pontuais |
| Navegação, menus dentro de menus, folhas empilhadas | E3: correções pontuais; mudanças de estrutura com antes e depois ⏸ |
| Alcance claro (vídeo, clipe ou objeto) | E3 |
| ✓, Voltar, Fechar, Cancelar e Restaurar: quando entra, quando fica, como desfazer | E3 |
| Prévia visível durante o ajuste, espaço, teclado, rolagem, tamanhos de texto | E3 |
| Ajustes preservados ao alternar opções ou reabrir | E3 |
| Consistência entre ferramentas parecidas, sem forma única para tudo | E3 (painel, folha ou tela maior conforme a tarefa) |

Saída: uma ficha por ferramenta (o que foi visto, o que mudou, antes e depois) e um roteiro de tarefas para o iPhone. Nenhum ajuste útil é removido só para encolher a interface.

## 10. Estado da E1 (06/11, noite)

| Item | Estado | Evidência |
|---|---|---|
| 10.1 Rascunho | Feito | Testes de unidade (store, keeper, view model); reabrir mantém o desfazer; selo segue o disco |
| Trabalho pendente no Done/Back | Feito | `EditorPendingWork`; teste de legendas |
| Narração e Central de Controle | Feito no código | Teste de unidade; falta conferir no iPhone que o AVAudioRecorder segue gravando com a cena inativa |
| Mídia faltando persistente | Feito | `MissingMediaNotice`; teste com Desfazer |
| Stabilize/Follow face pendente | Feito | `MotionPendingPill`; teste |
| 10.2 Exportação (agente) | Feito no código | Testes; falta iPhone: bloqueio automático no 15 Pro, ligação no meio |
| 10.7 Pro (agente) | Feito no código | Testes de unidade e UI; falta compra real no iPhone; perguntas ao dono no relatório |
| 10.3 Fontes e identidade do arquivo (agente) | Feito | `ExportRenderStamp`, `ExportedFileRecord` |
| §15 Checagem antes de exportar | Feito | No Done: fonte importada ausente ou fonte de escrita ainda baixando (`fontsNotReady`, linha laranja com o que resolve); mídia ausente (aviso na prévia + Remove); processamento pendente (o Done espera); Desfocar área não conferida (pede um quadro). `QuickEditFontCheckTests` |
| 10.3 Prévia × arquivo, imagem | 27 ferramentas iguais | `PreviewMatchesExportTests`; nova diferença achada: vídeo preso a segundos aparados (vai para E2, primeiro item) |
| 10.3 Prévia × arquivo, som | Medido, decisão do dono | Igual sob o teto; 2,5 dB e estouro na prévia acima dele. Proposta: aviso de nível alto no Volume, calculado de uma mistura em segundo plano; ou prévia por AVAudioEngine (grande) |
| Testes que falham fora do editor | Relatar | `IdeaSuggestionServiceTests`, `IdeaRouletteTests` (vêm de 789a445a, já no origin/main), `NearbyLinkTests` (rede local no simulador) |

## 11. Decisões de 06/11 (noite)

O dono testou a E1 no 15 Pro (roteiro de 9 tarefas) sem apontar problema e delegou: "faça suas recomendações no que você acha que tem que fazer e segue para a próxima tarefa".

| Ponto | Decisão |
|---|---|
| Qualidade da exportação (achado do dono) | Só uma gravação em 4K escolhe; 1080p/720p mostram a própria resolução, sem "4K · Pro". Pro começa em 4K numa gravação em 4K (`choosesQuality`, `-uiTestFourKTakes`) |
| Textos do Pro | Ficam |
| 4K na fila depois do Pro acabar | Sai em 1080p (já é assim) |
| Quem deixou de ser Pro | 1080p |
| Vídeo importado | A mesma regra, pela resolução gravada |
| Som da prévia acima do teto | Opção (a): aviso discreto no Volume; entra na E2, com roteiro para ouvir |
| Etapa 3 | Decisões explícitas do dono em `reports/editor-e3-decisoes-2026-11-07.md` (substituem "vale a recomendada"; nada estrutural fora delas está aprovado) |
| Full | Só no fim das 5 etapas (dono); por etapa, o que mudou e o que depende disso |
