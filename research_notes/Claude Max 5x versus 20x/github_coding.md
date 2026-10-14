# Claude Max 5x versus 20x para Claude Code — evidências de desenvolvedores

## O que os planos oficialmente prometem e como os limites funcionam

### Takeaway
Oficialmente, Max 5x custa US$100/mês e oferece 5x a capacidade do Pro; Max 20x custa US$200/mês e oferece 20x a capacidade do Pro. Porém, a Anthropic não publica a capacidade semanal em tokens ou dólares, e hoje há três travas relevantes: sessão de cinco horas, limite semanal geral e, nos planos Max, limite semanal separado para Fable. O “20x” não deve ser interpretado como garantia de quatro vezes mais capacidade semanal que o Max 5x.

### Cited Findings
- A página oficial de escolha de plano lista Max 5x por US$100/mês, com 5x a capacidade do Pro, voltado a usuários frequentes, e Max 20x por US$200/mês, com 20x a capacidade do Pro, voltado a quem usa Claude diariamente para a maior parte do trabalho. — [Claude Help Center: Choosing a Claude Plan](https://support.anthropic.com/en/articles/11049762-choosing-a-claude-ai-plan)
- A documentação oficial atual diz que Pro e Max têm limite de sessão de cinco horas e limite semanal; Max tem ainda um limite semanal separado para Fable. O consumo de Claude, Claude Code no terminal e IDEs é somado no mesmo conjunto de limites. — [Claude Help Center: Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)
- A mesma documentação recomenda Max 5x para quem bate os limites do Pro em repositórios maiores e Max 20x para quem bate consistentemente os limites do Max 5x, mas não fornece os tetos exatos nem a razão entre os tetos semanais dos dois planos. — [Claude Help Center: Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)
- Uma versão anterior da página oficial estimava, para um usuário médio, aproximadamente 50–200 prompts de Claude Code por janela de cinco horas no Max 5x e 200–800 no Max 20x. Essas são estimativas dependentes de tamanho do repositório, contexto, modelo, ferramentas e execução autônoma, não cotas garantidas. — [Anthropic Help Center em português](https://support.anthropic.com/pt/articles/11145838-usando-claude-code-com-seu-plano-pro-ou-max)

### Inferences
- O benefício mais defensável do 20x é capacidade de pico dentro da janela de cinco horas. Como os tetos semanais exatos não são publicados, não há base oficial para afirmar que a semana do 20x seja quatro vezes a semana do 5x.
- Uso no chat/desktop pode reduzir silenciosamente o que sobra para Claude Code; comparar somente os logs locais de Claude Code subestima o consumo total da conta.

### Gaps
- A Anthropic não publica, em 14 de outubro de 2026, os limites semanais de Max 5x e 20x em tokens, prompts, API-equivalent dollars ou uma razão oficial 20x:5x.
- Não há fórmula oficial pública que permita prever o consumo a partir de contexto, cache, esforço de raciocínio, subagentes e chamadas de ferramentas.

## O que GitHub e fóruns relatam sobre capacidade prática e workloads pesados

### Takeaway
As melhores medições públicas recentes sugerem que o Max 20x entrega aproximadamente 3,2–4,4× mais capacidade na janela de cinco horas, mas apenas cerca de 1,6–2,2× na semana, custando 2×. O 5x costuma se esgotar em trabalho agentic contínuo, repositórios grandes, múltiplas sessões/subagentes, uso de Opus com esforço alto e contextos longos; o 20x reduz bloqueios intrajornada, mas usuários intensivos ainda relatam atingir a semana em dois ou três dias.

### Cited Findings
- Um usuário que mediu chamadas locais e comparou com barras de uso, usando Claude Code em mais de 95% do consumo, encontrou no Max 20x uma sessão completa de cinco horas equivalente a cerca de US$508 de API e uma semana de cerca de US$1.827; no Max 5x, sessão de cerca de US$158 e semana extrapolada de cerca de US$1.170. Isso implica 3,2× por sessão, mas só 1,6× por semana, enquanto o preço dobra. É uma medição individual, não confirmação da Anthropic. — [GitHub issue #99330](https://github.com/anthropics/claude-code/issues/99330)
- Outro usuário que comparou períodos nos dois planos observou que o contato com o limite de cinco horas caiu de 9,7% para 0,9% após ir ao 20x, mas o contato com o limite semanal subiu de 13,5% para 19,9%; o consumo diário medido cresceu somente cerca de 1,3×, enquanto a mistura migrou de 53% para 82% de Opus, que consumia mais rapidamente a semana. — [GitHub issue #72872](https://github.com/anthropics/claude-code/issues/72872)
- Uma medição comunitária da mesma conta, nos mesmos modelos, reportou aumento de 4,4× na janela de cinco horas e de apenas 2,2× no limite semanal ao mudar de 5x para 20x. O autor também reportou mudanças promocionais nos limites semanais ao longo de 2026, reforçando que números históricos podem não valer hoje. — [Reddit r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1why2zx/a_lot_of_talk_about_reduced_weekly_limits_but_a/)
- Um relato recente de uso pesado — backend, web e mobile, com 7–8 CLIs simultâneos e outros modelos como subagentes — diz que mesmo o Max 20x ainda esgota facilmente tanto a janela de cinco horas quanto a semana. — [Reddit r/ClaudeCode](https://www.reddit.com/r/ClaudeCode/comments/1x2duqm/i_upgraded_from_max_5x_to_max_20x_heres_what_30/)
- Um issue relata que subagentes rodam em contexto isolado e consomem tokens mesmo quando falham sem devolver resultado útil; como todos contam para a mesma franquia, orquestração paralela é uma fonte importante de consumo. — [GitHub issue #48283](https://github.com/anthropics/claude-code/issues/48283)
- Há relatos de Max 5x esgotando uma janela em aproximadamente 1,5 hora com tarefas agentic normais e de Max 20x saltando de 21% para 100% em um prompt durante incidentes anormais. Esses relatos descrevem falhas/regressões, não o comportamento nominal do plano. — [GitHub issue #38335](https://github.com/anthropics/claude-code/issues/38335)

### Inferences
- Max 20x tende a valer mais para quem perde produtividade ao bater repetidamente a janela de cinco horas: vários agentes simultâneos, refactors grandes, exploração de monorepo, testes/depuração longos e Opus em esforço alto.
- Para quem usa uma sessão interativa por vez, trabalha algumas horas por dia e raramente bate o limite de cinco horas do 5x, o adicional de US$100 compra pouca utilidade; o teto semanal pode continuar sendo a trava dominante.
- Como 20x permite sessões maiores, ele pode induzir modelos mais caros, mais paralelismo e contextos maiores; a capacidade semanal extra pode ser consumida mais depressa, ocultando parte do ganho.

### Gaps
- Relatos públicos são auto-selecionados e não formam amostra representativa; não permitem estimar a porcentagem de clientes que atingem cada limite.
- “Prompt” não é unidade comparável entre projetos: uma pergunta curta e um agente que lê um monorepo, chama ferramentas e cria subagentes têm custos radicalmente diferentes.

## Incidentes de rate limit, restrições adicionais e workarounds

### Takeaway
Há evidência consistente de incidentes de cache, medição e autenticação que fizeram cotas desaparecerem muito mais rápido que o normal. Eles não provam que o plano nominal seja menor, mas tornam a experiência imprevisível. Os workarounds comunitários podem reduzir desperdício; trocar de plano não corrige necessariamente um bug de metering ou credencial.

### Cited Findings
- Em março de 2026, um agregador no repositório documentou regressões de cache que poderiam inflar consumo em 10–20×, afetando Pro, Max 5x e Max 20x; os workarounds relatados incluíam atualizar/corrigir a versão afetada, evitar `--resume`/`--continue` quando invalidavam cache, iniciar sessões novas com `/clear` e monitorar aumentos anormais nos primeiros turnos. — [GitHub issue #41930](https://github.com/anthropics/claude-code/issues/41930)
- Outro usuário mediu no Max 20x que o cache read ratio caiu a 4,3%, causando aproximadamente 20× de inflação por turno, e depois ficou em 95–99% na versão 2.1.90; isso liga parte dos episódios de esgotamento rápido a regressões do cliente, não apenas à cota do plano. — [GitHub issue #22876](https://github.com/anthropics/claude-code/issues/22876)
- Um relato de agosto de 2026 encontrou no token OAuth de uma conta Max 20x o tier `default_claude_max_5x`, enquanto o perfil da organização mostrava 20x; logout/login corrigiu o rótulo do token, mas não corrigiu a drenagem anormal do medidor, portanto a relação causal não foi demonstrada. — [GitHub issue #87419](https://github.com/anthropics/claude-code/issues/87419)
- Há casos separados de upgrade 5x→20x em que o medidor semanal pareceu continuar no tier 5x ou pior, inclusive um relato de limite alcançado em 3 dias no 20x versus 6–7 dias no 5x com carga semelhante. São issues de usuário, ainda sem confirmação de causa pela Anthropic. — [GitHub issue #79773](https://github.com/anthropics/claude-code/issues/79773)
- A documentação oficial alerta que uma variável `ANTHROPIC_API_KEY` definida faz o Claude Code usar a API paga em vez da franquia da assinatura; recomenda `/logout`, atualização e novo login quando a conta errada está ativa, e `/status` para acompanhar a franquia. — [Claude Help Center: Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)

### Inferences
- Antes de pagar o upgrade porque a cota “sumiu” de forma súbita, vale verificar versão, autenticação, `/status`, variável `ANTHROPIC_API_KEY`, taxa de cache e se uma retomada/contexto longo está invalidando o cache.
- Quando o consumo muda abruptamente sem mudança de workload, comparar o percentual antes/depois de uma tarefa curta e reproduzível é mais informativo que assumir que o plano é insuficiente.

### Gaps
- Issues fechadas como duplicadas, stale ou “not planned” não equivalem a confirmação ou negação técnica; em muitos casos não há resposta oficial conclusiva.
- Não existe histórico oficial detalhado por chamada que permita auditar facilmente a cobrança de cada janela; os usuários dependem de logs locais, que não incluem consumo de outras superfícies.

## Quando 5x, 20x ou API pay-as-you-go tende a ser mais econômico

### Takeaway
Para uso recorrente e pesado, a assinatura pode representar muito mais uso que o mesmo valor na API; API-only tende a ganhar quando o uso é esporádico ou previsivelmente abaixo de US$100/mês. Entre os Max, a decisão prática é marginal: se o 5x mais créditos extras custa menos de US$200 e interrupções são toleráveis, permaneça no 5x; se o excedente passa de cerca de US$100/mês ou as interrupções custam trabalho, o 20x tende a ser melhor.

### Cited Findings
- Oficialmente, ao atingir a janela de cinco horas ou os limites semanais, o usuário pode ativar usage credits/extra usage ou trocar para Console/API; esse consumo é cobrado às tarifas padrão de API, separadas do preço da assinatura. Créditos mensais de API incluídos no Max não podem ser usados no Claude Code ou nos apps, nem como extra usage. — [Claude Help Center: Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)
- A tabela oficial de 27 de maio de 2026 lista, por milhão de tokens e até 200K de contexto, Opus 4.5 a US$5 input/US$25 output/US$0,50 cache hit; Sonnet 4.5 a US$3/US$15/US$0,30; Haiku 4.5 a US$1/US$5/US$0,10. O custo real de Claude Code depende fortemente de cache writes, cache hits, output e modelo. — [Anthropic List Prices, 2026-05-27](https://www-cdn.anthropic.com/files/4zrzovbb/website/3684c2faafb97418665782cea0001f439f74b1d2.pdf)
- Uma medição comunitária estimou a semana do Max 5x em cerca de US$1.170 de API-equivalent e a do Max 20x em cerca de US$1.827, contra assinaturas mensais de US$100 e US$200; apesar das limitações da metodologia, isso sugere forte subsídio para quem realmente usa a cota. — [GitHub issue #99330](https://github.com/anthropics/claude-code/issues/99330)
- Outra medição anterior estimou uma semana de Max 5x em pelo menos US$523 de preço de API, observando que consumo interativo não capturado tornava o valor um limite inferior. — [Reddit r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1s0n5bf/what_a_claude_max_weekly_limit_is_actually_worth/)
- A própria Anthropic sugere mudar para Console e comprar créditos para “sprints de codificação intensivos”, o que favorece API como complemento temporário, não necessariamente substituto permanente, quando o pico é ocasional. — [Claude Help Center: Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan)

### Inferences
- API-only é economicamente racional se a fatura mensal medida ficar abaixo de US$100 e não houver valor relevante nos outros apps incluídos no Max. Acima disso, Max 5x tende a ser melhor, desde que suas janelas atendam o padrão de uso.
- O limiar simples entre Max 5x e 20x é aproximadamente US$100/mês de extra usage: 5x (US$100) + menos de US$100 de excedente custa menos que 20x (US$200). Esse cálculo deve incluir o custo das horas bloqueadas e a possibilidade de o limite semanal continuar dominante.
- Uma estratégia eficiente para uso irregular é Max 5x como base mais extra usage com teto baixo; após observar um mês real, subir para 20x somente se o excedente e/ou a interrupção justificarem a diferença.
- Para workloads contínuos de Opus, paralelismo e grandes repositórios, API pay-as-you-go pode superar rapidamente US$200, enquanto o 20x ainda oferece grande valor implícito mesmo sem quatro vezes a semana do 5x.

### Gaps
- Não há simulador oficial que reproduza o histórico real nos planos 5x/20x; sem preços internos do medidor semanal, a comparação exata precisa usar um mês de dados do próprio usuário.
- As estimativas “API-equivalent” não são faturamento real e podem variar com mudanças de modelo, promoções, cache e ponderação interna de cota.
