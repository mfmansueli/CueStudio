# Cue Studio: entradas do criador, auditoria, pesquisa e plano

Data: 01/11/2026 · Base: branch `main`, commit `ed350580` · Autor: Claude Code (Opus 5.5), a pedido do dono do app.

> **Revisões 2 a 4 (02/11):** depois das três análises do Codex e da primeira medição no iPhone, o **§11** responde a cada argumento, corrige os erros deste arquivo e traz o plano e as decisões revisados. Onde divergir do resto, vale o §11. **Implementação (02/11):** os consertos sem decisão e as bases Q0 e Q1 estão em **11.11**.

Este arquivo junta tudo: o que o app pede para o criador preencher, onde cada resposta é usada, o que não está chegando, o que pode sair, o que falta (lacunas), a pesquisa externa com fontes, a proposta para gênero gramatical e forma de tratamento, um plano por etapas e as decisões que ficam com o dono. Os anexos A a D, no fim, trazem as tabelas técnicas (com arquivo e linha do código) e os dois relatórios de pesquisa completos, em inglês.

---

## 0. Contexto para quem vai analisar

- **O app:** Cue Studio é um app de iPhone (SwiftUI, iOS 27) para criadores que gravam falando para a câmera (TikTok, Reels, Shorts, YouTube, LinkedIn). Tem teleprompter que acompanha a fala ("Voice Following"), editor de vídeo, legendas, compartilhamento e uma IA que escreve roteiros e sugere ideias. Interface em 20 idiomas: en, es, pt, fr, de, it, ja, ko, zh-Hans, zh-Hant, hi, id, ar, tr, th, vi, nl, sv, da, nb.
- **Quem escreve os roteiros:**
  - **Apple Intelligence no iPhone** (modelo pequeno, no aparelho).
  - **Apple Private Cloud Compute (PCC):** modelo maior da Apple na nuvem privada. É a **primeira escolha** para roteiros, reescritas e ganchos (`AIModelRoute.swift:28`).
  - **Ultra AI:** Google Gemini via Firebase. Hoje **só existe em builds de Debug** (`LaunchOptions.swift:288-291`).
  - As ideias ("Find inspiration") vão primeiro ao modelo do iPhone.
- **My Cue Voice:** o perfil de voz do criador. Tem quatro camadas: essenciais (quem é, tópicos, público, tom), personalidade (energia, frases, palavras, humor, palavrão, formatos, aberturas, finais, bordões, o que evitar, onde posta, duração), prova (exemplos colados, "Import my writing", "Sounds like me", "Your edits") e o interruptor "Use my voice in drafts".
- **Regras do dono que pesam aqui:**
  - As respostas ao dono são em português; o código, em inglês.
  - Os rascunhos podem imaginar cenas em primeira pessoa, mas **nunca inventar números, estudos ou credenciais** (01/11).
  - Voice Following é o padrão.
  - Os tópicos novos ficaram só no My Cue Voice e não viram mundos do universo (06/10).
  - Contraste WCAG AA em toda tela nova.
  - Todo texto novo entra nos 20 idiomas.
- **Como foi feito:**
  - Leitura do código (dois agentes e conferência manual dos achados mais graves).
  - Pesquisa na web (dois agentes): relatórios públicos, centrais de ajuda de concorrentes, fóruns, documentação da Apple, Google e Microsoft.
  - A presença no SDK do iOS 27 das APIs citadas (`TermOfAddress`, `NSMorphology.userMorphology`, `isUnspecified`) foi conferida.
- **Limites:**
  - Nada rodou no iPhone e nada foi alterado no app.
  - O Reddit bloqueou a leitura automática, então as opiniões de fórum vêm do fórum da OpenAI, Hacker News, issue trackers, newsletters e imprensa.
  - Parte dos números de mercado está atrás de paywall; nesses casos só o ranking é público.
  - Alguns fatos de 2026 vêm da web e não foram conferidos à parte.
  - Nada aqui é parecer jurídico.

---

## 1. Resumo executivo

1. Foram levantadas **61 entradas**: 33 chegam bem à IA, 15 chegam pela metade ou fracas, 2 são pedidas e nunca usadas, e 11 não são para a IA (ou são retorno para nós).
2. **A "prova" quase nunca chega ao roteiro.** Exemplos, "Import my writing", "Sounds like me" e "Your edits" são tirados do pedido no PCC (rota principal) e na Ultra. Só chegam quando o iPhone escreve como reserva, e nas ideias. Mesmo assim valem 20% do medidor da voz, e o aviso diz "Cue learns from it" (`AIRequestPolicy.swift:8-21`).
3. **O final escolhido é contradito ou desfeito.** No modelo do iPhone, a linha da plataforma (TikTok) pede chamada para ação mesmo com "No call to action". O PCC usa outro guia, que não impõe CTA, mas manda evitar "follow, like or subscribe" genéricos, o que contraria quem escolheu "Follow for more"; a Ultra também o desfaz. (Precisado e medido no §11.)
4. **Abertura e bordões viram opcionais no PCC e na Ultra** ("só quando o pedido sustentar").
5. **Texto apagado continua indo para a IA.** Aberturas, finais e bordões digitados são copiados para as tags livres e não saem quando o criador apaga.
6. **O briefing da marca se perde** em um caminho de criação, e as ferramentas reescrevem anúncios sem "Never say", link e cupom.
7. **Gênero gramatical não existe no app.** Em pt, es, fr, it, ar, hi e th, um roteiro em primeira pessoa muda com o gênero de quem fala ("cansado/cansada"). A IA escolhe sozinha, em geral no masculino. Os textos fixos (biblioteca de ideias) também erram ("appena sveglio" em italiano; o público tratado ora no masculino, ora no feminino).
8. **Lacunas de maior valor:**
   - gênero gramatical e forma de tratamento (tu/você, tú/usted, tu/vous, du/Sie);
   - um banco de histórias e fatos verdadeiros;
   - a oferta ou o negócio do criador;
   - o ritmo de fala real, medido nas gravações;
   - retorno a cada roteiro, aprendendo com o que o criador realmente falou.
9. **Dá para perguntar menos.** "Where you post", "Usual length" e "What you film most" podem ser deduzidos do uso; a dica "Who's watching?" repete o editor com outra lista; o tom repete energia, palavras e frases.
10. **Listas versus mercado:**
   - faltam tópicos grandes: comédia, saúde mental, ciência/história, cultura pop/fandom, direito, natureza, artesanato, sustentabilidade;
   - "My own business" mistura negócio local e negócio online;
   - "Budget travel" deveria ser "Travel".

---

## 2. Como uma resposta chega ao roteiro

1. **Perfil → voz.** O perfil vira `CreatorVoice`.
   - Tom e vocabulário só entram depois de respondidos.
   - Tópicos só entram quando a ideia digitada repete uma palavra deles (`IdeaFocus.swift:17-28`); subtópicos, só quando a ideia cita o próprio subtópico.
   - Os textos importados são filtrados por idioma e assunto (até 2 por pedido).
2. **Três portões** (`ScriptRequestFactory.swift:42`):
   - "Use my voice in drafts" ligado;
   - o criador respondeu tipo de criador, tópico, público ou tom (`CreatorProfile+VoiceSetup.swift:46-48`);
   - o formato não é sério (Apology).
3. **Qual IA:** roteiros, reescritas e ganchos vão primeiro ao PCC; ideias, ao iPhone; Ultra só em Debug.
4. **O que cada rota corta:**
   - PCC e Ultra não recebem exemplos, textos importados nem roteiros aprovados.
   - No Auto, a duração habitual sai do pedido em todas as rotas (`AIRequestPolicy.swift:27`).
   - A Ultra divide a voz: o rascunho recebe quem é e para quem fala; só o polimento recebe como fala.
5. **Limite de tamanho:** se a voz não cabe, sai primeiro o exemplo, depois "onde posta / duração", depois as tags livres (`VoiceBriefBuilder.swift:26-38`).
6. **Conferência:** no Apple Intelligence o roteiro é conferido (o que evitar, eu/nós, bordão no início, nome do estilo) e reescrito uma vez se falhar. A Ultra não tem conferência.

---

## 3. Inventário: tudo o que o criador preenche

Veredito: **CHEGA** (vai à IA e é usado) · **METADE** (só em algumas rotas ou casos) · **FRACO** (vai como sugestão opcional) · **NÃO VAI** (pedido e nunca usado) · **NÃO É P/ IA**.

### 3.1 Onboarding
| Entrada | Opções | Onde é usada | Veredito |
|---|---|---|---|
| "What do you usually talk about?" + "your own" | 10 tópicos, até 3 | Ideias (sempre), universo (mundos/cores), tags automáticas, biblioteca de ideias, notificações; roteiro só quando a ideia repete a palavra. Escolher um tópico já liga a voz. | METADE (roteiro) |
| "Where will you share your videos?" | 5 plataformas | Plataforma padrão de todo roteiro, teleprompter, barra de criação | CHEGA |
| Permissões, roteiro de treino | texto fixo | — | NÃO É P/ IA |

### 3.2 My Cue Voice · essenciais
| Entrada | Opções | Onde é usada | Veredito |
|---|---|---|---|
| "What kind of creator are you?" | 8 + texto próprio | "Who they are: …" nas três IAs e nas ideias; ordena os grupos de público; marca "Common for…" no tom; eu/nós padrão. Na dica, o texto próprio vira tag livre. | CHEGA |
| "Your credential" | texto | "Mention it only where it fits; never invent another." | CHEGA |
| "Scripts say" I / We | 2 | Regra de pessoa + conferência no iPhone (o PCC tolera desvio) | CHEGA |
| "What do you talk about?" | 25, até 3, + próprio | Roteiro só se a ideia repete a palavra; ideias, todos. Os 15 extras não viram mundo nem tag. | METADE |
| "More specific in …" | ~7 por tópico, até 3, + próprio | Roteiro só o subtópico que a ideia cita; ideias, todos | METADE |
| "Who is watching?" + "Describe them" | 8 grupos ou texto | "Their audience: …" nas três IAs | CHEGA |
| "Who's watching?" (dica) | 4 opções diferentes | Grava o vocabulário, que só vai sem grupo, descrição e "Words" | NÃO VAI |
| "How much do they already know?" | 3 | Regra de nível | CHEGA |
| "Why do they watch you?" | 6, até 2 | "They watch to …" | CHEGA |
| "How do you talk on camera?" | 8, até 2 | "They sound …" com palavras trocadas; na Ultra só no polimento | CHEGA |

### 3.3 My Cue Voice · personalidade
| Entrada | Opções | Onde é usada | Veredito |
|---|---|---|---|
| Energy · Sentences · Words · Humor | 3 cada | Linha "Delivery"; "Sentences" também muda a regra de frases e o tamanho | CHEGA |
| Swearing | Never / Mild only | Três IAs; plataforma profissional força "Never" | CHEGA |
| "What you film most" | 11, até 3, + próprio | "They film mostly: …", desempate do formato no Auto; o formato digitado cai em "Also true of them" | CHEGA |
| "How you like to open" | 7, até 2, + próprio | Firme no iPhone; opcional no PCC e na Ultra | FRACO |
| "How you usually end" | 6, até 2, + próprio | Contradito pela regra da plataforma; desfeito no PCC e na Ultra | FRACO |
| "My videos are for" | 7, até 2 | "Their videos aim to …" | CHEGA |
| "Phrases you actually say" | até 5 | Só 3 vão; opcional no PCC e na Ultra; duplicado nas tags | FRACO |
| "Cue never writes" | 8, até 3, + próprio | Regras + conferência e reescrita no Apple; Ultra sem conferência; formato sério não leva | CHEGA |
| "Where you post" | 6 | Só no polimento da Ultra; 2º corte; não muda a plataforma padrão nem o compartilhar | FRACO |
| "Usual length" | 4 | No Auto sai do pedido no Apple; Ultra usa como faixa; contradiz a duração pedida | METADE |
| "Use my voice in drafts" | interruptor | Liga a voz em roteiros e ideias; ganchos e "In my voice" ignoram | CHEGA |

### 3.4 Prova e aprendizado
| Entrada | Onde é usada | Veredito |
|---|---|---|
| "Add an example" (até 3) | Só quando o iPhone escreve, e nas ideias. Fica de fora se já houver 1 aprovado e 2 trechos importados (no máximo 3 exemplos por pedido). | METADE |
| "Import my writing" | Trechos: só no iPhone. Medidas: média de palavras por frase (só se "Sentences" não foi respondida) e um hábito de "!" ou "?" | METADE |
| "Sounds like me" | Guarda o roteiro como exemplo (só iPhone) e esconde a pergunta para sempre | METADE |
| "Your edits" (automático) | Igual: só iPhone | METADE |
| "Adjust" (5 motivos) | A reescrita usa. No perfil, "Too much slang", "Too formal" e "Too long" muitas vezes não mudam nada | METADE |
| "None of these" (dica) | Só decide quando perguntar de novo | NÃO É P/ IA |

### 3.5 Perfil e ajustes
| Entrada | Onde é usada | Veredito |
|---|---|---|
| Nome, @, foto | Perfil, avatar; @ nas sugestões da capa, "Follow @… made with Cue Studio", cartão do universo. Nunca vão para a IA. | NÃO VAI (IA) |
| Tipo de criador (Edit Profile) | O mesmo campo do My Cue Voice | CHEGA |
| "New scripts are made for" | Plataforma e registro de todo roteiro sem escolha | CHEGA |
| Monetization goals (em 3 folhas) | Meta de duração no teleprompter, na revisão e na barra de tamanho; Ultra. No Apple, quase nada no Auto. | METADE |
| Script language | Roteiro e ferramentas; ideias ignoram | CHEGA |
| App language | Idioma das ideias e padrão do roteiro | CHEGA |
| Apple Intelligence · Ultra AI | Interruptores | NÃO É P/ IA |
| Notificações, rotina, lembretes, tags automáticas | — | NÃO É P/ IA |

### 3.6 Criar um roteiro
| Entrada | Onde é usada | Veredito |
|---|---|---|
| A ideia (até 200 caracteres) | Três IAs, nas palavras do criador | CHEGA |
| Format (9 + 3) | Guia de formato nas três IAs (só nas ideias mandadas da barra) | CHEGA |
| Create for (6) | Regra da plataforma nas três IAs e nas ferramentas; ideias não | CHEGA |
| Brand brief (6 campos) | Só no anúncio; perdido em dois caminhos; ferramentas não veem | METADE |
| Answer a comment | Apple Intelligence (nunca Ultra, de propósito) | CHEGA |
| Logbook | Vira roteiro e inspira ideias | CHEGA |
| Duração | Sem seletor: só lida do texto ("2 minutes on…") e das ideias prontas | CHEGA |
| Import a script | Só texto | NÃO É P/ IA |

### 3.7 Ideias
| Entrada | Onde é usada | Veredito |
|---|---|---|
| Filtro de tópico | Limita os tópicos pedidos | CHEGA |
| Another idea · Start with it · Draft it now | Gosto aprendido (pesos), só nas ideias; não existe "não quero isso" | CHEGA |
| Ângulo e primeira frase da inspiração | Três IAs, só o que o texto ainda diz | CHEGA |

### 3.8 Ferramentas do roteiro
| Entrada | Onde é usada | Veredito |
|---|---|---|
| Improve (um toque por ferramenta) | Sem campo para o criador escrever o que quer | CHEGA |
| 3 new hooks | Usa a voz mesmo com o interruptor desligado | CHEGA |
| Tipo, plataforma e idioma depois de escrito | Mudam as ferramentas, não reescrevem | CHEGA |
| Fact check "I checked" | Só esconde o lembrete | NÃO É P/ IA |

### 3.9 Retorno para nós
| Entrada | Para onde vai |
|---|---|
| Sounds like me · Adjust | Só no iPhone; nenhuma contagem sai |
| "Don't suggest this" · dicas da primeira viagem | Contagem no Analytics, só com "Help improve Cue" ligado (vem desligado) |
| Dica da voz · convite e permissão da Ultra | Só no iPhone |
| Falhas da IA e do editor | Automático no Crashlytics (contagens, nunca texto) |
| Formulário, relato de problema, avaliação | Não existem |

---

## 4. O que não está chegando (achados)

**P1** afeta quase todo criador · **P2** chega pela metade · **P3** detalhe. Evidência: arquivo e linha (caminhos relativos a `Cue Studio/`).

### P1
1. **A "prova" quase nunca chega ao roteiro.** Exemplos colados, "Import my writing", "Sounds like me" e "Your edits" são tirados do pedido no PCC e na Ultra. É uma escolha de privacidade escrita no código ("Raw writing samples stay on the iPhone; PCC receives the creator's preferences and measured style"), mas contradiz a tela (20% do medidor, "Cue learns from it"). Do texto importado só passam a média de palavras por frase e um hábito de pontuação. `AIRequestPolicy.swift:8-21` · `AIModelRoute.swift:28` · `VoiceField.swift:21` · `VoiceFingerprintRules.swift:18-30`.
2. **O jeito de terminar escolhido não é respeitado.**
   - Quem escolheu "No call to action" recebe junto a regra do TikTok "end with one easy action (comment, follow or save)"; Reels e Stories são iguais.
   - "Follow for more", "Comment your answer", "Save this" e "Link in bio" são desfeitos: o PCC manda evitar despedida genérica de seguir, e a Ultra só põe chamada quando o pedido pede.
   - Evidência: `Context/PlatformGuide.swift:15-17` · `PCCScriptDirection.swift:68` · `Ultra/UltraInstructions.swift:26-27, 123`.
3. **Abertura e bordões ficam opcionais na rota principal.** No iPhone a regra é firme; no PCC e na Ultra vira "only when supported by this request" e "omission is better than forced repetition". `Voice/VoiceBriefBuilder.swift:277-305`.
4. **Texto apagado continua indo para a IA.**
   - Toda abertura, final ou bordão digitado é copiado para `customTags`. Apagar (`toggle`) tira só da lista.
   - A IA recebe o bordão duas vezes ("They often say: …" e "Also true of them, in their own words: …") e continua recebendo depois de apagado.
   - As mesmas tags aparecem como "formato digitado" no campo de formatos.
   - Evidência: `Managers/Preferences/CreatorProfileService+Personality.swift:27-36, 64-68` · `Screens/Profile/Voice/Editor/VoiceFormatsField.swift:60-68`.
5. **O briefing da marca se perde.**
   - Em "Start from a format → Sponsored ad", e quando o Apple Intelligence não pode escrever, o briefing digitado não é usado: abre um rascunho em branco, e o briefing só sobrevive se "Save brand" estava ligado.
   - O roteiro não guarda o briefing, então "Stronger CTA", "Shorter" e "In my voice" reescrevem sem "Never say", link e cupom.
   - Evidência: `Screens/Main/MainView.swift:202-214, 295-299` · `RewriteContext.swift:9-25` · `ScriptRequestFactory.swift:57`.

### P2
6. **Tópicos e subtópicos só vão quando a ideia repete a palavra.** É de propósito: em 07/10 a IA mudou de assunto por causa de um subtópico. Mas na prática os subtópicos quase nunca chegam ao roteiro. `Models/IdeaFocus.swift:6-28`.
7. **"Sounds like me" só pergunta uma vez na vida.** `ScriptDetailViewModel+VoicePreview.swift:12-25`.
8. **Duração habitual e metas de monetização quase não mudam o roteiro do Apple no Auto.** Com duração pedida no texto, o pedido diz ao mesmo tempo "Videos are usually under 30 seconds" e a duração pedida. `AIRequestPolicy.swift:27` · `ScriptPromptBuilder.swift:157-164` · `UltraLength.swift:23-31`.
9. **"Quem assiste" tem duas listas, e uma quase nunca vai.**
   - A dica tem 4 opções e grava o vocabulário; o editor tem 8 grupos.
   - "Too much slang" e "Too formal" mexem no vocabulário.
   - "Too long" não faz nada se "Sentences" não foi respondida.
   - Evidência: `Models/VoiceQuestion.swift:102` · `VoiceBriefBuilder.swift:225-228` · `Models/VoiceAdjustment.swift:45-58`.
10. **Respostas que não ligam a voz.** Quem respondeu só a personalidade, só colou exemplos ou só importou textos não manda nada. E o formato sério (Apology) não leva nem "Cue never writes", nem a credencial, nem o eu/nós. `CreatorProfile+VoiceSetup.swift:46-48` · `ScriptRequestFactory.swift:40-45`.
11. **Ganchos e "In my voice" ignoram o interruptor**, e "In my voice" não aplica a regra de plataforma profissional. `ScriptDetailViewModel.swift:192-199` · `ScriptAIService.swift:450` · `ScriptPromptBuilder.swift:488-490`.
12. **Ideias ignoram o idioma do roteiro e a plataforma.** `AppServices.swift:237` · `IdeaSuggestionService.swift:506`.
13. **A mesma pergunta em vários lugares:**
    - plataforma em 5 lugares e 3 campos (a padrão e "Where you post" não conversam);
    - tipo de criador em 4 lugares (na dica, o texto próprio vira tag);
    - monetização em 3 folhas;
    - tom sobreposto a energia, palavras e frases, com respostas contraditórias indo juntas.
14. **Nenhum retorno do criador chega ao dono.** "Help improve Cue" vem desligado. Não há formulário nem avaliação. Ideias não têm "não quero isso".

### P3
15. 5 bordões guardados, 3 enviados (`VoiceBriefBuilder.swift:296`).
16. **Palavras trocadas no pedido:** "Straight to the point" vai como "professional", "Playful" como "funny", "Conversational" como "casual"; plataformas vão com o nome traduzido num pedido em inglês (`VoiceSound.swift:18-40`, `VoiceBriefBuilder.swift:312`).
17. Formato digitado ("ASMR") vai para a linha genérica, a 3ª a ser cortada (`VoiceBriefBuilder.swift:291, 320`).
18. Medidas do texto importado pouco usadas (`WritingAnalyzer.swift:113-142`).
19. Ultra sem conferência depois de escrever; o ajuste de tempo não leva "Cue never writes" nem a regra de palavrão (`UltraFitRequest.swift:41-44`).
20. "What Cue sends" mostra mais do que vai (`VoiceSendsSheet.swift:19`).
21. **Restos no código:**
    - a linha "Tone:" do pedido nunca sai (`ScriptRequestFactory.swift:49`, `ScriptPromptBuilder.swift:154`);
    - estilos antigos;
    - cópia dos nichos em `CreatorVoice`;
    - campos do texto importado nunca lidos.

---

## 5. O mapa: manter, retirar ou deduzir, lacunas

### 5.1 Vale manter (melhora uma função de verdade)
| Informação | O que melhora | Ação |
|---|---|---|
| Tópicos e subtópicos | Ideias, universo, tags, biblioteca, notificações, roteiro | Manter |
| Plataforma | Regra da plataforma, registro, duração, teleprompter | Manter |
| Tipo de criador + credencial | Identidade no roteiro, sugestões nas outras perguntas | Manter (ver listas, §6.4) |
| Eu / Nós | Pessoa do roteiro | Manter |
| Público (grupo/descrição, nível, por que assistem) | Profundidade e promessa | Manter |
| "My videos are for" | Para onde o vídeo leva | Manter |
| Sentences, Words, Energy, Humor, Swearing | Como soa e tamanho | Manter (energia e frases também podem ser deduzidas, §5.2) |
| Abertura, final, bordões | Assinatura do criador | **Consertar** (P1) |
| "Cue never writes" | Regra dura conferida | Manter |
| Exemplos, Import, Sounds like me, Your edits | Voz real | **Consertar ou decidir** (D1) |
| Ideia, formato, Create for, marca, comentário, Logbook, inspiração | O roteiro em si | Manter; consertar a marca |
| Toques nas ideias, filtro | Gosto | Manter |
| @, nome, foto | Capa, compartilhar, perfil | Manter |
| Metas de monetização | Meta de duração | Manter num lugar só |
| Idioma do roteiro | Idioma | Manter; aplicar às ideias |

### 5.2 Pode sair ou virar dedução
| Informação | Por quê | No lugar |
|---|---|---|
| "Who's watching?" da dica + campo de vocabulário | Repete o editor com outra lista; quase nunca vai | Os mesmos 8 grupos; vocabulário derivado do grupo |
| Tons que repetem outros campos (Energetic, Conversational, Straight to the point) | Duplicam Energy/Words/Sentences e podem contradizer | Ficar com Educational, Confident, Warm & calm, Playful, Dry & sarcastic |
| "Where you post" | Fraco no roteiro; ninguém mais usa | Deduzir de onde compartilha; pré-escolher as redes no compartilhar |
| "Usual length" | Quase sem efeito no Apple | Deduzir das gravações; duração por roteiro (D10) |
| "What you film most" | O app já sabe o formato de cada roteiro | Deduzir do histórico; pergunta só para corrigir |
| Monetização em 3 folhas | Repetição | Um lugar só |
| "Sounds like me" uma vez + contador | Aprende pouco | Retorno a cada roteiro (lacuna 5) |
| Restos de código | Sem uso | Remover |

A pesquisa reforça (anexo C §2): coaches consideram energia e tamanho de frase deduzíveis das transcrições, e preferem perguntar "aberturas que você nunca usa" a "aberturas favoritas" (rodar aberturas é melhor).

### 5.3 Lacunas (falta e melhoraria muito)
| # | Lacuna | Por que | Prioridade |
|---|---|---|---|
| 1 | Gênero gramatical de quem fala e do "nós" | pt, es, fr, it, ar, hi, th mudam o texto em primeira pessoa; modelos usam masculino por padrão (estudo de 2026, anexo C §3) | Alta |
| 2 | Forma de tratamento do público | tu/você (pt-BR × pt-PT), tú/usted/vos, tu/vous, du/Sie, keigo, 해요체; modelos usam informal por padrão e escorregam de dialeto (ex. voseo) | Alta |
| 3 | Histórias e fatos verdadeiros | O PCC só abre com história quando ela vem no pedido; a IA não pode inventar números nem credenciais; coaches pedem "story bank" e "proof" | Alta |
| 4 | Oferta / negócio do criador | "My own business", "Sell something", "Win clients": nome, o que vende, para quem, link ou palavra-chave de DM, como agendar, cupom | Alta |
| 5 | Retorno a cada roteiro, aprendendo com o que foi dito | Botões de avaliação recebem resposta em 1 a 3% das vezes; edições e o que o criador realmente falou (Voice Following) valem mais (PRELUDE/CIPHER, NeurIPS 2024) | Alta |
| 6 | Ritmo de fala real | O tamanho usa 150 palavras por minuto com fator por idioma (`ReadTime.pace(for:)`), sem calibração por pessoa; as gravações já medem o criador (corrigido no §11.2) | Alta |
| 7 | Ponto de vista (2 a 3 opiniões) | Base de "hot take" e diferenciação; coaches citam como o que mais define uma voz | Média |
| 8 | País/região | Moeda, leis, dialeto, criador local, imóveis, finanças | Média |
| 9 | Regras do nicho (compliance) | Saúde, finanças, direito, UGC: licença, linha de aviso, alegações proibidas; "#publi" | Média |
| 10 | Transcrições dos próprios vídeos como exemplo | Amostra melhor que legenda escrita; o app já transcreve as gravações | Média |
| 11 | Como foram os vídeos | "Foi bem?" depois de postar, para as ideias aprenderem com o resultado | Média |
| 12 | Duração por roteiro | Seletor em vez de só ler do texto (concorrentes têm) | Média (D10) |
| 13 | Voz por plataforma | Metricool e Hootsuite têm instruções por rede | Baixa |
| 14 | Como se apresenta ("Oi, eu sou a Maya") | O nome existe, mas não vai | Baixa |
| 15 | Vocabulário próprio (nomes, termos) | Ajuda também o Voice Following e as legendas | Baixa |

---

## 6. Pesquisa externa (resumo; completa nos anexos C e D)

### 6.1 Nichos e mercado
- **Faltam tópicos grandes:**
  - Comédia e esquetes: 45% dos espectadores indianos assistem (BCG 2025); é categoria do YouTube; os comediantes têm os maiores públicos na Indonésia (Reuters). Hoje "Entertainer" não tem tópico para escolher.
  - Saúde mental e autodesenvolvimento: precisa de tópico próprio pelo risco nas alegações. O Guardian (maio/2025) achou desinformação em 52 dos 100 principais TikToks de #mentalhealthtips.
  - Ciência, história e curiosidades.
  - Cultura pop e fandom: K-pop, anime, o "oshikatsu" japonês.
  - Direito ("LawTok").
  - Natureza e ar livre: maior engajamento no Instagram (HypeAuditor 2025).
  - Artesanato e hobbies.
  - Sustentabilidade e causas.
  - Menores: astrologia; comida como crítica ou "comer fora" (o gênero nº 1 na Coreia).
- **Renomear ou fundir:**
  - "Budget travel" → "Travel": criadores de lifestyle e viagem nos países do Golfo cresceram 87% de 2023 a 2025.
  - "Daily routines" repete o tipo "Lifestyle" e o formato "Day in the life". Mas é um dos 10 do onboarding e do universo: D11.
  - "Books, film & TV" → incluir anime/fandom.
  - "Faith & spirituality" → incluir astrologia.
  - "Investing & crypto" vira subtópico regulado de finanças.
- **Tipos de criador:**
  - "My own business" deve se dividir em "Local business" (salão, clínica, restaurante) e "Founder / online business".
  - "Expert" e "Teacher" poderiam se fundir.
  - "News & commentary" (tipo) duplica "News & current events" (tópico).
  - "Content for brands" (UGC) precisa sobretudo do briefing e da linha de aviso de publicidade.
  - Falta "Artist / musician".
- **Sinais de mercado:**
  - Brasil: cerca de 2 milhões de influenciadores, +67% em um ano.
  - Índia: 4,1 milhões de criadores, 66% fora das grandes cidades.
  - Imóveis (EUA): 75% dos corretores usam redes sociais, e elas são a principal fonte de clientes (39%, NAR 2025).
  - LinkedIn: vídeos crescendo 34 a 36% ao ano.
  - China: desde cerca de out/2025, as plataformas exigem diploma ou licença comprovados de criadores de medicina, direito, finanças e educação.
- **Públicos a adicionar:** pessoas com mais de 50 anos, expatriados/diáspora, outros criadores. **Campo novo:** "o maior problema deles, nas palavras deles".
- **Metas a adicionar:** "Get brand deals" (a meta de dinheiro mais comum) e "Get bookings or visits" (negócio local).
- **Formatos a adicionar:** esquete, comparação (X vs Y), GRWM ("get ready with me"), estudo de caso, episódio de série. ("Hot take / reply" já existe em "More formats" e cobre a resposta a comentário: §11.2.)
- **Aberturas a adicionar:** opinião contrária, resultado primeiro, chamar o espectador ("Se você é enfermeira…").
- **Finais a adicionar:** "Comente a palavra X que eu te mando", "Mande para alguém que…", "Parte 2 / siga a série", "Agende ou visite". Coaches concordam: **uma chamada para ação por vídeo**.

### 6.2 Reclamações sobre roteiros de IA
- **Genérico e sem a voz da pessoa:** "ChatGPT writes blog posts, not video scripts"; a IA tende a um registro formal. Conteúdo que parece IA é visto como 48% menos confiável (Raptive 2025, 3.000 adultos nos EUA).
- **Mesmos ganchos em todo mundo:** "everyone is using the same AI-generated hooks".
- **Tamanho errado:** a IA conta as palavras, pede desculpas e escreve curto de novo.
- **Dialeto e formalidade errados:**
  - Espanhol argentino (voseo) quando a pessoa não é argentina; o Claude escorrega de volta para o voseo mesmo depois de corrigido.
  - pt-PT recebe pt-BR.
  - **Lição: exemplos dentro dos nossos prompts podem vazar o dialeto deles.**
- **Gênero:** os modelos usam masculino quando não sabem quem fala.
- **Risco de plataforma:** a regra de "conteúdo inautêntico" do YouTube (jul/2025) pode desmonetizar vídeos em massa com roteiros genéricos.

### 6.3 Concorrentes e retorno
- **O Cue pergunta mais que todos;** a falta está em conferir e atualizar o perfil:
  - **Testar antes de salvar:** o Writer roda textos de teste no cadastro; o Jasper mostra com e sem a voz.
  - **Mostrar e editar o que foi aprendido:** Grammarly, Writer, ChatGPT e Notion.
  - **Aprender com transcrições do canal:** Subscribr.
  - **Banco de fatos e ofertas:** Jasper Knowledge, Copy.ai Infobase, arquivos de conhecimento dos Gems do Gemini.
  - **Voz por rede:** Metricool, Hootsuite.
  - **Dados de desempenho:** Spotter Studio, vidIQ.
  - **Campo de duração:** Captions, CapCut e Subscribr têm.
- **Captions, CapCut, Canva, TubeBuddy e os apps de teleprompter** são mais fracos que o Cue em voz.
- **Retorno que funciona:**
  - Botões de avaliação recebem resposta em 1 a 3% das vezes e são enviesados; edições, regenerações e abandono carregam a maior parte do sinal.
  - **A maior oportunidade do Cue:** o Voice Following já sabe o que o criador falou de verdade em relação ao roteiro (palavras trocadas, frases puladas, improvisos na gravação mantida). Isso é retorno de graça, que pode virar uma lista "What Cue learned" que o criador vê e edita.
  - Quando o mesmo motivo do "Adjust" aparece duas vezes, propor como regra fixa (confirmar uma vez).
  - Evitar pares "qual você prefere" não pedidos: usuários do ChatGPT chamam de "teste A/B disfarçado".

### 6.4 Listas do Cue versus mercado
| Lista | Manter | Adicionar | Mudar |
|---|---|---|---|
| Tipos (8) | Lifestyle, Entertainer, Content for brands, Community | Artist/musician | Dividir "My own business" em local / online; fundir Expert + Teacher (D11); "News & commentary" → "Commentator" |
| Tópicos (25) | 20 deles | Comédia, saúde mental, ciência/história, cultura pop/fandom, direito, ar livre, artesanato, sustentabilidade | "Budget travel" → "Travel"; "Food" com críticas/comer fora; "Books, film, TV & anime"; "Faith, spirituality & astrology"; "Daily routines" (D11) |
| Público (8) | Todos | 50+, expatriados, outros criadores; "o maior problema deles" | — |
| Metas (7) | Todas | Get brand deals, Get bookings or visits | — |
| Formatos (11) | Todos | Esquete, comparação, GRWM, estudo de caso, episódio de série (hot take e resposta já existem) | — |
| Aberturas (7) | Todas | Opinião contrária, resultado primeiro, chamar o espectador | Perguntar também "nunca use" |
| Finais (6) | Todos | Palavra-chave por DM, mandar para alguém, parte 2 / série, agende ou visite | Uma chamada por vídeo |

