# Editor "award winning": relatório final

Branch `feature/editor-award` (a partir de `main` 4653ecc). 15 commits, 210 arquivos. Aparelho de teste: iago Lima iphone (iPhone 15 Pro).
Progresso item a item: `reports/editor-award-checklist.md`. Estado atual de cada tela: `DESIGN_PROJECT.md` §37. Referências: `reports/editor-references.md`.

## 1. Bugs corrigidos (todos confirmados no código antes e com teste de regressão)

| Bug | Correção |
|---|---|
| A capa guardava só o segundo e era renderizada sempre do vídeo principal (numa montagem, capa errada) | `CoverFrame` guarda gravação, clipe e segundo da gravação; o quadro sai da gravação certa, com o look do clipe |
| Falha ao salvar a capa sumia em silêncio; `.jpg` ficava no temporário | Estado próprio da capa na exportação (salvando / salva / não salva + motivo), Tentar de novo, Compartilhar, limpeza |
| Studio Voice só tratava a gravação principal | Trata cada gravação (escolha em "Applies to"), nivelamento entre clipes (+9/−12 dB, sem passar de −1 dBFS), mesmo arquivo na prévia e na exportação |
| A exportação tratava o som de novo e deixava `.caf` no temporário | Cache compartilhado (`RecordingSoundCache`), no máximo 8 arquivos |
| Clean Up só analisava a gravação principal | Cada sugestão sabe de que gravação é; remover corta só ela, em cada cópia |
| Mídias sobrepostas: só a primeira recebia alças | Seleção pela ordem visual, toque repetido alterna camadas, a coberta continua alcançável |
| Item arrastado aparecia duas vezes | O vídeo não desenha o item durante o arraste |
| "Join next" juntava legendas de gravações diferentes | Junta só a próxima fala da mesma gravação |
| Ajuste e arraste de legenda gravavam o tempo da gravação errada | Limitados ao clipe da própria linha |

## 2. Melhorias

- **Capa refeita (Cover Studio):** tela cheia, 5 etapas (Imagem → Modelo → Título → Gráficos → Finalizar).
  - **Modelos:** 6 (Educativo, Opinião, Lista, Demonstração, Antes/depois, Série), com miniatura real da sua foto e do seu título.
  - **Texto:** o bloco inteiro cabe sem cortar palavras, com RTL, acentos, emoji, japonês, chinês e tailandês.
  - **Gráficos:** editáveis.
  - **Antes/depois:** com duas imagens.
  - **Efeitos e estilo:** efeitos com força ajustável; estilo salvo sem guardar conteúdo.
  - **Guias de recorte:** marcadas como aproximação; o app não promete aplicar a capa em nenhuma rede.
- **Escopo explícito:** Crop e Studio Voice com o selo "All" e num grupo separado na barra do clipe.
- **"Media" na barra principal:** a folha explica a diferença entre sobre o vídeo (B-roll) e clipe na sequência.
- **Animações prontas** (Fade, Slide up, Slide in, Gentle zoom, Pop, In and out): com duração e força, por cima dos keyframes, que continuam editáveis.
- **Copiar e colar look:** escolhendo Adjust, Filter, Background e Zoom, num clipe ou em todos.

## 3. Funcionalidades novas

- **Trecho do B-roll:** início e duração próprios, nunca além do fim do arquivo.
- **Efeitos sonoros:** 11 sons **sintetizados pelo próprio Cue**. Nenhum arquivo de terceiros e nada baixado.
- **Gráficos no vídeo:** seta, círculo e etiqueta, desenhados como na capa.
- **Edit by text:**
  - **"Cut from video"** corta o vídeo.
  - **"Fix caption text"** muda só a legenda.
  - **Put back** devolve as palavras cortadas.
  - A transcrição é feita no aparelho.
- **Templates** (Bold hook, Tutorial, Story, Clean, Interview):
  - legendas, títulos e movimento mudam juntos;
  - palavras, cortes, som e gráficos ficam como estão;
  - um Undo desfaz tudo.
- **6 transições novas** (Zoom, Desfoque, Clarão, Empurrar, Soco, Cortina): a duração é ajustável de 0,2 a 1,5 s em todas.
- **Congelar quadro:** o quadro da agulha vira um clipe de 2 s, que pode ser esticado até 5 s.

**Não feitos** (avaliados; feitos agora seriam demonstrações frágeis; o motivo de cada um está no checklist): reverso, curvas de velocidade, cortes nas
batidas, reenquadramento por rosto, estabilização e rastreamento.

## 4. Referências estudadas e licenças

