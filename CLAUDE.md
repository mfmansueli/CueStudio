# Cue Studio

App SwiftUI (projeto Xcode com pastas sincronizadas: a pasta no disco é o grupo no Xcode).

## Arquitetura

Todo código novo ou alterado segue os padrões de @ARCHITECTURE.md: MVVM + Services organizado por
feature, um tipo por arquivo, Design System com tokens, strings localizadas, testes (Swift Testing +
XCUITest) na mesma entrega. Consulte o checklist da seção 8 ao terminar cada feature.

Se algum código existente divergir do documento, vale o documento; ao tocar num arquivo fora do
padrão, corrija-o.

## Design

A fonte de verdade do design é `design/cue-v30/handoff-telas/` (comece por `LEIA-ME.md` e `docs/09-Decisions.md`; as telas em
`screens/*.html` são a referência visual e `ANIMACOES.md` tem o movimento; o pacote anterior, com o protótipo `Cue App v30.dc.html` e os
documentos 01–08, saiu da árvore e continua no histórico do git, commit `bb39f35`). @DESIGN_PROJECT.md diz como o app ficou e onde as decisões foram
tomadas. Atualize-o junto com a UI.

## Contraste (WCAG 2.2 AA, HIG da Apple)

Toda tela, componente ou cor nova **precisa passar** no contraste antes de ser entregue; ao tocar numa cor existente, confira também:

- **Texto:** pelo menos **4,5:1** contra o que realmente está atrás dele (texto grande, de 18 pt ou mais, ou 14 pt em negrito ou mais, **3:1**). Isso vale para textos pequenos, rótulos mono, placeholders, textos legais e para texto sobre vidro, aurora, céu ou vídeo: o fundo é o **pior ponto** da superfície, não o token médio.
- **Partes de controle, ícones que informam e bordas de campo:** **3:1** (WCAG 1.4.11). Só o que é decorativo (setas de disclosure, separadores, pontos) pode ficar abaixo.
- **Use os tokens de texto de `Palette`** (`ink`, `ink2`, `inkHint`, `accText`, `aiText`, `warnText`, …); eles já são medidos em `PaletteContrastTests` com e sem Aumentar Contraste. `ink3` é só para o que não precisa ser lido (nunca para texto). **Não invente** `Color.white.opacity(x)`, `flightInk.opacity(x)` etc. para texto: se um token não serve, crie ou ajuste o token e meça.
- **Meça de verdade:** um token novo entra em `PaletteContrastTests`; uma tela com fundo translúcido (dock, cartões sobre o céu, vidro, onboarding) é conferida na imagem renderizada (`UserReportCaptureTests` / `HandoffCaptureTests` gravam o PNG e a hierarquia; `tools/contrast/audit.py` mede cada texto). Qualquer par abaixo do mínimo é corrigido na mesma entrega, e o relatório final diz o que foi medido.

## Build e testes

- **Build settings em `Config/*.xcconfig`** (`Project`, `App`, `UnitTests`, `UITests`), nunca no `project.pbxproj`: mude o
  arquivo de texto, não o editor de Build Settings do Xcode (ele grava no projeto, e `scripts/check-project.sh` acusa).
- Scheme compartilhado `Cue Studio` (app + `Cue StudioTests` + `Cue StudioUITests`), Swift 6, iOS 27. Testes por planos
  (`TestPlans/`): **Full** (o padrão do ⌘U: unidade + UI), **Fast** (unidade sem as exportações reais, tag `.realExports`) e
  **UISmoke** (um teste de UI por fluxo).
- **Build e testes pelos scripts** (`scripts/`), não por `xcodebuild` solto: um derivedData por checkout (`build/`), pacotes
  compartilhados, **um `xcodebuild` por vez no Mac** (o próximo espera o que está rodando, de outra sessão ou worktree) e só
  erros, warnings e falhas no terminal (o log inteiro fica em `build/logs/`).
  - `scripts/build.sh [tests|app|device|release]` (padrão `tests`: o app e os pacotes de teste no simulador).
  - `scripts/test.sh [fast|smoke|unit|exports|ui|full]`, `scripts/test.sh only "Cue StudioTests/DockFoldTests"`, com
    `--no-build` e `--repeat N`. Durante o trabalho, `fast`, `smoke` (um teste de UI por fluxo, plano `UISmoke`) ou `only`;
    `full` no fim. Testes de aparelho: `CUE_DEVICE=<iPhone>
    scripts/test.sh device <Suite>` (um conjunto por vez; liga a variável `TEST_RUNNER_CUE_…` certa).
  - `scripts/check-warnings.sh`: a conferência de zero warnings (abaixo).
  - `scripts/check-project.sh`: em segundos, confere `project.pbxproj`, os `.xcconfig`, o scheme e os planos de teste.
  - `scripts/strings.py`: o String Catalog sem editar o JSON à mão (`add` com os 20 idiomas, `missing`, `stale --remove`).
