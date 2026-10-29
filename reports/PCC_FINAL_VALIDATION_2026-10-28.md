# PCC — validação da entrega de 28/10/2026

## Fonte e escopo

Branch `codex/pcc-offline-review`, baseada na main69df2ac5 (PR76 incorporado por ae937739). Contém integralmente `codex/pcc-content-engines`; abrir somente um PR offline-review → main. Nenhum PR ou merge na main foi criado nesta continuação.

O app normal mantém duração informativa no Automático, perfil completo como orientação contextual, prioridade do pedido/perspectiva, rascunho estruturado, proteção literal e limites de chamadas/privacidade. Prosa livre, projeção reduzida de voz, exemplos, revisão e planejamento não foram promovidos. O candidato de cenas foi retirado. As 59 solicitações PCC desta continuação estão nos fixtures e nos relatórios PHASE3, PHASE4 e REJECTED_SCENES. Não há comprovação de paridade editorial com os textos de comparação nem de ausência de alucinações.

## Verificações anteriores às correções da regressão

- Compilações limpas para simulador, SDK do iPhone e Release: zero warnings, sessão5574.
- Testes dirigidos de contratos/perspectiva/snapshots e duas antigas falhas de UI: 13 aprovados, `only-20261028-204705.xcresult`.
- Instrumentos Python de qualidade: 9 testes aprovados.
- Instalação normal nos dois iPhones concluída; Iago abriu. Mansuelli estava bloqueado para abertura automática. Assinatura válida e entitlement PCC presente. Essas instalações antecedem o ajuste de Canvas abaixo e precisam ser atualizadas após validá-lo.

## Full após integrar a main

Unidade: `full-unit-20261028-211116.xcresult`:4476 aprovados,1 falha,97 pulados,1 falha esperada;381s. Interface: `full-ui-20261028-211834.xcresult`:392 aprovados,3 falhas,95 pulados;4047s. Esta rodada não foi verde.

| Falha | Evidência | Correção aplicada |
|---|---|---|
| QuickEditPlayer / playingMovesTheClockAndStopsAtTheEndHandle | Linha109, verificação intermediária de isPlaying; xcresult capturou currentTime1.0, ready e isPlayingfalse, exatamente no fim do corte de1s. A verificação imediata após play passou. | O teste mantém início, avanço, parada e limites do corte; após a espera aceita reprodução ou chegada ao mesmo fim já exigido no resultado final. Não muda o player. |
| TextSize / boas-vindas | Retângulo AX(16,703.78,483.12,122.44) numa tela402×874; vídeo mostra cápsula visual inteira na tela. A faixa SwiftUI rotacionada saía do layout antes do clip. | ShineSweep desenha a mesma faixa/gradiente/rotação dentro de Canvas de tamanho fixo, recortado pela mesma forma. Preserva duração, tamanhos e texto. A conferência posterior do pico do brilho exigiu reduzir sua opacidade de55% para35%, descrita abaixo. O teste verifica os limites e toque durante6s, cobrindo um ciclo de brilho. |
| ClipBar / fade de clipe mais alto | Parou antes do teste de áudio: esperava Clip2of3 e encontrou Clip2of4. SampleEdit.demo já começa com2 clipes, mais os2 cortes criados pelo teste. | Começa com edição simples de1 clipe, mantendo2 cortes, seleção do clipe do meio, volume maior, fade e verificação de reprodução. O vídeo de teste sem áudio não substitui validação de áudio real no aparelho. |
| ShareTo / Not yet e Yes | Linha121, primeiro Send após Share não apareceu. Vídeo terminou ainda na escolha da rede, sem exportação iniciada. Logs do runner também registraram erros do servidor AX remoto; a causa completa não foi isolada pela gravação. | O helper espera o botão inicial estabilizar e confirma que está alcançável antes do primeiro toque. Mantém exportação, Not yet, reenvio, Yes e tela de envio. |

