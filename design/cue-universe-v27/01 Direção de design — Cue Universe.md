# Cue Studio — Direção de design: "Cada criador tem um universo"

**Versão:** v27 (proposta) · 4 de outubro de 2026
**Base:** Cue App v26 (fluxos, lógica e dados continuam os da v26)
**Canvas de referência:** https://claude.ai/artifact/Hp4M32mkCAz1nTkxPeLSRx (página "Final workflow")
**Para quem é este documento:** para você, para o Claude Design (que vai gerar a v27) e para o Claude Code (que vai programar). As especificações técnicas, com números, estão em `06 Specs/DESIGN-SPEC.md`.

---

## 1. A ideia em uma frase

> **Cada criador tem um universo para compartilhar, e o Cue ajuda esse universo a chegar mais longe.**

O Cue não é um teleprompter com efeitos de espaço. É o estúdio de quem fala para a câmera, com uma personalidade própria: calma, noturna, luminosa. O espaço serve de moldura para o conteúdo e nunca compete com ele.

---

## 2. O conceito: o criador viajante

Todo criador vive num mundo: o tema que ele domina e ama, como manhãs produtivas, finanças pessoais ou viagens baratas. O que ele faz no Cue é **preparar algo seu para levar a outros mundos**. Cada vídeo é uma viagem que sai do mundo dele, atravessa uma galáxia (uma rede social) e chega a outras pessoas, que aprendem com ele e respondem.

O Cue é a nave e os instrumentos: roteiro, teleprompter, editor, legendas e a IA que escreve na voz dele. **Quem decide o rumo é sempre o criador.** A IA sugere e o criador aprova.

### O mapa da metáfora

| No tema | No Cue | Onde aparece |
| --- | --- | --- |
| O viajante | O criador. Decide tudo. Nunca é chamado de "capitão" na interface. | Princípio de design, não palavra na tela |
| O mundo dele | O tema central do criador. Pode ter até 3. | Onboarding (temas viram mundos em órbita), cores dos temas, etiqueta automática nos roteiros |
| Você, no centro | O criador como uma estrela branca no meio do próprio universo | "Your universe", onboarding, Profile |
| Galáxias | As redes: TikTok, Reels, Shorts, YouTube, LinkedIn | Escolha da rede, filtros, rota da despedida |
| Outros mundos | O público e outros criadores | Responder ao público com um vídeo (fase 3) |
| A viagem | Cada vídeo, da ideia à publicação | A jornada inteira do app |
| A estrela | Cada vídeo compartilhado vira uma estrela no universo do criador | Primeira estrela (onboarding), despedida, marcos |
| O horizonte | A linha de leitura amarela do teleprompter | Teleprompter, contagem, ícone do app |
| O navegador | A IA, sempre em violeta, sempre sugerindo | Roteiro, ganchos, melhor take, respostas |
| Os instrumentos | Os controles com orb (velocidade, tamanho, volume, brilho) | Ajustes, editor, Studio, Personalize |

### O que a pessoa deve sentir

- **Inspiração**: o app lembra que ela tem algo valioso para compartilhar ("Every creator has a universe to share").
- **Curiosidade**: pequenos momentos de descoberta, como um mundo nascendo, uma estrela acendendo ou um cometa partindo, convidam a explorar sem atrapalhar.
- **Confiança**: tudo é claro, preciso e sob controle. A IA ajuda mas não decide. Os valores sempre aparecem escritos. Nada é publicado sem ela.

Em resumo, a sensação é de **preparar algo seu, com calma e cuidado, para levar a outros mundos**.

---

## 3. A jornada: da ideia à publicação

O app inteiro é uma viagem em cinco etapas. Cada etapa tem um papel na metáfora, uma emoção-alvo e uma assinatura visual própria.

