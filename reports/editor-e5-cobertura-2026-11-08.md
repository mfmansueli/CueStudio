# Etapa 5: cobertura do plano (varredura de 08/11/2026)

Fontes lidas: plano `editor-plano-implementacao-2026-11-06.md` §11–§17 e §19 (checkout principal), `editor-trust-matrix.md`,
`editor-e3-canvas2-decisoes-2026-11-07.md` §6, `editor-e4-decisoes-2026-11-07.md`. Dono, 08/11: "Pode seguir em frente sem eu testar, eu quero
testar tudo quando terminar todas as fases" (o teste do dono é um só, no fim; o que o plano manda "apresentar para aprovação" é feito e marcado
para ele confirmar nesse teste).

## A. O que a varredura achou do E4 ainda aquém

| Item | Fonte | Estado em a0eb193f | Entrega |
|---|---|---|---|
| Seleção do trecho **na timeline principal**, alcance dito **antes do primeiro gesto** | canvas 2 §6, decisão D | Só por Select no painel; o alcance aparece durante o arraste | Place e Zoom na barra da legenda escolhida na timeline; o cabeçalho do menu nomeia a linha e o tempo |
| A timeline mostra onde o zoom por frase cai | regra "timeline always shows where a change lands" | Só a lupa no cartão do painel | Marca na legenda da faixa |
| **Zoom nos cortes** em um passo (12.1; R1.3/R2.1: 9–10 toques) | §11, matriz 12.1 | Não feito (o "Use on every cut" é transição) | Agente B |
| **Zoom centrado no rosto** quando confiável, sem trocar de pessoa (12.6) | §11 | Zoom por frase no centro do quadro | Agente B |
| Follow face em **vídeo horizontal importado**; aviso com duas pessoas | §11, matriz `auto-reframe`, §19 | Aviso só lê a análise da take | Agente B |
| Limite de resolução do zoom (horizontal cortado em 606 px) | §11, §19 | Só o limite de escala | Agente B |
| Preferência de **zoom no kit** (Meu estilo › Editing) | §14, matriz `saved-recipe` | Esperava o zoom por frase | Agente B (depois de zoom nos cortes) |
| Cores da legenda só depois de rolar (R1.6) | matriz | Não conferido | Eu: conferir na tela, corrigir se preciso |
| Respiração e sibilância | §13 | Não ligados | **Não fazer:** o plano pede benefício audível e o dono ouvir casos reais; fica registrado |
| Transientes nos cortes, uniformidade entre clipes | §13 | Já existem (mergulho no corte em `EditedComposition`, `VoiceLeveling`) | Só registrar |

## B. Etapa 5 propriamente

| Fluxo | Plano | Entrega |
|---|---|---|
| **Recorte estável** | §13: estabilizar a máscara no tempo antes de qualquer régua de borda; não revelar o fundo original num quadro que falhou sem o criador perceber; comparação e controle compreensíveis | Agente A: suavização no tempo (pedido de sequência do Vision), quadro que falha segura a última máscara boa por pouco tempo e depois avisa; o painel diz onde falhou e leva lá; comparação |
| **Pessoa recortada posicionável** | §13, matriz 12.10, R4.3, §19 (vira item de mídia; Photo/video, Show \| Part, F5) | Agente A: a pessoa move e escala sobre o fundo; o fundo aceita vídeo; prévia = arquivo |
| Validação do recorte | §13: cabelo, mãos, movimento, iluminação, falhas seguidas, prévia/exportação | Agente A, no iPhone (Mansuelli), em cópias em memória |
| **Quick pass** | §19 A: no Clean up, só fala (pausas, hesitações, repetições); ver antes, revisar tempos, desfazer inteiro | Eu |
| **Edição automática completa** | §14 + §19 A: ponto de entrada próprio (o Smart saiu na D1); etapas revisáveis e desligáveis sem apagar o resto; comparar antes e depois; cancelável e recuperável; preserva a edição manual; sem música, efeitos, estilos ou cortes que o criador não escolheu | Eu; **ponto de entrada marcado para o dono confirmar** |
| Cortes movem legendas, áudio e mídias | canvas 2 §6, aceitação de §19 | Teste num projeto com ajustes manuais |
| Tarefas 6 e 7 de §16 | §16 | Cenários de UI no fim: repetir o estilo num vídeo novo; zoom e composição com a pessoa recortada |
| Full | regra do dono | Uma vez, depois de tudo |
