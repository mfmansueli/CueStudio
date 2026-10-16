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
- ✅ Fluxo imagem → modelo → título → detalhes → salvar (Cover Studio em tela cheia, 5 etapas, desfazer próprio)
- ✅ Enquadramento (pinça, arraste, Reset, zoom por controle), frame preciso (faixa + ±1 quadro)
- ✅ Modelos com miniatura real (Educativo, Opinião, Lista, Demonstração, Antes/depois, Série); galeria conferida em 8 títulos/idiomas × claro/escuro
- ✅ Texto: posição (arraste com guias), tamanho (pinça/controle), largura (alça/controle), alinhamento, cores, sombra/contorno/caixa, maiúsculas,
  várias palavras em destaque (cor ou caixa), linha acima, ajuste do bloco inteiro sem cortar palavras (RTL, CJK, tailandês, emoji)
- ✅ Elementos gráficos editáveis (selecionar, arrastar, pinçar/girar, alça de canto, cor, duplicar, excluir, ordem, guias)
- ✅ Antes/depois com duas imagens, enquadramento próprio, divisor arrastável, rótulos editáveis e localizados
- ✅ Efeitos (força de Dim/Blur; "No person found") e estilo salvo sem conteúdo; capas antigas convertidas só ao abrir

## 3. Usabilidade do editor
- ✅ Escopo explícito: o que muda o vídeo inteiro (Format, Studio Voice, Media) saiu da barra do clipe e está na principal; subtítulo do Format
- ✅ Adicionar mídia: **Media** na barra principal, com a diferença entre sobre o vídeo (B-roll) e clipe na sequência explicada na folha
- ✅ Animações prontas (Fade, Slide up, Slide in, Gentle zoom, Pop, In and out) com duração e força, sobre os keyframes (edição manual mantida)
- ✅ Manipulação na prévia sem duplicação (o item some do vídeo durante o arraste; alças de mídias sobrepostas) — etapa 1
- ✅ Copiar e colar look entre clipes, escolhendo Adjust / Filter / Background / Zoom, num clipe ou em todos
- ✅ Telas menores e Dynamic Type: capturas de todo o editor no iPhone 17 e no iPhone SE em AX L; cortes corrigidos (blocos em 3 colunas, subtítulos
  em 2 linhas, Cover Studio com rótulos curtos)
- ✅ ✦ Smart com Templates numa aba própria (pedido do dono)

## 4. Funcionalidades
- ✅ Trecho do B-roll (início e duração próprios, nunca além do arquivo)
- ✅ Efeitos sonoros: 11 sons sintetizados pelo Cue (nenhum arquivo de terceiros, nenhum download)
- ✅ Elementos gráficos no vídeo (Arrow, Circle, Tag), desenhados como na capa

## 5. Edição por transcrição e templates
- ✅ Edit by text: "Cut from video" (corta o vídeo) × "Fix caption text" (só a legenda); Put back; transcrição no aparelho
- ✅ Templates (Bold hook, Tutorial, Story, Clean, Interview) num passo de desfazer, preservando palavras, cortes, som e gráficos

## 6. Recursos adicionais
- ✅ Transições novas (Zoom, Blur, Flash, Push, Punch, Wipe) com duração ajustável, adaptadas do GL Transitions (MIT, atribuído)
- ✅ Congelar quadro (clipe de quadro parado, com o look do clipe; exportação real testada)
- ⛔ Reverso: exige reescrever o trecho de trás para frente (AVAssetReader em blocos + arquivo novo, áudio invertido ou mudo); feito às pressas
  seria lento e pesado em 4K. Pendente.
- ⛔ Curvas de velocidade: a composição só estica trechos com velocidade constante (`scaleTimeRange`); uma curva exige dividir em muitos pedaços
  (degraus visíveis, áudio picotado) ou um compositor com tempo próprio. Pendente.
- ⛔ Cortes nas batidas: precisa de detecção de batida na música (onset/tempo) e do ímã na timeline; a música do Cue ainda não tem marcas. Pendente.
- ⛔ Reenquadramento por rosto: o Crop é um enquadramento fixo do vídeo inteiro; seguir o rosto exige trilha de enquadramento por tempo
  (Vision por quadro + suavização) que a prévia e a exportação ainda não têm. Pendente.
- ⛔ Estabilização e rastreamento: dependem de análise de movimento por quadro (Vision `VNTranslationalImageRegistrationRequest` /
  `VNTrackObjectRequest`) e de keyframes gerados; não cabem com qualidade nesta entrega. Pendente.

## 7. Auditoria de UX/confiabilidade e paridade com editores de celular (16/10)
- ✅ Auditoria (agente): 6 P1, 8 P2, 10 P3 verificados no código; corrigidos os P1 e P2 e os P3 de main thread, 44 pt, VoiceOver, large content
  viewer e tamanho do efeito. Fica: plural de "Cut N words" (o catálogo do projeto não usa plurais)
- ✅ Pesquisa CapCut / Edits / InShot / VN (agente) e comparação com o Cue, verificada no código
- ✅ Reordenar clipes (segurar ou Reorder), arrastar itens no tempo, barras na ordem de uso, Format na principal, Edit by text no ✦ Smart e nas
  Legendas, Animation no texto, Duplicate na mídia
- ✅ Robustez: espaço antes de exportar, limpeza ao abrir, MetricKit, congelar quadro fora da thread da interface
- 🟡 Testes da etapa (agente) · Full · check-warnings · capturas · aparelho
- ⬜ Próxima branch: exportação que continua fora do app, aviso de aparelho quente, medição no iPhone 15 (A16); depois análise de movimento, Seguir
  rosto, rastreamento, estabilização, tempo variável, cortes nas batidas (só faixas dos Files)
- ⬜ Pendências da pesquisa (não feitas nesta entrega): localizar e trocar / seleção múltipla nas legendas, Replace clip, Extract audio

## Referências do GitHub
- ✅ VideoLab, MTTransitions, MetalPetal, Cabbage, VideoEditorKit estudados (`reports/editor-references.md`): nenhum adotado como dependência;
  GL Transitions (MIT) usado como referência de movimento, reescrito em Core Image; licença e atribuições em `THIRD_PARTY_NOTICES.md` e no app

## Validação
- ⬜ Testes de regressão de cada bug
- ⬜ Prévia × exportação (imagem, áudio, duração, sincronia)
- ⬜ Medições 1080p e 4K no iago Lima iphone
- ⬜ `check-warnings.sh`, planos Fast e Full
