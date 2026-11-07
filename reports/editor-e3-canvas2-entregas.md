# Canvas 2 · relatório por entrega

Decisões: `editor-e3-canvas2-decisoes-2026-11-07.md`. Plano: `editor-e3-canvas2-plano.md`. Cada entrega diz o commit, as decisões cobertas, o que
muda para o criador, a evidência separada (aparelho × Simulator × código) e o que falta. Branch `feature/editor-trust`, sem push até o fim.

## Entrega 1 · Correções independentes — `922b12b2`

**Decisões:** erros 1, 5, 8 (Velocidade abria em Curve no clipe seguinte), 12 (ES); F6, F7, F8, F9, F11, N2; verificação de Volume › Avançado.
O erro 11 foi para a entrega 8 (ajudante), e Fundo › Recorte para a 2.

**O que muda para o criador**
- **Velocidade:** Normal e Curve só trocam a vista, e cada clipe abre na sua; a curva nunca some por trocar de vista. Escolher uma velocidade com
  curva a troca num passo, com o toast "Curve replaced by 1×" e Undo. Keep voice pitch está nas duas vistas.
- **Transição:** os dez estilos numa fileira lateral; "Use on all 4 cuts" diz quantos cortes, e o toast ("Dissolve on all 4 cuts") tem Undo.
- **Filtros:** Intensity em cima dos cartões; miniaturas de 64 pt (eram 88).
- **Pele:** chip e régua dizem **Texture** (o chip dizia "Refine").
- **Batidas:** Cut on → botão que diz o intervalo ("Cut every 2 beats") → Snap → "Move my cuts to the nearest beat"; a nota diz de onde vieram as
  batidas (música do Cue ou dos Files).
- **Volume:** numa foto ou vídeo por cima, Reset mexe só no som dele e o volta a como entrou (mudo, ou 100% se o criador manteve o som); o clipe
  embaixo fica. Com Avançado aberto, o painel do clipe cresce e rola até ele: Fade in e Fade out inteiros.
- **Barra da legenda:** Edit, Style, Split, Join next, Emphasis.
- **Espanhol:** "…en la barra del contenido".

**Evidência**
- Código + Simulator (unidade): `QuickEditSpeedViewTests` (3), `QuickEditToolFixesTests` (8), `QuickEditToolbarTests` e as suítes vizinhas: 141/141.
- Simulator (UI): `VolumeAdvancedReachUITests` (os dois fades inteiros no clipe; os da música alcançados rolando), `EditorUITests`,
  `EditorMotionUITests`, `CaptionToolsUITests`, `AudioMixUITests`, `TrackBarsUITests`, a montagem do `CreatorWorkflowUITests`: 47/48 na 1ª
  rodada (o Fade in ficava abaixo do painel médio), corrigido com a rolagem até o Avançado e 16/16 na 2ª (Volume, Fundo, barra do clipe, receitas,
  Máscara/Desfocar).
- Aparelho: nada ainda (vai na entrega 11).

**Falta:** o toast de Batidas "Split the video first, or use Cut on the beats" ainda cita o nome antigo (rever na entrega 6, nomes).

## Entrega 2 · Desfazer e resets — `adde3557`

**Decisões:** erro 3; R5 (B com resets específicos): nomes do Desfazer, Auto/Measure no Ajustar, resets com alcance, Fundo, Center and fill.

**O que muda para o criador**
- **Desfazer diz a ferramenta:** "Undid · Clip 2 · Speed", "Undid · Stabilize" (vários clipes), "Undid · Transition", "Undid · Pauses" (Pauses
  longer than e Gap left), "Undid · Beats". Antes: "Clip 1" para qualquer painel de clipe e "Adjust" para pausas, respiro e batidas.
- **Ajustar:** o chip Auto só escolhe a régua; quem mede é **Measure**, sempre à vista (também com o Auto aberto). Toques reais: hoje 1 (a cápsula
  "Auto"); agora 1 (Measure). O chip não mede mais sem querer.
