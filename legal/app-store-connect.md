# App Store Connect: o que preencher para o lançamento

Tudo bate com a política publicada (https://appoliumlabs.web.app/cue/privacy; fonte: `AppoliumLabs/site/src/cue/privacy.html`) e com
`Cue Studio/SupportFiles/PrivacyInfo.xcprivacy` (conferido em `PrivacyDisclosureTests`).

## 1. Endereços

O app já abre a política (`Cue Studio/SupportFiles/AppLinks.swift`, `privacyPolicy`: Settings › About, Settings › Privacy & AI data e o
Privacy do paywall). **Publique a página antes de enviar o build** (sem a nota de rascunho nem os "to confirm").

| Campo | Onde | Valor |
|---|---|---|
| **Privacy Policy URL** | App Information (o mesmo em todos os idiomas) | https://appoliumlabs.web.app/cue/privacy |
| **Support URL** | página da versão, em cada idioma | https://appoliumlabs.web.app/cue/support |
| **Marketing URL** (opcional) | página da versão, em cada idioma | https://appoliumlabs.web.app/cue |

## 2. App Privacy (o rótulo "Privacidade do app")

**App Store Connect › seu app › App Privacy › Get Started / Edit.** "Do you or your third-party partners collect data from this app?" → **Yes**.

Marque exatamente estes tipos (os demais ficam desmarcados):

| Tipo (como aparece no formulário) | Uso (Purposes) | Ligado à identidade? | Rastreamento? | Por quê |
|---|---|---|---|---|
| **Location › Coarse Location** | Analytics | No | No | O Firebase Analytics deduz uma localização aproximada do IP mascarado, só com "Help improve Cue" ligado |
| **User Content › Other User Content** | App Functionality | No | No | O pedido da Ultra AI vai à Anthropic pelo servidor do Cue |
| **Identifiers › Device ID** | App Functionality, Analytics | No | No | O id aleatório da instalação (contagem da Ultra e convites, sem pedir de novo os grátis) e o app instance ID do Firebase Analytics (só com a chave ligada). Não o IDFV (desligado no Info.plist, `GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED`) nem o IDFA |
| **Purchases › Purchase History** | App Functionality, Analytics | No | No | Com o Pro, o registro da compra vai ao servidor para contar os roteiros da Ultra; com a chave ligada, o Firebase Analytics registra as compras sozinho (`in_app_purchase`: produto, preço e moeda) |
| **Usage Data › Product Interaction** | Analytics | No | No | Firebase Analytics, só com "Help improve Cue" ligado |
| **Diagnostics › Crash Data** | App Functionality, Analytics | No | No | Crashlytics, só com a chave ligada (o manifesto do próprio Crashlytics diz App Functionality) |
| **Diagnostics › Performance Data** | App Functionality, Analytics | No | No | Travamentos e desempenho (MetricKit), só com a chave ligada |
| **Diagnostics › Other Diagnostic Data** | App Functionality, Analytics | No | No | Falhas da IA do aparelho, do editor e das exportações, só com a chave ligada |

Notas:
- **Não** marque Contact Info, Precise Location, Contacts, Browsing/Search History, Sensitive Info, Financial Info, Health, Audio/Photos/Videos
  (vídeos, áudio e fotos nunca saem do aparelho; o que você posta vai pelo app que escolher, não pelo Cue; o pagamento é da Apple).
- **Tracking: No** em tudo. O Cue não usa o IDFA (o Firebase é o `FirebaseAnalyticsCore`, sem identificador de publicidade) e não manda o IDFV.
- Dados opcionais (a chave desligada no início) **ainda contam** como coletados no rótulo: a Apple pede que se declare o que pode ser coletado.
- O Firebase Analytics não traz manifesto de privacidade próprio nesta versão do SDK (12.19): o do Cue declara por ele.

## 3. Ultra AI e a regra 5.1.2(i) (IA de terceiros)

Nada a preencher num campo próprio. O app pede permissão antes do primeiro envio e diz que vai à Anthropic. Escreva nas **App Review
Information › Notes**:

> Ultra AI is an optional script writer powered by Anthropic's Claude. The app never calls Anthropic directly: each request goes to our own
> server (Google Cloud Functions, run by us), which holds the API key, counts the install's scripts and forwards the request to Anthropic.
> Nothing is sent until the user allows Ultra AI on its permission screen ("Meet Ultra AI"), which names Anthropic; Apple Intelligence stays
> the default writer. Every install gets 3 free Ultra AI scripts; Cue Pro adds 30 a month. To try it: Scripts tab › tap the writer chip in
> the idea field at the bottom and pick Ultra AI › allow it on the permission screen › type an idea and send. Settings › Privacy & AI data ›
> What Ultra AI sends lists what is sent and shows the requests word for word; the Ultra AI switch there turns it off. The app has no account
> system: scripts and videos stay on the device. Usage data and crash reports are off unless the user turns on "Help improve Cue".
> Privacy policy: https://appoliumlabs.web.app/cue/privacy

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
