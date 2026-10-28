# Checkpoint PCC — 28/10/2026

Branch: codex/pcc-content-engines. Checkpoint solicitado pelo dono antes do fim do limite de tokens. Não é aprovação final de qualidade.

## Entrega preservada

Entitlement PCC habilitado no portal e confirmado no perfil e assinatura. Roteamento, deadlines, fallback, orçamento por rota e privacidade refinados. Exemplos brutos de voz e trechos importados ficam fora do PCC; preferências e fingerprint seguem. Automático decide a direção pelo pedido na própria geração; Talking head manual é preservado. Brief não promove placeholders a fatos. Proteção de frases explicitamente exigidas usa verificação e correção limitada, recusando resultado ainda inválido; não insere frase ausente. Último ajuste protege frases já presentes durante limpeza e normaliza NFC na comparação.

Pesquisa e fontes: Roteiros AI melhores no Cue.md e research_notes/Roteiros AI melhores no Cue/. Fixtures de prompts e saídas: Cue StudioTests/Fixtures/ScriptQuality/. Nada foi alterado no protótipo.

## Evidência e limites

16 saídas reais PCC arquivadas: seis baseline, dois controles de literal e oito casos protegidos. Rota privateCloud confirmada. Baseline: aproximadamente 2,3–4,1 s. Protegidos: aproximadamente 2,5–5,6 s; literal PT precisou de duas tentativas. Literais PT/EN/ES passaram na versão protegida. Qualidade geral NÃO aprovada: frases artificiais, passos pouco distintos, workshop/taller sem suporte no brief transmitido. Não prometer ausência de alucinações ou superioridade. Outros idiomas não validados fisicamente. Reasoning padrão não alterado; override é só para medição.

4.289 testes Fast passaram antes dos últimos refinamentos. Última rodada focada: 34 passaram, zero falhas (build/results/only-20261028-013110.xcresult), incluindo proteção literal, requisitos, voz e idioma. Outras rodadas focadas passaram; Python: seis verificadores de intenção e três de relatório. Catálogo sem traduções faltantes. Conferência limpa de warnings passou antes dos últimos ajustes e precisa ser repetida. Full final ainda pendente.

Contraste: capturas reais de simulador em build/pcc-captures e auditoria build/pcc-contrast-audit.txt, escala 3. Textos visíveis >=6,01:1; relatório também lista elementos cobertos/decorativos que não são texto visível.

## Aparelhos

iago Lima iphone: instalado e usado para testes PCC. Autorizado para automação. Teste UI PCCPrivacyUITests concluído: 1 passou, zero falhas; build/results/device-ui-20261028-013138.xcresult.

Mansuelli iPhone 18 Pro Max (00008160-0014398611100036): conectado na nova tentativa, build Debug concluído, app instalado e aberto com sucesso (com.cuestudioteleprompter). Disponível para testes manuais do dono e Mateus; manter automação no Iago. Comando usado:

```sh
CUE_DEVICE="Mansuelli iPhone 18 Pro Max" scripts/build.sh install
```

## Próxima sessão

1. Colher feedback dos testes manuais no Mansuelli; instalação e abertura concluídas. UI de privacidade no Iago passou.
2. Revalidar no Iago a última proteção de limpeza (34 testes locais passaram, execução física dessa última alteração ainda pendente).
3. Rever textos reais por fidelidade, fatos, voz, naturalidade, distinção dos pontos e CTA. Software passar não é aprovação editorial. Ampliar casos/idiomas progressivamente, marcando indisponíveis como não validados.
4. Quando não houver build ativo, rodar scripts/check-project.sh, scripts/check-warnings.sh e scripts/test.sh full. Não rodar check-warnings enquanto outro build usa o checkout: limpa intermediários antes do lock.
5. Registrar resultados e commit/push posteriores. Não fazer merge sem avaliar branch/base e validação.

Mudanças preexistentes excluídas do checkpoint: project.pbxproj (reordenação), 1465706025/, MARKETING_POSITIONING_MEMORY.md e reports/claude-code-auditoria-lacunas-e-validacao-2026-10-22.md. Não descartar nem incorporar automaticamente.

