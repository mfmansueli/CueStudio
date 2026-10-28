# Avaliação editorial PCC — 28/10/2026

## Decisão

Não ativar os exemplos sintéticos nem a segunda revisão editorial por padrão. Permanecem experimentos opt-in Debug. Não demonstraram ganho consistente de desenvolvimento ou fidelidade que justifique o custo adicional. O roteiro continua sendo rascunho editável; isso não torna verdadeiros os fatos inventados.

## Método e limites

15 solicitações novas no iago Lima iphone, todas com rota efetiva privateCloud: uma revisão inicial estruturada, oito casos com revisão em prosa livre (incluindo uma correção curta que corretamente pulou a revisão) e três novos pares com exemplos desligados/ligados. Somadas às seis saídas anteriores, são 21 solicitações preservadas nas fixtures method, review e examples2. Cada solicitação revisada pode usar duas chamadas; 15 não é a contagem de inferências. Não foi uma avaliação cega ou estatisticamente repetida.

A revisão compara o texto com seu próprio rascunho, preservado no mesmo JSON. Os pares de exemplos mantêm pedido, perfil sintético, esquema e teto4096; só variam a presença dos quatro exemplos sintéticos. Os assuntos dos exemplos são diferentes dos casos avaliados. Nenhuma amostra privada do criador foi usada como exemplo ou publicada.

Critérios: cobertura, raciocínio desenvolvido, exemplo útil, naturalidade oral e fidelidade factual/autoral. As guardas mecânicas não dão nota de qualidade; apenas impedem algumas regressões. Não houve verificação factual externa pelo app.

## Leitura dos resultados

| Caso | Resultado observado |
|---|---|
| Opinião PT | O diagnóstico identificou repetição de analogias e falta de explicação. A revisão continuou girando em torno de ritmo, sem resolver bem a causa. |
| Comparação EN | A revisão foi rejeitada pelas guardas; o rascunho original permaneceu. O candidato principalmente condensou o texto. |
| Tutorial PT | Retirou uma distância arbitrária de dois metros. Manteve outros números e explicações técnicas problemáticas. Precisão não aprovada. |
| Equipamento PT | Revisão retirou “Eu já vi isso acontecer”, que não tinha suporte. O argumento ainda ficou estreito. Com exemplos ampliados, o texto piorou ao dizer que a troca só faria sentido se a luz estivesse travada. |
| Bloqueio criativo EN | Exemplos ampliados desenvolveram melhor o ciclo de colecionar sem escolher. O texto ainda se desviou para exercícios físicos do perfil em vez de manter o foco na produção de vídeo. |
| Ficção ES | Nem exemplos nem revisão criaram uma cena oral convincente; o texto explicou a tensão e trouxe comunidade/taller do perfil. Liberdade de ficção ainda insuficiente. |
| Correção séria PT | Permaneceu curta, com uma chamada; não recebeu expansão editorial. |
| Frase literal ES | Preservou a frase exigida. Entretanto, o texto trouxe uma experiência passada de gravar no taller sem suporte e uma regra arbitrária de contar até três. Preservar literal não aprova fidelidade. |

A revisão em prosa livre levou aproximadamente 6,3–7,8s nos casos efetivamente revisados; o primeiro protótipo levou9,0s. A correção curta levou2,6s. Nos seis controles de exemplos, aproximadamente3,0–5,0s. São tempos de geração destas amostras, não SLA nem medições de abertura do app.

## Implementação preservada

- Revisão Debug com diagnóstico antes da reescrita, watchdog90s e orçamento compartilhado de duas chamadas. Uma correção pode consumir a chamada restante; não cria uma terceira chamada.
- Mantém o rascunho se a revisão falhar ou violar as guardas; cancelamento do criador é propagado. Falhas são registradas separadamente nas medições.
- Abreviações, frases exatas e abertura do Find Inspiration continuam protegidas. Testes de UI anteriores validaram os fluxos; a revisão experimental não foi ativada na UI normal.
- O campo extra qualification, usado no esquema dos ensaios, não foi promovido ao caminho normal. Limites solicitados continuam podendo ser desenvolvidos nos campos existentes.
- Não mudou de provedor, não fez fine-tuning e não introduziu API externa.

## Próxima hipótese, ainda não implementada

Reduzir a interferência de assuntos e estruturas habituais do perfil, preservando vocabulário, ritmo e restrições relevantes; avaliar também uma redação inicial em prosa livre. Os resultados desta rodada não autorizam prometer qualidade equivalente às redações do assistente.

## Resultados nativos

- `en-US-creative-block`: 6.33s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.
- `en-US-comparison`: 6.31s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=False.
- `es-ES-small-story`: 7.73s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.
- `es-ES-literal`: 6.94s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.
- `pt-BR-equipment`: 7.50s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.
- `pt-BR-editorial-draft`: 7.17s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.
- `pt-BR-serious`: 2.64s, 1 chamada(s) contabilizada(s), revisão aceita pelas guardas=False.
- `pt-BR-tutorial`: 7.55s, 2 chamada(s) contabilizada(s), revisão aceita pelas guardas=True.

Validação de compilação/testes final é registrada no handoff; não confundir os ensaios semânticos com aprovação de toda a suíte.

## Checkpoint de validação

Zero warnings em simulador, aparelho e Release;26 testes focados e9 testes Python aprovados. Full iniciado em full-unit-20261028-132841, ainda sem resumo final no checkpoint de créditos. Não declarar regressão completa aprovada. Compilação normal instalada nos dois aparelhos; Mansuelli bloqueado impediu somente a abertura. Três novas referências ilustrativas do assistente estão em research_notes/Roteiros AI melhores no Cue/editorial_next_references.json; não foram usadas como entradas dos ensaios.