---

## 7. Gênero gramatical e forma de tratamento: proposta

### 7.1 Onde pesa
| Peso | Idiomas | Exemplo |
|---|---|---|
| Perguntar sempre | es, pt, fr, it | estoy cansada / cansado · stanca / stanco · fatiguée / fatigué |
| Perguntar sempre | ar | adjetivos de quem fala |
| Perguntar sempre | hi | o verbo muda: करती / करता हूँ |
| Perguntar sempre | th | partícula ค่ะ / ครับ, pronome |
| Outra pergunta | ja | qual palavra usa para "eu" (watashi / boku / ore / atashi), não gênero |
| Só substantivos | de, nl | Ärztin / Arzt (a credencial já vem digitada) |
| Não perguntar | en, zh, ko, id, vi, tr, sv, da, nb | — |

### 7.2 Como está hoje
- Nenhuma pergunta, nenhuma regra no pedido: a IA escolhe sozinha, em geral no masculino.
- **Os textos fixos também erram.** A biblioteca de ideias em italiano tem "Ho iniziato a bere acqua tiepida appena sveglio" e "Dal momento in cui mi sveglio…". Ela também trata o público ora no masculino ("se sei stanco", "tu es perdu"), ora no feminino ("se você fica perdida").
- `LOCALIZATION.md` só pede para evitar primeira pessoa com gênero em hindi.

### 7.3 O que o iOS oferece (conferido no SDK do iOS 27)
- Ajustes › Geral › Idioma e Região › Forma de tratamento: Feminino / Masculino / Neutro, com "Compartilhar com todos os apps". Idiomas: es (2021), fr, it e pt-BR (2022), pt-PT e de (2023); árabe e hindi não aparecem.
- `NSMorphology.userMorphology` (Swift `Morphology.user`, iOS 15+) dá `grammaticalGender`. `isUnspecified` diz se a pessoa não escolheu ou não compartilhou com o app.
- `TermOfAddress.currentUser` (iOS 18+) é opaco: só serve para a concordância automática da interface (`^[…](inflect: true)`).
- **Ler o valor no aparelho precisa ser testado no iPhone.**

### 7.4 Como perguntar bem
- **Onde:** no cartão "I am" do My Cue Voice, logo abaixo de "Scripts say I / We" (é a mesma decisão: como o roteiro fala de quem fala). Também opcional no passo de configuração. Nunca obrigatório.
- **Quando aparece:** só se o idioma do roteiro ou da interface for da linha "perguntar sempre"; para o japonês, a pergunta do "eu".
- **Texto:** falar de gramática, nunca de "sexo" ou "identidade". Ex. pt: "Como os roteiros falam de você?", com uma frase de exemplo viva no idioma ("Hoje eu estou pronta / pronto…"). Opções: Feminino · Masculino · Neutro (reescreve sem marcar gênero quando dá) · Agora não.
- **Com "We":** o grupo, só quando importa: Só mulheres · Só homens · Misto. O misto usa o masculino plural por padrão, com a opção neutra.
- **Neutro = reescrever.** Os guias da Microsoft (pt-BR, fr) e a RAE indicam reformular e usar coletivos, e não construções como "ele(a)", "todes", "x" ou "@". "Iel"/"elu" só para pessoas que usam.
- **Padrão:** pré-preencher com o valor do iOS quando houver. Sem valor: neutro, nunca masculino por padrão. **Nunca deduzir pelo nome, pela voz ou pelo rosto.**
- **O que vai para a IA:** uma regra de gramática ("use feminine forms when the speaker refers to herself"), não "a criadora é mulher". Vai para iPhone, PCC e Ultra; a Ultra é o Google e entra no aviso dela (D6).
- **Conferência:** no iPhone, procurar as palavras mais comuns no gênero errado (como já se faz com eu/nós em en/pt/es).
- **Textos fixos:** biblioteca de ideias, ideias prontas, amostra do "Preview my voice" e roteiro de treino reescritos neutros nos idiomas com gênero (ou com uma variante por gênero).
- **Interface:** concordância automática do iOS (`inflect: true`) para "Bem-vindo/Bem-vinda" e afins.
- **Privacidade:** fica no iPhone; sai com "Delete my Cue data"; nunca vai ao Firebase; não entra no medidor. Base: minimização de dados (TJUE, caso *Mousse*, C-394/23, jan/2025: obrigar Monsieur/Madame foi considerado desnecessário). Na LGPD gênero não está na lista de dados sensíveis, mas há quem defenda que identidade de gênero está; não há posição da ANPD.

### 7.5 Forma de tratamento do público
- **Pergunta opcional:** "Como você fala com quem assiste?", com frases reais no idioma:
  - pt-BR você / pt-PT tu;
  - es tú / usted / vos (vosotros só na Espanha);
  - fr tu / vous;
  - de du / Sie;
  - ja polido / casual;
  - ko 해요체 / casual.
- **Padrão:** informal; formal pré-selecionado para finanças, direito, saúde e B2B. No alemão, o "du" domina no TikTok, mas só 17% dos clientes de seguros dizem gostar do "duzen".
- **Gênero do público:** quando o público é de um gênero só ("Mães"), tratar no feminino; senão, neutro.
- **Não perguntar** em en, sv, da, nb.
- **Precisa de revisão nativa:** várias afirmações de mercado aqui estão marcadas como não verificadas.

---

## 8. Plano por etapas

Ordem sugerida: 0 → 1 → 3 → 2 → 4 → 5 → 6 → 7. As etapas 1 e 3 não dependem das decisões de rota. Tamanho relativo: P (pequeno), M (médio), G (grande). Toda etapa segue o padrão do projeto:
- MVVM + Services;
- textos nos 20 idiomas;
- testes Swift Testing + XCUITest;
- zero warnings;
- contraste medido;
- `DESIGN_PROJECT.md` atualizado;
- telas novas só com o desenho aprovado pelo dono.

### Etapa 0 · Medir antes (M)
- **Personas novas** além das 14 de `VoicePersona(s).swift`:
  - criadora pt-BR de fitness;
  - criadora es de beleza;
  - criadora it de culinária;
  - criador fr;
  - dona de salão pt-BR (negócio local);
  - consultora financeira pt-BR;
  - uma dupla "we" mista em es.
- **Medir no iPhone** (`VoicePersonaDeviceTests`), no PCC e no aparelho:
  - erros de gênero em primeira pessoa;
  - final respeitado, abertura respeitada, bordão usado;
  - violações de "Cue never writes";
  - semelhança com os exemplos;
  - tamanho pedido × entregue;
  - forma de tratamento.
- **Novo avaliador determinístico** de concordância de gênero (listas de palavras por idioma).

### Etapa 1 · Consertos que não dependem de decisão (M)
1. **Tags livres:** o texto digitado fica só no seu campo (não é mais copiado para `customTags`). Uma migração remove das tags o que repete aberturas, finais e bordões, e mostra as tags restantes numa lista editável. (`CreatorProfileService+Personality.swift`, `VoiceFormatsField.swift`)
2. **Formato digitado** vai para "They film mostly".
3. **Bordões:** mandar os 5 dentro do limite (ou guardar só 3).
4. **Briefing da marca:**
   - guardado no roteiro e levado às ferramentas (`RewriteContext`);
   - "Start from a format → Sponsored ad" preenche as seções com o briefing.
5. **Ganchos e "In my voice"** respeitam o interruptor e a regra de plataforma profissional.
6. **Duração pedida** tira "Videos are usually…".
7. **A dica "Who's watching?"** usa os mesmos 8 grupos; o vocabulário vira derivado.
8. **"Adjust" grava nos campos que vão:** "Too long" → frases curtas; "Too formal" e "Too much slang" → Words.
9. **Palavras do pedido fiéis ao rótulo** (direct, playful, conversational); plataformas pelo nome em inglês.
10. **Ideias no idioma do roteiro** quando ele foi escolhido em Ajustes.
11. **Formato sério** leva "Cue never writes", credencial e eu/nós.
12. **Portão:** qualquer resposta liga a voz (personalidade, prova, importação).
13. **"What Cue sends"** mostra o pedido de verdade (tópicos filtrados, duração).
14. **Remover restos:**
    - a linha "Tone:" do pedido;
    - os estilos antigos (com migração);
    - a cópia dos nichos;
    - os campos não lidos do texto importado.
15. **Conferir se os exemplos dentro dos nossos prompts puxam dialeto** (voseo, pt-PT × pt-BR).

Medida: snapshots de `VoiceBriefBuilder` (`Fixtures/VoiceBriefs`), testes de unidade, personas da etapa 0.

### Etapa 2 · Rota e promessa, depois das decisões D1 a D5 (M)
- **D1 · Prova ao PCC.**
  - Se sim: `AIRequestPolicy` deixa de tirar exemplos, textos importados e aprovados (orçamento de 6.000 já existe), e o texto de privacidade diz o que vai.
  - Se não: o medidor e o aviso "Cue learns from it" mudam para dizer a verdade.
- **D2 · Final vence a plataforma.** A linha da plataforma perde a chamada quando há final escolhido; PCC e Ultra respeitam o final; uma chamada por vídeo.
- **D3 · Abertura e bordões firmes no PCC.**
- **D4 · Retorno a cada roteiro.** Proposta:
  - aprender do que foi gravado (Voice Following: o que foi dito × roteiro) e do "Adjust";
  - motivo repetido vira regra com uma confirmação;
  - uma lista "What Cue learned" que o criador edita;
  - a faixa "Sounds like me" volta, sem ser a cada roteiro.
- **D5 · Contagens no Analytics, sem texto:** aprovações, motivos do "Adjust", só com "Help improve Cue".

### Etapa 3 · Gênero gramatical e forma de tratamento (G)
- **Modelo:**
  - gênero de quem fala (feminino / masculino / neutro / não escolhido);
  - o grupo do "we" (mulheres / homens / misto);
  - o "eu" do japonês;
  - a forma de tratamento por idioma.
- **Padrão vindo do iOS** (`Morphology.user`, a testar no iPhone).
- **Tela:** no cartão "I am", conforme §7.4 e §7.5, só nos idiomas certos, com frase de exemplo viva.
- **Pedido:** regra de gramática nas três IAs e nas ferramentas (reescritas mantêm o gênero); conferência no iPhone com as palavras mais comuns.
- **Textos fixos:** reescrever neutros a biblioteca de ideias (20 pacotes; os afetados são es, pt, fr, it, ar, hi, th), as ideias prontas, a amostra do "Preview my voice" e o roteiro de treino. Regra nova no `LOCALIZATION.md`.
- **Interface:** `inflect: true` nas frases da interface que mudam com o gênero.
- **Privacidade e aviso da Ultra.**
- **Medida:** erros de gênero das personas, antes × depois.

### Etapa 4 · Fatos verdadeiros, oferta, ponto de vista, país, regras do nicho (G)
- **"My stories & proof":** até 5 fatos ou histórias verdadeiras (origem, um erro, um resultado de cliente, um número real).
  - A IA só usa números, credenciais e histórias que estão ali.
  - A regra do PCC "story opening requires an experience" passa a poder usar uma delas.
- **"My offer":** nome do negócio, o que vende, para quem, link ou palavra-chave de DM, como agendar, cupom fixo.
  - Aparece com "My own business", "Content for brands", ou metas "Sell something", "Win clients" e "Get bookings".
  - Reaproveita a estrutura das marcas salvas (`BrandStore`).
- **"What I believe":** 2 a 3 opiniões, para opinião polêmica e diferenciação.
- **País/região:** padrão da região do iPhone; aparece em finanças, imóveis, direito, saúde e negócio local.
- **Regras do nicho:** em saúde, finanças, direito e UGC, a licença, a linha de aviso do próprio criador e as alegações a evitar; um interruptor "este vídeo é patrocinado" que acrescenta a linha de aviso falada. Não é aconselhamento jurídico: o texto do aviso é do criador.
- **Medida:** números e credenciais inventados (zero), uso dos fatos, chamada certa.

### Etapa 5 · Deduzir em vez de perguntar (M/G)
- **Ritmo de fala por pessoa**, das gravações mantidas → tamanho do roteiro (hoje 150 palavras por minuto com fator por idioma, igual para todos).
- **Formatos** do histórico dos roteiros; "What you film most" vira resposta pré-preenchida e editável.
- **Onde posta**, do histórico de compartilhamento → pré-escolher as redes; a pergunta sai.
- **Duração habitual**, das gravações; seletor de duração por roteiro, se D10 aprovar.
- **Tom** reduzido aos 5 que só ele diz.
- **Importar transcrições das próprias gravações** como exemplos.
- **"Foi bem?"** depois de postar → gosto das ideias.

### Etapa 6 · Listas (M)
- Aplicar a tabela da §6.4 conforme a D11: subtópicos de cada tópico novo, pacotes da biblioteca de ideias para os tópicos novos (escritos uma vez, como os de hoje), 20 idiomas.
- D12: se os tópicos do My Cue Voice passam a virar mundos do universo.

### Etapa 7 · Medir depois e documentar (M)
- Personas de novo; 10 pares às cegas para o dono.
- `DESIGN_PROJECT.md` (§4, §13, §16, §23) e `LOCALIZATION.md`.
- Plano Full, `scripts/check-warnings.sh`, contraste medido das telas novas.

---

## 8A. Sugestões de UI/UX para os cartões de perguntas

**Como é hoje** (`DESIGN_PROJECT.md` §4):
- Página 9.3 com o cartão "✦ WHAT CUE USES" (chave + medidor + "Next: … Answer").
- Linhas de 52 pt em ESSENTIALS, PERSONALITY e PROOF, que abrem um editor só (`VoiceEditorSheet`).
- Configuração de 4 perguntas (2.1 a 2.4).
- Uma dica por dia acima do dock (17 perguntas; `VoiceQuestionSheet` com "+ Something else" e "None of these").

As sugestões abaixo mantêm o editor único e os componentes nativos (Picker segmentado, botões do sistema), conforme as regras do projeto. Qualquer tela nova passa antes pelo desenho e pela aprovação do dono.

1. **Mostrar o efeito na hora, em cada cartão.**
   - Uma linha de exemplo viva no idioma do roteiro muda conforme a escolha. Ex.: escolher "Question" em "How you like to open" mostra "Seus roteiros abrem assim: 'Você já reparou que…?'".
   - Gênero, forma de tratamento, Sentences e Words ganham o mesmo exemplo.
   - É o "testar antes de salvar" do Writer e do Jasper, sem precisar abrir o Preview.
2. **Dizer onde cada resposta é usada.** Uma linha pequena sob o cartão: "✦ Usado em roteiros e ideias", "Só nas ideias", "Usado no universo". Depois da etapa 1, isso precisa ser verdade em cada item; hoje "Where you post" diria "quase nada".
3. **O medidor conta o que chega.** O medidor da voz só deve contar o que de fato melhora os roteiros (depende de D1). Se a prova não vai ao PCC, ela não pode valer 20%.
4. **Um cartão "Como você soa" no lugar de dois.**
   - Hoje: 8 tons e quatro controles (Energy, Sentences, Words, Humor), com sobreposição e risco de contradição.
   - Proposta: os 5 tons que só o tom diz, mais os 4 controles como Pickers segmentados, e uma frase de exemplo que muda a cada toque.
5. **Chips com três estados nas aberturas e nos finais.** "Uso" (✓) e "Nunca uso" (✕), com um segundo toque ou toque longo. A pesquisa mostra que "o que nunca usar" vale mais que o favorito. Nos finais, um principal (uma chamada por vídeo).
6. **Confirmar em vez de perguntar.**
   - Formatos, onde posta e duração habitual chegam pré-preenchidos do uso, como sugestão a confirmar: "Detectado: Tutorial (6 roteiros) · Está certo?".
   - O gênero chega pré-preenchido do iOS, também a confirmar.
7. **"+ Something else" no lugar certo.** O texto digitado vira chip dentro do próprio cartão (abertura na abertura, papel no papel), nunca numa tag escondida. Um cartão "Também é verdade sobre mim" mostra as notas livres, editáveis, com apagar.
8. **Cartões que aparecem só quando servem:**
   - gênero gramatical e forma de tratamento, só nos idiomas que precisam;
   - "My offer", só para negócio, marcas ou meta de vender;
   - "Regras do seu nicho", só em saúde, finanças, direito e UGC;
   - "O eu do japonês", só em japonês.
   Isso mantém a página curta mesmo com campos novos.
9. **Histórias e fatos com perguntas guiadas e ditado.**
   - "Como você começou?", "Um erro que te ensinou", "Um resultado de cliente", "Um número verdadeiro do seu trabalho".
   - Criador fala melhor do que escreve: todo campo de texto livre ganha o microfone (o app já dita na barra de criação).
10. **Nova ordem da página**, por pergunta que o criador entende:
    - Quem você é (papel, credencial, eu/nós, gênero);
    - Com quem fala (público, nível, por que assistem, forma de tratamento);
    - Sobre o quê (tópicos);
    - Como soa;
    - Como abre e fecha;
    - O que é verdade sobre você (histórias, fatos, oferta, opiniões);
    - O que nunca dizer;
    - Exemplos e o que o Cue aprendeu.
    A divisão ESSENTIALS / PERSONALITY / PROOF fala a língua do sistema, não a do criador.
11. **Cartão "What Cue learned".** Lista do que foi aprendido com o "Adjust" e com as gravações ("Você troca 'galera' por 'pessoal'"; "Você corta frases longas"), cada linha com apagar. O criador vê e controla, como no Grammarly, no ChatGPT e no Notion.
12. **Retorno leve, por roteiro.** Depois de gravar, dois chips discretos, "Soa como eu" e "Ajustar", que somem sozinhos. Nada de nota de 1 a 5 nem de pares "qual você prefere" sem pedir.
13. **A dica diária pela ordem de impacto.**
    - Primeiro gênero e forma de tratamento (nos idiomas que precisam), depois histórias, oferta e público; os detalhes por último.
    - Perguntas de escolha única respondidas na própria dica, com um toque, sem abrir a folha.
14. **Texto do onboarding honesto.** "What do you usually talk about?" diz que serve para as ideias, mas também liga a voz nos roteiros: dizer "para suas ideias e roteiros".
15. **Acessibilidade.** Chips com estado em forma (✓/✕), não só em cor; contraste medido (o amarelo de "+ Add" sobre o cartão); Dynamic Type nas frases de exemplo; o VoiceOver lê o exemplo vivo depois da escolha.

---

## 9. Decisões do dono

| # | Decisão | Opções / recomendação |
|---|---|---|
| D1 | Mandar a prova (exemplos, textos importados, aprovados) ao PCC? | Recomendo sim: é a maior alavanca de voz, e o PCC é a nuvem privada da Apple. Se não, mudar o medidor e o aviso. |
| D2 | O final escolhido vence a regra da plataforma? | Recomendo sim, com uma chamada por vídeo |
| D3 | Abertura e bordões firmes no PCC, como no iPhone? | Recomendo firmes, mas rodando entre as escolhidas |
| D4 | Como aprender a cada roteiro | Recomendo aprender do que foi gravado + "Adjust", lista "What Cue learned" editável; sem nota a cada roteiro |
| D5 | Contagens (sem texto) de aprovações e motivos no Analytics | Recomendo sim, só com "Help improve Cue" |
| D6 | Gênero gramatical como em §7 (onde, opções, neutro como padrão, pré-preencher do iOS, mandar à Ultra) | Recomendo a proposta inteira |
| D7 | Forma de tratamento do público (pergunta opcional, padrão informal, formal para finanças/direito/saúde/B2B) | Recomendo sim |
| D8 | Quais campos novos entram: histórias/fatos, oferta, ponto de vista, país, regras do nicho | Recomendo histórias e oferta primeiro |
| D9 | Tirar ou deduzir: "Where you post", "Usual length", "What you film most", tons repetidos, a dica "Who's watching?" | Recomendo deduzir e tirar |
| D10 | Seletor de duração por roteiro | Decisão sua (hoje a duração vem do texto e do ritmo natural) |
| D11 | Listas: +8 tópicos, renomes, "Daily routines" (é do onboarding e do universo), dividir "My own business", fundir Expert + Teacher, novos públicos, metas, formatos, aberturas, finais | Recomendo os acréscimos; renomes e fusões ficam com você |
| D12 | Os tópicos do My Cue Voice viram mundos do universo? (06/10: não) | Decisão sua |
| D13 | Aprender com o que o criador falou de verdade (Voice Following) | Recomendo sim, no iPhone, com a lista editável |
| D14 | UI/UX dos cartões (§8A): exemplo vivo, onde é usado, cartão único de "como soa", chips ✓/✕, confirmar o deduzido, cartões condicionais, nova ordem da página | Recomendo fazer junto com as etapas 1 e 3, começando por um desenho para você aprovar |

---

## 10. Riscos e o que não foi verificado
- Auditoria por leitura de código; os efeitos na tela e no roteiro precisam ser medidos no iPhone (etapa 0).
- **O texto apagado que continua indo (P1-4) foi conferido no código.** Não foi visto na tela. Também não foi confirmado se alguma outra tela remove essas tags de outro jeito.
- A leitura do valor de `Morphology.user` no aparelho, a lista de idiomas da "Forma de tratamento" depois de 2023 e o comportamento com "Compartilhar com todos os apps" desligado precisam ser testados.
- **Pesquisa web:**
  - Reddit inacessível;
  - números de mercado em parte atrás de paywall;
  - alguns fatos de 2026 vêm de páginas da web e não foram conferidos à parte (Hank Green pausando canais em ago/2026, séries de Shorts do YouTube em set/2026, o guia do CONAR de 13/05/2026);
  - afirmações de formalidade por mercado precisam de revisão nativa.
- **Regras de compliance** (FTC, ESMA, CONAR, SEBI, CFM, ASCI) são resumos de fontes públicas, não parecer jurídico.
- **Mandar a prova ao PCC (D1)** muda a promessa de privacidade escrita no código: o texto para o criador precisa acompanhar.

---

## 11. Revisões 2 a 4: resposta às três análises do Codex e primeira medição no iPhone (01 e 02/11)

O Codex revisou este arquivo duas vezes no mesmo commit (`ed350580`), lendo o código e a documentação, sem rodar o app. Esta seção responde a cada argumento dele (concordo, discordo ou precisa de experimento), com a evidência, o que muda no plano e o critério de aceitação, e traz a primeira medição feita no iPhone. A **segunda análise** (02/11) foi favorável ao plano e pediu ajustes: os artefatos da medição, a frase sobre gênero, cada conserto ligado à decisão de que depende, critérios mais exigentes, um A11 mais estreito e o rastreio de todos os achados originais. As respostas estão em 11.4b, e as mudanças em 11.1, 11.4, 11.5 a 11.8, 11.9 e 11.10. **Onde divergir das seções 1 a 9, vale esta seção:** o plano revisado (11.5) substitui o §8 e as decisões revisadas (11.6) substituem o §9.

Uma ressalva que vale para o arquivo inteiro, e que o Codex fez bem em cobrar: "é enviado ao modelo", "é respeitado pelo modelo" e "melhora o roteiro" são três conclusões diferentes. A leitura de código mostra só a primeira. Os vereditos CHEGA, FRACO, METADE e NÃO VAI do §3 e do Anexo A dizem **se a informação chega ao pedido**, não se o roteiro fica melhor. O que diz algo sobre a segunda e a terceira conclusões está em 11.1, e é pouco: uma primeira rodada, não um estudo.

### 11.1 O que foi medido agora

Feito em 01 e 02/11 com o código de `main` (`ed350580`), sem mudar nada no app. **Todos os artefatos** (testes, roteiros, pedidos, registros, classificação à mão e critérios) **estão em `reports/entradas-do-criador-2026-11-01-medicao/`** (11.10). Três testes novos, ainda fora do repositório (não commitados), ficam como base para medir depois de cada conserto:

- `Cue StudioTests/Models/TypedPersonalityTagsTests.swift`, no simulador;
- `Cue StudioTests/Language/CreatorInputsDeviceTests.swift`, no iPhone, registrado em `scripts/test.sh device`. Variáveis: `TEST_RUNNER_CUE_INPUTS_ROUTES=app|device|cloud` e `TEST_RUNNER_CUE_INPUTS_CASES`;
- `Cue StudioTests/Language/CreatorInputsPromptCaptureTests.swift`, no simulador: grava o pedido de cada caso, por rota.

**Os casos.** Seis criadores com perfis mínimos, 3 ideias cada, no TikTok, sem formato e sem duração escolhidos:
- quatro criadoras escrevendo em primeira pessoa, sem nada no perfil que diga o gênero (o app não tem esse campo): pt (fitness), es (beleza), it (comida) e fr (viagem);
- um criador en com "No call to action", abertura "Question" e o bordão "Here's the thing";
- um criador pt com "Follow for more", "Question" e "Bora lá".

**Os aparelhos.** iago Lima (iPhone 15 Pro, iOS 27.2) e Mansuelli (iPhone 18 Pro Max, iOS 27.0.1, modelo do aparelho mais antigo). Foram **54 roteiros, todos no modelo do iPhone**:
- no iago Lima, o PCC não estava disponível;
- no Mansuelli, o PCC aparecia como disponível, mas toda chamada voltou `cloud.quotaLimitReached` ("Usage quota reached") e caiu para o aparelho.

**O PCC, que é a rota principal dos roteiros, ainda não foi medido.** A mesma rodada repete quando a cota voltar (`TEST_RUNNER_CUE_INPUTS_ROUTES=cloud`).

**Como foi lido.** Cada roteiro foi lido à mão. O script de triagem (`score_inputs.py`) só aponta onde olhar: deixou passar um dos masculinos do francês.

**O tamanho da amostra.** Cada caso tem 9 roteiros: 3 ideias, uma vez no Mansuelli e duas vezes no iago Lima (as rotas "app" e "device" acabaram no mesmo modelo). Isso mostra que o defeito existe, não a frequência exata.

**1. Tags digitadas** (simulador, `TypedPersonalityTagsTests`). Os 2 testes falham hoje, como o achado previa:
- um bordão digitado ("Hey fam") vai **duas vezes** ao pedido: "They often say: “Hey fam”" e "Also true of them, in their own words: Hey fam";
- uma abertura digitada e depois apagada ("Okay, real talk") sai de `openings`, mas fica em `customTags` e no pedido: "Also true of them, in their own words: Okay, real talk."

**2. Forma de tratamento do iOS** (`Morphology.user`). A leitura funciona no aparelho e devolveu `unspecified=true` nos dois iPhones:
- o do iago Lima está em en-US e pt-BR;
- o Mansuelli está em pt-BR;
- nenhum dos dois tem a opção escolhida.

Isso valida só a leitura no estado **não especificado**. Falta conferir com um valor escolhido (Ajustes › Geral › Idioma e Região › Forma de tratamento) e com o compartilhamento da forma de tratamento com os apps desligado.

**3. Roteiros** (54, modelo do iPhone, 9 por caso):

| Caso | O que o perfil pede | Resultado |
|---|---|---|
| Criadora fr | nada (o app não sabe o gênero) | **4 de 9 no masculino**: "Je suis parti trop tôt", "Je me suis réveillé tard", "Je suis passé à l'essentiel", "je suis arrivé". Nenhum no feminino |
| Criadora es | nada | 1 de 9 no masculino ("me sentí perdido"), 1 de 9 no feminino ("confianza en mí misma") |
| Criadora it | nada | 1 de 9 no masculino ("mi sono reso conto") |
| Criadora pt | nada | Nenhuma marca ("perdi", "comecei"). Mas apareceu um número de saúde inventado, **"Eu perdi 2 quilos em 7 dias"**, para uma ideia sem número nenhum. Apareceu também "ginásio", possível marca de pt-PT (no Brasil, a academia), num pedido em pt-BR. E 1 roteiro veio quebrado, com uma linha só |
| Criador pt sem gênero dito | — | "isso me deixa mais calmo": masculino por padrão |
| en, "No call to action" | nenhum CTA | **5 de 9 terminam pedindo ação**: "Comment below.", "Save this.", "Now save this…" |
| en, abertura "Question" | abrir com pergunta | 8 de 9 |
| en, bordão "Here's the thing" | uma vez | 9 de 9, nunca repetido |
| pt, "Follow for more" | pedir para seguir | 5 de 9 pedem para seguir, 1 com erro de português ("Seguam para mais dicas"). **8 de 9 pedem também para comentar ou salvar**, que é o que a linha do TikTok sugere (no nono, "Agora eu salvo esse momento" é o criador falando de si) |
| pt, abertura "Question" | abrir com pergunta | 6 de 9 |
| pt, bordão "Bora lá" | uma vez | 8 de 9 |

**Leitura:**
- **Gênero.** Nas 7 vezes em que uma frase marcou o gênero de quem fala, saíram **6 masculinos e 1 feminino**, em roteiros para quatro criadoras. Mas os pedidos **não diziam** que eram criadoras, porque o app não tem esse campo. Então isto não mostra desobediência a uma escolha. Mostra que **o app não permite informar a concordância desejada e que, quando o modelo precisa decidir sozinho, pode produzir uma forma incompatível com quem vai ler o roteiro** (aqui, predominantemente masculina). O erro se concentra no francês (passé composé com "être"), mas aparece também em es e it. Em pt as ideias quase não pediram concordância, então a ausência de erro lá não prova nada. A rodada com "Feminino" escolhido (critério de 11.7) precisa de ideias que forcem a concordância ("cansada", "sono arrivata", "je suis allée").
- **"No call to action"** é desobedecido em mais da metade dos roteiros no modelo do iPhone. O pedido gravado explica: três instruções pedem CTA (a linha da plataforma, o bloco "CTA" da estrutura e "CTA: one clear action") contra uma que pede o contrário (11.3).
- **"Follow for more"** aparece em pouco mais da metade e sempre divide espaço com a ação que a plataforma sugere.
- **Abertura e bordão** são bem seguidos no modelo do iPhone (6 a 9 de 9).
- **Tamanho.** Os roteiros do iago Lima saíram muito curtos: 22 a 50 palavras, de 9 a 20 segundos lidos. Os do Mansuelli saíram um pouco mais longos. Não era o foco, mas merece conferência à parte.
- **Número inventado.** "Perdi 2 quilos em 7 dias" fere a regra de honestidade do próprio prompt ("Never invent personal stories, clients, results, numbers…", que estava no pedido) e a decisão do dono ("nunca números inventados"), numa área (saúde e peso) em que a pesquisa (Anexo C) mostra risco legal.
- **Os outros números.** Entre as ocorrências classificadas, só uma foi marcada como resultado pessoal sem suporte ("perdi 2 quilos em 7 dias"). As demais são uma lista ("1. 2. 3."), um gancho retórico ("Ventisette piatti in un'ora: è possibile?"), um conselho ("a timer for twenty minutes") e detalhes de rotina numa cena em primeira pessoa ("três vezes por semana", "cinco minutos", "ho cotto tutto per venti minuti"). A lista não é exaustiva: a triagem pulava números iguais aos da ideia, e o último exemplo usa o número da ideia (vinte **pessoas**) com outra unidade (vinte **minutos**). Reutilizar um número com outra unidade não preserva um fato fornecido. A conclusão vale assim mesmo: detectar qualquer número sem fonte seria inadequado, e A11 trata só de resultados atribuídos (11.5).

### 11.2 Erros deste arquivo, corrigidos

1. **Ritmo de fala.** O §5.3 (lacuna 6) e a Etapa 5 dizem "150 palavras por minuto fixo". Errado: desde 01/11, `ReadTime.pace(for:)` aplica fatores por idioma (coreano 0,75, turco 0,8, indonésio 0,85, árabe 0,9, espanhol, hindi, norueguês, holandês e chinês 1,1, francês e vietnamita 1,15), medidos em leituras reais (FLEURS) e no tamanho das traduções. A lacuna real é menor: **não há calibração por pessoa**. As gravações do criador poderiam ajustar esse fator, como uma evolução dessa base.
2. **Chamada para ação (CTA) no PCC.** O resumo (§1, item 3) junta coisas diferentes. Precisando:
   - **Modelo do iPhone** (`PlatformGuide.swift`): a linha da plataforma pede uma ação no fim (TikTok "comment, follow or save", Reels "save or share", Stories "reply or vote", LinkedIn uma pergunta, YouTube "next video"), mesmo quando o criador escolheu "No call to action". Esse é o conflito do Anexo A.
   - **PCC** (`PCCScriptDirection.swift:44`): usa outro guia e diz "Platform conventions never require an engagement CTA". Não impõe CTA. Mas a linha 68 diz "use the creator's ending preference only when it fits this video; **avoid a generic follow, like or subscribe sign-off**". Para quem escolheu "Follow for more" ou "Subscribe", que são opções do próprio app, isso é uma instrução contrária à escolha. "No call to action" no perfil é tratado como preferência, não como pedido explícito: só vale "when it fits".
   - O efeito real disso está medido em 11.1.
3. **Bordões.** "Guarda 5, manda 3" está incompleto. O prompt leva sempre os 3 primeiros (`VoiceBriefBuilder.swift:296`, `prefix(3)`, sem rodízio). Mas, como todo bordão digitado também é copiado para `customTags`, o 4º e o 5º chegam em "Also true of them, in their own words", **por causa do bug**, e os 3 primeiros chegam duas vezes (medido, 11.1). Consequência: corrigir as tags sem mudar a seleção faria o 4º e o 5º sumirem. O conserto certo junta as duas coisas (A1 e A9 em 11.5).
4. **Formatos "novos".** "Hot take / reply" já existe em "More formats" (Anexo B, linha da sheet Format), e a resposta a comentário cabe nele. A lista de adições do §6.1 e do §6.4 não deveria incluir "resposta a comentário" nem "hot take" como novidade. O que sobra (esquete, comparação, GRWM, estudo de caso, episódio de série) vai para a trilha D (expansões que esperam sinal de uso).
5. **Privacidade (Anexo D, "Practical pattern").** A frase "declarar no rótulo só se sair do aparelho de forma identificável" está errada. Pelas definições da Apple ([App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)), três perguntas são separadas:
   - **coletado** = transmitido para fora do aparelho de um jeito que nós ou parceiros possam acessar por mais tempo do que o necessário para atender o pedido em tempo real;
   - **vinculado à identidade** = se fica ligado à pessoa;
   - **finalidade** = para que é usado.
   
   Identificável decide o vínculo, não a coleta. Na prática:
   - o gênero gramatical guardado só no iPhone não é coletado;
   - no PCC, a Apple processa sem guardar e nós não temos acesso: tende a não ser coleta nossa, a confirmar;
   - na Ultra (Gemini pelo Firebase), depende de o Google reter o pedido além do tempo real no plano usado; se retiver, é coleta e entra no rótulo, e o aviso da Ultra precisa citar essa informação;
   - as contagens no Analytics (D5) são coleta de dados de uso de qualquer jeito, mesmo sem texto.
   
   A análise final depende do processamento efetivo e é do dono, não deste arquivo.
