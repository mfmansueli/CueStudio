# Editor: pendências da comparação com o CapCut e pendências técnicas

Branch `feature/editor-capcut-gaps` (a partir de `afce6f9`, que já tem `feature/editor-award` e `feature/export-reliability`). Só Simulador
(iPhone 17, iOS 27): o iPhone físico ficou com o outro agente. Estado de cada tela: `DESIGN_PROJECT.md` §37 (atualizado na mesma entrega).

**Fase desta entrega (pedido do dono):** programar tudo, com cada item compilando e os testes de unidade do item passando. A fase de testes
(`scripts/check-warnings.sh`, `scripts/test.sh full`, UI completa, capturas) fica para a sessão principal (§6).

## 1. O que entrou

| Item | O que o criador ganha | Onde |
|---|---|---|
| **C1. Localizar e trocar nas legendas** | Captions › **Find and replace** (e no menu de legendas): a palavra em todas as linhas que tocam, na ordem em que tocam, marcada em amarelo; **Replace** troca uma, **Replace all** todas num passo de desfazer ("Replaced 2 times" · Undo). Maiúsculas e largura não importam; acento importa ("e" não acha "é"). Os tempos da linha e das palavras que continuam iguais ficam. | `CaptionFindReplace`, `QuickEditViewModel+CaptionFind`, `CaptionFindSheet` |
| **C2. Várias linhas de legenda** | Captions › **Select lines** (ou segurar uma linha): círculos nas linhas, "N selected", Select all, Done; ações fixas embaixo: **Emphasis** (a linha inteira na cor de destaque), **Size** (Regular, Bigger, Biggest), ‹ › (0,1 s, todas juntas, sem sair do clipe nem encostar em outra linha) e lixeira. Cada ação é um passo de desfazer. O estilo é desenhado na prévia e na exportação. | `CaptionLineStyle`, `CaptionCue.lineStyle`, `CaptionCollectionRenderer`, `WordEmphasis.count`, `QuickEditViewModel+CaptionPicks`, `CaptionPickTools` |
| **C3. Replace clip** | Barra do clipe › **Replace**: um vídeo do Fotos no lugar do clipe, do começo, pela mesma duração (mais curto: o clipe fica do tamanho dele), com velocidade, zoom, volume, transição e look; textos/mídias/narrações presos ao clipe ficam no mesmo momento. Undo traz o antigo. | `EditTimeline.replaceSource`, `TakeEdit.moveOverlays`, `QuickEditViewModel+ReplaceClip`, `PhotoRequest.replaceClip` |
| **C4. Extract audio** | Barra do clipe (e da mídia, num vídeo com som) › **Extract audio**: o som vai para a faixa de música onde tocava ("Sound · Clip 2"), como o Cue o toca (Studio Voice e nivelamento, na velocidade do clipe), editável (mover, aparar, fades, volume), sem abaixar sob a voz; o clipe ou o vídeo fica mudo. Segue o seu momento quando algo antes é cortado. Undo desfaz os dois. | `SoundExtractor`, `SoundExtraction`, `TakeEditing.extractSound`, `MusicClip.extractedFrom`, `QuickEditViewModel+ExtractAudio` |
| **D5. Plural** | As frases com número do editor variam por plural no String Catalog, nos 20 idiomas (árabe com as seis formas). Saíram as chaves "1 …" que contornavam o plural; "Cut from video (N)" virou "Cut N words from the video" e "Words cut: N" virou "N words cut · 0,8 s". `scripts/strings.py add` aceita as formas (`{"one": …, "other": …}`) no formato do Xcode e confere as categorias de cada idioma. Regra em `LOCALIZATION.md` §3. | `Localizable.xcstrings`, `scripts/strings.py`, `PluralStringsTests` |
| **D6. Congelar quadro em HDR** | Numa gravação HDR, o quadro congelado é o próprio quadro decodificado em 10 bits, gravado em HEVC Main 10 com as primárias, a transferência (HLG/PQ) e a matriz da gravação, e a mesma rotação: o editor o converte como os clipes vizinhos. SDR continua H.264. Se o HDR não puder ser gravado, congela em SDR (nunca falha por isso). | `StillClipWriter` |
| **D7. Aviso depois de fechar uma folha** | **Causa encontrada: não era a árvore de acessibilidade.** Medido com uma sonda XCUITest: o aviso aparece na árvore ~0,6 s depois do toque (3 vezes: o host do editor e os de trás) e some aos 2 s. O teste antigo esperava a folha sumir antes de procurar o aviso, e o tempo acabava. O teste `testPastingAnUntouchedLookOnEveryClipChangesNothing` agora procura o aviso primeiro e passa (3 rodadas com animações desligadas e 1 com as reais). Nenhuma mudança no app. | `CreatorWorkflowUITests` |

**Decisão de layout depois de comparar com CapCut/Edits/InShot:** no Select, as ações ficavam no topo da lista e sumiam ao rolar, e as linhas mal
cabiam no painel médio (o teste de UI não conseguia tocar a segunda linha). Agora, como no CapCut: o painel cresce até a altura dos painéis
de estilo enquanto escolhe, a contagem fica no lugar da chave e dos chips, e as ações ficam fixas no rodapé (registrado no §37).

