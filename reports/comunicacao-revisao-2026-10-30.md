# Comunicação do Cue Studio: revisão da proposta contra o código

30/10/2026.

**Código conferido**
- main `1f62fb24`, igual a origin/main e à referência do PDF. Não há nada mais novo na main.
- Nenhuma branch ou worktree à frente da main mexe em comunicação. Só `marketing/foundation` tem commits, e são documentos.
- A mudança local ainda não commitada (`SteadyValueText`, o valor dos sliders) não tem relação com comunicação e ficou intacta.

**Como foi feito:** só leitura. Nada foi alterado, compilado ou testado. Os caminhos são relativos a `Cue Studio/`.

**Decisões já tomadas, que esta revisão não discute:**
- A animação de abertura do Pro fica em toda abertura.
- O onboarding continua sem Skip.
- As adaptações de acessibilidade existentes ficam.
- O gesto de voltar de qualquer ponto da tela fica.
- A Ultra AI existir só em Debug é intencional: o frontend vem antes da produção.
- O Remote continua livre para todos (decisão de 30/10).

---

## 1. Problemas confirmados

Em ordem de impacto. Cada um tem o trecho no código e um cenário concreto.

### A. Trabalho que se perde

**A1. Um resultado assíncrono apaga o Undo de um roteiro excluído.**
- **Código:** a versão para uma plataforma roda num `Task {}` sem cancelamento (`Screens/ScriptDetail/ScriptDetailView.swift:127`). Excluir apaga na hora (`Managers/Library/ScriptLibraryService.swift:128-132`) e `ToastService.show` substitui o toast anterior (`Managers/ToastService.swift:39-54`).
- **Cenário:**
  1. Pedir a versão TikTok.
  2. Excluir o roteiro (`ScriptDetailView.swift:123-126`).
  3. "Script deleted · Undo" aparece.
  4. Segundos depois, "TikTok version saved" toma o lugar dele, e o roteiro se perde sem volta.

**A2. Fora do editor, o Undo só existe no toast, e tocar no toast o fecha.**
- **Código:** `Screens/Shared/Toast/ToastHost.swift:30`. Depende só do toast:
  - excluir roteiro e ideia (`ScriptsViewModel.swift:81-88`, `ScriptDetailViewModel.swift:456-460`, `LogbookView.swift:556-562`);
  - excluir estilos salvos (`CaptionsViewModel+Library.swift:69-79`);
  - excluir take (`TakeReviewViewModel.swift:283-289`): o vídeo é apagado em 4,6 s fixos, mesmo que o toast ainda esteja na tela.
- Não existe lixeira.

**A3. Fechar o app depois do capítulo 1.4 encerra o onboarding sem a prática e sem o 1.7.**
- **Código:**
  - o capítulo não é salvo (`Managers/Onboarding/OnboardingService.swift:16,29`);
  - em 1.4 o roteiro e os tópicos já existem;
  - no próximo lançamento, `resolve(hasExistingContent:)` (`SupportFiles/AppServices.swift:264-266`) chama `markCompleted()` e `markFirstStarShown()` (`OnboardingService.swift:38-42`).
- **Cenário:** em 1.5 o criador recusa o microfone e vai aos Ajustes, como a tela pede ("Turn them on in Settings", `Screens/Onboarding/Voice/VoiceChapter.swift:130-138`). Se o iOS encerrar o app, ao voltar o onboarding já está concluído.

### B. Mensagens que dizem o contrário do que aconteceu

**B1. "Ready to travel" mostra legendas que o vídeo não tem.**
- **Código:** `announce` zera `captionNotice` (`TakeReviewViewModel.swift:682-685`) **antes** de `exported()` calcular `hasCaptions: … && captionNotice == nil` (`:630`). A ordem está em `:498-499`.
- **Cenário:** as legendas falham e o vídeo é salvo. O toast diz que o vídeo ficou sem legendas, mas fica escondido sob o cover. O cover diz que tem.

**B2. O aviso de trabalho de uma operação vira o resultado de outra, com háptico de sucesso.**
- **Código:** `endsWork` vale para qualquer toast que chega sobre um de trabalho (`ToastService.swift:40`).
- **Cenário:** durante "Drafting the TikTok version…", um toque em "Checked" mostra "✓ Marked as fact-checked" no mesmo aviso, com o háptico de sucesso. Parece que a versão terminou.

**B3. O mesmo marco aparece duas vezes na mesma revisão.**
- **Código:** `ShareFlow.reachedMilestone` nunca volta a nil (`Screens/TakeReview/Share/ShareFlow.swift:26,167`), e cada send-off o copia de novo (`TakeReviewView.swift:195-199`).
- **Cenário:** o criador chega ao marco de 10 e vê a história. Na mesma revisão, compartilha o mesmo take em outra rede e toca Done: a história do marco 10 abre outra vez.

