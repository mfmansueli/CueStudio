# Cue Studio

App SwiftUI (projeto Xcode com pastas sincronizadas: a pasta no disco é o grupo no Xcode).

## Arquitetura

Todo código novo ou alterado segue os padrões de @ARCHITECTURE.md: MVVM + Services organizado por
feature, um tipo por arquivo, Design System com tokens, strings localizadas, testes (Swift Testing +
XCUITest) na mesma entrega. Consulte o checklist da seção 8 ao terminar cada feature.

Se algum código existente divergir do documento, vale o documento; ao tocar num arquivo fora do
padrão, corrija-o.

## Design

A fonte de verdade do design é `design/cue-v30/handoff-telas/`: comece por `LEIA-ME.md` e `docs/09-Decisions.md` (vale mais que os outros
documentos); as telas em `screens/*.html` são a referência visual e `ANIMACOES.md` / `docs/motion-README.md` têm o movimento. Pacotes antigos
(protótipo `Cue App v30.dc.html`, documentos 01–08, `handoff-hoje`, `handoff-atualizacao`) só existem no histórico do git (commit `bb39f35`).

`DESIGN_PROJECT.md` diz **como o app está hoje** e as decisões do dono que divergem do quadro, por tela. **Leia a seção da tela antes de mexer
nela** (não é carregado automaticamente) e atualize-a na mesma entrega, descrevendo o estado atual (sem histórico: o que saiu, sai do texto).

## Contraste (WCAG 2.2 AA, HIG da Apple)

Toda tela, componente ou cor nova **precisa passar** no contraste antes de ser entregue; ao tocar numa cor existente, confira também:

- **Texto:** pelo menos **4,5:1** contra o que realmente está atrás dele (texto grande, de 18 pt ou mais, ou 14 pt em negrito ou mais, **3:1**). Isso vale para textos pequenos, rótulos mono, placeholders, textos legais e para texto sobre vidro, aurora, céu ou vídeo: o fundo é o **pior ponto** da superfície, não o token médio.
- **Partes de controle, ícones que informam e bordas de campo:** **3:1** (WCAG 1.4.11). Só o que é decorativo (setas de disclosure, separadores, pontos) pode ficar abaixo.
- **Use os tokens de texto de `Palette`** (`ink`, `ink2`, `inkHint`, `accText`, `aiText`, `warnText`, …); eles já são medidos em `PaletteContrastTests` com e sem Aumentar Contraste. `ink3` é só para o que não precisa ser lido (nunca para texto). **Não invente** `Color.white.opacity(x)`, `Palette.Flight.ink.opacity(x)` etc. para texto: se um token não serve, crie ou ajuste o token e meça.
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
- **Firebase** (projeto `cuestudio-app`, SPM `firebase-ios-sdk`): só Analytics (`FirebaseAnalyticsCore`, sem IDFA) e Crashlytics, iniciados em
  `Managers/Telemetry/TelemetryManager.swift`, o único arquivo que importa o SDK. Testes, `-uiTestInMemory` e previews não enviam nada
  (`TelemetryPolicy`). Upload dos dSYMs só em archive. DebugView: `-FIRAnalyticsDebugEnabled`. Falhas do Apple Intelligence (`AIFailureReport`):
  cada uma vai ao Console (`studio.cue` / `ScriptAI`) com o motivo do framework e as condições do aparelho; a que chega ao criador vira non-fatal
  (`AppleIntelligence.<operação>.<motivo>`). Nunca o texto.
- O build Release também precisa compilar: previews usam dados de `SupportFiles/Debug/` e ficam em `#if DEBUG`.
- **Launch arguments** (só Debug; a lista completa e o que cada um faz está em `SupportFiles/LaunchOptions.swift`). Os mais usados:
  - Estado: `-uiTestInMemory`, `-uiTestSeedSamples`, `-uiTestPro`, `-uiTestSampleVideo`, `-uiTestAppLanguage <lproj>`, `-uiTestExportsLeft <0…5>`,
    `-uiTestUniverse sample|newYear|newAccount`, `-uiTestTopics …`, `-uiTestSky off|serene|adrift|interstellar` (off nos testes).
  - Fluxos: `-uiTestOnboarding` (+ `-uiTestOnboardingStep <capítulo>`, `-uiTestPermissions granted|denied`), `-uiTestVoyage` (sem ele nenhum teste vê
    as dicas da primeira viagem), `-uiTestVoiceTip`, `-uiTestNotificationInvite`, `-uiTestNotificationAuth <estado>`, `-uiTestNotificationTap <destino>`
    (`NOTIFICATIONS.md`), `-uiTestShareQueue`, `-uiTestFakeShareSheet`, `-uiTestAppsInstalled` (`SHARING.md`), `-uiTestRemoteConnects`.
  - IA de teste: `-uiTestStubAI`, `-uiTestSlowWriting`, `-uiTestWriterStalls`, `-uiTestIdeasSlow`, `-uiTestIdeasFail`.
  - Tempo e animação: `-uiTestFastAnimations` (padrão do `CueApp.launch`; `animations: true` pede as reais), `-uiTestStarTransition`,
    `-uiTestWelcomeOpening`, e os que congelam uma cena num segundo (`-uiTestWelcomeAt`, `-uiTestProAt`, `-uiTestChapterAt`, `-uiTestStoryAt`,
    `-uiTestSendOffAt`, `-uiTestFirstStar`, `-uiTestMilestone <n>`).
  - `-uiTestCatalogue <seção>` (transition, writing, universe, sky, inspire…) e `-uiTestSceneCapture on|off` (`DESIGN_PROJECT.md` §26).