**Diferença que fica:** no Replace clip, o CapCut deixa escolher o trecho do vídeo novo; aqui ele entra do começo e as alças do clipe aparam.
Próximo passo: a faixa "Part of the video" do B-roll (`MediaTrimStrip`) também para clipes de outra gravação (§37).

## 2. Como foi testado (Simulador, `scripts/test.sh only …`)

| Suíte | Testes | Resultado |
|---|---|---|
| `CaptionFindReplaceTests`, `QuickEditCaptionFindTests` (+ `QuickEditToolbarTests`) | 45 | passaram |
| `CaptionLineStyleRenderingTests`, `QuickEditCaptionPicksTests` (+ renderer, LazyText, caption panels, revisions) | 55 | passaram |
| `QuickEditReplaceClipTests`, `QuickEditExtractAudioTests`, `RealExports/SoundExtractorTests` (+ toolbar, clip looks, montage, sound effects, Quick Creator) | 114 | passaram |
| `PluralStringsTests` (20 idiomas × 0, 1, 2, 3, 11, 100), `LocalizationCatalogTests` (+ suítes cujas frases mudaram) | 129 | passaram |
| `RealExports/FreezeFrameHDRTests`, `FreezeFrameExportTests`, `QuickEditFreezeFrameTests` | 7 | 6 passaram, 1 só no iPhone (abaixo) |
| UI: `CaptionToolsUITests` (2), `ExtractAudioUITests` (1), `CreatorWorkflowUITests/testPastingAnUntouchedLook…` | 4 | passaram (uma rodada cada) |

Números medidos:
- **Extract audio em arquivo real:** 3 s de som extraídos com o trecho alto no segundo certo (> −20 dBFS) e silêncio fora (< −40 dBFS); a 2×,
  o som sai com metade da duração e o tom no lugar certo.
- **HDR:** o quadro congelado de um clipe HEVC Main 10/BT.2020/HLG gerado no teste sai HEVC, 10 bits, HLG, BT.2020, com a mesma rotação, e o
  valor do quadro (Y′CbCr de 10 bits) a ±6 do original.
- **Plural:** `String(localized: "Removed \(1) pauses · \("0.4")")` = "Removed 1 pause · 0.4" (o número e o segundo valor caem nos lugares
  certos com as formas numeradas); pt-BR "1 pausa removida · 0.4"; árabe "3 أسطر" / "11 سطرًا".
- **SwiftLint** limpo nas pastas tocadas; nenhum warning nos builds desta entrega (os logs de `build/logs/` sem `warning:`).

## 3. Contraste

Nenhum token novo. Os textos novos usam tokens já medidos em `PaletteContrastTests`: `ink`, `ink2` e `accText` sobre `sheetNight` (Find and
replace), `ink`/`accText` sobre `fill` e `accText` sobre `accSoft` (chip Emphasis ligado), `ink2`/`accText` sobre `panelCard`, `dangerText`
sobre `dangerWash`, `ink2` nos placeholders. A linha com Emphasis usa a cor que a palavra dita já usa em cada estilo (medida em
`VideoTemplateCaptionContrastTests`, ≥ 3:1, texto grande); Size só aumenta (nunca abaixo do tamanho medido). **Medido na imagem renderizada**
(capturas de `CaptionToolsUITests`, `tools/contrast/audit.py` e o pixel de cada texto): ver §7.

## 4. O que NÃO foi validado, e por quê

- **Fase de testes inteira** (pedido do dono): `scripts/check-warnings.sh` (recompila do zero para Simulador, aparelho e Release), `scripts/test.sh
  full`, UI completa e capturas não foram rodados por esta sessão. A sessão principal faz.
- **Exportar uma gravação HLG no Simulador falha** (`-12905`, VideoToolbox não converte HLG para o BGRA do compositor). Medido: o clipe HDR
  sozinho, sem quadro congelado, não exporta; o mesmo clipe marcado BT.709 exporta. Por isso o teste "a exportação mostra o quadro congelado
  igual ao clipe de onde veio" (`FreezeFrameHDRTests.anExportShowsTheFrozenFrameLikeTheClipItCameFrom`) só roda no iPhone e está **não
  validado**. Se no iPhone a exportação de uma take HDR também falhar, é um problema anterior a esta branch (o editor inteiro é SDR/BGRA).
- **HDR de verdade do iPhone** (Dolby Vision 8.4 com HLG): só o clipe HLG gerado no teste. A metadata de Dolby Vision não é copiada para o
  quadro congelado (fica HLG puro, que o compositor lê igual).
- **Extract audio com som real no Simulador:** as takes de exemplo dos testes de UI são mudas, então o teste de UI confere o aviso "This clip has no
  sound" e que nada muda; o caminho com som está nos testes de unidade (fakes) e no `SoundExtractorTests` (arquivo real). O caminho com Studio
  Voice ligado (`RecordingSounds.prepare` antes de extrair) não tem teste com áudio real.
