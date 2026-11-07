# Etapa 3 · Canvas 2 "Ferramentas por dentro" · decisões do dono (07/11/2026)

Texto do dono, na íntegra. Canvas: https://claude.ai/artifact/76YnKZ4dDnYReZN7RHzxUW (versão 2). Vale este texto sobre qualquer desenho,
estimativa ou cronograma do canvas. O plano de execução e o estado de cada item ficam em `editor-e3-canvas2-plano.md`.

---

Revise e implemente o segundo canvas da etapa 3, “Ferramentas por dentro”, seguindo as decisões abaixo. Este texto consolida a avaliação anterior e o complemento da segunda revisão. Se um desenho, estimativa ou cronograma do canvas divergir destas decisões, siga este texto.

O objetivo é melhorar o Cue Studio para quem grava, edita e exporta no iPhone. A pessoa deve encontrar o próximo controle, entender qual parte do vídeo vai mudar, conferir o resultado e voltar ao mesmo ponto da edição com segurança. Preserve o visual do Cue, os atalhos úteis e as decisões já registradas em reports/editor-e3-decisoes-2026-11-07.md. Qualquer mudança estrutural fora das escolhas abaixo precisa de uma decisão separada.

## 1. Regras gerais dos painéis

| Decisão | O que implementar |
|---|---|
| R1 — A | Encurtar os subtítulos sem perder a identificação do objeto e do alcance. Preservar a ordem dos botões, o Reset quando aplicável, a indicação PREVIEW, o botão de expandir e o ✓ amarelo. Em tamanhos de acessibilidade, a legibilidade tem prioridade sobre caber em uma linha. |
| R2 — A | Em Texto, mostrar no cabeçalho o alcance persistente, como This title ou All 3 texts. Refletir o alcance na timeline principal e manter Style all como atalho. Motion atua por título. Deixar esse alcance explícito e restaurar o contexto de estilo em todos os textos ao voltar a Fonte ou Cor, quando esse era o contexto anterior. Nas cópias pontuais, mostrar o número de cortes, clipes ou itens afetados e permitir desfazer o lote em uma ação. Manter o selo ALL e o alcance implícito de onde a ferramenta foi aberta. |
| R3 — A | Manter ferramenta e aba como níveis de navegação. Texto fica com Styles, Font, Color e Motion. Animated vira filtro de Styles. Modelos e Kit da marca ficam em painéis separados, acessíveis pelos respectivos botões da barra. |
| R4 — A | Abrir os painéis na altura adequada à tarefa. Quando o ajuste depende da imagem, priorizar a prévia e colocar o controle principal à vista. Em Limpar fala e Selecionar legendas, mostrar a lista antes dos ajustes e preservar o contexto na timeline principal. Música, efeitos sonoros e Adicionar mídia abrem em folha alta. |
| R5 — B com resets específicos | Corrigir o nome das ações de Desfazer. Em Ajustar, o chip Auto seleciona o controle e Measure executa a análise de forma explícita. Deixar a ação visível quando o Auto estiver aberto e comparar os toques reais com o fluxo atual. Manter os resets por ajuste e acrescentar somente os resets com escopo definido nesta proposta. Em Tela dividida, Center and fill deve atuar apenas sobre o enquadramento. Conferir em Fundo como voltar ao original e tornar perceptível quando Recorte está ativo. |
| R6 — A | Unificar os nomes que realmente confundem nos idiomas do app. Usar Volume de forma consistente para o mesmo controle, Duration para duração e Stop para parar de seguir. Preservar distinções úteis de contexto e convenções como Motion de um objeto e Animation do clipe. |
| R7 — A | Lembrar a aba e o estado de Advanced por painel no mesmo vídeo. Quando dependem do item, lembrar por item. Abrir outro clipe ou vídeo com o estado apropriado a ele. |
| R8 — A | Com o teclado aberto, manter acessíveis o campo e o próximo controle da tarefa. Conferir Capa, Kit da marca e etiquetas de Gráficos, além dos campos já tratados. |
| R9 — A | Em texto grande, permitir quebra por palavra, dar largura aos rótulos, empilhar ações quando necessário e adaptar seletores longos. Testar também VoiceOver, idiomas com rótulos longos e árabe. |
| R10 — B, com regra explícita | A timeline e suas faixas pertencem à tela principal do editor. Nenhum sheet ou painel recebe faixa, minitimeline, playhead ou uma réplica navegável da timeline. Use nome do objeto, alcance ou timecode em texto quando der contexto. Abrir uma ferramenta comum deve preservar o acesso à timeline principal e manter o clipe e o ponto de edição. As folhas altas de seleção de mídia, música e efeitos podem ocupar a tela enquanto a pessoa escolhe. |
| R11 — A | Guardar o rascunho de Texto para fala e do Kit ao fechar acidentalmente e restaurá-lo no contexto certo. Cancelar ou descartar explicitamente deve respeitar a intenção da pessoa. Em Adicionar mídia, confirmar o descarte quando houver seleção e informar quantos itens serão perdidos. Manter a proteção existente da Capa e fechar diretamente quando não houver trabalho em risco. |
| R12 — A | Manter − e + para precisão e permitir repetição ao segurar. Oferecer durações comuns ao tocar no valor onde forem pertinentes. Distinguir duração de posição absoluta de início ou fim. Abrir o seletor por si só deve preservar o valor. Manter as réguas de duração de Transição e Movimento. |