- **Reset com alcance definido:** Texto (o visual com que um texto do papel dele começa neste vídeo, sem movimento; palavras, lugar, tempo e giro
  ficam), Gráfico (cor do tipo, 100%, sem giro e sem movimento), Movimento de foto ou vídeo (sem entrada, saída e keyframes), Foto ou vídeo (janela
  Original, tamanho e opacidade de quando entrou; como aparece, a parte que toca e a ordem ficam). Com o estilo de todos os textos não há Reset de
  um texto. O da Proporção veio na entrega 8 (F16).
- **Fundo:** o cartão Cutout diz **In use** quando um fundo está escolhido; o caminho de volta do vídeo inteiro segue sendo o tile Original. Em
  português o Cutout virou **Contorno** (era "Recorte", perto demais do Crop, "Recortar").
- **Tela dividida:** Center and fill já só mexia no enquadramento; agora um teste garante.

**Evidência**
- Código + Simulator (unidade): `QuickEditLayerResetTests` (6: texto, gráfico, estilo de todos, movimento, foto ou vídeo, Center and fill),
  `QuickEditGestureTrustTests.aClipsChangeIsNamedByTheToolThatMadeIt` (velocidade, zoom, look, vários clipes, transição, um clipe só, pausas,
  respiro, batidas): 39/39 e 6/6.
- Simulator (UI): `EditorUITests.testAutoMeasures…` (o chip Auto não mede sozinho; o botão diz Measure) e `BackgroundPanelUITests`: 16/16.
- Aparelho: nada ainda (entrega 11).

**Falta:** "Undid · Clip 2 · Speed" junta o número e a ferramenta com " · " sem tradução própria (o separador é o mesmo em todo o app; conferir no
árabe na entrega 11).

## Entrega 3 · Memória e folhas — `032655b3`, `6d2511a7`

**Decisões:** R7, R11, R4 (folhas), F13, F14.

**O que muda para o criador**
- **Painel lembra (R7):** cada painel abre na aba e com o Avançado como foi deixado neste vídeo; os painéis de um item lembram por item (o texto A
  em Color, o B em Font). Um caminho que pede uma aba (o ••• de um cartão, a barra da legenda) continua abrindo nela.
- **Text to speech e kit de marca guardam o que foi escrito (R11):** fechados com um deslizar, voltam com o texto e dizem "Your text from before is
  back · Cancel discards it"; **Cancel** no cabeçalho joga fora. O X do sistema fecha guardando, como o deslizar.
- **Add photo or video (F13):** abre alta, com cartões de modo menores e explicações de uma linha. Com fotos escolhidas, deslizar não fecha; Cancel
  ou voltar da revisão pergunta **"Discard what you picked?"** com **Discard 3** e **Keep picking**.
- **Música e efeitos (F14):** uma folha alta só, com as duas partes sempre à vista (Music | Sound effects), cada botão da barra abrindo a sua;
  Browse Files embaixo da busca, antes das faixas do Cue; o nome da parte não se repete.

**Evidência**
- Código + Simulator (unidade): `QuickEditPanelMemoryTests` (aba e Avançado por painel e por item, caminho que pede aba, rascunho do TTS e do kit):
  86/86 com as suítes vizinhas.
- Simulator (UI): `SheetsKeepWorkUITests` (três escolhidas e uma tirada: entram duas; Cancel pergunta e Keep picking não perde nada; arrastar pelo
  puxador não fecha; TTS volta com o texto e Cancel joga fora; folha alta de música com as duas partes), `AudioMixUITests` 5/5, `CreatorWalksUITests`,
  `VolumeAdvancedReachUITests`. Três testes falharam na 1ª rodada: o `confirmationDialog` do iOS 27 esconde o botão de cancelar no iPhone (troquei
  por um alerta, que mostra os dois), e dois eram o teste (o nome "Sound effects" do botão da barra atrás da folha; o deslizar no TTS só baixava o
  teclado). Capturas conferidas: a pergunta com os dois botões e a folha de efeitos.
- Aparelho: nada ainda (entrega 11).

