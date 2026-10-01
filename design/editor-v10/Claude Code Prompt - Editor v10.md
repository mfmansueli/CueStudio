# Prompt para o Claude Code — Cue Studio: Editor v10

> Copie tudo abaixo da linha e cole no Claude Code, na raiz do repositório do app.
> Antes, coloque em `design/editor-v10/` no repositório: `Cue Editor v10.dc.html`, `support.js` e a pasta `assets/`.
> Para ver o protótipo, abra o `.html` num navegador.

---

Você vai redesenhar e reimplementar o **editor de vídeo (Quick edit)** do app iOS **Cue Studio**.

O objetivo é que alguém **sem experiência** consiga, sem nenhuma explicação:
- cortar um erro;
- remover uma pausa;
- corrigir uma legenda;
- estilizar um título.

A lógica de edição deve ser familiar para quem já usa editores com timeline (playhead central fixa, ferramentas por contexto), mas com a identidade visual do Cue.

**Não copie a interface de nenhum app de terceiros:** ícones, nomes e layout seguem o protótipo.

## Referência de design (fonte da verdade)
- `design/editor-v10/Cue Editor v10.dc.html` é um protótipo interativo completo.
  - **Template (markup):** layout, espaçamentos, cores, textos e estados visuais de cada painel.
  - **Classe `Component` (`<script>`):** estados, regras, cálculos e dados de exemplo. Os pontos principais são:
    - `derive()`: mapeamento entre tempo do original e tempo editado;
    - `pauses()`: detecção das pausas;
    - `cutRange()`: remoção de trechos;
    - `vTimeline()`: layout das faixas;
    - `vToolbar()`: ações de cada contexto;
    - `vPanel()`: conteúdo de cada painel;
    - `PRE`: presets de texto;
    - `PH`: altura de cada painel.
- **Leia o arquivo inteiro antes de começar.** Quando este prompt e o protótipo divergirem, siga o protótipo e me avise.
- **Não implemente o painel lateral** do protótipo ("Teste as 4 tarefas", "Onde ficou cada recurso"). Ele existe só para a demo.
- **O que no protótipo é só simulação** e aqui precisa funcionar de verdade:
  - Background (Blur / Color / Image) e Color key;
  - Enhance voice / Reduce noise;
  - Compare with original;
  - tradução das legendas;
  - geração automática das legendas;
  - a imagem do vídeo, que no protótipo é um quadro fixo.

## Regras de trabalho
1. **Explore o código primeiro e me reporte antes de alterar qualquer coisa.** Mapeie:
   - a tela atual do Quick edit e as abas Edit / Text / Captions / Audio / Media / Adjust;
   - o player e a fonte da verdade do tempo;
   - o modelo de edição atual (EDL/segmentos, se já existir da fase anterior);
   - a geração de thumbnails;
   - a exportação (composition, videoComposition, audioMix);
   - o Clean Up (transcrição, silêncios, vícios de linguagem);
   - o autosave e o rascunho ("Draft restored" / "Draft kept");
   - a navegação para dentro e para fora do editor.

   Depois mostre um plano curto com a lista de arquivos a mudar.
2. **Reaproveite o motor e troque a interface.** O que já funciona na parte de mídia deve ser mantido: player, EDL, export, transcrição, Clean Up. A mudança principal é de interface e de interação. Se algo do motor impedir o novo comportamento, refatore só essa parte.
3. **Trabalhe por fases** (abaixo). Ao fim de cada uma: compile, rode os testes, faça um commit e me mostre um resumo curto com captura do Simulator em **iPhone SE (3ª geração), iPhone 16 e iPhone 16 Pro Max**.
4. **Não quebre o que já funciona:** takes já editadas devem abrir com as edições intactas. Se o modelo de dados mudar, escreva a migração e um teste para ela.
5. **Apenas frameworks da Apple:** AVFoundation, Core Image, Vision, Speech, Translation, Foundation Models, Core Haptics e Accelerate. Nenhum SDK de terceiros, nenhum backend.
6. **Se algo depender de uma API que você não conseguir confirmar no SDK instalado, pare e me pergunte. Não invente API.**
7. **Nada falso na tela.** Todo controle que aparece funciona. Se um recurso não estiver disponível no aparelho (Apple Intelligence, Translation), mostre o controle desativado com o motivo.