## 2. Decisões por ferramenta

| Decisão | O que implementar |
|---|---|
| F1 — A | Preservar a estrutura atual de Legendas e seus atalhos. Em Selecionar, chamar de Highlight line o destaque da linha inteira. No Estilo da legenda, incluir Choose words to emphasize, abrindo a edição da linha sob a agulha. Conferir o retorno ao estilo e ao mesmo ponto da edição. |
| F2 — A com ajustes | Abrir Estilo da legenda mostrando estilos completos, com o atual marcado. Tirar a seção Mine vazia do topo de All e manter Save style no fim da galeria correspondente. Preservar um atalho compacto de Tamanho em Styles, sem empurrar a galeria para fora da primeira vista. O ajuste completo fica em Layout. Em Layout também fica a segmentação do texto, inclusive uma palavra por legenda. Em Animation ficam a animação palavra por palavra e o destaque da palavra falada. Manter a cor do destaque em Custom e nomear claramente o alcance de cada reset. Medir “Texto por legenda” nos idiomas do app, incluindo alemão e finlandês. Se o rótulo precisar mudar, trazer uma proposta. |
| F3 — A | Aplicar as quatro abas e o alcance no cabeçalho definidos em R2/R3. Colocar os ajustes do estilo animado abaixo dos cartões e o menu ••• no canto, livre da amostra. Manter os atalhos Edit e Style da barra e seus comportamentos. |
| F4 — A | Organizar Gráficos em duas abas. Deixar cor, tamanho e rotação no estilo e reutilizar o padrão de Motion do Texto. Preservar o acesso direto pela barra. |
| F5 — B | Dividir apenas o painel atual de Foto ou vídeo em Show e Part. Preservar Volume, Motion e Máscara como ferramentas próprias, com acesso direto pela barra. Testar mídia em janela, recorte do trecho, volume e animação no mesmo projeto. |
| F6 — A | Normal e Curve trocam a vista. Aplicar explicitamente uma velocidade normal substitui a curva e pode ser desfeito. Cada clipe abre com o próprio estado. Colocar Keep voice pitch antes de Advanced e conferir no iPhone menor. |
| F7 — B | Usar uma fileira rolável para os estilos de Transição, com nomes legíveis e indicação de que há mais opções. Manter a régua de duração inteira e a aplicação em todos os cortes como ação separada e visível. Preservar a precisão e o alcance contado de R2. |
| F8 — A | Manter Filtros compacto, com cartões mais baixos e Intensidade acima dos cartões quando um filtro estiver aplicado. Conferir o controle principal e a prévia com o painel aberto. |
| F9 — A | Usar Texture no chip e na régua de Pele. Preservar a distinção entre tocar num preset, que aplica, e tocar num chip de ajuste, que seleciona o controle. |
| F10 — A | Manter Limpar fala médio, com abas e expansão por botão. Mostrar uma fileira de pausas ao abrir. O cabeçalho dá acesso ao limite de pausa e ao espaço deixado. O rodapé diz o que será removido. Na aba Texto, a dica de seleção de palavras deve continuar acessível mesmo com pausas pré-marcadas. As marcas ficam na timeline principal. |
| F11 — A | Subir o seletor e a ação de criar cortes nas batidas. O botão mostra o intervalo escolhido. Diferenciar criar cortes de mover os existentes para a batida mais próxima. Ajustar a mensagem à origem real do áudio, seja biblioteca do Cue ou Arquivos. Manter Batidas na barra da música. |
| F12 — A | Expor Edit e Remover no grupo My fonts dos seletores que mostram fontes importadas. Pressionar e segurar continua como atalho. Conferir o comportamento de projetos que já usam uma fonte removida. |
| F13 — A | Usar uma folha alta para Música e Efeitos sonoros, com abas visíveis. Cada botão da barra abre sua aba. Deixar Browse Files perto da busca de Música e eliminar títulos duplicados. |
| F14 — A | Manter os quatro modos de Adicionar mídia com cartões menores, explicação curta e mais galeria à vista. Deixar claros os estados selecionado e desmarcado, a ordem da sequência e o descarte. Testar selecionar três vídeos e retirar um antes de confirmar. |
| F15 — A | Trazer Pop para o início dos presets. Organizar em presets e duração, depois Seguir e Keyframes, com início e fim em Advanced. Preservar os atalhos da barra. Validar o Pop pausado no primeiro quadro, após fechar o painel com o objeto ainda selecionado, ao retornar a agulha à entrada e no final de In + Out. A pessoa precisa ver o objeto sem que o playhead pule a animação. Conferir a animação em PREVIEW, na reprodução e no arquivo exportado. |
| F16 — A com Follow face voluntário | Usar cartões mais baixos e deixar Reset e Follow face visíveis. Follow face só liga por escolha da pessoa, inclusive ao converter um vídeo deitado para vertical. Com vários rostos, baixa confiança ou formato incompatível, comunicar a limitação e preservar o enquadramento. Corrigir o aviso que oferece o formato já selecionado. Mostrar as dimensões reais quando o recorte reduzir a resolução. Preservar a regra de exportação sem ampliação automática. |
| F17 — A | Corrigir o Done com texto grande. Dar largura inteira às opções e colocar os selos abaixo do título quando necessário. Validar leitura completa, inclusive no maior tamanho de acessibilidade. |
| F18 — A | Manter os cinco passos da Capa. Em Imagem, deixar Zoom e Reset acessíveis. Em Título, usar Words, Type, Color e Box; manter o destaque e Line above acessíveis com o teclado. Em Gráficos, priorizar os controles do item selecionado. Usar Effects no último passo, pôr Save style em Template, manter a remoção da capa e Next: X, e retirar a sugestão que repete o título atual. |
| F19 — A | Abrir as opções de exportação dentro da mesma folha do Done, com retorno claro. Incluir qualidade, dimensões efetivas e as escolhas de legenda previstas em D11. Partir do idioma do editor e aceitar uma escolha explícita para aquele vídeo. Manter as opções discretas, com hierarquia separada dos avisos de exportações grátis e de fonte. |

