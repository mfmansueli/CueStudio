# RETOMAR AQUI — checkpoint solicitado por limite de sessão (28/10/2026)

**ÚLTIMA ATUALIZAÇÃO ANTES DE ENCERRAR:** unidade Full terminou:4406 passaram,1 grupo falhou,98 pulados,1 falha esperada. Grupo `VoiceBriefSnapshotTests/theBriefMatchesTheKeptSnapshot(persona:)`, duas variantes, diferença de snapshot: o factory agora pede duração informativa mas o snapshot ainda espera150–225 palavras. Não corrigido neste checkpoint; ler o diff antes de atualizar o esperado. Resultado `full-unit-20261028-132841.xcresult`. UI começou em `full-ui-20261028-133424.xcresult`, ainda em execução na sessão73360. Logo, não afirmar Full verde. Os trechos mais abaixo dizendo que a unidade ainda estava ativa descrevem a verificação anterior.

Checkpoint de código25814300 e documentação cc0d6617 enviados ao origin; este adendo também deve ser enviado antes de finalizar.

O dono informou apenas8% de sessão e pediu salvar tudo para continuar quando a carga voltar. Encerrar trabalho ativo após salvar este checkpoint; não iniciar novos experimentos nesta retomada sem primeiro ler os resultados pendentes.

## Estado comprovado

- Branch `codex/pcc-content-engines`. Commit `25814300` já enviado ao origin. Não houve merge desta branch na main. A main cf54716b foi incorporada anteriormente na nossa branch via aa0a8a7f.
- Mais15 solicitações de roteiro executadas no PCC real do **iago Lima iphone**, todas com rota privateCloud; somadas às seis anteriores do experimento por exemplos,21 solicitações preservadas. Não confundir solicitações com chamadas: revisão pode usar duas.
- Revisão editorial implementada como experimento **somente Debug**, opt-in `CUE_QUALITY_EDITORIAL_REVIEW=1`; padrão false. Compartilha orçamento de duas chamadas com geração/correções. Exemplos sintéticos ampliados também continuam desligados por padrão (`PCCEditorialExamples.isEnabled=false`). Não promover: resultados mistos, sem ganho consistente. O modelo diagnosticou bem algumas fraquezas, mas frequentemente só parafraseou. Não afirmar que a precisão factual foi resolvida.
- Relatório principal: `reports/PCC_EDITORIAL_EVALUATION_2026-10-28.md`. Textos sintéticos/diagnósticos em fixtures `quality-run-review*`, `quality-run-examples2*`, `quality-run-method-*`.
- `scripts/check-warnings.sh` terminou integralmente com **zero warnings em simulador, aparelho e Release**. Sessão51683 concluída. Nenhuma alteração posterior no código do app.
- Testes focados `only-20261028-132256.xcresult`: **26 passaram**, zero falhas/skips. O primeiro ensaio falhou somente por esperar27 casos; contrato atualizado para30 e rerun aprovado. Nove testes Python de tools/quality passaram. Strings missing=0; SwiftLint e diff --check passaram.
- Compilação **normal** instalada nos dois iPhones, com experimentos desligados. Iago instalou e abriu. Mansuelli instalou, mas não abriu porque o aparelho estava bloqueado; dono/Mateus podem desbloquear e abrir. Não rodar testes automatizados no Mansuelli, reservado aos testes manuais deles.

## Regressão completa ainda em andamento — NÃO declarar aprovada