- **Replace clip pelo Fotos:** o seletor do sistema não é dirigível pelo XCUITest; as regras estão em `QuickEditReplaceClipTests`.
- **Estilo por linha em legendas antigas** (sem `captionCollection`) e **em traduções**: não se aplica (o painel diz "Pick a look in Style…";
  traduções mostram as linhas sem o estilo).
- **Plural em frases com dois números** ("2 of 3 recordings"): ficaram sem variação (precisariam de substituições por argumento).
- **Toque humano no iPhone, VoiceOver com o dedo, iPhone SE e texto grande** nas telas novas: não conferidos (os layouts têm `ViewThatFits` e
  alvos de 44 pt).
- **Clones de simulador:** não rodei `xcrun simctl --set testing delete all`, porque outras sessões estavam testando ao mesmo tempo no Mac e o
  comando apagaria os clones delas. A sessão principal apaga no fim da fase de testes.

## 5. Commits (em inglês, com as linhas de atribuição)

1. `1c14fc5` Captions: Find and replace in every line…; strings.py writes plural variations
2. `7f7bfb6` Captions: Select lines to emphasize, size, move or delete several together…
3. `bbdb92c` Clip tools: Replace … and Extract audio … (C3 e C4 num commit: dividem a barra do clipe e as ações; separados, um não compilaria)
4. `7ccf561` Strings: the editor's counts vary by plural…
5. `9def270` Freeze frame: a frame of an HDR recording stays HDR…
6. `3c5c6ac` Toast after a sheet: it is in XCUITest's tree (measured)…
7. `607163a` Captions › Select: the panel grows while picking…; UI tests
8. o commit destes relatórios.

## 6. Para a fase de testes (sessão principal)

1. `scripts/check-warnings.sh`.
2. `scripts/test.sh full` (inclui `CaptionToolsUITests` e `ExtractAudioUITests`; `CaptionToolsUITests/testFindAndReplaceFixesAWordInEveryLine`
   entrou no plano `UISmoke`).
3. No iPhone: `RealExports/FreezeFrameHDRTests` (o teste de exportação HLG) e um Extract audio numa take real com Studio Voice.
4. Capturas das telas novas (Find and replace, Select com o rodapé) e `tools/contrast/audit.py`.
5. `xcrun simctl --set testing delete all`.

## 7. Fase de testes (17/10, sessão principal)

Esta branch foi validada **dentro de `feature/editor-motion`**, que a contém inteira (merge `60cb278`, e de novo depois da correção abaixo):
um Full só para as duas, em vez de um para cada (cada Full leva cerca de 2 h).

- **`scripts/check-warnings.sh`:** sem nenhum warning (Simulador, aparelho e Release), no merge e de novo no estado final.
- **Full** (`60cb278`): 3.862 aprovados, 3 falhas. Duas exportações estouraram o tempo sob a carga do plano em paralelo e passam sozinhas em
  2,9 s e 2,7 s (`EditorExportMatchesPreviewTests`, `QuickCreatorExportTests`); um teste de UI esperava o rótulo antigo "(2)" de Edit by text
  (corrigido para "2 words", passa).
- **Revisão de código** (duas correções nesta branch):
  - `1f517a0`: Replace clip num clipe cortado movia o que tocava na outra parte do corte (textos, mídia, som). Agora fica onde estava
    (`TakeEdit+ReplaceClip.moveOverlays`, teste `whatPlaysOnTheOtherPartOfACutClipStaysThere`).
  - `8cbe836`: Extract audio num clipe mudo (som já extraído ou desligado) criava uma segunda voz igual. Agora avisa "This clip is muted · Turn
    its sound on to extract it" e não muda nada (teste `aMutedClipOrVideoHasNothingToExtract`).
- **Contraste na imagem renderizada:**
  - Find and replace: título 15:1, subtítulo, "1 match" e a linha encontrada 6,1:1; o botão Replace 13,3:1; Replace all 14,6:1.
  - **Corrigido:** o texto de exemplo "New word" estava a **4,3:1** (`inkHint` sobre o campo, que é mais claro em cima da folha). Agora usa
    `ink2`, como o `SearchField`, e mede **5,1:1** (commit `23ed9ed`).
  - Select lines: o tempo de uma linha não marcada 5,7:1; a linha marcada em amarelo 11:1; Select all 13,4:1; Delete 4,9:1 (ícone, mínimo 3:1).
  - As outras medidas abaixo do mínimo que o `audit.py` listou são de telas escondidas atrás do editor (a lista de takes, a revisão), que
    continuam na árvore de acessibilidade. Conferi cada uma na imagem.
- **No iPhone (iago Lima iphone, 15 Pro):** `RealExports/FreezeFrameHDRTests` 3/3, incluindo a exportação de uma gravação HLG com quadro
  congelado, que o Simulador não roda. O HDR do quadro congelado está **validado**. Para isso, `scripts/test.sh device` agora aceita
  `RealExports/<Suíte>`.
- **Clones de simulador** apagados (`xcrun simctl --set testing delete all`) no fim.
- **Continua não validado:** Extract audio numa take real com Studio Voice; Replace pelo Fotos com o dedo; VoiceOver, iPhone SE e texto
  grande nas telas novas.