**B4. A contagem por ano não bate com o ícone acumulado.**
- **Código:** o ícone abre pelo total (`MilestoneService.isUnlocked`, `shares >= milestone`), mas o marco conta o ano (`MilestoneService.swift:61-66`).
- **Cenário:** 5 vídeos em 2026 e 5 em 2027. O ícone de 10 abre sem nenhuma celebração. Em 2027, Your universe ainda diz "NEXT MILESTONE · 5 / 10 · Unlocks the … app icon" (`Screens/Profile/Universe/YourUniverseView.swift:165-167`), para um ícone que já está aberto.

**B5. O convite "Want a reminder to record this script?" aparece fora do roteiro, e o botão dele não cria lembrete.**
- **Fora do roteiro:** o convite dispara no `onDisappear` da página (`ScriptDetailView.swift:62,104-111`). Trocar de aba também conta, então ele pode abrir sobre Settings.
- **Sem lembrete:** "Allow" só pede a permissão (`Managers/Notifications/NotificationService+Invite.swift:41-46`).

**B6. O convite aparece na primeira viagem, contra o próprio comentário.**
- **Código:** o comentário diz "Never on first launch or during the first flight" (`NotificationService+Invite.swift:10`), mas `invite()` não confere nenhum dos dois (`:18-27`).

**B7. Ligar uma chave em Settings › Notifications liga tudo, inclusive a rotina Seg/Qua/Sex 18:00.**
- **Código:** qualquer chave tocada antes de o iOS ter perguntado chama `allowEverything` e depois `turnEverythingOn` (`NotificationsSettingsView.swift:134-136`; `NotificationService+Groups.swift:33-46`). Isso liga todas as categorias, Tools and news incluída.
- O convite não faz isso (`NotificationService+Reconcile.swift:142`).

### C. Coordenação (não existe porteiro)

**C1. Fechar uma dica e outra aparecer 1,2 s depois.**
- **Código:**
  1. ✕ na dica da viagem insere o passo em `closedThisSession` (`Managers/FirstVoyage/FirstVoyageService.swift:118-121`).
  2. `floatingStep` vira nil.
  3. A dica de voz passa a valer e aparece 1,2 s depois (`Screens/Shared/VoiceStyle/VoiceQuestionTipHost.swift:44,63-73`).

**C2. "Not now" no convite e, no mesmo dia, a dica de voz.**
- **Código:** a dica de voz confere `exposures` (`NotificationService+Discovery.swift:15-19`), mas o convite grava em `invitesShown` (`+Invite.swift:35`). O bloqueio só vale num sentido.

**C3. O cartão da Ultra AI no dock aparece junto com a dica da viagem.**
- **Código:**
  - o cartão não confere viagem nem voz (`Screens/Scripts/Dock/ScriptsDock.swift:152-153`);
  - abrir Find inspiration já conta como uso (`FindInspirationSheet.swift:133`), e com `usesBefore = 1` o convite vale a partir do 2º uso.
- Hoje só em Debug, mas é o frontend que está sendo preparado.

**C4. A mesma orientação aparece três vezes.**
- **Código:** não há memória de "visto no lugar". `shownThisSession` serve só à telemetria (`FirstVoyageService.swift:33-34`).
- **Cenário:** Pick na revisão (`TakeReviewView.swift:567-579`), depois o toast "Next: pick a take", depois o Pick flutuante. Practice repete o mesmo caminho: página do roteiro e depois flutuante.

**C5. A introdução adiada de uma ferramenta se perde.**
- **Código:** `deferredIntro` é apagado (`NotificationService+Discovery.swift:44`) antes de `MainView` conferir `presentation.sheet == nil` (`Screens/Main/MainView.swift:348-349`). Com uma sheet aberta, a introdução nunca aparece.

**C6. A primeira gravação traz 5 recados em sequência.**
1. First star
2. Pick na revisão
3. o convite (sheet)
4. "Recorded · Next: pick a take"
5. o Pick flutuante

O First star abre no `onAppear` da revisão (`TakeReviewView.swift:219`), por cima da revisão que o criador queria ver.

### D. TipKit (a dica de voz)

**D1. "Delete my Cue data" zera o agendador, mas não o TipKit.**
- **Código:** `Managers/Privacy/DataEraserService.swift:113`; `resetDatastore` só roda em memória (`SupportFiles/CueStudioApp.swift:50`).
- **Efeito:**
  - a id `vq.tip.<q>.0` já foi invalidada, então a dica volta invisível;
  - mesmo assim gasta a cota do dia e da semana;
  - e marca `tipDays`, o que bloqueia o convite e as introduções naquele dia (`VoiceQuestionTipHost.swift:69-73`; `+Invite.swift:23`; `+Discovery.swift:38`).