## Continuação urgente — últimos ajustes ainda em validação

O dono pediu textos menos genéricos, melhor uso do My Cue Voice/PCC e mais conteúdo para lapidar, mirando o teto da duração escolhida, com pequeno excesso aceitável. Exemplo dele: TikTok de 60–90 s estava entregando menos de 60 s. Tratar esses pedidos como requisitos persistentes.

Implementado APÓS a instalação no Mansuelli, ainda sem comparação física:

- VoiceBriefBuilder recebe contextualPreferences (padrão false). No PCC, abertura/fecho são preferências condicionais e bordão é opcional; abertura narrativa só com experiência fornecida. Identidade, ritmo, fingerprint, vocabulário e restrições continuam no brief. A rota local conserva instruções anteriores. What Cue sends usa o mesmo brief condicional para PCC.
- PCCScriptDirection.platformLine define registro/ritmo sem impor CTA, história pessoal ou venda. Motivo concreto: fixture es-ES-product mostrava simultaneamente instruções de história, bordão e seguir/salvar, produzindo taller inventado e metatexto genérico. Direção pede ação observável + motivo + critério de comparação e remove frases sobre explicar/ajudar que não entregam substância.
- askedRange no PCC agora mira 90–105% das palavras do teto escolhido a 150 palavras/minuto: 60–90 s -> 203–237 palavras; 120–180 s -> 405–473. Pequeno excesso é permitido como material para edição. Prompt diz que limite explícito de palavras/tempo no pedido tem prioridade e proíbe preencher com repetição/fatos inventados. Isso é meta de geração, NÃO garantia da duração entregue. Ainda NÃO foi acrescentada tentativa automática por falta de palavras; medir antes de decidir, pois histórico local de expansão teve regressões. Não transferir o fator inflacionado local para nuvem.
- Novos testes em PCCScriptDirectionTests cobrem preferências condicionais/plataformas e alvo de 90 s; AIRequestPolicyTests ajustado ao alvo. SwiftLint dos arquivos alterados e diff --check passaram. Precisa confirmar execução dos testes.

Pesquisa consultada: https://github.com/microsoft/PromptWizard (Microsoft, MIT), otimização e crítica de prompts por avaliações; inspiração metodológica apenas, nenhuma dependência instalada/copied code. PCC usa o modelo Apple, não instala pesos de modelo GitHub. https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute descreve janela maior e reasoning configurável; não aumentar reasoning/calls indiscriminadamente sem comparar qualidade, tempo e quota.

### Processos e evidências a recuperar

- Sessão 44856: scripts/check-warnings.sh. Concluiu com sucesso: simulator, device e Release sem warnings. Arquivos foram alterados durante a etapa Release, portanto a rodada NÃO comprova zero warnings de todos os destinos para a última revisão: repetir depois de congelar o código e quando não houver outro build ativo.
- Sessão 69771: teste focado iniciado após o Release. Resultado build/results/only-20261028-014413.xcresult. Seleciona PCCScriptDirectionTests, ScriptIntentContractTests, VoiceBriefBuilderTests e ScriptVerbatimProtectionTests. Conferir se viu as últimas alterações; AIRequestPolicyTests precisa rodar também. Log build/logs/test-only.log.
- scripts/check-project.sh passou com acesso adequado; tentativa sem acesso ao serviço Xcode falhou por ambiente, não por estrutura. Nove testes Python em tools/quality passaram nesta continuação.
- Full final permanece pendente. Depois dos focados, medir no Iago pelo menos pt-BR-tutorial e es-ES-product com os MESMOS inputs baseline; coletar JSON e comparar detalhe/naturalidade/voz/fatos/duração. Escolher um caso literal para regressão. Outros idiomas não devem ser marcados aprovados.
- Instalar nova revisão no Mansuelli APENAS depois da verificação: a versão que está lá é a do checkpoint anterior. Instalação está autorizada; automação continua no Iago.