Esses arquivos estavam iguais aos da main antes dos ajustes. Isso não prova sozinho a causa de todas as falhas.

## Repetições dirigidas

Sem mudar o código: player e ShareTo passaram em 3 repetições cada, resultado `only-20261028-222747.xcresult`,144s. Evidência de sensibilidade à carga/animações, sem apagar a falha do Full.

Após os ajustes acima: os 4 casos passaram em 3 execuções cada, **12 execuções aprovadas**, `only-20261028-223213.xcresult`,456s. xcresulttool confirmou “Test case with 3 runs / Passed” para cada caso. SwiftLint estrito e git diff --check passaram.

## Conferência final dirigida — concluída

O dono orientou explicitamente rodar somente as partes pertinentes à correção para ser mais rápido: não será repetido o Full. A rodada completa original permanece registrada como falha, com os quatro casos ajustados aprovados nas repetições dirigidas.

Captura PNG + hierarquia das boas-vindas aprovada: `only-20261028-224031.xcresult`,71s. Auditoria da subárvore visível onboarding.root:23 textos, mínimo6,52:1; botão14,88:1 nesse quadro. A árvore AX integral também contém a tela Scripts coberta, cujos retângulos não correspondem ao texto visível da captura; o original foi preservado.

A captura estática não cobria o pior instante da animação. Medição dos pixels do vídeo no pico da faixa branca de55% encontrou cerca de2,80:1 sobre a tinta. A faixa foi reduzida para35%. Um novo teste renderiza o próprio componente no pico, confirma que a faixa está presente e exige4,5:1 tanto no contraste normal quanto aumentado. Não basta medir somente os tokens sem a sobreposição.

A compilação limpa da sessão99400 passou simulador e SDK iPhone com a fonte55%, mas foi interrompida durante Release para corrigir o contraste real; não é aprovação final da fonte35%. Uma tentativa de teste foi interrompida após SwiftLint acusar comprimento do arquivo de testes; o novo caso foi separado em extensão, com lint estrito aprovado. A primeira compilação do novo teste também identificou uma tentativa de definir um EnvironmentValue somente de leitura; a definição foi removida, mantendo a exigência de que a faixa esteja presente na imagem. Não houve falha de produto nessa tentativa.

**Validação final dirigida aprovada:** `only-20261028-232531.xcresult`,56 testes,0 falhas,0 pulados,157s. Inclui PaletteContrastTests, o novo teste do componente no pico (mínimo4,5:1 normal/aumentado) e boas-vindas no maior texto. A captura atual foi inspecionada visualmente e medida em `build/inspection/welcome-shine35/audit-visible`:23 textos, mínimo6,52:1, botão14,88:1 no quadro estático; limites370×54pt dentro da tela. A verificação do pico é separada da medição estática.

**Compilações limpas finais aprovadas:** sessão27453 exit0, simulador, SDK iPhone e Release, zero warnings. Correção e teste enviados ao remoto em `f7c90f57`. Sem nova matriz PCC e sem novo Full.

**Instalações finais concluídas:** Iago, sessão40381 exit0, build assinado aprovado, instalado e aberto sem argumentos de teste. Mansuelli, sessão18738 exit0, mesmo binário final instalado diretamente depois de confirmar que o provisioning inclui seu UDID. A recompilação redundante da sessão4681 foi cancelada somente enquanto aguardava o lock; nenhuma compilação da outra sessão foi interrompida. Abertura automática no Mansuelli recusada por aparelho bloqueado (sessão93371); instalação permanece concluída e pode ser aberta manualmente. Assinatura verificada com codesign e entitlement PCC=true.

A sessão paralela skin-beauty voltou a executar testes no Iago depois da nossa instalação; ela pode substituir o app desse aparelho por seu próprio build. O registro acima comprova nossa instalação, não reserva o dispositivo contra alterações posteriores de outra sessão. Nenhum teste automático foi executado no Mansuelli nesta entrega. Não houve PR nem merge na main.