- Comando iniciado: `scripts/test.sh full --no-build`, sessão de terminal **73360**. Primeiro resultado: `build/results/full-unit-20261028-132841.xcresult`. Log unidade `build/logs/test-full-unit.log`; UI será `build/logs/test-full-ui.log` e resultado `full-ui-<horário>.xcresult` gerado após a unidade.
- Última verificação: unidade ainda ativa; xcodebuild PID74393 e host de testes PID74823, CPU ativa. Nenhum resumo final publicado naquele momento. A execução pode terminar enquanto a sessão estiver sem créditos. Antes de iniciar outro build, conferir processos/resultados e tentar ler a sessão73360. Scripts usam lock global; não chamar xcodebuild direto.
- O script Full roda unidade e depois UI em duas cópias gerenciadas, apagadas ao sair. Se falhar, ler todas as falhas e fazer reruns dirigidos; não chamar a primeira rodada de verde. Não repetir check-warnings se não houve alteração de código.
- Se o processo deixar de existir sem resumo, consultar os xcresults e logs antes de decidir o que falta. Não perder os resultados nem reiniciar toda a matriz PCC.

## Material novo para a próxima iteração

- `research_notes/Roteiros AI melhores no Cue/editorial_next_references.json`: três redações deste assistente para equipamento PT, bloqueio criativo EN e ficção ES, sem aplicar perfil. Foram escritas **depois** de ler as saídas PCC; comparação ilustrativa, não cega nem independente. Não foram entradas do PCC e não devem ser usadas como resposta-exemplo no mesmo caso avaliado.
- Hipóteses ainda NÃO implementadas: reduzir interferência de assuntos/estruturas habituais do perfil mantendo estilo/restrições relevantes; testar primeira redação em prosa livre. A ficção continuou expositiva; perfil EN desviou para exercícios e ES trouxe taller/comunidade. A revisão retirou um relato passado inventado e uma distância arbitrária, mas preservou outras afirmações ruins. Critério: desenvolvimento, cobertura, exemplos, naturalidade e fidelidade; tamanho/aceitação mecânica não são qualidade.
- Campo qualification usado nos ensaios não foi promovido; foi retirado antes da validação final. Não atribuir os resultados coletados ao esquema normal sem esse campo.
- Textos privados da comparação com o perfil real permanecem somente em `build/private-writing-comparison/E361EFD1-D340-45E7-8AEE-B07D62799E76.json`. **Não publicar no Git nem usar collect.py neles.**

## Preservar alterações alheias

Não incluir em commits: reordenação preexistente de `Cue Studio.xcodeproj/project.pbxproj`, pasta1465706025, MARKETING_POSITIONING_MEMORY.md e reports/claude-code-auditoria-lacunas-e-validacao-2026-10-22.md. Só restam nossos documentos de checkpoint/referências para salvar nesta rodada. Nenhuma worktree nova criada, nenhum agente novo delegado, nenhum provedor/API externa adicionado.

---

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

## Protótipo novo por seções — avaliação separada, não integrado ao app

Após a falta de ganho com prompts/retries/cap/reasoning, foi criado um experimento explicitamente opt-in apenas no target de testes:

- PCCSectionPlan: plano de exatamente três ajustes para o caso sintético TikTok de três ajustes. Não é classificador geral nem deve ser aplicado a declarações sérias ou pedidos de outra contagem/formato.
- PCCSectionExperiment: uma chamada de plano e três chamadas de redação, sequenciais, com perfil sanitizado (AIRequestPolicy), idioma e texto já escrito para continuidade. Sem APIs externas/dependências. Não é usado pelo app nem por testes comuns.
- Primeira variante: texto livre por seção,165 palavras,5,50s. Falhou a meta203. Fixture quality-run-pcc-sections-prototype.json.
- Segunda: PCCSectionDraft separa ação/motivo e verificação/ajuste, cada campo pede quatro frases.246 palavras (~98,4s a150ppm),6,98s; passou o teste de duração. Quatro chamadas, não uma. Fixture quality-run-pcc-sections-structured.json; device-20261028-062134.xcresult. É o primeiro ganho de duração concreto nesta comparação, mas só uma execução/PT/um caso.
- Limites editoriais reais: instrução sobre exposição é simplificada/confusa (não basta proteger a janela se o rosto é o assunto); texto repete padrões como “Isso...”/“Se...”. Não aprovar fatos ou naturalidade só porque passou na contagem. Plano introduziu temperatura de cor como terceiro ajuste nesta variante; é pertinente ao tema, mas os detalhes precisam de revisão. Fala em primeira pessoa é compatível com o perfil, não prova de experiência real. Contexto factual não vem de uma busca automática.
- Fontes primárias para revisão humana do caso, NÃO enviadas ao modelo nesta comparação: Sony https://www.sony.co.uk/alphauniverse/alpha-academy/articles/top-tips-window-light-portraits (direcionar/modificar luz e expor o rosto); Canon https://asia.canon/en/support/8200425400 (refletor ilumina o rosto e pode aumentar reflexo nos olhos). Elas também mostram por que “reflexo nos olhos sumiu = correto” das variantes antigas não serve como regra universal. Esses links não tornam o gerador um sistema de verificação factual.

