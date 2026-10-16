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

### Achados da auditoria de UX e da revisão de código (16/10), corrigidos

**Auditoria de UX e confiabilidade:**

| Bug | Correção |
|---|---|
| Cache do Studio Voice podia apagar um som em uso numa montagem | Arquivo reusado conta como recente; arquivo de outra chave nunca é apagado; arquivo usado nos últimos 2 min fica |
| "Colar look em todos" desligava Filters, Adjust e Background do vídeo inteiro | Em todos: vai para os ajustes do vídeo e limpa as cópias dos clipes; num clipe: guarda só o que difere |
| Congelar quadro perdia o fundo, entrava no lugar errado perto do início de um clipe e pesava na thread da interface | Fundo e look do clipe; antes do clipe quando colado no início; fora da thread da interface |
| Templates moviam os textos de lugar | A posição e o alinhamento de cada texto ficam |
| A etiqueta "NEW" virava título da capa e hook do template | Gráficos não sugerem título |
| "Use on every cut" não copiava a duração | Copia; se já está em todos, avisa |
| Edit by text cortava todas as cópias do clipe e mantinha a seleção depois do Undo | Corta só o clipe onde as palavras foram lidas; a seleção limpa quando os cortes mudam |
| Efeitos sonoros não acompanhavam os cortes | Seguem o momento em que foram postos, como os textos |
| Cover Studio: quadro antigo podia vencer ao arrastar a faixa; Vision e o look na thread da interface | O mais recente vence; desenho fora da thread da interface |

**Revisão de código antes do PR:**

| Bug | Correção |
|---|---|
| A limpeza de arquivos apagaria todas as mídias com mais de 7 dias se a lista de takes falhasse ao carregar | A limpeza de mídias foi descartada; só sons temporários de sessões anteriores são apagados |
| O efeito sonoro saía do lugar ao arrastar uma ponta para fora e de volta | O efeito é recalculado a partir de onde o gesto começou |
| O congelar quadro entrava no lugar errado se a pessoa cortasse durante a espera (~2 s em 4K) | Se os cortes mudaram, nada entra e um aviso pede para congelar de novo |
| Um arraste que não pegava nada deixava o desfazer travado | O passo de desfazer só começa quando o arraste pega algo |
| A capa deixava fotos para trás ao cancelar; o arquivo da capa era apagado com a folha de compartilhar aberta | As duas coisas corrigidas |

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
- **Layout de editor de celular** (depois de comparar com CapCut, Edits e InShot; decisão sua):
  - **Barras:**
    - Principal: Edit · Captions · Text · ✦ Smart · Media · Audio · **Format** · Filters · Cover.
    - Clipe: só ferramentas do clipe, as mais usadas primeiro (Split, Speed, Zoom, Volume…), com **Reorder**.
    - Texto: ganha **Animation**. Mídia: ganha **Duplicate**.
  - **Reordenar clipes:** segurar um clipe na timeline abre a lista para arrastar.
  - **Arrastar no tempo:** com um texto, B-roll, legenda ou som escolhido, arrastar o bloco o move, com ímã nos cortes.
  - **Edit by text à vista:** primeiro bloco do ✦ Smart e botão no painel de Legendas.
  - **Templates:** aba própria no ✦ Smart.
- **Texto grande** (conferido no iPhone SE em tamanho de acessibilidade): nada cortado nos painéis novos.
- **Robustez:**
  - Exportação avisa antes quando falta espaço ("Free about N MB").
  - Sons temporários de sessões anteriores são apagados ao abrir o app.
  - Travamentos, CPU e escrita em disco medidos pelo MetricKit chegam ao Crashlytics (sem conteúdo do usuário).

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

- **Aviso depois de fechar uma folha:** o aviso que aparece logo após fechar uma folha (por exemplo "Every clip already looks like this") é visível
  na tela e anunciado em voz pelo VoiceOver. Mesmo assim, o teste automático de UI (XCUITest) não o encontra na árvore de acessibilidade naquele
  instante. O texto do aviso é verificado por teste de unidade; o comportamento no VoiceOver com o dedo não foi conferido.

- **Diferenças com o CapCut que ficaram para depois:**
  - localizar e trocar nas legendas, e seleção de várias linhas;
  - Replace clip;
  - Extract audio.
- **Bibliotecas protegidas (problema anterior a esta branch, corrigido nela):**
  - **Antes:** uma única take ou um único roteiro ilegível fazia a biblioteca inteira carregar vazia, e a próxima gravação a salvava vazia por cima do arquivo, apagando tudo.
  - **Agora:**
    - cada take, roteiro, texto, mídia, música e legenda é lido separado, e só o item com problema fica de fora;
    - o arquivo original é guardado ao lado (`takes-kept-…json` / `scripts-kept-…json`);
    - uma biblioteca que não pôde ser lida, por exemplo antes do primeiro desbloqueio do aparelho, nunca é sobrescrita.

- **Travamento na primeira medição de latência:** o cenário de fundo desfocado passou de 5 minutos logo depois das exportações 4K. Rodei a `main` e esta branch de novo, com o aparelho descansado, e as duas passaram com os mesmos números. Concluí que foi o estado do aparelho, mas não reproduzi a causa.
- **Congelar quadro em vídeo HDR:** o quadro sai em SDR. Num vídeo HDR pode ficar um pouco diferente dos clipes vizinhos. Não testado com gravação HDR real.
- **Som do `AudioEnhancer`:** deixa um som mono cerca de 3 dB abaixo do pedido. Observado e não alterado; o nivelamento novo não passa por ele.
- **Telas pequenas e Dynamic Type:** os painéis novos usam os controles do editor (rolagem, alvos de 44 pt), mas não fiz capturas no iPhone SE nem em tamanho XXXL.
- **Uso real no aparelho:** os fluxos novos (Cover Studio, Edit by text, templates, transições, congelar quadro) foram testados no simulador e por testes automáticos no aparelho, não por toque humano no iPhone.
- **Plural:** "Cut 1 words" sai sem plural, como em outras strings do projeto, que não usa variações de plural no catálogo.
- **Clones de simulador:** os testes rodam em paralelo com clones (o script não permite desligar). Apaguei os clones depois de cada rodada.
- **Recursos não feitos:** reverso, curvas de velocidade, batidas, reenquadramento, estabilização e rastreamento (§3).