- **Idiomas:** `LOCALIZATION.md` (três idiomas independentes, terminologia, RTL). Todo texto novo entra nos 20 idiomas dos String Catalogs.
- Compras são testadas localmente com `Cue StudioTests/Fixtures/CueStudio.storekit` (selecionado no scheme; `StoreManagerTests` o usa num `SKTestSession`). Em Debug, uma instalação nova volta a ter as 5 exportações
  grátis (o contador fica no Keychain; `UsageQuotaService` o zera no primeiro lançamento, `DefaultsKey.installLaunched`). Release não zera.

### Testes no aparelho (opt-in)

Sempre `CUE_DEVICE="<iPhone>" scripts/test.sh device <Suite>`: um conjunto por vez, iPhone desbloqueado e com a tela acesa (o modelo da Apple é
limitado em segundo plano e dois conjuntos de fala disputam os 5 idiomas; bloqueado, o script para na hora, senão o `xcodebuild` esperaria o
desbloqueio para sempre). O script liga a variável `TEST_RUNNER_CUE_…` certa. Um teste de
aparelho tem 5 minutos, por isso os conjuntos pegam poucos casos por execução (variáveis `TEST_RUNNER_CUE_…` de cada suíte). Um idioma que o
aparelho não roda aparece como **não validado** (teste cancelado), nunca aprovado.

| Assunto | Suítes | Onde ficam os resultados |
|---|---|---|
| Fala (o Simulator não roda o reconhecimento) | `VoiceFollowingSpeechTests` (inclui `availabilityOnThisDevice()`), `VoiceFollowingLatencyTests`, `CaptionSpeechTests`, `SpokenLanguageDeviceTests` (idioma falado num vídeo sem roteiro) | `LOCALIZATION.md` §5 |
| Apple Intelligence | `LanguageModelDeviceTests`, `ScriptGenerationFlowDeviceTests` | `LOCALIZATION.md` §5 |
| My Cue Voice e roteirista | `VoicePersonaDeviceTests` (`tools/voice/collect_runs.py`, `make_pairs.py`), `PromptBudgetDeviceTests`, `WritingImportDeviceTests`, `PlatformLengthDeviceTests`, `LengthVariantsDeviceTests`, `ScriptToolsDeviceTests`, `IdeaRelevanceDeviceTests`, `IdeaSuggestionsDeviceTests`, `CreatorDayDeviceTests`, `InspirationDeviceTests` | `DESIGN_PROJECT.md` §4, §23, §30 |
| Qualidade de roteiros e ideias (PT/EN/ES, voz completa, meia e sem voz) | `ScriptQualityDeviceTests` (`TEST_RUNNER_CUE_QUALITY_RUN=<nome>`; `tools/quality/collect.py`, `report.py`; reaplicar a lógica pura nos textos: `QualityReplayTests`) | `DESIGN_PROJECT.md` §4.1 |
| Quick edit | `QuickEditPreviewLatencyTests`; `SkinSmoothingDeviceTests` e `BackgroundDeviceTests` (Vision de verdade; foto de retrato em `Documents` do app via `xcrun devicectl device copy to … --domain-identifier com.cuestudioteleprompter`, `TEST_RUNNER_CUE_SKIN_MEDIA=Documents/skin.jpg`) | `DESIGN_PROJECT.md` §20, §31 |
| Eye Contact (✦ Smart) | `EyeContactDeviceTests` (o Face Mesh em Core ML e o desenho na CPU de verdade numa CÓPIA da tomada mais nova; `TEST_RUNNER_CUE_EYES_TAKE=<arquivo>` escolhe outra, `…_SECONDS`, `…_STRENGTH`; o vídeo corrigido e a análise vão para `Documents` do app; `TEST_RUNNER_CUE_EYES_CLEANUP=1` com `EyeContactDeviceTests/removesWhatTheseRunsLeft()` apaga o que ficou lá) | `DESIGN_PROJECT.md` §40 |

## Espaço em disco (não encher o Mac)

Sessões do Claude Code já deixaram dezenas de GB de lixo em builds e simuladores. Para não repetir:

- **Nunca chame `xcodebuild` direto nem crie DerivedData fora de `build/DerivedData`.** Nada de pastas `dd-*`, scratchpad ou
  `/tmp` para builds: use sempre `scripts/build.sh` e `scripts/test.sh` (eles já usam o `build/DerivedData` do checkout).
- **Não crie simuladores nem baixe runtimes de iOS** (`xcrun simctl create`, Xcode › Components). Use o simulador que os
  scripts já definem.
- **Testes em paralelo criam clones de simulador** em `~/Library/Developer/XCTestDevices` (o `du` mostra ~18 GB cada, mas são
  cópias APFS que dividem dados com o original; mesmo assim crescem a cada rodada). `scripts/test.sh ui` e `full` usam **2 clones**
  (decisão do dono, 21/10/2026: a UI caiu de ~113 para ~45 min neste M3 de 16 GB) e os apagam ao terminar; não use mais de 2, e
  `--parallel 1` roda num simulador só. Fora do script, ao terminar uma rodada, rode `xcrun simctl --set testing delete all`.
- **Ao fim de cada sessão, apague o que você criou fora do repositório** (pastas temporárias, capturas, logs grandes) e o
  `build/DerivedData` de worktrees descartados.
