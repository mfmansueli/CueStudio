# Referências para o editor (Quick edit): VideoLab, MTTransitions/GL Transitions, MetalPetal, Cabbage, VideoEditorKit

Pesquisa feita em 16/10/2026, só leitura. Cada repositório foi clonado (`git clone --depth 1`) numa pasta temporária fora do projeto e lido
ali; os metadados (datas, issues, tags) vieram da API pública do GitHub (`api.github.com`, sem autenticação). Nada foi compilado nem
executado. Onde algo não pôde ser verificado, o texto diz.

## 0. Resumo executivo

- **Nenhum dos cinco deve virar dependência do Cue.** O `CueVideoCompositor` já faz o que esses frameworks oferecem de estrutural
  (composição com instruções por intervalo, segunda trilha para o outro lado do corte, Core Image por quadro, camadas com keyframes,
  prévia = exportação). Trocar ou somar um motor de renderização (Metal próprio, MetalPetal) não mostra vantagem concreta medida, e todos,
  menos o VideoEditorKit, estão parados desde 2022–2024, em Swift 5 sem anotações de concorrência.
- **O que vale a pena é a matemática de 6–8 transições do GL Transitions** (MIT, autor por arquivo), reescrita à mão em Core Image: a maioria
  sai só com filtros nativos (`CIZoomBlur`, `CIBoxBlur`, `CILinearGradient` + `CIBlendWithMask`, transformações afins); só o glitch e, se
  quiser fidelidade, o zoom blur pedem um `CIKernel` em Metal. Cada uma entra como um `case` novo em `EditTransition` e uma função
  `(outgoing, incoming, progress) -> CIImage` no compositor, exatamente onde `slide` e `blend` já estão.