## 3. Barra, timeline e atalhos

* M1 — C. Manter os painéis separados. Adiar a navegação entre ferramentas vizinhas e o painel unificado. Qualquer retomada começa por comparar tarefas reais, espaço de prévia e esforço para encontrar a próxima ferramenta.
* M2 — A. Marcar discretamente na barra as ferramentas já aplicadas ao clipe selecionado. Diferenciar esse indicador do selo ALL e anunciar o estado no VoiceOver. Conferir se acompanha troca de clipe, Reset e Desfazer.
* M3 — A. No Limpar fala, tocar numa marca da timeline principal deve levar ao cartão correspondente e destacá-lo. Preservar o caminho inverso, do cartão para a marca, e deixar claro quando uma ação muda a seleção de pausas que serão removidas. Nas Legendas, preservar o comportamento aprovado de abrir e fechar o painel pelo toque na faixa.
* N1 — A. Na timeline principal, usar um ícone reconhecível de faixas empilhadas e mostrar a contagem. Dar às marcas de Transição um alvo de toque adequado quando nenhum clipe estiver selecionado, sem disputar o gesto das alças de trim. Conferir o caminho até Música e Batidas partindo de outra faixa.
* N2 — A. Na barra de uma legenda selecionada, colocar Style logo depois de Edit. Reposicionar Emphasis conforme o canvas e preservar a ordem dos outros grupos.

