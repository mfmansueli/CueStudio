# Próximo teste editorial PCC: voz e prosa — 28/10/2026

## Estado

Preparação de código apenas, na worktree codex/pcc-offline-review. Não compilado e não executado no PCC nesta etapa para não disputar Xcode, simuladores ou aparelhos com Claude Code. SwiftLint passou; isso não valida tipos, concorrência, comportamento nem qualidade. Ambos os flags começam false, estão em Debug, e não alteram o caminho normal/Release. Não instalar ou promover como melhoria comprovada.

## Hipóteses separadas

| Condição | CUE_QUALITY_FREE_PROSE | CUE_QUALITY_DELIVERY_VOICE |
|---|---|---|
| Controle atual |0|0|
| Só prosa livre |1|0|
| Só voz de entrega |0|1|
| Prosa + voz de entrega |1|1|

A primeira variante usa PCCProseDraft com texto falado completo em parágrafos. Não exige um campo de explicação/aplicação para cada ponto. Mantém streaming, watchdog, orçamento compartilhado de duas chamadas, proteção/restauração de literais, idioma e revisão factual informativa. Não salva resposta parcial como completa e não é uma nova revisão adicional.

A segunda usa uma cópia de CreatorVoice, sem alterar o perfil salvo. Retira papel/credencial/identidade livre, temas e nichos, descrições de audiência, metas/motivos de assistir, formatos/aberturas/fechos habituais e redes/duração habituais. Preserva som, estilo, vocabulário, nível de conhecimento, humor, restrições/evitar, expressões, tags de estilo, fingerprint e a perspectiva padrão resolvida antes de retirar o papel. O pedido, formato explícito, ângulo/abertura do Find Inspiration e frases obrigatórias ficam intactos. A filtragem de privacidade PCC continua antes dessa projeção; ela não reintroduz exemplos privados.

Limitações da ablação: perder contexto de audiência ou credenciais pode prejudicar pedidos que dependem dele; não é uma recomendação de apagar o perfil em produção. A perspectiva padrão ainda precisa respeitar a perspectiva do pedido, avaliada semanticamente, não por detecção de idioma com palavras-chave.

As duas variantes só se aplicam a prompts livres PCC com duração informativa. Duração explícita, modelos locais e formatos de brief continuam no caminho atual. O harness rejeita misturar esta matriz com planning, revisão ou exemplos anteriores, para não atribuir o ganho à variável errada.

## Próximas verificações, quando os recursos estiverem livres

1. Compilar/testar as suítes PCCDeliveryVoiceTests e PCCProseDraftTests, além das guardas existentes. A worktree ainda não tem build; não usar --no-build na primeira rodada.
2. Primeiro PCC nativo: executar os quatro controles nos mesmos casos existentes (opinião PT, comparação EN, tutorial PT, equipamento PT, bloqueio criativo EN e ficção ES), com os mesmos perfis e teto. Acrescentar correção séria e literal ES como controles de fidelidade. Uma execução por condição é triagem; repetir casos promissores antes de concluir estabilidade.
3. Comparar cobertura, desenvolvimento causal, exemplo útil, naturalidade, fidelidade, influência indevida do perfil e latência. Para ficção, verificar cena e ação em vez de explicação da tensão. Para tutorial, verificar plausibilidade técnica e não só número de passos. A ausência de erro do SDK não aprova o texto.
4. Se houver ganho consistente, repetir nos fluxos reais do card e Find Inspiration, com abertura selecionada e My Cue Voice completo/meio/ausente. Só depois discutir ativação. Não há resultado desta etapa ainda.
5. Compilação limpa sem warnings (simulador/aparelho/Release) e verificações adequadas após as mudanças; a validação sem warnings anterior antecede este código.

Exemplo de comando futuro, não executado:

`CUE_DEVICE="iago Lima iphone" TEST_RUNNER_CUE_QUALITY_RUN=prose-voice-11-opinion TEST_RUNNER_CUE_QUALITY_MODEL=privateCloud TEST_RUNNER_CUE_QUALITY_DURATION=informative TEST_RUNNER_CUE_QUALITY_INTENT_CASE=pt-BR-editorial-draft TEST_RUNNER_CUE_QUALITY_FREE_PROSE=1 TEST_RUNNER_CUE_QUALITY_DELIVERY_VOICE=1 TEST_RUNNER_CUE_QUALITY_EDITORIAL_EXAMPLES=0 TEST_RUNNER_CUE_QUALITY_EDITORIAL_REVIEW=0 TEST_RUNNER_CUE_QUALITY_PLANNING=0 scripts/test.sh device 'ScriptQualityDeviceTests/writesAnIntentBenchmarkCase()'`

QualityRunSample registra os dois flags e as instruções/prompt da voz projetada. Os flags indicam configuração solicitada; a elegibilidade depende da rota, fonte e política de duração. Não misturar os resultados novos com fixtures antigas que usavam qualification. Não fornecer as respostas de referência do próprio benchmark como exemplos de entrada.