Comando de reprodução (quatro chamadas PCC por execução, exige aparelho desbloqueado):

```sh
CUE_DEVICE="iago Lima iphone" TEST_RUNNER_CUE_QUALITY_RUN=pcc-sections-next \
 TEST_RUNNER_CUE_QUALITY_MODEL=privateCloud TEST_RUNNER_CUE_QUALITY_SECTION_EXPERIMENT=1 \
 scripts/test.sh device 'ScriptQualityDeviceTests/evaluatesSectionWritingForTheTikTokDurationCase()'
```

Próxima etapa técnica é generalizar o plano respeitando formato e contagem reais, não fixar três para todo pedido; comparar PT/EN/ES, fatos fornecidos, literal e tom sério; avaliar contexto factual e naturalidade e só então decidir integração/custo de quatro chamadas. O motor de produção permanece com a política anterior e a limitação de duração ABERTA. Não trocar o app pelo protótipo nem afirmar ganho consistente com uma amostra.

Total27 saídas arquivadas. Sessão80331 executa novamente check-warnings para incluir os novos arquivos de teste. A Full anterior continua válida para o app inalterado, com falhas e reexecuções descritas acima; não rerodar a Full só por um experimento opt-in se não houver nova alteração de comportamento/diagnóstico.

### Resultado final do protótipo e próxima decisão

- Segunda execução estruturada:260 palavras (~104s),6,82s, quatro chamadas, passou. Fixture quality-run-pcc-sections-structured-repeat.json; device-20261028-062943.xcresult. Esta última amostra guarda instruções e TODOS os prompts efetivamente enviados, incluindo continuidade; as duas primeiras amostras experimentais guardam resumo do pedido/plano, não o transcript completo. Não comparar campo prompt desses dois formatos como se fossem idênticos.
- Ambas as estruturadas atingiram a meta de palavras em um único caso PT, mas repetem cadência mecânica e explicações simplificadas de exposição/histograma. Não há validação semântica, de outros formatos/idiomas nem de benefício proporcional ao uso de cota. Nenhuma integração em produção.
- Check-warnings sessão80331 concluiu: zero warnings em simulador, aparelho e Release, incluindo os novos arquivos experimentais. A última repetição física também compilou sem warnings. O teste de duração de produção agora só se habilita com CUE_QUALITY_MODEL=privateCloud, para não impor uma meta PCC em medições explicitamente locais.
- Total28 saídas arquivadas. Produção inalterada desde4e2b80b9; protótipos só no target de testes, ativação explícita CUE_QUALITY_SECTION_EXPERIMENT=1. Não alegar que o app instalado usa quatro chamadas ou já entrega246–260 palavras.
- PERGUNTA FUNCIONAL ENVIADA AO DONO (ainda sem resposta nesta escrita): no Automático, priorizar a faixa da rede ou a duração habitual do My Cue Voice? ScriptRequestFactory.targetRange atualmente usa voice.reach.length quando existe, exceto Stories e plataformas de estúdio. Portanto, um perfil de30–60s pode pedir menos que o ideal TikTok60–90s. Os testes novos retiram a duração habitual do perfil sintético para medir a faixa da rede; não mostram que o app já ignora essa preferência. Esta precedência ainda NÃO foi alterada. Não confundir o problema de resolução do alvo com o problema separado de o modelo ficar abaixo do alvo recebido.
- Próxima implementação depende dessa prioridade: preservar durações explícitas do card/prompt sempre; se a rede ganhar no Auto, atualizar contratos e documentação da fábrica. O protótipo por seções precisa de plano que respeite a contagem/formato reais, fontes/contexto factual, naturalidade e avaliação PT/EN/ES antes de integrar.