**Decisões tomadas sem o dono:** alerta em vez da folha de pergunta do quadro (no iOS 27 a folha não mostra "Keep picking"); explicações longas dos
modos saíram do catálogo.

**Falta:** nada desta entrega.

## Entrega 4 · Cabeçalhos e Text style — `b6791f94`, testes `aaa1fa45`, merge `9d3cd303`

**Decisões:** R1, R2, R3, F3, F4, bug 4.

**O que muda para o criador**
- **Cabeçalho de uma linha (R1):** o subtítulo de cada painel cabe numa linha ao lado dos botões em todos os idiomas; as contagens dizem quantos
  ("Use on all 3 clips", "All 2 texts").
- **Text style em quatro abas (R3):** Styles · Font · Color · Motion, um nível só. Animated e Mine viraram filtros de Styles, com os estilos do criador
  primeiro e Save no fim. Templates e Brand kits viraram painéis próprios.
- **Escopo no cabeçalho (R2, bug 4):** "This title | All 2 texts" fica no lugar do subtítulo, cada escolha da largura das palavras, e sai da frente
  enquanto se digita. Com All, a timeline acende todos os textos; Motion continua sendo só deste texto.
- **••• no canto da imagem do cartão (F3);** um gráfico tem as abas Style e Motion (F4).

**Evidência**
- Código + Simulator (unidade): `QuickEditPanelMemoryTests` e as suítes de texto, verdes no branch.
- Simulator (UI): `TextStyleUITests` 7/7 e `EditorTaskUITests` (Logbook no título e depois em todo texto). Na 1ª rodada falharam 3; eram os
  testes: um lia o subtítulo antigo, outro media o escopo pela área de toque (que passa um pouco das palavras), e o rolar do painel usava o swipe
  do XCTest, que não mexe numa lista cuja moldura passa da tela (troquei por um arrasto na parte visível, como faz um dedo com o teclado aberto).
- Integração na `feature/editor-trust` (merge `9d3cd303`): as suítes das entregas 3, 4 e 9a juntas (memória dos painéis, capa, folhas, cabeçalho,
  Logbook) 53/53 no Simulator.
- Aparelho: nada ainda (entrega 11).

**Decisões tomadas sem o dono:** o subtítulo volta enquanto se digita (o escopo some com o teclado, e o cabeçalho não pode ficar vazio).

**Falta:** nada desta entrega.

## Entrega 6 · Mídia, Motion e prévia que segura — `fb682db4`, correções `c41be45c`, merge `c6c4529a`

**Decisões:** F15, F5, R12, R6, bugs 9 e 12.

**O que muda para o criador**
- **Pausado sobre um item escolhido (F15, bug 9):** a prévia mostra o texto, o gráfico, a foto ou o vídeo como fica depois de entrar (o 1º quadro do
  Pop, o fim do In and out), então dá para ajustar sem dar play. O playhead não pula mais para depois da entrada; a revisão e o export não leem isso.
- **Motion:** Pop vem primeiro, depois Track e Keyframes; Starts e Ends ficam no Advanced.
- **Show | Part (F5 B):** só o painel de foto ou vídeo por cima ganhou abas (uma foto tem só Show). Em Part, Duration oferece 1, 2, 3, 5 e 10 s.
- **− e + que repetem (R12):** segurar repete, e a sequência inteira é um passo de Undo.
- **Track › Stop guarda o que foi seguido (bug 12),** como no Blur area; Undo tira. Um vídeo por cima diz **Volume** na barra, no título e no controle (R6).

**Evidência**
- Código + Simulator (unidade): `PreviewMotionHoldTests`, `QuickEditMotionTests`, `QuickEditTrackTests`, `QuickEditMediaNamesTests`,
  `OverlayAnimationTests`, `QuickEditSplitScreenTests`, `PreviewMatchesExportTests` e vizinhas, 92/92.