## Tokens (mantenha no arquivo de tema existente; não espalhe cores soltas)
- **Fundos:** tela `#000000`; painéis do editor `#121214`; controles `#1C1C1E` / `#2C2C2E`; segmento selecionado `#636366`; controle neutro `rgba(118,118,128,0.24)`.
- **Texto:** branco; secundário `rgba(235,235,245,0.6)`; terciário `rgba(235,235,245,0.3)`.
- **Acento:** amarelo `#FFD60A`. Usado em:
  - seleção (contorno de 2 pt e alças de trim);
  - botão Export;
  - botão ✓ de aplicar;
  - pausas marcadas para remoção;
  - toasts.
- **Destrutivo:** `#FF453A`. **Toggle ligado:** `#34C759`.
- **Cores das faixas da timeline** (fundo em 20–32% + texto na cor cheia):

  | Faixa | Fundo | Texto |
  |---|---|---|
  | Texto | `rgba(255,214,10,.2)` | `#FFD60A` |
  | Legendas | `rgba(235,235,245,.14)` | branco |
  | Música | `rgba(10,132,255,.3)` | `#64D2FF` |
  | Voice-over | `rgba(255,159,10,.3)` | `#FFB340` |
  | Mídia sobreposta | `rgba(191,90,242,.3)` | `#DA8FFF` |
  | Gravando (voice-over) | `rgba(255,69,58,.5)` | — |

- **Raios:** painel inferior 22 pt (só nos cantos de cima); sheets 28 pt; clipes da timeline 7 pt; itens das faixas 6 pt; botões pill = altura ÷ 2.
- **Tipografia da interface:** SF Pro. Nos controles, nunca use as fontes de estilo.
- **Fontes de estilo** (títulos e legendas no vídeo): **DM Sans** (400/500/700/800), **Space Grotesk** (400–700) e **DM Serif Display** (400).
  - As três usam a **SIL Open Font License 1.1**, que permite uso comercial e embutir no app.
  - Empacote os arquivos `.ttf` no bundle, registre em `UIAppFonts` e inclua o texto da licença na tela de Acknowledgements.
  - O mesmo arquivo de fonte precisa ser usado no preview e na exportação.

## Fase 1 — Layout adaptativo (CRÍTICO: aparelhos menores que o Pro Max)
O protótipo foi desenhado para 402×874 pt (iPhone 16 Pro). **Não use posições fixas.** Monte a tela como uma pilha vertical com orçamento de altura calculado a partir da área útil (`safeAreaInsets` reais):

```
[Top bar 44]
[Preview  ← flexível]
[Player bar 44]
[Timeline ← flexível, com mínimo]
[Toolbar 64]  ou  [Painel com altura por tipo]
[home indicator / safe area]
```

**Regras de distribuição** (implemente numa única `struct EditorLayout`, com teste unitário):
- `H` = altura útil entre a safe area de cima e a de baixo.
- Sem painel aberto:
  - `timeline = clamp(0.32·H, 184, 300)`;
  - `preview = H − 44 − 44 − timeline − 64`.
- Com painel aberto, o painel tem três tamanhos:

  | Tipo | Painéis | Altura |
  |---|---|---|
  | mini | Speed, Zoom, Volume, Filters, Crop, Voice-over, Auto captions | `clamp(0.27·H, 200, 250)` |
  | médio | Voice, Pauses, Captions, Adjust, Background, Cover | `clamp(0.35·H, 250, 330)` |
  | cheio | Text style, Caption style | `clamp(0.44·H, 300, 380)` |

  Neste caso, `timeline = max(0, H − 44 − 44 − preview − painel)`.
- **Mínimo do preview** (o vídeo nunca some):
  - `previewMin = max(0.30·H, 190)`;
  - se o painel + o preview não couberem, **reduza a timeline primeiro** e depois deixe o painel rolar internamente;
  - nos painéis cheios, a timeline pode sumir (ela não é necessária para estilizar).