**D2. Colar um exemplo conta como fechamento.**
- **Código:** a sheet de exemplo nunca chama `answered` (`Screens/Profile/Voice/Question/VoiceQuestionSheet.swift:24-25`), então fechar conta como `dismissed` (`VoiceQuestionSheetModel.swift:162-165`). Três seguidos pausam tudo por 14 dias.
- **Caminhos parecidos:**
  - "+ Something else" sem Save (`:114-118`);
  - marcar e desmarcar uma opção (`:89-91`): a rodada não muda e a dica volta invisível.

### E. Promessas maiores do que o app sabe

**E1. "✓ Monetizable" mede só a duração gravada.**
- **Código:** a duração contra `preset.minimum` (`MonetizationCheck.swift:16-23`). Ao lado, "TikTok pays Creator Rewards over one minute" (`MonetizationGoal.swift:33`).
- O app não sabe de seguidores nem de originalidade. Um corte no editor pode deixar o vídeo abaixo de 1:00.

**E2. "Fits" / "✓ Fits TikTok" é só a faixa recomendada.**
- **Código:** `idealRange` (`PlatformPreset.swift:15-18`). O único limite rígido modelado é o do Shorts, 180 s (`ShareNetworkLine.swift:12`).
- "Fits" soa como "a plataforma aceita".

**E3. "Checking the facts" é uma passada do modelo, sem pesquisa.**
- **Código:** `UltraFlow.checked` existe (`Managers/ScriptAI/Ultra/UltraScriptService.swift:22`), mas as próprias instruções dizem que não há ferramenta de pesquisa e que a revisão não prova a precisão (`UltraInstructions.swift:65-66`).

**E4. "Checked" só esconde o aviso.**
- **Código:** `factCheck = false` (`ScriptLibraryService.swift:97-101`), sem data nem registro.
- Uma reescrita pela IA depois disso não traz o aviso de volta (`ScriptDetailViewModel.swift:267-276`).

**E5. "My Cue Voice 40%" mede o preenchimento, não a qualidade.**
- **Código:** os pesos estão em `VoiceField.swift:16-22`. Com 85% ou mais, o rótulo vira "Sounds like you" (`VoiceStrengthLevel.swift:16-25`).

**E6. "Cancel" no tracking do Blur guarda o que já foi seguido.**
- **Código:** `BlurViewModel+Following.swift:37-40`. Só o VoiceOver ouve "Keeps what was tracked" (`BlurStatusCard.swift:72`).

**E7. Três dos quatro benefícios visíveis no paywall estão abertos para todos.**
- **Código:** `Screens/Shared/Paywall/PaywallCopy.swift:41-45`:
  - My Cue Voice completo e rascunhos de anúncio;
  - versões de hook e de plataforma;
  - capas, tags de série e "Text behind me".
- **O que é de fato Pro:**
  - exportações ilimitadas;
  - ícones a partir de 10 vídeos;
  - sem marca d'água na gravação de tela (`CaptureWatermark.swift:53`);
  - 30 roteiros Ultra por mês.

### F. Sucesso parcial sem aviso que fica

**F1. A compra dá certo e depois a exportação falha: nada fica na tela.**
- **Código:** `continueAfterPurchase` (`TakeReviewViewModel.swift:363-367`) mostra "Couldn't export · Try again" por 2,4 s. `.failed` não tem tela e `pendingAction` já foi zerado.

**F2. Fotos desligado na fila "Share to universe": só um toast, sem botão.**
- **Código:** `TakeReviewViewModel.swift:~484`.
- O Save já tem o `PhotosDeniedCard`.

**F3. Ao trocar uma mídia com Blur e legendas, o aviso do Blur esconde o das legendas.**
- **Código:** `OverlaysViewModel+Media.swift:286-302`, `return` em `:298`.

**F4. Toasts que aparecem embaixo de uma sheet aberta** (confirmado no código).

| Toast | Por cima de |
|---|---|
| "Copy your script first" | `ImportScriptSheet` |
| "Add brand and product" | `BrandBriefSheet` |
| "Signed in with Apple", "Signed out", "Couldn't sign in · Try again" | `EditProfileSheet` |
| "X removed · Undo" (o único Undo) | `AddMediaSheet` aberta em `.large` |
| "Saved to Photos · N of 3 free exports left · …no captions" | o cover "Ready to travel" |

Só o Logbook tem host próprio (`LogbookView.swift:138`).

### G. Progresso da primeira viagem

**G1. A viagem já começa em 3/6.**
- **Código:**
  - o roteiro de demonstração de 1.4 conta como "Write" (`VoyageProgress.swift:19`);
  - a prática de 1.6 conta como "Practice" (`PrompterView.swift:115-117`);
  - importar um vídeo do Fotos conclui write, practice e record (`TakesViewModel.swift:66`).

