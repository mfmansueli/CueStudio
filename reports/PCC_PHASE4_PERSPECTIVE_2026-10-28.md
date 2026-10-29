# PCC fase4 — prioridade da perspectiva (28/10/2026)

A correção removeu uma contradição concreta das instruções: o pedido atual podia escolher narrador, mas o lembrete final ainda impunha o pronome do perfil. No PCC, a perspectiva do perfil passa a ser um padrão quando o pedido não a define. Instruções locais permanecem iguais; perfil completo e regras de evitar/marca são mantidos. Não houve parsing de palavras-chave de idioma nem substituição mecânica de pronomes no texto.

72 testes focados passaram em only-20261028-201242. O build mostrou um aviso SwiftLint de vírgula final; formato corrigido logo depois, SwiftLint estrito passou e a compilação seguinte para aparelho ficou sem esse aviso. Conferência limpa completa ainda deve ser registrada no handoff final.

## Dez solicitações reais, sem os experimentos anteriores

Todas retornaram privateCloud. Fixtures quality-run-p4-*.json. Flags de prosa livre, projeção de voz, exemplos, planning e revisão ficaram0. Casos novos têm até200 caracteres e o contrato foi ampliado de30 para33 casos, incluindo POV manual.

- EN second-person,2 repetições: ambas mantiveram você/you. Uma ainda incluiu conselhos e instruções fora da cena; a outra foi mais direta. Preservar perspectiva não aprova qualidade completa.
- ES singular explícito,2 repetições: uma manteve singular; a outra misturou yo com controlamos/mezclamos/nos. Portanto, singular ainda não é garantido.
- ES cena anterior,2 repetições: passaram de narração em equipe para voz predominantemente singular. Uma ainda trouxe conselhos condicionais no meio do relato. É leitura qualitativa antes/depois, não ensaio estatístico cego.
- PT comunicado da equipe e correção séria: ambos preservaram a ação plural e14:35, sem justificativa adicional.
- Literal ES: frase requerida preservada; demais alegações ainda dependem de revisão.
- Opinião PT: controle de continuidade; não é evidência de melhora geral de raciocínio.

## Próximo ajuste delimitado

O esquema de pontos explicativos continuou introduzindo orientação técnica dentro de ficção/POV. A fase5 foi um piloto de cena que retirava explicações/aplicações, mas rendeu só quatro frases. A fase6 prepara campos próprios de momento e reação para desenvolver a ação, sem quota de duração. Não atribuir a essa estrutura nova os resultados fase4. Ficção pode inventar detalhes; histórias reais que proíbem inventar depois precisam ficar nos acontecimentos fornecidos.

Gênero, perspectiva e precisão factual são critérios separados. A correção do contrato de prompt é necessária, mas não demonstra eliminação de alucinações ou paridade com os textos de referência do assistente.