| Etapa | Telas | Na metáfora | Emoção | Assinatura visual e de movimento |
| --- | --- | --- | --- | --- |
| **1. Ideia** | Scripts, Need an idea?, Logbook, estado vazio | Uma estrela nasce | Curiosidade | Céu de três camadas nas telas de navegação; ✦ violeta para ideias da IA; "Every universe starts with an idea." |
| **2. Roteiro** | Página do roteiro, ganchos, melhorar com IA | Traçar a rota | Confiança | Palavras que nascem da luz enquanto a IA escreve; aura violeta girando na borda; gancho, corpo e CTA como trechos de uma rota |
| **3. Gravação** | Contagem, teleprompter, Studio | A partida; o horizonte | Foco e coragem | Anel de 12 estrelas na contagem; linha do horizonte; palavras que acendem quando são ditas; trilha de constelação mostrando gancho, corpo e CTA |
| **4. Refinamento** | Escolher o take, editor, legendas, som, texto | Ajustar os instrumentos | Controle | Varredura de análise e estrela no melhor take; controles com orb; editor limpo, sem céu |
| **5. Publicação** | Pronto para postar, despedida, marcos, seu universo | A viagem e a chegada | Orgulho | O vídeo vira luz e viaja como cometa até a rede; flash de chegada; nova estrela; marcos liberam ícones do app |

### O primeiro voo (onboarding)

O onboarding conta a história em 7 capítulos curtos e já leva a pessoa a usar o app de verdade:

1. **Boas-vindas**: as estrelas chegam com um zoom lento, a constelação se desenha, a estrela amarela acende e a frase "Every creator has a universe to share." surge do desfoque.
2. **Seu universo**: a pessoa toca nos temas, e cada tema vira um mundo em órbita ao redor dela ("YOU").
3. **Primeira viagem**: escolhe a galáxia (rede). Uma rota se desenha com um cometa até lá, e o Cue já define formato, duração ideal e zonas seguras.
4. **Primeiro roteiro**: a IA escreve um roteiro de ~15 segundos no tema escolhido, com as palavras nascendo da luz ("Your first script, in your voice."). Sem Apple Intelligence, entra um roteiro pronto do mesmo tema, sem prometer IA.
5. **Dê voz a ele**: os pedidos de microfone e câmera fazem parte da história. O botão diz "Continue" e o alerta do iOS aparece em seguida; ao permitir, a íris da câmera se abre e mostra o rosto da pessoa.
6. **Treino**: o teleprompter rola de verdade e as palavras acendem enquanto ela lê. Ela escolhe "Record it for real" ou "Not now — take me to my studio".
7. **Primeira estrela**: o take se dobra em luz, voa até o universo dela e vira a primeira estrela.

Não há paywall no onboarding. A pessoa sai dele já tendo usado as três coisas que fazem o Cue único: roteiro na voz dela, texto que segue a voz e o vídeo virando estrela.

---

## 4. Princípios de design

1. **O conteúdo é o herói; o espaço é a moldura.** O céu estrelado só aparece nas telas de navegação. Nunca sobre o rosto do criador, nunca sobre a edição, nunca sobre o vídeo.
2. **Sutil, nunca literal.** Nada de naves, missões, uniformes ou painéis de ficção científica. Planetas pequenos, estrelas discretas, luz em vez de objetos.
3. **Movimento com significado.** Cada animação explica uma mudança de estado: algo nasce, viaja, chega, segue a voz ou é escolhido. Em telas de trabalho, nada se mexe só para enfeitar.
4. **Você no comando.** A IA sugere em violeta e o criador decide em amarelo. "You review every word. Nothing is posted without you."
5. **Clareza antes da poesia.** Os nomes dos recursos são funcionais (Scripts, Takes, Record, Captions, Settings). A metáfora vive nas transições, nos estados vazios e nas comemorações, nunca nos rótulos que a pessoa precisa entender.
6. **Preciso e acessível.** Todo valor aparece em texto, todo alvo de toque tem 44 pt, tudo funciona com VoiceOver e com "Reduzir movimento".

---

## 5. Como a temática aparece

### 5.1 Nas animações

Há uma linguagem de movimento única, feita de poucos elementos que se repetem com sentido:

| Elemento | O que significa | Onde aparece |
| --- | --- | --- |
| **Céu em três camadas** (estrelas distantes, médias e próximas em velocidades diferentes) | Profundidade, calma, "você está em casa" | Telas de navegação e onboarding |
| **Cintilar com brilho em cruz** (como estrela vista pela câmera do celular) | Vida no céu | Poucas estrelas por tela, 3 a 8 |
| **Estrela cadente** (rara, a cada 11 a 14 s) | Um pequeno presente para quem olha | Telas de navegação |
| **Constelação que se desenha** | Ideias se conectando | Boas-vindas, ícone Constellation |
| **Ignição** (onda de luz + brilho em cruz) | Algo importante começou | Estrela do Cue, melhor take, chegada, marcos |
| **Nascimento de um mundo** (faísca, órbita que se desenha, planeta que surge) | Um tema virou parte do seu universo | Onboarding, novos temas |
| **Cometa** (cabeça de luz + cauda, com a rota desenhando) | Seu conteúdo viajando | Primeira viagem, despedida, primeira estrela |
| **Chegada** (flash + duas ondas) | Chegou a outro mundo | Galáxia de destino |
| **Palavras que nascem da luz** (desfoque → nítido, com brilho violeta) | A IA escrevendo na sua voz | Roteiro, primeiro roteiro, respostas |
| **Aura da IA** (luz girando na borda do card) | A IA está trabalhando | Enquanto escreve |
| **Horizonte** (linha amarela de leitura) | Onde você está lendo agora | Teleprompter, contagem, ícones do app |
| **Palavras que acendem** | O texto segue a sua voz | Teleprompter e treino |
| **Trilha de constelação** | Progresso no roteiro (gancho → corpo → CTA) | Lateral do teleprompter |
| **Anel de estrelas** | Contagem regressiva | 3, 2, 1, "Let's Cue" |
| **Orb com anel de órbita** | Você está ajustando um valor | Todos os sliders |
| **Brilho no botão principal** | O próximo passo | Botões amarelos, com moderação |

Regras gerais:

- Durações curtas nas interações (120 a 400 ms) e mais longas só nos momentos de história (onboarding, despedida, marcos).
- Molas suaves para coisas físicas (orb, abas, cartões) e curvas de desaceleração para luz.
- **Reduzir movimento** desliga o céu animado, as órbitas, os cometas e os brilhos. Ficam só as mudanças de estado, com fade.
- Haptics acompanham os momentos certos: toque leve ao escolher, "success" quando algo chega, tique a cada passo de um slider.
- Durante a gravação, só se mexe o que ajuda a ler: horizonte, palavras e trilha.

### 5.2 Nos ícones

O conjunto **"orbit line" (v2, 53 ícones)** foi desenhado como um caminho de luz:

- Grade de 24 pt, margem de 2 pt, traço único de 1,75 pt, pontas e cantos arredondados.
- **Três motivos discretos**, usados só onde fazem sentido:
  - **o orb**: um pequeno círculo cheio que representa você, um valor ou um estado (gravar, linha de leitura, velocidade, ajustes, aba ativa);
  - **a órbita**: um arco aberto para o que volta ou se repete (virar câmera, refazer, seu universo, tema);
  - **a estrela**: a estrela de 4 pontas do Cue; violeta quando é IA, amarela quando é conquista ou melhor take.
- Ícones monocromáticos; a cor vem do contexto: amarelo = ação e sinal, violeta = IA, vermelho = só gravação, cinza 62% = repouso.
- **A aba ativa ganha um orb amarelo que viaja até a aba escolhida**, como um pequeno planeta mudando de órbita.
- **Ícones alternativos do app** são liberados por marcos: Aurora (1º compartilhamento), First Light (10), Deep Space (25) e Constellation (50, as estrelas formam um "C"). Todos mantêm a linha de leitura amarela, que é a assinatura da marca.

### 5.3 Nos textos

A voz é **calorosa, curta e confiante**. As palavras do espaço aparecem raramente, sempre no momento certo:

- **Onde a metáfora entra:** onboarding, estados vazios, conclusões, comemorações, marcos e o título do paywall.
- **Onde ela não entra:** botões de ferramentas, rótulos de ajustes, mensagens de erro, textos legais e de privacidade.
- **Vocabulário permitido, com moderação:** universe, world, star, voyage, send-off, horizon, galaxy (só no onboarding), orbit (só em descrições).
- **Nunca usar:** captain, mission, crew, warp, stardate, "boldly go" ou qualquer termo, som ou visual de Star Trek. "Captain" tem gênero em várias línguas e soaria forçado.

