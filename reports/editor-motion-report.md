# Editor: movimento — relatório

Branch `feature/editor-motion` (a partir de `afce6f9`, que tem `feature/editor-award` e `feature/export-reliability`). Aparelho: iago Lima iphone
(iPhone 15 Pro, iOS 27). Estado de cada tela: `DESIGN_PROJECT.md` §39 (e as barras em §37). Descrição do PR: `reports/editor-motion-pr.md`.

**Mudança de prioridade no meio da tarefa (pedido do dono, pela sessão principal):** programar as seis funções, com só os protótipos de aparelho
que decidem o desenho e os testes de unidade de cada pedaço. **Ficou para a fase de testes** (não rodei): `scripts/check-warnings.sh`, o plano
Full, as rodadas de UI (rodei só `EditorMotionUITests`, 2/2), a instalação no iPhone e `xcrun simctl --set testing delete all` (outro agente
usava o Simulador ao mesmo tempo; apagar os clones derrubaria os testes dele).

Tudo no iPhone: Vision, AVFoundation, Core Image e Accelerate. Nenhuma dependência nova, nenhum serviço pago, nada na nuvem.

## 1. Análise de movimento em segundo plano

**Protótipo medido no aparelho** (`MotionAnalysisDeviceTests`, cópias das 2 takes mais novas, 1920×1080 a 29 fps, em `.utility`):

| Take | Duração | Análise | Por quadro | Memória | Calor | Rostos | Arquivo |
|---|---|---|---|---|---|---|---|
| 35338DDF | 33,8 s | 8,4 s (0,25× a duração) | 8,3 ms | +55 MB | nominal → nominal | 332/338 momentos | 61 KB |
| 9294CE60 | 31,2 s | 8,7 s (0,28×) | 9,3 ms | +30 MB | nominal → nominal | 313/313 | 39 KB |

Primeira versão (homografia no quadro inteiro): 0,19× e 6,3 ms por quadro. A medição mostrou que o giro e o deslize medidos no quadro inteiro vinham
da pessoa se mexendo, não da câmera, e o desenho mudou: o movimento da câmera passou a ser medido numa grade de 4 × 6 blocos do fundo, sem os
blocos que as pessoas cobrem nem os lisos, combinados por mínimos quadrados robustos (`BackgroundTiles`, `CameraMotion`). Num quadro parado de
take real sacudido com movimento conhecido, o caminho medido erra 0,54% (x) e 0,29% (y) do quadro e 0,003 rad, para uma oscilação de 1,5%.

**O que entrou:** `MotionAnalyzer` (Vision: rostos e corpos 10×/s, registro por blocos a cada quadro até 30/s, numa cópia de 512 pontos),
`MotionAnalysisService` (uma gravação por vez, para no segundo plano e com o iPhone quente, retoma de onde parou, guarda a cada 5 s de vídeo ou
a cada vigésimo da duração num vídeo longo), `MotionAnalysisStore` (`<gravação>.cuemotion` ao lado da gravação, fora do backup, versionado; sai
com a take e com a mídia da edição; nada é salvo de uma gravação já apagada; as últimas 6 análises lidas ficam na memória com a data do arquivo e
os caminhos do Stabilize, então os painéis e cada build da prévia não decodificam o JSON de novo). O editor pede a análise de todas as gravações
que toca ao abrir, e de cada gravação nova (Reverse, Replace, clipe novo) enquanto Seguir rosto ou Estabilizar estão ligados; a prévia é
redesenhada quando uma fica pronta; a exportação faz a que faltar fora da thread principal e, se o iPhone esquenta (sério ou crítico), para
(o feito fica salvo) e diz "Your iPhone is too warm to finish this video. Let it cool down, then export again."

**Testes:** `MotionAnalyzerTests` (deslize e giro em vídeos de movimento conhecido, blocos, ajuste robusto, parar e retomar sem medir quadro duas
vezes, arquivo e versão), `MotionAnalysisServiceTests` (fila, segundo plano, calor).

## 2. Seguir rosto no Format/Crop