- **Zero warnings.** Todo build termina sem nenhum warning (compilador, SwiftLint, ferramentas do
  Xcode): se um build mostrar um warning, corrija na mesma entrega, mesmo que não tenha vindo da sua
  mudança. Build incremental não repete warnings de arquivos não recompilados: antes de dar por terminado, rode
  `scripts/check-warnings.sh`, que recompila o app e os testes do zero para o simulador, para o aparelho (o SDK dele acusa
  outras coisas, como anotações de concorrência) e em Release.
- **Sessões em paralelo** trabalham cada uma num git worktree (`.claude/worktrees/`), nunca duas na mesma pasta. Os scripts
  já separam o derivedData por worktree e enfileiram os builds.
- **Diagnósticos do editor:** `scripts/lsp-setup.sh` (uma vez por checkout ou worktree; precisa de
  `brew install xcode-build-server`) faz o SourceKit-LSP ler o build de verdade, em vez de acusar os tipos do projeto como
  ausentes.
- **SwiftLint** (`brew install swiftlint`) roda em todo build do app (Build Phases › SwiftLint) com
  `.swiftlint.yml`. Corrija o código em vez de afrouxar a configuração; `swiftlint --fix` resolve
  parte, mas revise o formato do que ele muda.
- **Firebase** (projeto `cuestudio-app`, SPM `firebase-ios-sdk`): só Analytics (`FirebaseAnalyticsCore`, sem IDFA) e
  Crashlytics, iniciados em `Managers/Telemetry/TelemetryManager.swift`, o único arquivo que importa o SDK. Testes de
  unidade, de UI (`-uiTestInMemory`) e previews não enviam nada (`TelemetryPolicy`). O upload dos dSYMs roda só em
  archive (Build Phases › Upload dSYMs to Crashlytics). Para ver eventos no DebugView: `-FIRAnalyticsDebugEnabled`.
  Falhas do Apple Intelligence (`AIFailureReport`): cada tentativa que falha vai para o Console (`studio.cue` / `ScriptAI`) com o motivo exato do
  framework (guardrailViolation, timeout, concurrentRequests…) e as condições (modelo pronto, calor, Low Power, memória, app em primeiro plano,
  aparelho); a que chega ao criador vira um non-fatal no Crashlytics (`AppleIntelligence.<operação>.<motivo>`). Nunca o texto.
- O build Release também precisa compilar: previews usam dados de `SupportFiles/Debug/` e ficam em `#if DEBUG`.
- Launch arguments (só em Debug, ver `SupportFiles/LaunchOptions.swift`): `-uiTestInMemory` (armazenamento
  em memória), `-uiTestSeedSamples` (scripts de exemplo), `-uiTestPro` (começa no Cue Pro),
  `-uiTestSampleVideo` (vídeos reais pequenos atrás dos takes de "3 morning habits", para o Quick edit),
  `-uiTestRemoteConnects` (um iPad de mentira entra logo depois do pareamento do Remote Control),
  `-uiTestAppearance <light|dark>` (as telas do Cue começam claras ou escuras, como em Settings › Appearance),
  `-uiTestAppLanguage <lproj>` (a interface começa nesse idioma, em memória, sem mudar o simulador).
  v27: `-uiTestOnboarding`, `-uiTestPermissions granted|denied`, `-uiTestSky off|calm|lively` (off por padrão nos testes), `-uiTestAppsInstalled` (os apps das plataformas contam como instalados e "recebem" o vídeo, só para ver a tela de envio; ver `SHARING.md`),
  `-uiTestCatalogue <seção>` (a seção `transition` mostra a estrela; ver `DESIGN_PROJECT.md`).
  v30: `-uiTestVoiceTip` (abre as portas da dica do My Cue Voice), `-uiTestStarTransition` (a estrela da ideia mantém os tempos reais; nos testes de UI ela é encurtada)
  e `-uiTestSlowWriting` (com o roteirista de teste, as palavras chegam devagar na página).
  `-uiTestExportsLeft <0…5>` (quantas exportações grátis restam; 0 abre "Your video is ready"), `-uiTestWelcomeAt <s>` / `-uiTestProAt <s>` (congelam a abertura da 1.1 / do Pro nesse segundo), `-uiTestUniverse sample|newYear|newAccount` (o que o Your universe guarda, como o painel APP DATA do protótipo), `-uiTestFirstStar` / `-uiTestMilestone <n>` (a revisão abre direto na história da 1.7 / do 8.3), `-uiTestSendOffAt <s>` (congela o send-off 8.2), `-uiTestStoryAt <s>` (congela o 8.3 e a 1.7), `-uiTestFakeShareSheet` (um substituto com Complete/Cancel no lugar da folha de compartilhamento do sistema), `-uiTestShareQueue` (uma fila do Share to universe deixada para o take de exemplo: o card Continue posting),
  `-uiTestOnboardingStep welcome|universe|voyage|script|voice|practice` (com `-uiTestOnboarding`, o primeiro voo abre nesse capítulo), `-uiTestChapterAt <s>` (congela a abertura do capítulo na tela, 1.2 a 1.6, nesse segundo),
  `-uiTestWelcomeOpening` (a abertura da 1.1 toca inteira, ≈ 8 s; nos testes de UI ela mostra só o estado final).
  Testes de UI: `-uiTestFastAnimations` (nada anima: sheets, pushes e as transações do SwiftUI; o `CueApp.launch` passa por padrão
  e `animations: true` pede as reais).
