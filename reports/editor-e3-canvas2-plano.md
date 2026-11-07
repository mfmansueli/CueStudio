# Etapa 3 · Canvas 2 · plano de execução

Decisões: `editor-e3-canvas2-decisoes-2026-11-07.md` (texto do dono, §1–7). Base: `feature/editor-trust` b984a96f. Cruzamento com o
código feito em 07/11 por leitura (dois agentes, linha a linha) e conferido por mim nos pontos de conflito.

O primeiro marco (barra nova + Limpar fala integrado + correções da etapa 2) já foi instalado e o dono avaliou no iPhone em 07/11 de manhã
("tudo ok até onde percebi"): as mudanças que dependiam dele estão liberadas. R10-B é restrição de layout em todas as entregas; M1-C é adiamento
(nada a fazer, registrado em DESIGN_PROJECT).

## O que o cruzamento achou (muda o plano)

- **Não existe finlandês no app** (20 idiomas: ar, da, de, en, es, fr, hi, id, it, ja, ko, nb, nl, pt, sv, th, tr, vi, zh-Hans, zh-Hant). F2 mede
  "Texto por legenda" em alemão ("Text pro Untertitel", "Kurze Phrase"), francês ("Phrase courte") e nos outros longos (nl, ru não existe).
- **F15 inverte o que está no código:** hoje a agulha pula para depois da entrada (`showPickedTextWhole`, `setMotionPreset`). O dono quer o objeto
  inteiro **sem** a agulha pular: vira um "segurar inteiro" só na prévia, que a exportação nunca lê. A linha "Pop" do estado da etapa 3 é refeita.
- **F12: não existe segurar nas fontes hoje.** O atalho é construído junto (menu de contexto Remove).
- **F16: Follow face já nunca liga sozinho.** Fica assim; o canvas não é seguido nesse ponto.
- **F10 e erro 7: a regra do §61** ("sem escolha, o Remove de sempre") esconde a dica; a dica passa a ficar no conteúdo da aba e o §61 é emendado.
- **R3 desfaz o painel Templates + Kit com abas** feito na D1: Kit da marca volta a ter painel próprio.
- **R6 "Stop":** o Cancel do Track hoje joga fora tudo o que foi seguido; o Stop do Desfocar guarda. Stop passa a guardar o que foi seguido
  (Undo tira), igual ao Desfocar.
- **PT "Recorte":** D5 deu "Recorte" ao Crop do clipe; o Cutout (tela verde) em PT deixa de se chamar "Recorte" (nome de tradução, meu).
- **Erros 4 e 6** são comportamento de propósito no código: viram R2 e F6.

## Escolhas que fiz dentro do texto do dono (sem decisão nova)

| Ponto | Escolha | Por quê |
|---|---|---|
| R2 "restaurar o contexto" | Só depois do Motion da barra (o único que força "este título") | é o único caminho que troca o alcance sozinho |
| R5 resets "com escopo definido" | Os cinco do canvas: Proporção, Texto, Gráfico, Motion, Foto ou vídeo; Fundo no vídeo inteiro volta ao Original | foram os que o canvas definiu com alcance |
| R12 durações comuns | Só em valores de duração (Plays for, Shows for); Starts/Ends continuam posições, sem menu | "distinguir duração de posição absoluta" |
| Erro 1 Reset do volume | Volta ao volume com que a mídia entrou (mudo ou com som, como a pessoa escolheu) | é o "original" daquela mídia |
| F2 Mine / Save style | Mine some de All quando vazio; Save style é o último cartão de Mine e, sem Mine, o último de All. A mesma regra no Texto e na Capa (Template) | "no fim da galeria correspondente"; um lugar só no app |
| F3 ••• | No canto do cartão, fora da amostra (substitui o texto da D3 no DESIGN_PROJECT) | decisão nova do dono vale sobre a antiga |
| F5 foto | Foto não tem Part: o painel fica sem abas; Trazer à frente/Enviar para trás em Show | não há trecho numa foto |
| F16 Reset | Volta à proporção da gravação, Fill, sem deslocamento, Follow face desligado | o "original" do vídeo |
| F18 Box | "Box" como o dono escolheu (cobre sombra, contorno e caixa) | decidido |

## Entregas (commits separados; um build por vez)

Ordem: primeiro o que é independente e pequeno, depois o que mexe nos componentes comuns (cabeçalho, abas, memória), por fim layout e exportação.
Ajudantes (até 2) só em entregas de arquivos separados, cada um no seu worktree; integro e valido o conjunto antes de fechar.