- **Ideias a estudar (sem copiar código):** reuso de trilhas de vídeo para não estourar o limite de decodificadores (VideoLab), "camada de
  ajuste" que aplica efeito ao que está abaixo (VideoLab), fatiamento de instruções por interseção de intervalos (Cabbage, VideoLab), cuidado
  com espaço de cor na exportação (issue #84 do Cabbage), snapshot de edição `Codable` com versão de esquema e mapeamento de tempo
  fonte↔linha do tempo sob velocidade (VideoEditorKit), margens seguras por rede social (VideoEditorKit, números a conferir).

## 1. O que importa no Cue para julgar as referências

Lido no worktree (sem editar): `Cue Studio/Models/EditTransition.swift`, `Cue Studio/Models/TransitionWindow.swift`,
`Cue Studio/Managers/Editing/CueVideoCompositor.swift`.

- `EditTransition` hoje: `hardCut`, `dissolve` (0,5 s), `fade` (0,6 s, mergulho no preto com som), `slide` (0,4 s). O comentário do tipo já
  prevê "um novo jeito de suavizar um corte é um novo `case` aqui e um novo ramo lá".
- `CueVideoCompositor.composedImage(...)` recebe o quadro principal e o do outro lado do corte (`blending other`), decide quem é
  `outgoing`/`incoming` pelo instante do corte e chama `slide(_:over:amount:)` ou `blend(_:into:amount:)` (`CIFilter.dissolveTransition()`).
  Ou seja: **o ponto de extensão para transições novas já existe**, com as duas imagens já "enquadradas" (Adjust, filtros, pele, recorte).
- Buffers em `kCVPixelFormatType_32BGRA`, `CIContext(options: [.cacheIntermediates: false])`.
- Regras do projeto relevantes: nada pago nem em nuvem; dependência só atrás de protocolo; preferir frameworks da Apple; só outra
  infraestrutura de renderização com vantagem concreta; registrar origem, versão e licença; `THIRD_PARTY_NOTICES.md` já existe na raiz
  e há uma tela `Cue Studio/Screens/Settings/Acknowledgements/AcknowledgementsView.swift` (lugar natural para atribuições dentro do app).

## 2. VideoLab (ruanjx/VideoLab)

- URL: https://github.com/ruanjx/VideoLab — branch padrão `develop`.
- Último commit: `d2651f4092a6eb343a799282def92c36c217958f`, 31/10/2022 ("feat:update detail.md"; os últimos commits são só de README).
  Única tag: `0.0.1` (`904fe4e`). 921 estrelas, 21 issues abertas. Não arquivado, mas **sem manutenção desde 2022**.
- **Licença:** MIT (`LICENSE`, "Copyright (c) 2020 Chocolate"). Uso comercial e redistribuição permitidos com o aviso de copyright e a
  licença. Repositório público e realmente open source (não é SDK pago).
- **Ressalva de proveniência (importante):** a pasta `VideoLab/Render/Base/` (`MetalRenderingDevice.swift`, `MetalRendering.swift`,
  `ShaderUniformSettings.swift`, `Texture.swift`, `Color.swift`, `Position.swift`, `Size.swift`) tem os mesmos nomes de tipos, funções
  (`generateRenderPipelineState`, `renderQuad`, `standardImageVertices`, `uniformLookupTable`) e até as mesmas mensagens de `fatalError`
  do **GPUImage3** de Brad Larson (https://github.com/BradLarson/GPUImage3, licença **BSD-3-Clause**, "Copyright (c) 2018, Brad Larson and
  Janie Clayton"), mas os cabeçalhos dizem "Copyright © 2020 Chocolate" e o GPUImage3 só aparece como "material recomendado" em
  `Document/README-DETAIL-EN.md`. Comparei com o GPUImage3 em `84466fc` (18/02/2024). Não dá para afirmar cópia literal (os arquivos foram
  alterados), mas é derivação evidente: **copiar qualquer coisa de `Render/Base` exigiria também o aviso BSD-3 do GPUImage3.**
- **Plataforma e Swift:** só CocoaPods (`VideoLab.podspec`, iOS 11, `swift_version = "5"`); **não tem `Package.swift`**, então não entra por SPM
  sem fork. Usa APIs síncronas de `AVAsset` descontinuadas (28 ocorrências de `tracks(withMediaType:)`, `.duration`, `naturalSize` etc.;
  nenhuma `load(...)`). Sem `Sendable`, singletons globais mutáveis (`sharedMetalRenderingDevice`): não compila em modo Swift 6 sem trabalho.
- **Dependências:** nenhuma externa (Metal, AVFoundation). Recurso `VideoLab.bundle/BlankVideo.mov` (2 KB).
- **Impacto estimado (não medido):** pequeno em binário (~3,4 mil linhas Swift/Metal), mas é um **segundo motor de renderização** (contexto
  Metal, cache de texturas próprio, conversão YUV→RGB própria) ao lado do Core Image do Cue: mais memória de GPU e trabalho por quadro.
  Issues abertas relatam memória crescendo (#24 "内存暴涨", #19 "200 MB não liberados"), travamento ao exportar fotos (#27), tremor em
  zoom (#26), sem HDR (#16).
- **O que estudar:**
  - `Document/README-DETAIL-EN.md` §AVComposition: **reuso de trilhas de vídeo** — uma camada nova reaproveita a trilha cuja última camada
    não se sobrepõe no tempo; só cria trilha nova se nenhuma servir, porque cada trilha é um decodificador e o sistema tem limite. Útil para o
    Cue à medida que os B-rolls sobrepostos crescem.
  - §AVVideoComposition: **uma instrução por intervalo entre bordas de camadas** (T1…T6) e composição de baixo para cima por `layerLevel`;
    uma camada **só de efeitos** (sem fonte) é aplicada sobre o resultado acumulado — o conceito de "camada de ajuste" do After Effects.
  - Imagens paradas viram trilha de um vídeo preto mínimo (`BlankVideo.mov`) para o compositor ser chamado naquele trecho.
  - `KeyframeAnimation.swift` (keyframes por `keyPath` com uma função de tempo por segmento) e `TimingFunction.swift` (curvas de Penner:
    quad, cubic, quart, quint, sine, circ, expo, elastic, back, bounce). O Cue já tem keyframes; as curvas `back`/`elastic` podem inspirar o
    "pop" dos presets de movimento (a matemática de Penner é de domínio comum; reescrever, não copiar).
  - `Text/TextOpacityAnimationLayer.swift`: animação por letra com `CATextLayer` + `AVSynchronizedLayer` (prévia) e
    `AVVideoCompositionCoreAnimationTool` (exportação). **Não recomendo para o Cue**: são dois caminhos diferentes para prévia e exportação,
    o oposto da regra "prévia = exportação" que o Cue já cumpre com textos pré-renderizados em `CIImage`.
- **Recomendação: estudar só.** Motivo: sem SPM, sem manutenção, Swift 5, segundo motor sem vantagem medida, e a pasta de renderização tem
  proveniência BSD-3 não declarada. Nenhum arquivo a adaptar.

## 3. MTTransitions (alexiscn/MTTransitions) e GL Transitions

### 3.1 MTTransitions

- URL: https://github.com/alexiscn/MTTransitions — último commit `66531b19368f8cd49d55e892db6f273d3fea4205`, 12/12/2024 ("Add
  MTLissajousTilesTransition"). Última tag `1.6.6` = commit `3860c7b`, 31/08/2022 (os commits de dezembro de 2024 **não estão em
  nenhuma versão**). 258 estrelas, 16 issues abertas; um PR aberto (#39, macOS/tvOS, 29/05/2026).
- **Licença da biblioteca:** MIT (`LICENSE`, "Copyright (c) 2019" sem nome; o podspec atribui a `alexiscn`). Uso comercial e redistribuição
  permitidos.
- **Licença por shader:** os 85 `.metal` em `Source/Transitions/` são portes do GL Transitions e mantêm o cabeçalho `// License:` /
  `// Author:` do original. Exceções que **não são MIT**:
  - `MTInvertedPageCurlTransition.metal` — **BSD-3-Clause**, © 2010 Hewlett-Packard Development Company (adaptado por Sergey Kosarevsky).
  - `MTStereoViewerTransition.metal` — **BSD-2-Clause**, © 2016 Theodore K Schundler.
  - `MTFadeInWipeLeftTransition.metal` e `MTFadeInWipeUpTransition.metal` — **sem cabeçalho de licença** ("Created by Nazmul on
    04/08/2022"); por padrão cairiam na MIT do repositório, mas o autor não declarou.
  - As imagens de `Source/Assets.bundle` (584 KB: `displacementMap.jpg`, `spiral-*.png`, `conical-*.png`…) usadas pelas transições de luma e
    deslocamento **não têm origem nem licença declaradas** (não verificado; vieram do GL Transitions, cuja licença também não fala de imagens).
- **Dependências:** **MetalPetal** (`from: "1.24.0"`, SPM) — e por ela, Objective-C/C++14. Os shaders incluem `MTIShaderLib.h` do
  MetalPetal: não são reaproveitáveis fora dele sem reescrever.
- **Swift/iOS:** `swift-tools-version:5.1`, `swiftLanguageVersions: [.v5]`, iOS 11. Sem `Sendable`; `public static let context` global.
- **Qualidade técnica e controle de duração (lido no código):**
  - `MTVideoTransition.merge(_:effects:transitionDuration:)`: **uma única duração para todas as junções**; corta a duração para no máximo
    metade do clipe mais curto; `frameDuration` fixo em **30 fps** (`CMTimeMake(value: 1, timescale: 30)`); exige vídeos da mesma resolução.
  - `MTVideoCompositor.startRequest`: se o `cast` da instrução falha, faz `return` **sem terminar o pedido** (o AVFoundation fica esperando);
    `shouldCancelAllRequests` é lido e escrito em filas diferentes sem sincronização; erros de renderização engolidos (`try?` em
    `MTVideoTransitionRenderer`). Buffers só BGRA 8 bits.
  - O progresso entra linear; cada shader faz sua própria curva. Duração padrão de 1,2 s (UIView) e 2 s no exemplo de vídeo — longo para
    vídeo de criador falando para a câmera.
  - Issues abertas: vazamento de memória em `MTVideoTransition` (#33), "Source frame missing" na exportação (#8), orientação (#5, #6),
    nitidez baixa (#18), filtros do MetalPetal não funcionando junto com transição (#30).
- **Impacto estimado (não medido):** MetalPetal inteiro + um `default.metallib` com 85 shaders + 584 KB de imagens; um segundo contexto Metal
  só para transições, com conversão CIImage↔MTIImage a cada quadro de transição.
- **Recomendação: rejeitar como dependência; estudar a lista e reescrever a partir do GL Transitions original** (não dos portes `.metal`, que
  são derivados e acoplados ao MetalPetal). Atribuição: a do autor de cada transição (abaixo) e a MIT do GL Transitions; nada do
  MTTransitions precisa viajar se nenhum arquivo dele for copiado.

### 3.2 GL Transitions (fonte original)

- URL: https://github.com/gl-transitions/gl-transitions — ativo: último commit `c06c4905958446b7da2d121b12942495e18c99c0`, 15/10/2026
  (merge do PR #298). 2.152 estrelas.
- **Licença:** `LICENSE` MIT, "Copyright (c) 2017-present gl-transitions contributors", com a nota: *"Individual transitions in the
  transitions/ directory may have their own license specified in their file header comments. When no license is specified, the transition
  is covered by this MIT license."* (por isso o GitHub mostra `NOASSERTION`).
- Contagem nos 125 `.glsl` atuais: 124 declaram MIT (123 `// License: MIT` + 1 `// License : MIT`), 1 BSD-3 (`InvertedPageCurl.glsl`,
  Hewlett-Packard) e 1 BSD-2 (`StereoViewer.glsl`, Ted Schundler).
- Convenções: `uv` em [0,1]² com origem embaixo à esquerda (igual ao Core Image), `progress` em [0,1], `ratio` = largura/altura,
  `getFromColor(uv)` = quadro que sai (A), `getToColor(uv)` = quadro que entra (B).

### 3.3 Subconjunto recomendado para vídeo de criador falando para a câmera

Critério (julgamento editorial meu, não medido em usuário): transições curtas, que não "brincam" com o rosto, que funcionam em 9:16, com
leitura clara num corte de fala; nada de coração, folha, caleidoscópio, cubo, virada de página ou "Doom". Todas MIT.

| Nome sugerido no Cue | Arquivo GL Transitions | Autor (cabeçalho) | Licença | Duração sugerida | Precisa de CIKernel? |
|---|---|---|---|---|---|
| Zoom (zoom blur) | `CrossZoom.glsl` | rectalogic (portado por gre; baseado em glfx.js de Evan Wallace, MIT) | MIT | 0,3–0,45 s | Não para aproximação (`CIZoomBlur`); sim para fidelidade |
| Desfoque | `LinearBlur.glsl` | gre | MIT | 0,4–0,6 s | Não (`CIBoxBlur`/`CIGaussianBlur` + dissolve) |
| Clarão | `Overexposure.glsl` | Ben Zhang | MIT | 0,25–0,4 s | Não (`CIColorKernel` simples, ou matriz de cor + soma) |
| Empurrar (push) | `Directional.glsl` + curva de `directional-easing.glsl` | Gaëtan Renaudeau; Max Plotnikov | MIT | 0,3–0,4 s | Não (translações afins; o `slide` atual já é quase isso) |
| Soco (zoom in-out) | `zoomInOut.glsl` (ou `SimpleZoom.glsl`) | OllyOllyOlly (ou 0gust1) | MIT | 0,3–0,4 s | Não (escala afim + dissolve) |
| Cortina suave | `directionalwipe.glsl` | gre | MIT | 0,4–0,5 s | Não (`CILinearGradient` + `CIBlendWithMask`) |
| Glitch | `GlitchMemories.glsl` | Gunnar Roth ("based on work from natewave", origem não verificada) | MIT | 0,25–0,35 s | Sim (deslocamento por canal) ou 3 passes nativos |
| (opcional) Íris | `circleopen.glsl` | gre | MIT | 0,4–0,5 s | Não (`CIRadialGradient` + `CIBlendWithMask`) |
| (opcional) Mergulho em cor | `fadecolor.glsl` | gre | MIT | 0,5–0,6 s | Não (o `fade` atual; acrescenta cor e "fase" ajustável) |

"gre" é o apelido de Gaëtan Renaudeau, criador do GL Transitions. Observação: `zoomInOut.glsl` não existe no MTTransitions (é mais novo).

### 3.4 A matemática de cada uma (para reescrever em Core Image, sem copiar o GLSL)

Notação: `p` = progresso 0→1; `A` = quadro que sai, `B` = quadro que entra; `uv` = coordenada normalizada; `mix(x, y, t) = x·(1−t) + y·t`;
`smoothstep(a, b, x)` = Hermite 3t²−2t³ com t = clamp((x−a)/(b−a)). Em Core Image, trabalhar em pixels (`destCoord()`), com o centro e as
distâncias convertidos da `extent`. Para `CIKernel` com `sampler`, o ROI precisa cobrir de onde se lê (no zoom e no push, a `extent` inteira
das entradas; nos desfoques, a `extent` dilatada pelo raio).

1. **Zoom (CrossZoom).**
   - Centro do zoom anda na horizontal pela metade central: `c(p) = (0,25 + 0,5·p, 0,5)`.
   - Troca A→B concentrada no meio: `d(p)` = *exponential ease-in-out* de 0 a 1 (curva 2^(10(t−1)) na primeira metade, espelhada na
     segunda).
   - Força do desfoque sobe e desce: `s(p) = S·(1 − cos 2πp)/2`, com `S ≈ 0,4` — zero nas pontas, máxima em p = 0,5.
   - Para cada pixel, 41 amostras na reta de `uv` até `c`: posição `uv + (c − uv)·q·s`, com `q = (k + r)/40`, k = 0…40, e `r` um ruído
     por pixel em [0,1) (hash `fract(sin(dot(uv, (12,9898; 78,233)))·43758,5453)`) para disfarçar o número fixo de amostras; peso
     parabólico `w = 4q(1−q)`; cor = Σ w·mix(A, B, d) / Σ w.
   - Em Core Image sem kernel: `CIZoomBlur` (centro `c` em pixels, `inputAmount` ∝ `s`) aplicado a A e a B, depois `CIDissolveTransition`
     com `d`. Fica muito próximo; o original desfoca a mistura, não cada lado, diferença invisível em 0,4 s. Para 9:16, considerar manter o
     centro fixo no meio (mover o centro na horizontal faz sentido em 16:9).
2. **Desfoque (LinearBlur).**
   - Deslocamento em triângulo: `disp = I·(0,5 − |0,5 − p|)`, `I ≈ 0,1` (pico I/2 no meio).
   - Média de uma grade 6×6 de amostras em `uv + disp·v`, com `v` de −0,5 a +0,333 em cada eixo (a grade é levemente assimétrica: desloca a
     imagem em −disp/12; numa reescrita, centrar a grade), feita para A e para B; depois `mix(A_desf, B_desf, p)` linear.
   - Em Core Image: `CIBoxBlur` ou `CIGaussianBlur` com raio ∝ `disp × largura` em A e B (`clampedToExtent()` antes, `cropped(to:)` depois,
     para não escurecer as bordas) + dissolve.
3. **Clarão (Overexposure).**
   - Pesos: `mA = 1 − p + S·sin(πp)`, `mB = p + S·sin(πp)`, `S ≈ 0,6`; saída = A·mA + B·mB (com alfa multiplicado; vídeo é opaco).
   - No meio cada peso vale ~1,1 e a soma ~2,2: os claros estouram no branco e voltam — o "flash".
   - Em Core Image: um `CIColorKernel` de uma linha, ou `CIColorMatrix` escalando A e B + `CIAdditionCompositing`. Cuidado: o espaço de
     trabalho padrão do Core Image é **linear**, então o mesmo `S` fica mais agressivo do que no GLSL (que roda em sRGB); ajustar `S` na
     prévia ou fazer a soma em espaço perceptual. Limitar a saída a [0,1] se o buffer de saída for SDR.
4. **Empurrar (Directional + directional-easing).**
   - Direção `dir` com componentes em {−1, 0, 1}; `q = uv + e(p)·dir`; se `q` está dentro de [0,1]² mostra `A(q)`, senão mostra
     `B(fract(q))` — a imagem inteira anda, A sai por um lado e B entra colada a ela pelo outro (empurra; não sobrepõe).
   - Curva: `e(p) = √((2 − p)·p)` (= √(1 − (1 − p)²), *circular ease-out*: começa rápido e assenta).
   - Em Core Image: A transladado por `−e·W·dir`, B transladado por `(1 − e)·W·dir`, os dois recortados à `extent` e compostos. Ideia própria
     possível (não está no GLSL): `CIMotionBlur` na direção do movimento com raio proporcional à velocidade `e′(p)` vira um "whip pan".
5. **Soco (zoomInOut / SimpleZoom).**
   - `zoom(uv, a) = 0,5 + (uv − 0,5)·(1 − a)` → aproximação 1/(1 − a) em torno do centro.
   - zoomInOut: `aA = smoothstep(0, 1, 2p)` (A aproxima na primeira metade), `aB = smoothstep(0, 1, 2(1 − p))` (B afasta na segunda),
     troca `smoothstep(0,4; 0,6; p)`; saída `mix(A(zoom(uv, aA)), B(zoom(uv, aB)), troca)`. No original `a` chega a 1 (aproximação infinita,
     "vira uma cor"); para rosto, **limitar `a` a ~0,3–0,4** (1,4×–1,7×), senão aparece pixel.
   - SimpleZoom: A aproxima com `a = smoothstep(0, Q, p)` (Q ≈ 0,8) e mistura com B parado por `smoothstep(Q − 0,2; 1; p)`.
   - Em Core Image: a função `zoomed(_:by:)` que o compositor já tem + `blend`.
6. **Cortina suave (directionalwipe).**
   - `v = dir` normalizado e depois dividido por |vx| + |vy|; `d = v·(0,5; 0,5)`;
     máscara `m = 1 − smoothstep(−s, 0, v·uv − (d − 0,5 + p·(1 + s)))`, zerada em p = 0; saída `mix(A, B, m)`.
   - É uma faixa de gradiente de largura `s` (≈ 0,5) atravessando a tela na direção `dir` (padrão diagonal (1, −1)).
   - Em Core Image: `CILinearGradient` (branco→preto ao longo de `s`, posição pela fórmula) como máscara de `CIBlendWithMask(B, A)`.
7. **Glitch (GlitchMemories).**
   - Ruído que muda em degraus com o progresso: `n = floor(p·(1200, 3500))/64`; deslocamento `δ = (fract(n) − 0,5)·0,3·(1 − p)` (some no
     fim). Cada canal lê de um lugar: R em `uv + 0,2δ`, G em `uv + 0,3δ`, B em `uv + 0,5δ`; cada canal é `mix(A, B, p)` naquele ponto.
   - Detalhe verificado no código: o termo `floor(p.xy / 16)` (blocos) usa `uv` normalizado, então dá sempre 0 — **não há blocos de
     verdade**: é uma separação RGB do quadro inteiro que treme e diminui. Se quiser blocos, calcular em pixels (ideia própria).
   - É determinístico (só depende de `p`), o que preserva prévia = exportação. Em Core Image: `CIKernel` com `sampler` (três leituras), ou
     três passes nativos (`CIColorMatrix` isolando cada canal + translação + `CIAdditionCompositing`).
8. **Íris (circleopen)**, opcional: `m = smoothstep(−s, 0, √2·dist(centro, uv) − p·(1 + s))`, saída `mix(A, B, 1 − m)`. Como a distância é
   em `uv` normalizado, em 9:16 vira **elipse vertical**; para círculo, corrigir pela razão. Core Image: `CIRadialGradient` + `CIBlendWithMask`.
9. **Mergulho em cor (fadecolor)**, opcional: A some para a cor em `smoothstep(1 − f, 0, p)` e B aparece da cor em `smoothstep(f, 1, p)`,
   misturados por `p`; `f` (≈ 0,4) é quanto tempo a cor fica sozinha no meio. Generaliza o `fade` atual (preto) para branco ou cor da marca.

Sobre escrever kernels em Metal para Core Image: a Apple oferece kernels Core Image em Metal compilados no `default.metallib` do app
(funções `[[stitchable]]` com `#include <CoreImage/CoreImage.h>`, ou o caminho antigo com `-fcikernel`/`-cikernel`). **Não conferi qual
variante e quais flags o Xcode 27/iOS 27 exige**; ao implementar, confirmar na documentação da Apple e pôr qualquer flag em
`Config/App.xcconfig`, nunca no `project.pbxproj`. O Cue não tem nenhum `.metal` hoje.

## 4. MetalPetal (MetalPetal/MetalPetal)

- URL: https://github.com/MetalPetal/MetalPetal — último commit e última versão: `1.25.2` = `f9b78897bd4214bb097f352a1bde0a4f4a1e2ddb`,
  21/02/2023 ("Add autoreleasepool in MTIAsyncVideoCompositionRequestHandler"). Último PR aceito: #339, 03/11/2022. 2.193 estrelas, 43
  issues abertas. O `MetalPetal.podspec.json` ainda diz `1.23.0`.
- **Manutenção: dormente.** Issue #395 (06/2025) e #400 (15/08/2026, "Fork and continued development"): o autor (YuAo) sumiu em abril de
  2023 segundo a comunidade; existe o fork https://github.com/eerimoq/MetalPetal (MIT, último commit `d52ee140e2`, 08/08/2026, 5 estrelas,
  "Swift only", feito "com o Claude", sem garantias). Issue #391: exportação falhando com `-12780` em vídeos do iPhone 16 Pro no iOS 18
  (via `VideoIO`); #376: `enablesRenderGraphOptimization` trava; #382: sem Privacy Manifest.
- **Licença:** biblioteca **MIT** (`LICENSE`, "Copyright (c) 2017 Yu Ao"). **Exceção:** a pasta `MetalPetalExamples/` tem
  `MetalPetalExamples/LICENSE.md` própria: *"Files in this directory (/MetalPetalExamples) are for non-commercial testing and evaluation
  purposes only. We reserves all rights not expressly granted."* — **nada dos exemplos pode ser copiado para um app comercial.** A
  documentação é CC-BY-4.0 (README).
- **Swift/iOS:** núcleo em Objective-C/C++14 (`MetalPetalObjectiveC`) com camada Swift; `swift-tools-version:5.1`; iOS 11. ~28 mil linhas
  (ObjC/C++/Metal/Swift) em `Frameworks/MetalPetal`. Concorrência: o README diz que `MTIImage` é imutável e `MTIContext` é seguro entre
  threads, `MTIFilter` não; nada disso está anotado para Swift 6 (precisaria de `@preconcurrency import` e caixas `@unchecked Sendable`).
- **Dependências:** nenhuma externa; usa MetalPerformanceShaders (indisponível no Simulador: desfoque gaussiano MPS e CLAHE não rodam lá —
  o Cue testa muito no Simulador). Para exportar vídeo, o README usa o `VideoIO` (https://github.com/MetalPetal/VideoIO, MIT, último commit
  `1623b3d597` de 12/03/2022).
- **Vantagem sobre Core Image para o Cue?** O README lista: vertex/fragment customizáveis, MRT (vários alvos de render) e "Generally better
  performance. (**Detailed benchmark data needed**)" — o próprio projeto não tem números. Para o Cue: as transições e efeitos do quadro
  cabem em kernels de fragmento do Core Image; o Cue não precisa de geometria própria nem de MRT; o Core Image já concatena filtros e
  gerencia intermediários; Vision (segmentação, rosto) já entrega `CVPixelBuffer`/`CIImage`. Os filtros prontos do MetalPetal que o Cue
  poderia querer (pele por high-pass, CLAHE, bokeh hexagonal, desfoque de superfície) são do mesmo autor e o Cue já avaliou e não adotou o
  de pele (`THIRD_PARTY_NOTICES.md`). **Nenhuma vantagem concreta demonstrada** que justifique um segundo motor, e há custo: dois contextos
  de GPU, conversões CIImage↔MTIImage, mais memória e energia por quadro (estimativa, não medida), e um framework sem manutenção.
- **Impacto estimado (não medido):** algo como 1,5–3 MB de binário + metallib; uma `MTIContext` com caches próprios de textura e pipeline.
- **O que estudar:** a seção "Optimizations" do README (calcular o número mínimo de texturas intermediárias do grafo e concatenar
  "receitas" para eliminar passes) como checklist de desempenho do próprio compositor do Cue; `MTIAsyncVideoCompositionRequestHandler`
  (o `autoreleasepool` por pedido, motivo do último commit) — o Cue deve conferir que tem o mesmo.
- **Recomendação: rejeitar como dependência; estudar só (README).** Não copiar nada de `MetalPetalExamples/`.

## 5. Cabbage (VideoFlint/Cabbage)

- URL: https://github.com/VideoFlint/Cabbage — último commit `41c78700c32b3814eaa242a3b4fe9323e14d63fc`, 21/03/2022 ("HDR support demo").
  Última tag `0.5.1` (`c8f72a0`). 1.579 estrelas, 47 issues abertas. PR aberto #92 "Fix audio bug ios 26" (01/09/2025), sem descrição e
  sem merge. **Sem manutenção.**
- **Licença:** MIT (`LICENSE`, "Copyright © 2018 Vito Zhang"). Uso comercial e redistribuição permitidos. Sem exceções por arquivo
  encontradas.
- **Swift/iOS:** `Package.swift` com `swift-tools-version:5.3` (sem `platforms`), podspec `swift_version = "4.2"`. Código duplicado: os
  fontes reais estão em `Cabbage/Sources/` (~3,8 mil linhas) e `Sources/Cabbage/` são links simbólicos para eles. 77 usos de APIs síncronas
  descontinuadas de `AVAsset`; `public static var ciContext` global mutável; `objc_setAssociatedObject` para guardar o tap de áudio; chaves
  `kCVPixelBufferOpenGLESCompatibilityKey`. Não passa em Swift 6 estrito sem reescrita.
- **Dependências:** nenhuma (AVFoundation, Core Image).
- **Pontos de atenção encontrados:** #84 "Exported video appears to be darker (colour shifting)" — o compositor renderiza com
  `CIContext()` padrão direto num buffer BGRA sem tratar espaço de cor; #91 crash `EXC_BAD_ACCESS` em `ciContext.render` (iOS 18.4.1);
  #34 áudio + transição deixa a prévia preta; `VideoCompositor.newRenderedPixelBufferForRequest` lê `renderContext` fora da fila que o
  escreve.
- **O que estudar:**
  - É o mais parecido com o Cue (AVFoundation + **Core Image** + compositor próprio): `Core/Model/VideoTransition.swift` (protocolo
    `renderImage(foregroundImage:backgroundImage:forTweenFactor:renderSize:)` — mesma forma que as funções `slide`/`blend` do Cue),
    `Core/CompositionGenerator.swift` (`calculateSlices`: fatia as instruções em intervalos por interseção; trilhas alternadas ×1000/×2000
    para os dois lados da transição), `Core/Model/AudioTransition.swift` (rampas de volume no `AVAudioMix` na sobreposição).
  - `Core/Audio/AudioProcessingTapHolder.swift`: `MTAudioProcessingTap` no `AVAudioMix` processa áudio **em tempo real na prévia**. O Cue
    renderiza a voz offline com `AVAudioEngine`; um tap só valeria se o Cue quisesse ouvir um ajuste de áudio na hora, antes de renderizar.
  - `Track/Resource/AVAssetReverseImageResource.swift`: vídeo ao contrário lendo com `AVAssetReader` (caso o Cue queira "reverso").
  - `Core/Video/HDRVideoCompositor.swift`: só troca os buffers para `420YpCbCr10BiPlanarFullRange` e liga `supportsHDRSourceFrames` /
    `supportsWideColorSourceFrames`. Lembrete útil: o Cue grava em HEVC no iPhone (possivelmente HDR/10 bits) e o compositor pede BGRA 8
    bits — conferir se a cor da exportação bate com a da gravação (é exatamente o defeito da #84).
- **Recomendação: estudar só.** Nenhum arquivo precisa ser adaptado; as ideias acima são padrões de AVFoundation documentados pela própria
  Apple (amostra AVCustomEdit).

## 6. VideoEditorKit (didisouzacosta/VideoEditorKit)

- URL: https://github.com/didisouzacosta/VideoEditorKit — último commit `c917b1e99ddc631b754a43704c05dfe3836e8183`, 30/04/2026 ("Improve
  video watermark export flow"), = tag `v1.5.0`. Criado em 02/04/2026; 22 estrelas; 0 issues abertas. **Ativo, mas novo e pequeno** (um
  autor). O repositório tem `AGENTS.md`, `CLAUDE.md` e uma seção "AI Implementation Prompt" no README: boa parte parece escrita com IA
  (observação, não juízo de qualidade).
- **Licença:** MIT (`LICENSE`, "Copyright (c) 2026 didisouzacosta"). Uso comercial e redistribuição permitidos.
- **Swift/iOS:** `swift-tools-version: 6.2` (modo Swift 6), iOS 18 no `Package.swift` (o README diz 18.6+), SwiftUI + Observation + Swift
  Testing. 72 `@MainActor`, 1 `actor` (`VideoCanvasMappingActor`), 6 `@unchecked Sendable`, 1 `@preconcurrency import CoreImage`. É o único
  dos cinco pensado para Swift 6.
- **Dependências:** nenhuma externa. **Mas:**
  - `Sources/VideoEditorKit/Transcription/OpenAIWhisperAPIClient.swift` e companhia (cliente da API da OpenAI, chave passada pelo app) estão
    **dentro do alvo da biblioteca**, não só nos exemplos: viriam no binário mesmo sem uso. Fora das regras do Cue (nuvem, chave de terceiro).
  - `Sources/VideoEditorKit/Resources/preview.mp4` tem **38 MB** e é recurso do alvo (`.process("Resources")`), usado só num `#Preview`
    (`Views/Editor/VideoEditorView.swift`, ~linha 510): **iria para o pacote do app**.
- **Arquitetura de exportação (lida):** `Internal/Models/Enums/VideoEditor.swift` (2.553 linhas) exporta em **estágios sequenciais**, cada um
  um `AVAssetExportSession` com arquivo intermediário: base (redimensionar/recortar) → ajustes de cor (`CIFilter`) → legendas
  (`AVVideoCompositionCoreAnimationTool`) → marca-d'água. Recodifica o vídeo até 4 vezes: pior em tempo, energia e qualidade do que a
  passada única do `CueVideoCompositor`.
- **O que estudar:**
  - `Editing/VideoEditingConfiguration.swift`: snapshot `Codable` com `version`/`SchemaVersion` e `decodeIfPresent ?? padrão` em cada
    parte — bom padrão para o Cue conferir na persistência das edições (abrir projetos antigos sem quebrar).
  - `Playback/PlaybackTimeMapping.swift` e `Transcription/TranscriptTimeMapper.swift`: conversão tempo da fonte ↔ tempo da linha do tempo sob
    velocidade e corte, preservando a posição ao mudar a velocidade; útil para legendas por palavra depois de cortes/velocidade.
  - `SafeArea/SocialPlatformSafeArea.swift`: margens seguras por rede (TikTok 240/660/120/120 px em 1080×1920; Shorts 288/672/48/192;
    Instagram 14 %/35 %/6 %/6 %). **Os números não têm fonte citada no código**; se o Cue quiser guias de área segura, medir nas próprias
    redes antes de usar.
  - Organização SwiftUI por coordenadores (`Internal/Editing/*Coordinator.swift`) e o rascunho de ferramenta (`EditorToolDraftCoordinator`:
    editar numa cópia e confirmar/cancelar).
- **Recomendação: estudar só.** Motivos: o cliente de nuvem e o vídeo de 38 MB dentro da biblioteca, a exportação em vários passes, e o
  Cue já tem editor próprio mais completo. Se algum dia copiar um arquivo pequeno (por exemplo o mapeamento de tempo), é MIT: levar o aviso.

## 7. Alternativas gratuitas melhores

1. **Filtros de transição nativos do Core Image** (Apple, sem licença a cumprir): `CIDissolveTransition` (já usado), `CISwipeTransition`,
   `CIBarsSwipeTransition`, `CICopyMachineTransition`, `CIFlashTransition`, `CIModTransition`, `CIRippleTransition`,
   `CIAccordionFoldTransition`, `CIPageCurlTransition`, `CIDisintegrateWithMaskTransition`; mais os blocos `CIZoomBlur`, `CIMotionBlur`,
   `CIBoxBlur`, `CILinearGradient`, `CIRadialGradient`, `CIBlendWithMask`. Com eles saem as transições 1–6 e 8–9 da §3.4 sem kernel próprio.
   A maioria dos `CI*Transition` tem estética datada; os blocos são o que interessa.
2. **GL Transitions direto** (https://github.com/gl-transitions/gl-transitions, MIT por padrão, licença por arquivo, ativo em 10/2026): fonte
   original, com metadados (`Description`, `Tags`, faixas de parâmetro) e um editor online para testar cada uma antes de reescrever.
3. **Harbeth** (https://github.com/yangKJ/Harbeth, MIT, último commit `6c01592c47` de 28/09/2026, 721 estrelas): biblioteca de filtros em
   Metal mantida, citada na issue #381 do MetalPetal. **Só olhei os metadados** (licença e atividade), não o código: se um dia o Cue precisar
   de um filtro que o Core Image não tem, é a referência mantida a avaliar antes do MetalPetal. Para transições, não é necessária.

## 8. Tabela resumo

| Repositório | Tipo | Licença (SPDX) | Exceções | Último commit / versão | Swift 6 | Dependências | Recomendação |
|---|---|---|---|---|---|---|---|
| ruanjx/VideoLab | Open source público | MIT | `Render/Base` derivado do GPUImage3 (BSD-3-Clause) sem aviso | `d2651f4`, 31/10/2022 / `0.0.1` | Não (Swift 5, só CocoaPods) | Nenhuma | **Estudar só** (reuso de trilhas, camada de ajuste, instruções por intervalo) |
| alexiscn/MTTransitions | Open source público | MIT | 1 shader BSD-3 (HP), 1 BSD-2 (Schundler), 2 sem cabeçalho, imagens sem licença | `66531b1`, 12/12/2024 / `1.6.6` de 31/08/2022 | Não (Swift 5) | MetalPetal | **Rejeitar**; usar a lista e reescrever do GL Transitions |
| gl-transitions/gl-transitions | Open source público | MIT | Por arquivo; 1 BSD-3, 1 BSD-2 | `c06c490`, 15/10/2026 | n/a (GLSL) | n/a | **Adaptar a matemática** de 6–8 transições em Core Image, com atribuição |
| MetalPetal/MetalPetal | Open source público | MIT (docs CC-BY-4.0) | `MetalPetalExamples/`: só uso não comercial | `f9b7889`, 21/02/2023 / `1.25.2` | Não (ObjC/C++ + Swift 5) | Nenhuma (MPS; VideoIO para exportar) | **Rejeitar**; estudar o README de otimizações |
| VideoFlint/Cabbage | Open source público | MIT | Nenhuma encontrada | `41c7870`, 21/03/2022 / `0.5.1` | Não (Swift 4.2/5) | Nenhuma | **Estudar só** (fatiamento, tap de áudio, reverso, alerta de cor) |
| didisouzacosta/VideoEditorKit | Open source público | MIT | Nenhuma; mas inclui cliente OpenAI e vídeo de 38 MB no alvo | `c917b1e`, 30/04/2026 / `v1.5.0` | Sim (tools 6.2) | Nenhuma externa | **Estudar só** (snapshot versionado, mapeamento de tempo, áreas seguras) |

Nenhum é SDK pago; todos são repositórios públicos com licença permissiva (o único trecho "não livre" é `MetalPetalExamples/`).

## 9. Licenças e atribuições (o que precisa viajar com o app)

Se o Cue **só estudar** VideoLab, MetalPetal, Cabbage e VideoEditorKit (recomendado), **nada deles precisa viajar** com o binário. Vale
registrar a avaliação em `THIRD_PARTY_NOTICES.md`, como já foi feito com o YUCIHighPassSkinSmoothing.

Se o Cue **reescrever as transições da §3.3 a partir do GL Transitions**, mesmo sem copiar texto, recomendo tratar como adaptação (a
fórmula e as constantes vêm de lá) e levar:

1. O texto da licença MIT do GL Transitions, com a linha "Copyright (c) 2017-present gl-transitions contributors", em
   `THIRD_PARTY_NOTICES.md` e na tela de agradecimentos (`AcknowledgementsView`).
2. Uma linha por transição usada, com arquivo de origem, autor e licença, e o commit de referência `c06c4905958446b7da2d121b12942495e18c99c0`
   (15/10/2026):
   - `CrossZoom.glsl` — rectalogic (portado por gre), MIT; baseado em glfx.js `zoomblur.js`, © 2011 Evan Wallace, MIT
     (https://github.com/evanw/glfx.js).
   - `LinearBlur.glsl` — gre (Gaëtan Renaudeau), MIT.
   - `Overexposure.glsl` — Ben Zhang, MIT.
   - `Directional.glsl` — Gaëtan Renaudeau, MIT; `directional-easing.glsl` — Max Plotnikov, MIT.
   - `zoomInOut.glsl` — OllyOllyOlly, MIT (ou `SimpleZoom.glsl` — 0gust1, MIT).
   - `directionalwipe.glsl` — gre, MIT.
   - `GlitchMemories.glsl` — Gunnar Roth, MIT ("based on work from natewave"; a obra de natewave não foi localizada nem verificada).
   - Opcionais: `circleopen.glsl` — gre, MIT; `fadecolor.glsl` — gre, MIT.
3. Comentário no topo de cada função/kernel do Cue com o nome do arquivo de origem, o autor e "MIT", para a origem ficar no código.

**Não usar** (ou, se usar, levar o texto completo da licença BSD e o copyright): `InvertedPageCurl` (BSD-3-Clause, © 2010 Hewlett-Packard
Development Company, L.P.) e `StereoViewer` (BSD-2-Clause, © 2016 Theodore K Schundler). **Não copiar** nada de `MetalPetalExamples/`
(licença só não comercial), nem de `VideoLab/Render/Base` (exigiria também o aviso BSD-3 do GPUImage3, © 2018 Brad Larson e Janie
Clayton), nem as imagens de `MTTransitions/Source/Assets.bundle` (origem desconhecida).

## 10. O que não consegui verificar

- Tamanho de binário, memória e bateria de cada biblioteca: **estimados**, não medidos (nada foi compilado, por instrução).
- A variante exata de kernel Metal para Core Image e as flags de build no Xcode 27/iOS 27.
- A origem do trabalho de "natewave" citado em `GlitchMemories.glsl` e a licença das imagens de luma/deslocamento do MTTransitions.
- Se a comunidade do MetalPetal (#400) vai de fato assumir o projeto; o fork `eerimoq/MetalPetal` não foi lido.
- O código do Harbeth (só licença e atividade).
- Se avisos de compilação de pacotes SPM remotos apareceriam no build do Cue (o Xcode costuma suprimi-los para pacotes não raiz; não
  conferido neste projeto). Irrelevante se a recomendação de não adicionar dependência for seguida.