- **Preview:** mostra o frame no formato da take (9:16, 4:5, 1:1, 16:9), com "fit" dentro da área disponível. Converta coordenadas com um único `FrameGeometry` (VideoSpace 1080×1920 ↔ ScreenSpace). O tamanho dos textos no preview é proporcional ao frame, para que o preview seja igual ao export.

**Classes de altura** (use `H`, não o nome do modelo):
- **Regular (H ≥ 780; ex.: 16, 16 Pro, Pro Max):** layout do protótipo.
- **Compacto (680 ≤ H < 780; ex.: mini, 13/14 com Dynamic Type grande):**
  - trilha principal 48 pt, faixas 24 pt;
  - rótulos da toolbar a 10 pt;
  - no Text style, as abas Presets / Font / Color / Motion ficam na mesma linha do seletor de escopo (rolagem horizontal).
- **Muito compacto (H < 680; ex.: iPhone SE):**
  - top bar 40 pt, player bar 40 pt;
  - trilha principal 44 pt, faixas 22 pt;
  - a toolbar mostra só ícones com 44 pt de alvo (os rótulos saem e ficam no VoiceOver e num tooltip de toque longo);
  - os painéis cheios abrem como sheet com detents `.medium`/`.large`, mas no `.large` a borda de cima para **abaixo do preview mínimo**, nunca cobrindo o vídeo;
  - o preview em tela cheia (botão ⤢) fica mais importante: garanta que funcione.
- **Largura:**
  - teste em 375 pt (SE/mini);
  - a toolbar rola horizontalmente com itens de 64 pt (60 no compacto) e mostra um fade na borda direita quando há mais itens;
  - os segmentados com 5 a 6 opções (velocidade, reveal) diminuem a fonte até 12 pt antes de quebrar;
  - nada de texto truncado com "…" em rótulos de ação.
- **Dynamic Type:**
  - os controles respeitam até `accessibilityMedium`;
  - acima disso, os painéis rolam, e a timeline e a toolbar mantêm o tamanho.
- **Critério de aceite:** no iPhone SE, com o painel Pauses aberto, dá para ver o preview, a trilha principal com as pausas marcadas e o botão "Remove N pauses", sem rolar.

## Fase 2 — Timeline central
**Referência:** `vTimeline()` e o bloco `<!--TIMELINE-->` do template.

Implemente com **UIKit** (um `UIScrollView` ou uma `UICollectionView` com layout customizado dentro de `UIViewRepresentable`) para ter rolagem, inércia e pinça nativas e fluidas.

**Playhead central fixa:**
- linha branca de 2 pt no centro horizontal, sobre todas as faixas;
- o conteúdo rola por baixo dela, e o tempo atual é `contentOffset.x / pontosPorSegundo`;
- durante o scrub: `seek(toleranceBefore: .zero, toleranceAfter: .zero)`, com o player pausado;
- durante o play: o `AVPlayer` (via `addPeriodicTimeObserver`) move o `contentOffset`. O player é a fonte da verdade.

**Zoom por pinça:**
- ancorado na playhead (o tempo sob ela não muda);
- `pontosPorSegundo = 44 × zoom`, com zoom de 0.35 a 5;
- ctrl + scroll no Simulator/Mac também funciona.

**Régua:** o passo muda com o zoom (0.5 s / 1 s / 2 s / 5 s); os rótulos principais saem em `mm:ss` a cada 2 passos.

**Trilha principal:**
- **Clipe:** miniaturas reais (`AVAssetImageGenerator`, geradas de forma assíncrona e em cache por tempo de origem, com a largura de cada miniatura = altura × 9/16) e, embaixo, uma faixa de 14 pt com a **forma de onda** (RMS por 0,1 s do original via Accelerate).
- **Selo** no canto superior esquerdo do clipe, quando houver, com o texto em amarelo: velocidade ("1.5×"), zoom ("Push in") ou "Muted".
- **Duração** do clipe no canto superior direito, quando selecionado.
- **Cover:** bloco de 50 pt à esquerda do início, que abre o painel Cover.
- **"+"** branco depois do fim, que abre Media no modo "Insert as clip".