6. **Aberturas e bordões "amolecidos" no PCC não são defeito.** É decisão registrada (`DESIGN_PROJECT.md` §4, "Preferências sem conflito no PCC": "Aberturas e fechos habituais são condicionais; […] bordões são opcionais"). O próprio documento diz que o ganho "ainda depende de comparação no aparelho". Endurecer isso sai dos consertos e vira experimento (E2).
7. **Exemplos fora do PCC também é decisão registrada** (`DESIGN_PROJECT.md` §4: "No PCC, a voz usa até 6000 unidades, sem exemplos colados, trechos importados ou roteiros aprovados"). O defeito comprovado é a **promessa**: o medidor dá 20% à prova, a tela diz que o Cue aprende com ela e o aviso "Cue learned from this" aparece, mas na rota principal nada disso vai ao modelo. Mandar os exemplos é uma hipótese (E1), não um conserto.

### 11.3 Achados novos desta revisão

- **As ferramentas de reescrita não levam as restrições.** Só "In my voice" recebe a voz (`ScriptAIService.swift:406`: `tool == .inMyVoice ? context.voice : nil`). Shorter, Longer, Translate, Stronger CTA, Simplify e as outras reescrevem sem "Never say", sem os itens de Avoid, sem eu/nós e sem o registro profissional. O ajuste de duração da Ultra (`UltraFitRequest.swift`) leva só a parte de "como fala" (`ultraProjection(...).delivery`), sem as regras.
- **O pedido do modelo do iPhone empurra três vezes para a CTA** (`prompts/` do pacote, 11.10): "end with one easy action (comment, follow or save)" (plataforma), "Blocks, in this order: Hook → Body → CTA" e "CTA: one clear action" (estrutura genérica), contra uma linha "End by leaving out any call to action". Explica os 5 de 9 de 11.1.
- **O pedido do PCC se contradiz para "Follow for more":** a linha 18 diz "Usual ending preference […]: inviting them to follow for more", e a linha 33 diz "avoid a generic follow, like or subscribe sign-off".
- **Nos roteiros medidos (11.1):** um resultado pessoal inventado ("Eu perdi 2 quilos em 7 dias"), uma possível palavra de Portugal num pedido em pt-BR ("ginásio"), um erro de conjugação ("Seguam") e um roteiro quebrado de uma linha. São casos isolados numa amostra pequena e entram nas métricas de proteção (11.8). Entre as ocorrências classificadas, só uma foi marcada como resultado pessoal sem suporte ("perdi 2 quilos em 7 dias").
- **O aprendizado pelas edições aprende a abertura mesmo quando a edição foi só no meio.** `DraftEdits.isTheirs` compara o roteiro inteiro (20% das palavras e no mínimo 8), e `learnFromRecordedScript` guarda a abertura da versão gravada. Se o criador mexeu só no corpo, a abertura guardada como "jeito de escrever dele" é a da IA. E esse exemplo aprendido também é tirado no PCC: o aviso "Cue learned from this" promete algo que a rota principal não usa.

### 11.4 Cada argumento do Codex

