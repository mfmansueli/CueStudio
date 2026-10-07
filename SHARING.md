# Cue Studio — Compartilhar e contar exportações

Como um vídeo sai do Cue, quando uma das 5 exportações grátis é descontada e o que cada plataforma permite de verdade. Leia com
`ARCHITECTURE.md` e `DESIGN_PROJECT.md` (a tela "Share to" não mudou de layout).

## 1. A regra de contagem

Uma exportação grátis é descontada **uma vez por operação** (um arquivo exportado), na primeira vez que o vídeo **comprovadamente sai do Cue**
(`DeliveryEvidence`):

| Acontece | Desconta? |
|---|---|
| Salvo na biblioteca de fotos (**Save video**, ou a cópia que TikTok/“salvar e abrir” precisam) | **Sim**, mesmo que nunca seja publicado |
| Uma atividade da folha de compartilhamento terminou (`completed == true`) | **Sim** (qualquer atividade: o arquivo saiu do Cue) |
| Instagram: vídeo na área de transferência **e** o compositor abriu (`pasteboardHandoff`) | **Sim**: o vídeo saiu da mão do Cue. Se o Instagram não abre, a área de transferência é limpa e **não** desconta |
| O Share Kit do TikTok respondeu sucesso (ou “salvo como rascunho”) | **Sim** (na prática já descontado pelo salvamento em Fotos) |
| Só abrir o app da plataforma, sem vídeo (salvar e abrir já contou pela cópia em Fotos) | Não |
| Preparar o arquivo (renderizar), reaproveitar um arquivo | Não |
| Cancelar antes da entrega, fechar a folha, erro | Não |

- **Uma vez só:** `ExportLedgerService` guarda cada operação (`ExportOperation`, JSON em Application Support) com `countedAt`. Salvar e depois
  compartilhar o mesmo arquivo, callbacks repetidos, tentativas e a volta do app depois de fechado não descontam de novo. O razão é gravado
  **antes** da cota (Keychain): se o app morrer entre os dois, no pior caso uma exportação deixa de ser contada, nunca é contada duas vezes.
- **Mesmo arquivo:** `ExportFingerprint` (SHA-256 do take, da edição, do formato, das legendas, da qualidade e do arquivo gravado) decide se o
  arquivo já exportado serve de novo. Qualquer mudança gera outra operação, que segue a cota normal. Um arquivo que o sistema apagou é refeito
  **na mesma operação** quando o criador compartilha de novo a partir de "Ready to travel".
- **Uma operação já contada nunca pede a cota de novo:** com 0 exportações grátis sobrando, ainda dá para compartilhar o vídeo que acabou de
  ser salvo; uma edição diferente abre o paywall.
- O contador no Keychain (5 grátis) não foi tocado: o uso existente vale, e reinstalar não devolve exportações.
- **Limpeza:** `leave()` (ao fechar a revisão sem nada em andamento) apaga o arquivo temporário; ao abrir o app, arquivos com mais de 24 h somem
  e registros com mais de 7 dias também. O arquivo fica enquanto a folha de compartilhamento, a celebração ou uma exportação precisam dele.

Caminhos de exportação (todos passam pelo razão): **Take Review** (`TakeReviewViewModel`: Save video, tiles de plataforma, More, "Ready to
travel" › Share to / Other apps, "On its way" › Share again, e o "download" do fim do editor), **Quick edit** (`QuickEditExportModel`:
Export video, Share). `saveCoverIfChosen` salva só uma imagem e nunca conta. O compartilhamento de roteiros (texto) e do universo (imagem) não é
exportação de vídeo.

## 1.1. "Share to universe" (fase A): uma exportação por envio, uma rede por vez

O botão amarelo da revisão renderiza o arquivo uma vez (`ExportAction.render`: nada sai, nada conta) e a fila (`ShareQueue`) leva o **mesmo arquivo** a cada rede escolhida, pela **folha de compartilhamento do sistema**
(`ShareIntegrationConfiguration.integrationsEnabled = false`: `ShareRouteResolver` devolve `.activitySheet` para todos). Conta **uma** exportação: quando o arquivo sai (salvo em Fotos pela opção "Also save to Photos", ou a primeira atividade
concluída), nunca por rede; editar e reexportar dentro da fila herda a contagem (`ExportLedgerService.begin(inheritingCountFrom:)`). Uma atividade concluída pergunta "Posted on {rede}?": só **Yes, it's live** marca a rede como postada,
grava o `ShareRecord` (plataforma, data, tema) e acende o planeta; **Not yet** volta ao passo; cancelar a folha também. O Cue nunca afirma que algo foi publicado sem a resposta do criador.

## 2. Estados (`ExportPhase`) e mensagens

`idle → preparing → savingToPhotos → delivering(destino?) → delivered(evidência) | cancelled | failed`. **Não existe estado "publicado"**:
nenhuma plataforma avisa o momento da publicação, então nenhuma mensagem diz "postado". "Ready to post on X" fala do vídeo (salvo e pronto), "Shared
with X" diz que o app recebeu, "Opened X with your video · Cue can't see if you post it" diz que só abriu. A tela de envio ("On its way") só
aparece quando há entrega comprovada **para aquele app** (Share Kit; ou uma atividade da folha cujo identificador é do app tocado). Abrir o
app (salvar e abrir, Instagram) mostra "Ready to travel" (salvo) ou só o aviso, nunca a celebração do envio. Os marcos (`recordShare`) contam só
envios com entrega.

## 3. Rotas por destino (`ShareRouteResolver`, puro e testado)

