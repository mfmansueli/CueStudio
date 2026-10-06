# Conferir o app com o quadro (handoff-telas)

Ferramentas para pôr, lado a lado, a imagem de uma tela do HTML (`design/cue-v30/handoff-telas/screens`) congelada num segundo e a mesma tela do app.

| Arquivo | Para quê |
|---|---|
| `htmlframe.py <tela.html> <T> <saida.png>` | renderiza o HTML parado em T segundos (Chrome headless, 390 × 844) |
| `dumpscreen.py <tela.html>` | lista as camadas animadas de uma tela (`motion/screens-motion.json`) |
| `appshot.sh <saida.png> <espera> <argumentos>` | abre o app no simulador (`SIMULATOR_UDID`) com argumentos de lançamento e fotografa |
| `frames.sh <nome> <tela.html> "<t1 t2 …>" <argumento de congelar> <argumentos…>` | faz os dois e monta `$FIDELITY_OUT/cmp/<nome>.png` (quadro em cima, app embaixo) |
| `cmp.py` | junta pares de imagens numa folha |

O app congela o relógio de cada tela com os argumentos de lançamento de `CLAUDE.md` (`-uiTestChapterAt`, `-uiTestWelcomeAt`, `-uiTestStoryAt`, `-uiTestSendOffAt`, `-uiTestProAt`…). Para o conjunto inteiro das
telas, `HandoffCaptureTests` grava um PNG por tela em `TEST_RUNNER_CUE_FIDELITY_DIR`. O movimento do quadro é assado em dados por `tools/bake_motion.py` e `tools/bake_galaxies.py`.
