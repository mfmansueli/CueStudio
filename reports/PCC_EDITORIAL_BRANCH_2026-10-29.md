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

## Primeira leitura: opinião PT, uma repetição

Quatro respostas PCC preservadas em quality-run-editorial-v1-opinion-r1.json. Teste passou tecnicamente (1 teste,71s total; geração das quatro condições22s incluindo pausas). Baseline3,25s; stack-guided2,52s; lean-guided1,90s; lean-raw1,68s. Texto de instruções+pedido caiu de10720 para2915 caracteres; isso não é contagem de tokens.

Não há ganho editorial demonstrado: todas continuam pouco desenvolvidas, com analogias de música/trilha. Lean-guided mistura banda e bicicleta; lean-raw usa bicicleta de olhos fechados e termina com pergunta de engajamento não solicitada, apesar da instrução de não forçar CTA. Stack-guided teve concordância ruim (“Se eu forçando”). Mais rápido/curto não significa melhor. Não promover nenhuma alternativa por esses resultados.

Próximos controles no mesmo binário: equipamento e tutorial, uma execução cada, quatro condições. A referência do assistente ainda desenvolve uma distinção, consequências e exemplo com mais clareza; a medição inicial não reproduziu esse nível.

## Triagem completa v1: três pedidos PT

Doze solicitações (quatro condições×três casos),11 textos e1 recusa de segurança do framework. Equipamento: device-20261029-001631,1 teste aprovado tecnicamente; tutorial: device-20261029-001944,1 teste falhou porque lean-raw retornou “Streamed response may contain sensitive or unsafe content”. O erro foi preservado no quarto registro. Não contornar as guardrails nem chamar isso de sucesso.

Equipamento: lean-guided trouxe relação incoerente entre compra, brilho e som e “Eu já vi” sem suporte. Lean-raw continua superficial. Baseline também diz “Eu vejo isso todo dia” sem suporte; schema atual não resolve fidelidade sozinho. Tutorial: baseline inventa distância de1–2m como regra e generaliza horário da luz; lean-guided trata celular como refletor e não explica bem os ajustes. Nenhuma alternativa aprovada para produção. Resultado negativo registrado; não vender redução de caracteres/tempo como melhoria de qualidade.

## Próximas ablações delimitadas

Verificar a mesma pergunta sem perfil (full versus none), depois raciocínio deep mantendo o resto, depois um preset de amostragem explícito. Amostragem criativa = randomTopP0,95/temperatura0,8/seed17, um preset conjunto; não atribuir eventual diferença isoladamente à temperatura. Default permanece nil, não foi demonstrado qual política interna o PCC usa. Nenhuma alteração em modelos/guardrails nem provedores. As configurações e o texto enviado ficam gravados. A execução só segue para uma configuração de cada vez, sem repetir a matriz inteira.

Deep já foi tentado com planejamento na rodada anterior sem ganho. Testá-lo agora sem perfil, sem planejamento, sem schema e com prompt enxuto é uma configuração diferente; não esconder o resultado negativo anterior. Ainda não há ganho comprovado. Testes de configuração e contratos atualmente na sessão22394, only-20261029-002307.xcresult; fonte experimental congelada durante a compilação.

## Configurações v2

A primeira compilação only-20261029-002307 identificou import FoundationModels ausente no teste de propriedades de GenerationOptions. Corrigido sem mudar o produto. Reexecução only-20261029-002822:5 testes aprovados,0 falhas,102s, sem warnings observados. Novas configurações mantêm defaults v1 e rejeitam valores inválidos/duplicados; presetcriativo não pode ser aplicado ao baseline que não o suporta.

Primeiro controle v2 solicitado: editorial-v2-none-default, opiniãoPT, somente lean-raw, sem perfil, amostragem/raciocínio padrão; sessão46461. Ainda sem resultado neste checkpoint. O controle deep será comparado a esse mesmo semperfil; o presetcriativo também, sem misturar fatores. A recusa do tutorial não prova que o framework errou: não temos o texto bloqueado para distinguir falso positivo de conteúdo gerado problemático.

## Resultados v2 e novo controle editorial v3

Três controles sem perfil concluídos, uma resposta cada: default2,34s (device-20261029-003028), deep2,34s (device-20261029-003420), presetcriativo1,79s (device-20261029-003600). Dados quality-run-editorial-v2-none-*.json. Default sem perfil teve parágrafos mais desenvolvidos que o raw com perfil, mas continua vago e mistura música/ciclismo. Deep não demonstrou ganho claro; exemplo de gravar café pode ser interpretado como hábito pessoal não fornecido. Creative voltou a um parágrafo curto e genérico. Uma repetição não demonstra causalidade estável nem teto do modelo. Não promover deep, amostragem ou retirada de voz por isso. Total desta branch até aqui:15 solicitações registradas,14 textos e1 recusa; contagem de solicitações não é contagem exata das inferências internas do baseline.

V3 adiciona editorial-raw (orientação de monólogo desenvolvido, distinção/razão/exemplo/consequência, uma analogia em vez de metáforas como substituto de argumento) e editorial-demo-raw (mesma orientação mais conversa sintética de exemplo sobre caixas e organização da casa). A demonstração é texto contínuo em papéis reais de usuário/assistente no Transcript, não quatro exemplos esquemáticos anexados à pilha antiga. Não é nenhum dos três textos de referência do benchmark. Ela é guardada inteira no campo editorialExampleInstructions do sample. Nunca aplicar ao próprio pedido da demonstração.

Código de apoio e testes foram agrupados em Support/EditorialExperiment e Managers/EditorialExperiment conforme arquitetura. Sete testes aprovados em only-20261029-004046,195s, sem warnings observados. Incluem papéis do transcript, preservação das instruções, inexistência de pedido idêntico na base congelada e igualdade do conteúdo do pedido quando só muda o enquadramento editorial.

Primeira v3 em andamento: sessão29435, run editorial-v3-none-opinion-r1, opiniãoPT sem perfil, modos lean-raw/editorial-raw/editorial-demo-raw, raciocínio e amostragem padrão. Fonte congelada durante execução; ainda sem resultado neste checkpoint. Nenhuma alteração no writer normal/Release, nenhum provedor externo, nenhum treino, nenhuma flexibilização de guardrails.