## Atualização: duração informativa e avaliação editorial (28/10)

A nova hipótese do dono substitui a preferência anterior por atingir o teto da rede: deixar a geração completar o pedido naturalmente e usar a duração como informação. A implementação experimental está opt-in; o padrão normal continua targeted. Não foi aprovada uma melhora geral nem ativado o novo padrão.

Doze saídas reais privateCloud, seis pares PT/EN/ES, estão em `Cue StudioTests/Fixtures/ScriptQuality/quality-run-duration-ab-*.json`. Os mesmos casos e limites de resposta foram mantidos entre políticas. Uma execução por condição: não demonstra estabilidade estatística. Todos os testes executaram sem erro; isso não aprova a qualidade editorial.

Leitura qualitativa: aviso factual livre preservou os dados sem inventar o que o preço cobre; controle inventou que o preço cobre somente o horário. Literal livre preservou a frase sem inventar o taller do controle. Comparação livre permaneceu superficial e inventou experiência pessoal de travar diante da câmera; controle também personalizou indevidamente. Tutorial livre entregou três frases vagas, sem explicar verificações; controle desenvolveu mais, mas trouxe orientação de iluminação problemática. Correção séria livre mudou a ação coletiva para pessoal; controle inventou horário anterior e convite atualizado. Produto livre ficou mais conciso, porém pouco desenvolvido. Nenhuma política está aprovada como superior no conjunto. Próximo refinamento deve cobrar cobertura, desenvolvimento e fidelidade independentemente de duração.

Interface real no iago: card gerou em `device-ui-20261028-111557.xcresult`; texto trouxe só um ajuste apesar de pedir três com verificação, portanto reprovado editorialmente. Find Inspiration passou após correção da preparação de navegação, em `device-ui-20261028-111918.xcresult`: três ajustes e abertura coerentes com ângulo, mas desenvolvimento e conclusão vagos. Dados isolados de teste; sem stub de IA; PCC preferido, rota efetiva não observada pelo teste de UI. Capturas/JSON em `build/duration-ui/`. Primeiro teste de inspiração falhou antes de gerar, por navegação antiga; rerun passou.

36 testes unitários focados passaram em `only-20261028-110731.xcresult`. Alterações desta fase ainda precisam conferência final de warnings/Release e revisão antes de commit. Não confundir com validação anterior.

Dono informou merge de Claude Code em outra parte do app. Fetch confirmou `origin/main=cf54716b`, merge PR #74 feature/text-presets; HEAD desta branch acbe7fe9 diverge 6 commits próprios / 3 da main. Não foi feito merge nesta fase. Preservar alterações preexistentes e testar compatibilidade antes da integração.

## Refinamento implementado após autorização do dono

O factory agora escolhe informative para duração automática e targeted quando há duração explícita no card ou reconhecida no prompt. A duração habitual da voz deixa de ser enviada na política informativa. A faixa continua disponível para a interface. O teto PCC informativo agora é 4096 tokens independente da duração; não é uma meta de palavras.