| Momento | Texto (EN) | Por que funciona |
| --- | --- | --- |
| Boas-vindas | Every creator has a universe to share. | A promessa da marca, em uma linha |
| Estado vazio | Every universe starts with an idea. | Transforma o "nada aqui" num convite |
| Onboarding | This is your universe. · Every video is a voyage. · Your first script, in your voice. · Your script is ready. Now it needs you. · Your universe has its first star. | Uma história curta em 5 capítulos |
| Contagem | Let's Cue · Just talk. The text follows your voice. | Tira a pressão antes de gravar |
| IA | Writing in your voice · You review every word. Nothing is posted without you. | Confiança: a IA serve o criador |
| Despedida | On its way. · It's now a star in your universe › | O orgulho de publicar |
| Marco | A new icon is yours. | Recompensa concreta, sem exagero |
| Paywall | Take your universe further. | Benefício emocional + lista objetiva |
| Erro | Couldn't save the video. Try again. | Sem metáfora: clareza em primeiro lugar |

**Nas 20 línguas:** as metáforas (universo, mundo, estrela, viagem) traduzem bem. Evitar trocadilhos, gírias e palavras com gênero. Os textos novos precisam de revisão nativa.

### 5.4 Nos detalhes da interface

- **App sempre escuro.** A noite é a identidade. O ajuste de aparência foi removido e o modo claro da v26 sai.
- **Cores com significado:** amarelo `#FFD60A` = ação, sinal e linha de leitura; violeta `#B4A7FF` = IA; vermelho = só gravação; verde = pronto; ciano = em edição.
  - **Temas = mundos**: âmbar `#FFC46B`, menta `#7EE0B8`, rosa `#FF9BD2` e azul-céu `#8FB8FF`.
  - **Redes = galáxias**: TikTok `#64D2FF`, Reels `#BF5AF2`, Shorts `#FF6B5A`, YouTube `#FF9F0A`, LinkedIn `#0A84FF`, Stories `#FF6FA8`.
- **Filtro principal por rede**, porque é como o criador pensa no dia a dia. O tema vira uma **etiqueta automática** (um ponto de cor) que a IA escolhe no aparelho e que a pessoa pode trocar.
- **A linha de leitura é a assinatura da marca.** Ela aparece no teleprompter, na contagem, nas prévias, no ícone do app e nos ícones alternativos.
- **Controles com orb.** Todo slider usa um pequeno planeta dourado como polegar e uma linha de luz como trilho. Ao segurar, surge um anel de órbita que gira devagar e o valor acende. O valor está sempre escrito, há posição padrão com tique tátil, controle fino (arraste para baixo) e toque duplo para voltar ao padrão. Estão em:
  - Ajustes do Prompter: velocidade, tamanho do texto, linha de leitura, margens, contagem;
  - Som no editor: voz, música, limpeza de voz;
  - Texto no editor: tamanho e brilho;
  - Legendas: tamanho;
  - Studio: velocidade;
  - Personalize: intensidade do céu.
- **Estilos de texto do editor com fontes gratuitas** (licença SIL Open Font License, que permite embutir no app). Os nomes seguem o tema sem atrapalhar:

| Estilo | Fonte | Caráter |
| --- | --- | --- |
| Orbit | Unbounded ExtraBold | Larga, geométrica, cósmica: títulos e ganchos |
| Logbook | Instrument Serif Italic | Editorial e elegante: citações, frases de efeito |
| Signal | Space Mono Bold | Painel de controle: números, listas, passos |
| Launch | Anton | Condensada e forte: ganchos de impacto (substitui "Impact") |
| Nebula | Syne ExtraBold | Expressiva, de personalidade |
| Comet | Space Grotesk Bold | Moderna e limpa: uso geral |
| Postcard | Caveat Bold | Manuscrita: notas pessoais |

Em línguas com outras escritas (japonês, coreano, chinês, árabe, hindi, tailandês), o estilo mantém cor, brilho e caixa, mas usa a fonte do sistema.

- **Tipografia do app:** SF Pro e SF Mono (fontes do sistema). Cobrem as 20 línguas, respeitam o Dynamic Type e são as que o app vai usar de fato. A Geist aparece só nas maquetes.
- **Sons:** nenhum efeito sonoro por padrão, porque criadores gravam áudio. A emoção vem de luz, movimento e haptics.

---

## 6. Decisões tomadas