- Simulator (UI): `MediaMotionUITests` (Show | Part, Duration com os tamanhos comuns, segurar o +, um Undo para a sequência, Volume, Pop primeiro,
  Starts no Advanced), `TextPresetsUITests`, `EditorRecipeUITests`. Falhas da 1ª rodada eram do teste: o valor "2,0s" com vírgula, o nome do controle
  lido no lugar do valor, e o vídeo do demo sem som (o Volume avisa "This video has no sound", certo).
- **Medido:** o repetir do sistema dá ~5 passos em 2 s segurando (2,0 → 2,5 s). É o ritmo de `buttonRepeatBehavior`; se ficar lento no aparelho,
  dá para acelerar com um repetir próprio.
- **Não validado:** a prévia que segura o quadro precisa do iPhone (o Simulator não toca a composição). Fica para a entrega 11.

**Decisões tomadas sem o dono:** nenhuma além do quadro.

**Falta:** conferir no aparelho a prévia pausada no Pop e no In and out.

## Entrega 7 · Clean up — `dfc2c9bd`, correções `c41be45c`, merge `c6c4529a`

**Decisões:** F10, M3, F11.

**O que muda para o criador**
- **Abre na fileira de pausas (F10):** os ajustes (pausas maiores que, sobra) ficam atrás de uma cápsula no cabeçalho ("0,7s"), lembrada como Advanced.
- **Marca na timeline leva ao cartão (M3):** o 1º toque numa marca acende o cartão dela (troca de aba se for palavra, rola até ele) e mostra aquele
  momento, sem mudar nada; o 2º toque troca Remove/Keep. VoiceOver diz o que ficou.
- **Text (F11):** sem nada escolhido, uma nota diz como escolher palavras ("Tap the first word…"); as ações só aparecem com palavras escolhidas.

**Evidência**
- Código + Simulator (unidade): `QuickEditPausesPanelTests` (marca → cartão → troca; abre com os ajustes guardados), `QuickEditCleanUpPanelTests`.
- Simulator (UI): `CleanUpUITests` inteiro (fileira primeiro, ajustes no cabeçalho, marca → cartão aceso → 2º toque troca, nota do Text),
  `NotificationsUITests`. A falha da 1ª rodada era do teste: "1,2s" lido como 12 s, o toque caía fora da marca.
- Aparelho: entrega 11.

**Decisões tomadas sem o dono:** M3 com dois toques (o 1º só mostra), para que nada mude sem o cartão à vista; os ajustes atrás de uma cápsula com o
valor, não de um ícone só.

**Falta:** nada desta entrega.

## Entrega 8 · Done, exportação e proporção — `649ba682`, merge `0df22492`

Feita por um ajudante (branch `e3c2-done-export`); revisada e unida por mim.

**Decisões:** F16, F17, F19; erros 2, 10, 11.

**O que muda para o criador**
- **Done no texto grande (F17, erro 2):** nos tamanhos de acessibilidade, título e detalhe de cada resposta usam a largura toda e só quebram entre
  palavras; a pílula (SHARED / IN PHOTOS) desce para baixo deles e cresce com o texto (antes os 22 pt fixos a cortavam).
- **Opções dentro do Done (F19):** "Export options · …" vira a segunda página do próprio Done, com "‹ Export options"; nada de folha sobre folha.
  Com Reduzir Movimento, a página só aparece, sem deslizar. O formulário é um só (`ExportOptionsForm`) para o Done e para a revisão.
- **Tamanho real (erro 10):** quando o formato corta o vídeo e o arquivo sai menor que a qualidade, Done, Share e "Ready to travel" dizem
  **606×1080**; em Quality: "This format exports at 606×1080 · never enlarged". O vídeo nunca é aumentado.
- **Proporção (F16):** cartões baixos (44 pt, eram 68), então Framing e Follow face aparecem sem rolar; Reset no cabeçalho volta à proporção da
  gravação, Fill, sem deslocamento e Follow face desligado, num passo de Desfazer; a nota de tamanho também aparece aqui.
