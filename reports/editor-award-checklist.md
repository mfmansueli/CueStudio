# Editor "award winning": checklist de progresso

Branch `feature/editor-award` (worktree `.claude/worktrees/editor-award`), a partir de `main` 4653ecc. Aparelho de teste: **iago Lima iphone**
(iPhone 15 Pro, tela menor). Legenda: ✅ feito e testado · 🟡 em andamento · ⬜ não começado · ⛔ fora desta entrega (motivo ao lado).

## 0. Auditoria (confirmação dos achados da análise do 9f01ab0, no código de 4653ecc)

| Achado | Tipo | Confirmado? | Onde |
|---|---|---|---|
| Capa guarda só o segundo; renderiza sempre do vídeo principal | Bug | Sim (leitura + teste de regressão) | `CoverSource.frame(TimeInterval)`, `CoverRenderer.frame(of: videoURL…)`, `endCoverScrub`, `useFrameAsCover` |
| Falha da capa some em silêncio; arquivo temporário fica | Bug | Sim | `QuickEditExportModel.saveCover` (`try?`, sem estado, `.jpg` em `tmp` nunca apagado) |
| Studio Voice só trata a gravação principal | Limitação | Sim | `EditedComposition.build(processedAudio:)` troca só o som de `sourceID == nil` |
| Exportação reprocessa o som da take do zero e deixa os `.caf` em `tmp` | Desempenho / limpeza | Sim | `VideoExportService.processedAudio`, `AudioTrackExtractor.extract` |
| Clean Up só analisa a gravação principal | Limitação | Sim | `cleanUpSuggestions(forVideoAt: videoURL)`, `EditTimeline.remove` ignora `sourceID != nil` |
| Mídias sobrepostas: só a primeira da playhead recebe alças | Bug | Sim | `visibleMedia` (primeira barra que contém o tempo, não a selecionada nem a de cima) |
| "Join next" mistura gravações | Bug | Sim | `mergeCaptionWithNext` ordena por `start` de gravações diferentes |
| Ajuste de duração da legenda grava tempo de outra gravação | Bug | Sim | `nudgeCaption` usa `sourceTime(forEdited:)` do trecho que toca, não o da linha |
| Texto arrastado aparece duas vezes (cópia + original no vídeo) | Usabilidade | Sim | `OverlayEditingLayer.textHandle` |
| Studio Voice e Crop aparecem nas ferramentas do clipe sem dizer que valem para tudo | Usabilidade | Sim | `items(for: .clip)` |
| "Adicionar foto ou vídeo" só pelo clipe ("Overlay") ou pelo + do fim da trilha | Usabilidade | Sim | `mainItems` |
| B-roll em vídeo sempre começa no 0 do arquivo | Limitação | Sim | `placeMedia` (`CMTimeRange(start: .zero…)`) |

## 1. Confiabilidade
- ✅ Capa: gravação, trecho e tempo certos; comportamento quando o trecho sai (`DESIGN_PROJECT.md` §37)
- ✅ Exportação: vídeo e capa com estados separados, tentar de novo, compartilhar capa, limpeza
- ✅ Studio Voice: escopo por gravação, cache compartilhado prévia/exportação, nivelamento entre takes (medido com áudio real)
- ✅ Clean Up em montagens (origem por sugestão, cópias, velocidade, ordem)
- ✅ Mídias sobrepostas: seleção pela ordem visual, acesso às cobertas, sem duplicação no arraste
- ✅ Legendas: juntar/ajustar/arrastar/dividir na ordem de reprodução e na gravação certa
- Achado extra: o arraste da barra de uma legenda para um clipe de outra gravação gravava tempos da gravação errada (corrigido).
- Observado e não mudado: o tratamento de volume do `AudioEnhancer` (render pelo `AVAudioEngine`) deixa um mono ~3 dB abaixo do pedido; não afeta o
  nivelamento novo (que não passa por ele).
- Ambiente: `scripts/test.sh` roda os planos com testes paralelos (clones de simulador); apago os clones ao fim de cada rodada
  (`xcrun simctl --set testing delete all`). `VoiceBriefSnapshotTests` falha de forma intermitente lendo o arquivo de snapshot (outro arquivo a cada
  rodada; não é do editor).

## 2. Capa
- ⬜ Fluxo imagem → modelo → título → detalhes → salvar
- ⬜ Enquadramento (ampliar, mover, restaurar), frame preciso
- ⬜ Modelos com miniatura real (Educativo, Opinião, Lista, Demonstração, Antes/depois, Série)
- ⬜ Texto: posição, tamanho, alinhamento, cores, fundo/contorno/sombra, maiúsculas, destaque, ajuste do bloco
- ⬜ Elementos gráficos editáveis
- ⬜ Antes/depois com duas imagens
- ⬜ Efeitos e estilo salvo

## 3. Usabilidade do editor
- ⬜ Escopo explícito
- ⬜ Adicionar mídia (clipe × sobre o vídeo)
- ⬜ Animações prontas
- ⬜ Manipulação na prévia sem duplicação
- ⬜ Copiar e colar ajustes entre clipes

## 4. Funcionalidades
- ⬜ Trecho do B-roll
- ⬜ Efeitos sonoros (biblioteca própria)
- ⬜ Elementos gráficos no vídeo

## 5. Edição por transcrição e templates
- ⬜ Cortar pelo texto
- ⬜ Templates completos

## 6. Recursos adicionais
- ⬜ Congelar quadro, reverso, curvas de velocidade, batidas, reenquadramento, estabilização, rastreamento (avaliar)

## Referências do GitHub
- ⬜ VideoLab, MTTransitions, MetalPetal, Cabbage, VideoEditorKit (licença, o que serve, o que foi aproveitado)

## Validação
- ⬜ Testes de regressão de cada bug
- ⬜ Prévia × exportação (imagem, áudio, duração, sincronia)
- ⬜ Medições 1080p e 4K no iago Lima iphone
- ⬜ `check-warnings.sh`, planos Fast e Full
