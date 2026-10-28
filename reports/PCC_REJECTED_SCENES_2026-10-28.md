# Candidato de cenas reprovado — 28/10/2026

A implementação de cenas não será mantida no app normal. O código experimental foi preservado em um commit de pesquisa antes de sua retirada; o hash é761be694. Esse commit preserva a última versão do candidato (fase7); os JSONs anteriores refletem as versões anteriores dos campos/nomes de intent descritas neste relatório. Os JSONs p5/p6/p7 preservam as saídas reais. Não confundir execução sem erro do SDK com qualidade aprovada.

## Amostras

- Fase5:1 cena ES com statements apenas,4 frases; retirou coaching, mas resumiu demais.
- Fase6:15 solicitações PCC, com campos próprios de momento e reação. Ficção ES passou a ter acontecimentos em singular sem coaching, mas ficou breve e pouco desenvolvida. As repetições da mesma entrada deram textos iguais; não são prova de diversidade estatística. EN POV preservou you, porém ainda trouxe conclusões genéricas.
- Controles de história real PT/EN/ES não respeitaram bem a fronteira de dados fornecidos. O EN inventou cenário/horário, uma causa do microfone desligado e um desfecho. O pedido proibia inventar o que aconteceu depois.
- Fase7:1 controle EN após restringir o nome da categoria para fictionalScene. Mesmo assim, o modelo escolheu essa categoria para um relato real, inventou living room/this morning e terminou com um aprendizado não fornecido. A verificação decisiva reprovou o candidato.
- Tutoriais/opiniões/comparações da fase6 ainda tiveram superficialidade e alegações sem suporte. Uma opinião alegou retorno positivo de público em um dia anterior sem esse dado no pedido. Avisos PT e frase literal ES foram preservados, mas isso não aprova os demais critérios.

## Decisão e alcance

São17 solicitações nesses três pilotos, somadas às32 da matriz fase3 e10 dos controles fase4:59 solicitações nesta continuação, todas com rota efetiva privateCloud. Os dois erros de compilação/lint durante o desenvolvimento não são inferências nem testes de qualidade aprovados.

Não há baseline medido dos três relatos reais na implementação antiga; portanto, não afirmar que o candidato introduziu todas essas falhas. A decisão é que não demonstrou fidelidade suficiente para ser promovido. Ficção pode criar detalhes, mas esse mecanismo não distinguiu de modo confiável a licença criativa de uma fronteira factual explícita.

Manter somente a correção pontual de instruções contraditórias de perspectiva no PCC, com perfil completo e preservação do código local. Prosa livre, voz de entrega, exemplos e revisão continuam desligados. Isso corrige o contrato do prompt; não é garantia de narrador perfeito nem de ausência de alucinações. A avaliação fase4 mostrou1/2 misturas de pessoa em ES e esse limite permanece documentado.

A próxima investigação de narrativa deve separar a autorização para ficcionalizar da geração do texto, com critérios verificáveis e sem introduzir provedor externo sem uma decisão de produto. Nenhum novo provedor foi adicionado nesta rodada.