Não afirmar que todos os refinamentos foram concluídos nem que qualidade está aprovada. Não fazer merge automático. Preservar os arquivos preexistentes excluídos. Próximo trabalhador deve começar por este documento e git status, recuperar resultados e terminar validação antes de adicionar outra camada de geração.

## Retomada após renovação de créditos — resultado atual

- Checkpoint e5154814 tinha erro de compilação em PCCScriptDirection: append recebeu dois textos. Corrigido para adicionar os dois elementos; trailing comma corrigida. 48 testes focados passaram (only-20261028-042806), depois 46 e 37 em experimentos locais de duração. Os últimos dois conjuntos incluíam lógica experimental retirada abaixo; não tratá-los como prova da versão final.
- Nova comparação real es-ES-product: privateCloud, 3,55 s, 114 palavras, sem taller inventado e sem CTA de seguir/salvar. Ainda tem metatexto genérico. O alvo era 135–158 palavras: não atingido. Um caso favorável em precisão/CTA não prova consistência.
- Novo teste físico opt-in writesTikTokNearTheChosenUpperDuration usa fábrica real, perfil PT completo com preferência de duração removida, TikTok ideal60–90, Auto. Exige >=203 palavras; mantém a falha visível. Baseline134 palavras/53,6s. Correção genérica145/58s; reasoning moderado123/49,2s; orçamento explícito do desenvolvimento138/55,2s; expansão com próprio rascunho131/52,4s. Nenhum atingiu a meta. Não ajustar o critério para disfarçar essas falhas.
- Todos esses resultados e prompts foram coletados em quality-run-pcc-contextual-*.json e quality-run-pcc-duration-*.json. Regressão literal espanhola passou (device-20261028-043705). Os fixtures são sintéticos. O campo attempts indica revisão retida e não é medidor confiável de chamadas quando uma segunda resposta foi descartada.
- Experimentos de retry de duração (PCCDraftDevelopment, mudanças em VoiceCheckedWriting/RevisionChoice/DraftAssessment e testes temporários) foram RETIRADOS: custo adicional sem resolver o problema. Reasoning padrão permanece nil. Não reintroduzir sem nova evidência. Produção conserva duas chamadas máximas compartilhadas para correções já existentes, sem retry específico de tamanho.
- Alteração ainda presente no prompt: orçamento de desenvolvimento em palavras, sem aumentar pontos pedidos ou preencher com invenção. Não resolveu o caso TikTok e precisa ser tratada como alvo, não garantia. Fatos técnicos continuam exigindo revisão: algumas saídas sobre luz contêm diagnósticos vagos/pouco confiáveis. Não aprovado para promessa comercial de precisão.
- Sessão 23653: scripts/check-warnings.sh && scripts/test.sh full, versão congelada após retirar os experimentos. Recompila os três destinos e só então roda Full. Conferir saída/resultados antes de concluir. Nenhum outro build deve ser iniciado durante check-warnings.
- Próximos passos: terminar checks, registrar falhas reais do Full se houver, commit/push somente arquivos próprios e atualizar Mansuelli com versão compilada. Não instalar/afirmar melhoria de duração como resolvida. O problema de geração curta permanece aberto; considerar uma arquitetura de desenvolvimento por seção com orçamento de chamadas explicitamente avaliado, e contexto factual fornecido, antes de mais instruções genéricas. Não adicionar APIs pagas/chaves/provedores sem decisão do dono.

### Validação da revisão congelada

check-warnings terminou sem warnings no simulador, aparelho e Release (28/10). Full unit: 4.306 passaram, 2 grupos falharam, 94 ignorados, 1 falha esperada; build/results/full-unit-20261028-045452.xcresult. Falhas: snapshots de instrução literal (duas variantes, esperados agora corrigidos só nessa frase) e timeout de 5 min em MotionAnalyzerTests/stopsAndGoesOnWithoutMeasuringAFrameTwice. Não declarar Full aprovado. Full UI em andamento: build/results/full-ui-20261028-050321.xcresult, sessão23653. Repetição isolada snapshots + timeout de movimento na fila: sessão64187, only-20261028-050411.xcresult. Recuperar ambos antes de decidir se há regressão de mídia.

