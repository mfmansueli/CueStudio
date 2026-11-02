# Medição de base das entradas do criador (01–02/11/2026)

Os artefatos do §11.1 de `reports/entradas-do-criador-2026-11-01-completo.md`, para quem for conferir ou repetir. Código do app: `main`, commit
`ed350580`, sem nenhuma mudança. Os testes desta pasta **não estão no repositório** (não commitados): rodaram no worktree
`.claude/worktrees/integration-audit` (HEAD `ed350580`), com `scripts/test.sh` mudado como em `tests/test.sh.diff`.

## O que tem aqui

| Caminho | O quê |
|---|---|
| `tests/TypedPersonalityTagsTests.swift` | Simulador: bordão digitado repetido e abertura apagada que continua no pedido. Resultado em `simulador-tags.txt` |
| `tests/CreatorInputsDeviceTests.swift` | iPhone: 6 casos × 3 ideias, rotas `app` (a escolha do app), `device` (só o modelo do aparelho) e `cloud` (pede o PCC primeiro); também lê `Morphology.user` |
| `tests/CreatorInputsPromptCaptureTests.swift` | Simulador: grava as instruções e o prompt de cada caso, por rota (`prompts/`) |
| `tests/test.sh.diff` | A linha que registra `CreatorInputsDeviceTests` no modo `device` do script |
| `run1-iago-lima/` | 36 roteiros (rotas `app` e `device`), `term-of-address.txt`, `manifest.json` do xcresult |
| `run2-mansuelli/` | 18 roteiros (rota `cloud`, que caiu no aparelho), `term-of-address.txt`, `log-excerpt.txt` (as falhas `cloud.quotaLimitReached`), `manifest.json` |
| `prompts/` | 36 arquivos: instruções + prompt de cada caso e ideia, para `onDevice` e `privateCloud` |
| `classificacao.csv` | Uma linha por roteiro (54), com a classificação feita à mão e a citação que a justifica |
| `q1-baseline.csv` | Qualidade editorial (Q1), uma linha por roteiro: preserva o assunto, desenvolve algo concreto, soa natural; lida por um agente sem ver `classificacao.csv` (02/11) |
| `tools/score_inputs.py`, `tools/show_scores.py` | A triagem automática (só aponta onde olhar; deixou passar casos, ver abaixo) |
| `tools/build_classification.py` | Gera o CSV a partir dos JSON e da classificação à mão, que está escrita no próprio arquivo |

## Aparelhos, rotas e versões

| Rodada | Aparelho | Sistema | Rota pedida | Rota efetiva | Quando |
|---|---|---|---|---|---|
| 1 | iago Lima iphone, iPhone 15 Pro (iPhone16,1) | iOS 27.2 (24B119) | `app` e `device` | `onDevice` nos 36 | 01/11, 23:54–00:01 (CET) |
| 2 | Mansuelli iPhone 18 Pro Max (iPhone19,7) | iOS 27.0.1 (24A446) | `cloud` | `onDevice` nos 18 (PCC: `cloud.quotaLimitReached`, "Usage quota reached") | 02/11, 00:02–00:06 |

A rota efetiva é `GeneratedScript.model`, gravada em cada JSON (`model`).

**Limites:**
- **Nada mediu o PCC.**
- **Rodada 1:** o registro de console foi sobrescrito pela rodada 2. Ficaram os JSON (com a rota efetiva), mas não o motivo de o PCC não ter sido usado: a disponibilidade só passou a ser gravada na rodada 2.
- **Dois aparelhos com modelos diferentes:** a comparação antes/depois precisa controlar aparelho e sistema.
- **Segunda tentativa não gravada:** o JSON tem o texto final; uma segunda tentativa que `VoiceCheckedWriting` pode ter pedido não fica registrada.
- **Prompts aproximados:** os de `prompts/` são os montados depois de `AIRequestPolicy.prepare`, antes do ajuste à janela do aparelho (que não corta perfis tão pequenos) e sem a segunda tentativa.

## Casos