**G2. Exportar com legendas conclui Pick e Polish sem o criador escolher.**
- **Código:** `cacheCaptions` cria um `edit` (`TakeReviewViewModel.swift:650-672`), e a condição é `$0.edit != nil` (`VoyageProgress.swift:23`).

**G3. Com um só take, Pick não tem saída clara.**
- A dica diz "Star your favorite. The others stay in Takes." (`Models/VoyageStep.swift:63,78`), mas não há outros takes.
- A dica flutuante oferece "Watch" e reabre a mesma revisão (`VoyageNavigator.swift:28-30`).

### Correções do que eu mesmo disse

**Nas pranchas:**
- O toast ✓ comum **não vibra** (`ToastService.swift:84-85`, "A plain ✓ has none"). A prancha 05 dizia o contrário.
- O anúncio de passo concluído da viagem usa só um `soft`, sem háptico duplo.
- **Na mensagem anterior:**
  - **O que eu disse:** a estrela não é registrada num envio direto.
  - **A correção:** isso só vale com as integrações ligadas (Fase B; `integrationsEnabled` está desligado, `Managers/Share/ShareRouteResolver.swift:10`). Na versão que existe hoje, toda rede passa pela fila e pelo "Yes, it's live", que registra a estrela.
  - **O risco que fica:** é um risco latente. Com o Share Kit do TikTok, `.delivered` abre o send-off direto (`TakeReviewViewModel.swift:552-556`), pulando a confirmação e o registro.

---

## 2. Suspeitas descartadas ou já resolvidas

| Suspeita | Situação |
|---|---|
| Abrir o editor conta como Pick | **Descartada.** Conta salvar uma edição com mudança (`VoyageProgress.swift:23`), mas veja o G2 |
| "Allow" no convite liga uma rotina | **Descartada no convite** (`+Reconcile.swift:142`). Acontece só em Settings (B7) |
| O Undo do editor depende do toast | **Já resolvido:** há o botão fixo (`EditorPlayerBar.swift:29`) e o histórico fica no rascunho (`QuickEditViewModel.swift:482-487,641`) |
| Biblioteca, kits e fontes perdem os dados quando o toast some | **Descartada:** os arquivos ficam até a limpeza do próximo lançamento (`MediaLibraryStore.swift:12`, `BrandKitStore.swift:11`, `CustomFontStore.swift:150-157`). Falta só um lugar para desfazer |
| Tracking parcial do Blur passa despercebido | **Já resolvido:** o trecho fica marcado e há "Track from here" (`BlurViewModel+Following.swift:135-150`) |
| Corte, velocidade e crop invalidam o Blur | **Descartada:** o caminho fica no tempo e nas coordenadas da gravação (`BlurViewModel+Following.swift:12-14`). Trocar mídia avisa (F3) |
| Fotos recusado no Save | **Já resolvido:** `PhotosDeniedCard`, a exportação não é contada e o arquivo é reaproveitado |
| "Try again" do primeiro rascunho | **Já resolvido:** é um alerta com Try again (`ScriptDetailView.swift:63-67`). Legendas, Pausas e prévia também têm Try again no lugar |
| Exportação contada sem sair do app, ou contada duas vezes | **Já resolvido:** só conta com prova de entrega, uma vez por operação. Cancelar, falhar ou abrir outro app não contam (`TakeReviewViewModel.swift:11-13`, `DeliveryEvidence`) |
| Um vídeo em 3 redes conta 3 | **Descartada:** conta 1 vídeo, e cada rede soma no próprio planeta. Compartilhar de novo não soma (`MilestoneService.swift:8-9,51-60`). "Publicado" nunca é afirmado (`DeliveryEvidence.confirmsPublication == false`) |
| Cota da Ultra gasta em falha ou cancelamento | **Descartada:** só conta o roteiro escrito. O mês é o do calendário (prévia; o servidor vem depois) |
| As mensagens de processamento não batem com o caminho real | **Descartada:** Private Cloud Compute está ligado (`ScriptAIService.swift:23`) e o texto diz "this iPhone or Private Cloud Compute". A Ultra diz "Sent to Google · only when you pick it" (`PrivacyView.swift:34,67,78`) |
| O teste do Pro se confunde com os usos grátis da Ultra | **Descartada:** "3 exports" e "3 Ultra AI scripts" são linhas separadas, e não há trial (`PaywallCopy.swift:55-62`, `UsagePolicy.swift:12`) |
| Watch e anúncios contradizem o relatório | **Resolvida:** o app do Watch é uma base que compila mas não vai junto com o do iPhone (DESIGN_PROJECT §43), e a linha dele no paywall está escondida (`isAvailable: false`). Os rascunhos de anúncio existem e funcionam, só não são do Pro |
| "Fechar a história conta como vista" contra "o marco fica pendente" | **Descartada no código:** a história do marco só fecha pelos botões, que marcam como vista (`MilestoneView.swift:68`). Não existe marco pendente. A contradição estava na minha prancha |
| Celebrations desligado perde a conquista | **Descartada:** a conquista é registrada e o ícone abre; só a história não aparece (`TakeReviewView.swift:199,608`) |
| Renomear na biblioteca precisa de toast | **Já está certo:** não tem toast, e o nome muda na grade |
| O roteiro de demonstração é duplicado | **Descartada:** 1.6 só o recria com a biblioteca vazia (`OnboardingView.swift:126-129`). O toque duplo vai para o teste no aparelho |
| Reduzir Movimento e Reduzir Transparência nas dicas | **Já resolvido:** as dicas entram com um fade de 0,2 s (`VoyageFloatingTip.swift:30,37`, `VoiceQuestionTipHost.swift:35,43`). A dica de voz usa o vidro do sistema, e o cartão da viagem e o toast são opacos |