Nova versão instalada com sucesso no Mansuelli (build-install sem warnings), mas abertura automática recusada porque aparelho bloqueado. Desbloquear e abrir manualmente; não dizer que abriu nesta instalação. Nenhuma automação real foi executada nele.

Hipótese para uma próxima comparação controlada, ainda NÃO testada: o teto de resposta no caso TikTok é 1061 tokens e no caso espanhol 800. Antes de investir em múltiplas chamadas, comparar o MESMO pedido com teto PCC maior (por exemplo 8192) e registrar conclusão/truncamento e tempo; reasoning pode interagir com orçamento. Não afirmar que isso explica as respostas curtas sem medir. Apple recomenda usar maximumResponseTokens apenas como proteção e avisa que o corte pode ocorrer sem erro: https://developer.apple.com/documentation/foundationmodels/generationoptions/maximumresponsetokens e https://developer.apple.com/documentation/FoundationModels/GenerationOptions . As saídas observadas têm fechamento e schema completo, então não provam truncamento. Manter o teto local medido; fazer primeiro override de avaliação, sem alterar produção nem quota silenciosamente.

### Fechamento das reexecuções e hipótese de teto

- Full UI terminou: 366 passaram, 3 falharam, 93 ignorados em 3733s. Casos: ScriptLibraryUITests/testImproveIsOnThePageAndTheMenuLeadsToDetails, FirstVoyageUITests/testTheTipOpensTheEditorWithPolishsTipAndSkippingMovesOnToSharing, EditorUITests/testVoiceOverShowsTheScriptOverThePreviewUntilItsSwitchIsOff. Todos os três passaram na repetição isolada, sem alteração do código de UI: only-20261028-060801.xcresult (117s). Não esconder as falhas originais nem dizer que Full foi inteiramente verde; causa de instabilidade não foi estabelecida.
- Snapshots corrigidos e MotionAnalyzer/stopsAndGoesOn passaram isoladamente: only-20261028-050411.xcresult, 2 grupos, zero falhas, 91s. Não foi necessário alterar o analisador.
- Hipótese de teto foi testada, não ficou só como recomendação: override temporário exclusivamente no retorno de ScriptAIService.responseTokens para PCC, definido como8192, restaurado automaticamente em finally após cada comando. Default:127 palavras (device-20261028-061027). Moderado:146 palavras (device-20261028-061159). Ambos abaixo da meta203. Fixtures quality-run-pcc-duration-cap8192*.json registram o teto efetivamente usado. Não provou que o teto explica o problema; não mudar teto/reasoning padrão nem adicionar retries sem ganho mensurado.
- Total25 saídas PCC arquivadas. A geração perto de90s continua ABERTA. A arquitetura por seção com fontes/contexto factual pode ser uma próxima investigação, mas NÃO está implementada/aprovada e não é garantia de resultado. Não promover uma variante só por produzir mais palavras. Considerar naturalidade, precisão, pontos distintos e fidelidade à voz/pedido em mais de uma execução e idioma.
- Código de produção foi restaurado após as avaliações. Instalação normal no Iago concluída: build, instalação e abertura confirmados após restaurar o código; Mansuelli já recebeu a versão normal e estava bloqueado ao abrir.

Estado final desta retomada: nenhum experimento de retry/cap/reasoning foi promovido. Código normal instalado nos dois aparelhos; Iago abriu, Mansuelli estava bloqueado ao abrir. Zero warnings comprovado nos três destinos; Full original teve falhas, todas passaram nas reexecuções dirigidas após atualizar duas frases de snapshot. Nove testes Python passaram. Falha de duração PCC permanece aberta e os25 outputs permitem comparar as variantes sem perder evidência. Arquivos preexistentes continuam excluídos; nenhum merge realizado.