- Idiomas: `LOCALIZATION.md` (três idiomas independentes, terminologia, RTL). Todo texto novo entra
  nos 20 idiomas dos String Catalogs. O teste de fala de verdade é opt-in:
  `TEST_RUNNER_CUE_SPEECH_E2E=1 xcodebuild … -only-testing:"Cue StudioTests/VoiceFollowingSpeechTests" test`,
  num aparelho: o Simulator lista os idiomas mas não roda o reconhecimento de fala. Com o mesmo
  flag, `-only-testing:"Cue StudioTests/VoiceFollowingLatencyTests"` mede a latência do Voice
  Following no aparelho (uma gravação tocada em tempo real pelo caminho de áudio da câmera: voz →
  indicador, palavra → texto p50/p95, quanto o texto se adianta, sala com ruído) e
  `VoiceFollowingSpeechTests/availabilityOnThisDevice()` lista os 20 idiomas sem baixar nada.
- Mais testes opt-in no aparelho (um conjunto por vez, com o iPhone desbloqueado e a tela acesa: o modelo da Apple é limitado em segundo plano e dois
  conjuntos de fala disputam os 5 idiomas): `TEST_RUNNER_CUE_SPEECH_E2E=1 … -only-testing:"Cue StudioTests/CaptionSpeechTests"` (legendas: o que foi
  ouvido, tempos, sincronia) e `TEST_RUNNER_CUE_AI_E2E=1 … -only-testing:"Cue StudioTests/LanguageModelDeviceTests"` ou `…/ScriptGenerationFlowDeviceTests`
  (Apple Intelligence de verdade: idioma do resultado, tradução, My Cue Voice, o fluxo do card até o script salvo). Um idioma que o aparelho não roda
  aparece como **não validado** (teste cancelado), nunca como aprovado. Resultados e limites: `LOCALIZATION.md` §5.
- A prévia do Quick edit tem uma medição opt-in no aparelho: `TEST_RUNNER_CUE_PREVIEW_LATENCY=1 xcodebuild …
  -only-testing:"Cue StudioTests/QuickEditPreviewLatencyTests" test` (quanto uma mudança leva para
  aparecer e se a imagem some, com filtro, texto, fundo Blur, 4K e corte).
- **Skin Smoothing** (Quick edit › Adjust) tem uma medição opt-in com rosto de verdade, no aparelho (o Vision não acha rostos no Simulator; os testes de
  unidade usam um detector falso e um rosto desenhado): `TEST_RUNNER_CUE_SKIN_E2E=1 TEST_RUNNER_CUE_SKIN_MEDIA=Documents/skin.jpg xcodebuild … -destination
  "platform=iOS,id=<UDID>" -only-testing:"Cue StudioTests/SkinSmoothingDeviceTests" test`, com uma foto de retrato em `Documents` do app (`xcrun devicectl
  device copy to … --domain-type appDataContainer --domain-identifier com.cuestudioteleprompter --destination Documents/skin.jpg`). Mede o custo de um quadro
  em 1080p e 4K, se o rosto fica firme com movimento e se a prévia e a exportação saem iguais; os resultados vão como anexos (`SKIN SMOOTHING …`) do xcresult.
- Compras são testadas localmente com `CueStudio.storekit` (selecionado no scheme).
- Em Debug, uma instalação nova volta a ter as 5 exportações grátis: o contador fica no Keychain (sobrevive a reinstalar)
  e o `UsageQuotaService` o zera no primeiro lançamento depois de instalar (`DefaultsKey.installLaunched`). Release não zera.