**Faixas abaixo:** Text (textos + mídia sobreposta), Captions, Music e Voice-over.
- Faixa vazia mostra um atalho tracejado ("+ Add text", "+ Auto captions", "+ Add audio").
- Com painel aberto, a faixa relacionada ao painel sobe para logo abaixo da régua, e a trilha principal encolhe (40 pt). Veja `order` em `vTimeline()`.

**Seleção:**
- tocar num item o seleciona: contorno amarelo de 2 pt, alças amarelas de trim (16 pt no clipe e 12 pt nas faixas, com área de toque de pelo menos 32 pt);
- os outros itens ficam com 50–55% de opacidade;
- a faixa do item selecionado cresce de 28 para 36 pt;
- tocar no vazio tira a seleção.

**Trim pelas alças:**
- balão amarelo no topo com o tempo ou a duração ("00:04.1 · 1.8s");
- na alça esquerda do clipe, o conteúdo acompanha o dedo (compensação `tOff` no protótipo) e se reajusta ao soltar;
- as legendas não podem sobrepor as vizinhas.

**Gestos, por ordem de prioridade:** alça > seleção por toque > scrub > pinça. Um toque é um movimento menor que 4 pt.

**Snapping com háptico** (`UISelectionFeedbackGenerator`): a playhead e as alças encaixam em junções de clipes, no início e no fim de legendas e textos e em keyframes, a menos de 6 pt.

**Undo / Redo** ficam na player bar e estão sempre acessíveis.
- Cada gesto contínuo (arrastar alça, slider, mover texto) gera **uma** entrada no histórico (coalescência de 900 ms, como em `commit(fn, key)`).
- Pilha de 60 níveis.

## Fase 3 — Modelo e sincronização (tempo do original × tempo editado)
- A EDL continua sendo a verdade: `clips: [Clip]` com `id, sourceIn, sourceOut, speed, zoom(.none/.pushIn/.pullOut/.punchIn), zoomAmount, volume, keepPitch, muted`.
- **Textos, legendas e mídia sobreposta são guardados em tempo do original** (`sourceStart / sourceEnd`) e mapeados para o tempo editado. Assim, cortar um trecho leva junto a legenda dele.
  - Implemente `sourceToEdited(t, mode: .forward/.backward)` e `span(start,end) -> ClosedRange?`, como em `derive()`.
  - Uma legenda cujo trecho foi cortado inteiro fica **oculta**, não é apagada: o undo a traz de volta.
- **Música e voice-over** ficam em tempo editado.
- **Split** na playhead divide o clipe; a seleção vai para a parte da direita.
- **Delete** remove o clipe; manter pelo menos 1 clipe é uma invariante.
- **Duplicate** insere uma cópia depois do original.
- **Funções puras com testes:** `split`, `cutRange`, `trim`, `sourceToEdited`, `editedToSource`, `span` e a detecção de pausas.

## Fase 4 — Ferramentas por contexto (toolbar)
**Referência:** `vToolbar()`.

A toolbar tem 64 pt de altura, ícones de 24 pt com traço de 1.7 e rótulo de 11 pt.

- **Com um item selecionado:** a toolbar inteira troca de conteúdo. À esquerda fica o botão "‹" amarelo com o nome do contexto (Clip, Text, Caption, Music, Voice-over, Media), que volta à barra principal.

| Contexto | Itens |
|---|---|
| **Principal** (nada selecionado) | Edit · Text · Captions · Audio · Pauses · Media · Adjust · Filters · Background · Crop |
| **Clip** | Split · Speed · Zoom · Volume · Voice · Duplicate · Delete (vermelho) |
| **Text** | Edit · Style · Keyframe · Duplicate · Delete |
| **Caption** | Edit · Split · Join next · Style · Delete |
| **Music** | Volume · Replace · Delete |
| **Voice-over** | Volume · Re-record · Delete |
| **Media** | Delete |
| **Text** (ferramenta, sem seleção) | Title · Subtitle · Hook · Callout · Style all |
| **Audio** (ferramenta) | Voice · Music · Voice-over |

