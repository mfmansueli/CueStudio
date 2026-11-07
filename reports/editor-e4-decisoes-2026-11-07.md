# Etapa 4: decisões do dono (07/11/2026, noite)

Resposta do dono à revisão da etapa 4 (https://claude.ai/artifact/JQF6FsWAPoxyi6xxqQ29mR). Texto do dono, sem edição. Vale mais que a §19 do
plano onde as duas divergem.

Eu aprovaria os três consertos imediatos e a volta de Meu estilo para a etapa 4. Nas escolhas de produto, eu aceitaria a maior parte da proposta, mas mudaria duas coisas. O Quick pass só deve ficar em Limpar fala se atuar na fala. E a legenda pode servir para selecionar o trecho do zoom, mas o zoom precisa continuar editável de forma independente.

| Decisão | Minha escolha |
|---|---|
| A · Edição automática | Quick pass no Clean up se o escopo for limpar fala e repetições. Se também aplicar zoom, estilo de legenda ou áudio, eu daria à automação um ponto de entrada próprio, sujeito a aprovação na etapa 5. No Done, a pessoa já está decidindo como publicar. Em qualquer caso, ela precisa ver o que será aplicado e poder desfazer a operação. |
| B · Áreas seguras | Usar a plataforma do roteiro como sugestão e permitir trocar na própria guia. Sem plataforma conhecida, abrir com uma guia genérica. Mostrar a plataforma ativa, dizer que é uma aproximação e manter a troca como escolha daquele vídeo. A guia visual fica só no editor. A posição das legendas deve corresponder à prévia no arquivo final. |
| C · Minhas palavras | Aprovar no ••• de Legendas e como atalho em Buscar e substituir. Antes de adicionar uma palavra, deixar claro qual grafia será guardada. A lista ajuda o reconhecimento em vídeos futuros. Uma substituição no vídeo atual continua sendo uma ação separada. |
| D · Posição da legenda e zoom por frase | Aprovar a seleção na faixa principal de Legendas, inclusive Select lines. A posição manual deve mover original e tradução juntos e prevalecer sobre o posicionamento automático na divisória. Para o zoom, as linhas indicam o intervalo inicial, sem dividir o clipe. Corrigir o texto ou desligar as legendas não deve apagar o zoom. |
| E · Três defeitos | Corrigir agora. Recalcular as margens quando mudar a proporção, salvar a tentativa escolhida com Desfazer e usar o roteiro do take correspondente numa montagem. Testar fechar e reabrir o projeto e misturar takes com roteiros diferentes e um vídeo importado sem roteiro. |

A maior lacuna do canvas está em Meu estilo. Ele volta para a etapa 4, mas já existem Kit, Template e Copy/Paste look, e o próprio canvas relata que um template pode sobrescrever a aparência do kit sem aviso. Antes de desenhar outro seletor, a Claude precisa mostrar o que cada caminho salva, o que substitui e o que preserva. Se a receita guardar preferências de limpeza, zoom e áudio, aplicá-la deve carregar essas preferências. Executar novos cortes ou outros ajustes que mudam o vídeo deve ser uma ação explícita.

## Resposta para enviar à Claude

Pode corrigir agora os três defeitos do item E. Registre a correção das margens por proporção, a persistência de Keep this one com Desfazer e o uso do roteiro de cada take na montagem. Confira esses casos na prévia, ao reabrir o projeto e, para as margens, no arquivo exportado.

A. Quick pass no Clean up se atuar só sobre a fala. Se a etapa 5 incluir uma automação que também aplica zoom, legendas ou áudio, apresente um ponto de entrada próprio para aprovação. A pessoa deve ver o que será aplicado, revisar mudanças de tempo e desfazer a aplicação inteira.

B. Use a plataforma do roteiro como sugestão. Permita trocar ou desligar a guia dentro do editor e use uma guia genérica quando não houver plataforma conhecida. Identifique a plataforma ativa e trate a guia como aproximação. Valide contraste e texto grande com vídeos claros e escuros.

C. Aprove My words no ••• de Legendas e Add to my words em Buscar e substituir. Mostre a grafia que será salva. A lista serve ao reconhecimento de fala e fica separada do perfil usado pela IA de roteiros. Adicionar uma palavra à lista e substituir texto no vídeo são ações distintas.

D. Use a faixa de Legendas da timeline principal para selecionar uma linha ou várias. Mostre antes do ajuste se a posição é local ou global. A posição manual da linha prevalece sobre a divisória automática, move original e tradução juntos e tem reset local que recupera a posição automática. O zoom usa o intervalo selecionado como ponto de partida e pode ser ajustado separadamente, sem dividir o clipe. Teste o que acontece ao corrigir, dividir ou apagar uma legenda e ao cortar o vídeo depois. A timeline principal continua fora dos painéis, com os controles locais já aprovados.

Meu estilo volta para a etapa 4. Antes de implementar, mostre lado a lado o alcance de Meu estilo, Kit, Template e Copy/Paste look. Resolva a sobrescrita silenciosa de fontes e cores. Defina o que a receita guarda, o que exige aplicação explícita e o que acontece com ajustes locais existentes. Inclua um teste de reaplicar o estilo num vídeo novo e outro de aplicar sobre um vídeo já editado. Trate também a folha repetida do Paste look e a visibilidade das cores da legenda no plano revisado.

Feche os pontos pendentes antes de implementar cada fluxo. Defina a regra para alongar legendas junto de outra linha e na borda de um clipe. Separe marcas de ênfase manual e automática para que desligar a automação preserve o trabalho manual. Em zoom por frase, defina limites de qualidade e duração e confira Follow face também em mídia importada. Em áudio, explique o nível da música e quanto ela baixa sob a voz. Meça loudness e true peak no arquivo antes de aprovar normalização, e ouça casos reais antes de ativar tratamento de respiração ou sibilância. Para Repetições, mantenha o fluxo em Words e registre os idiomas efetivamente testados com fala real.

Depois do meu teste da etapa 3 no iPhone, feche os pontos de entrada e a altura dos painéis da etapa 4. No relatório, separe o que foi lido no código, o que foi reproduzido e o que foi validado no aparelho. O congelamento ainda fica pendente do meu fluxo de teste.