Preserve a barra principal, as ferramentas contextuais, a lixeira fixa quando aplicável e os atalhos diretos já aprovados. Na revisão de ferramentas repetidas, diferencie um atalho útil que abre o mesmo controle de duas implementações ou dois rótulos que criam dúvida sobre o que será alterado. A reorganização interna dos painéis deve resolver o segundo caso e preservar o primeiro.

## 4. Correções que precisam aparecer na entrega

Cruze estes pontos com os 12 itens do canvas. Os itens 4 e 6 envolvem comportamento de produto e seguem R2 e F6.

1. Volume da sobreposição. O Reset deve aparecer quando o volume da sobreposição selecionada mudou e restaurar somente esse volume. Testar com o clipe principal também alterado e conferir Desfazer.
2. Done em texto grande. Corrigir rótulos e selos conforme R9/F17.
3. Desfazer. Identificar a ação ou ferramenta correta em pausas, espaço deixado, batidas e ajustes de clipe.
4. Escopo Texto → Motion → Texto. Conferir o alcance individual do movimento e o retorno ao contexto de estilo anterior.
5. Origem da música em Batidas. Usar a mensagem correspondente à faixa do Cue ou ao arquivo importado.
6. Normal e Curve. Navegar entre vistas preserva a curva. A troca ocorre ao aplicar explicitamente uma velocidade.
7. Dica de corte por palavras. Manter acessível mesmo com pausas pré-marcadas.
8. Velocidade por clipe. Impedir que a aba de um clipe determine a de outro sem relação com seu estado.
9. Nome de Volume. Alinhar a barra, o controle e o subtítulo para a sobreposição.
10. Resolução real. Conferir no arquivo final as dimensões de vídeos horizontais recortados. Mostrar no Done o tamanho que será entregue quando diferir da qualidade escolhida.
11. Aviso do Follow face. Oferecer formatos que façam sentido para o estado atual, sem sugerir o formato que já está selecionado.
12. Aviso de áudio em espanhol. Apontar para o objeto e o controle certos, inclusive quando a mídia vira apoio de tela dividida. Conferir se a instrução leva ao botão que aparece no app.

Traga também evidência de que Volume › Avançado pode ser alcançado por inteiro e de que Fundo › Recorte é encontrável e indica quando está ativo. Esses dois casos aparecem no inventário do canvas e precisam de verificação explícita.

## 5. Execução e validação

1. Cruze o canvas com a branch de trabalho antes de implementar. Confira o código atual, as 16 decisões registradas e o estado das correções já iniciadas. Reorganize as ondas para incluir F1 na entrega de legendas e F19 junto de Done, D11 e exportação. Trate R10-B como restrição de layout e M1-C como adiamento. Para cada uma das 36 decisões e dos 12 pontos, indique a entrega e a evidência esperada.
2. Respeite o primeiro marco já combinado. Entregue a barra e a limpeza integrada para avaliação no iPhone. Enquanto essa avaliação estiver pendente, avance com as correções independentes. As mudanças que dependem do novo layout esperam o resultado desse teste. Faça commits separados por entrega e rode um build por vez no Mac.
3. Teste o editor em uso, com vídeo real. Compare antes e depois em um iPhone menor e num tamanho de referência. Mostre abertura, expansão e fechamento dos painéis, quanto da prévia sobra, o primeiro controle visível, o acesso à timeline principal, o teclado e o retorno ao mesmo clipe e ponto de edição. Para os caminhos que mudaram, registre toques e rolagens reais. Separe o que foi testado em aparelho, em Simulator e no código.
4. Teste um fluxo completo de talking head. Grave ou importe um take, corte uma pausa e algumas palavras, ajuste a legenda, estilize um título com Pop, adicione uma mídia em janela, ajuste o volume dela e exporte. Inclua um projeto existente. Confira se ações locais preservam outras camadas, se Desfazer funciona e se fechar e reabrir mantém o estado certo.
5. Valide a exportação pelo arquivo gerado. Use um vídeo em que original e tradução tenham textos claramente diferentes. Confira os pixels das legendas com original, tradução, ambos e legendas desligadas. Verifique dimensões reais, sincronismo e os caminhos de salvar e compartilhar. A escolha de idioma de um vídeo deve ficar restrita a ele. Ao testar a passagem pelo Done, confira também a convivência das opções com os avisos existentes.
6. Mantenha a condição de D16. Antes de ativar a automação de limpeza prevista nessa decisão, ouça os casos difíceis no aparelho, incluindo fala baixa, respiração, ventilador, rua e música. Se a detecção estiver incerta, mantenha o aviso honesto. Posição de legenda por trecho, áreas seguras, zoom por frase, Meu estilo e edição automática continuam nas etapas já previstas.