| Destino | Rota | Evidência de entrega | Sem configuração / app ausente |
|---|---|---|---|
| TikTok | **Share Kit** (`TikTokShareManager`): salva em Fotos, manda o `localIdentifier` do asset | callback do Share Kit (`errorCode == 0` e `shareState` 20000/20015) | sem client key/redirect URI: **salvar e abrir**; sem app: folha do sistema |
| Instagram Reels | `instagram-reels://share` + vídeo na área de transferência (`com.instagram.sharedSticker.backgroundVideo`, expira em 5 min) | **nenhuma** (a Meta não dá callback). O vídeo vai para a área de transferência local e o compositor abre com ele; **não sobe para a rede** até a pessoa tocar em compartilhar lá. Conta como saída do Cue (`pasteboardHandoff`), sem celebração | sem Meta App ID, vídeo fora de 3–60 s: salvar e abrir |
| Instagram Stories | `instagram-stories://share?source_application=<ID>` + o mesmo item | **nenhuma** (idem) | sem Meta App ID, vídeo > 20 s: salvar e abrir |
| YouTube / Shorts | folha do sistema (a extensão de compartilhamento do app do YouTube, quando a versão instalada tem) | atividade concluída | app ausente: folha do sistema |
| LinkedIn | **só salvar em Fotos** e avisar "Saved to Photos · Open LinkedIn to post it" (não há integração documentada que receba um vídeo; o app não é aberto) | — (a cópia em Fotos conta) | sem Fotos: folha do sistema |
| More | folha do sistema | atividade concluída | — |

Permissões de Fotos: o Cue só tem **adicionar** (`NSPhotoLibraryAddUsageDescription`). O identificador do asset vem do placeholder da própria
criação, que não precisa de leitura; quem lê o vídeo pelo identificador é o **app do TikTok**, com a permissão dele (o SDK responde
`noPhotoLibraryPermission` se faltar). O SDK não toca a biblioteca. **Não pedimos acesso de leitura**; se a validação em aparelho mostrar que o TikTok não
acha o asset com acesso só de adição, a mudança é pedir `.readWrite` apenas na rota do Share Kit. Sem acesso a Fotos, os destinos usam a folha do
sistema, que recebe o arquivo direto.

## 4. O que falta (configuração externa) — nada abaixo está validado

As integrações vêm **desligadas**: as chaves em `SupportFiles/Info.plist` estão vazias e a rota cai no fallback honesto. Nenhuma credencial
foi inventada.

1. **TikTok Share Kit** (TikTok for Developers):
   - registrar o app, adicionar o produto **Share Kit** e obter a **Client key** → `TikTokClientKey` no Info.plist **e** adicionar a mesma chave
     em `CFBundleURLTypes › CFBundleURLSchemes`;
   - um **universal link** do Cue (domínio com `apple-app-site-association`) registrado como redirect URI → `TikTokShareRedirectURI`, mais o
     entitlement **Associated Domains** (`applinks:<domínio>`) em `Cue Studio.entitlements`;
   - a aprovação do app/Share Kit pela TikTok. Sem ela o app do TikTok não devolve resultado.
   - O SDK (`tiktok-opensdk-ios` 2.5.0, SPM) já está no projeto e o callback já entra por `onOpenURL`/`onContinueUserActivity` (`RootView`).
2. **Instagram Reels / Stories** (Meta for Developers):
   - criar um app Meta, deixá-lo **Live**, e colocar o **App ID** em `MetaAppID`. A página de Reels exige o App ID e o app em produção.
   - A página de Stories lista vídeo de fundo na tabela de formatos mas só mostra código iOS para imagem; usamos a mesma chave `backgroundVideo`
     do Reels por analogia. **Confirmar em aparelho.**
3. **YouTube**: o app do YouTube voltou a ter extensão de compartilhamento de vídeo na versão 19.47.7 (relatado pela imprensa, **não** pela
   documentação do Google). Confirmar em aparelho; se não aparecer na folha, o destino precisa virar "salvar e abrir".
4. **LinkedIn**: nenhuma integração pública aceita um vídeo de outro app; o vídeo é só salvo em Fotos e o Cue recomenda postar pelo app.
5. `LSApplicationQueriesSchemes` declara só o que o SDK do TikTok consulta (`tiktoksharesdk`, `snssdk1180`, `snssdk1233`). O Cue não pergunta se um app está instalado: o iOS 27 depreciou `canOpenURL` ("tente abrir e trate a falha"), então o destino é tentado e, se não abre, o vídeo vai para a folha do sistema.

**Validação em aparelho (pendente):** só um iPhone com TikTok, Instagram, YouTube e LinkedIn instalados e as credenciais acima mostra a
entrega de verdade. Os testes automáticos cobrem a contagem, as rotas, o mapeamento dos códigos do TikTok e o que o Cue escreve na área de
transferência; **eles não provam que a plataforma recebe o vídeo** (`DemoVideoSharing`, usado por `-uiTestAppsInstalled`, só existe para ver a tela
de envio no Simulator).

## 5. Limites conhecidos

- Instagram não reporta nada: a contagem vale quando o vídeo foi para a área de transferência e o compositor abriu; o Cue não sabe se o Instagram leu o vídeo nem se a pessoa postou (a mensagem diz só "Opened X with your video · Cue can't see if you post it"). Se a pessoa fecha o Instagram sem usar o vídeo, a exportação já foi contada.
- Qualquer atividade concluída conta (AirDrop, Salvar em Arquivos…), porque o arquivo saiu do Cue; só a atividade do próprio app do destino
  dispara a tela "On its way".
- Uma nova exportação do mesmo take sem mudar nada, depois que o arquivo foi apagado (ao fechar a revisão), é uma exportação nova e desconta.
- O callback do TikTok pode nunca chegar (o criador volta sozinho); a fase fica em `delivering` e nada trava (a UI não espera por ele).