**Medido no aparelho** (`EditorMotionDeviceTests`, take de 33,8 s): exportação 1:1 em 3,8 s sem e 3,7 s com Seguir rosto; 16:9, 3,3 s nos dois
(o custo é nulo). O recorte se move em 378 de 1014 quadros (1:1) e 528 (16:9), no máximo 6,7 e 7,4 px por quadro (sem tranco).

**O que entrou:** `FaceFollowPath` (operador de câmera: zona calma, velocidade máxima, suavização nos dois sentidos, olhos acima do meio, nunca
fora da gravação, fica no rosto que seguia), `FollowPace` (Calm, Natural, Quick), toggle e ritmo no painel Format, recorte por quadro no
compositor (`SourceFrame.cropRect(at:)`), capa do quadro com o recorte daquele momento, arrastar o vídeo desliga.

**Testes:** `FaceFollowPathTests` (7), `MotionExportTests.theSquareCropFollowsTheFace` (exportação real: o "rosto" fica no meio).

## 3. Rastreamento (Track)

**Medido no aparelho:** o rosto da take seguido por 6 s em 1,1 s (6,0 ms por quadro), os 6 s inteiros, a 21 px (p50) e 33 px (p90) do rosto que a
análise acha, num quadro de 1080 px.

**O que entrou:** `ObjectTracker` (`VNTrackObjectRequest` preciso, para a frente e para trás um segundo por vez, fora da thread principal),
`FramePlacement` (ponto da gravação ↔ ponto do vídeo, com a correção do Stabilize, recorte, Seguir rosto ou Fit), `TrackedMotion` (Ramer–Douglas–Peucker a 0,4%), Track nas barras de texto e mídia
e no painel de movimento, com progresso e Cancel; um passo de desfazer. Um resultado só entra se é da corrida em curso, com o editor aberto e o
vídeo e o item como estavam ("The video changed meanwhile · Track it again"); fechar o editor cancela.

**Testes:** `ObjectTrackerTests` (quadrado nos dois sentidos, keyframes mínimos dentro da tolerância, ida e volta de pontos),
`QuickEditTrackTests` (texto no quadrado segue, um passo de desfazer).

## 4. Estabilização

**Medido no aparelho:** nas takes do dono (firmes, 0,5 px de tremor por quadro) não há o que tirar e o resultado fica igual (0,54 → 0,57 px).
Para medir de verdade, um quadro de uma take real sacudido como na mão (2% do quadro e 0,5°; `ShakenFootage`):

| | Tremor (px por quadro, cópia de 512) | Zoom | Exportação de 10 s |
|---|---|---|---|
| Sacudido | 2,63 | | |
| Gentle | 0,56 (−79%) | 3,2% | 1,9 s |
| Standard | 0,44 (−83%) | 3,5% | 1,9 s |
| Strong | 0,41 (−84%) | 3,7% | 2,0 s |

As medições mudaram o desenho três vezes: (1) blocos do fundo em vez do quadro inteiro (a pessoa não vira câmera); (2) zoom mínimo (90% dos
quadros) com o caminho mantido num corredor em vez de cortado, para nunca aparecer borda nem tranco; (3) cada quadro com a sua correção mesmo
quando a edição o segura (sem isso, uma gravação de 15 qps ou câmera lenta tremia mais que a original: 2,15 → 2,62 px).

**O que entrou:** `StabilizationPath`, `StabilizationLevel`, Stabilize na barra do clipe com Use on every clip e a nota do zoom.

**Testes:** `StabilizationPathTests` (5), `MotionExportTests.aShakingRecordingComesOutSteadier` (exportação real: tremor cai mais de 55%).

## 5. Tempo variável: curvas de velocidade e reverso

**Medido no aparelho:** exportação de 6,1 s sem curva e 8,0 s com Hero nos primeiros 10 s (o som é renderizado ao longo da curva). Reverso de
10 s em 2,2 s, arquivo de 16 MB, memória sem crescer depois, calor nominal.