| Entrega | Itens | Evidência esperada |
|---|---|---|
| **1 · Correções independentes** | Erros 1, 5, 8, 11, 12 (ES); F6; F7; F8; F9; F11; N2; verificações Volume › Avançado e Fundo › Recorte; R5 Center and fill (teste) | unidade por erro (reset só do volume da mídia + Undo, nota de Batidas por origem, aba de Velocidade por clipe, aviso do Follow face sem a proporção atual, curva preservada em Normal↔Curve); UI: Fade out alcançado, Recorte achado e marcado ativo; capturas antes/depois no 17 e SE |
| **2 · Desfazer e resets** | Erro 3, R5 (nomes de Desfazer, Auto/Measure em Ajustar, resets com escopo, Fundo) | unidade: nome certo do Desfazer em pausas, respiro, batidas, velocidade, zoom, look; toques reais do Auto antes/depois (UI) |
| **3 · Memória e folhas** | R7, R11, R4 (folhas altas), F13, F14 | unidade: aba/Avançado por painel e por item, rascunho do TTS e do Kit volta, descarte pede confirmação com número; UI: escolher 3 vídeos, tirar 1, continuar = 2 na ordem; Música e Efeitos com abas e Browse Files perto da busca |
| **4 · Cabeçalho e Texto** | R1, R2, R3, F3, F4, erro 4, ••• do cartão | 20 idiomas nos subtítulos; unidade: alcance Texto→Motion→Texto, cópias contadas com Desfazer do lote; UI: quatro abas, Animated como filtro, Kit em painel próprio; capturas 17/SE/texto grande e alemão |
| **5 · Legendas** | F1 (Emphasize line / Enfatizar linha, Choose words to emphasize), F2 | UI: do Estilo › Custom até a linha sob a agulha e de volta ao estilo no mesmo ponto; galeria com estilos à vista ao abrir; "Texto por legenda" medido em de/fr/it/nl e árabe |
| **6 · Movimento, mídia e nomes** | F15 (ordem + segurar inteiro só na prévia), F5, R12, R6, erros 9 e 12 (resto) | unidade: prévia mostra o Pop inteiro parado na entrada sem mover a agulha, exportação igual (`PreviewMatchesExportTests`); stepper repete ao segurar; nomes iguais nos 20 idiomas; UI no mesmo projeto: mídia em janela, trecho, volume, animação |
| **7 · Limpar fala** | F10, M3, erro 7 (§61 emendado) | UI: fileira de pausas ao abrir, ajustes pelo cabeçalho, rodapé numa linha; tocar na marca leva ao cartão aceso; dica de palavras com pausas pré-marcadas |
| **8 · Done, exportação e proporção** | F17, erro 2, R9 (varredura), F19, D11, erro 10, F16, erro 11 | UI: Done legível em AX5, opções dentro da folha do Done com ‹; dimensões reais (606×1080) no Done e no **arquivo** exportado; legendas original/tradução/ambas/desligadas conferidas nos pixels do arquivo; escolha restrita ao vídeo |
| **9 · Fontes e Capa** | F12, F18, R8 (Capa, Kit, etiqueta do Gráfico), Capa preserva a agulha (R10 §7.2) | UI: Remover pelo grupo My fonts e por segurar, projeto com fonte removida abre; Capa com teclado mostra destaque e Line above; voltar da Capa com a agulha onde estava |
| **10 · Timeline e barra** | R10 (§7.3: régua + faixa do item acima dos painéis cheios, botão de recolher no SE), M2, N1 | capturas 17 e SE com uma fileira inteira de estilos + régua; UI: recolher e voltar preserva item, estilo e agulha; marca de aplicado acompanha troca de clipe, Reset e Desfazer; alvo da marca de Transição de 44 pt só sem clipe escolhido |
| **11 · Validação de ponta a ponta** | §5.3–5.5 do dono | fluxo talking head completo com take real (Simulator + iPhone), projeto existente, fechar e reabrir; vídeo curto no iPhone + roteiro para o dono; relatório separa aparelho × Simulator × código |

D16 (§5.6): nada da automação de limpeza muda nestas entregas; os casos difíceis no aparelho continuam pendentes antes de ativá-la.

## Item por item

| Item | Entrega | Item | Entrega | Item | Entrega |
|---|---|---|---|---|---|
| R1 | 4 | F1 | 5 | F14 | 3 |
| R2 | 4 | F2 | 5 | F15 | 6 |
| R3 | 4 | F3 | 4 | F16 | 8 |
| R4 | 3, 7, 10 | F4 | 4 | F17 | 8 |
| R5 | 2 | F5 | 6 | F18 | 9 |
| R6 | 6 | F6 | 1 | F19 | 8 |
| R7 | 3 | F7 | 1 | M1 | adiado |
| R8 | 9 | F8 | 1 | M2 | 10 |
| R9 | 8 | F9 | 1 | M3 | 7 |
| R10 | todas; 9, 10 | F10 | 7 | N1 | 10 |
| R11 | 3 | F11 | 1 | N2 | 1 |
| R12 | 6 | F12 | 9 | | |
| | | F13 | 3 | | |

Erros: 1→1, 2→8, 3→2, 4→4, 5→1, 6→1 (F6), 7→7, 8→1, 9→6, 10→8, 11→1, 12→1 (ES) e 6 (Volume na barra da tela dividida).

## Estado

| Entrega | Commit | Estado |
|---|---|---|
| 1–11 | | a fazer |
