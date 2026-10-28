# Continuação isolada sem recursos de execução — 28/10/2026

## Isolamento

Claude Code usa /Users/iagoxavierdelima/Desktop/Projects/CueStudio. Esta continuação está na worktree /Users/iagoxavierdelima/.codex/worktrees/pcc-offline-review/CueStudio, branch codex/pcc-offline-review, criada a partir de ebed0ec1. Não modificar o checkout principal nem fazer merge nele enquanto a outra sessão o usa. Não foram iniciados builds, simuladores ou testes de aparelho nesta continuação.

## Resultado final da bateria já existente

- Unidade:4406 passaram,1 grupo falhou,98 pulados,1 falha esperada. Resultado original full-unit-20261028-132841.xcresult no build/results do checkout principal.
- UI:386 passaram,2 falharam,95 pulados;483 no total,4064s (~68min). Resultado full-ui-20261028-133424.xcresult. Processo finalizado, sessão73360 encerrada com exit65. Não declarar Full aprovado.
- O resumo inicial de que havia só duas variantes de snapshot estava incompleto: a árvore detalhada do xcresult mostra **13 variantes** falhando no mesmo grupo; a persona yoga, com duração explícita, não falhou.

## Correção preparada sem executar o app

Treze fixtures VoiceBriefs/v2 mantinham duas linhas de duração obrigatória. Foram substituídas apenas pelo parágrafo da política informativa já aprovada pelo dono. A alteração foi comparada byte a byte com o prompt efetivamente capturado em cada falha do xcresult: os13 arquivos agora coincidem integralmente com a saída registrada. Nenhum outro trecho foi modificado e o snapshot yoga com duração explícita permaneceu intacto. Isso é verificação estática de consistência, não um novo teste Swift aprovado.

Quando os recursos estiverem disponíveis, rodar desta worktree:

`scripts/test.sh only "Cue StudioTests/VoiceBriefSnapshotTests"`

Não usar --no-build no primeiro teste desta worktree: ela ainda não tem DerivedData. Não chamar xcodebuild direto.

## Falhas de UI ainda sem correção

1. CreatorWalksUITests/testABrandKitMadeHereGoesOnAnotherVideo: o teste não encontrou app.buttons["close"] após tocar o ColorPicker do kit. Esse dado não distingue falha de apresentação, seletor incompatível ou sincronização. O componente fica em Screens/QuickEdit/Panels/Controls/PanelSwatches.swift; fluxo em Sheets/Brand/BrandKitEditorSheet.swift. Não enfraquecer o teste nem substituir por sucesso fictício; consultar captura/hierarquia e reproduzir isoladamente quando possível.
2. TextSizeUITests/testTheWelcomesButtonIsOnTheScreenAtTheLargestTextSize: frame de Get started (16,703.7813,435.117,122.437) em tela402x874; a borda direita chega a451.117, excedendo a tela em49.117pt. O teste reporta overflow horizontal, não botão abaixo da tela. WelcomeChapter cria o botão em um ZStack e OnboardingPrimaryButton usa maxWidth.infinity. Não foi confirmada a causa; não alterar a asserção para ignorar o overflow. Verificar captura e proposta de largura do layout antes de corrigir. A correção precisa respeitar o design e passar por captura/contraste se houver mudança visual.

Também houve dois avisos de runtime sobre inversão de prioridade QoS no resultado de UI, ainda sem investigação. Isso é diferente da compilação limpa, que passou sem warnings antes desta continuação.

## Próxima evolução editorial

Experimentos de exemplos e revisão permanecem desligados por falta de ganho consistente. Próximas hipóteses, ainda não implementadas: evitar que assuntos habituais do perfil substituam o assunto atual e testar uma primeira redação em prosa livre. Não usar as respostas de referência do mesmo caso como exemplos de entrada e depois alegar melhora em benchmark independente. Não publicar textos privados de build/private-writing-comparison.