| Projeto | Licença | Decisão |
|---|---|---|
| VideoLab | MIT (a pasta Render/Base vem do GPUImage3 sem aviso) | Só estudo |
| MTTransitions | MIT, depende do MetalPetal | Rejeitado: 30 fps fixos, defeito no compositor, shaders com licença incerta |
| MetalPetal | MIT; os exemplos são só para uso não comercial | Rejeitado |
| Cabbage | MIT | Só estudo (exportação mais escura por espaço de cor, issue #84) |
| VideoEditorKit | MIT | Só estudo (embute um cliente da OpenAI) |
| GL Transitions (commit c06c490) | MIT, por arquivo | **Usado como referência do movimento**: 6 transições reescritas em Core Image, sem copiar código. Aviso MIT e autores em `THIRD_PARTY_NOTICES.md` e em Ajustes › Agradecimentos |

Nenhuma dependência nova, nenhum serviço pago e nada na nuvem. A IA e a transcrição rodam só no aparelho.

## 5. Testes

**Testes novos:**
- **Unidade:** cerca de 30 suítes.
  - Capa, texto da capa, Studio Voice, Clean Up, mídias sobrepostas, legendas.
  - Animações, copiar look, B-roll, efeitos sonoros, gráficos, Edit by text, templates.
  - Transições, créditos de licença, congelar quadro, contraste.
- **Exportação real:** B-roll, efeitos sonoros, Studio Voice na montagem, congelar quadro.
- **Prévia × exportação:** uma montagem com todos os recursos novos juntos, comparada em 7 quadros (inclusive no meio do Zoom e do Clarão), com a mesma duração e o efeito sonoro no lugar.
- **UI:** 3 testes do Cover Studio.

**Resultados:**
- **Fast:** 3.389 passaram. Uma falha intermitente do `VoiceBriefSnapshotTests`, que lê do disco do Mac um arquivo diferente a cada rodada. As fixtures e o código de voz estão iguais aos da `main`.
- **UI:** Smoke 26/26; editor, Cover Studio e Ajustes 34/34.
- **Full:** ver §8.
- **Zero warnings** (`check-warnings.sh`): simulador, aparelho e Release.
- **Contraste:** `PaletteContrastTests` 38/38, inclusive os tokens novos (contorno das mídias, guias da capa, blocos escolhidos).

## 6. Medições (iago Lima iphone, iPhone 15 Pro)

**Exportação da montagem completa:** 9 s de vídeo com 2 transições, quadro congelado, B-roll, seta animada, legendas gravadas, efeito sonoro, Studio Voice e fundo desfocado.

| | Antes da otimização | Depois |
|---|---|---|
| 1080p | 7,5 s | **6,7 s** (0,75× a duração) |
| 4K | 17,3 s | **9,3 s** (1,03× a duração) |

**Quadro de cada transição (p50):**
- Dissolver, Clarão, Soco, Empurrar e Cortina: 2 a 8 ms.
- Zoom em 4K: era 118 ms e passou a 11 ms.
- Desfoque em 4K: era 41 ms e passou a 13 ms. O desfoque agora é feito numa cópia reduzida, e o resultado visual ficou igual.

**Latência da prévia (até a mudança aparecer, p50):**

| Cenário | Esta branch | `main` |
|---|---|---|
| Filtro | 40 ms | 44 ms |
| Texto | 44 ms | 44 ms |
| Fundo desfocado | 58 ms | 58 ms |
| 4K | 50 ms | 50 ms |
| Corte, p50 | 89 ms | 88 ms |
| Corte, pior caso | 92 ms | 1044 ms |

Nenhuma mudança deixou a tela em branco.

**Congelar quadro:** gerar o clipe leva 0,6 s em 1080p e 1,8 s em 4K.

## 7. Limitações e o que não foi validado

- **Travamento na primeira medição de latência:** o cenário de fundo desfocado passou de 5 minutos logo depois das exportações 4K. Rodei a `main` e esta branch de novo, com o aparelho descansado, e as duas passaram com os mesmos números. Concluí que foi o estado do aparelho, mas não reproduzi a causa.
- **Congelar quadro em vídeo HDR:** o quadro sai em SDR. Num vídeo HDR pode ficar um pouco diferente dos clipes vizinhos. Não testado com gravação HDR real.
- **Som do `AudioEnhancer`:** deixa um som mono cerca de 3 dB abaixo do pedido. Observado e não alterado; o nivelamento novo não passa por ele.
- **Telas pequenas e Dynamic Type:** os painéis novos usam os controles do editor (rolagem, alvos de 44 pt), mas não fiz capturas no iPhone SE nem em tamanho XXXL.
- **Uso real no aparelho:** os fluxos novos (Cover Studio, Edit by text, templates, transições, congelar quadro) foram testados no simulador e por testes automáticos no aparelho, não por toque humano no iPhone.
- **Plural:** "Cut 1 words" sai sem plural, como em outras strings do projeto, que não usa variações de plural no catálogo.
- **Clones de simulador:** os testes rodam em paralelo com clones (o script não permite desligar). Apaguei os clones depois de cada rodada.
- **Recursos não feitos:** reverso, curvas de velocidade, batidas, reenquadramento, estabilização e rastreamento (§3).
