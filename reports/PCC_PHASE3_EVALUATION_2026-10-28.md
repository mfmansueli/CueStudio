# PCC fase3 — prosa livre e voz de entrega (28/10/2026)

## Decisão

Não promover prosa livre nem a remoção ampla de contexto do perfil. Os dois flags continuam false no app normal e ausentes em Release. A matriz não mostrou ganho consistente de desenvolvimento; houve regressão de agência em um controle sério. Preservar o perfil completo e corrigir a contradição pontual de perspectiva é o próximo ajuste separado, sem atribuir a ele estes resultados.

## Execução real

32 solicitações no iago Lima iphone: oito pedidos x quatro condições, todas com rota efetiva privateCloud, nenhum erro de geração. As mesmas entradas, perfis sintéticos e teto4096 foram mantidos, variando esquema e projeção de voz. A ordem das condições foi rotacionada entre casos, sem randomização ou cegamento. Uma amostra por condição/caso; avaliação qualitativa, não prova estatística. As respostas de referência do assistente não foram fornecidas como exemplos ao modelo.

| Condição | Amostras | Mediana de geração | Tentativas registradas |
|---|---:|---:|---:|
|00 atual|8|3,79s|9|
|10 prosa livre|8|2,66s|8|
|01 voz de entrega|8|3,71s|8|
|11 ambas|8|2,54s|8|

O controle literal00 precisou de uma segunda tentativa. A contagem de tentativas não é uma medição de tokens/custo. Velocidade e comprimento não foram usados como aprovação editorial.

## Leitura dos textos

- Opinião PT: todas continuaram apoiadas em ritmo e analogias pouco desenvolvidas. Prosa livre condensou o texto; não explicou melhor a causa.
- Comparação EN: prosa livre tornou vantagens/limites explícitos, mas em poucas frases de desenvolvimento raso e com relato de teste passado não fornecido. A variante de voz manteve o foco, sem ganho suficiente de argumento.
- Tutorial PT: as quatro condições continuaram trazendo regras de iluminação frágeis ou sem suporte. Prosa inventou ajuste de ângulo em centímetros; outra condição afirmou que a janela resolve tudo. Precisão técnica não aprovada.
- Equipamento PT: respostas categóricas demais, como concluir que o resultado seria igual se só a câmera mudasse. Exemplos não estabeleceram bem quando a troca é necessária. Não houve vencedor consistente.
- Bloqueio criativo EN: voz de entrega evitou parte do desvio para exercício físico, mas continuou vaga. Prosa livre simplificou o raciocínio em vez de aprofundá-lo. Não tratar todo exemplo ligado ao perfil como erro; o problema é mudar a ação pedida de criar um vídeo para executar o exercício.
- Ficção ES: perfil completo ainda trouxe o taller; isso pode ser um cenário ficcional válido, não uma alucinação factual por si só. Voz de entrega retirou esse contexto, mas todos mantiveram narração em equipe e pouca construção dramática. Prosa escreveu um resumo, não uma cena convincente. O pedido usa primeira pessoa singular (intento), enquanto o prompt termina impondo we/neverI: conflito investigado separadamente.
- Correção PT:00,01 e10 preservaram publicamos.11 mudou para eu publiquei, alterando quem fez a ação. Regressão suficiente para impedir ativação.
- Literal ES: as quatro condições mantiveram a frase exigida. Isso não aprovou os demais fatos: alguns textos inventaram experiência no taller e generalizaram resultados.

## Evidências e limite

Fixtures `Cue StudioTests/Fixtures/ScriptQuality/quality-run-p3-*.json`, cada uma com prompt, instruções, flags, modelo, texto e tempo. Os oito casos são pt-BR-editorial-draft, en-US-comparison, pt-BR-tutorial, pt-BR-equipment, en-US-creative-block, es-ES-small-story, pt-BR-serious e es-ES-literal. UI não foi ativada com esses flags. Não afirmar que houve ganho comprovado ou eliminação de alucinações.

Os24 testes focados anteriores passaram em only-20261028-185516. A compilação inicial para aparelho e controle PCC passaram em device-20261028-195939. A correção de perspectiva feita depois desta matriz ainda tem validação própria, descrita no handoff.
