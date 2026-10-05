# Cue Studio

App SwiftUI (projeto Xcode com pastas sincronizadas: a pasta no disco é o grupo no Xcode).

## Arquitetura

Todo código novo ou alterado segue os padrões de @ARCHITECTURE.md: MVVM + Services organizado por
feature, um tipo por arquivo, Design System com tokens, strings localizadas, testes (Swift Testing +
XCUITest) na mesma entrega. Consulte o checklist da seção 8 ao terminar cada feature.

Se algum código existente divergir do documento, vale o documento; ao tocar num arquivo fora do
padrão, corrija-o.

## Design

A fonte de verdade do design é `design/cue-v30/` (comece por `LEIA-ME.md` e `09-Decisions.md`; o protótipo
`prototype/Cue App v30.dc.html` é a referência visual). @DESIGN_PROJECT.md diz como o app ficou e onde as decisões foram
tomadas. Atualize-o junto com a UI.

## Build e testes

- Scheme compartilhado `Cue Studio` (app + `Cue StudioTests` + `Cue StudioUITests`), Swift 6, iOS 27.
- `xcodebuild -project "Cue Studio.xcodeproj" -scheme "Cue Studio" -destination "platform=iOS Simulator,name=iPhone 17" test`
- **Zero warnings.** Todo build termina sem nenhum warning (compilador, SwiftLint, ferramentas do
  Xcode): se um build mostrar um warning, corrija na mesma entrega, mesmo que não tenha vindo da sua
  mudança. Build incremental não repete warnings de arquivos não recompilados, então confira com um
  build limpo (`-derivedDataPath` novo) antes de dar por terminado. O SDK do simulador e o do
  aparelho acusam coisas diferentes (anotações de concorrência): confira os dois.
- **SwiftLint** (`brew install swiftlint`) roda em todo build do app (Build Phases › SwiftLint) com
  `.swiftlint.yml`. Corrija o código em vez de afrouxar a configuração; `swiftlint --fix` resolve
  parte, mas revise o formato do que ele muda.
- O build Release também precisa compilar: previews usam dados de `SupportFiles/Debug/` e ficam em `#if DEBUG`.
- Launch arguments (só em Debug, ver `SupportFiles/LaunchOptions.swift`): `-uiTestInMemory` (armazenamento
  em memória), `-uiTestSeedSamples` (scripts de exemplo), `-uiTestPro` (começa no Cue Pro),
  `-uiTestSampleVideo` (vídeos reais pequenos atrás dos takes de "3 morning habits", para o Quick edit),
  `-uiTestRemoteConnects` (um iPad de mentira entra logo depois do pareamento do Remote Control),
  `-uiTestAppearance <light|dark>` (as telas do Cue começam claras ou escuras, como em Settings › Appearance),
  `-uiTestAppLanguage <lproj>` (a interface começa nesse idioma, em memória, sem mudar o simulador).
  v27: `-uiTestOnboarding`, `-uiTestPermissions granted|denied`, `-uiTestSky off|calm|lively` (off por padrão nos testes), `-uiTestAppsInstalled`,
  `-uiTestCatalogue <seção>` (a seção `transition` mostra a estrela; ver `DESIGN_PROJECT.md`).
  v30: `-uiTestVoiceTip` (abre as portas da dica do My Cue Voice) e `-uiTestStarTransition` (a estrela da ideia mantém os tempos reais; nos testes de UI ela é encurtada).
- Idiomas: `LOCALIZATION.md` (três idiomas independentes, terminologia, RTL). Todo texto novo entra
  nos 20 idiomas dos String Catalogs. O teste de fala de verdade é opt-in:
  `TEST_RUNNER_CUE_SPEECH_E2E=1 xcodebuild … -only-testing:"Cue StudioTests/VoiceFollowingSpeechTests" test`,
  num aparelho: o Simulator lista os idiomas mas não roda o reconhecimento de fala. Com o mesmo
  flag, `-only-testing:"Cue StudioTests/VoiceFollowingLatencyTests"` mede a latência do Voice
  Following no aparelho (uma gravação tocada em tempo real pelo caminho de áudio da câmera: voz →
  indicador, palavra → texto p50/p95, quanto o texto se adianta, sala com ruído) e
  `VoiceFollowingSpeechTests/availabilityOnThisDevice()` lista os 20 idiomas sem baixar nada.
- A prévia do Quick edit tem uma medição opt-in no aparelho: `TEST_RUNNER_CUE_PREVIEW_LATENCY=1 xcodebuild …
  -only-testing:"Cue StudioTests/QuickEditPreviewLatencyTests" test` (quanto uma mudança leva para
  aparecer e se a imagem some, com filtro, texto, fundo Blur, 4K e corte).
- Compras são testadas localmente com `CueStudio.storekit` (selecionado no scheme).