---

## 3. O que precisa de teste no aparelho

1. O Ready to travel com legendas que falharam (B1) e o toast sob o cover (F4).
2. **Toasts com botão nas línguas longas:**
   - **Onde:** em alemão, holandês, hindi e francês, no SE / 16e e com Dynamic Type grande.
   - **Por quê:** o `ToastView` corta em 2 linhas e encolhe até 0,85 (`ToastView.swift:28-29`). "Undo" chega a 14 caracteres e "Try again" a 16.
3. **O toast no `UniverseShareSheet`** (a sheet tem a altura do conteúdo): aparece ou fica coberto?
4. **First star com uma primeira take importada do Fotos:** o editor e a história pedem a tela no mesmo instante. Qual vence?
5. **O cartão Continue posting junto com a dica de voz em Takes:** os dois se sobrepõem?
6. **Ao fechar a revisão:** o convite, o anúncio da viagem e a dica disparam juntos. O toast é marcado como dito embaixo da sheet do convite?
7. **TipKit:**
   - Depois de "Delete my Cue data", `statusUpdates` registra fechamentos que não aconteceram? Três deles pausariam tudo por 14 dias.
   - A dica fica presa depois de uma pergunta com várias respostas?
8. **Onboarding:**
   - Mudar a permissão nos Ajustes do iOS em 1.5 encerra o app?
   - Um toque duplo em "Try the teleprompter" cria dois roteiros?
9. **VoiceOver:** as dicas flutuantes não são anunciadas ao chegar. Só os toasts anunciam (`ToastService.swift:46`). Como isso soa na prática?
10. **Contraste** das dicas de vidro sobre o céu, medido no pior ponto da imagem renderizada (`tools/contrast/audit.py`). Os tokens já passam: `ink2` sobre o cartão da dica dá 5,1:1.
11. **Blur:** crop junto com espelhar mantém as áreas no lugar?

---

## 4. Sugestões do revisor: aceitas, adaptadas, rejeitadas