- **Edit** na barra principal seleciona o clipe sob a playhead.
- **Split** fica esmaecido (mas tocável, com um toast explicando) quando a playhead está fora do clipe.
- **Velocidade e Zoom são ferramentas separadas.** Não junte as duas de novo.

## Fase 5 — Edição direta no preview
- **Tocar num texto** o seleciona:
  - contorno amarelo de 2 pt com 5 pt de afastamento;
  - "×" (excluir) no canto superior esquerdo e ⤡ (escala por arraste) no inferior direito, ambos brancos com 24 pt e área de toque de 44 pt;
  - tocar de novo num texto já selecionado abre o painel Text style.
- **Arrastar um texto** o move.
  - Se o texto tiver keyframes, o arraste cria ou atualiza o keyframe no tempo atual.
  - **Guias de alinhamento:** linha amarela vertical e horizontal ao passar pelo centro (encaixe a menos de 2,5% do frame, com háptico).
  - Mostre a **área segura** tracejada enquanto arrasta (use os mesmos presets de Social Safe Zone da gravação, pela plataforma da take).
- **Arrastar a legenda** muda a posição vertical global das legendas, com encaixe em Top 16% / Middle 50% / Bottom 76%.
- **Tocar no vazio** tira a seleção. Em tela cheia, tocar no vídeo faz play/pause e tocar fora sai.

## Fase 6 — Painéis
Todos os painéis ficam **acima da área do home indicator** e seguem a mesma estrutura:
- **Cabeçalho:**
  - título e subtítulo;
  - o subtítulo diz o **escopo**: "This clip", "Whole take", "Applies to all 8 lines", "Only this title changes";
  - "Reset" quando fizer sentido;
  - botão **✓ amarelo** (40 pt) que **aplica e fecha**.
- **As mudanças aparecem ao vivo no preview.** Não existe botão "Preview".
- **Três ações com lugares diferentes:**
  - ✓ = aplicar o ajuste e fechar o painel;
  - **Done** (topo esquerdo) = concluir a edição, salvar na take e voltar à tela da take;
  - **Export** (topo direito, amarelo) = gerar o arquivo.

  Não misture essas ações.
- **Ajustes essenciais primeiro, detalhes técnicos em "Advanced"**, uma linha recolhível.

**Speed** (clipe):
- segmentado 0.5× · 0.75× · 1× · 1.25× · 1.5× · 2×, com o selecionado em amarelo;
- subtítulo "This clip · 00:21.6 → 00:14.4";
- com um único clipe, botão "Split at playhead to change one part";
- Advanced: slider de 0.25× a 4× em passos de 0.05, e "Keep voice pitch" (`AVAudioTimePitchAlgorithm.spectral` quando ligado).

**Zoom** (clipe):
- 4 cards: None · Push in · Pull out · Punch in;
- escolher um move já toca 2,5 s do clipe para prévia;
- Advanced: Intensity de 0 a 100 (escala máxima 1.3×);
- implemente no export com uma transformação por frame (`AVMutableVideoCompositionLayerInstruction.setTransformRamp`) ou com Core Image.

**Volume:** de 0 a 200%, para clipe, música ou voice-over. No clipe, também "Mute this clip".

**Voice** (take inteira):
- Enhance voice e Reduce noise, cada um com Off / Soft / Strong;
- "Compare with original" alterna o áudio processado e o original durante o play, com o selo "Original audio" no preview;
- investigue o que o SDK oferece para processamento offline de voz (por exemplo o audio unit de isolamento de voz, EQ e dinâmica com `AVAudioEngine` em modo de render manual) e **me reporte antes de implementar**.

**Pauses** (o antigo Clean Up):
- as pausas aparecem **na trilha principal**:
  - marcada para remover: hachurado amarelo e borda amarela;
  - para manter: hachurado cinza e borda tracejada branca;
  - tocar na marcação alterna;