Perfis mínimos (`CreatorProfile` com papel, tópico, tom e, nos dois últimos, abertura, final e bordão), TikTok, sem formato, sem duração. Idioma
lido da ideia e da preferência do aparelho dada ao `ScriptRequestFactory`.

| Caso | Perfil | Idioma |
|---|---|---|
| `pt-fitness-woman` | expert, fitness, energetic + confident | pt-BR |
| `es-beauty-woman` | personal, beauty, casual + warm & calm | es-ES |
| `it-food-woman` | personal, food, casual + funny | it-IT |
| `fr-travel-woman` | personal, travel, casual + confident | fr-FR |
| `en-no-cta` | educator, productivity; "Here's the thing"; "Question"; "No call to action" | en-US |
| `pt-follow-cta` | personal, lifestyle; "Bora lá"; "Question"; "Follow for more" | pt-BR |

As quatro primeiras são "criadoras" só no sentido de que as ideias são de uma mulher falando de si. **Nada no pedido diz isso**, porque o app não tem esse campo. O teste mostra o que o modelo escolhe quando não sabe; não mostra desobediência a uma escolha.

## Critérios de classificação (lidos à mão)

- **Marca de gênero de quem fala:** uma forma em primeira pessoa cuja concordância diz o gênero do falante. São adjetivos e particípios com "être", "essere", "estar" ou "sentirse", e pronomes como "misma". Contam "je suis parti", "me sentí perdido", "mi sono reso conto" e "en mí misma". Não contam os particípios com "avoir", "avere" ou "haber" ("ho cucinato", "he probado"), nem o português com verbo sem concordância ("perdi", "comecei").
  - Valores: `M`, `F` ou `none` (não havia onde marcar).
  - A triagem automática deixou passar "Je suis parti".
- **CTA de engajamento no fim** (caso `en-no-cta`): o último bloco pede ao espectador para comentar, salvar, seguir, compartilhar ou curtir.
  - Uma instrução para aplicar a dica ("Try setting that timer") **não** conta.
  - Uma marcação de palco ("[follow]") não conta, porque não é falada.
- **Pede para seguir** (caso `pt-follow-cta`): a fala pede para seguir, mesmo com erro de grafia ("Seguam").
  - **Outra ação do espectador:** pedir para comentar ou salvar.
  - "Agora eu salvo esse momento no meu celular" é o criador falando de si, não um pedido ao espectador.
- **Abre com pergunta:** a primeira frase falada termina em "?".
- **Bordão:** a expressão aparece na fala.
- **Números que não estão na ideia,** por tipo:
  - `structure`: uma lista;
  - `rhetorical`: um gancho ou uma hipótese;
  - `scene`: detalhe de uma rotina ou história imaginada em primeira pessoa;
  - `advice`: um passo que o espectador pode seguir;
  - `RESULT`: um resultado atribuído ao criador, como peso, dinheiro ou porcentagem.
  
  Entre as ocorrências classificadas, só uma é `RESULT`. A lista **não é exaustiva**: a triagem pulava números iguais aos da ideia. "ho cotto tutto per venti minuti" (it, rodada 2) foi acrescentado à mão: a ideia dava vinte *pessoas*, e o número voltou com outra unidade, o que não preserva um fato fornecido.

## Totais (do CSV)

- **Gênero, 36 roteiros das quatro criadoras:** M 6, F 1, sem marca 29.
- **"No call to action":** CTA de engajamento no fim em 5 de 9.
- **"Follow for more":** pede para seguir em 5 de 9; pede outra ação em 8 de 9.
- **Abre com pergunta:** en 8 de 9, pt 6 de 9.
- **Bordão:** en 9 de 9, pt 8 de 9.

## Como repetir

No worktree com os testes copiados para `Cue StudioTests/` e a linha de `tests/test.sh.diff` aplicada:

```sh
CUE_DEVICE="<iPhone>" TEST_RUNNER_CUE_INPUTS_ROUTES=cloud scripts/test.sh device CreatorInputsDeviceTests   # ou app,device
scripts/test.sh only "Cue StudioTests/CreatorInputsPromptCaptureTests"                                         # prompts
scripts/test.sh only "Cue StudioTests/TypedPersonalityTagsTests"                                               # tags
xcrun xcresulttool export attachments --path build/results/<rodada>.xcresult --output-path <pasta>
python3 -I tools/build_classification.py <pasta>   # depois de classificar à mão os roteiros novos
```

O suíte de aparelho substitui o app no iPhone: reinstale a versão de uso depois (`scripts/build.sh install`).

## Bases Q0 e Q1 (02/11)

`tools/q0.py` (cópia de `tools/creator_inputs/q0.py` da branch `fix/creator-inputs`) faz as quatro contagens da bateria de aprovação sobre o que foi pedido:

```
tools/q0.py --run run1-iago-lima:app,device --run run2-mansuelli:cloud --labels classificacao.csv --q1 q1-baseline.csv
```

- **Execução e roteiro escrito:** 54/54.
- **Restrições** (o "never" do perfil e a regra do bordão; as outras dependem das decisões): 13/18, o "No call to action" ignorado em 5 de 9.
- **Qualidade editorial (Q1, as três perguntas):** 12/54 (22%; IC95 13–35%). Assunto 42/54, concreto 37/54, natural 19/54. Nos três, por idioma:
  en 4/9, es 5/9, pt 3/18, it 0/9, fr 0/9.
- **Ressalvas do Q1:** o masculino nos casos "woman" contou como não natural (o app não informa o gênero; sem esse critério, só fr device-1 muda),
  e o decalque "Salva/Sauve este momento" também (sem ele, es cloud-0 e it cloud-0 passam nos três).


## Rodada 3: PCC no iago Lima iphone (02/11, 10:44–10:51, branch `fix/creator-inputs` com os consertos da trilha A)

`run3-iago-lima-pcc/`, rota `cloud`, os 6 casos. **O PCC escreveu só 4 dos 18:** os 3 de `en-no-cta` e o primeiro de `pt-fitness-woman`. Depois,
cada pedido foi negado em 0,1 s com `PrivateCloudComputeError: deniedDueToUserDeviceRateLimit` (o app registra `cloud.quotaLimitReached`) e o app
escreveu no modelo do iPhone. É um limite de pedidos por aparelho num intervalo, não a cota do dia: às 10:44 havia cota, às 10:48 já não.

- **O que o PCC escreveu:** os 3 de `en-no-cta` sem CTA no fim. Nenhum com o bordão ("Here's the thing", opcional no PCC) e nenhum abrindo com
  pergunta. Os três começam com "I used to…", a mesma moldura. `needsFactCheck` marcado nos 4, porque o PCC sempre pede a conferência.
- **Os 14 do modelo do iPhone** valem como mais uma rodada do aparelho, com os consertos da trilha A.
- `tools/q0.py` separa as restrições pelo modelo que escreveu (`constraints by model`).

## Rodada 4: Mansuelli iPhone 18 Pro Max (02/11, 11:32–11:37, depois do A8, A2/A4 e A11b)

`run4-mansuelli-18pm-a8/`, rotas `device` e `cloud`, 3 casos (`en-no-cta`, `pt-follow-cta`, `pt-fitness-woman`). O PCC negou os pedidos por limite
do aparelho (`deniedDueToUserDeviceRateLimit` 3×, `cloud.quotaLimitReached`): **os 18 roteiros são do modelo do iPhone.**

- **"No call to action" (hábito):** 6 de 6 terminam sem pedir nada (antes: CTA de engajamento em 5 de 9). Dois leram a instrução em voz alta
  ("Nothing to do.", "the takeaway is this:"): o texto do bloco Close mudou depois desta rodada, sem "nothing" nem "takeaway".
- **"Follow for more":** 6 de 6 pedem para seguir e nenhum pede outra ação (antes: outra ação em 8 de 9).
- **Resultado inventado (B12):** nenhum em `pt-fitness-woman` (0 de 6); só números de rotina ("10 minutos", "três vezes por semana").
- Q0: restrições 6/6 nas duas rotas pedidas (todas escritas no aparelho).
