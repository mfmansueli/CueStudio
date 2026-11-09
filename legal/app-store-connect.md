# App Store Connect: o que preencher para o lançamento

Para o build de `feature/launch-readiness`. Tudo bate com `privacy-policy.md` e com `Cue Studio/SupportFiles/PrivacyInfo.xcprivacy`.

## 1. Link da política de privacidade

1. Publique `privacy-policy.md` (e, se quiser, `politica-de-privacidade.md`) num endereço público e permanente.
2. **App Store Connect › seu app › App Information › Privacy Policy URL**: cole o link (um por idioma, se publicar as duas).
3. Me mande o link: ele entra em `Cue Studio/SupportFiles/AppLinks.swift` (`privacyPolicy`), e as linhas de Ajustes, paywall e privacidade
   passam a abri-lo.

## 2. App Privacy (o rótulo "Privacidade do app")

**App Store Connect › seu app › App Privacy › Get Started / Edit.** "Do you or your third-party partners collect data from this app?" → **Yes**.

Marque exatamente estes tipos (os demais ficam desmarcados):

| Tipo (como aparece no formulário) | Uso (Purposes) | Ligado à identidade? | Rastreamento? | Por quê |
|---|---|---|---|---|
| **User Content › Other User Content** | App Functionality | No | No | O pedido da Ultra AI vai à Anthropic pelo servidor do Cue |
| **Identifiers › Device ID** | App Functionality, Analytics | No | No | O id aleatório da instalação (créditos da Ultra e convites) e o id do Firebase (só com a chave ligada) |
| **Purchases › Purchase History** | App Functionality | No | No | O registro da compra do Pro vai ao servidor para contar os roteiros da Ultra |
| **Usage Data › Product Interaction** | Analytics | No | No | Firebase Analytics, só com "Help improve Cue" ligado |
| **Diagnostics › Crash Data** | Analytics | No | No | Crashlytics, só com a chave ligada |
| **Diagnostics › Performance Data** | Analytics | No | No | Travamentos e desempenho (MetricKit), só com a chave ligada |
| **Diagnostics › Other Diagnostic Data** | Analytics | No | No | Falhas da IA do aparelho e de exportações, só com a chave ligada |

Notas:
- **Não** marque Contact Info, Location, Contacts, Browsing/Search History, Sensitive Info, Financial Info, Health, Audio/Photos/Videos
  (vídeos, áudio e fotos nunca saem do aparelho; o que você posta vai pelo app que escolher, não pelo Cue).
- **Tracking: No** em tudo. O Cue não usa o IDFA (o Firebase é o `FirebaseAnalyticsCore`, sem identificador de publicidade).
- Dados opcionais (a chave desligada no início) **ainda contam** como coletados no rótulo: a Apple pede que se declare o que pode ser coletado.

## 3. Ultra AI e a regra 5.1.2(i) (IA de terceiros)

Nada a preencher num campo próprio. O app já pede permissão antes do primeiro envio e diz que vai à Anthropic. Escreva nas **App Review
Information › Notes**:

> Ultra AI is an optional script writer powered by Anthropic's Claude through our own server. It only runs after the user allows it on the
> permission screen ("Meet Ultra AI"), which names Anthropic. Every user gets 3 free scripts; Cue Pro adds 30 a month. To try it: Scripts tab
> › type an idea in the field at the bottom › tap the writer chip and pick Ultra AI › send. Settings › Privacy & AI data shows exactly what is
> sent and lets the user turn it off. The app has no account system; all scripts and videos stay on the device.

## 4. Export compliance (criptografia)

Responda **"uses only exempt encryption"** (o build já declara `ITSAppUsesNonExemptEncryption = NO`): o controle remoto usa só a CryptoKit da
Apple, e o resto é HTTPS.

## 5. Assinatura

- **Billing Grace Period:** deixe **desligado** no lançamento. Ligado, um assinante no período de carência perde os roteiros mensais da Ultra
  até a renovação (o servidor vê a transação vencida).
- Os textos do paywall listam só o que o Pro realmente dá: exportações sem limite e 4K, os 30 roteiros da Ultra AI por mês, os ícones dos marcos e
  a gravação de tela sem marca.

## 6. Antes de enviar (com o meu OK do servidor)

1. Subir um build do TestFlight desta branch e escrever 2 roteiros com a Ultra (um grátis, um no Pro do sandbox).
2. Eu publico `firebase deploy --only functions:ultra,firestore:indexes --project cuestudio-app` (servidor em `enforce`, TTL das contagens).
3. No **Claude Console › Settings › Limits**, ponha um limite mensal (sugestão: **USD 100**) como segunda rede.