| Data | Decisão | Por quê |
| --- | --- | --- |
| 4 out. | Personalidade "cada criador tem um universo" aprovada | Diferencia o Cue de apps com interface defasada e cria vínculo |
| 4 out. | Estilo das telas-conceito 1–14 escolhido, em vez da recriação fiel da v26 | Mais personalidade, mantendo os fluxos da v26 |
| 4 out. | Tema também no teleprompter, de forma funcional: horizonte, trilha de constelação e palavras que acendem | O tema ajuda a ler, sem céu sobre o rosto |
| 4 out. | Editor de vídeo continua próximo da v26 | É uma ferramenta de precisão; a personalidade fica nos controles e transições |
| 4 out. | Filtro principal por rede; tema como etiqueta automática | Criadores de vários nichos pensam por rede |
| 4 out. | App sempre escuro | A noite é a identidade; câmera, take e editor já eram escuros |
| 4 out. | Estrelas mais vivas, com brilho em cruz e estrelas cadentes | Pedido do fundador; mais vida sem poluir |
| 4 out. | Onboarding "primeiro voo" em 7 capítulos, com roteiro escrito pela IA no tema da pessoa | O momento "uau" vem de usar o app de verdade |
| 4 out. | Sem Apple Intelligence, o onboarding usa um roteiro pronto do mesmo tema | Funciona em todos os iPhones sem prometer o que não existe |
| 4 out. | Tela de permissões com botão "Continue" (não "Allow"), sem "Not now" nem "Skip" | A revisão da Apple costuma rejeitar telas que usam "Allow" ou oferecem um jeito de pular o alerta do sistema |
| 4 out. | Pedir "não rastrear" (App Tracking Transparency) só se o app usar rastreamento | Sem rastreamento, o pedido é desnecessário e prejudica a confiança |
| 4 out. | Sem paywall no onboarding | Primeiro a pessoa ama o fluxo; o Pro aparece depois das 5 exportações grátis |
| 4 out. | Controles com orb em todos os sliders | Ligam a interface ao tema com movimento suave, sem perder precisão |
| 4 out. | Ícones v2 "orbit line" (53) e orb que viaja na barra de abas | Linguagem visual única em todo o app |
| 4 out. | 7 estilos de texto do editor com fontes OFL; "Impact" vira "Bold" com Anton | A fonte Impact é comercial e não pode ser embutida no app sem licença |
| 4 out. | Interface em SF Pro / SF Mono | Cobertura das 20 línguas e Dynamic Type |
| 4 out. | Nunca "captain" na interface; nada da franquia Star Trek | Gênero nas traduções e risco de marca |
| 4 out. | Fases: lançamento → 1ª atualização → depois | Lançar com o que vende e reter com o que encanta |

---

## 7. Fases de implementação

1. **Lançamento**
   - Nova pele em todo o app: tokens, céu, ícones v2, orbs.
   - Onboarding "primeiro voo".
   - Teleprompter com horizonte, palavras que acendem e trilha de constelação.
   - Contagem com anel de estrelas e escolha do melhor take.
   - Abertura do editor, legendas, som e estilos de texto.
   - Pronto para postar, despedida com cometa e paywall.
   - Ajustes, Prompter e Personalize.
2. **1ª atualização:** Your universe, marcos e ícones alternativos, Logbook, etiqueta automática de tema.
3. **Depois:** responder ao público com um vídeo (extensão de compartilhamento + leitura do comentário + card no editor) e a retrospectiva do ano.

---

## 8. Em aberto

- **Preço mensal:** $7.99 (v26) ou $9.99 (memória do projeto). É definido no App Store Connect, não no código. O anual fica em $39.99 com 7 dias grátis.
- Revisão nativa dos textos novos nas 20 línguas.
- Incluir o arquivo de licença OFL de cada fonte no app (Settings › About › Licenses).
- Confirmar a licença comercial da foto da criadora usada nas maquetes.
- IA no plano grátis: ilimitada ou com limite (recomendação: ilimitada).

---

## 9. Onde está cada coisa neste pacote

Veja `00 LEIA-ME.md`. Em resumo:

- `00 Workflow overview.png`: todas as telas em ordem.
- `02` e `02b`: storyboards de movimento.
- `03`: imagens das telas.
- `04`: código HTML das telas, com as animações funcionando.
- `05`: ícones em SVG.
- `06 Specs`: especificações técnicas, mapa de telas e textos.
- `07 Prompts`: os dois prompts, um para o Claude Design e outro para o Claude Code.