| Sugestão | Decisão | Por quê |
|---|---|---|
| Uma sugestão por contexto | **Aceita**, com escopo maior | Confirmado (C1–C3). O porteiro cobre também o cartão da Ultra e o Continue posting. Ele **reaproveita** os portões que já existem (`isForegroundBusy`, `isQuiet`, `introsThisSession`, `tipDays`) numa função só, sem infraestrutura nova |
| Nada substitui de imediato após um fechamento | **Aceita** | C1 e C2. Depois de um fechamento, nenhuma outra sugestão na mesma tela pelo resto da sessão |
| Revalidar antes de mostrar | **Aceita** | Já é feito em 4 lugares. Falta no convite `readyScript` (B5) e na introdução adiada (C5) |
| A celebração tem prioridade | **Adaptada** | Ganha no **fim de uma tarefa**, nunca por cima de uma ação de abertura (`.edit`, `.pickBest`, `.share`) (C6) |
| Um significado por gesto: ✕ fecha · "Agora não" adia · "Não sugerir novamente" sai · "Ocultar guia" é reversível | **Aceita**, no lugar do meu "um prazo por gesto" | O código já está quase assim. "3 dias para tudo" pesaria o ✕ da viagem e deixaria um ✕ de qualquer fonte pausar a voz |
| "O segundo Agora não é para sempre" (da minha proposta) | **Rejeitada nas introduções** | Tornaria permanente um não que hoje expira (2 em 90 dias), sem tela para desfazer. No convite, já é o limite atual de 2 |
| "Não sugerir novamente" em Settings › Notifications | **Adaptada** | Uma lista reversível de ferramentas ocultas. O lugar depende da decisão 4 (§6) |
| Corrigir o TipKit | **Aceita** | D1 e D2. Contar só a dica visível (status `.available`) e só fechamentos de verdade. Colar um exemplo é neutro |
| Undo e trabalho independentes da duração do toast | **Aceita, sem infraestrutura nova** | É o padrão da biblioteca: o item removido fica no serviço até sair da tela ou até o próximo lançamento. O take só é apagado ao sair da revisão. O editor fica como está |
| Fila de toasts (da minha proposta) | **Rejeitada** | No editor, o Undo do toast é "desfazer o último". Com fila, o Undo visível desfaria outra coisa, e o take apagado voltaria sem vídeo. A regra fica menor: **um resultado assíncrono não toma o lugar de um toast com botão** (A1, B2) |
| Toasts nas sheets | **Aceita** | Estender o `toastHost(inSheet:)` às 4 sheets e aos covers de celebração (F4) |
| "Try again" no toast | **Adaptada** | Botão só onde o contexto sobrevive: ferramenta de reescrita, Ultra fora das falhas de rede, rascunho da estrela. Falha de exportação vira cartão. Rejeitado em voice-over, código do Remote e login |
| O botão que confirma a si mesmo | **Aceita, já existe** | O "Ready to travel" já mostra "✓ Saved to Photos" (`ReadyToTravelView.swift:154-157`). Sai o toast repetido, e a cota de exportações grátis vai para o cover |
| Tirar toasts de mudanças que a prévia já mostra | **Aceita**, 8 casos | "Captions format: X", "\(name) on this text", "Places swapped", "Line split", "Line break added", "Joined with next line", "Mask removed/reset", "Look pasted" |
| Manter retorno em ações invisíveis | **Aceita** | Copiar, "Music added at 0:12", "…on every text", "Stabilize on every clip", "the video is 2.1s longer". A contagem cancelada e o Disconnect do Remote ganham só um anúncio de VoiceOver, sem toast |
| Manter as diferenças entre os textos de "salvo" | **Aceita** | Os textos de lembrete trazem informação distinta (`ReminderFeedback.swift:14-23`). "Saved in Takes · export with Pro anytime" é o que fica depois de fechar a sheet |
| Menos tutoriais fixos nos painéis | **Aceita** | Cerca de 40 dos 72 `PanelNote` são tutoriais: mostrar uma vez ou encurtar. Os cerca de 21 avisos de consequência ficam. `PanelNote` passa a usar `cueFont` (`PanelNote.swift:15`) |
| Dicas em versão compacta | **Aceita** | A nova dica de voz fica com a pergunta mais uma linha, sem crescer em relação à atual |
| 28/60 caracteres como guia editorial | **Aceita** | Medidos em inglês. Nunca cortam nem encolhem a letra. Valem com o teste do item 2 do §3 |
| Canais diferentes não são incoerência | **Aceita** | O R4 ("uma forma por camada") fica, mas não obriga tudo a ser igual |
| Primeira jornada mais simples | **Adaptada** | Pick conta sozinho com um take. Polish já tem Skip. O efeito colateral das legendas deixa de contar (G2). A importação do Fotos conta só Record. O demo depende da decisão 5. Sem Skip no onboarding |
| Uma estrela por vídeo, redes como destinos | **Já é o código** | `MilestoneService` conta um vídeo uma vez, e cada rede soma no planeta. Não há impacto nos dados |
| Ícones por marco acumulado, ano como retrospectiva | **Aceita** (decisão 2) | Corrige o B4. Os registros já têm data, e a chave `year*1000+m` vira marco da vida. Sem usuários ainda, não há o que migrar |
| Celebração única que nunca perde nem repete | **Aceita** | Corrigir o B3. A conquista já é registrada separada da história |
| Háptico na chegada da dica, no cancelar/sair e em todo pequeno sucesso | **Rejeitada** | A dica chega sozinha, e vibrar sem um gesto da pessoa interrompe. A regra atual está certa: o ✓ comum não vibra e `success` só vem quando um trabalho termina. Saem os novos `tipArrive` e `stepDone` da prancha 05 |
| "Um háptico por história" contra o sucesso no pouso e no ícone | **Resolvida** | Um `success` por história, no ponto mais alto: na abertura do ícone quando há marco, senão no pouso da estrela. O pouso leva `light`. Hoje o send-off (`SendOffView.swift:165`) e o marco (`MilestoneView.swift:204`) vibram com 0,6 s de distância |
| Remote só no Pro | **Decidido (30/10): fica livre** | Decisão do dono. Não muda nada na comunicação do Remote |

---

## 5. Alterações propostas nas pranchas

Nada foi alterado ainda. Aplico quando você aprovar. O protótipo não é tocado.