**Medido no Simulador antes de decidir:** esticar o som em passos dentro da composição (o jeito do vídeo) deixava buracos com "Keep voice pitch"
(16 a 40 janelas de 10 ms abaixo de metade do nível) e estalos sem ele (4). O som passou a ser renderizado à parte (`CurveSoundRenderer`:
time-pitch da Apple ou varispeed, offline, a taxa mudando a cada 5,8 ms): sem estalos, e com o tom mantido no máximo uma queda de 20 ms num tom
puro de 6 s (a fala não foi medida assim).

**O que entrou:** `SpeedCurve` (0,25× a 4×, a faixa do varispeed da Apple; cúbica monótona em escala log, tempo = integral de 1/velocidade numa
tabela de 240 passos; cada parte ao dividir guarda no máximo 25 amostras mais os pontos de dentro quando são até 8, então dez divisões seguidas
ficam com no máximo 33 pontos), 7 curvas prontas e Custom com pontos arrastáveis, Normal | Curve no painel Speed, imagem esticada em 30 passos por
segundo (no máximo 1.500 por clipe), som renderizado fora da thread principal, lendo a gravação um segundo por vez (no máximo ~3 s na memória),
parado quando a prévia é refeita, os renders antigos de cada clipe apagados (ficam os 2 últimos); enquanto um dedo arrasta um ponto da curva ou
uma alça de clipe, a prévia estica o som em passos e o renderiza quando o dedo solta; Extract audio de um clipe curvo sai ao longo da curva; prévia ao alcançar
além das alças na velocidade da ponta, todas as contas de tempo do app passando pela curva (legendas, transcrição, capa, transições, quadros,
voz). Reverso: `ReversedClipWriter` (passos de quadros copiados, no máximo ~100 MB), `ReversedSound`, `ClipReversal` (Reverse de novo volta; mais
uma vez reaproveita o vídeo invertido já escrito; os que nada toca saem no Done; editor fechado durante a escrita: o arquivo é apagado); textos,
mídias e voice-overs no clipe ficam onde estavam.

**Testes:** `SpeedCurveTests` (9), `SpeedCurveExportTests` (cada quadro no momento da curva; som com e sem tom mantido), `ReverseExportTests`
(imagem e som de trás para a frente), `QuickEditReverseTests` (um passo, textos no lugar, volta ao original).

## 6. Cortes nas batidas

**Medido no aparelho:** 3 min de música (faixa de cliques a 124 BPM) em 1,63 s: 123,0 BPM, 371 batidas.

**O que entrou:** `BeatTracker` (fluxo espectral, tempo por autocorrelação com preferência por 120 BPM e teste de pulso, batidas por programação
dinâmica), `BeatDetector` (lê o arquivo, até 10 min), `BeatStore` (`.cuebeats` ao lado do arquivo; nada salvo de um arquivo já
removido), Beats na barra da música (só música dos Files; efeitos sonoros e sons extraídos do vídeo não têm): Snap to beats, Move cuts to the beats, Cut the video on every 1, 2 ou 4 batidas; risquinhos na faixa da música.

**Testes:** `BeatTrackerTests` (90, 120, 128 e 150 BPM com cada batida a até 25 ms; nenhuma no silêncio; ruído sem pulso).

## Testes rodados

- **Revisão de código (17/10, depois do Full em `60cb278`):** `scripts/check-warnings.sh` sem nenhum warning (Simulador, aparelho e Release);
  SwiftLint nos arquivos mudados: 0. Suítes de unidade da revisão (curvas, análise, serviço, rastreador, Track, Reverse, Extract audio, transições,
  player, seleção de legendas, composição, caminhos, batidas): 124 aprovados. Exportações reais `SoundExtractorTests`, `SpeedCurveExportTests`,
  `ReverseExportTests`, `MotionExportTests`: todas aprovadas. UI: `EditorMotionUITests` 2/2 e `CreatorWorkflowUITests/testEditByTextCuts…` 1/1.
  As duas exportações que estouraram o tempo no Full (`EditorExportMatchesPreviewTests/cutsTextsCaptionsAndLookExportAsPreviewed`,
  `QuickCreatorExportTests/aVoiceOverIsHeardFromWhereItStarts`) passam sozinhas em 2,9 s e 2,7 s: não usam curva nem movimento (a análise e
  o som de curva nem entram nesses builds), foi a carga do plano em paralelo. Plano Fast: 3.523 aprovados, 2 falhas de tempo sob carga que
  passam sozinhas (`QuickEditCopyLookTests/aPasteThatChangesNothingSaysSo`, `QuickEditPlayerTests/playingFromTheEndStartsAgain`: 37/37).