`PCCScriptDraft` desenvolve cada ponto com enunciado, explicação e aplicação em uma única chamada transmitida; a resposta é normalizada para o mesmo GeneratedScript. Avisos/correções permitem campos vazios sem completar fatos. O esquema anterior forçava todo bloco em primeira pessoa; isso foi corrigido. Em prompts livres PCC, o checker de pronomes do perfil não pode reescrever a agência do pedido. Limite de duas chamadas e proteção de literais continuam. Resposta parcial do novo esquema não é apresentada como roteiro concluído.

Primeira rodada de seis casos: cinco geraram, literal ES falhou com requiredWording (nunca apresentado como sucesso). Tutorial cresceu de três frases vagas para três parágrafos com explicação; dois pontos ainda próximos. Comparação desenvolveu ambos os lados sem alegar teste pessoal passado, mas ainda há formulações artificiais e limites discutíveis. Produto ficou mais explicado. Aviso factual e correção séria ficaram concisos e preservaram os dados, sem contexto extra; a correção manteve Publicamos. Fixtures `quality-run-developed-*.json`. Mudaram esquema e espaço de resposta juntos: não atribuir o ganho somente à duração. Uma amostra por caso não prova estabilidade.

UI real: `device-ui-20261028-113459.xcresult`, dois fluxos passaram. Card agora entregou os três ajustes com verificações pedidos, em vez de apenas um. Inspiração seguiu o ângulo e abertura, mas presumiu vidro e prometeu que o brilho some; não aprovada editorialmente. Capturas e texto em `build/duration-ui/developed/`. Rota real UI não instrumentada; PCC preferido.

Após essa leitura: esquema pede mecanismos distintos; prompt torna detalhes de cena não fornecidos condicionais. Literais podem usar marcadores internos emitidos pelo modelo e restaurados antes da limpeza; nunca são acrescentados se ausentes. Texto que ainda contém marcador incompleto não pode ser entregue. Reexecução literal pendente neste checkpoint.

29 testes focados passaram em `only-20261028-113112.xcresult` antes dos ajustes finais de literais/perspectiva. Uma primeira seleção de teste Swift sem parênteses executou zero casos (`device-20261028-112819.xcresult`); NÃO contar como validação, seletor corrigido e lote real confirmou anexos para cada caso.

Pedido mais recente do dono: textos pouco desenvolvidos e excesso de restrição para falar pelo criador; roteiro é rascunho editável. O prompt PCC agora concede explicitamente opiniões, preferências, recomendações, analogias e exemplos autorais em primeira pessoa. Mantém precisão de biografia concreta, credenciais, clientes, depoimentos e resultados. Esquema pede raciocínio conectado e consequência/tradeoff, em vez de uma definição por ponto. A regra local antiga fica no fallback para preservar seu orçamento medido. Avaliar novamente desenvolvimento e naturalidade, sem tratar primeira pessoa editorial como alucinação.

Proteção por slots passou no caso ES em `device-20261028-114120.xcresult`: uma tentativa, rota privateCloud, frase exata mantida; fixture developed-literal-slots. Build anterior `113957` falhou porque um teste mudou durante compilação e viu módulo antigo; não conta como teste executado. Fonte estabilizada e recompilada.

Integração da main concluída na branch: `aa0a8a7f` incorpora origin/main cf54716b, sem conflitos. Não é merge desta branch na main. Preservada a alteração preexistente de ordenação do pbxproj.

Rodada autoral de uma chamada passou em sete casos reais (opinião PT/EN/ES, tutorial PT, comparação EN, literal ES e sério PT), fixtures `quality-run-authorial-*.json`. Frase exata e nota séria preservadas. Ainda houve raciocínio raso, analogias em sequência e comparação incompleta. O ganho não é qualidade final aprovada.