- **02 · O que melhorar**
  - Entram os confirmados: A1–A3, B1–B7, C5, D1–D2, E1–E7, F1–F4, G1–G3.
  - Sai a fila de toasts como solução.
  - O Watch fica marcado como "base não distribuída".
  - A Ultra fica marcada como "só Debug, intencional".
- **03 · Proposta · Linguagem**
  - **R1:** a ordem passa a ser "celebração no fim da tarefa › dica no lugar › dica flutuante › convite". O porteiro inclui a Ultra no dock e o Continue posting, e ganha três regras: não substituir após um fechamento, revalidar antes de mostrar, e o que foi visto no lugar não volta flutuando.
  - **R6:** vira "um significado por gesto", e a tabela de prazos sai. O "fechar a história conta como vista" fica.
  - 28/60 aparece como guia editorial.
- **04 · Proposta · Componentes**
  - Try again só nos 3 casos.
  - Cartão de falha de exportação, inclusive depois da compra.
  - Cartão de Fotos desligado na fila.
  - Aviso das legendas que faltam no cover.
  - Sai o toast "Saved to Photos" do Save, e a cota vai para o cover.
  - Dica de voz compacta.
  - Paywall só com o que é Pro.
- **05 · Proposta · Movimento**
  - O passo concluído se transforma dentro da dica **só nas dicas no lugar**: Practice na página, Pick na revisão, Polish no editor. Record e Share terminam no prompter ou na revisão: lá fica o silêncio, e a próxima dica vem depois.
  - "O botão confirma a si mesmo" aparece como algo que já existe.
  - Saem a fila, `tipArrive` e `stepDone`.
  - A frase sobre o háptico do ✓ é corrigida.
  - Um `success` por história, como descrito no §4.
  - Entra o anúncio de VoiceOver para as dicas flutuantes.
- **07 · Convites:** o `readyScript` só sai da própria página. O convite fica fora da primeira viagem (decisão 3). O botão "Allow" de "Want a reminder…" cumpre o que diz.
- **06 · Notificações:** o "Turn on" de Settings conforme a decisão 1.
- **08 · Dicas:** as regras de contagem do TipKit (D1, D2) e o ✕ que não chama outra dica.
- **09 · Primeira viagem:**
  - Pick automático com um take, e a cópia da dica sem "the others".
  - O progresso sem efeitos colaterais (G2).
  - O que foi visto no lugar não repete.
  - A primeira gravação passa de 5 recados para 2: a história e o Pick no lugar.
- **10 · Onboarding:** o capítulo é guardado a partir de 1.4 (A3).
- **11 · Celebrações:** o marco não repete (B3), o marco passa a ser acumulado e o ano vira retrospectiva (B4), e um háptico por história.
- **14–15 · Toasts 3–4:** saem os 8 toasts do editor que a prévia já mostra.
- **20–22 · Avisos 1–3 e 24 · Gravação 1:** os textos honestos de E1, E2, E4 e E5.
- **23 · Espera:** "Checking the facts" → "Checking the claims", e "Cancel" → "Stop" no tracking do Blur.
- **26 · Pro e limites:** a lista de benefícios real e a Ultra só em Debug.

---

## 6. Decisões do dono (30/10/2026, noite)

Todas tomadas. As que divergem da recomendação estão com as palavras do dono.

1. **"Turn on" em Settings › Notifications:** liga só o que foi tocado. A rotina vira uma escolha explícita, com o horário visível. *(Como recomendado.)*
2. **Marcos acumulados:** 1, 10, 25 e 50 vídeos na vida, ligados ao ícone. O ano fica como retrospectiva em Your universe. *(Como recomendado.)*
3. **Convite de notificações:**
   - sai da primeira viagem;
   - aparece na **próxima sessão, num contexto útil**, e nunca logo depois da celebração do primeiro compartilhamento;
   - quando a pessoa pede um lembrete por conta própria, a permissão pode ser pedida naquele momento.
4. **Introduções no app:** deixam de depender da notificação "Tools and news". A lista reversível das ferramentas ocultas por "Don't suggest this" fica em Personalize. *(Como recomendado.)*
5. **Roteiro de demonstração:**
   - conta, e o passo passa a se chamar **"Prepare your first script"**;
   - a prática conta **só se aconteceu de verdade**;
   - importar um vídeo leva direto à edição, sem dizer que a pessoa escreveu, ensaiou ou gravou no Cue.