- no painel:
  - "Pauses longer than" com −/+ (0.3 a 3.0 s, padrão 0.7 s);
  - cards horizontais, cada um com duração, tempo, Remove/Keep e **Listen**. Listen toca 1,2 s antes e depois; se a pausa estiver marcada, pula o trecho para o usuário ouvir o resultado;
  - rodapé com o **tempo economizado** em amarelo ("−4.1s"), "00:21.6 → 00:17.5" e o botão "Remove N pauses";
- mantenha 0,12 s de respiro em cada lado da pausa removida e o crossfade de 10 a 20 ms que já existe;
- **use a detecção real** (transcrição com tempo por palavra + RMS) que já existe no app. O protótipo calcula as pausas pelos intervalos entre legendas só para a demo;
- se o Clean Up atual detecta vícios de linguagem ou regravações, **mantenha como uma segunda seção do mesmo painel** ("Filler words", "Retakes"), com o mesmo padrão visual de cards e me avise.

**Captions** (lista):
- linha de controles fixa no topo:
  - toggle de legendas;
  - chip de idioma falado (lista inline: Automatic + idiomas);
  - chip Translate (Off / English / Español / Français… via **Translation framework**, com a nota "Translated on your iPhone with Apple Translation. Nothing is sent anywhere.");
  - botão branco **Style**;
- **Lista de frases com tempos** ("00:05.2 → 00:07.1 · 1.9s"):
  - **tocar numa frase leva a playhead até ela** e a seleciona também na timeline;
  - durante o play, a frase atual fica em amarelo e a lista rola até ela;
- **Frase selecionada:** fica expandida, com:
  - campo de texto com borda amarela;
  - Start −/+ e End −/+ em passos de 0,1 s, que não sobrepõem as vizinhas e movem a playhead para o ponto ajustado;
  - Play · Split · Join next · Excluir;
- "+ Add a line at the playhead" (só num intervalo livre de 0,3 s ou mais);
- a legenda também pode ser ajustada pelas alças na faixa Captions da timeline.

**Auto captions** (quando ainda não há legendas): idioma falado (Auto / Português / English / Español) e o botão amarelo "Generate captions". A geração usa a transcrição que já existe, com tempo por palavra.

**Caption style** (sempre global, com o subtítulo "Applies to all N lines"). Abas:
- **Presets;**
- **Reveal:** Line · Fade · Words · Highlight · Box. Tocar num estilo toca a frase atual como prévia;
- **Position:** Top / Middle / Bottom, e Size de 12 a 28;
- **Font:** família · peso · cor.

**Text style** (painel cheio):
- campo de texto no topo, que recebe foco ao criar o texto;
- **seletor de escopo explícito:** "This title" · "All texts · N" · "+ Captions" (aplica a textos e legendas). O subtítulo repete o efeito ("All 3 texts change together");
- abas:
  - **Presets:** o primeiro card é "Save as my style"; depois vêm My style (se existir) e os 8 presets;
  - **Font:** família em chips (cada chip renderizado na própria fonte); peso (DM Serif Display só tem Regular); tamanho de 12 a 56;
  - **Color:** cor do texto; fundo None / Box / Pill com a cor do fundo; sombra None / Soft / Outline;
  - **Motion:** ◀ / "Add keyframe"/"Remove keyframe" / ▶; Starts e Ends com −/+; nota explicando os keyframes;
- os keyframes aparecem como losangos brancos no item da faixa Text;
- a posição entre keyframes é interpolada linearmente (deixe o easing preparado para o futuro).

**Presets de texto e legenda** (copie `static PRE` exatamente). Todos foram pensados para ter contraste sobre qualquer vídeo, com fundo sólido ou sombra/contorno:

| Preset | Fonte | Peso | Cor | Fundo | Sombra | Caixa-alta | Escala |
|---|---|---|---|---|---|---|---|
| Cue | DM Sans | 800 | preto | caixa `#FFD60A` | — | não | 1.0 |
| Editorial | DM Serif Display | 400 | branco | — | soft | não | 1.12 |
| Bold | Space Grotesk | 700 | branco | — | outline | sim | 1.0 |
| Pop | Space Grotesk | 700 | `#FFD60A` | — | outline | não | 1.05 |
| Soft | DM Sans | 700 | `#111` | pill branca | — | não | 0.9 |
| Minimal | DM Sans | 500 | branco | — | soft | não | 0.85 |
| Label | Space Grotesk | 600 | branco | caixa `rgba(0,0,0,.8)` | — | sim (tracking 0.08 em) | 0.62 |
| Paper | DM Serif Display | 400 | `#111` | caixa `#F4EFE6` | — | não | 1.0 |