- **Erro 11:** a nota de falta de espaço nunca oferece o formato já escolhido ("Pick 4:5, 1:1, or 16:9…" numa gravação 9:16).
- **Rosto:** duas notas novas que não mudam o enquadramento: mais de um rosto em 25% dos momentos com gente ("the frame follows one") e rosto
  achado em menos de 60% do vídeo ("the frame holds still where it's lost").

**Evidência**
- Código + Simulator (unidade): `ExportFrameSizeTests`, `FaceFollowLimitTests`, `QuickEditFormatTests`, `TakeReviewViewModelTests` e vizinhas:
  72/72 no ajudante; 82/82 no meu branch depois do merge (o conflito em `PanelReset` ficou com os dois lados).
- Exportação real no Simulator: `ExportCaptionChoiceTests` 1/1 (1920×1080 a 9:16 em original, tradução, as duas e sem legenda; todo arquivo 606×1080
  e os pixels queimados conferidos).
- Aparelho: nada ainda (entrega 11).

**Decisões tomadas sem o dono:** o tamanho só aparece quando é o corte que reduz (o vídeo de teste, 144×256, mostrava "144×256" em tudo); o Done
empilha em `isAccessibilitySize` em vez de `ViewThatFits`, para as quatro respostas ficarem iguais entre si; a "baixa confiança" do rosto é medida
pela frequência com que ele é achado (o Vision não guarda rostos abaixo de 0,5).

**Falta:** um vídeo importado só mostra o tamanho depois que o arquivo é lido; ver no aparelho na entrega 11.

## Entrega 9a · Capa — `8ed18cae`, `3dfd369f`, merge `b88f507a`

Feita por um ajudante (branch `e3c2-cover`), adiantada porque a Capa não depende das outras entregas; o resto da 9 (fontes, F12) continua no plano.

**Decisões:** F18, R8 (teclado na Capa), §7.2 (a fita de quadros não mexe na agulha do editor).

**O que muda para o criador**
- **Picture:** Zoom e Reset numa linha de 44 pt logo abaixo da fita de quadros, à vista sem rolar do iPhone SE para cima.
- **Title:** Words · Type · Color · Box embaixo do campo, abrindo em Words (palavras em destaque e Line above); Box é o antigo Readability. A
  sugestão nunca repete o título atual.
- **Teclado aberto (R8):** a barra de passos e o cabeçalho somem e a capa encolhe para 28% do espaço acima do teclado (no máximo 150 pt). Campo,
  sugestões, Words e as palavras em destaque ficam acima do teclado e das sugestões dele, também no SE.
- **Graphics:** os controles do gráfico escolhido vêm primeiro; a fileira de adicionar vem depois, menor.
- **Effects:** o último passo (era Finish) guarda o Remove cover. **Save style** virou o cartão tracejado no fim de Template.
- **Agulha:** escolher quadros na Capa não mexe na agulha do editor (já era assim; agora tem teste).

**Evidência**
- Código + Simulator (unidade): `CoverStudioViewModelTests`, `QuickEditCoverTests`, `CoverPartTests`, `CoverTitleSuggestionsTests`,
  `CoverGalleryCardTests`: 32/32 (a agulha fica em 21 s depois de Done e de Cancel).
- Simulator (UI): `CoverStudioUITests` 7/7 no iPhone 17 e 7/7 no "Cue v10 iPhone SE". Conferi as capturas: teclado aberto no SE e Picture.
- Aparelho: nada ainda (entrega 11).

**Decisões tomadas sem o dono:** "Next: X" some junto com o cabeçalho enquanto se digita; chave própria `coverStudio.title.words` (o "Words" que
já existia diz "palavra por palavra" em tailandês e vietnamita).

**Falta:** na linha de Zoom, o trilho do slider ficou curto (cerca de 90 pt entre "Zoom" e "100% Reset"); reavaliar na entrega 11.

## Entrega 9 · Minhas fontes (F12) — `f6380734`, merge `c6c4529a`

**Decisões:** F12.

**O que muda para o criador**
- **My fonts em todo seletor:** as fontes importadas aparecem num grupo próprio no Text style › Font, no Caption style (Custom) e no título da Capa,
  separadas da lista do Cue.