Para enfrentar o desenvolvimento, `PCCScriptPlan` acrescenta um plano interno antes da redação informativa: ponto de vista, requisitos, desenvolvimentos e um exemplo. Não é meta de tempo nem plano mostrado ao usuário. Chamadas PCC agora têm orçamento compartilhado de TRÊS: plano+rascunho normalmente usam duas, sobrando uma para correção; se a tentativa anterior consumiu o orçamento, uma correção não replaneja. Sem novas APIs externas. Planejamento e redação mantêm watchdog/cancelamento, e não entregam esquemas cortados como completos. A licença autoral permanece. Nova rodada planned em andamento; não atribuir a ela os resultados da rodada anterior.

Primeiro plano+redação no pedido autoral PT passou tecnicamente, mas repetiu o mesmo argumento sobre voz; requestedReasoning deep também não melhorou (`planned-pt-opinion`, `planned-deep-pt-opinion`, ~6,5–6,7s). Não declarar ganho editorial pelo planejamento ou pelo deep. Foi encontrada uma instrução literal sobre voz no fim do prompt reaparecendo como argumento do texto. Em PCC ela foi substituída por uma instrução direta de foco e de não recitar o perfil, preservando o prompt local medido. Novo controle `planned-focus-pt-opinion` em execução.

Decisão após leitura: os três controles de planejamento PT (padrão, deep e foco corrigido) não mostraram ganho consistente de desenvolvimento e aumentaram a latência para ~6,5s. NÃO promover planejamento nem deep. Planejamento fica apenas em Debug, opt-in `TEST_RUNNER_CUE_QUALITY_PLANNING=1` (ready configura evaluatesCloudPlanning), teto 3 nesse experimento. App normal/Release mantêm uma redação estruturada e até uma correção, orçamento 2. A correção da instrução de foco e a licença autoral ficam em produção; novo ensaio final deve ser sem planning. Não atribuir saídas planned ao caminho normal.

UI final sem plano: `device-ui-20261028-120234.xcresult`, 2/2 fluxos passaram. Card entregou texto substancial (~260 palavras) com três ajustes e verificação, preservando o pedido e sem meta de duração; amostra em build/duration-ui/final. Ganho de desenvolvimento claro contra a primeira UI que entregou apenas um ajuste. NÃO aprovar precisão técnica: há explicações de iluminação discutíveis/erradas, especialmente sobre recuar do fundo e a luz voltar ao rosto. Inspiração preservou ângulo/abertura, mas ainda promete que o brilho some. Rascunho não significa fatos verificados. Segue necessidade de revisão técnica/creator review; não declarar ausência de alucinações nem qualidade editorial integral.

Comparação solicitada: três redações do assistente sem aplicar perfil estão em research_notes/Roteiros AI melhores no Cue/writing_comparison.json, com prompts idênticos e referências das saídas PCC. Não é comparação cega: o assistente já leu as falhas do Cue, e não foi executado o app consumidor ChatGPT separado. Avaliar cobertura, raciocínio, exemplos, naturalidade e fidelidade; não usar palavras como proxy de qualidade nem alegar benchmark independente. Um teste opt-in compara também com o perfil real salvo, clonando-o em TestDefaults, respeitando switches e guardando só saídas em attachment privado; NÃO usar collect.py nem publicar esses textos no Git.