- **Soft:** sombra 0 1 2 `rgba(0,0,0,.45)` + 0 2 14 `rgba(0,0,0,.55)`.
- **Outline:** contorno preto de 1,5 pt + sombra de 3 pt para baixo.
- **Valores padrão ao criar:**
  - Title → Cue 26, na altura de 22%;
  - Subtitle → Minimal 18, a 30%;
  - Hook → Pop 30, a 36%;
  - Callout → Label 22, a 56%.

**Cover:**
- "Frame from video" / "Photo";
- faixa de miniaturas com um quadro branco arrastável;
- "Title on the cover", que usa o preset Cue;
- enquanto o painel está aberto, o preview mostra o quadro da capa.

**Adjust** (take inteira):
- botão Auto e Reset;
- Exposure, Contrast e Warmth (de −100 a +100, com o preenchimento saindo do centro);
- Advanced: Saturation, Highlights, Shadows e Sharpness;
- no Core Image: `CIExposureAdjust`, `CIColorControls`, `CITemperatureAndTint`, `CIHighlightShadowAdjust`, `CISharpenLuminance`.

**Filters:** Original · Vivid · Warm · Cool · Mono · Fade, com miniatura real de cada filtro e Intensity.

**Crop:** 9:16 · 4:5 · 1:1 · 16:9 e Fill / Fit. O preview muda de formato na hora.

**Background:**
- Original · Blur · Color · Image;
- a pessoa é segmentada com `VNGeneratePersonSegmentationRequest`, de preferência com qualidade `.balanced` no preview e `.accurate` no export;
- Advanced: **Color key** com Green screen / Blue screen, Tolerance, Edge e Spill (filtro chroma com `CIColorCube`);
- subtítulo "Whole take · your recording stays untouched".

**Media:**
- sheet "Add photo or video" (`PHPickerViewController`) com "On top of video" / "Insert as clip";
- a mídia sobreposta pode ser arrastada no preview, fica na faixa Text e dura 3 s por padrão.

**Music:**
- sheet a partir de Files (`UIDocumentPicker`);
- aviso de direitos: "Use only music you own or have the rights to — songs from Apple Music can't be added.";
- entra a 40% sob a voz.

**Voice-over:**
- painel com um botão de gravar grande (o círculo vira quadrado ao gravar);
- grava a partir da playhead com o vídeo tocando **sem som**;
- a faixa cresce em vermelho durante a gravação e vira um item laranja ao parar;
- "Re-record" apaga o item e volta a playhead para o início dele.