- **Plano Fast** (unidade sem as exportações reais), no fim: **3.474 aprovados**, 2 falhas que passam sozinhas (`CoverRendererTests`
  estourou 5 min e `QuickEditCopyLookTests` leu o aviso antes da hora, os dois sob a carga do plano em paralelo; reexecutados: 9/9). Na primeira
  rodada, 8 falhas: 6 expectativas das barras (as ferramentas novas), o teste de pausa do serviço de análise (corrida de tempo; o analisador
  falso agora espera ser parado) e os mesmos dois de tempo.
- **Suítes novas e exportações reais** (Simulador): análise, serviço, caminhos, rastreador, curvas, batidas, reverso, exportações de Seguir
  rosto, Estabilizar, curvas e reverso: todas aprovadas.
- **UI:** `EditorMotionUITests` 2/2 (Format › Follow face e ritmo com desfazer; Stabilize, Speed › Curve › Hero com o editor e Reverse).
- **Aparelho:** `MotionAnalysisDeviceTests` 1/1, `EditorMotionDeviceTests` 6/6.
- **Warnings:** build do Simulador com todos os arquivos mudados recompilados: 0; SwiftLint nos arquivos mudados: 0. Aparelho e Release não
  conferidos (`check-warnings.sh` fica para a fase de testes).
- **Textos:** 68 novos nos 20 idiomas (`scripts/strings.py missing`: 0).

## Comparação com CapCut, Edits e InShot

Seguir rosto = "Auto reframe" do CapCut (no painel de formato, com ritmo); Stabilize com três níveis como no CapCut, por clipe, mais "Use on every
clip"; Track sem caixa (o item é a caixa: põe e toca), um passo a menos que o CapCut; Speed com Normal | Curve e Reverse na barra do clipe como
CapCut e InShot; Beats como as marcas de batida do CapCut, mais ímã e cortes automáticos. Nenhuma diferença pediu mudança de layout além dessas
(registrado em §39).

## Contraste

Nenhuma cor nova: tokens de `Palette` (`acc`, `accText` sobre `Editor.accTile`, `ink`, `ink2`, `Editor.panelCard`; `ink3` e `Editor.separator` só
na grade decorativa do editor de curva; os risquinhos das batidas na cor do rótulo da faixa). Não medi capturas das telas novas (`tools/contrast/
audit.py`): fica para a fase de testes.

## O que NÃO foi validado

- Estabilização numa take **realmente** tremida (as do aparelho são firmes); validada com um quadro real sacudido de forma conhecida.
- Som de curva com fala real (medido com tom puro); reverso de 2 min e de 4K (medido 10 s em 1080p).
- Track em objetos que não sejam rosto (medido no rosto da take); batidas em música real (medido em cliques).
- Seguir rosto e Estabilizar em gravações de 60 qps e em vídeos do Fotos de outros aparelhos.
- O caminho da análise com o Cue indo e voltando do segundo plano no aparelho (testado com analisador falso no Simulador).
- iPhone 15 comum (A16): o dono não tem.
- A faixa de quadros da timeline num clipe curvo é desenhada na velocidade média (aproximação visual).
- Commits por função: arquivos que várias funções mudam (`EditedComposition`, `EditSegment`, `EditTimeline`, `TakeEdit`, o view model, as barras,
  o String Catalog) entram no commit da primeira função que os usa; só o último commit compila garantido sozinho.

## O que mudou no aparelho

Nada nas takes nem no Fotos: todos os testes de aparelho trabalharam em **cópias** das takes mais novas, na pasta temporária, apagadas no fim de
cada teste (análises, exportações, reversos e o vídeo sacudido também). O app de testes foi instalado e rodado no iago Lima iphone pelo
`xcodebuild test` (o app do Cue Studio instalado é o do pacote de testes desta branch até a próxima instalação).