No relatório de cada entrega, informe o commit, as decisões cobertas, o que mudou para quem edita, a evidência e as pendências. Para a aprovação visual, envie um vídeo curto do fluxo no iPhone com um roteiro de teste. O ponto de aprovação é conseguir achar o controle, entender o alcance, conferir o resultado e retomar a edição com segurança.

## 6. Atualização do plano das etapas 4 e 5 (acréscimo do dono, 07/11)

Antes de iniciar a etapa 4, revise o plano original das cinco etapas à luz do segundo canvas da etapa 3 e das decisões aprovadas. Atualize o documento do plano, mantendo cada funcionalidade na etapa em que já foi aprovada. Para cada mudança de fluxo, registre o caminho anterior, o novo caminho, a dependência da etapa 3 e o teste de aceitação. Se a revisão exigir mudar uma funcionalidade de etapa ou introduzir uma decisão estrutural, traga a proposta separadamente.

Etapa 4. Desenhe o fluxo de posição de legenda por trecho e áreas seguras sobre o editor atualizado. A seleção temporal acontece na timeline principal. Se o ajuste for local, a interface deve identificar o trecho e deixar claro o que será alterado antes do primeiro gesto. Defina como o ajuste global se relaciona com posições locais e como restaurar apenas a posição do trecho escolhido. Valide com duas legendas em posições diferentes, uma mudança global depois disso e um export final para conferir o enquadramento. A regra R10-B vale também aqui. A timeline fica na tela do editor, fora dos sheets e painéis.

Etapa 5. Confira quais recursos pertencem a essa etapa no plano original e atualize os fluxos correspondentes. Para Meu estilo, se estiver previsto, especifique o que o preset salva e o que preserva ao ser reaplicado, especialmente ajustes manuais por trecho. Para zoom por frase ou edição automática, onde estiverem previstos, defina como a pessoa confere o resultado, como desfaz a operação e como cortes e mudanças de tempo afetam legendas, áudio e mídias já editados. Teste em um projeto que já tenha ajustes manuais.

Atualize primeiro as dependências e os critérios de aceitação. Depois da avaliação da etapa 3 no iPhone, feche os pontos de entrada, a altura dos painéis e a interação com a timeline. A implementação deve partir do fluxo validado no aparelho e das decisões registradas.

## 7. Esclarecimentos do dono (07/11, depois das decisões)

1. **F1, nome do chip do Selecionar:** "Escolha Emphasize line. A Claude tem razão em corrigir minha sugestão anterior. O botão aplica a cor e o tamanho de ênfase à linha inteira. Highlight fica reservado ao destaque da palavra que está sendo falada. Whole line indica o alcance, mas deixa a ação implícita. Use Emphasize line em inglês e Enfatizar linha em português. Mantenha Choose words to emphasize para escolher palavras específicas e Highlight color para a cor da palavra falada. Atualize o rótulo em F1."
2. **R10-B, as cinco tiras:** "Ajuste R10-B para manter a timeline principal, suas faixas e a navegação do projeto fora dos sheets. Preserve os cinco controles existentes como editores locais: o indicador de posição na Curva, os seletores de trecho em Foto ou vídeo e Tela dividida, as palavras da linha em Legendas, o seletor de quadro da Capa e o recorte da mídia nova. Cada controle deve ficar restrito ao item ou à tarefa aberta. Na Capa, escolher um quadro atualiza a prévia da capa e preserva a posição em que deixei a timeline principal ao voltar ao editor."
3. **R10-B, painéis cheios:** "Em Estilo do texto e Estilo da legenda, deixe à vista por padrão a régua e a faixa relevante da própria timeline principal, acima do painel. Mantenha a prévia e pelo menos uma fileira completa de estilos visíveis ao abrir. Valide no SE e no iPhone 17. Se no SE isso apertar demais a galeria, priorize os estilos e ofereça um botão visível para recolher o painel e acessar a timeline em um toque, sem precisar tocar em ✓. Ao expandir de novo, preserve o item selecionado, o estilo e a posição da agulha. Expandir voluntariamente ou abrir o teclado pode ocultar a timeline temporariamente. Nenhuma faixa da timeline principal entra no painel."