Checagem factual adicional dos nove textos full/half/none encontrou orientações de pele/protetor inadequadas, não só problemas de estilo. A equivalência por ingrediente isolado e testes de eficácia pela aparência não são base suficiente; AAD orienta verificar FPS, amplo espectro e resistência à água (https://www.aad.org/public/everyday-care/sun-protection/shade-clothing-sunscreen/choosing-right-sunscreen). A afirmação categórica de que hidratante antes do protetor impede a proteção não é sustentada pela orientação consultada da Johns Hopkins (https://www.hopkinsmedicine.org/health/wellness-and-prevention/sunscreen-and-your-morning-routine). Não aprovar a precisão factual do motor como resolvida. FactCheckBanner continua necessário; não é verificação externa automática.

Correção curta regrediu na rodada final (impacto/aviso atualizado não fornecidos). PCCScriptIntent agora classifica conciseStatement no mesmo fluxo guiado. Nessa classe, o renderer preserva abertura e enunciados, omitindo explicações/aplicações/fecho extras. Teste real concise-pt-serious passou e entregou somente as duas informações fornecidas. Conferência anterior de warnings foi interrompida deliberadamente para corrigir essa regressão; precisa rerodar integralmente após congelar fonte.

Comparação com perfil real disponível: `device-20261028-121948.xcresult`, três textos gerados pelo PCC com uma cópia do perfil salvo, sem alterar preferências reais. Somente saídas em build/private-writing-comparison/E361EFD1-D340-45E7-8AEE-B07D62799E76.json. Não publicar esse JSON no Git. O tutorial tinha needsFactCheck=false apesar de conter alegações técnicas; ScriptFactCheckPolicy agora mantém revisão informativa em todo prompt livre PCC, sem confiar apenas no booleano do modelo. Não é detecção/correção automática de alucinações nem trava a gravação. Unit tests novos e assert do lembrete nos testes de UI.

Matriz candidate (após conciseStatement, antes da política de banner): cinco casos reais passaram, incluindo nova repetição da correção curta e aviso factual. O escopo de texto do banner não altera a geração; toda checagem final deve incluir compilação/Release e UI após essa política.

Checagem focada final: 44 passaram, um grupo de contratos falhou por comprimento dos NOVOS prompts editoriais (PT203/ES214 excediam o card200). Textos de benchmark nativo já coletados mantêm suas entradas originais; fixtures atuais PT/ES encurtados sem alterar requisitos para caber no card. Comparação do assistente usa a entrada nativa original idêntica à do PCC, com nota explícita no JSON. Rerun do contrato pendente. UI final `device-ui-20261028-122839.xcresult`: 2/2 passaram, agora também verificando o lembrete de conferência factual nos dois fluxos.

Pedido seguinte do dono: trazer o método de desenvolvimento do assistente para o Cue com os recursos existentes. Novo A/B `method-*` mantém o mesmo pedido, perfil, teto4096 e esquema, variando só os exemplos editoriais sintéticos. `PCCEditorialExamples` demonstra posição→razão→exemplo concreto→limite em assuntos diferentes dos benchmarks (reunião e organização de arquivos). Não são amostras privadas nem fine-tuning do modelo. `isEnabled=false` até avaliar ganho; override Debug `CUE_QUALITY_EDITORIAL_EXAMPLES=1/0`, registrado em QualityRunSample.editorialMethod. Esquema tem qualification opcional para limite/contraponto, omitido em conciseStatement. Não afirmar melhora antes de ler pares.

A segunda checagem de warnings foi interrompida em função desse pedido de refinamento; permanece pendente uma execução integral depois de congelar a versão. O rerun do contrato de prompts passou em only-20261028-123303.xcresult (PT/ES agora cabem200). Commit remoto checkpoint b0575556 contém o candidato anterior; método por exemplos ainda está em avaliação local.


### Resultado do teste de transferência por exemplos

Seis gerações concluídas, três pares (opinião PT, comparação EN e tutorial PT), fixtures `quality-run-method-*`. Todas usaram privateCloud. Mesmos pedidos/perfis/esquema/teto, apenas exemplos sintéticos ligados/desligados; uma amostra por condição, avaliação qualitativa não cega. Os exemplos acrescentaram ressalvas úteis em alguns pontos, mas não demonstraram ganho consistente de desenvolvimento: opinião manteve metáforas repetidas, comparação continuou superficial e tutorial ainda trouxe generalizações técnicas. Não promover `PCCEditorialExamples.isEnabled`: permanece false. O campo opcional qualification permite representar limites pedidos sem forçar avisos em correções curtas. Não confundir execução técnica com aprovação editorial.

Pedido atual: transferir a forma de desenvolver textos do assistente. Método parcialmente expresso no esquema/instruções: intenção, ponto de vista, razões conectadas, aplicação e limite útil; isso não transfere os pesos nem a capacidade do modelo. Uma segunda revisão editorial semântica NÃO foi implementada nem validada. Não anunciar que o Cue escreve como este assistente ou que a precisão factual foi resolvida. Comparação disponível favorece os textos do assistente nestas três amostras, com as limitações já registradas.


### Próximo ensaio autorizado: revisão editorial (28/10)

Revisão semântica opt-in Debug via CUE_QUALITY_EDITORIAL_REVIEW=1, padrão false. Usa a chamada que sobrar do teto normal de duas, depois das correções de voz/idioma. Não revisa conciseStatement, duração dirigida ou fallback catalogOnly. O PCC diagnostica problemas concretos e devolve revisão completa; watchdog existente de 90s, cancelamento do criador propagado, falha mantém o rascunho e registra motivo no sample. Revisão não é verificação externa dos fatos. Guardas mecânicas preservam abertura escolhida, literais, gravidade das restrições, cobertura lexical, conteúdo e ausência de repetição extra; não são nota editorial. Produção/Release não usam esse passe.

Critérios definidos antes da leitura dos novos resultados: cobertura do pedido, desenvolvimento causal/argumentativo, exemplo que esclarece, naturalidade oral e fidelidade factual/autoral. Comparar revisão com seu próprio rascunho, guardado no mesmo sample, além de controles sem revisão. Não considerar mais palavras ou aceitação pelas guardas como prova de melhora. Incluir opinião, comparação, tutorial, bloqueio criativo, decisão sobre equipamento e ficção explícita. Os três últimos são novos casos com até 200 caracteres. Exemplos sintéticos anteriores permanecem desativados por padrão.


Resultado da rodada seguinte: 15 solicitações novas, todas privateCloud, fixtures review/review2/examples2. Revisão estruturada identificou problemas mas quase só parafraseou. Revisão em prosa livre fez correções pontuais, sem ganho consistente; comparativo EN rejeitado pelas guardas, sério PT pulou segunda chamada, literal ES preservado mas com experiência passada inventada. Exemplos ampliados ajudaram um desenvolvimento EN e pioraram decisão de equipamento PT; ficção ES continuou expositiva. NÃO promover os dois experimentos. Análise em reports/PCC_EDITORIAL_EVALUATION_2026-10-28.md. Campo qualification extra dos ensaios foi retirado antes da entrega normal: não atribuir resultados a uma versão sem esse campo. App normal/Release continuam sem exemplos/revisão. Fonte congelada para validação final; testes focados em andamento only-20261028-131313.

Validação focada only-20261028-131313: 25 testes passaram; um contrato falhou porque ainda esperava27 casos, agora30 com os três novos. O contrato foi atualizado para30 sem remover as verificações de tamanho, privacidade, idioma, literais e formato. Rerun pendente. SwiftLint dos Swift alterados passou; strings missing=0; diff --check limpo. check-warnings integral iniciado após confirmar ausência de xcodebuild ativo.

check-warnings concluído integralmente: simulador, aparelho e Release passaram sem warnings (sessão51683). Nove testes Python de tools/quality passaram. Rerun focado com30 casos em only-20261028-132256 ainda em execução.

Rerun focado only-20261028-132256: 26 passaram, zero falhas/skips. Contrato com30 casos aprovado. Instalação normal no Iago iniciada; experimentos continuam desligados.

Instalação normal concluída nos dois aparelhos. Iago instalou e abriu. Mansuelli instalou, mas abertura foi negada por aparelho bloqueado; basta o dono desbloquear e abrir o Cue Studio. Não executar testes automatizados no Mansuelli: ele fica para os testes manuais do dono/Mateus. Full --no-build iniciado com duas cópias gerenciadas pelo script, unidade primeiro e UI depois; validação ainda pendente.