- **Tirar uma fonte:** Edit põe um − em cada uma (ou segurar o chip › Remove). Sai com Undo no aviso: "%@ removed · videos that use it keep it".
  Uma fonte em uso no vídeo aberto continua à vista e não sai.

**Evidência**
- Código + Simulator (unidade): `CustomFontStoreTests` (tirar com Undo, um vídeo na família tirada continua com ela), `CoverStudioViewModelTests`.
- Simulator (UI): `MyFontsUITests` (fonte importada pelo `-uiTestImportedFont`, Edit, −, Undo), `CoverStudioUITests`.
- Aparelho: entrega 11 (importar uma fonte de verdade pelo Arquivos).

**Decisões tomadas sem o dono:** Edit com − (o padrão do iOS) além do segurar, para não ter porta só por toque longo (plano §8).

**Falta:** nada desta entrega.

## Entrega 10 · Barra do clipe, faixas e timeline ao lado do estilo — `08817ea9`, `58d3b0f3`, `b6a6ea2f`, `419e82ae`, `e9f12dc3`, merge `c6c4529a`

**Decisões:** M2, N1, R10 §7.3.

**O que muda para o criador**
- **O que já mudou no clipe (M2):** um ponto amarelo no canto das ferramentas que já mudaram o clipe escolhido (Speed, Volume, Zoom, Adjust, Skin,
  Filters, Background, Crop, Stabilize, Animation, Voice effects, Transition). Muda com outro clipe, Reset e Undo; VoiceOver diz "Changed on this clip".
  Mute e Mirror já são chaves acesas; Blur area é da faixa dele.
- **Quantas faixas (N1):** com as faixas guardadas, o quadrado da faixa atual mostra uma pilha e o número de faixas sob o vídeo ("▤ 4"); abertas, ▴.
  Sem clipe escolhido, a marca de um corte pega o toque a 44 pt.
- **Timeline acima do Text style e do Caption style (R10 §7.3):** a régua e a faixa do painel ficam à vista; tocar outro texto ou legenda ali troca o
  que se estiliza, sem ✓. O vídeo fica no menor tamanho e o painel cede até 330 pt (uma fileira inteira de estilos). Expandido, a faixa sai.
- **No SE:** ⌄ no cabeçalho da folha tira a folha da frente e devolve a timeline inteira; uma barra com o nome do painel a traz de volta como estava
  (item, aba, playhead), e ✓ termina.

**Evidência**
- Código + Simulator (unidade): `ClipAppliedToolsTests` (marcas por ferramenta, a transição do corte seguinte, Undo), `TimelineGeometryTests` (alcance de
  44 pt, contagem de faixas), `EditorLayoutTests` (régua e faixa acima do painel cheio em todas as telas menos o SE, o painel ≥ 330 pt, o vídeo ≥ o
  mínimo, a soma bate), `QuickEditPanelTuckTests` (só a faixa do texto acima; guardar e voltar com o mesmo texto, aba e playhead).
- Simulator (UI): `TextStyleUITests` 8/8 no iPhone 17, incluindo o novo (faixa acima, rolar a timeline com o painel aberto e tocar o subtítulo troca o
  texto no painel). Integração na `feature/editor-trust`: 61/62 na 1ª rodada (a falha era do teste, corrigida e repassada).
- **Não validado:** o ⌄ do SE roda só no SE (o caminho do teste existe, mas os scripts usam o iPhone 17 e não crio simulador); fica para o aparelho
  ou um SE disponível. **Não conferido ainda:** chegar a Music/Beats a partir de outra faixa com a contagem nova.

**Decisões tomadas sem o dono:** a contagem conta as faixas sob o vídeo (o atalho de áudio conta); o alcance de 44 pt só sem clipe escolhido (com um
escolhido, as alças vêm primeiro); no SE a folha sai por ⌄ em vez de ficar baixa, porque baixa ela ainda cobriria a faixa.

**Falta:** conferência no SE e no aparelho.