| # | Argumento | Veredito | Evidência | O que muda no plano | Critério de aceitação |
|---|---|---|---|---|---|
| 1 | Separar falhas, decisões, hipóteses e expansões | **Concordo** | O §8 misturava as quatro (p. ex. a Etapa 1 tinha escolhas de produto) | Plano refeito em quatro trilhas (11.5) | Cada item tem trilha, evidência e critério próprios |
| 2 | Tags digitadas ficam em `customTags`; a migração não pode guardar lixo nem apagar notas legítimas | **Concordo** | Medido no simulador (11.1). `addCustom` copia para `customTags` (`CreatorProfileService+Personality.swift:64-67`); `toggle` só tira do campo (l. 31-35) | A1: daqui em diante o valor digitado fica só no campo dele. Migração: tirar uma tag só quando ela é igual (mesma chave) a um valor que está hoje em aberturas, finais, bordões ou formatos. A que não bate com nada fica, e passa a aparecer numa lista visível "Também é verdade sobre mim", com apagar: quem decide é o criador, nada some em silêncio | Os 2 testes de 11.1 passam. Testes de migração: duplicata sai; tag órfã fica e aparece; nota de "Something else" fica. Cada bordão aparece uma vez no pedido |
| 3 | Briefing de marca perdido e ausente do `RewriteContext`; guardar no roteiro as condições daquela versão | **Concordo, e adoto a sugestão de guardar uma cópia** | `MainView.swift:202-214, 295-299`; `RewriteContext` não tem campo de briefing | A3: o roteiro guarda uma cópia do briefing usado (o que nunca dizer, link, cupom, frases obrigatórias), sem ligação viva com o Kit de marca salvo. As ferramentas recebem essa cópia | Anúncio criado por "Start from format" mantém o briefing depois de fechar o app; o pedido de Shorter, Translate, Stronger CTA e In my voice contém o "nunca dizer" e as frases obrigatórias; editar o Kit de marca não muda roteiros já criados |
| 4 | O portão da voz ignora respostas só de personalidade ou de prova | **Concordo, na formulação da segunda análise** | `CreatorProfile+VoiceSetup.swift:46-48`: só papel, tópicos, público ou tom ligam a voz | A5: **qualquer informação aplicável participa do pedido, respeitando o interruptor e a rota.** `voice != nil` não basta: no PCC, um perfil só com exemplos continua sem nada que chegue (os exemplos são tirados), e a tela precisa dizer isso (A6) | Por rota, o pedido contém cada campo que a política daquela rota aceita. Perfil só com finais: o final está no pedido nas duas rotas. Perfil só com exemplos: o exemplo está no pedido do aparelho, nada vai no do PCC, e a tela diz isso. Interruptor desligado: nada vai |
| 5 | Formato sério exclui o perfil inteiro, até restrições | **Concordo** | Formato sério não manda voz (Anexo A) | A4: o sério leva as restrições (Avoid, nunca dizer, eu/nós, gênero gramatical, forma de tratamento, variante regional) e deixa de fora estilo, bordões, aberturas, finais e humor | Teste do pedido sério; no iPhone, 3 declarações sérias com lista de Avoid: nenhum item violado, nenhum bordão |
| 6 | Restrições precisam sobreviver a encurtar, traduzir, ganchos, CTA, duração; separar estilo de restrição | **Concordo; vira a prioridade 1** | 11.3 | A2, depois de B9 (o que é restrição, preferência ou exigência do roteiro): dividir a voz em **restrições** (vão em toda geração e transformação: ferramentas, ganchos, ajuste de duração, tradução) e **estilo** (só na geração e em In my voice). Na tradução, as palavras de Avoid vão como estão, "e seus equivalentes no idioma de destino" | Teste de contrato por ferramenta: o pedido de cada uma contém as restrições. No iPhone, na bateria de 11.8: **zero violações** de proibição crítica (Avoid, nunca dizer, frases obrigatórias, eu/nós, concordância escolhida) depois de Shorter, Translate, Stronger CTA, ganchos e ajuste de duração. "Menor ou igual à geração" não serve: aprovaria uma geração que já viola. Zero em N casos não é garantia: a taxa real fica abaixo de cerca de 3/N |
| 7 | Hierarquia entre restrições, pedido, preferências e plataforma | **Concordo, com a nuance da segunda análise** | — | É preciso distinguir **revogação explícita** de **contradição acidental**. "Neste vídeo, peça para seguir" abre uma exceção ao "nunca" do perfil; "faça um anúncio convincente" não autoriza "prometer resultados". Também não se juntam coisas de natureza diferente: o briefing da marca é uma restrição daquele roteiro, que o próprio criador pode mudar; a declaração séria é um contexto que muda o registro; uma regra legal é externa e pede fundamento próprio (hoje o app não tem nenhuma). **A política é decisão do dono (B1, B11).** Minha recomendação, nesta ordem: (1) briefing do roteiro e regras externas; (2) revogação explícita no pedido; (3) restrições do perfil; (4) exigências implícitas do pedido; (5) hábitos do perfil; (6) convenções da plataforma. Quando uma revogação explícita passa por cima de um "nunca", um aviso | Matriz de conflitos em teste de unidade do pedido (cada fonte contra revogação explícita, contradição acidental e hábito); no iPhone, a bateria de 11.8 |
| 8 | Não endurecer preferências sem mostrar benefício | **Concordo** | 11.2, item 6 | D3 vira o experimento E2. O conflito "avoid a generic follow" contra "Follow for more" é outra coisa: contradiz a própria decisão ("condicional", não "proibido") e entra como conserto (A8) quando a medição no PCC confirmar o efeito; no modelo do iPhone, o conflito com a plataforma já está medido (11.1) | E2: a versão firme só entra se aumentar "abre como escolheu" sem piorar a preferência às cegas nem aumentar o bordão forçado |
| 9a | Guardar 5 bordões e mandar 3 pode ser certo; o problema é mandar sempre os mesmos | **Concordo** | 11.2, item 3 | A9, junto com A1, depois de B10 (rodízio ou relevância) | Com rodízio: em 6 roteiros seguidos, cada um dos 5 entra no pedido pelo menos uma vez (mede distribuição, não relevância). Com relevância: o dono julga às cegas, em 10 roteiros, se o bordão escolhido combina com a ideia. Nos dois casos: no máximo 3 por pedido e nenhum repetido |
| 9b | "Too long" não significa necessariamente frases curtas | **Concordo** | §4 item 8 propunha "Too long → frases curtas" | Sai dos consertos. No "Also my profile", um toque a mais pergunta o quê: "Frases longas · Vídeo longo · Ideias demais" (B3) | Cada resposta grava no campo certo, com teste |
| 9c | "In my voice" com a voz desligada pode ser uso explícito; avaliar os ganchos à parte | **Concordo** | §4 item 11 | "In my voice" fica como está (o criador pediu a voz naquela hora). Se os ganchos seguem o interruptor vira decisão pequena (B2) | — |
| 9d | Ideias no idioma do roteiro: há quem leia num idioma e grave em outro | **Concordo** | O idioma escolhido em Ajustes já manda no roteiro (`ScriptRequestFactory`), mesmo com a ideia em outro idioma | Sai dos consertos; vira opção só se aparecer confusão de verdade (B4) | — |
| 9e | Plataforma padrão, plataforma do roteiro e redes onde atua são coisas diferentes | **Concordo** | Anexo B | D9 muda: "Where you post" não sai; vira sugestão deduzida para confirmar | Nada é tirado sem conferir todos os usos (§3 e Anexo B) |
| 9f | Campo que não vai ao modelo pode servir para seleção, migração, diagnóstico ou interface | **Concordo** | — | Regra: só se tira um campo sem uso em prompt, seleção, migração, diagnóstico e interface, e sem decisão do dono que o mantenha | Lista de usos conferida por campo antes de tirar |
| 10 | Exemplos no PCC: hipótese de alto interesse, não conserto | **Concordo** | 11.2, item 7 | A6 conserta a promessa já. E1 testa três versões no PCC: (A) como hoje; (B) A + 1 ou 2 exemplos escolhidos pela relevância; (C) A + traços de estilo tirados dos exemplos, sem o texto | Medir semelhança de voz (às cegas + distância de estilo), cópia (trechos de 8 palavras iguais aos exemplos; fatos copiados), contaminação de assunto e de dialeto, latência e falhas. B ou C só entram se ganharem em voz sem piorar cópia e contaminação |
| 11 | Aprendizado automático exige cautela (PRELUDE usa usuário simulado; reconhecimento de fala erra; risco de reforçar a escrita da própria IA) | **Concordo** | PRELUDE/CIPHER: e-mails e resumos com usuário simulado por GPT-4 ([Microsoft Research](https://www.microsoft.com/en-us/research/publication/aligning-llm-agents-by-learning-latent-preference-from-user-edits/)); 11.3 | A7: só aprender a abertura quando a própria abertura mudou. A6: o aviso diz a verdade sobre a rota. "What Cue learned" com origem, data e desfazer (trilha C). Aprender pela fala (D13) sai das recomendações: antes, medir a confiabilidade da transcrição (as legendas erram 6,5% das palavras) e exigir recorrência (a mesma mudança em 3 ou mais takes) e confirmação | A7: edição só no corpo não gera exemplo; edição na abertura gera |
| 12 | Gênero e tratamento: aprovar a direção, refinar a especificação | **Concordo com todos os refinamentos** | 11.1 (Morphology no iPhone e erros de gênero) | Especificação revisada em 11.7 | 11.7 |
| 13 | Histórias e ofertas: origem, validade, autorização, exclusão; fatos não só do banco | **Concordo** | — | Cada item guarda origem (digitado, importado, aprendido), data, validade (ofertas e cupons vencem), autorização ("posso citar essa pessoa") e apagar. A regra muda de "só fatos do banco" para "todo fato tem fonte: o pedido, o briefing, o banco ou outra fonte autorizada" | Oferta vencida não vai ao pedido; item apagado some do pedido seguinte |
| 14 | Pesquisa externa não demonstra demanda dentro do Cue | **Concordo** | — | Listas novas esperam sinal de dentro do app; o mecanismo é B14. "Comédia" deixa de ser exceção: é decisão editorial (existe tópico próprio) e entra na D11 | — |
| 15 | Cuidados de UI: exemplo ilustrativo não é o comportamento, medidor não é qualidade, chip de três estados é difícil, controle que some precisa ser alcançável, mais cartões contra perguntar menos | **Concordo** | — | Exemplos marcados "exemplo" (o de verdade é o Preview que já existe). O medidor vira "Quanto o Cue sabe de você", nunca "qualidade". Sem chip de três estados: "Uso" e "Nunca uso" em duas listas visíveis (Avoid já é a segunda). Cartão condicional sempre alcançável em "Mais perguntas". **Esforço medido, não contado:** tempo para responder, toques, abandono da configuração da voz e quantas dicas interrompem por sessão; uma pergunta opcional nova entra se mostrar valor sem piorar essas medidas | Essas medidas antes e depois; VoiceOver e contraste medidos |
| 16 | O ritmo já tem fatores por idioma | **Concordo (erro meu)** | 11.2, item 1 | Lacuna vira "calibração por pessoa" (E4) | — |
| 17 | Experimentos com rota efetiva, fallback, idioma, repetições, qualidade, latência, falhas; 10 pares às cegas não validam tudo | **Concordo** | — | Protocolo em 11.8 | — |

### 11.4b Segunda análise do Codex (02/11)

O parecer foi favorável ao plano, com ajustes. Cada um, e o que mudou:

| # | Ponto | Veredito | O que mudou |
|---|---|---|---|
| 1 | Os testes, os roteiros e os registros não estavam no checkout dele | **Concordo** | Tudo em `reports/entradas-do-criador-2026-11-01-medicao/` (11.10): testes, triagem, os 54 roteiros com rota efetiva, aparelho e sistema, os pedidos de cada caso, o registro da rodada 2, o CSV com a classificação à mão e os critérios. Os testes continuam fora do repositório (não commitados) |
| 2 | "Toda vez […] masculino" contradiz o 6 a 1; o teste não informava que eram criadoras; `Morphology.user` só validado sem valor escolhido | **Concordo** | Frase corrigida em 11.1. A conclusão passa a ser: *o app não permite informar a concordância desejada; quando o modelo precisa decidir sozinho, pode produzir uma forma incompatível com quem vai ler o roteiro.* A integração com o iOS fica como "lida no estado não especificado"; falta testar com valor escolhido e com o compartilhamento desligado |
| 3 | A hierarquia: revogação explícita ≠ contradição acidental; briefing, regra legal e declaração séria não são equivalentes; a política é decisão de produto | **Concordo** | 11.4, #7 reescrito; a política fica com o dono (B1, B11), com a minha recomendação |
| 4 | Consertos executados antes das decisões de que dependem | **Concordo** | 11.5: cada conserto diz de qual decisão depende; os que não dependem de nenhuma podem começar já. A5 reescrito na formulação dele |
| 5 | Critérios: "≤ a geração" aprova sistema ruim; distribuição não é relevância; "7 de 9" sem a decisão; variação sem método; 3 repetições não bastam; controlar aparelho e versão | **Concordo** | Proibição crítica: zero violações na bateria, com o limite honesto da regra de três. Critérios de A8 e A9 dependem da decisão. Método de variação, tamanhos de amostra e controle de aparelho, sistema e rota em 11.8 |
| 6 | A11 amplo demais: nem todo número sem fonte é fato inventado; aviso não corrige a fabricação | **Concordo, e a amostra confirma** | Entre as ocorrências classificadas, só uma foi marcada como resultado pessoal sem suporte ("perdi 2 quilos em 7 dias"); as demais são lista, gancho, detalhe de cena e conselho (classificação não exaustiva: 11.1). Detectar qualquer número sem fonte seria inadequado. A11 passa a ser prevenção + detecção só de resultados atribuídos (11.5) |
| 7 | Achados originais sem destino; "Something else" sem mecanismo definido | **Concordo** | Tabela de rastreio de todos os achados (11.9). B14 separa contar o uso do campo de saber o que foi digitado |
| 8 | Duas regras rígidas: "Comédia" como defeito e o orçamento de perguntas | **Concordo** | "Comédia" vira decisão editorial (D11). O orçamento vira medida de esforço e interrupção (11.4, #15) |

### 11.4c Terceira análise do Codex (02/11)

O parecer foi favorável ao plano, sem pedido de nova revisão ampla, depois de conferir os testes, os 54 roteiros, a classificação, os pedidos e o registro. Ele pediu quatro ajustes:

| # | Ponto | Veredito | O que mudou |
|---|---|---|---|
| 1 | Qualidade editorial merece avaliação própria: um roteiro pode acertar bordão, pergunta e CTA e ainda ser pouco utilizável | **Concordo** | Q1 em 11.8 (três perguntas), como métrica de proteção de toda mudança de personalização e como base nos 54 roteiros |
| 2 | A classificação de números não é exaustiva ("ho cotto tutto per venti minuti": vinte pessoas viraram vinte minutos) | **Concordo** | Frase limitada em 11.1, 11.3 e 11.4b; o caso entrou na classificação (`classificacao.csv`) |
| 3 | A1 e A9 coordenados: tirar a duplicação pode fazer o 4º e o 5º bordão sumirem | **Concordo** | A1 declara o tratamento: até B10, os bordões guardados (até 5) vão na própria linha, cada um uma vez |
| 4 | Os testes novos são de investigação, não de aprovação; falhas no denominador | **Concordo** | Bateria de aprovação Q0 em 11.8, com quatro contagens separadas |

### 11.5 Plano revisado (substitui o §8)

**Trilha A · Falhas verificáveis**, cada uma com teste. A coluna "Depende de" diz o que precisa estar decidido antes; sem nada nela, pode começar já.

| Item | O quê | Depende de | Critério |
|---|---|---|---|
| A1 | Tags digitadas: o valor fica só no campo dele; migração cuidadosa (11.4, #2). **Bordões, até B10:** como hoje o 4º e o 5º só chegam pela duplicação, a entrega manda os bordões guardados (até 5) na própria linha dos bordões, sem perda nem repetição. B10 decide depois se ficam todos, se há rodízio ou se a escolha é pela relevância | — | 11.4, #2, e: depois da migração, cada bordão guardado aparece no pedido exatamente uma vez |
| A3 | Cópia do briefing de marca no roteiro, levada às ferramentas | — | 11.4, #3 |
| A5 | Qualquer informação aplicável participa do pedido, respeitando o interruptor e a rota | — | 11.4, #4 |
| A6 | Promessas verdadeiras por rota: medidor, "Cue learns from it", "Cue learned from this", What Cue sends mostrando o que vai na rota usada | — | Em cada rota, a tela só diz que é usado o que o pedido daquela rota contém (teste comparando o texto da tela com o pedido) |
| A7 | Aprender a abertura só quando ela foi editada | — | 11.4, #11 |
| A13 | Formato digitado ("ASMR"): conferir com teste se cai na linha genérica, a terceira a ser cortada (§4, P3-17). Se sim, levar para "They film mostly" | — | O teste mostra o formato na linha dos formatos, e a linha sobrevive ao corte de orçamento |
| A14 | Palavras do pedido fiéis ao rótulo: "Straight to the point" vai como "professional", "Playful" como "funny" (§4, P3-16) | — | Snapshot do pedido com cada tom, conferido contra o rótulo |
| A15 | Duração explícita tira o "Videos are usually…" do mesmo pedido (§4, P2-8) | — | Pedido com duração explícita não contém a duração habitual |
| A16 | Restos no código: a linha "Tone:" que nunca sai, os estilos antigos, a cópia dos nichos em `CreatorVoice` (§4, P3-21) | — | Build sem warnings e testes passando; migração dos estilos antigos testada com um perfil salvo. Os campos do texto importado que ninguém lê só saem depois de conferir todos os usos (11.4, #9f) |
| A11a | Investigar o "perdi 2 quilos em 7 dias": por que a regra de honestidade não segurou no modelo do iPhone; `needsFactCheck` marcou? | — | Relatório do caso, com o pedido (`prompts/`) e o que o conferidor fez |
| A2 | Restrições em toda geração e transformação; estilo separado (11.4, #6) | **B9** (o que é restrição, preferência ou exigência do roteiro) | 11.4, #6 |
| A4 | Formato sério leva as restrições | **B9** | 11.4, #5 |
| A8 | O final escolhido vence a convenção da plataforma. No modelo do iPhone, o pedido hoje empurra três vezes para a CTA (linha da plataforma, bloco "CTA" da estrutura, "CTA: one clear action") contra uma linha de "No call to action". No PCC, a linha 33 manda evitar o "follow" que a linha 18 oferece como preferência | **B1** (hierarquia) e **B11** (o que "No call to action" e "Follow for more" querem dizer) | Com "No call to action" como proibição: zero CTA na bateria. Com "Follow for more" como preferência: nenhuma segunda ação inventada pela plataforma, e o pedido para seguir medido, não exigido. Com "Follow for more" como exigência: pedir para seguir em todos |
| A9 | Seleção dos bordões, junto com A1 | **B10** (rodízio ou relevância) | 11.4, #9a |
| A10 | Gênero gramatical e forma de tratamento | **B8** (especificação de 11.7) | 11.7 |
| A11b | Prevenção e detecção de resultado atribuído ao criador | **B12** (que números uma cena imaginada pode ter) | Prevenção: a regra "nenhum resultado pessoal sem fonte" vira restrição persistente (A2), também nas reescritas. Detecção: só a categoria "resultado atribuído" (peso, dinheiro, porcentagem, ganho, cura), em frases de primeira pessoa, sem fonte no pedido, no briefing ou no banco de fatos. Bateria rotulada de 40 frases ou mais nos 4 idiomas, com os casos desta rodada: aponta os resultados e não aponta lista, gancho, conselho e (segundo B12) cena. Geração: zero resultado sem fonte em 30 ideias de fitness e finanças por rota |

**Ordem:**
1. Já: A1, A3, A5, A6, A7, A11a, A13, A14, A15 e A16, mais a bateria de aprovação (Q0) e a avaliação editorial de base (Q1).
2. Decisões B1, B8, B9, B10, B11 e B12. São as que destravam o resto da trilha A; as outras decisões B não bloqueiam nada.
3. A2 e A4 (depois de B9), A8 (depois de B1 e B11), A9 (depois de B10), A10 (depois de B8), A11b (depois de B12).
4. Experimentos E1 e E2, quando houver cota de PCC.
5. Trilha D.

**Trilha B · Decisões do dono.** As que destravam a trilha A vêm marcadas.
- **B1** (destrava A8): a hierarquia. Recomendação em 11.4, #7.
- B2: os ganchos seguem o interruptor?
- B3: o toque a mais do "Too long".
- B4: idioma das ideias como opção.
- B5: contagens no Analytics (D5).
- B6: seletor de duração (D10).
- B7: tópicos do My Cue Voice no universo (D12).
- **B8** (destrava A10): a especificação de 11.7.
- **B9** (destrava A2 e A4): a taxonomia. Recomendo:
  - **restrição:** Avoid, nunca dizer do perfil e do briefing, frases obrigatórias do briefing, eu/nós, concordância escolhida, variante regional, forma de tratamento escolhida, nenhum resultado pessoal sem fonte;
  - **exigência do roteiro:** o que o pedido daquele vídeo diz;
  - **preferência:** tom, energia, frases, palavras, humor, aberturas, finais, bordões, formatos, duração habitual.
- **B10** (destrava A9): bordões por rodízio ou por relevância à ideia.
- **B11** (destrava A8): "No call to action" é proibição ou hábito? "Follow for more" é exigência ou preferência? Recomendo separar na interface "costumo terminar assim" de "nunca faço isso" (este vai para Avoid).
- **B12** (destrava A11b): uma cena imaginada em primeira pessoa pode ter números de rotina ("três vezes por semana", "cinco minutos")? A decisão de 01/11 diz "nunca números inventados". Recomendo:
  - permitir número de rotina só quando a própria ideia é uma história em primeira pessoa;
  - proibir sempre resultado, estatística, preço e credencial.
- **B13:** a dica "Who's watching?" (4 opções, grava o vocabulário) contra o editor (8 grupos); recomendo uma lista só, a do editor (§4, P2-9).
- **B14:** como saber o que falta nas listas. Três mecanismos diferentes:
  - (a) contar quantas vezes "+ Something else" é usado em cada pergunta: só contagem, sem texto;
  - (b) no aparelho, ver se o texto digitado bate com uma opção existente e mandar só "bateu com X" ou "não bateu com nada": sem texto;
  - (c) mandar o texto: fere a regra atual de telemetria (nunca texto), só com consentimento explícito e numa tela própria.
  
  Recomendo (a) + (b), dentro de "Help improve Cue".

**Trilha C · Hipóteses, experimento antes:**
- E1: prova no PCC, com as três versões;
- E2: aberturas e bordões firmes no PCC;
- E3: aprender com edições explícitas (o cartão "What Cue learned");
- E4: ritmo por pessoa, a partir das gravações;
- E5: efeito de um banco de histórias e oferta.

**Trilha D · Expansões, esperam sinal de uso (B14):** listas e formatos novos, ponto de vista, país e regras do nicho, cartões novos e aprender pela fala.

### 11.6 Decisões revisadas (substitui o §9 onde diverge)

| Antes | Agora |
|---|---|
| D1 · Prova ao PCC | **E1** (experimento); a promessa é consertada já (A6) |
| D2 · Final vence a plataforma | **A8**, depois de **B1** e **B11** |
| D3 · Abertura e bordões firmes no PCC | **E2** |
| D4 · Aprender a cada roteiro | **A7** + **E3** |
| D5 · Contagens no Analytics | **B5** e **B14**, com a ressalva de privacidade de 11.2, item 5 |
| D6 · Gênero gramatical | **A10**, depois de **B8** |
| D7 · Forma de tratamento | Em 11.7: sem dedução pela profissão |
| D8 · Campos novos | Trilha D, com as regras de origem, validade e autorização (11.4, #13) |
| D9 · Tirar ou deduzir | Deduzir e confirmar; nada sai sem conferir todos os usos (11.4, #9e e #9f) |
| D10, D12 | Iguais (B6, B7) |
| D11 · Listas | Decisão editorial, inclusive "Comédia" (existe tópico próprio); o resto espera o sinal de B14 |
| D13 · Aprender pela fala | Trilha D, depois de medir a transcrição |
| D14 · UI/UX dos cartões | Com os cuidados de 11.4, #15 |
| — | **Novas:** B9 (taxonomia), B10 (bordões), B11 (sentido dos finais), B12 (números em cenas), B13 (lista de público), B14 (sinal das listas) |

### 11.7 Gênero gramatical e forma de tratamento: especificação revisada (substitui partes do §7)

- **Três eixos separados**, cada um com seu campo: (1) variante regional (já existe: pt-BR/pt-PT, es-ES/es-MX…); (2) concordância de quem fala; (3) tratamento do público.
- **Concordância de quem fala:** "Não escolhido", "Feminino", "Masculino" e "Prefiro sem gênero" (reescrever sem marcar gênero; nunca "todes" nem "elu" sem pedido).
  - "Não escolhido" não vira masculino. A regra pede para evitar marcar gênero quando não se sabe, o que é diferente de "Prefiro sem gênero" (escolha do criador).
- **Para "nós":** perguntar como o grupo aparece no texto ("nosotras / nosotros / sem marcar"), sem perguntar quem é o grupo.
- **O valor do iOS** (`Morphology.user`) é só sugestão: vem pré-marcado, com "do seu iPhone", e precisa de confirmação. O roteiro pode ser de outra pessoa ou de uma equipe.
- **Forma de tratamento:** pergunta opcional; padrão informal. O cartão pode **sugerir** o formal (finanças, direito, saúde, B2B), mas nunca deduz sozinho pela profissão.
- **Conferência:**
  - listas de palavras servem só de triagem; a palavra final é de leitura humana nativa ou às cegas;
  - os guias de localização da interface não viram regra para a voz do criador.
- **Integração com o iOS:** lida no iPhone só no estado não especificado (11.1). Falta testar com um valor escolhido e com o compartilhamento da forma de tratamento com os apps desligado.
- **Critério:**
  - **Bateria:** ideias que forcem a concordância nas quatro línguas ("cansada", "sono arrivata", "je suis allée", "me quedé sola").
  - **Com "Feminino" escolhido:** zero formas masculinas na primeira pessoa e concordância feminina onde o texto pede, nas duas rotas, conferido por leitura.
  - **Com "Não escolhido":** nenhuma marca de gênero na primeira pessoa em pelo menos 80% dos roteiros.
  - **Amostra:** o tamanho segue 11.8.

### 11.8 Protocolo dos experimentos e das baterias

- **Controle:**
  - antes e depois no mesmo aparelho, com a mesma versão do sistema (e, portanto, do modelo do aparelho) e a mesma rota efetiva;
  - rota efetiva conferida em cada roteiro (`GeneratedScript.model`); uma rodada em que o PCC caiu para o aparelho não conta como PCC;
  - o PCC só é comparado consigo mesmo, no mesmo dia, porque o modelo do servidor pode mudar sem aviso.
- **Registrar por roteiro:**
  - aparelho, sistema, rota pedida e efetiva, e se houve fallback;
  - idioma, caso, ideia, braço e repetição;
  - tempo, falha, número de palavras, o pedido enviado e a resposta (como em 11.10).
- **Exploração:** 3 repetições por caso, ideia e braço. Servem para achar defeitos, não para medir melhorias pequenas.
- **Confirmação:** cada métrica binária é uma proporção com intervalo de 95% (Wilson).
  - **Diferença real:** só quando os intervalos de antes e depois não se sobrepõem, ou quando um teste pareado pela mesma ideia (McNemar) dá p < 0,05.
  - **Tamanho:** é escolhido pelo efeito que se quer ver. Por exemplo, para ver uma queda de 50% para 10% de violação, com 80% de poder, são cerca de 20 roteiros por braço; quedas menores pedem bem mais.
- **Proibição crítica** (Avoid, nunca dizer, concordância escolhida, resultado sem fonte): o critério é zero violações na bateria. Com N roteiros sem violação, a taxa real fica abaixo de cerca de 3/N, com 95% de confiança (regra de três). Com 30 roteiros, isso dá menos de 10%; não é garantia.
- **Métricas automáticas** (triagem, não veredito):
  - concordância;
  - final, abertura e bordão;
  - violação de Avoid;
  - cópia (trechos de 8 palavras);
  - contaminação de assunto;
  - marcas de dialeto;
  - números por tipo (os do README do pacote);
  - tamanho contra a faixa.
- **Avaliação humana:** 10 pares às cegas pelo dono por experimento, nos idiomas que ele lê. Nos outros, a revisão por IA é só triagem. Dez pares avaliam o texto, não validam sozinhos a mudança inteira.
- **Regra de decisão:** fixada antes de rodar. Métrica-alvo, métricas de proteção e o tamanho de efeito que conta.
- **Bateria de aprovação** (Q0, diferente dos testes de investigação de 11.10, que só exigem um roteiro escrito). Quatro contagens separadas:
  1. execução concluída;
  2. quantas gerações deram certo;
  3. cumprimento das restrições;
  4. qualidade editorial (Q1).
  
  **As falhas ficam no denominador:** uma mudança não pode parecer melhor só porque deixou de responder nos casos difíceis. Um roteiro que não saiu conta como não cumprido.
- **Qualidade editorial** (Q1), com três perguntas por roteiro, lido à mão:
  - preserva o assunto e a intenção da ideia?
  - desenvolve algo concreto, sem só repetir a promessa?
  - soa natural lido em voz alta?
  
  Uma mudança de personalização só conta como sucesso se essas três não piorarem. Exemplos da amostra local que falhariam: "Eu deixava meu sono se tornar um hábito" e "Eu movia meu corpo sem energia" (não naturais); "Ho scoperto che mangiare fuori cambia tutto" para "smettere di comprare cibo pronto" (muda o assunto). Vale para o modelo do iPhone; não se transfere ao PCC.

### 11.9 Rastreio: cada achado original e o destino dele

| Achado (§4 e Etapa 1 do §8) | Destino | Onde |
|---|---|---|
| P1-1 Prova não chega ao PCC e à Ultra | Experimentar; consertar a promessa já | E1, A6 |
| P1-2 Final escolhido contrariado | Corrigir depois de decidir | A8 (B1, B11) |
| P1-3 Abertura e bordões opcionais no PCC | Experimentar (decisão registrada) | E2 |
| P1-4 Texto apagado continua indo; bordão duas vezes | Corrigir já | A1 (+ A9 depois de B10) |
| P1-5 Briefing da marca perdido | Corrigir já | A3 |
| P2-6 Subtópicos só com a palavra na ideia | Adiar: decisão registrada em 07/10 (a IA mudava de assunto); reabrir só com medição | — |
| P2-7 "Sounds like me" uma vez na vida | Experimentar, junto do retorno leve | E3 |
| P2-8 Duração habitual contra duração explícita | Corrigir já | A15 |
| P2-8 Metas de monetização quase sem efeito | Adiar: entra com "My offer" | Trilha D |
| P2-9 Duas listas de público; dica que grava campo quase ignorado | Decidir | B13 |
| P2-9 "Too long", "Too formal", "Too much slang" no perfil | Decidir | B3 |
| P2-10 Portão ignora personalidade e prova | Corrigir já | A5 |
| P2-10 Formato sério sem restrições | Corrigir depois de decidir | A4 (B9) |
| P2-11 Ganchos e "In my voice" com o interruptor | Decidir (ganchos); "In my voice" fica | B2 |
| P2-11 "In my voice" sem a regra de plataforma profissional | Corrigir com as restrições | A2 (o registro profissional entra como restrição em B9) |
| P2-12 Ideias no idioma do roteiro e na plataforma | Decidir | B4 |
| P2-13 Mesma pergunta em vários lugares | Adiar: conferir todos os usos antes de mexer | D9, 11.4 #9e/#9f |
| P2-14 Nenhum retorno chega ao dono | Decidir | B5, B14 |
| P3-15 5 bordões, 3 enviados | Corrigir depois de decidir | A9 (B10) |
| P3-16 Rótulos de tom diferentes do pedido | Corrigir já | A14 |
| P3-17 Formato digitado na linha genérica | Conferir e corrigir | A13 |
| P3-18 Medidas do texto importado pouco usadas | Experimentar, com a prova | E1 (versão C) |
| P3-19 Ultra sem conferência; ajuste sem "Cue never writes" | Corrigir com as restrições (a Ultra é só Debug hoje) | A2 |
| P3-20 "What Cue sends" mostra mais do que vai | Corrigir já | A6 |
| P3-21 Restos no código (linha "Tone:", estilos antigos, cópia dos nichos, campos não lidos) | Corrigir já, com migração onde houver dado salvo; não é mudança de comportamento | A16 (limpeza; os campos não lidos só saem depois de conferir os usos, 11.4 #9f) |
| Etapa 1 · 15 Exemplos dos nossos prompts puxando dialeto | Experimentar: entra como métrica (a amostra teve um "ginásio" em pt-BR) | 11.8 |
| Novo · Reescritas sem restrições | Corrigir depois de decidir | A2 (B9) |
| Novo · Abertura aprendida sem edição na abertura | Corrigir já | A7 |
| Novo · Resultado pessoal inventado | Investigar já; prevenir e detectar depois de decidir | A11a, A11b (B12) |
| Novo · Estrutura "Hook → Body → CTA" fixa no modelo do iPhone | Corrigir com o final | A8 |
| Novo · Roteiros fracos: curtos (22 a 50 palavras), um quebrado, frases pouco naturais, assunto trocado | Medir como proteção de toda mudança | Q1 (11.8) |

### 11.10 Artefatos da medição

Tudo em `reports/entradas-do-criador-2026-11-01-medicao/`, com um `README.md` que diz o que é cada arquivo, os critérios de classificação e como repetir:
- **Testes:** os três (`tests/`) e a mudança no `scripts/test.sh`.
- **Rodada 1, iago Lima:** os 36 roteiros, em JSON, com a rota efetiva.
- **Rodada 2, Mansuelli:** os 18 roteiros e o trecho do registro com as falhas `cloud.quotaLimitReached`.
- **Pedidos:** as instruções e o prompt de cada caso, por rota (`prompts/`).
- **Classificação:** à mão, uma linha por roteiro, com a citação que a justifica (`classificacao.csv`).
- **Ferramentas:** a triagem automática e o script que gera o CSV (`tools/`).

**Limites:**
- o registro de console da rodada 1 foi sobrescrito, então não se sabe por que o PCC não foi usado nela;
- uma segunda tentativa de `VoiceCheckedWriting` não fica gravada;
- os pedidos de `prompts/` são os montados antes do ajuste à janela do aparelho, que não corta perfis tão pequenos.

Os arquivos estão no checkout principal, sem commit. Para outro checkout ver, é preciso commitar ou mandar a pasta (vai junto, compactada).

### 11.11 Implementação dos consertos sem decisão (02/11)

Na branch `fix/creator-inputs` (worktree `.claude/worktrees/creator-inputs`, a partir de `main` `ed350580`), sem commit. Cada linha diz o que mudou,
como foi conferido e em que rota vale.

| Item | O que mudou | Conferido por | Rotas |
|---|---|---|---|
| A1 | Abertura, fecho e bordão digitados ficam só no próprio campo: não são mais copiados para `customTags`, vão uma vez ao modelo e saem quando o criador os tira. Ao abrir, um perfil salvo antes perde as cópias que batem com um valor guardado; o que não bate com nada fica, porque pode ser uma nota. Os bordões guardados (até 5) vão todos na linha dos bordões, uma vez cada, com "Use one…" (até B10) | `TypedPersonalityTagsTests` (4), `VoiceTypedValuesTests`, `VoiceValidationTests` | aparelho, PCC, Ultra |
| A3 | O roteiro guarda uma cópia do briefing da marca (`Script.brand`), também no rascunho aberto à mão e no Start from a format. Improve, ganchos, a versão para outra plataforma, a tradução e o ajuste de tamanho da Ultra recebem o #ad, o que a marca pediu e proibiu, o link e o cupom; link e cupom ficam como estão, até na tradução. Um roteiro que deixou de ser anúncio é reescrito sem o briefing | `AdBriefKeptTests` (9) | ferramentas no aparelho e no PCC; ajuste da Ultra |
| A5 | A voz vale com qualquer resposta que o briefing conte (abertura, fecho, bordão, formato, regra, estilo, alcance, nota, exemplo, texto importado, roteiro aprovado), não só com os Essentials | `VoiceGateTests` (4): só um fecho vai nas duas rotas; só exemplos vão no aparelho e nada vai no PCC; interruptor desligado, nada vai | aparelho, PCC |
| A6 | Textos verdadeiros por rota: "Saved · Cue uses it on this iPhone" (Sounds like me na página), "Saved · counts toward your voice" (na prévia, onde a amostra não é guardada), "Saved as your writing · used on this iPhone" (aprendizado), a dica do primeiro rascunho, e uma nota em PROOF: exemplos, texto importado e roteiros aprovados guiam o que o Cue escreve neste iPhone e nunca vão ao PCC nem à Ultra. What Cue sends mostra a voz como o pedido a lê (sem duração habitual), diz quando o interruptor está desligado e que os temas só vão quando a ideia é sobre eles. 7 textos novos nos 20 idiomas, 3 removidos | `DraftLearningTests`, `VoiceV29UITests` | telas |
| A7 | O começo só é guardado como "jeito de escrever" quando o próprio começo mudou pela mesma medida (20% e 8 palavras); editado só depois dele, o rascunho espera | `DraftLearningTests` (2 novos) | aparelho |
| A11a | Caso "Eu perdi 2 quilos em 7 dias": a regra contra resultados inventados estava no pedido (linha 11 do prompt); o assunto não é factual (`FactualTopic`), então no aparelho só a própria marcação do modelo (`statesFacts`) pediria a conferência, e a rodada não gravou essa marcação. O teste de aparelho passa a gravar `needsFactCheck` | `InventedResultCaseTests` (2) | aparelho |
| A13 | Formato digitado ("ASMR") fica em `customFormats` e vai em "They film mostly", que o orçamento não corta; conta no limite de 3 e sai com um toque no editor | `TypedFormatTests` (5) | aparelho, PCC, Ultra |
| A14 | Tons com as palavras do rótulo ("conversational", "straight to the point", "playful") e plataformas pelo nome em inglês | `ScriptPromptBuilderTests`, retratos `VoiceBriefSnapshotTests` (11 regravados, diferenças conferidas uma a uma) | aparelho, PCC, Ultra |
| A15 | A duração habitual nunca vai no texto do pedido de roteiro nem das ferramentas (no Automático ela só ajusta a faixa) | `ScriptDurationPolicyTests` | aparelho, PCC (a Ultra já fazia) |
| A16 | Saíram o campo `tone` do pedido e a linha "Tone:", `Tone.promptWord`, `VoiceSound.tone` e a cópia dos nichos em `CreatorVoice` | build e testes | — |
| Q0 | `tools/creator_inputs/q0.py`: quatro contagens por rodada e rota, todas sobre o que foi pedido, com intervalo de Wilson; restrições num arquivo de especificação que as decisões B1, B8, B9 e B11 vão preencher (hoje: o "never" do perfil e a regra do bordão). Preferências aparecem à parte, como frequência | rodado na medição de 01/11 | — |
| Q1 | Base editorial dos 54 roteiros, lida por um agente sem ver a classificação anterior (`q1-baseline.csv` no pacote) | — | aparelho |

**Base do Q0 (54 roteiros de 01/11, todos escritos no aparelho, mesmo o pedido "cloud"):** execução 54/54, roteiro escrito 54/54, restrições
13/18 (o "No call to action" ignorado em 5 de 9), qualidade editorial 12/54 (22%; IC95 13–35%).

**Base do Q1:** assunto 42/54, concreto 37/54, natural 19/54; nos três, 12/54. Por idioma, nos três: en 4/9, es 5/9, pt 3/18, it 0/9, fr 0/9.
"Natural" é o ponto fraco (pt 4/18, it 1/9, fr 1/9). **Ressalva:** o leitor contou como não natural o masculino nos casos "woman" (6 roteiros), mas o
app não informa o gênero (B8); sem esse critério, só um deles muda (fr device-1 passa em natural). E contou o decalque "Salva/Sauve este momento"
como não natural; sem isso, es cloud-0 e it cloud-0 passam nos três. Exemplos que falham: "Ho scoperto che mangiare fuori cambia tutto" (muda o
assunto), "Eu perdi 2 quilos em 7 dias… reforcei minhas escolhas" (o contrário da ideia, com número inventado), "Eu deixava meu sono se tornar um
hábito", "Eu não preciso ir ao ginásio" com um "”," solto.

**O que mudou de comportamento além do previsto:**
- os pedidos ficaram um pouco maiores (nomes de plataforma e rótulos de tom completos). O criador mais completo da suíte cabe no pedido de roteiro
  (cerca de 2.089 de 2.100, porque a duração habitual saiu); nas ideias, que ainda levam a duração habitual, esse perfil extremo passa do
  orçamento por 26 e perde um pedaço dos exemplos;
- um bordão a mais pode aparecer (até 5 em vez de 3), sempre com "Use one".

**O que ficou para depois, e por quê:**
- **estilos antigos** (`styles`): ainda vão no pedido de perfis antigos ("Style: storytelling, opinionated"), e tirá-los muda o que esses perfis
  mandam; a migração vai junto com a taxonomia (B9). `ScriptStructure.tones` e `Tone.label` também não têm uso, mas saem numa varredura com
  Periphery, não aqui;
- **pesos do medidor** (Proof 20%): a nota em PROOF diz onde a prova vale; mudar os pesos muda os cartões e lembretes, e é decisão sua;
- **o texto do passo "4 · Fit to time"** em What Cue sends (Ultra) não cita o briefing da marca, que agora vai junto num anúncio;
- **medição no iPhone depois dos consertos:** não rodei. Os casos medidos quase não passam pelo que mudou (só as palavras de tom mudariam), então a
  rodada mostraria pouco; ela vale depois das decisões, como bateria Q0 completa, e com o PCC quando houver cota.

**Testes:** plano Full em 02/11: unidade com 4.933 aprovados e 2 falhas, UI com 400 de 400 (114 pulados, como sempre).
- `NearbyLinkTests`: é o ambiente; a rede local fica bloqueada no sandbox desta sessão.
- `ScriptRequestFactoryTests`: esperava o comportamento antigo do A5 (um perfil com só um bordão não usava a voz). O teste foi ajustado para a regra
  nova (um perfil intocado continua sem voz; só um bordão já a liga) e passou com 13 de 13.

`scripts/check-warnings.sh`: nenhum warning no simulador, no aparelho e em Release. Contraste: os três textos novos ficam sobre fundos opacos com pares
já medidos em `PaletteContrastTests` (`ink2` sobre `surface` na página; `ink2` e `warnText` sobre `sheetNight` no What Cue sends), todos acima de 4,5:1.

**Commits:** dois na branch `fix/creator-inputs`: os consertos com seus testes, e este relatório com o pacote de medição. Branch enviada ao GitHub, sem PR.

### 11.12 Implementação das decisões do dono (02/11)

As decisões B8 a B14 aprovadas pelo dono, cada uma com os testes dela. B2 a B7 continuam abertas (a comparação das telas, com hoje e a proposta lado a
lado, está no canvas "My Cue Voice: decisões de UI").

| Item | O que ficou | Onde |
|---|---|---|
| A8 · fecho | "Calls to action" no Avoid; fechos que não pedem nada tiram o CTA do formato; fechos que pedem uma ação levam só essa; o pedido do vídeo vence quando pede em tantas palavras, dito uma vez fora do brief (o brief continua em 2.100 caracteres); toast quando o pedido passou por cima do Avoid | `CreatorVoice+Ending`, `FormatGuide`, `VoiceConstraintChecker.lifted(by:)`, `ScriptStarter` |
| A2/A4 · B9 | As regras (Avoid, I/We, palavrão "never", concordância) valem no Improve, Shorter, Longer, Translate, Fit da Ultra AI e no roteiro sério; o estilo não | `CreatorVoice+Restrictions`, `ScriptPromptBuilder.rewriteInstructions` |
| A9 · B10 | Bordões: 3 por roteiro, em rodízio; o What Cue sends mostra os da próxima vez | `CatchphraseRotation`, `CreatorProfileService.catchphraseTurn` |
| A11b · B12 | Resultado na boca do criador que ninguém deu (quilos, dinheiro, %, seguidores) é uma violação de gravidade 3; números de rotina ficam; sobrando, o roteiro pede conferência | `AttributedResultDetector` (48 frases rotuladas em 5 idiomas) |
| A10 · B8 | "Write me as" / "Write us as" (opcional, com o termo do iOS como atalho) e "Speak to viewers" no I am; regra na língua do roteiro (pt, es, fr, it, hi, ar), "never assume the masculine" sem escolha, tratamento informal por padrão; conferência depois do roteiro em pt/es/fr/it | `VoiceAgreement`, `AgreementGuide`, `GenderAgreementChecker`, `VoiceAgreementField` |
| B13 | A dica "Who's watching?" usa os 8 grupos do editor | `VoiceQuestion.audience` |
| B14 | Resposta digitada: só a pergunta e se bateu com uma opção, com "Help improve Cue" ligado, nunca o texto | `VoiceTypedAnswerEvent` |

**Medido no Mansuelli iPhone 18 Pro Max** (rodada 4, `entradas-do-criador-2026-11-01-medicao/run4-mansuelli-18pm-a8/`, 18 roteiros, todos do
modelo do aparelho porque o PCC negou por limite do iPhone):

- "No call to action" como hábito: 6 de 6 sem pedir nada (antes, 5 de 9 com CTA). Dois leram a instrução em voz alta; o texto do Close mudou depois.
- "Follow for more": 6 de 6 pedem só para seguir (antes, outra ação em 8 de 9).
- Resultado inventado: 0 de 6 no caso fitness; só números de rotina.

**Não medido:** o PCC (limite do aparelho nos dois iPhones hoje) e o A10 no aparelho (concordância em pt/es com o modelo real); os dois ficam para
uma rodada da bateria (`CreatorInputsDeviceTests`).

### 11.13 Decisões de UI do dono (02/11, pelo canvas "My Cue Voice: decisões de UI")

| Item | Decisão |
|---|---|
| 1, 2, 4, 5, 6, 7, 10, 11, 13, 14, 15, B3 | Sim, como recomendado (o 2 depois de cada linha dizer a verdade) |
| 3 · medidor | Sim, com a D1: a prova (exemplos, texto importado, aprovados) passa a ir também ao Private Cloud Compute, e o medidor conta só o que chega |
| 8 · cartões só quando servem | Sim, sem seletor de idioma no My Cue Voice: "Write me as" e "Speak to viewers" seguem o Script language de Ajustes › Language & Region |
| 9 · histórias e fatos | Sim. O cartão diz ao criador que as respostas são situações reais, usadas como exemplo de como ele fala e escreve nos roteiros |
| 12 · retorno leve | Não. A faixa "Does it sound like you?" fica como está |
| B4 · idioma das ideias | Não |
| B6 · duração por roteiro | Não |
| B7 · tópicos viram mundos | Não, fica como está |
| Regra para todos | Textos de ajuda curtos, que dizem o que fazer onde se preenche algo |

B2 (os ganchos seguem o interruptor da voz) e B5 (contagens no Analytics) continuam abertos; não são de UI.

---

# Anexos

Os anexos estão em inglês, como foram escritos para o código. Caminhos relativos a `Cue Studio/`.

- **Anexo A:** rastreio de cada campo do My Cue Voice até o pedido da IA.
- **Anexo B:** inventário de cada tela e uso das entradas fora do perfil.
- **Anexo C:** pesquisa de nichos, voz, reclamações e necessidades por nicho, com fontes.
- **Anexo D:** pesquisa de concorrentes, retorno, gênero gramatical, formalidade e outras entradas, com fontes.



---

## Anexo A · Rastreio campo a campo (My Cue Voice → IA)

### My Cue Voice / CreatorProfile: what reaches the script AI

Read-only audit of `main` (ed350580), 2026-11-01. Paths are relative to `Cue Studio/`. Only code I actually read is cited here; anything I could not confirm is marked "not verified".

#### How the voice travels (the common pipe)

- `CreatorProfile.voice` (Models/CreatorProfile.swift:156-168) builds `CreatorVoice`. It sends `sounds` only if `.tone` was answered and `vocabulary` only if `.audience` was answered (l.159). `styles` and everything else always pass through. Excerpts are picked with `ExcerptRetriever.pick`.
- `voice(inLanguage:idea:professional:excerpts:)` (l.173-188): topics go through `IdeaFocus` (they are kept only when the idea shares a word with them); excerpts are filtered by language and idea, at most 2; examples and approved scripts about the idea move to the back; the fingerprint is dropped when its language is not the script's.
- Gates: `ScriptRequestFactory.request` (Managers/ScriptAI/ScriptRequestFactory.swift:42-45) sends a voice only when `profile.writesInMyVoice && !isSerious`. `writesInMyVoice = usesVoiceInAI && canWriteInMyVoice` (Managers/Preferences/CreatorProfileService.swift:43). `canWriteInMyVoice` needs at least one of role, topic, audience or tone (Models/CreatorProfile+VoiceSetup.swift:46-48).
- `AIRequestPolicy.prepare` (Managers/ScriptAI/AIRequestPolicy.swift:23-30) runs for every Apple route (`ScriptAIService+ContextBudget.swift:17`):
  - on PCC it strips `examples`, `excerpts` and `approvedSamples` (l.15-21);
  - on Auto length (`durationPolicy == .informative`, the default) it sets `reach.length = nil` on every route (l.27);
  - the PCC voice budget is 6000.
- Route choice: scripts (`freePrompt`), rewrites and hooks go to **PCC first**; ideas (`themes`) go to the device first (Managers/ScriptAI/AIModelRoute.swift:28).
- Brief text: `VoiceBriefBuilder.brief` (Managers/ScriptAI/Voice/VoiceBriefBuilder.swift:16-43).
  - Budget is 2100 units (`VoiceBrief.swift:15`). When the request is near the 4096-token window, `ContextBudget.voiceSteps` tries 1400, 900, 500 and 0 (Context/ContextBudget.swift:19, applied in Context/ScriptAIService+ContextBudget.swift:23-27).
  - Cut order: examples (shortened, then dropped), then reach, then tags (VoiceBriefBuilder.swift:29).
  - Nothing else is ever cut, even with budget 0: identity, audience, topics, sound, structure and rules always stay.
- Device and PCC script prompt: `ScriptPromptBuilder.instructions` (Managers/ScriptAI/ScriptPromptBuilder.swift:42-43) puts in the brief; the closing "Remember: …" rules are added at l.179-190. PCC uses `contextualPreferences: true`, which softens openings, endings and phrases into "preferences" (VoiceBriefBuilder.swift:281-303).
- Ultra: `UltraPayload` (Managers/ScriptAI/Ultra/UltraPayload.swift:44-62) uses `VoiceBriefBuilder.ultraProjection` (VoiceBriefBuilder.swift:50-65).
  - The **draft and check** stages get `content`: identity, audience, topics, tags, avoid rules and the swearing line.
  - Only the **polish** gets `delivery`: sounds, energy, sentences, words, humor, fingerprint lines, legacy styles, openings, endings, formats, phrases and platforms.
  - Examples, excerpts, approved scripts and `reach.length` are always removed.
  - The fit call gets `delivery` only (UltraFitRequest.swift:41-44).
- Post-check: `VoiceCheckedWriting` and `VoiceConstraintChecker` (avoid, pronoun, catchphrase-first, style name, fingerprint drift) run only in the Apple path (ScriptAIService.swift:145). Ultra has no post-check. PCC ignores pronoun violations (VoiceCheckedWriting.swift:91).

#### Field table

The device, PCC and Ultra columns are about **scripts**.

| field | how it gets into the AI (wording / summary) | on-device? | PCC? | Ultra? | ideas/tools? | dropped when | verdict |
|---|---|---|---|---|---|---|---|
| `name` | Never read by any prompt builder. Used in Profile UI and avatar (ProfileIdentityContent.swift:39, ProfileAvatar.swift:54) | no | no | no | no | always | UI-ONLY |
| `handle` | Never in a prompt. Profile UI, share text, QuickEdit `creatorHandle` (QuickEditView.swift:87) | no | no | no | no | always | UI-ONLY |
| `photoData` | Avatar only (ProfileAvatar.swift:17) | no | no | no | no | always | UI-ONLY |
| `niches` | Becomes `topics` (`CreatorProfile+Topics.swift:11-13`) as `"Topics: <promptName> (subtopics)."` (VoiceBriefBuilder.swift:261-267), e.g. "fitness and wellness". `CreatorVoice.niches` itself is never read by any builder (only zeroed in DEBUG `PCCDeliveryVoice.swift:14`). Also picks the starter ideas and idea slots (IdeaTopic.swift:28-34) | yes | yes | yes (draft) | ideas: always, as `IdeaTopic` in the prompt even with the voice off (ScriptPromptBuilder.swift:419-433) | `IdeaFocus` (Models/IdeaFocus.swift:17-28): dropped from a script when the idea (≥2 meaningful words) shares no word with the English promptName or the localized label (a pt idea with no shared word loses every topic); voice off; serious format; catalogOnly keeps niches | USED (scripts: only when the idea matches) |
| `customTopics` | Same "Topics:" line, typed text as is (VoiceTopicRef.swift:34-40) | yes | yes | yes (draft) | ideas yes | IdeaFocus as above; **catalogOnly drops typed topics** (CreatorVoice+CatalogOnly.swift:24-27) | USED |
| `voiceTopics` | Same "Topics:" line (`VoiceTopic.promptName`) | yes | yes | yes (draft) | ideas yes | IdeaFocus | USED |
| `topicDetails` (subtopics) | In parentheses after the topic: `"Topics: food and cooking (Italian, …)"` | yes | yes | yes (draft) | ideas: always listed (`themesPrompt`, ScriptPromptBuilder.swift:419-421) | scripts: **only the subtopics the idea itself names** (IdeaFocus.swift:25); catalogOnly keeps only Cue's own subtopics | PARTIAL (scripts) / USED (ideas) |
| `phrases` | Device: `They often say: “a”, “b”, “c”. Use one naturally, ideally in the opening.` or `…once after the first sentence` (VoiceBriefBuilder.swift:295-303). PCC/Ultra: `Optional familiar expressions: … Use at most one only if natural here; omission is better than forced repetition.` Also kept verbatim in rewrites (ScriptPromptBuilder.swift:691-693), trimmed from idea opening lines (IdeaBriefReader.swift:99-100, CatchphraseTrim.swift) | yes | yes (weak) | polish only (weak) | ideas brief (device); "In my voice" | **only the first 3 of up to 5** (`prefix(3)`, l.296; VoiceLimits.phrases = 5); catalogOnly drops all; VoiceAdjustment `.notMyPhrase` clears them | USED (device) / USED-BUT-WEAK (PCC, Ultra) |
| `role` | `Who they are: <promptName>.` (VoiceBriefBuilder.swift:201-205). Also sets the default "I"/"we" (`CreatorRole.suggestedSpeaksAs`, business/brands → "we") | yes | yes | yes (draft) | ideas, In my voice | not sent when `customRole` is set (custom wins); serious format | USED |
| `customRole` | `Who they are: <typed>.` | yes | yes | yes (draft) | ideas, tools | catalogOnly drops it (CatalogOnly.swift:22) | USED |
| `credential` | `Credential: <typed>. Mention it only where it fits; never invent another.` (l.206-208) | yes | yes | yes (draft) | ideas, tools | catalogOnly drops it | USED |
| `speaksAs` | Identity line `They speak as a team: say “we”…` / PCC/Ultra `Their default voice is …` (l.209-217) plus a closing rule (l.71-78). Device pronoun check (VoiceConstraintChecker.swift:86-100, en/pt/es only). Ultra fit: "Keep the speaker" (UltraInstructions.swift fitter) | yes (+check) | yes (soft; pronoun violations ignored, VoiceCheckedWriting.swift:91; "request's perspective overrides", PCCScriptDirection.swift:52) | yes (draft, "default") | ideas, tools | nil → `role.suggestedSpeaksAs` → "I" | USED |
| `voiceApproved` | Only hides the "sounds like me" preview strip (ScriptDetailViewModel+VoicePreview.swift:13,24,52) | no | no | no | no | always | UI-ONLY |
| `sounds` | `They sound casual and confident.` (`VoiceSound.promptWord`, VoiceBriefBuilder.swift:120) | yes | yes | polish only | ideas, tools | **sent only when `.tone` is in `confirmedVoiceSteps`** (CreatorProfile.swift:159); profiles from old builds (`unverifiedVoiceSteps`) send nothing until confirmed. The prompt word differs from the label: "Straight to the point"→"professional", "Playful"→"funny", "Conversational"→"casual" (VoiceSound.swift:18-40) | USED (label replaced, see Gaps) |
| `vocabulary` | Only as an audience fallback: `Their audience is everyday people: use simple, everyday words.` etc. (VoiceBriefBuilder.swift:227-249) | rarely | rarely | rarely | rarely | needs `.audience` confirmed **and no `audienceNote`/`audienceGroup` and no `style.words`** (l.225-228). Picking a group also writes the group's vocabulary (CreatorProfileService+VoiceDetails.swift:112), so it is redundant there | PARTIAL (mostly NOT USED) |
| `styles` (legacy) | `Style: storytelling, opinionated.` (l.141-142) | yes | yes | polish only | ideas, tools | the defaults `shortSentences` and `conversational` are always filtered out; no current screen writes `storytelling` / `educational` / `opinionDriven` (only old profiles; VoiceAdjustment `.tooLong` appends `shortSentences`, which is then filtered out) | NOT USED for new creators (legacy) |
| `usesVoiceInAI` | Master switch: no voice in scripts or ideas when off (CreatorProfileService.swift:43, IdeaSuggestionService.swift:507) | gate | gate | gate | **not** a gate for "In my voice" or hooks (the rewrite context always carries the voice, ScriptDetailViewModel.swift:192-199) | – | USED (gate) |
| `defaultPlatform` | Platform for a request with none chosen (ScriptRequestFactory.swift:24-27): platform line, register (professional caps), length preset | yes | yes | yes | blank scripts | only primary platforms count (else TikTok); **independent of `reach.platforms`** | USED (indirect) |
| `monetizationGoals` | Platform preset `idealRange` (PlatformRules.swift:86-99, ScriptRequestFactory.swift:39) → `targetRange` on Auto | ~no (Auto: "Platform duration is informational", ScriptPromptBuilder.swift:157-164; only the response-token cap, ScriptAIService.swift:755-758, and the progress meter) | ~no (same) | **yes**: on Auto `UltraLength.ideal(targetRange)` is said in the prompt (UltraLength.swift:23-31) | – | overridden by `reach.length` when answered (ScriptRequestFactory.swift:75-81); YouTube on Ultra is free; Stories/studio keep the preset | PARTIAL (Ultra only) |
| `confirmedVoiceSteps` / `unverifiedVoiceSteps` | Gates for `sounds`/`vocabulary` and for `canWriteInMyVoice` | gate | gate | gate | gate | – | USED (gate, no text) |
| `openings` | Device: `Open with a question or a bold claim: show it in the script, never write the style's name.` (VoiceChoiceCatalog guidance; typed text quoted) + hookRule "in the creator's own way of opening" (ScriptPromptBuilder.swift:263-271) + closing "Never write the name of an opening style" + style-name check (VoiceConstraintChecker.swift:136-151). PCC/Ultra: `Usual opening preference, only when supported by this request: … A story opening requires an experience supplied in the request; otherwise open directly on the subject.` | yes | yes (weak) | polish only (weak; writer: profile "never imposes … the opening", UltraInstructions.swift:26) | ideas (device brief) | an idea from Find inspiration with its own opening line overrides it (ScriptPromptBuilder.swift:168-172); catalogOnly keeps known styles only | USED (device) / USED-BUT-WEAK (PCC, Ultra) |
| `endings` | Device: `End by asking viewers to save the video.` / `End by saying “See you Sunday”.` (l.285-290). PCC: `Usual ending preference, only if this request permits it … never an automatic sign-off` + "avoid a generic follow, like or subscribe sign-off" (PCCScriptDirection.swift:68). Ultra polish: same preference line, but the editor is told "add a call to action only when the request asks for one" (UltraInstructions.swift:123) | yes (conflicts with platform line) | weak | **effectively overridden** for CTA endings | ideas | catalogOnly keeps known only | USED (device) / USED-BUT-WEAK (PCC) / ~NOT USED (Ultra CTAs) |
| `formats` | `They film mostly: tutorials, lists and tips.` (l.291-294). Device Auto also uses them as the tie-breaker for the block structure (`FormatGuess.format(for:usual:)`, ScriptPromptBuilder.swift:216; FormatGuess.swift:13-18). PCC: "Usual formats are a fallback only when the request gives no direction" (PCCScriptDirection.swift:22). Ultra: "usual formats only help when the request is vague" (UltraPayload.swift:83-84) | yes (+structure) | yes (weak) | polish only (weak) | ideas | – | USED |
| `style.energy` | `Delivery: energy: calm; …` (VoiceBriefBuilder.swift:122) | yes | yes | polish only | ideas, tools | – | USED |
| `style.sentences` | Delivery line, plus the first instruction ("in natural spoken language with longer, flowing sentences", ScriptPromptBuilder.swift:54-60), plus words per sentence for the length rule (l.286-298). Ultra: "short and punchy … (a rhythm preference, never a limit…)" | yes | yes | polish only | ideas, tools | unanswered → the instruction still says "short sentences" (l.58) | USED |
| `style.words` | Delivery line `words: plain and everyday` | yes | yes | polish only | ideas, tools | "some slang" becomes "plain" on a professional platform (l.125-127) | USED |
| `style.swearing` | `Never swear.` / `Mild swearing is fine now and then. Never write strong swearing or slurs.` (l.131-139) | yes | yes | yes (draft/content) | ideas, tools | professional platform → "Never swear." | USED |
| `avoid` | `Rules: <instruction>; …` (l.324-327) + closing `Remember: … Avoid: clickbait.` (l.80-82) + post-check: word lists for Cue's rules, literal match for typed ones (VoiceConstraintChecker.swift:47-66), one rewrite. PCC: "Keep … the creator's avoid rules" (PCCScriptDirection.swift:50) | yes (+check) | yes (+check) | yes (draft and check; **not in the fit call; no post-check**) | ideas, tools | catalogOnly drops typed avoid items (CatalogOnly.swift:16); **serious format sends no voice at all** | USED (Ultra: weaker) |
| `avoidNone` | Only counts as answered for the meter (CreatorProfile+VoiceSetup.swift:89) | – | – | – | – | – | UI-ONLY (correct: nothing to send) |
| `reach.platforms` | `They post on TikTok, Reels.` (VoiceBriefBuilder.swift:310-317), using the **localized `Platform.label`** in the English brief | yes | yes | polish only | ideas | **cut 2nd** by the budget (also at window steps 1400…0) | USED-BUT-WEAK |
| `reach.length` | `Videos are usually under 30 seconds.` (l.313) and `targetRange` on Auto (ScriptRequestFactory.swift:75-81) | Auto: **line removed** (AIRequestPolicy.swift:27) and the range is not binding; chosen length: the line stays alongside the chosen length | same as device | line always removed (VoiceBriefBuilder.swift:55); on Auto it sets the `.ideal` range (non-YouTube) | – | cut 2nd by the budget; Stories/studio ignore it; capped 25 s…120 s | PARTIAL |
| `reach.humor` | `Delivery: …; humor: none, no jokes.` (l.128) | yes | yes | polish only | ideas, tools | – | USED |
| `audienceLevel` | `They know some basics: skip the obvious and go one level deeper.` (l.230-257) | yes | yes | yes (draft) | ideas, tools | – | USED |
| `approvals` (count) | Meter only: `provenExamples` (CreatorProfile+VoiceSetup.swift:75) | no | no | no | no | – | UI-ONLY |
| `examples` (pasted, ≤3) | Under `Here is how they write. Match the voice; never reuse these sentences, facts or stories:` as `- “…”` (VoiceBriefBuilder.swift:149,192), each cut at 300 chars (VoiceExample.swift:14,30-33) | yes (fallback route only) | **no** (stripped) | **no** | ideas (device, the main route); "In my voice" only on the device fallback | **examples go first in the cut**; order is newest approved, then up to 2 excerpts, then pasted, then other approved, **max 3 in total** (l.332-336), so with 1 approved + 2 excerpts **no pasted example is sent**; examples about the idea go last; catalogOnly drops them | PARTIAL (rarely reach scripts) |
| `customTags` (format tags "Talking head", "Q&A"…) | Added to the `They film mostly:` line (l.291) | yes | yes | polish only | ideas | – | USED |
| `customTags` (other typed tags) | `Also true of them, in their own words: …` (l.319-322) | yes | yes | yes (draft) | ideas, tools | cut 3rd by the budget; catalogOnly drops them; **typed openings, endings and phrases are copied into this list too** (CreatorProfileService+Personality.swift:64-68) and never removed with them | USED (with duplicates / stale entries) |
| `declinedVoiceItems` | Only `nextQuestion` skipping (CreatorProfile+VoiceSetup.swift:131-133) | – | – | – | – | – | UI-ONLY |
| `audienceGroup` | `Their audience: working professionals.` (`AudienceGroup.promptName`, l.225-226) | yes | yes | yes (draft) | ideas, tools | `audienceNote` wins | USED |
| `audienceNote` | `Their audience: <typed>.` | yes | yes | yes (draft) | ideas, tools | catalogOnly drops it | USED |
| `watchReasons` | `They watch to learn something and get inspired.` (l.233-235) | yes | yes | yes (draft) | ideas, tools | – | USED |
| `contentGoals` | `Their videos aim to sell a product or service.` (l.236-238) | yes | yes | yes (draft) | ideas, tools | – | USED |
| `approvedSamples` ("Sounds like me" + "Your edits") | First place among the examples (the newest one) (l.332-335) | yes (fallback route only) | **no** | **no** | ideas (device) | same as `examples`; at most 3 kept (CreatorProfileService+VoiceDetails.swift:246-251; +DraftLearning.swift:16-24) | PARTIAL |
| `excerpts` (imported, ≤24) | Up to 2 per request (CreatorProfile.swift:173-177; `ExcerptRetriever.pick`), as examples | yes (fallback) | **no** | **no** | ideas (device, up to 2) | other language; emoji on a professional platform (ExcerptRetriever.swift:33-35); budget cut first; catalogOnly | PARTIAL |
| `excerpts[].language / role` | language: filter; role: opening/body/closing pick order (ExcerptRetriever.swift:30-48) | selection only | – | – | – | – | USED (selection) |
| `excerpts[].wordCount / source / addedAt`, `examples[].source / addedAt` | Not sent | – | – | – | – | – | NOT USED (metadata) |
| `fingerprint.wordsPerSentence` | `Their sentences average about 14 words.` (VoiceFingerprintRules.swift:21-23); length rule words per sentence (ScriptPromptBuilder.swift:293-295); drift check (soft) | yes | yes | polish only | ideas, tools | only if `isReliable` (≥150 words, ≥2 pieces), same language, **`style.sentences` unanswered**, and a spaced script | PARTIAL |
| `fingerprint.exclamationShare / questionShare` | `They almost never use exclamation marks.` (≤3%, ≥200 words) **or else** `They often ask the viewer a question.` (≥25%) (l.24-28); exclamation drift check | yes | yes | polish only | ideas, tools | reliable + same language; only one of the two is ever said | PARTIAL |
| `fingerprint.emojiPer100Words / averageWordLength` | Not in prompts; used once at import to suggest energy and words (WritingImport/WritingAnalyzer.swift:113-128) | indirect | indirect | indirect | – | – | NOT USED at generation (import-time only) |
| `fingerprint.singularWords / pluralWords / medianWords / measuredAt` | Stored only. At import, speaksAs is suggested from the raw counts, not these fields (WritingAnalyzer.swift:137-142); no reader of these fields elsewhere | – | – | – | – | – | NOT USED |
| `voiceSchemaVersion` | Written at encode (l.345), decoded (l.288), never read elsewhere | – | – | – | – | – | NOT USED |

#### Gaps

1. **The Proof layer almost never reaches a script.** Scripts go to PCC first (AIModelRoute.swift:28), and PCC strips `examples`, `excerpts` and `approvedSamples` (AIRequestPolicy.swift:15-21). Ultra strips them too (VoiceBriefBuilder.swift:52-54).
   - They only reach a script when PCC is unavailable or fails and the device writes.
   - They do reach ideas, which run on the device (`themesInstructions`, ScriptPromptBuilder.swift:404-408).
   - Yet they are 20% of `voiceStrength` (CreatorProfile+VoiceSetup.swift:62-75), and "Import my writing" and "Sounds like me" promise learning. Only the fingerprint *numbers* get through on PCC and Ultra.
2. **Pasted examples are crowded out.** At most 3 examples are sent, in the order newest approved, then up to 2 excerpts, then pasted (VoiceBriefBuilder.swift:332-336). A creator with one "Sounds like me" or "Your edits" sample and imported writing never has a pasted example sent, even on the device. `learnFromRecordedScript` (CreatorProfileService+DraftLearning.swift:16-24) adds "Your edits" samples automatically, which makes this more likely.
3. **Endings contradict the platform line on the device.** `PlatformGuide.line` for TikTok says "end with one easy action (comment, follow or save)" (Context/PlatformGuide.swift:15). Reels says "an ending that asks to save or share", Stories "ending with a request for a reply or a vote". These sit next to "End by leaving out any call to action" (VoiceChoiceCatalog.swift:31). The format guides' CTA blocks (fixture `Cue StudioTests/Fixtures/VoiceBriefs/v2/VoiceBriefs-v2-barbershop.txt`) do the same.
4. **Ultra effectively ignores CTA endings.** The ending goes only to the polish, and the editor is told "add a call to action only when the request asks for one" (UltraInstructions.swift:123). The writer is told the profile "never imposes … the opening … or the ending. Do not add a question or a call to comment, like or follow out of habit" (l.26-27). "Follow for more", "Comment your answer", "Save this" and "Link in bio" are therefore overridden. On PCC, "avoid a generic follow, like or subscribe sign-off" (PCCScriptDirection.swift:68) contradicts a chosen "Follow for more".
5. **Openings and phrases are softened on PCC and Ultra.** They become "only when supported by this request" or "at most one only if natural; omission is better" (VoiceBriefBuilder.swift:281-303). On the device they are firm. Since PCC is the main script route, the creator's opening and catchphrase are weak by default.
6. **Phrases are silently truncated.** The creator can store 5 (VoiceLimits.swift:14), but only `prefix(3)` is sent (VoiceBriefBuilder.swift:296).
7. **Topics are dropped by literal word overlap.** `IdeaFocus.topics` keeps a topic only if the idea shares a word (or a 5-letter prefix) with the English `promptName` or the localized label (IdeaFocus.swift:17-28, 42-50). Synonyms and paraphrases don't count. Subtopics go only when the idea names them (l.25). This is intentional (the doc comment cites a measured off-topic bug), but in practice topics and subtopics rarely reach scripts. Ideas get all of them.
8. **`reach.length` contradicts a chosen length.** With a chosen length (`.targeted`), `AIRequestPolicy.prepare` keeps `reach.length` (l.27), so the brief says "Videos are usually under 30 seconds" next to "Length: between X and Y words" for, say, 3 minutes. On Auto, the Apple engines drop the line and treat the range as informative (ScriptPromptBuilder.swift:157-164). The usual length then only changes the token cap and the progress meter, so for on-device and PCC scripts it has almost no effect.
9. **`monetizationGoals` mostly has no effect on Apple scripts.** On Auto the range is "informational" for the device and PCC. It only reaches the prompt on Ultra (`UltraLength.ideal`, UltraLength.swift:23-31) and on screens that show the ideal range.
10. **Typed text is duplicated and goes stale in `customTags`.**
    - `addCustom` copies every typed opening, ending or phrase into `customTags` (CreatorProfileService+Personality.swift:64-68).
    - The brief then says it twice: "They often say: “Hey fam”" and "Also true of them, in their own words: Hey fam".
    - Removing the item with `toggle` (l.27-36) edits only the list, never `customTags`. The only `customTags.remove` is for format tags (CreatorProfileService+VoiceAnswers.swift:215-216), so a deleted opening keeps being sent as a tag. Not verified: whether some editor UI removes it another way. `VoiceFormatsField.swift:68` lists these tags as typed formats.
11. **Typed formats lose their label.** A typed format (e.g. "ASMR") goes to `customTags`, and only Cue's known format tags go to "They film mostly" (VoiceBriefBuilder.swift:291, 319-322). The typed format ends up in the generic "Also true of them" line, and that line is cut by the budget (3rd).
12. **Labels are swapped for coarser or different prompt words** (VoiceSound.swift:18-40):
    - "Straight to the point" → "professional";
    - "Playful" → "funny";
    - "Conversational" → "casual".
    `reach.platforms` uses the localized UI label ("Reels", "Shorts", or a translation) in an English brief instead of `promptName` (VoiceBriefBuilder.swift:312; Platform.swift:20-40).
13. **`vocabulary` is mostly dead.** It is sent only when there is no audience group or note and no `style.words` (VoiceBriefBuilder.swift:225-228). Choosing a group writes the group's vocabulary (VoiceDetails.swift:112), which is then never sent. The `.tooMuchSlang` and `.tooFormal` adjustments edit it (VoiceAdjustment.swift:45-48), usually to no effect.
14. **The `.tooLong` adjustment can do nothing.** When `style.sentences` is unanswered it only appends `.shortSentences` to legacy `styles` (VoiceAdjustment.swift:56-58), which the brief filters out (VoiceBriefBuilder.swift:141).
15. **No voice at all on a serious format**, including avoid rules, credential and "I"/"we" (ScriptRequestFactory.swift:40-45; ScriptPromptBuilder.swift:20). A creator's "never mention X" is not applied to an apology or statement.
16. **The voice gate ignores Personality and Proof answers.** `canWriteInMyVoice` needs role, topic, audience or tone (CreatorProfile+VoiceSetup.swift:46-48). A creator who only answered avoid, openings, phrases or examples, or only imported writing, sends nothing.
17. **Ultra checks less.** There is no `VoiceConstraintChecker` pass (avoid, pronoun, catchphrase-first, style name), no closing "Remember" rules and no catalog-only retry. The fit call carries `delivery` only: no avoid rules and no swearing rule (UltraFitRequest.swift:41-44).
18. **Rewrite and hooks ignore the switch and the platform.** `rewriteContext` always builds the voice, even with "Use my voice in drafts" off or before `canWriteInMyVoice` (ScriptDetailViewModel.swift:192-199). Hooks use it (ScriptAIService.swift:450). `rewriteInstructions` calls `voiceLines(voice)` with no platform (ScriptPromptBuilder.swift:488-490), so the professional caps (no slang or swearing on LinkedIn) are not applied in "In my voice". Other tools get no voice, only phrase preservation (ScriptAIService.swift:406, 418).
19. **Fingerprint reach is narrow.** Only `wordsPerSentence` and one of exclamation/question become prompt lines (VoiceFingerprintRules.swift:18-30). The sentence average is suppressed whenever `style.sentences` is answered. Emoji rate, word length and I/we counts only seed suggestions at import. `singularWords`, `pluralWords` and `medianWords` are never read after they are written.
20. **Stored but unused or redundant fields:**
    - `voiceApproved`: UI only (preview strip);
    - `approvals`: meter only;
    - `voiceSchemaVersion`: never read;
    - `CreatorVoice.niches`: duplicate of `topics`, never read by a builder;
    - `name`, `handle`, `photoData`: UI only.
21. **Unchecked contradictions between fields.** Nothing reconciles `sounds` "energetic" with `style.energy` "calm", or `sounds` "funny"/"dry" with `reach.humor` "none, no jokes". Both go to the model as they are (VoiceBriefBuilder.swift:120-129). `defaultPlatform` and `reach.platforms` are independent: a creator who posts only on Instagram but left TikTok as the default gets TikTok scripts.
22. **"What Cue sends" differs from what a request sends.**
    - The "On this iPhone" card is `profile.voice`: every topic and subtopic, casual register (ScriptPromptBuilder.swift:347-350; VoiceSendsSheet.swift:19). A real request filters topics by the idea and caps by platform.
    - The PCC card uses contextual wording (VoiceSendsSheet.swift:92-95), which is correct for scripts.
    - Neither card shows that on Auto the usual length is removed.


---

## Anexo B · Inventário técnico das telas

### Cue Studio: everything the creator is asked, and whether it is used

Read-only audit of `main` (ed350580), 01/11/2026. Paths are relative to `Cue Studio/`. Nothing was built or run.
"On-device" means Apple's model on the iPhone, "PCC" means Private Cloud Compute, and Ultra is Ultra AI (Gemini).

**Facts that apply to the whole report**

- **One request object for all three script engines.** On-device, PCC and Ultra are all built from one `ScriptRequest`, made in `ScriptRequestFactory.request` (`Managers/ScriptAI/ScriptRequestFactory.swift:31-62`).
  - On-device and PCC use the same `ScriptPromptBuilder.instructions/prompt`. PCC adds its own lines when `modelRoute == .privateCloud` (`ScriptAIService+CloudDraft.swift:22,41`; `PCCScriptDirection.swift`).
  - Ultra uses `UltraPayload` (`Ultra/UltraPayload.swift:46-60`).
  - So any field in the request reaches all three engines, unless a filter is noted below.
- **Scripts go to PCC first.** A script written from an idea is task `.freePrompt` (`ScriptAIService.swift:107`), and `.freePrompt`, `.rewrite` and `.hooks` prefer PCC (`AIModelRoute.swift:28`).
  - On PCC, `AIRequestPolicy.voice` removes `examples`, `excerpts` and `approvedSamples` (`AIRequestPolicy.swift:15-21`).
  - Ultra never sends them either (comment at `UltraPayload.swift:8-11`).
  - Result: every "proof" input reaches the AI only when the on-device model writes. For scripts and tools, that is only the fallback when PCC is unavailable.
- **Ultra is Debug only.** It is offered only when `UltraLabConfiguration.isPresent` in Debug (`SupportFiles/LaunchOptions.swift:288-291`). In Release, nothing about Ultra is shown or used.
- **No length picker.** Nothing in the UI sets `ScriptLength`. The dock's length comes only from:
  - phrases in the idea such as "2 minutes on…" (`ScriptLength.detected`, `ScriptRequestFactory.swift:38`),
  - starter ideas in Find inspiration (`FindInspirationSheet.swift:549`),
  - an idea opened from a notification (`NotificationNavigator.swift:135`).
- **No way to send feedback.** I found no feedback form, no "Report a problem", no App Store rating request (`requestReview`), no email link, and no thumbs up/down. The only signals that leave the iPhone are counts sent to Firebase through `Managers/Telemetry/TelemetryManager.swift`, and only when "Help improve Cue" is on.

---

#### Part A: Inventory

##### Onboarding (first launch)

| input | where | kind & options | saved to |
|---|---|---|---|
| "What do you usually talk about?" | `Screens/Onboarding/Universe/UniverseChapter.swift:49,77` | Chips, pick up to 3 (`OnboardingTopic.limit`). 10 topics: Fitness & wellness, Food & cooking, Beauty & skincare, Fashion & style, Personal finance, Tech & AI, Budget travel, Productivity & career, Parenting & family, Daily routines | `OnboardingService.topics`, then `CreatorProfile.niches` (`OnboardingViewModel.swift:127-136`; `CreatorProfileService.applyFirstFlight`, `CreatorProfileService.swift:56-62`) |
| "+ your own" topic | `UniverseChapter.swift:118` (placeholder "Budget travel") | Free text, 2–40 characters, checked by `VoiceTextValidator` (`:214`); counts toward the 3 | `CreatorProfile.customTopics` |
| "Where will you share your videos?" | `Screens/Onboarding/Voyage/VoyageChapter.swift:70,106` | Single choice, 5 options (`Platform.primary`): TikTok, Reels, Shorts, YouTube, LinkedIn | `CreatorProfile.defaultPlatform`, plus the dock's `IdeaDraftService.platform` (`OnboardingViewModel.swift:134-135`) |
| Mic, Speech and Camera permissions | `Screens/Onboarding/Voice/VoiceChapter.swift`; `OnboardingViewModel.swift:65-112` | System prompts | iOS (not AI) |
| Practice script / teleprompter | `Message/ScriptChapter.swift:80`, `PracticeChapter.swift` | No input. The script is fixed (`OnboardingScript.practice`), not written by AI | Becomes a library script (`keepScript`, `:118-124`) |

Nothing asked in onboarding is lost. A flight quit before 1.4 starts again from the welcome. Side effect: one topic picked here (`topicCount > 0`) makes `canWriteInMyVoice` true (`CreatorProfile+VoiceSetup.swift:46-48`), so "Write in my voice" is effectively on from the first script.

##### My Cue Voice: Essentials (asked in three places)

The same profile fields are asked in three places:

- the guided setup `Screens/Shared/VoiceStyle/VoiceSetupSheet.swift:104-107` (the steps are role, niche, audience and tone; `VoiceSetupStep.swift`),
- the full page and editor `Screens/Profile/Voice/MyCueVoicePage.swift` and `Editor/*`,
- the one-question tip `Screens/Profile/Voice/Question/VoiceQuestionSheet.swift`, which uses the `VoiceQuestion` bank (`Models/VoiceQuestion.swift`).

| input | where | kind & options | saved to |
|---|---|---|---|
| "What kind of creator are you?" | `Editor/VoiceRoleField.swift:42`; tip `VoiceQuestion.role`; Edit Profile `Sheets/CreatorTypePicker.swift:21` | Single choice, 8 options: Lifestyle & personal, Entertainer, Expert/coach/pro, Teacher or explainer, My own business, Content for brands, News & commentary, Community or cause | `role` |
| own kind of creator | `VoiceRoleField.swift:92` ("e.g. Wedding photographer…"); `CreatorTypePicker.swift:112` ("Podcaster, chef, gamer…"); in the tip, "+ Something else" | Free text, 2–40 characters | Editor and Edit Profile save it to `customRole`. The tip saves it to `customTags` (`CreatorProfileService+VoiceAnswers.swift:187`) |
| "Your credential" (optional) | `VoiceRoleField.swift:122-128` | Free text ("e.g. Registered nurse") | `credential` |
| "Scripts say" I / We | `VoiceRoleField.swift:24-27` | Segmented control, 2 options | `speaksAs` |
| "What do you talk about?" | `Editor/VoiceTopicsField.swift:29-40`; tip `.topics` | Multi-choice, up to 3 of 25: the 10 onboarding topics plus 15 more (Gaming, Real estate, Music & arts, Pets & animals, Home & DIY, Health & medicine, Business & marketing, Study & exams, Relationships, Faith & spirituality, News & current events, Cars & motorcycles, Sports, Languages, Books/film & TV) | `niches`, `voiceTopics` |
| "+ Not here? Add your topic" | `VoiceTopicsField.swift:106-112` | Free text, 2–40 characters | `customTopics` |
| "More specific in X" | `VoiceTopicsField.swift:133-145` | Chips, up to 3 per topic (about 7 suggestions per topic, `VoiceSubtopicCatalog`), plus "Your own" text | `topicDetails` |
| "Who is watching?" (editor and setup) | `Editor/VoiceAudienceField.swift:21,48-51` | Single choice, 8 options: Teenagers, Students, Young adults, Parents, Working professionals, Business owners, My local community, People who already know the field | `audienceGroup` (also sets `vocabulary`, `CreatorProfileService+VoiceDetails.swift:107-116`) |
| "+ Describe them in your words" | `VoiceAudienceField.swift:75-81` | Free text ("e.g. Nurses on night shifts") | `audienceNote` |
| "Who's watching?" (tip version) | `VoiceQuestion.swift:102` | Single choice, **4 different options**: Everyday people, People who know the field, A young crowd, Professionals | `vocabulary` only (`VoiceAnswers.swift:90-94`). The tip's "+ Something else" goes to `customTags` |
| "How much do they already know?" | `VoiceAudienceField.swift:98-101`; tip `VoiceQuestionSheetModel.swift:20,69` | Single choice, 3 options: New to it, Some basics, Experienced | `audienceLevel` |
| "Why do they watch you?" | `VoiceAudienceField.swift:26-32` | Multi-choice, up to 2 of 6: Learn something, Get inspired, Solve a problem, Have a laugh, Feel understood, Decide what to buy | `watchReasons` |
| "How do you talk on camera?" | `Editor/VoiceToneField.swift:31-38`; tip `.tone` | Multi-choice, up to 2 of 8: Conversational, Straight to the point, Educational, Confident, Warm & calm, Energetic, Playful, Dry & sarcastic | `sounds` (in the tip, "+ Something else" goes to `customTags`) |

##### My Cue Voice: Personality

| input | where | kind & options | saved to |
|---|---|---|---|
| Energy | `VoiceToneField.swift:55`; tip "What's your energy on camera?" | 3 options: Calm, Balanced, High | `style.energy` |
| Sentences | `VoiceToneField.swift:61`; tip "Short sentences or longer ones?" | 3 options: Short, Mixed, Long | `style.sentences` |
| Words | `VoiceToneField.swift:67`; tip "How technical are your words?" | 3 options: Plain, Some slang, Expert terms | `style.words` |
| Humor | `VoiceToneField.swift:73`; tip "How much humor…?" | 3 options: None, A little, A lot | `reach.humor` |
| Swearing | `VoiceToneField.swift:79`; tip "Any swearing?" | 2 options: Never, Mild only | `style.swearing` |
| "What you film most" | `Editor/VoiceFormatsField.swift:18`; tip `.formats` | Up to 3 of 11: Talking head, Tutorial, Storytime, List/tips, Review, Reaction, Day in the life, Myth vs fact, Q&A, Behind the scenes, Before/after; plus own text | `formats`. The 5 with no matching `ScriptType` are saved as text in `customTags` (`VoiceQuestion.swift:141-147`) |
| "How you like to open" | `VoiceFormatsField.swift:19`; tip `.openings` | Up to 2 of 7: Bold claim, Question, Story opener, Surprising fact, POV, Mistake to avoid, Start with a number; plus own text | `openings` |
| "How you usually end" | `VoiceFormatsField.swift:20`; tip `.endings` | Up to 2 of 6: Save this, Follow for more, Comment your answer, Link in bio, Try it and tell me, No call to action; plus own text | `endings` |
| "My videos are for" | `VoiceFormatsField.swift:81-87` (editor only) | Up to 2 of 7: Grow my audience, Sell something, Teach, Entertain, Win clients, Build a community, Raise awareness | `contentGoals` |
| "Phrases you actually say" | `Editor/VoicePhrasesField.swift:26-45`; tip `.phrases` (free text first, with 3 examples to tap) | Free text, up to 5, max 40 characters each | `phrases` |
| "Cue never writes" | `VoicePhrasesField.swift:59-71`; tip `.avoid` | Up to 3 of 8: Clickbait, Hype words, Emojis in captions, Medical claims, Politics, Exaggerated promises, False urgency, Naming competitors; plus "Nothing to avoid" and own text | `avoid`, `avoidNone` |
| "Where you post" | `Editor/VoiceReachField.swift:18`; tip "Where do you post most?" | Editor: multi-choice of 6 platforms. Tip: single choice (it replaces the list, `VoiceAnswers.swift:128`) | `reach.platforms` |
| "Usual length" | `VoiceReachField.swift:30-35`; tip | 4 options: Under 30 s, 30 to 60 s, 1 to 3 min, Longer | `reach.length` |
| "None of these" (tip) | `VoiceQuestionSheetModel.swift:114-120` | Button | `VoiceQuestionScheduler.state.skipped`, kept on the iPhone (not AI) |
| "Use my voice in drafts" | `Profile/Voice/MyCueVoicePage.swift:92` | Toggle | `usesVoiceInAI` |

##### Proof and learning

| input | where | kind | saved to |
|---|---|---|---|
| "Add an example" plus "I said or wrote this myself" | `Editor/VoiceExamplesField.swift:126-142` | Free text (2–4 sentences), up to 3. The toggle is required to save and is not stored | `examples` |
| "Import my writing" (paste, "I wrote these myself", findings to keep or drop) | `Voice/Import/WritingImportCollectView.swift:21,44`; `WritingFindingRow.swift:17` | Pasted text separated by `---`; one toggle per finding | `excerpts`, `fingerprint`, and the fields each finding fills (`CreatorProfileService+WritingImport.swift`) |
| "Does it sound like you?" → **Sounds like me** | `ScriptDetail/Page/VoicePreviewStrip.swift:21,36` → `ScriptDetailViewModel+VoicePreview.swift:51-58` | Button | `voiceApproved = true` (the strip never shows again for any script), `approvals` +1, and the opening joins `approvedSamples` |
| My Cue Voice / Without | `VoicePreviewStrip.swift:51` | Segmented control; view only (Without asks Apple Intelligence for a version without the voice) | nothing |
| **Adjust** → "What didn't sound like you?" | `Page/VoiceAdjustSheet.swift:20-56` | Multi-choice, 5 options: Too formal, Too much slang, Too over the top, "I don't say that", Too long. Plus "This script only" or "Also my profile". Plus ✦ Rewrite | Profile fields when "Also my profile" (`VoiceAdjustment.swift`); otherwise used once for the rewrite (`ScriptDetailViewModel+VoicePreview.swift:64-83`) |
| Your edits on a Cue draft you then recorded | implicit (`Managers/Preferences/DraftLearning/DraftLearningService.swift:52-60`) | No question; the toast offers Undo | `approvedSamples` (source "Your edits") |
| Preview my voice / What Cue sends | `MyCueVoicePage.swift:172,184`; `Preview/VoicePreviewSheet.swift:53` | View only | nothing |

##### Edit Profile and Settings

| input | where | kind | saved to |
|---|---|---|---|
| Name, @handle, photo | `Profile/Sheets/EditProfileSheet.swift:76,89`; `EditProfilePhoto.swift:70` | Text up to 40 characters; handle 2–24 characters; photo | `name`, `handle`, `photoData`. **None of them reaches the AI** (no use of `profile.name`/`handle` in `Managers/ScriptAI`) |
| Kind of creator | `CreatorTypePicker.swift:21,112` | Same choices as My Cue Voice | `role` / `customRole` |
| "New scripts are made for" | `EditProfilePreferences.swift:19-27` | Single choice, 6 platforms (Stories included; `ScriptRequestFactory.swift:24-27` treats Stories as TikTok) | `defaultPlatform` |
| Monetization goals | `EditProfilePreferences.swift:38`; also `DestinationSheet.swift:32` and `ScriptDetailsSheet.swift:44` | Toggle (one setting shown in 3 places) | `monetizationGoals` |
| Settings › Language & Region: App language / Voice following / **Script language** | `Settings/Rows/LanguageEntryRow.swift:29,49-52` | Menus (Script language: Auto-detect or one of the app's languages) | `LanguageService` |
| Settings › Privacy: "Apple Intelligence" | `Settings/Rows/PrivacyEntryRow.swift:28` | Toggle. It turns all of Apple's AI (on-device and PCC) on or off; there is no "on-device only" choice | `usesOnDeviceAI` → `writer.isEnabled` (`PrivacyPreferencesService.swift:15-19`) |
| "Help improve Cue" | `PrivacyEntryRow.swift:33` | Toggle (off by default) | allows the notification and first-voyage Analytics events |
| Ultra AI permission | `Settings/Privacy/PrivacyView.swift:73`; `Shared/Ultra/UltraConsentSheet.swift:92-98` (Allow / Not now) | Toggle / buttons | `UltraConsentService` |
| Personalize › "Tag new scripts automatically" | `Settings/Personalize/PersonalizeTopics.swift:41` | Toggle | `autoTagsTopics` → `Script.topic` (universe only, not AI) |
| Notifications: "Help me finish what I start" / "Tools and news" / "Remind me to create" | `Settings/Notifications/NotificationGroupRow.swift:16`; `Models/Notifications/NotificationGroup.swift:31-33` | Toggles | `NotificationService` (not AI) |
| Creation routine (days, time) and reminders | `NotificationRoutineEditor.swift:45`; `Shared/Reminders/ReminderSheet.swift:106` | Date/time picker | `NotificationService` (not AI) |

##### Create a script (the Scripts dock and the sheets it opens)

| input | where | kind & options | saved to |
|---|---|---|---|
| **The idea** ("Say it or type your idea…") | `Screens/Scripts/Dock/ScriptsDock.swift:669,712-714`; dictation `:613` | Free text, max 200 characters (`IdeaPromptDraft.swift:16`) | `IdeaDraftService.draft`, kept on disk as `DockDraft` |
| **Format** ⌄ | `ScriptsDock.swift:578-594` → `Screens/CreateScript/Format/FormatSheet.swift` | Single choice. 9 tiles (`FormatChoice.gridTiles`): Auto, Talking head, Tutorial, Storytime, List/tips, Review, Myth vs fact, POV, Sponsored ad. "More formats": Hot take/reply, Launch, Apology | `IdeaDraftService.formatChoice` |
| **Create for** (platform) | `ScriptsDock.swift:565-574` → `ScriptDetail/Sheets/DestinationSheet.swift:28` (wired at `Main/MainView.swift:312-316`) | Single choice, 6 platforms, plus the Monetization toggle | `IdeaDraftService.platform` (this idea only) |
| ✦ Voice chip | `Shared/VoiceStyle/MyCueVoiceChip.swift:59` | Opens the voice questions or setup. It does not switch the voice on or off | — |
| Writer chip (Apple Intelligence / Ultra AI) | `Scripts/Dock/DockWriterChip.swift:41-42` (Debug only) | Menu, 2 options | `IdeaDraftService.engine` (kept between launches) |
| **Brand brief** (Sponsored ad) | `CreateScript/Brand/BrandBriefSheet.swift:49-58,155` | 6 text fields: Brand*, Product or offer*, Must say, Never say, Link, Code. "Save brand" toggle. Saved brands as chips | `IdeaDraftService.brand` (the dock's ad) and `BrandStore` (when saved). **Not stored on `Script`** (`Models/Script.swift:11-43`) |
| Answer a comment | `CreateScript/Answer/AnswerCommentSheet.swift:56,92,101,110` | Screenshot (Vision reads it on the iPhone), "@name", "What they asked", platform chips (6) | `ScriptComment` kept on the script; also the Logbook |
| Logbook capture | `Scripts/Logbook/LogbookView.swift:189` | Free text or held-mic dictation | `LogbookService` entries |
| Import a script | `CreateScript/ImportScriptSheet.swift:109` | Paste, scan or photos (up to 5) | `Script.text` (not AI) |
| Start from a format | `MainView.swift:295-302` | The format grid, without Auto | a blank draft |

##### Ideas (Find inspiration, and the idea shown on the dock)

| input | where | kind | saved to |
|---|---|---|---|
| Topic filter: "All my topics" / one topic / edit topics | `Scripts/Inspiration/InspirationFilterBar.swift:24,34,68` | Chips (the creator's topics) | `IdeaTopicFilter` (this session) |
| **Another idea** (↻ on the dock, the arrow in the sheet) | `FindInspirationSheet.swift:370-390`; `Dock/DockAnotherIdeaButton.swift` | Tap. Counts as a "pass" (-0.35) | `IdeaTaste` (`Models/IdeaTaste.swift:14-37`), kept on the iPhone |
| **Start with it** | `FindInspirationSheet.swift:400-407` | Tap. Counts as "selected" (+1.5). The idea's brief goes into the dock | `IdeaTaste`; `IdeaDraftService.brief` |
| **Draft it now** / Draft with Ultra AI | `FindInspirationSheet.swift:428,461` | Tap. A sent idea counts +3, a script written from it +4 | `IdeaTaste`; then a script |
| There is no explicit "not for me" or dislike | — | — | Passing is the only negative signal |

##### Script tools (on the script page)

| input | where | kind & options | saved to |
|---|---|---|---|
| Improve script | `ScriptDetail/Sheets/ImproveScriptSheet.swift:85-140`; list at `ScriptDetailViewModel.swift:184-186` | One tap per tool: In my voice, plus the format's own (Fit to time, More energy, Fix grammar, Translate (pick a language), Stronger CTA, Add disclosure, More human, Less defensive, Shorter & direct). **There is no field to type an instruction** | rewrites `Script.text` |
| AI selection bar (text selected) | `Page/AISelectionBar.swift:31` | Taps (Rewrite and others) | rewrites the passage |
| 3 new hooks → "Pick a new hook" / more | `Sheets/HooksSheet.swift:60,79` | Pick one of the suggestions | replaces the hook in `Script.text` |
| Length nudge: Record anyway / Make it shorter | `Page/LengthNudgeSheet.swift:27,36` | 2 buttons | runs Shorter, or nothing |
| Script type (after creation) | `Sheets/ScriptTypeSheet.swift:35`; `ScriptDetailsSheet.swift:34` | Single choice of `ScriptType` | `Script.type` |
| Create for (after creation) | `ScriptDetailsSheet.swift:26`; `ScriptDetailViewModel.swift:208-212` | Single choice | `Script.platform` |
| Script language | `Scripts/ContextMenu/ScriptActionsMenu.swift:43`; `ScriptActionsPopover.swift:100` | Menu | `Script.language` |
| Title, stage cue ("laugh") | `Page/ScriptPageHeader.swift:23`; `Page/ScriptPageView.swift:154` | Text | `Script.title`, `Script.text` |
| Fact check "I checked" | `Models/FactReview.swift` | Button | `Script.factReview`, kept on the iPhone (hides the reminder) |

##### Telling us something (feedback)

| input | where | where the answer goes |
|---|---|---|
| Sounds like me / Adjust | above | Stays on the iPhone, in the profile. **No telemetry** |
| Feature introduction: Try it / Not now / "Don't suggest this" | `Shared/Discovery/FeatureIntroSheet.swift:25`; `NotificationService+Discovery.swift:99-106` | Kept on the iPhone (`notInterested`; Settings › Personalize › Hidden suggestions brings it back). With Help improve Cue on, also an Analytics `cue_notification` event (campaign, category, outcome) |
| First voyage tip: act / close | `FirstVoyage/VoyageTipCard.swift` | Analytics `cue_voyage` event (step, place, outcome) when Help improve Cue is on (`TelemetryManager.swift:69-72`) |
| Voice question tip: Not now / dismiss / None of these | `VoiceQuestionTipHost.swift`; `VoiceQuestionScheduler.swift:161-187` | Kept on the iPhone (when to ask again). No telemetry |
| Ultra invitation: Try it / ✕ | `Shared/Ultra/UltraInviteCard.swift:64-84`; `UltraInviteService.swift:48` | Kept on the iPhone |
| Ultra consent: Allow / Not now | `UltraConsentSheet.swift:92-98` | Kept on the iPhone (`UltraConsentService`) |
| AI and editor failures | automatic, not asked (`AIFailureReport`, `EditorFailureReport`) | Crashlytics non-fatal (counts and conditions, never text) |
| Feedback form, problem report, rating, NPS, "why did it fail?" | **none** | — |

---

#### Part B: How each input that is not a CreatorProfile field is used

Engines: **dev** = on-device, **PCC** = Private Cloud Compute, **Ultra** = Ultra AI, **ideas** = the idea writer, **tools** = Improve, hooks and the selection bar.

| input | dev | PCC | Ultra | ideas | tools | verdict |
|---|---|---|---|---|---|---|
| Idea text | ✓ "The video: …" (`ScriptPromptBuilder.swift:196-208`) | ✓ same prompt + plan (`CloudDraft.swift:41`, `CloudPlan.swift:11`) | ✓ in the creator's exact words (`UltraPayload.swift:105-110`) | n/a | n/a | **USED** |
| Dock platform (Create for) | ✓ `PlatformGuide.line` (`ScriptPromptBuilder.swift:36-38`, `:145-149`) | ✓ `PCCScriptDirection.platformLine` | ✓ `Platform:` line (`UltraPayload.swift:66`) | ✗ the idea prompt has no platform (`ScriptPromptBuilder.swift:416-440`) | ✓ `RewriteContext.platform` | **USED** (not by ideas). Only for ideas sent from the dock (`ScriptStarter.swift:155`) |
| Format (Auto, Talking head, type) | ✓ `formatGuide` (`ScriptPromptBuilder.swift:212-217`) | ✓ (Auto lets PCC choose, `PCCScriptDirection.swift:13-31`) | ✓ `formatLine` (`UltraPayload.swift:80-85`) | ✗ (ideas are always "talking-head video ideas", `:424`) | ✓ `Script.type` → tool list and structure | **USED**. Dock only: Find inspiration and Logbook ideas are written on Auto |
| Serious format (Apology) | removes the voice and the brief (`ScriptPromptBuilder.swift:165-166`; factory `:40-45`) | same | `seriousRule` (`UltraPayload.swift:68`) | — | — | **USED** |
| Brand brief (6 fields) | ✓ `brandLines` (`ScriptPromptBuilder.swift:175,356-368`) | ✓ + PCC brand rule (`PCCScriptDirection.swift:70-72`) | ✓ (`UltraPayload.swift:56`) | — | ✗ **not on `Script`, not in `RewriteContext`** (`RewriteContext.swift:9-25`) | **PARTIAL**. Only sent with `format == .ad` (`ScriptRequestFactory.swift:57`). Lost when "Start from a format" → Ad or without AI (`MainView.swift:210-214`) |
| "Must say", Link, Code | ✓ also kept word for word (`ScriptRequest.preservedPhrases`, `:56-59`) | ✓ | ✓ | — | ✗ | **PARTIAL** (as above) |
| Length (`ScriptLength`, read from the idea or from a starter idea) | ✓ "Length: between X and Y words" when a length is set (`ScriptPromptBuilder.swift:157-160`) | ✓ | ✓ `UltraLength.required` | — | Fit to time uses the platform's ideal (`RewriteContext.idealRange`) | **USED**. No UI picker; it is read from the text only |
| Monetization goals (toggle in 3 places) | affects only the token cap and the length target on Auto (`ScriptRequestFactory.swift:39,75-81`). The Auto prompt calls the duration "informational" (`:162-163`) | ✗ on Auto (4,096 tokens, `ScriptAIService.swift:757`) | ✓ `UltraLength.ideal(range)` (`UltraLength.swift:23-30`) | — | ✓ Fit to time / length bar via `preset.idealRange` | **PARTIAL** (on Auto it barely changes Apple's scripts) |
| Script language (Settings) | ✓ language rule (`ScriptPromptBuilder.swift:45-47,138-139`) | ✓ | ✓ `languageLine` | ✗ ideas use the **interface** language (`AppServices.swift:237`; `IdeaSuggestionService.swift:506`) | ✓ (`Script.language` → `sourceLanguage`) | **PARTIAL** (ideas ignore it) |
| App (interface) language | fallback when nothing else says the language (`ScriptRequestFactory.swift:85-87`) | same | same | ✓ decides the ideas' language | — | **USED** |
| Write in my voice (Use my voice in drafts) | ✓ voice nil when off (`ScriptRequestFactory.swift:42-45`) | ✓ | ✓ | ✓ (`IdeaSuggestionService.swift:507`) | ✗ hooks and "In my voice" read the voice **even when off** (`ScriptDetailViewModel.swift:192-199`; `ScriptAIService.swift:450`) | **PARTIAL** (off is not respected by 3 new hooks) |
| Writer chip (Apple / Ultra) | — | — | ✓ decides the engine (`ScriptStarter.swift:163-174`) | — | ✗ touch-ups are always Apple's (`ScriptDetailViewModel.swift:180-183`) | **USED** for the dock and the Logbook. Comments always stay with Apple (`:163`). Debug only |
| Inspiration brief (the subject, angle and first line of "Start with it") | ✓ `briefOpeningRule` / `briefAngleRule` / `briefTopicRule`, but only the parts the text still holds (`ScriptRequestFactory.swift:59`) | ✓ | ✓ (`UltraPayload.swift:88-96`) | feeds taste (`generated`) | — | **USED** |
| Find inspiration taps (pass / select / send / generate) | — | — | — | ✓ `IdeaTaste.slots` picks the angles and topics asked (`IdeaSuggestionService.swift:517`) | — | **USED** (ideas only) |
| Topic filter | — | — | — | ✓ limits the topics asked (`IdeaSuggestionService.swift:511-514`) | — | **USED** (ideas only) |
| Logbook notes | ✓ when written ("Write") | ✓ | ✓ (dock writer) | ✓ `IdeaInspiration` (first 5 notes, `IdeaInspiration.swift:14-21`) | — | **USED** |
| Script titles | — | — | — | ✓ `IdeaInspiration` (last 4 titles) | ✓ the title is cleaned | **USED** (ideas) |
| Comment: author + text + platform | ✓ "Answer this comment from @x…" (`AnswerCommentViewModel.swift:134-137`); its language is read from the comment (`ScriptRequestFactory.swift:41`) | ✓ | ✗ always Apple (`ScriptStarter.swift:163`) | — | — | **PARTIAL** (never Ultra, by design) |
| Comment screenshot | Vision reads it into the text on the iPhone | — | — | — | — | **USED** (as the text) |
| Script type / Create for set after writing | — | — | — | — | ✓ tool list, structure, platform, ideal range | **USED** (tools only; nothing is rewritten) |
| Adjust (5 reasons, "This script only") | ✓ rewrite with the adjusted voice (`ScriptDetailViewModel+VoicePreview.swift:64-83`) | ✓ (Rewrite prefers PCC) | ✗ | — | ✓ | **USED** |
| "Sounds like me" → `approvedSamples` | ✓ | ✗ removed (`AIRequestPolicy.swift:19`) | ✗ | ✓ on-device (ideas prefer on-device) | ✓ only when a tool runs on-device | **PARTIAL** (lost on the main route, PCC) |
| Examples / imported excerpts | ✓ | ✗ (`AIRequestPolicy.swift:17-18`) | ✗ | ✓ on-device | same | **PARTIAL** (CreatorProfile field; the other agent traces it) |
| Onboarding topics → `niches`/`customTopics` | ✓ only when the idea is about them (`CreatorProfile.swift` `voice(inLanguage:idea:)` → `IdeaFocus`) | ✓ | ✓ (voice projection) | ✓ `ideaTopics` decide the ideas | — | **USED** |
| Onboarding platform → `defaultPlatform` | ✓ the default platform for every idea | ✓ | ✓ | ✗ | — | **USED** |
| Name, handle, photo | ✗ | ✗ | ✗ | ✗ | ✗ | **NOT FOR AI** (profile, share card, cover) |
| Auto-tag topics, Starry sky, Celebrations, Haptics, App icon, notification groups and routine, reminders | — | — | — | — | — | **NOT FOR AI** |
| Feature introduction "Don't suggest this" / voyage tip outcomes | — | — | — | — | — | **NOT FOR AI** → Analytics counts (Help improve Cue on) |
| Voice tip "None of these" / Not now | — | — | — | — | — | **NOT FOR AI** (only when to ask again) |
| Apple Intelligence switch (Settings) | turns off all of Apple's AI | same | — | same | same | **USED** (as a switch) |

---

#### Gaps

##### Asked but never used by the AI

1. **Brand brief typed in "Start from a format" → Sponsored ad**, or when Apple Intelligence can't draft the ad. The brief is thrown away and a blank ad draft opens (`MainView.swift:210-214`, `:295-299`). It survives only if "Save brand" was on.
2. **Brand brief after the ad is written.** It is not stored on `Script` and not in `RewriteContext`. So Stronger CTA, Add disclosure, Shorter, More human and In my voice rewrite an ad without "Never say", the approved claims, the link or the code. A rewrite could drop the code, or add a claim the brief forbids. I did not test this.
3. **Name and @handle.** Asked in Edit Profile, never sent to any AI. That may be intended, but a creator could expect it ("Hey, I'm Maya").
4. **The tip's answers that go to `customTags`.** "+ Something else" on role, audience, tone and formats is saved in `customTags`, not in `customRole`/`audienceNote` (`VoiceAnswers.swift:187`). The other agent should confirm whether tags reach every engine.
5. **`ScriptRequest.tone`** is always nil (`ScriptRequestFactory.swift:49`), so the "Tone:" line of the prompt (`ScriptPromptBuilder.swift:154`) is dead code. Nothing in the UI asks for it.

##### Used by one engine and not another

1. **The main script route (PCC) never sees the proof.** "Sounds like me" scripts, "Your edits", examples and imported excerpts are removed on PCC (`AIRequestPolicy.swift:15-21`), and scripts prefer PCC (`AIModelRoute.swift:28`). Ultra drops them too. They reach the AI only on-device: ideas, and scripts or tools when PCC falls back. Yet the app says "Cue learns from it" (`ScriptDetailViewModel+VoicePreview.swift:56`) and the voice meter gives them 20% (`VoiceField.swift:21`).
2. **Monetization goals and the usual length on Auto.** They shape Ultra's range and the on-device token cap. Apple's prompt calls the duration "informational", and on PCC `reach.length` is cleared (`AIRequestPolicy.swift:27`), so on PCC they change almost nothing.
3. **Ideas ignore Script language and platform.** They are written in the interface language and for no platform. A creator with an English interface and Portuguese scripts gets English ideas, then Portuguese scripts.
4. **Hooks ignore "Use my voice in drafts" being off**, because `rewriteContext.voice` is not gated (`ScriptDetailViewModel.swift:197`). "In my voice" uses the voice by design.
5. **Dock choices apply only to dock ideas.** Format, platform and brand are not used by "Draft it now" (Find inspiration), the Logbook or comments (`ScriptStarter.swift:155-158`, design decision A23). Format is always Auto there.
6. **Comments never go to Ultra**, even with Ultra chosen (`ScriptStarter.swift:163`).
7. **Adjust → Rewrite and touch-ups always run on Apple Intelligence**, even for a script Ultra wrote. "Without" (the version with no voice) is also asked of Apple (`ScriptDetailViewModel+VoicePreview.swift:37-48`). I am not sure this is wanted for Ultra scripts.

##### The same question asked twice, in different places

1. **Platform: 5 places, 3 places it is saved.** Onboarding ch. 2, Edit Profile "New scripts are made for" (`defaultPlatform`). The dock's "Create for" (this idea only). The script page "Create for" (`Script.platform`). My Cue Voice "Where you post" and the tip "Where do you post most?" (`reach.platforms`). The tip replaces a multi-choice list with a single answer (`VoiceAnswers.swift:128`).
2. **Monetization goals.** The same toggle in Edit Profile, Create for and Script details.
3. **Kind of creator.** Edit Profile (`CreatorTypePicker`), the My Cue Voice "I am" field, the setup step and the tip. Typed text goes to `customRole` in the first two and to `customTags` in the tip.
4. **Audience: two different lists for the same question.** The tip "Who's watching?" offers 4 options saved to `vocabulary`. The editor and setup offer 8 groups saved to `audienceGroup` (+ `audienceNote`). The same creator can give contradictory answers.
5. **Topics.** Onboarding ch. 1, My Cue Voice, the setup step "What do you create?", Settings › Personalize › Your topics (a link), and Find inspiration's edit button. All go to the same storage, which is fine, but the onboarding text says only "Cue uses them for your video ideas". They also turn on "Write in my voice" (`canWriteInMyVoice`).
6. **Tone vs Style.** "How do you talk on camera?" (Energetic, Warm & calm, Educational, Straight to the point) overlaps Energy (Calm/Balanced/High) and Words (Plain/Expert terms). Adjust edits both, plus the old `vocabulary`/`styles` (`VoiceAdjustment.swift:40-62`).
7. **Length.** My Cue Voice "Usual length" against a script length the creator can only type into the idea. There is no length chip.

##### Onboarding answers lost

None. Topics and platform are both saved (`OnboardingViewModel.swift:127-136`). A flight quit before 1.4 is asked again from the welcome.

##### Feedback that goes nowhere outside the iPhone

1. **"Sounds like me" and Adjust (the 5 reasons, this script or my profile).** Only the local profile changes. There is no count in telemetry, so the owner can't learn which reasons are common or how often the voice is approved.
2. **"Sounds like me" asks only once in the app's life.** `voiceApproved = true` hides the strip for every later script (`ScriptDetailViewModel+VoicePreview.swift:12-13,52`). After the first approval, the only learning left is "Your edits".
3. **There is no feedback, problem report, rating or "why didn't this work" anywhere.** After an AI or export failure the creator gets only a toast with "Try again". The automatic non-fatal reports carry no answer from the creator.
4. **"Don't suggest this" and first-voyage tips** reach Firebase as counts, but only with "Help improve Cue" on, which is off by default (`PrivacyPreferencesService.swift:34`).
5. **Ideas have no "not for me".** A pass ("Another idea") weighs only -0.35 and is the only negative signal (`IdeaTaste.swift:17`). A creator has no way to say "never this topic or angle".

##### Not sure / not checked

- I did not trace the `CreatorVoice` fields into `VoiceBriefBuilder` or the Ultra projection (the other agent covers them).
- `PCCDeliveryVoice` (it removes most of the profile on PCC) is a Debug evaluation behind `evaluatesDeliveryOnlyVoice` (`ScriptAIService+CloudProse.swift:45`). I did not check whether that flag is ever on by default in Debug.
- QuickEdit inputs (text to speech, captions, covers) were skipped: none of them feeds scripts.


---

## Anexo C · Pesquisa: nichos, voz, reclamações, necessidades por nicho

### Creator niches, voice and AI-script needs: research for "My Cue Voice"

Research date: 1 Nov 2026. Free sources only (web search, public pages, public forums, public APIs).

**Limits of this research (read first)**
- **Reddit could not be read.** reddit.com blocks this research agent's crawler (search filter refused the domain; direct fetch returns a block page). I did not get around the block. Forum quotes in §3 therefore come from the OpenAI Community forum, GitHub/Claude issue trackers, Hacker News (public Algolia API), Kagi feedback, creator newsletters (Substack/beehiiv), and press coverage. If the owner wants Reddit itself, it has to be read by hand in a browser (suggested searches at the end of §3).
- **Most category share numbers are paywalled** (Statista, HypeAuditor full report, Collabstr, AnyMind). Where only the ranking (not the %) is public, I say so. Where data is from before 2024, it is marked **[pre-2024]**.
- Many "top niches 2025/2026" lists are SEO/vendor blogs with no method. I used them only when a primary or semi-primary source agreed; they are marked **[vendor]**.

---

#### 1. Niche landscape

##### 1.1 Platform category lists (the "official" taxonomies)

| Source | Categories | Notes |
|---|---|---|
| **YouTube Data API `videoCategories`** (the categories a creator picks on upload) | Film & Animation, Autos & Vehicles, Music, Pets & Animals, Sports, Travel & Events, Gaming, People & Blogs, Comedy, Entertainment, News & Politics, Howto & Style, Education, Science & Technology, Nonprofits & Activism | 15 assignable categories; list varies slightly per region (`regionCode`). https://developers.google.com/youtube/v3/docs/videoCategories (list from the API; docs only describe the endpoint) |
| **Instagram professional account categories** | Hundreds (1000+) of business/creator labels: Digital creator, Video creator, Artist, Gamer, Writer, Blogger, Personal blog, Education, Fitness model, Public figure, plus every local-business type (Dentist, Real estate agent, Hair salon, Restaurant, Lawyer…) | No official public Meta list; third-party compilation: https://predis.ai/resources/instagram-business-categories/ ; Creator labels: https://info.bundle.social/blog/instagram-business-vs-creator-account . Key point: **Meta treats "local business type" as the creator's identity**, not a topic. |
| **LinkedIn** | Creator mode and its "Talks about" hashtags were **retired in 2024** (hashtags Feb 2024, toggle Mar 2024); topics are now inferred from posts | https://www.socialmediatoday.com/news/linkedins-removing-its-creator-mode-option/706585/ , https://contentin.io/glossary/creator-mode/ . So there is no LinkedIn topic list to copy any more. |
| **HypeAuditor categories** (used by brands to find creators) | Lifestyle, Beauty, Fashion, Music, Humor & Fun/Comedy, Family, Sports, Fitness, Food, Travel, Gaming, Art, Cars, Animals, Education, Finance, Medicine, Business, Science, Shows, Cinema & Actors, Modeling, Foreign affairs… | https://hypeauditor.com/instagram-category ; note "Modeling", "Cinema & Actors/Actresses", "Humor & Fun" and "Foreign affairs" exist as categories. |
| **Marketing Türkiye / CreatorDen monthly ranking (Turkey)** | Anne-Çocuk (parenting), Eğlence (entertainment), Kozmetik, Lifestyle, Spor, Yemek | https://marketingturkiye.com.tr/?p=180880 (Apr 2025). A local industry using just six buckets. |

##### 1.2 What is big or growing (numbers where they exist)

**Global / cross-market**
- **Creator count & market**: Goldman Sachs (Apr 2023, **[pre-2024]**) sized the creator economy at $250B, projected $480B by 2027; ~4% of creators are "professional" (>$100k/yr). https://www.goldmansachs.com/insights/articles/the-creator-economy-could-approach-half-a-trillion-dollars-by-2027
- **Instagram, by category**: Statista/HypeAuditor 2023: **Lifestyle 13.73%** of influencers was #1 (published Mar 2024). 2024 edition (published May 2025): **"Romantic relationships" #1, Entertainment #2** (shares paywalled). https://www.statista.com/statistics/1123051/instagram-influencers-share-world-category/
- **HypeAuditor State of Influencer Marketing 2025** (76M IG, 13.1M YouTube, 104M TikTok accounts; 2024 data): YouTube creators by category: **Music & Dance 16.5%, Animation 16.2%** top two. Instagram top content category: romantic relationships, then entertainment, then shopping & fashion. **Fastest-growing Instagram niches in 2024: medicine, healthy food, medical education.** Highest engagement: sports & outdoor. **Brazil has the most Instagram influencers: 3.8M (15.8% of global).** https://hypeauditor.com/state-of-influencer-marketing-2025/
- **TikTok 2022 [pre-2024]**: Lifestyle was the most crowded category (~18% of influencers). https://www.marketingmag.com.au/tech-data/the-state-of-influencer-marketing-hypeauditors-2022-report/
- **TikTok Shop**: Beauty & personal care was ~22% of 2025 US TikTok Shop GMV (~$2.49B) **[vendor, no source named]**. https://everything-pr.com/the-tiktok-pr-trend-forecast-2026-booktok-fintok-cleantok-retiretok
- **News creators**: Reuters Institute (Oct 2025, 24 countries): news creators matter most in big, social-video-heavy countries (India, Brazil, Indonesia, US); **85% of top news creators are men**; social video for news rose from 52% (2020) to 65% (2025) of people. https://reutersinstitute.politics.ox.ac.uk/news-creators-influencers-2025
- **LinkedIn video**: uploads +34% YoY (Later) / +36% YoY as of Jan 2025 (MediaPost); >20% per Microsoft earnings. Talking-head "thought leadership" video is the growth format. https://www.mediapost.com/publications/article/406435/linkedin-pushes-video-creation-with-new-ad-product.html , https://www.emarketer.com/content/linkedin-revenues-grow-12--paid-video-yields-strong-results
- **Health**: "3 in 5 adults use YouTube to learn about health topics" (cited by AIR Media-Tech, **[vendor]**). https://air.io/en/audience-growth/whos-growing-fastest-on-youtube-and-which-niches-are-hot-in-2025
- **AI/tech** is named as a top 2025 trending niche by many sources (YouTube MENA's 2025 year-end list names "AI" as a trending topic). https://blog.google/intl/en-mena/product-updates/connect-communicate/youtubes-20th-the-creators-topics-artists-defining-menas-content-map-in-2025/
- **UGC / content for brands**: Adobe Creators' Toolkit (Oct 2025, 16,000 creators): 86% use creative gen-AI. Kolsquare/NewtonX (783 European creators, 2025): 72% use AI regularly for ideation, scripting or analytics. https://news.adobe.com/news/downloads/pdfs/2025/10/10282025-inauguraladobecreatorstoolkitreport.pdf , https://www.kolsquare.com/en-gb/free-resources/voices-of-the-creator-economy-by-kolsquare-newtonx

**By market (the 20 languages)**

| Market | What is big | Source |
|---|---|---|
| **Brazil** | ~2M influencers (Mar 2025, +67% YoY; Influency.me). Most sought by brands (Oct 2025): **sports, games, lifestyle**. Strong **finance influencers** (InfoMoney ranks them). Only 22% monetize. Brazil = #1 country by Instagram influencers (3.8M, HypeAuditor). | https://www.meioemensagem.com.br/midia/brasil-ja-soma-2-milhoes-de-influenciadores , https://www.meioemensagem.com.br/midia/os-influenciadores-mais-procurados-por-marcas-e-agencias , https://startups.com.br/pesquisas/so-22-dos-creators-no-brasil-ganham-com-conteudo-diz-pesquisa/ |
| **India** | BCG (May 2025): genres consumed: **comedy 45%**, movies & daily soaps 35%, fashion 33%; short video dominant. 3.5–4.5M creators (Kofluence), 4.12M in 2025 with **66% outside metro cities** (ISB/Hashfame). Gaming among fastest growing (Qoruz). Regional-language creators dominate growth. | https://www.bcg.com/publications/2025/india-from-content-to-commerce-mapping-indias-creator-economy , https://kofluence.com/inside-kofluences-influencer-marketing-research-report-2025/ , https://prodcd.isb.edu/media/ykmjlwaj/india_creator_economy_interactive_report.html |
| **GCC / Arab world** | Qoruz GCC study: ~263k influencers in 2025 (150k in 2023). **Lifestyle & travel 31k→58k (+87%)**, **fashion & beauty 28k→53k**; **parenting** gaining. Saudi ≈40% of GCC market ($95.7M in 2025). TikTok >> Instagram (Saudi 2.7M TikTok vs 257k IG influencers; date unclear). UAE brands use **Indian-origin creators for South Asian expats** (audience = diaspora). | https://www.netinfluencer.com/gcc-influencer-market-jumps-75-percent-as-lifestyle-creators-lead-growth/ , https://www.arabianbusiness.com/industries/media/gccs-creator-economy-grows-75-in-two-years , https://influencermarketinghub.com/mena-influencer-marketing-report/ |
| **Indonesia** | Lifestyle and **news-adjacent** creators "hugely popular"; musicians and **comedians** have the biggest followings (Reuters 2025). TikTok share of SEA campaigns 28%→51% (2023→2025, AnyMind via Contentgrip). | https://reutersinstitute.politics.ox.ac.uk/news-creators-influencers/2025/Indonesia , https://www.contentgrip.com/influencer-marketing-indonesia/ |
| **Korea** | Gallup Korea 2024: favourite YouTubers led by **mukbang (Tzuyang 5.2%, Hamzy, Heebab) and travel (Pani Bottle)**. Statista: lifestyle 56.4%, hobby 44.2% of monetizing creators' genres (2022 content **[pre-2024]**). ASMR, toys/blind bags, vlog appear in 2025 lists. | https://www.koreatimes.co.kr/lifestyle/trends/20240621/tzuyang-named-koreas-favorite-youtuber , https://www.statista.com/statistics/1489264/south-korea-most-published-content-creation-genre/ |
| **Japan** | Beauty/makeup is a major YouTube category; **fandom ("oshikatsu")** is a mainstream behaviour (Statista surveys Dec 2024 & Mar 2024, numbers paywalled). Fashion influencer market ≈ $440M (IMARC 2025). | https://www.statista.com/statistics/1620504/japan-leading-fan-genres , https://www.japanbuzz.info/influencer-marketing-in-japan-statistics-and-facts/ |
| **Vietnam / Thailand** | Vietnam: **Entertainment & hobbies** and **Food & drink** in the top 3 categories; F&B fastest-growing **[2021 data, pre-2024]**; Facebook still leads in Vietnam. Thailand: IG = lifestyle/fashion/beauty; TikTok = short entertainment; beauty review KOLs historic core. KOC (affiliate seller-creators) is a big creator type. | https://ajmarketing.io/post/vietnam-influencer-marketing-complete-guide , https://anymindgroup.com/news/report/17144/ |
| **Turkey** | Industry buckets: parenting, entertainment, cosmetics, lifestyle, sports, food. Market 6.27B TL in 2024. Crypto and auto are separate ranked niches on Heepsy. | https://marketingturkiye.com.tr/?p=180880 , https://www.cnnturk.com/teknoloji/influencer-pazarlamasi-iab-connectte-masaya-yatirildi-2371074 |
| **China / Taiwan** | Since ~Oct 2025 platforms (Douyin, Bilibili, Weibo) must verify a **degree/licence for creators discussing medicine, law, finance and education** (fact-checkers say it enforces a 2022 livestreaming code rather than a new law). **Credential is a gate, not a nice-to-have.** | https://www.netinfluencer.com/china-now-requires-degrees-for-influencers-discussing-professional-topics/ , https://annielab.org/2025/11/26/analysis-no-new-chinese-law-on-influencers-livestream-regulations-took-effect-in-2022/ |
| **France / Germany / Italy / Spain / Nordics / NL** | No public category ranking found. France's 2023 influencer law (Loi 2023-451) bans or restricts promotion of cosmetic surgery and some financial products and requires "publicité"/"collaboration commerciale" labels. Germany: **"du" is the norm on Instagram/TikTok**, "Sie" still argued for in finance/B2B. | https://www.vie-publique.fr/node/288793 , https://t3n.de/news/?p=1091287 |

##### 1.3 Gaps vs Cue's 25 topics and 8 kinds

**Big niches that are missing or hidden**

1. **Comedy, skits & memes**: top consumed genre in India (45%), a YouTube category, a HypeAuditor category ("Humor & Fun"), biggest followings in Indonesia. Cue only has *Entertainer* as a kind and *Have a laugh* as a "why they watch", no topic. An entertainer who does skits has no topic to pick.
2. **Mental health & self-improvement**: huge on TikTok/Instagram and **claim-sensitive** (Guardian, May 2025: 52 of the top 100 #mentalhealthtips TikToks contained misinformation; JMIR 2025 1,000-video study). Today it hides under "Health & medicine" or "Relationships". Deserves its own topic because the AI must behave differently (no diagnosis, no "you have ADHD if…"). https://gigazine.net/gsc_news/en/20250602-tiktok-metal-health-misinformation , https://www.jmir.org/2025/1/e64225/PDF
3. **Investing & crypto** (as distinct from budgeting): FinTok, Brazil finfluencers, Turkey crypto. Regulated differently from "personal finance" tips (UK FCA FG24/1, India SEBI, France). Could be a subtopic, but the AI needs to know because the rules change.
4. **Law & rights ("LawTok")**: lawyers are a real creator type (bar rules on advertising, disclaimers on case results, risk of creating a client relationship by answering comments). https://nysba.org/?p=129983 , https://www.zuckerman.com/blog/six-ethical-pitfalls-avoid-lawyer-tiktok/
5. **Science, history & curiosities / school subjects**: YouTube "Education" and "Science & Technology". "Study & exams" is about *being a student*, not about explaining physics or history; "Tech & AI" is narrower than science.
6. **Pop culture & fandom (anime, K-pop, celebrities, series)**: Japan's oshikatsu, Korea, Thailand/Indonesia; Instagram "Entertainment" #2. Cue's "Books, film & TV" misses anime, K-pop, celebrity news and fan culture.
7. **Travel (all of it)**: "Budget travel" is too narrow. GCC lifestyle & travel is the fastest-growing bucket; Korea's #5 favourite YouTuber is a traveller; YouTube category "Travel & Events". Budget should be a subtopic.
8. **Outdoors, nature & gardening / plants**: highest engagement category on Instagram is "sports & outdoor" (HypeAuditor 2025). Gardening only fits under Home & DIY today.
9. **Crafts & hobbies (knitting, painting, models, collecting, toys/blind bags)**: Korea "hobby" 44%; Vietnam "Entertainment & hobbies". "Music & arts" and "Home & DIY" each catch half.
10. **Sustainability & environment / causes**: there is a *Community or cause* kind and *Raise awareness* goal, but no topic. YouTube has "Nonprofits & Activism".
11. **Local business by type** (restaurant, salon/barber, clinic/dentist, gym/personal trainer, real estate agent, shop): Instagram literally makes this the account category. NAR 2025: **75% of Realtors use social media; social media is their #1 lead-generating technology (39%)**. https://www.nar.realtor/newsroom/realtors-embrace-ai-digital-tools-to-enhance-client-service-nar-survey-finds
12. **B2B / SaaS / careers on LinkedIn (founder-led, "thought leadership")**: "Business & marketing" + "Productivity & career" cover it partly; the voice is different (proof, POV, no slang).
13. **Astrology, tarot & manifestation**: big in Brazil, Turkey, Thailand, Indonesia, US Gen Z. Today only "Faith & spirituality", which reads as religion. *Uncertain: I found no hard number in 2025 sources; flagged from general market knowledge.*
14. **Weddings & events, luxury, modeling**: HypeAuditor categories; better as subtopics (Fashion → luxury; Lifestyle → weddings).
15. **Cooking vs eating out**: "Food & cooking" misses **food reviews / mukbang / street food / restaurant tours** (Korea's #1 genre, Vietnam/Thailand F&B).
16. **Seniors/"RetireTok", creator-economy ("content about making content")**: smaller but growing; better as audiences/subtopics.

**Cue topics that are probably low-use or mis-framed**
- *Daily routines*: overlaps with the kind *Lifestyle & personal* and with format *Day in the life*. It is a format, not a subject.
- *Budget travel*: too narrow (rename *Travel*).
- *Languages*: real niche (language teachers are a big group on TikTok/YouTube) but small; keep.
- *Study & exams*: very big in India, Korea, Vietnam, Indonesia (exam culture); keep but separate from "explaining a subject".
- *Cars & motorcycles*, *Real estate*, *Pets*: each is a YouTube/HypeAuditor/Instagram category; keep.

**Where kinds and topics are confused**
- *My own business* is a kind, but what the AI needs is the **business type** (restaurant vs SaaS) + city + offer; Instagram treats that as the category. *Real estate* is both a topic (market commentary) and a business (agent). *Health & medicine* is both a topic and a credential (nurse, doctor).
- *Expert/coach/pro* vs *Teacher or explainer*: coaches and agencies don't separate these; the distinction that matters is **"do I sell my expertise (clients/courses) or do I teach for reach/ads?"**, which the *goals* already capture. Merge or reword.
- *Lifestyle & personal* (kind) vs *Daily routines* (topic) vs *Day in the life* (format): three answers for one idea.
- *Entertainer* (kind) has no topic and *Have a laugh* (why they watch) duplicates it.
- *News & commentary* (kind) + *News & current events* (topic): duplicates; kind could become "Commentator / opinion" (covers reaction, pop culture commentary too).
- *Content for brands* (kind) = UGC creators; their real need is the **brief** (product, claims allowed, mandatory disclosure), not a voice profile topic.

---

#### 2. What defines a talking-head creator's voice and content (coaches, agencies, creators)

Consensus elements, with what Cue does today:

| Element | What coaches say | Cue today | Verdict |
|---|---|---|---|
| **Content pillars** | 3–5 recurring themes under one umbrella; "fewer than 3 feels repetitive, more than 5 dilutes focus"; map pillar × format in a **content matrix** (Justin Welsh). Example fitness coach: workout tips, nutrition, mindset, client transformations. https://buffer.com/resources/content-pillars-for-social-media/ , https://linkedinpreview.com/blog/linkedin-content-pillars , https://skillselion.com/skills/charlie947/social-media-skills/content-matrix | Topics (≤3) + subtopics: close. | Rename/frame "topics" as **pillars** and let one pillar be *proof/behind the scenes/personal*, not only subjects. Ideas should rotate across pillars. |
| **Audience avatar** | Specific person + pain point + level + where they live; coaching worksheets build pillars from the "ideal client profile with pain points". https://tandemcoach.co/coaching-tools/content-pillars-worksheet/ | Audience (8), level, why they watch. | Good. **Missing: their problem/pain in their words, and their country/region** (needed for language variant, currency, laws). |
| **Point of view / beliefs** | "You don't need a personal brand, you need a point of view"; define 3–4 beliefs others in the field don't say out loud. https://storycraft855.substack.com/p/you-dont-need-a-personal-brand-you | Not asked. | **Add**: "What do you believe that others in your field get wrong?" Strongest antidote to generic AI. |
| **Personal stories / origin story** | Origin story is "something AI can't replicate". https://amerilife-marketing-mentors-podcast.castos.com/episodes/your-niche-your-story | Writing examples only. | **Add a small story bank** (2–5 true stories: how I started, a failure, a client win, a turning point). |
| **Proof & credibility** | Buyers "want evidence"; results, numbers, years, clients, credentials. https://the-creative-catalyst-dk.beehiiv.com/p/the-100k-mo-personal-branding-framework-steal-this | Credential (e.g. "Registered nurse"). | **Extend**: real results/numbers the AI may use (so it never invents them, see §3). |
| **Offer** | Coaches tie content to one offer (product, service, booking, lead magnet, keyword DM). | Goal "Sell something / Win clients", ending "Link in bio". | **Add**: what you sell, what the link/keyword is, booking method, price range (optional). Without it the AI writes vague CTAs. |
| **Hooks taxonomy** | Hooks state the topic in 1–2 s; contrast hooks, curiosity loops, re-hooks mid-video (Kallaway). https://wayfindknow.substack.com/p/irresistible-hook , https://www.castmagic.io/podcast/rhythm-hooks-and-a-billion-views-kane-kallaways-short-form-video-content-secrets | 7 openings. | Good list. **Add contrarian/"unpopular opinion"**, **"result first/proof"**, **"call out the viewer" ("If you're a nurse…")**. Asking the creator to *pick one favourite* opening is low value: coaches say rotate; better "openings I never want". |
| **CTA** | **One CTA per video**; don't stack subscribe+share+buy. https://influenceflow.io/resources/the-ultimate-guide-to-an-effective-call-to-action-for-videos-2026-edition/ , https://kompozy.io/glossary/cta | 6 endings. | Good. **Add "Comment KEYWORD and I'll DM you"** (very common lead CTA), **"Share with someone who…"**, **"Watch part 2 / series"**, **"Book / visit us"** (local). Enforce one CTA. |
| **Series / recurring formats** | "One tip a day", "mistake of the week" make consistency easier; YouTube launched **Shorts series (seasons/episodes)** Sept 2026. https://techcrunch.com/2026/09/23/youtubes-new-short-series-feature-brings-episodic-viewing-to-shorts/ , https://frameo.ai/blog/youtube-shorts-boost-engagement/ | Not asked. | **Add**: "Do you have a recurring series? Name + format". Ideas can then propose episodes. |
| **Posting cadence & platform** | Cadence and platform drive length and CTA (YouTube "subscribe", TikTok "follow", LinkedIn no slang). | Platform chosen per script. | Cadence is low value for the writer; platform per script is right. |
| **Writing samples** | Voice tools (Jasper) learn from **3–5 samples, up to 8**, ~300+ words each. https://help.jasper.ai/hc/en-us/articles/18618693085339-Brand-Voice | Examples of own writing. | Keep; prefer **transcripts of their own videos** (spoken) over written posts. |
| **Tone, energy, humor, sentence length, words** | Coaches describe voice by POV + stories + phrasing, rarely by abstract sliders. | 8 tones + energy + length + words + humor + swearing. | **Partly low value**: energy and sentence length are better inferred from transcripts; keep humor, swearing, words (plain/slang/expert), catchphrases and "never write" (high value). |

**Missing questions that matter specifically for a 20-language app (high value)**
- **Form of address & register**: tu/você (pt-BR vs pt-PT), tú/usted/vos/vosotros, tu/vous, du/Sie, keigo vs tameguchi (Japanese), 존댓말/반말 (Korean), Hindi aap/tum, Arabic MSA vs dialect (Egyptian, Gulf, Levantine, Maghrebi). German social media defaults to "du" but finance/B2B still argue for "Sie" (t3n). Japanese viewers react to tameguchi either way (ABEMA example). https://t3n.de/news/?p=1091287 , https://times.abema.tv/articles/-/10091911
- **Creator's grammatical gender** for first-person (pt/es/fr/it/ar/hi/he-like agreement: "estou cansado/cansada", "je suis prêt/prête"): models default to masculine when ambiguous (ConGA 2026: "both models default to masculine realisations when ambiguity is present"). https://arxiv.org/pdf/2603.17962
- **Country/region of creator and audience**: currency, laws, units, examples, slang, dialect.

---

#### 3. What creators complain about with AI-written scripts

(Short quotes; links. Reddit unavailable, see Limits.)

1. **Sounds generic / not their voice**
   - AI scripts "sound like they were written for a LinkedIn keynote"; generic content "could have been written for anyone" (paraphrase of creator newsletter). https://imanoubou.substack.com/p/7-ways-i-make-my-ai-scripts-sound
   - "ChatGPT writes blog posts, not video scripts"; it "dumps all information upfront, killing suspense". https://app.thejuicehq.com/content/haFTbP3z1Z1YJnq872Wg5WbW
   - AI "defaults to a slightly formal register. Most YouTube audiences prefer casual conversation." https://youtubeniches.com/blog/chatgpt-youtube-scripts
   - Flat rhythm: "similar sentence lengths and predictable structures", repeating what the viewer already understands. https://www.mytrendsphere.com/resources/why-your-youtube-script-sounds-like-ai
   - Audience side: content *perceived* as AI is **48% less trustworthy, 57% less authentic, 60% lower emotional connection** (Raptive, 3,000 US adults, Jul 2025), even when humans wrote it. https://raptive.com/blog/the-ai-stink-is-real-and-its-costing-brands/
2. **Cringe / same hooks**
   - "Everyone is using the same AI-generated hooks, and that's why they flop"; they "try too hard to be clickbait". https://theunpolishedfounder.beehiiv.com/p/chatgpt-hooks-suck-but
   - Recurring tics: contrast framing ("it's not X, it's Y"), closing offer lines, generic praise openers. https://coachway.io/articles/how-to-make-chatgpt-not-sound-like-ai/
   - Em dashes as an AI tell: "I will even remind ChatGPT not to use it and it will agree, and then do it immediately again." (OpenAI Community) https://community.openai.com/t/please-make-it-stop-using-em-dashes/1103789 . (OpenAI said it fixed instruction-following for this in Nov 2025.)
3. **Wrong length**
   - "She'll accurately count the words of the text, apologize for the inaccurate length, and proceed to produce another too short text." (OpenAI Community) https://community.openai.com/t/what-do-you-have-to-do-for-gtp4-to-generate-text-in-the-required-lenght/613014
   - Custom GPT ignored a ~1,830-word target for a 10-min video. https://community.openai.com/t/chat-does-not-comply-with-the-number-of-words-requirement/711568
   - "Write 400 words for a '60-second' video and you've actually written a three-minute one"; consensus 130–150 words/min (English). https://www.eesel.ai/blog/can-ai-write-video-scripts
4. **Invented facts / over-reliance**
   - Hank Green (Aug 2026) paused channels after fans flagged chatbot-style phrasing; he wrote "I have been relying too heavily on AI as a research aid" and "I'm mortified that I have let so many people down." https://fortune.com/2026/08/04/did-hank-green-use-ai-chatgpt-youtube-social-media/
   - Health/mental-health content is where invented or overgeneralised claims do most harm (52/100 top #mentalhealthtips with misinformation, Guardian 2025). https://gigazine.net/gsc_news/en/20250602-tiktok-metal-health-misinformation
   - Platform risk: YouTube renamed "repetitious" to **"inauthentic content"** (15 Jul 2025): mass-produced videos "with generic voiceovers, visuals, or scripts" can lose monetization. https://www.socialmediatoday.com/news/youtube-clarifies-monetization-update-inauthentic-repeated-content/752892/
5. **Regional language / wrong variant**
   - "ChatGPT is generating text based on Argentine Spanish, which is very annoying for the rest of Spanish speakers." (OpenAI Community) https://community.openai.com/t/spanish-mexico-international-is-not-working/1225785
   - Claude defaulted to voseo "from first turn, ignoring neutral-Spanish" rules; "Only ~45M [of ~400M Latin American speakers] are in the voseo region." https://claudeissues.com/issue/52568-model-opus-4-7-defaults-to-argentine-spanish-voseo-from-first-turn-ignoring-neut ; reverts "mid-session even after being explicitly corrected": https://claudeissues.com/issue/77377-model-reverts-to-argentine-voseo-mid-session-even-after-being-explicitly-correct
   - A project found Rioplatense words in its own prompt ("acordate, ¿Seguimos?, dale") made models switch to "vos". **Lesson for Cue: example text inside prompts leaks dialect.** https://newreleases.io/project/github/Gentleman-Programming/gentle-ai/release/v1.18.4
   - pt-PT users get pt-BR: "Kagi News translates to pt-BR even when pt-PT selected." https://kagifeedback.org/d/10119-kagi-news-translates-to-pt-br-even-when-pt-pt-selected
6. **Wrong formality (T/V)**
   - Research: default outputs used the informal form; prompts can steer to formal (2022). Formal control is harder: models "often avoid second person forms entirely" when asked to be formal. https://arxiv.org/pdf/2202.11822 , https://arxiv.org/abs/2205.04022 . Without control, output "can be perceived as rude or jarring" (Amazon Science). https://www.amazon.science/blog/controlling-formality-in-machine-translation **[2022, pre-2024 but still the main literature]**
7. **Gendered grammar**
   - OpenAI Community thread on Spanish masculine self-reference ("Estoy encantado"). https://community.openai.com/t/chatgpt-gender-bias-training-needed/673195
   - Models "default to masculine realisations when ambiguity is present" (2026). https://arxiv.org/pdf/2603.17962 ; Spanish ChatGPT/Mistral show "higher gender bias concerning language inclusiveness" (Lovelace Project 2024). https://repositorio.comillas.edu/items/89bdedba-4374-4f3a-9474-9ebf78c773d6
8. **Too many CTAs**: no forum quote found; coach consensus is one CTA (§2). *Uncertain as a complaint; certain as advice.*

To read Reddit by hand (owner, in a browser): r/NewTubers "chatgpt script", r/TikTokCreators "AI script", r/youtubers "sounds like AI", r/portugal "ChatGPT brasileiro", r/argentina or r/mexico "ChatGPT voseo", r/LinkedInTips "AI posts".

---

#### 4. Niche-specific needs: the 2–4 facts an AI needs per niche

Synthesis from the sources above plus regulator/coach material. Items marked ⚖ are legal/regulatory and should change what the AI is allowed to say.

| Niche | Facts the AI needs | Why / source |
|---|---|---|
| **Fitness & wellness** | Training style (strength, running, yoga, home, calisthenics); audience level & goal (fat loss, muscle, mobility, 40+); credential (PT, physio, none); body/food claims they refuse to make | Pillars example (tips, nutrition, mindset, transformations): Buffer. ⚖ health/weight-loss claims need "competent and reliable scientific evidence" (FTC; Teami $15.2M case). https://www.thefashionlaw.com/the-federal-trade-commission-just-published-influencer-specific-guidance-on-endorsement-disclosures/ |
| **Health, medicine & mental health** | Exact credential & specialty (and licence number where shown, e.g. Brazil CRM, India); country; claim limits (no diagnosis, no dosage, before/after rules); whether they sell a service | ⚖ Brazil CFM Res. 2.336/2023 (in force Mar 2024): before/after allowed only for education with criteria, profile must show required data. https://legismap.com.br/conteudos/artigos-e-noticias/publicidade-medica-veja-o-que-foi-liberado-e-o-que-ainda-e-proibido ⚖ India ASCI: qualification needed (and disclosed) when giving technical health/finance advice (Addendum 2, Apr 2025). https://www.newslaundry.com/2025/04/28/asci-tweaks-guidelines-for-health-business-influencers-for-public-service-generic-messages ⚖ China: credential verification for medicine/law/finance/education. |
| **Personal finance, investing, crypto** | **Country & currency**; licensed or not (SEBI RIA/RA, CVM, FCA-authorised…); products they talk about (budgeting vs stocks vs crypto); disclaimer they must use | ⚖ UK FCA FG24/1: each post must comply standalone; unapproved promotion can be a criminal offence (up to 2 years). https://cms.law/en/gbr/legal-updates/fca-publishes-finalised-guidance-on-financial-promotions-on-social-media ⚖ India: advice only if SEBI-registered, show registration number. https://www.exchange4media.com/advertising-news/asci-new-rules-finfluencers-can-now-offer-investment-advice-only-if-registered-with-sebi-129252.html ⚖ France 2023 law restricts some financial products. |
| **Real estate** | City/neighbourhood & market (buy, rent, luxury, first-time buyers); role (agent, investor, broker); licence/brokerage disclosure; lead path (DM, link, open house) | NAR 2025: social = #1 lead source (39%). US fair-housing wording rules apply (no "perfect for young families"-type steering) *(general knowledge; not sourced here)*. |
| **Local business (restaurant, salon, clinic, gym, shop)** | Business type; **city/neighbourhood**; the offer (signature item, price, promo, hours); booking/visit method (link, WhatsApp, phone, walk-in) | Local Reels advice: show what makes you distinct, menus/hours, behind the scenes, end with call/visit. https://mojo-app.com/instagram-reels/10-proven-reels-ideas-for-local-businesses/ |
| **Law** | Jurisdiction (country/state) and practice area; disclaimer for case results; "not legal advice / no client relationship" line; whether comment replies are allowed | ⚖ NYSBA: disclaimer whenever a post covers a past case result. https://nysba.org/?p=129983 ; risk of creating a client relationship by answering comments (Zuckerman). |
| **Beauty & skincare** | Skin type/tone & hair type they speak to; budget level (drugstore vs luxury); cosmetic-procedure stance; brand-deal disclosure | Beauty ≈22% of US TikTok Shop GMV **[vendor]**. ⚖ France bans promoting cosmetic surgery by influencers. |
| **Food** | Cooking vs eating out/reviews/mukbang; diet & cuisine (halal, vegetarian, regional); kitchen level/time; city (for reviews) | Korea #1 genre = mukbang/eating shows; Vietnam F&B top 3. |
| **Parenting & family** | Kids' ages; stance on showing children; family type/country (school system) | GCC and Turkey rank parenting as a top category. (Child-privacy rules on showing minors exist in France, 2023 law on child influencers.) |
| **Tech & AI** | Audience (consumers vs developers vs business); platforms/ecosystem (iPhone vs Android); affiliate/sponsor disclosure | AI = top trending topic 2025 (YouTube MENA). |
| **Content for brands (UGC)** | Brand, product, **allowed claims**, mandatory disclosure wording (#ad / "publicité" / "Werbung"), deliverable length & hook count | ⚖ FTC: platform "Paid partnership" label doesn't replace an in-content disclosure; France requires "publicité"/"collaboration commerciale". |
| **News & commentary** | Country/region focus; political stance or "neutral"; sourcing rule (link sources, no unverified numbers) | Reuters 2025: 47% see influencers as top source of false info. |
| **Education / study & exams** | Exam/system (ENEM, JEE/NEET, Suneung, gaokao, SAT, Abitur…); subject; student level | China credential rule for education creators; exam culture in India/Korea/Vietnam. |

---

#### 5. Table: Cue's lists vs the market

##### Kinds of creator (8)

| Cue today | Action | Proposal |
|---|---|---|
| Lifestyle & personal | Keep | "Lifestyle & vlogs" (then drop topic *Daily routines*) |
| Entertainer | Keep + rename | "Entertainer (comedy, skits)" and add topic *Comedy & skits* |
| Expert / coach / pro | Merge | with Teacher → "Expert, coach or teacher" (credential field stays) |
| Teacher or explainer | Merge | (above) |
| My own business | Split | "Local business (shop, salon, clinic, restaurant…)" + "Founder / online business" |
| Content for brands | Keep + rename | "UGC / content for brands"; ask for brief + disclosure |
| News & commentary | Rename | "Commentator (news, pop culture, opinions)" |
| Community or cause | Keep | |
| — | Add | "Licensed professional" is covered by credential; add *Artist / musician / performer* (promotes own work) |

##### Topics (25)

| Cue topic | Action | Note |
|---|---|---|
| Fitness & wellness | Keep | |
| Food & cooking | Rename | "Food (cooking, reviews, eating out)" |
| Beauty & skincare | Keep | subtopics: hair, nails, makeup, procedures |
| Fashion & style | Keep | subtopic luxury, modest fashion |
| Personal finance | Keep + subtopic | "Investing & crypto" as subtopic flagged ⚖ |
| Tech & AI | Keep | |
| Budget travel | Rename | "Travel" (budget as subtopic) |
| Productivity & career | Keep | subtopic LinkedIn/B2B, job search |
| Parenting & family | Keep | |
| Daily routines | Remove/merge | duplicate of kind Lifestyle + format Day in the life |
| Gaming | Keep | |
| Real estate | Keep | |
| Music & arts | Keep | |
| Pets & animals | Keep | |
| Home & DIY | Keep + subtopic | gardening & plants |
| Health & medicine | Keep | |
| Business & marketing | Keep | subtopic SaaS/B2B, creator economy |
| Study & exams | Keep | |
| Relationships | Keep | top Instagram category |
| Faith & spirituality | Rename | "Faith, spirituality & astrology" |
| News & current events | Keep | |
| Cars & motorcycles | Keep | |
| Sports | Keep | football first in most markets |
| Languages | Keep | |
| Books, film & TV | Rename/expand | "Books, film, TV & anime" (or split fandom out) |
| — | **Add** | Comedy & skits |
| — | **Add** | Mental health & self-improvement |
| — | **Add** | Science, history & curiosities |
| — | **Add** | Pop culture, celebrities & fandom (K-pop, anime) |
| — | **Add** | Law & rights |
| — | **Add** | Outdoors & nature |
| — | **Add** | Crafts & hobbies |
| — | **Add** | Sustainability & causes |
| — | Optional add | Weddings & events; Local food & places (city guides) |

##### Audience (8)

| Cue | Action | Note |
|---|---|---|
| Teenagers, Students, Young adults, Parents, Working professionals, Business owners, Local community, People who already know the field | Keep | |
| — | Add | "People 50+" (RetireTok), "Expats / diaspora" (GCC, Europe), "Other creators" |
| — | **Add field** | Audience country/region + language variant + form of address |
| — | **Add field** | "Their biggest problem, in their words" |

##### Goals (7)
Keep all; **add "Get brand deals"** (most common creator money goal) and "Get bookings or visits" (local) or fold the latter into *Win clients*.

##### Formats (11), openings (7), endings (6)
- Formats: keep; **add** Skit/sketch, Reply to a comment, Hot take / unpopular opinion, Comparison (X vs Y), GRWM / get ready with me, Case study / client result, Series episode. *Daily routines* topic folds into *Day in the life*.
- Openings: keep; **add** Contrarian / unpopular opinion, Result first, Call out the viewer ("If you're a …"). Change the question from "favourite" to "never use".
- Endings: keep; **add** "Comment a keyword, I'll DM you", "Share with someone who…", "Part 2 / follow the series", "Book or visit us". Enforce one CTA.

##### Voice fields
- **Add**: point of view/beliefs, story bank, proof/results the AI may cite, offer + link/keyword, recurring series, creator's grammatical gender, form of address, country/region, compliance (licence, disclaimer line, claims to avoid).
- **Lower priority** (infer from transcripts instead of asking): energy, sentence length; 8 tones overlap with humor/words.

---

#### Sources (main)

Platform taxonomies: https://developers.google.com/youtube/v3/docs/videoCategories · https://predis.ai/resources/instagram-business-categories/ · https://info.bundle.social/blog/instagram-business-vs-creator-account · https://hypeauditor.com/instagram-category · https://www.socialmediatoday.com/news/linkedins-removing-its-creator-mode-option/706585/

Market data: https://hypeauditor.com/state-of-influencer-marketing-2025/ · https://www.statista.com/statistics/1123051/instagram-influencers-share-world-category/ · https://www.goldmansachs.com/insights/articles/the-creator-economy-could-approach-half-a-trillion-dollars-by-2027 · https://www.bcg.com/publications/2025/india-from-content-to-commerce-mapping-indias-creator-economy · https://kofluence.com/inside-kofluences-influencer-marketing-research-report-2025/ · https://prodcd.isb.edu/media/ykmjlwaj/india_creator_economy_interactive_report.html · https://www.meioemensagem.com.br/midia/brasil-ja-soma-2-milhoes-de-influenciadores · https://www.meioemensagem.com.br/midia/os-influenciadores-mais-procurados-por-marcas-e-agencias · https://startups.com.br/pesquisas/so-22-dos-creators-no-brasil-ganham-com-conteudo-diz-pesquisa/ · https://www.netinfluencer.com/gcc-influencer-market-jumps-75-percent-as-lifestyle-creators-lead-growth/ · https://influencermarketinghub.com/mena-influencer-marketing-report/ · https://reutersinstitute.politics.ox.ac.uk/news-creators-influencers-2025 · https://reutersinstitute.politics.ox.ac.uk/news-creators-influencers/2025/Indonesia · https://www.contentgrip.com/influencer-marketing-indonesia/ · https://www.koreatimes.co.kr/lifestyle/trends/20240621/tzuyang-named-koreas-favorite-youtuber · https://www.statista.com/statistics/1489264/south-korea-most-published-content-creation-genre/ · https://www.statista.com/statistics/1620504/japan-leading-fan-genres · https://ajmarketing.io/post/vietnam-influencer-marketing-complete-guide · https://marketingturkiye.com.tr/?p=180880 · https://www.mediapost.com/publications/article/406435/linkedin-pushes-video-creation-with-new-ad-product.html · https://www.nar.realtor/newsroom/realtors-embrace-ai-digital-tools-to-enhance-client-service-nar-survey-finds · https://blog.google/intl/en-mena/product-updates/connect-communicate/youtubes-20th-the-creators-topics-artists-defining-menas-content-map-in-2025/ · https://news.adobe.com/news/downloads/pdfs/2025/10/10282025-inauguraladobecreatorstoolkitreport.pdf · https://www.kolsquare.com/en-gb/free-resources/voices-of-the-creator-economy-by-kolsquare-newtonx

Coaching: https://buffer.com/resources/content-pillars-for-social-media/ · https://tandemcoach.co/coaching-tools/content-pillars-worksheet/ · https://wayfindknow.substack.com/p/irresistible-hook · https://www.castmagic.io/podcast/rhythm-hooks-and-a-billion-views-kane-kallaways-short-form-video-content-secrets · https://storycraft855.substack.com/p/you-dont-need-a-personal-brand-you · https://influenceflow.io/resources/the-ultimate-guide-to-an-effective-call-to-action-for-videos-2026-edition/ · https://techcrunch.com/2026/09/23/youtubes-new-short-series-feature-brings-episodic-viewing-to-shorts/ · https://help.jasper.ai/hc/en-us/articles/18618693085339-Brand-Voice · https://t3n.de/news/?p=1091287 · https://times.abema.tv/articles/-/10091911

AI complaints: https://community.openai.com/t/spanish-mexico-international-is-not-working/1225785 · https://claudeissues.com/issue/52568-model-opus-4-7-defaults-to-argentine-spanish-voseo-from-first-turn-ignoring-neut · https://claudeissues.com/issue/77377-model-reverts-to-argentine-voseo-mid-session-even-after-being-explicitly-correct · https://newreleases.io/project/github/Gentleman-Programming/gentle-ai/release/v1.18.4 · https://kagifeedback.org/d/10119-kagi-news-translates-to-pt-br-even-when-pt-pt-selected · https://community.openai.com/t/what-do-you-have-to-do-for-gtp4-to-generate-text-in-the-required-lenght/613014 · https://community.openai.com/t/chat-does-not-comply-with-the-number-of-words-requirement/711568 · https://community.openai.com/t/please-make-it-stop-using-em-dashes/1103789 · https://community.openai.com/t/chatgpt-gender-bias-training-needed/673195 · https://imanoubou.substack.com/p/7-ways-i-make-my-ai-scripts-sound · https://theunpolishedfounder.beehiiv.com/p/chatgpt-hooks-suck-but · https://coachway.io/articles/how-to-make-chatgpt-not-sound-like-ai/ · https://www.mytrendsphere.com/resources/why-your-youtube-script-sounds-like-ai · https://app.thejuicehq.com/content/haFTbP3z1Z1YJnq872Wg5WbW · https://youtubeniches.com/blog/chatgpt-youtube-scripts · https://www.eesel.ai/blog/can-ai-write-video-scripts · https://raptive.com/blog/the-ai-stink-is-real-and-its-costing-brands/ · https://fortune.com/2026/08/04/did-hank-green-use-ai-chatgpt-youtube-social-media/ · https://www.socialmediatoday.com/news/youtube-clarifies-monetization-update-inauthentic-repeated-content/752892/ · https://arxiv.org/pdf/2202.11822 · https://arxiv.org/abs/2205.04022 · https://www.amazon.science/blog/controlling-formality-in-machine-translation · https://arxiv.org/pdf/2603.17962 · https://repositorio.comillas.edu/items/89bdedba-4374-4f3a-9474-9ebf78c773d6

Regulation / niche needs: https://www.netinfluencer.com/china-now-requires-degrees-for-influencers-discussing-professional-topics/ · https://annielab.org/2025/11/26/analysis-no-new-chinese-law-on-influencers-livestream-regulations-took-effect-in-2022/ · https://www.newslaundry.com/2025/04/28/asci-tweaks-guidelines-for-health-business-influencers-for-public-service-generic-messages · https://www.exchange4media.com/advertising-news/asci-new-rules-finfluencers-can-now-offer-investment-advice-only-if-registered-with-sebi-129252.html · https://cms.law/en/gbr/legal-updates/fca-publishes-finalised-guidance-on-financial-promotions-on-social-media · https://legismap.com.br/conteudos/artigos-e-noticias/publicidade-medica-veja-o-que-foi-liberado-e-o-que-ainda-e-proibido · https://www.vie-publique.fr/node/288793 · https://www.thefashionlaw.com/the-federal-trade-commission-just-published-influencer-specific-guidance-on-endorsement-disclosures/ · https://nysba.org/?p=129983 · https://www.zuckerman.com/blog/six-ethical-pitfalls-avoid-lawyer-tiktok/ · https://gigazine.net/gsc_news/en/20250602-tiktok-metal-health-misinformation · https://www.jmir.org/2025/1/e64225/PDF · https://mojo-app.com/instagram-reels/10-proven-reels-ideas-for-local-businesses/


---

## Anexo D · Pesquisa: concorrentes, retorno, gênero gramatical e formalidade

### Cue Studio research: how voice tools learn, grammatical gender and formality, and better inputs

Research date: 2026-11-01. Sources were free only: web search, vendor help centres and docs, Apple/Android developer docs, Microsoft localization style guides (PDF text pulled with PDFKit), news and law-firm commentary.

**Limits on this research:**
- **Reddit.** The fetch tool is blocked from reddit.com, so I could not read threads directly. Reddit opinion here comes second-hand, through blogs and the OpenAI community forum.
- **Missing help pages.** Several vendors have no public help page for their voice features (TubeBuddy, Buffer, Linktree, InVideo, VEED). Those rows say "not documented" rather than guessing.
- **Pre-2024 sources** are marked *(older)*.
- **Uncertain claims** are marked *(unverified)*.

---

#### 1. Competitors and adjacent tools: what they ask and how they learn

##### 1.1 Summary table

| Tool | Profile fields | Writing samples | Feedback loop | What Cue lacks compared with it |
|---|---|---|---|---|
| **Jasper** (Brand Voice + Jasper IQ) | Voice: name, description (editable, "down to every detail"), excerpts. Separate **Knowledge** (products and services, facts). **Audiences** (ICP → audience → persona; up to 3–4 audiences attached to one generation). Admin-only **Style guide** (custom terms, punctuation rules). | URLs, files or pasted text, 3–5 strong samples (help centre). Third parties say about 1,000 words or more. | Shows the **same content with and without the voice** side by side. You add or remove extracted excerpts. A "flag off-brand copy" check runs before publishing. You can set a workspace default voice. | A facts/offer store, several audiences, a with/without preview, an editable "what was extracted" list. |
| **Copy.ai** (Brand Voice + Infobase) | Brand Voice is built from samples. **Infobase** is a tagged store of facts (brand guidelines, product details, value propositions), called with "@" or a hashtag. | Paste or upload. A Copy.ai guide recommends 3,000+ words. | Pick a voice from a dropdown on each generation. No documented learning loop. | A facts store referenced by tag, and several named voices (for example one per format). |
| **Writer.com** | Voice is **generated from examples** or set by **manual trait selection** or a written description. Writer says examples "consistently generate better" output than descriptions. | At least 300 words, 500+ recommended, up to 8 boxes. "Use examples from a single content type." | **Test step inside setup:** try sample prompts and see the output beside them. Review and adjust extracted attributes; a refresh button regenerates the adjectives after you change examples. Voices are being converted to "skills" (help page updated Aug 2026). | A "try it before saving" step, and attributes the creator can see and edit after extraction. |
| **ChatGPT** | Personalization: **Base style and tone** (Default, Professional, Friendly, Candid, Quirky, Efficient, Nerdy, Cynical; list per third parties). Custom instructions ("what should ChatGPT know about you" / "how should it respond"; older form: name, occupation, traits). **Memory** (saved memories + reference chat history). | No dedicated sample slot; people paste text into chats or instructions. | Thumbs up/down on each reply. Occasional **"Which response do you prefer?"** A/B pairs. Memory is learned implicitly from chats and can be viewed and deleted. | Implicit memory the creator can see and edit; the A/B pair (but see the backlash in §2). |
| **Claude** (Styles) | Presets plus Custom style. "Add writing example" (upload PDF/DOC/TXT or paste) **or** "Describe style instead". Claude generates a style the user can edit. | Upload or paste. A third party says Claude rewrites the examples into its own guideline *(unverified)*. | Switch style per chat; edit the style text. | Naming one profile per format ("Shorts", "Tutorial"). |
| **Gemini Gems** | Free-text instructions in four parts: **Persona, Task, Context, Format**. "Use Gemini to re-write instructions" button. **Knowledge** files. | Uploaded files. | None besides editing the Gem; a commentator says the rewrite button adds generic advice and drops your rules. | Reference files. The Persona/Task/Context/Format split is a good mental model. |
| **Notion AI** (Notion Agent) | Personalization: instruction pages; you can keep several and switch between them. **Memories** are on by default, private, and can be viewed and turned off in Settings › Notion AI › Memory. | Workspace pages. | Implicit memories the user can see. | Visible, editable learned memories. |
| **Grammarly** (now Superhuman) | **Voice profile detected automatically from your writing** and "updates continuously as you write". Short messages and long documents count as separate styles. A newer custom-voice feature takes samples. | Passive (everything you write) plus optional samples. | You can **remove individual style elements** from the profile. | Passive learning from what the person actually writes or says; separate profiles for short and long content. |
| **Taplio** (LinkedIn) | AI voice/style settings where you paste samples *(third-party)*. | Paste only, no bulk import *(competitor claim, unverified)*. | Directory claims it "learns from posts and edits" *(unverified)*. | Not much to copy; reviews call its output generic. |
| **AuthoredUp** (LinkedIn) | **Coauthor** (closed beta, v6.7) "learns from your existing posts"; full LinkedIn history import (used for analytics). | Imports the person's own post history. | You write and it suggests; you keep or drop each suggestion. | Importing the person's published history. |
| **Typefully / Hypefury** (X) | Typefully: AI suggests ideas "drawn from your own content"; extra instructions typed in the command bar. Hypefury: viral template library, no voice AI *(2026 comparison)*. | Your own posts (Typefully). | None documented. | — |
| **Spotter Studio** (YouTube) | Connects to the YouTube channel; Brainstorm uses "your channel's history" plus Outliers (high performers across YouTube). Needs at least one public video over 1 minute. | Channel data, not scripts. | Pin ideas; Outliers feed into brainstorm. | **Real performance data** (which of the creator's videos did well). |
| **vidIQ** | AI Coach uses "your channel context and performance signals". The script writer has tone settings; a "channel voice" claim comes from a directory *(unverified)*. | Connected channel. | Chat-style follow-ups. | Performance data from a connected channel. |
| **Subscribr** (YouTube scripts, adjacent) | Channel settings: link a channel; the voice profile is **regenerated from the channel's content** when re-linked. Defaults for target audience, preferred video length, format type. | The channel's videos and transcripts. | Re-link to refresh. | Voice built from the creator's spoken transcripts; length and format defaults. |
| **TubeBuddy** | Not documented: no voice profile found; title/CTR tools only. | — | — | — |
| **Captions** (now under mirage.app) | Script inputs: description, template, keywords, **tone of voice**, **length**, language (9 languages). Guide: edit the draft "until it fits your voice"; formal scripts sound stiff on camera. | None. | None documented. | Nothing on voice; Cue is ahead here. Captions has a length input. |
| **CapCut** (AI writer / script to video) | Category (8 presets), video name, **highlights**, **length**. "Improve" and "Expand" on drafts; several drafts generated. | None. | Pick among drafts; Improve/Expand. | Several drafts to choose from (implicit preference signal). |
| **InVideo AI** | Not documented: "long-term memory" for visual consistency *(third-party)*; nothing on writing voice. | — | — | — |
| **Opus Clip** | Brand templates (colours, fonts, logo); "brand vocabulary" on pricing pages, mechanism undocumented. | — | Reprompt clipping. | A custom vocabulary list (names, product terms) for spelling and captions. |
| **Descript** (Underlord) | **Underlord Instructions** (Settings › AI Models), saved and reused across projects: pacing, captions, brand rules *(third-party summaries)*. Brand Studio (Business plan): layouts, colours, fonts, "language tools". | — | Saved instructions persist across projects. | Standing editing preferences. |
| **VEED** | Not documented (searches found nothing official). | — | — | — |
| **BIGVU** (teleprompter + AI) | Preset tones (persuasive, neutral, friendly, professional, witty, marketing, funny). **"My personal style"**: drop in previous scripts; the AI "suggests your brand tone"; you **review and change** it, then save. | Previous scripts or pasted text. | Review the extracted tone before saving. | Showing the creator the analysed tone (Cue's Import my writing measures, but check whether it shows the result as something editable). |
| **Teleprompter Premium / PromptSmart** | No AI script writer found in their listings (Opus review, Nov 2025). Other "Teleprompter: AI…" apps have generic AI writers. | — | — | Nothing; Cue is ahead. |
| **Hootsuite** (OwlyWriter / OwlyGPT) | Tone picker. **Brand voice tied to a social profile** that "integrate[s] the voice and tone of previous posts" (OwlyGPT beta, June 2025). Output goes through approval workflows. | That profile's past posts. | Approvals. | A voice per platform or account. |
| **Later** (Caption Writer) | Generate or rephrase in a different tone. Marketing says it learns your tone "based on the language used in your previous posts". English-only beta. | Previous posts. | Rephrase. | — |
| **Buffer** (AI Assistant) | Not documented in a public help page. | — | — | — |
| **Metricool** | **Brand settings › AI Configuration**: an overall writing style plus **separate instructions per social network**; per brand; generating the instructions costs no credits. | — | — | **Per-platform instructions** (TikTok vs YouTube vs LinkedIn). |
| **Linktree** | Not documented: AI chat gives profile advice and link suggestions; no caption or voice writer found. | — | — | — |
| **Canva** (Magic Write + Brand Voice) | Brand Kit › **Brand voice**: free-text guidelines up to about 500 words; set by owners, admins and brand designers. "Generate in this brand voice" / "Apply brand voice". | None (text description only). | Edit the guidelines when output is off. | — (Cue's guided questions are richer than Canva's single text box.) |

##### 1.2 What stands out against Cue's My Cue Voice

Cue's question set (kind of creator, credential, I/we, topics, audience, goals, tone, energy, sentence length, words, humour, swearing, formats, openings, endings, catchphrases, never-write rules, examples, Import my writing, Sounds like me, Adjust) is already **broader than any competitor's structured profile**. The gaps are in **how the profile is checked and updated**, not in what it asks:

1. **A "see it before you save it" check** (Writer's test prompts, Jasper's with/without voice view, BIGVU's review of the analysed tone). After setup or an import, show one short script in the creator's voice next to a generic one.
2. **An editable "what Cue learned" list** (Grammarly lets you remove style elements, Writer's adjective chips, Jasper's excerpts, ChatGPT and Notion memories). Today Cue's learned signals (Adjust, Sounds like me, Import measurements) are not shown to the creator as plain-language rules they can delete.
3. **Learning from the creator's own spoken output** (Subscribr's channel transcripts, Grammarly's passive profile, AuthoredUp's history import). Cue records the creator. Its takes, and what they actually said compared with the script, are a richer sample than pasted captions (see §2).
4. **A facts/offer store** (Jasper Knowledge, Copy.ai Infobase, Gemini Knowledge). See §4.
5. **Per-platform or per-format overrides** (Metricool per network, Hootsuite per profile, Copy.ai's advice to keep one voice per content type, Writer's "single content type"). Cue asks about formats but keeps one voice.
6. **Performance data** (Spotter Studio, vidIQ). Which past videos worked.
7. **Length**: Captions, CapCut and Subscribr all expose a length input. Cue deliberately has none (natural pace); just note that competitors treat it as a basic control.

---

#### 2. Feedback loops that work

##### 2.1 What the evidence says

- **Explicit feedback is rare.** Practitioner write-ups put explicit feedback (thumbs) at about **1–3% of interactions**, sometimes **under 1%**, with thumbs-up clicked less than thumbs-down. Those who click are a biased sample (koji.so 2026; tianpan.co 2026; vendor and blog sources, indicative only). Building learning on thumbs alone gives very little signal.
- **Implicit signals carry most of the information.** The usual ones are edit rate, regenerate, copy without editing, and abandonment. "Copy without editing is the cleanest signal"; "regeneration is a diagnostic signal, not an acceptance signal" (tianpan.co; Amplitude's docs capture copy, regenerate and abandonment automatically).
- **Learning from edits works, and stays readable.** Microsoft Research's **PRELUDE/CIPHER** (Gao et al., NeurIPS 2024) learns a **plain-language description of the user's hidden preferences from their edits**. It finds the most similar past contexts, combines their preferences into the prompt (no fine-tuning), and gets the **lowest edit-distance cost** of the methods compared. A secondary review reports 31% less editing on summaries and 73% less on emails *(numbers from a third-party summary)*. Because the learned preference is text, "the user can view and modify" it. This maps directly onto Cue's prompt-based on-device and PCC models.
- **Passive, continuous profiles work for Grammarly.** "Detects your unique voice profile from your writing and updates the profile continuously", separates short from long content, and lets the user remove elements.
- **Reason-coded regenerate** (Cue's Adjust chips) is the common pattern: BIGVU tone rewrites, Later rephrase-in-tone, CapCut Improve/Expand. Nobody documents remembering the reason across scripts; that is where Cue could go further (turn repeated Adjust picks into a standing rule the creator can see).
- **Use A/B "which do you prefer" sparingly.** On the OpenAI forum, users call ChatGPT's pairs a "stupid feature", "A/B testing disguised as a feature", "forced to choose between two bad choices". They interrupt focused work and sensitive conversations, and some users regenerate or delete the chat to avoid them (community.openai.com threads 394873, 1044881, 1264022, 1138224). Lesson: offer A/B only when the creator **asks** for options ("Show me two openings"), never as an interruption, and always with "neither".
- **Setup-time testing beats later nagging.** Writer and Jasper put the test inside setup. No vendor documents scheduled "re-asks". The closest is Subscribr re-generating the profile when you re-link the channel.

##### 2.2 What creators and marketers say about brand-voice features (second-hand; Reddit not readable)

- Without setup the output is "cookie-cutter", like free tools. A blog says Jasper's voice takes "3–5 rounds before it's usable" and drifts toward generic tone after about 1,500 words *(blog claims)*.
- r/SEO, as quoted by a review site: "Jasper is crap"; the price only makes sense for teams.
- r/DigitalMarketing: "no tool gets perfect brand tone automatically… training it with examples… and refining".
- The consistent advice: **examples beat adjectives** (Writer says so officially), **do/don't pairs**, and plan to edit once or twice. Creators who script videos recommend pasting **2–5 transcripts of past videos** (spoken, not written) as the sample.
- Taplio is criticised as generic "without significant effort" (competitor source).

##### 2.3 Feedback loop ideas for Cue, from the evidence

1. **The performance as the edit signal.** Voice Following already aligns speech to the script. The **difference between what was written and what was said** in the take the creator keeps (words swapped, sentences skipped, ad-libs added) is exactly CIPHER's "user edit", and costs the creator nothing. Turn it into plain-language preferences on device ("says 'a gente', not 'nós'", "drops the closing question"), shown in an editable list.
2. **Edits in the editor**, the same way (Cue already has per-line drafts).
3. **Strong implicit outcomes**: recorded or not, number of takes, exported or shared, regenerated, or abandoned after reading.
4. **Explicit, but light**: keep Sounds like me / Adjust. Add an optional "Why?" only after a regenerate, and turn **the same reason picked twice** into a proposed rule ("Make this a rule: shorter sentences?"). That gives one confirmation instead of a rating form.
5. **How often to ask**: no study gives a number. Practice suggests asking only at a natural pause (after export), at most about once a week, never during recording, and only when there is an actual change to confirm.

---

#### 3. Grammatical gender and formality: how to ask well

##### 3.1 Apple: Terms of Address and automatic grammar agreement

- **User setting.** Settings › General › Language & Region › **Term of Address**: **feminine, masculine or neutral**, plus a **"Share with All Apps"** switch ("so all apps personalize how they address you"; "available for some primary languages, for example, Spanish"). Source: Apple iPad/Mac user guides; the iPhone guide was not retrieved but describes the same setting. A forum reply says you can only set it while a strongly gendered language is primary, and it persists if you switch back to English *(forum, unverified)*.
- **Languages, by year:**
  - **2021 (iOS 15):** automatic agreement for **Spanish and English** (WWDC21 10109). The Spanish "Bienvenido/a" example was driven by the Term of Address.
  - **2022 (iOS 16):** French, Italian and Brazilian Portuguese joined Spanish for personalised terms of address.
  - **2023 (iOS 17):** grammatical agreement added for **European Portuguese and German** (WWDC23 10153).
  - **Since 2023:** I found no newer list.
  - **For Cue's languages, this means** es, fr, it, pt-BR, pt-PT and de are covered (plus English pronouns). **Arabic and Hindi are not on any list I found** *(unverified for iOS 18–27)*.
- **Can an app read the user's choice? Yes, with consent built in.**
  - **`Morphology.user`** (iOS 15+): "The addressing preferences of the current user. If the user hasn't specified preferences, **or chose not to share them with this app**, `isUnspecified` is true." It exposes `grammaticalGender` (feminine, masculine, neuter). The value doesn't change during the process's lifetime.
  - **`TermOfAddress.currentUser`** (iOS 18+): "the term of address that should be used for addressing the user". It is opaque (it only compares equal to another `currentUser`), meant to be passed to `LocalizationOptions.concepts = [.termsOfAddress([.currentUser])]`, not read as a value.
  - **`TermOfAddress`** (iOS 17+): `.feminine`, `.masculine`, `.neutral`, and `.localized(language:pronouns:)` for custom pronouns; "not all terms of address exist in all languages".
  - **Inflection markup**: `^[…](inflect: true)` in localized strings, `referentConcept` / `agreementConcept`, `InflectionRule`, and an "inflection alternative" (fallback text used "if we do not know or the user prefers not to specify").
  - A 2023 forum thread (740368) asking whether third-party apps can read the setting was never answered by Apple. The documentation above answers it: `Morphology.user` is the read path, and the "Share with All Apps" switch is the consent.
- **What this means for Cue:**
  - **UI strings.** Cue's interface text can use `inflect` with the system Term of Address at no cost.
  - **AI scripts.** A script is free text from a model, so inflection markup doesn't apply. What Cue can do is **pre-fill** its own question from `Morphology.user.grammaticalGender` when it is shared, and pass "the speaker is feminine/masculine/prefers neutral" into the prompt.
  - **No setting.** When the setting is unspecified, ask Cue's own question (only in the languages that need it).
  - **Which gender.** The system setting is about **how the device addresses the user** (second person). Cue needs **the speaker's own gender** (first person: "estou animada", "je suis prête", "मैं तैयार हूँ/तैयारी हूँ…"). These usually match but are conceptually different, so phrase Cue's question around how the creator talks about themselves.

##### 3.2 Android

- **Android 14 Grammatical Inflection API** (`GrammaticalInflectionManager`): per-app; the app asks the user (setup flow or settings) and calls `setRequestedApplicationGrammaticalGender(FEMININE | MASCULINE | NEUTER)`. Resources live in `values-fr-feminine/…`, with the default (neutral) string as fallback. The API is about "the person who's viewing the UI, not who's being talked about"; Google's example is French "Vous êtes abonnée/abonné à…". Calling it recreates the Activity unless `configChanges="grammaticalGender"` is declared.
- **Android 15 (API 35)**: `getSystemGrammaticalGender()` exists, but **only privileged preloaded apps** can read it (`READ_SYSTEM_GRAMMATICAL_GENDER`). Ordinary apps must ask themselves. Apple is more open here, through the share switch.
- **Google Translate** (Dec 2018, expanded 2020): shows **both feminine and masculine** translations for ambiguous queries (EN→es/fr/it/pt single words; tr→en sentences); the 2020 rewrite reached 97% precision *(older)*. Its pattern of offering both forms instead of guessing is a useful fallback for Cue: when gender is unknown, write neutrally or let the creator flip it.

##### 3.3 Neutral language: what style guides recommend

- **Microsoft pt-BR style guide** (§3.1 "Avoid gender bias"): use collective or neutral nouns (a humanidade, a classe política, o corpo docente, **estudantes** not alunos, a coordenação), invariable pronouns ("ninguém que"), restructure (passive, imperative, infinitive), plural generalisations (pessoas, indivíduos), address with **você**, use lhe(s) (formal) / te (informal), and **"Don't use constructions like ele(a)"**. Neopronouns such as "elu" or "-e" endings are **not** recommended; they are not mentioned at all.
- **Microsoft fr-FR style guide** (§3, aligned with Microsoft France, Sept 2022): "degender" the text where possible; epicene words (élève, membre, fonctionnaire); collective nouns ("la direction" instead of "les directeurs et les directrices"); feminise job titles for real people (autrice/auteure). **For real people, use their pronouns "whether it's il, elle, iel or another pronoun."** For mixed groups, doublets **in alphabetical order** ("Bonjour à tous et à toutes"). The guide does not mention the point médian (·). The 2017 Word "inclusive" option suggested doublets, not points *(older)*.
- **RAE (Spanish)**: rejects "todes", "todxs", "tod@s" and generic doublets; "x" is "innecesario e impronunciable"; the generic masculine is the unmarked form. Use and acceptance of "-e" vary by country and community.
- **Brazilian Portuguese in practice**: "no accepted standard yet… different speakers may choose different gender-neutral forms" (UWM). Proton's localisers stay neutral but use gendered forms "if remaining neutral goes against the writing best practices". Inclusive guides list "elu", "amigues" as non-binary forms (Warwick).
- **Arabic**: second person and verbs are gendered (أنتَ/أنتِ); the default is masculine. Discourse's localisers keep defaults neutral and add variants only where needed, "Hebrew and Arabic are probably the main cases". Research system: *User-Aware Arabic Gender Rewriter* (Alhafni, Obeid, Habash 2023) rewrites first- **and** second-person gender to the user's preference.
- **Hindi**: first-person verbs agree with the **speaker's** gender (मैं करता हूँ / करती हूँ; जा रहा / रही हूँ; गया / गई). Transitive perfective verbs agree with the object instead. Plural/respectful forms ("kar rahe hain") avoid marking when addressing others. **A Hindi script written in the first person cannot be gender-neutral by rephrasing alone**; it needs the speaker's gender.
- **Thai**: the polite particle depends on **the speaker's gender, not the listener's** (ครับ khráp / ค่ะ khâ, ค่ะ/คะ for statements vs questions); first-person pronouns are gendered (ผม phǒm male; ดิฉัน/ฉัน female). Scripts need the speaker's form.
- **Japanese**: first-person pronouns carry gender and register: watashi (neutral or polite), boku and ore (masculine), atashi (feminine) (UCLA paper). Research on YouTubers' pronoun use is "thin" (same paper); creators mix plain and polite forms (Hikakin study, abstract only). Better to ask "Which word do you use for 'I'?" with the four options plus "I avoid it" than to ask for gender.
- **Other Cue languages, from general linguistic knowledge (not sourced in this round)**:
  - **Korean, Chinese, Indonesian, Vietnamese, Turkish, English and the Nordic languages**: no grammatical gender in self-reference. Vietnamese and Korean pick pronouns and speech level by relationship, not gender.
  - **German**: self-reference is not gendered, but nouns are ("ich bin Lehrer/Lehrerin").
  - **Dutch and Swedish**: the issue is limited to nouns.

##### 3.4 UX best practice for asking

- **Ask only when the language needs it, and only for grammar.**
  - **Must ask** (first-person scripts are wrong without it): **es, pt, fr, it, ar, hi, th**.
  - **Better to ask** (nouns only): de, nl.
  - **Ask the "I" word**: ja.
  - **Never ask**: en, zh, ko, id, vi, tr, sv, da, nb.
  - Ask again if the creator adds a script language that needs it.
- **Wording.** Frame it as *grammar*, not identity. Never say "sex" or "gender identity". Example: "How should scripts talk about you? Cue writes 'estou pronta' or 'estou pronto'": **Feminine forms / Masculine forms / Neutral wording where possible / Not now**. Show a live one-line example in the creator's language. GOV.UK patterns: explain what the question is for and what happens to the answer; make it optional. Practitioner guidance: separate "what should we call you" from "how do you identify"; "if you can't explain why, don't ask".
- **The neutral option must be honest.** In Romance languages "neutral" means **rephrasing** (Microsoft's approach), not neopronouns. Say so: "Cue avoids gendered words where it can; some sentences may sound less natural." In Hindi and Thai a neutral first person barely exists, so offer neutral where possible, then fall back to a form the creator picks per script.
- **Groups ("we").** When the profile says "we", ask the group's makeup **only if needed**: "All women / All men / Mixed or prefer neutral". In es/pt/fr/it the standard mixed plural is masculine ("estamos prontos"); offer neutral rephrasing ("estamos com tudo pronto") as an option. In French, doublets in alphabetical order for the audience ("à toutes et à tous").
- **Audience plural.** A separate, optional question about how to address viewers: "pessoal/gente" vs "todos vocês"; neutral collective nouns ("quem está assistindo", "a comunidade") per Microsoft's collective-noun approach.
- **Pre-fill from the system** when `Morphology.user` is shared, with "Change" next to it. Never infer gender from the name, voice or face.
- **When to ask.** Inside My Cue Voice (optional section), or **just in time** the first time the creator writes in a language that needs it ("One quick grammar question for Spanish scripts"). Don't ask in onboarding for English speakers.

##### 3.5 Privacy (GDPR / LGPD)

- **GDPR**: gender is **not** an Article 9 special category in itself, but **data minimisation (Art. 5(1)(c)) applies strictly**. The **CJEU ruled in *Mousse v CNIL & SNCF Connect* (C-394/23, 9 Jan 2025)** that forcing "Monsieur/Madame" to personalise communication "based on gender identity" was **not necessary** for the contract. Necessity is judged strictly; a legitimate-interest basis must be disclosed and balanced against the right to object. For Cue this argues for an **optional** question with a clear purpose (grammar of scripts), a "not now" choice, and no use for marketing or analytics.
- **LGPD**: "gênero" is **not on the sensitive-data list** (Art. 5 II: racial or ethnic origin, religion, politics, health, sex life, genetic and biometric data). Scholars argue **gender identity** should count as sensitive (via "vida sexual" or a broad reading); others disagree. **No ANPD position found.** The cautious choice is to treat it as if sensitive: explicit, specific consent and purpose limitation.
- **Practical pattern**: keep the value **on device** (as Cue's profile already is). Send it to PCC/Gemini only as a grammar instruction ("use feminine first-person agreement"), never as "the user is a woman". Don't send it to Firebase (Cue's telemetry rule already forbids text). Delete it with the profile. *(Corrected in §11.2, item 5: Apple's label asks separately whether data is collected (sent off the device and accessible beyond real-time servicing), linked to identity, and for what purpose; identifiability decides only the second.)* Note that the Ultra AI disclosure would need to say the grammar setting is sent to Google with the request.

##### 3.6 Formality toward the audience

Hard data is thin; much of this rests on general sociolinguistic knowledge and should be checked with native reviewers (Cue already did an AI l10n review in October).

| Language | Options | What creators and brands seem to use | Evidence |
|---|---|---|---|
| **German** | du / Sie; ihr (plural) | "On German social channels such as Facebook or TikTok, 'du' has now prevailed." Yet only 17% of 2,046 insurance customers said they explicitly like *duzen* in ads and social (9% among broker clients). Sie is still expected in finance and B2B. | Sirius Campus survey via versicherungsbote.de; YouGov DE (23% always use "du" among users) |
| **Spanish** | tú / usted / vos; vosotros (Spain) vs ustedes (LatAm) | Spain: tuteo almost universal. LatAm: usted still used even informally in places (Colombia; Mérida, Venezuela). Voseo in Argentina, Uruguay and parts of Central America. Brands in Guatemala juggle vos, tú and usted. | Academic and blog sources, low quality |
| **Portuguese** | pt-BR você (tu regional) / o senhor; pt-PT tu / você / omitted subject | pt-BR creators: você/vocês, "gente/pessoal". pt-PT: Marktest's 2024 survey has a question on brands' preferred "tom de tratamento", but the results were not reachable. My understanding *(unverified)*: young pt-PT creators use "tu", and "você" can sound distant or rude, so drop the subject or use "vocês". | Marktest 2024 brochure (topic only) |
| **French** | tu / vous | "vous" is both plural and formal, so addressing the audience as "vous" is natural; "tu" to the single viewer is common on TikTok *(no study found)*. | — |
| **Japanese** | です/ます vs plain | YouTubers mix polite and plain forms (Hikakin study). Polite is the safe default for an open audience. | Indonesian journal abstract; learner sources |
| **Korean** | 합니다 / 해요 / 반말 | 해요체 is "the most versatile" everyday polite level; 합니다 is broadcast and formal; 반말 is close friends. Speech level shows respect to the **audience**. | Learner guides (migaku, seoulstart) |
| **Hindi** | आप / तुम / तू; "aap log", "doston" | *(unverified)* creators open with "doston" and use आप for viewers. | — |
| **Dutch** | je/jij / u | *(unverified)* "je" is the norm for brands and creators. | — |
| **Turkish** | sen / siz | *(unverified)* "siz" (plural or polite) to the audience. | — |
| **Indonesian** | kamu / Anda / kalian / "guys" | *(unverified)* casual kamu/kalian on TikTok; Anda feels formal or ad-like. | — |
| **Vietnamese** | mình–các bạn and other kinship pronouns | *(unverified)* "mình / các bạn" is the creator default. | — |
| **Thai** | ครับ/ค่ะ politeness particles | Particles follow the speaker's gender. | §3.3 |
| **Swedish, Danish, Norwegian, English, Chinese** | du; you; 你/您, 大家 | No real choice in the Nordic languages (du is universal); zh 您 only for very formal content. | — |

**Recommendation**:
- **One question, asked only where it matters:** de, es, pt, fr, it, ja, ko, hi, tr, nl, id, vi, zh, ar.
- **Shape of the question:** "How do you talk to your viewers?" with two or three options shown as **real example sentences** in that language (for example de: "Hey, schön, dass du da bist" / "Willkommen, schön, dass Sie da sind").
- **Spanish and Portuguese:** add the regional variant (voseo; pt-PT vs pt-BR).
- **Default** to the informal option for creators. Pre-select the formal one when the kind of creator or credential suggests it (finance, law, health professional, B2B).
- **Never ask:** sv, da, nb, en.

---

#### 4. Other inputs that would make scripts much better

From the tools above and creator advice:

1. **A bank of true stories and facts.** The "story bank" (Asian Efficiency): real stories tagged by topic, pulled from recordings, queried when a post needs an example, "to stop AI from making up stories". IONOS's ghostwriting guide: AI must not present experiences the user never had. This fits the owner's rule (01/11) that drafts may imagine first-person scenes but never invent numbers, studies or credentials. A story bank lets Cue **prefer the creator's real stories** over imagined ones. Ideal source: lines the creator ad-libbed in past takes (§2.3).
2. **Offer and business details** (Jasper Knowledge, Copy.ai Infobase, Gemini Knowledge): product or service names, prices, link-in-bio, current promo, lead magnet, CTA destination, words to avoid about the offer. This stops invented offers and makes endings concrete.
3. **Location, currency, units and local references.** Prices in the creator's currency, "R$" vs "€", metric vs imperial, local holidays and cultural references. Most tools ignore this; Cue knows the device region and can pre-fill it.
4. **Speaking pace measured from takes.** Cue already records and follows speech. Words per minute from the creator's kept takes (per language) should set script length for a target duration. Competitors ask for "length" (Captions, CapCut, Subscribr); Cue can derive it from real pace instead.
5. **Past top-performing videos** (Spotter Studio, vidIQ, Subscribr): a "my best ones" list. Even without platform APIs, the creator could mark takes or exports that did well (views typed in, or just a star), giving Cue examples of hooks and endings that worked.
6. **Transcripts of the creator's own published videos** (Subscribr, creator advice: "2–5 transcripts of past videos"). Spoken samples beat written captions for a teleprompter app. Import my writing could accept a video file or link and transcribe it on device.
7. **Per-platform rules** (Metricool per network, Hootsuite per profile): length, hook style, CTA wording and swearing tolerance per platform (TikTok vs YouTube vs LinkedIn).
8. **Niche compliance guardrails** (topic- and region-aware "never claim" packs):
   - **Health:** the FTC says you "can't make up claims… such as scientific proof that a product can treat a health condition" (Teami 2020 detox-tea case; 2023 warning letters to dietitians and health influencers).
   - **Finance:** **ESMA warning, 6 Feb 2024**: people posting investment recommendations must disclose interests and conflicts in **each** post, with market-abuse risk (MAR); AMF and CONSOB echoed it.
   - **Brazil:** **CONAR's new influencer guide (13 May 2026)**: platform disclosure tools preferred over "#publi"; **using AI to make content doesn't remove responsibility**; affiliates are covered; minors need guardian authorisation and a judicial permit.
   - **Sponsored content:** the FTC Endorsement Guides (2023) require clear disclosure inside the content itself, not just a platform label.
   - **Product shape:** an optional "My content is about health / money / law / kids" switch that adds the right disclaimers and blocks unprovable claims, plus a "This video is sponsored" toggle that adds a spoken disclosure line in the creator's language.
9. **Custom vocabulary** (Opus Clip "brand vocabulary"): names, brand and product terms, and how to spell or pronounce them. Useful for scripts, for Voice Following and for captions.
10. **Audience segments** (Jasper's audiences and personas): more than one audience, and pick which one per script.

---

#### Sources

**Apple**
- TermOfAddress: https://developer.apple.com/documentation/foundation/termofaddress (iOS 17+; feminine/masculine/neutral/localized; "not all terms of address exist in all languages")
- TermOfAddress.currentUser: https://developer.apple.com/documentation/foundation/termofaddress/currentuser (iOS 18+; "only compare equal to another currentUser")
- Morphology.user: https://developer.apple.com/documentation/foundation/morphology/user (iOS 15+; `isUnspecified` true "if the user hasn't specified preferences, or chose not to share them with this app")
- Morphology: https://developer.apple.com/documentation/foundation/morphology
- WWDC23 10153 "Unlock the power of grammatical agreement": https://developer.apple.com/videos/play/wwdc2023/10153 (pt-PT and German added; fr/it/pt-BR in 2022; Spanish)
- WWDC21 10109 "What's new in Foundation": https://developer.apple.com/videos/play/wwdc2021/10109/ (automatic agreement for Spanish and English; Term of Address option; inflection alternative) *(older)*
- Mac User Guide, Language & Region: https://support.apple.com/en-ie/guide/mac-help/intl163/26/mac/26 ("Share with all applications")
- iPad guide: https://support.apple.com/en-ke/guide/ipad/ipad0cc6a80b/ipados
- Forum thread on third-party access: https://developer.apple.com/forums/thread/740368 (unresolved; suggests NSMorphology.userMorphology) *(older)*

**Android and Google**
- Grammatical inflection: https://developer.android.com/about/versions/14/features/grammatical-inflection
- GrammaticalInflectionManager: https://developer.android.com/reference/android/app/GrammaticalInflectionManager (system value needs READ_SYSTEM_GRAMMATICAL_GENDER, privileged apps only)
- Google Translate: https://blog.google/products/translate/reducing-gender-bias-google-translate/ and https://research.google/blog/a-scalable-approach-to-reducing-gender-bias-in-google-translate/ *(older)*

**Style guides and language**
- Microsoft pt-BR style guide: https://download.microsoft.com/download/8/e/3/8e349e32-9eb9-4b63-9909-7586b94a24dd/por-bra-StyleGuide.pdf (§3.1)
- Microsoft fr-FR style guide: https://download.microsoft.com/download/c/7/9/c7921dbd-4531-4a4e-8490-e4656d739f3d/fra-fra-StyleGuide.pdf (§3, Sept 2022 position; iel)
- RAE on todes/x/@: https://www.vistazo.com/actualidad/internacional/la-real-academia-espanola-mantiene-su-postura-en-contra-de-terminos-como-todes-CJ920613 ; https://eju.tv/?p=2434013
- Portuguese neutral language: https://uwm.edu/world-languages-cultures/?p=23789 ; https://localize.proton.me/t/guidance-for-portuguese-brazilian/116 ; https://warwick.ac.uk/fac/cross_fac/iatl/sharingpractice/repository/gonzalez-abbatelli/portuguese_-_inclusive_language_guide.pdf
- Arabic: https://meta.discourse.org/t/gender-and-translations/73728?page=2 ; https://aclanthology.org/2023.gitt-1.1
- Hindi: https://en.wikibooks.org/wiki/Hindi/Verbs ; https://web.stanford.edu/dept/linguistics/languages/hindi/Default.htm
- Thai: https://www.thaipod101.com/lesson/thai-teachers-answer-your-questions-1-whats-the-difference-between-khrap-and-kha ; https://cuir.car.chula.ac.th/dspace/bitstream/123456789/78768/1/Thornwarat%20La_tran_2017.pdf
- Japanese pronouns: https://escholarship.org/uc/item/4qc633pf ; https://e-journal.unmas.ac.id/index.php/sphota/article/view/1665
- Korean speech levels: https://migaku.com/blog/korean/korean-formal-vs-informal-speech
- German du/Sie: https://www.versicherungsbote.de/id/4906861/Kunden-mochten-im-Beratungsgesprach-eher-nicht-geduzt-werden/ ; https://yougov.com/de-de/artikel/16253-du-musst-sie-sagen
- Spanish address forms: https://es.scribd.com/document/997455017/Comparando-El (low quality) ; https://latintorera.substack.com/p/92-como-esta-usted
- Portugal (Marktest 2024 topic list): https://ww.marktest.com/wap/private/images/Logos/Folheto_Portugueses_Redes_Sociais_2024.pdf

**Privacy and UX**
- CJEU C-394/23 Mousse: https://curia.europa.eu/jcms/upload/docs/application/pdf/2025-01/cp250002en.pdf ; https://cov.com/-/media/files/corporate/publications/2025/01/cjeu-finds-customers-title-is-not-necessary-data-for-the-purchase-of-a-train-ticket.pdf
- LGPD and gender: https://www.santander.com.br/blog/para-voce/como-proteger-dados-sensiveis ; https://www.scielo.br/j/rdp/a/sjf8hNGcJs3v9L7kf8y6GLt/?lang=en
- GOV.UK equality information pattern: https://design-system.service.gov.uk/patterns/equality-information ; Home Office: https://design.homeoffice.gov.uk/design-system/patterns/ask-users-for/sex-gender ; https://uxdesign.cc/designing-forms-for-gender-diversity-and-inclusion-d8194cf1f51

**Tools**
- Jasper: https://help.jasper.ai/hc/en-us/articles/18618693085339-Brand-Voice ; https://www.jasper.ai/brand-voice ; Audiences https://help.jasper.ai/hc/en-us/articles/36829917506203-Audiences
- Copy.ai: https://support.copy.ai/en/articles/8342114-what-is-brand-voice ; https://support.copy.ai/en/articles/7320850-what-is-infobase
- Writer: https://support.writer.com/articles/4354376534-how-to-set-up-and-use-your-personal-voice-profile
- ChatGPT: https://help.openai.com/en/articles/11899719-customizing-your-chatgpt-personality ; A/B complaints https://community.openai.com/t/stupid-feature-which-response-do-you-prefer-your-choice-will-help-make-chatgpt-better/394873 , https://community.openai.com/t/give-users-an-option-to-opt-out-of-response-selection/1044881 , https://community.openai.com/t/topic-a-b-testing-ux-is-actively-discouraging-feedback-and-producing-garbage-data/1264022
- Claude Styles: https://support.anthropic.com/en/articles/10181068-configuring-and-using-styles
- Gemini Gems: https://support.google.com/gemini/answer/15235603
- Notion: https://www.notion.com/help/notion-agent ; https://www.notion.com/en-gb/help/view-your-notion-agent-memories
- Grammarly: https://support.grammarly.com/hc/en-us/articles/23153676821773-Introducing-voice-features ; https://techcrunch.com/2023/10/25/grammarlys-new-generative-ai-feature-learns-your-style-and-applies-it-to-any-text *(older)*
- Taplio: https://reepl.io/blog/best-ai-linkedin-post-generators (competitor)
- AuthoredUp: https://roadmap.authoredup.com/news/authored-up-6-7-import-your-full-linked-in-history-redesigned-editor-toolbar-and-coauthor-beta
- Typefully: https://support.typefully.com/en/articles/8717738 ; Hypefury: https://www.wearefounders.uk/hypefury-vs-typefully-2026-which-x-tool-is-worth-paying-for/
- Spotter Studio: https://help.spotterstudio.com/en/articles/9704517-brainstorm-overview ; https://techcrunch.com/2024/09/03/spotter-launches-ai-tools-youtubers-brainstorm-video-ideas-thumbnails
- vidIQ: https://vidiq.com/chat ; https://vidiq.com/pt/features/script-writer/
- Subscribr: https://subscribr.ai/help/channel-settings (as summarised by search; page 404 on fetch) ; https://daveswift.com/subscribr/
- Captions: https://captions.ai/help/docs/project/script ; https://captions.ai/help/guides/creators/camera-teleprompter
- CapCut: https://www.capcut.com/resource/script-to-video-ai ; https://www.capcut.com/resource/script-writing-ai
- Opus Clip: https://help.opus.pro/docs/article/how-to-add-a-brand-template.md ; https://www.opus.pro/pricing
- Descript: https://help.descript.com/hc/en-us/articles/36803785502221-Underlord-beta-Your-AI-co-editor-in-Descript ; https://www.createwith.com/tool/descript/updates/descripts-underlord-ai-now-learns-your-editing-style-with-custom-instructions
- BIGVU: https://bigvu.tv/ai-writer/ai-brand-tone-generator ; https://faq.bigvu.tv/en/articles/7219757-how-to-rewrite-a-script-with-the-ai-magic-writer
- PromptSmart / Teleprompter Premium: https://www.opus.pro/blog/best-teleprompter-apps-for-creators
- Hootsuite: https://www.hootsuite.com/whats-new/personalize-owlygpt-responses-with-your-brand-voice-beta ; https://hootsuite.com/platform/owly-writer-ai
- Later: https://help.later.com/hc/articles/12252569781015 ; https://later.com/caption-writer/
- Metricool: https://help.metricool.com/en/article/how-to-set-up-ai-prompt-customization-in-metricool-hxhplw/
- Canva: https://www.canva.com/help/brand-voice/ ; https://www.canva.com/newsroom/news/magic-write-ai-text-generator/

**Feedback research**
- PRELUDE/CIPHER: https://www.microsoft.com/en-us/research/publication/aligning-llm-agents-by-learning-latent-preference-from-user-edits/ ; https://neurips.cc/virtual/2024/poster/96078
- Feedback rates and implicit signals: https://www.koji.so/docs/ai-feedback-signals-thumbs-research ; https://tianpan.co/blog/2026/04/10/thumbs-down-data-lying-selection-bias-ai-feedback ; https://amplitude.com/docs/api/content/amplitude-ai/agent-analytics/collect-user-feedback
- Brand-voice sentiment (second-hand): https://marcandrews.com/?p=2313 ; https://wyzowl.com/jasper-review ; https://reddit.sentinel-team.org/posts/1tnwd7t/snapshots/2026-05-26T12%3A34%3A10.31372Z ; https://creativemarketing.ai/blog/ai-copywriting-best-practices-marketing-automation-brand-voice
- Story bank: https://www.asianefficiency.com/technology/the-story-bank-how-to-stop-ai-from-making-up-stories-in-your-content/ ; IONOS https://www.ionos.com/digitalguide/online-marketing/social-media/ai-as-ghostwriter/

**Compliance**
- FTC: https://www.thefashionlaw.com/the-federal-trade-commission-just-published-influencer-specific-guidance-on-endorsement-disclosures/ ; https://adlaw.lewissilkin.com/post/102g3nd/ftc-action-says-influencers-made-false-claims-and-failed-to-include-proper-disclo
- ESMA: https://www.esma.europa.eu/sites/default/files/2024-02/ESMA74-1103241886-912_Warnings_on_Social_Media_and_Investment_Recommendations.pdf
- CONAR 2026: https://propmark.com.br/digital/conar-atualiza-guia-de-publicidade-com-influenciadores-e-inclui-regras-sobre-ia/ ; https://www.klalaw.com.br/conar-atualiza-guia-de-publicidade-com-influenciadores/
