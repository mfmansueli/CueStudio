# Nova branch editorial — 29/10/2026

## Base e autorização

Branch codex/script-editorial-quality criada de origin/main0fd19d1a, após merge PR77. Reutiliza worktree isolada pcc-offline-review; não altera checkout principal nem skin-beauty. O dono deu liberdade para mudar o fluxo e testar outras instruções com qualidade comparável às referências do assistente, e pediu explicitamente branch nova. Isso não demonstra que o objetivo já foi atingido.

## Primeiro experimento: separar instruções e schema

Somente código no target de testes. O caminho normal e Release permanecem iguais à main. Um caso congelado por execução, mesmo pedido, perfil sintético completo, plataforma e teto de resposta. Quatro condições, sessões novas:

1. baseline: serviço real atual, com suas verificações/correções e até duas chamadas. Registrar essa diferença de custo ao comparar.
2. stack-guided: pilha atual de ScriptPromptBuilder, PCCProseDraft, uma chamada.
3. lean-guided: instruções editoriais enxutas, contexto de voz permitido inteiro, mesmo PCCProseDraft já existente, uma chamada.
4. lean-raw: exatamente as mesmas instruções/prompt de lean-guided, resposta String sem schema, uma chamada.

Isso NÃO repete a antiga ablação de prosa com a pilha inteira de instruções. Stack-guided versus lean-guided muda somente a pilha de instruções/prompt, mantendo schema, dados e uma chamada. Lean-guided versus lean-raw muda schema mantendo instruções/prompt. Baseline é controle de produto, com suas correções; não atribuir toda diferença dele ao schema ou às instruções. Perfil não é descartado. Não se enviam respostas de referência nem critérios de julgamento como gabarito. Não usa provedor externo, API paga ou novo treinamento. Raciocínio padrão nas quatro condições; aprofundamento pode ser uma variável posterior, isolada.

Medição em ScriptQualityDeviceTests/comparesEditorialPromptAblations(), opt-in CUE_QUALITY_EDITORIAL_ABLATION=1. Cada alternativa tem prazo60s, grava texto integral sem pós-edição e tempo no mesmo formato QualityRunSample; só aceita rota privateCloud no baseline. Falha/timeout é registrado, não aprovado. Sem chamadas extra de reparação nas alternativas; literais, idioma, agência e cumprimento de instruções serão julgados explicitamente, não inferidos de texto não vazio. Não comparar custo/segurança de um protótipo cru como se já fosse produção.

## Critérios editoriais

Avaliar progressão do argumento, exemplo útil, explicação causal, oralidade, personalização sem contaminar assunto, aderência ao pedido, perspectiva, fidelidade factual/biográfica e latência. Não pontuar só por palavras nem alegar ganho consistente com uma amostra. Notas sérias e frases literais são controles de regressão; tutorial precisa de revisão técnica. As referências do assistente são um alvo editorial, não fonte factual nem verdade absoluta. O assistente teve contexto das críticas anteriores, portanto a comparação inicial não é um ensaio controlado entre capacidades máximas de modelos.

## Estado

SwiftLint estrito passou nos três arquivos novos. Dois testes de contrato aprovados em only-20261029-000654.xcresult,214s, sem warnings observados. A primeira chamada queued71669 foi cancelada apenas enquanto aguardava o lock, para completar o controle de mesma estrutura; substituída pela69682, encerrada exit0.

Primeira medição real solicitada no Iago: sessão38951, device-20261029-001357.xcresult, run editorial-v1-opinion-r1, caso pt-BR-editorial-draft, quatro condições. Ainda aguardando execução; não há resultado nativo desta branch neste checkpoint. Referências da conversa preservadas separadamente em research_notes/Editorial refinement/assistant_references_2026-10-29.json, nunca enviadas como gabarito ao modelo.

Instalações normais anteriores pertencem à entrega anterior. Nenhum Full solicitado/iniciado. Não declarar qualidade melhor sem ler os textos reais. A nova branch é experimental, não está pronta para merge por ter passado apenas contratos.