6. **Onboarding interrompido:** o capítulo fica guardado e é retomado de onde parou. Sem Skip. *(Como recomendado.)*
7. **Roteiros e ideias apagados:** **sem "Recently deleted"** (o dono reverteu em 31/10/2026, depois de ver a tela no iPhone: "deletou tá deletado"). Apagar é para sempre; só o Undo do toast (4 s, que não se perde num toque) traz de volta.
8. **Textos honestos** (nos 20 idiomas, com traduções naturais):

   | Hoje | Novo (EN, como a interface) | Ideia do dono (PT) |
   |---|---|---|
   | "✓ Monetizable" | "Length goal met · 1:00" | "Meta de duração atingida · 1:00", sem prometer monetização |
   | "Fits TikTok" | "Within the target length" | "Dentro da duração-alvo" |
   | "Sounds like you" (85%) | "Profile 85% filled" | "Perfil 85% preenchido"; "Perfil completo" só com 100% |
   | "Checking the facts" | "Reviewing the draft" | "Revisando o rascunho" |
   | "Cancel" no tracking do Blur | "Stop" | "Parar" |

9. **"Checked":**
   - o aviso volta depois de uma reescrita pela IA;
   - fica registrada a conferência **daquela versão do texto**, com data;
   - o botão passa a querer dizer "I reviewed the claims";
   - se for só para esconder o aviso, não é registrado como conferido.
10. **Remover um lembrete:** toast com **Undo**, com o anúncio do VoiceOver. O Undo segue a mesma proteção dos outros: um resultado que chega depois não toma o lugar dele.
11. **TipKit depois de "Delete my Cue data":** uma "geração" na id da dica. *(Como recomendado.)*
12. **Lista do Pro:**
    - só benefícios reais e disponíveis;
    - **nenhuma** função gratuita é trancada agora só para justificar a lista;
    - a Ultra AI entra quando estiver disponível;
    - "gravação de tela sem marca d'água" precisa ficar bem separada das exportações comuns gratuitas, para não parecer que elas saem com marca d'água.

**Continuam valendo:**
- A animação de abertura do Pro aparece em toda abertura.
- O Remote fica livre para todos.
- O onboarding continua sem Skip.

## 7. Ordem de implementação

Por impacto e dependência. Cada etapa sai com testes (Swift Testing e XCUITest), os textos nos 20 idiomas e o DESIGN_PROJECT atualizado.

1. **Bugs que perdem trabalho ou mentem.** São pequenos, independentes e não precisam de decisão:
   - A1: um resultado assíncrono não substitui um toast com botão;
   - B2: o aviso de trabalho não vira o resultado de outra operação;
   - B1: a ordem do `hasCaptions`;
   - B3: o marco volta a nil;
   - C5: a introdução adiada;
   - B5: o `readyScript` só na página;
   - D1, D2: a contagem do TipKit;
   - G2: o efeito colateral das legendas.
2. **Undo que não depende do toast** (A2), no padrão que a biblioteca já usa. Inclui o take apagado só ao sair da revisão.
3. **Avisos que ficam na tela** (F1–F4):
   - o cartão de exportação falha;
   - Fotos desligado na fila;
   - as legendas no cover;
   - os hosts de toast nas sheets e nos covers;
   - sai o "Saved to Photos" repetido.
4. **O porteiro.** Depende das decisões 1, 3 e 4. É uma função com os portões de hoje, com as regras do §4: não substituir após fechar, revalidar, o que foi visto no lugar não repete, e a celebração no fim da tarefa (C1–C6).
5. **Promessas e Pro.** Depende das decisões 8, 9 e 12:
   - os textos honestos (E1–E6);
   - a lista do Pro.
6. **Menos excesso:**
   - os 8 toasts do editor;
   - os tutoriais dos painéis;
   - a dica de voz compacta;
   - o anúncio de VoiceOver das dicas;
   - o háptico único na história.
7. **A primeira viagem e os marcos.** Depende das decisões 2, 5 e 6:
   - Pick com um take;
   - a primeira gravação com 2 recados;
   - o onboarding retomável;
   - os marcos acumulados.

---

## Onde esta revisão muda a minha proposta

- **O porteiro continua,** mas a celebração deixa de ser sempre a primeira, e ele passa a cobrir também a Ultra e o Continue posting.
- **"Um prazo por gesto" vira "um significado por gesto",** e o "segundo Agora não = para sempre" sai das introduções.
- **A fila de toasts sai.** No lugar, uma regra só: um resultado assíncrono não toma o lugar de um toast com botão. O Undo deixa de depender do toast.
- **Os hápticos novos saem,** e a prancha 05 tinha uma afirmação errada sobre o ✓. Fica um `success` por história.
- **O passo concluído dentro da dica** só funciona nas dicas no lugar.
- **"A estrela pertence ao compartilhamento"** já é como o código conta. O que muda são os marcos, que passam a ser acumulados.
- **Entra uma camada nova, de textos honestos** (Monetizable, Fits, Checked, Checking, Cancel, Sounds like you), que a proposta não tinha.
- **Pro:** a lista do paywall fica só com o que é verdade. O Remote continua livre.