## Fase 7 — Export, Done e tela da take
- **Export** abre uma sheet com:
  - miniatura, duração e formato, e a nota "captions and text burned in";
  - Resolution 720p / 1080p / 4K e Frame rate 30 / 60;
  - tamanho estimado;
  - o contador de exportações grátis, seguindo as regras de negócio que já existem (5 grátis, depois paywall; nada de marca d'água);
  - botão "Export video".

  Durante o processo, mostre progresso real e "Exporting · keep Cue open". No fim: "Saved to Photos", com Share e Done.
- **Pipeline:**
  - uma `AVMutableComposition` a partir da EDL;
  - uma `AVVideoComposition` com Core Image para adjust, filtro, background, chroma, crop e zoom;
  - textos e legendas renderizados na **mesma** função de desenho usada no preview (Core Graphics/Core Text para `CIImage`, ou `AVVideoCompositionCoreAnimationTool`), para garantir o mesmo resultado;
  - um `AVAudioMix` para volumes, música, voice-over e crossfades.
- **Done:** salva a EDL e os estilos na take, volta à tela da take e mostra o toast "Edits saved to this take". Voltar em Edit reabre exatamente o mesmo estado.
- Mantenha o autosave e o rascunho que já existem. A estrutura persistida agora inclui: `texts`, `captions` (texto, tempos e `edited`), `captionStyle`, `voice`, `music`, `voiceOvers`, `media`, `adjust`, `filter`, `crop`, `background`, `cover`, `pauseThreshold` e `myStyle`.

## Fase 8 — Acabamento
- **Toast** no topo do preview: pílula `#2C2C2E` com uma pequena estrela amarela, 2 s de duração, uma linha só.
  - Use para confirmar ações e explicar bloqueios ("Move the playhead inside the clip", "A video needs at least one clip").
  - **Não use texto de ajuda fixo** embaixo dos controles; só as notas curtas que o protótipo tem.
- **Alvos de toque:** pelo menos 44 pt em tudo que é tocável. Isso inclui as alças (via área de toque estendida), os chips e os segmentados.
- **Hápticos:** seleção (`.selection`), snap (`.selection`), aplicar ✓ (`.light`), apagar (`.rigid`), início e fim da gravação do voice-over (`.medium`).
- **Animações:** painel entrando de baixo (220 ms, ease), troca de toolbar com crossfade de 150 ms e **Reduce Motion** respeitado.
- **VoiceOver:**
  - rótulos em todos os ícones;
  - a timeline expõe o clipe atual e o tempo ("Clip 2 of 3, 4.2 seconds, playhead at 00:07.1");
  - `accessibilityAdjustableAction` para mover a playhead de 0,1 s em 0,1 s.
- **Teclado de hardware / Simulator:** espaço = play/pause, ⌘Z = undo, ⇧⌘Z = redo.

## Ordem de implementação
1. `EditorLayout` + esqueleto da tela (Fase 1), testado nos 3 tamanhos
2. Timeline com playhead central, rolagem, pinça e miniaturas
3. Seleção + toolbar por contexto
4. Trim pelas alças, Split, Delete, Duplicate, Undo/Redo
5. Modelo em tempo do original e mapeamento (Fase 3)
6. Pauses
7. Captions (lista, edição, tempos, alças) e Caption style
8. Text (criação, edição direta no preview, guias, estilos, escopo, keyframes)
9. Speed, Zoom, Volume, Voice
10. Adjust, Filters, Crop, Background/Color key, Cover, Media, Music, Voice-over
11. Export + Done + acabamento

## Testes obrigatórios
- **Unitários:**
  - `EditorLayout` (SE, 16 e Pro Max, com e sem cada tipo de painel; o preview nunca fica abaixo do mínimo);
  - `split` / `cutRange` / `trim` / `sourceToEdited` / `span`;
  - detecção de pausas e cálculo do tempo economizado;
  - split e join de legendas;
  - limites de start/end entre legendas vizinhas;
  - interpolação de keyframes;
  - escopo do estilo (um texto / todos / + legendas);
  - coalescência do undo.
- **As quatro tarefas-alvo**, em teste de UI no iPhone SE e no 16 Pro:
  1. cortar "não, pera" com Split + Delete, e também pelas alças;
  2. remover 3 de 4 pausas ouvindo uma antes;
  3. corrigir "caudo" → "caldo" e ajustar o fim da frase em +0,2 s;
  4. aplicar o preset Editorial só no título e depois em todos os textos.
- **Export:** o arquivo final corresponde exatamente ao preview (duração, cortes, posição e estilo dos textos, legendas, áudio). Trechos cortados não aparecem. Faça um teste comparando quadros-chave.
- **Casos-limite:**
  - take de 1 s e de 5 min;
  - apagar todas as legendas;
  - cortar o trecho de um texto com keyframes;
  - zoom máximo e mínimo;
  - rotação;
  - ir para segundo plano durante o export;
  - Dynamic Type no máximo.

## Entrega final
- Resumo por fase com arquivos principais e pendências.
- Capturas das 4 tarefas nos 3 tamanhos de tela.
- Lista de tudo que ficou diferente do protótipo e por quê (principalmente limitações de API em Voice, Background e Translation).
