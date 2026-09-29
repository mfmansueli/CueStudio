# Cue Studio

App SwiftUI (projeto Xcode com pastas sincronizadas: a pasta no disco é o grupo no Xcode).

## Arquitetura

Todo código novo ou alterado segue os padrões de @ARCHITECTURE.md: MVVM + Services organizado por
feature, um tipo por arquivo, Design System com tokens, strings localizadas, testes (Swift Testing +
XCUITest) na mesma entrega. Consulte o checklist da seção 8 ao terminar cada feature.

Se algum código existente divergir do documento, vale o documento; ao tocar num arquivo fora do
padrão, corrija-o.

## Design

A fonte de verdade do design é @DESIGN_PROJECT.md (tokens, telas, estados e as diferenças em relação
ao protótipo do Claude Design). Atualize-o junto com a UI.

## Build e testes

- Scheme compartilhado `Cue Studio` (app + `Cue StudioTests` + `Cue StudioUITests`), Swift 6, iOS 27.
- `xcodebuild -project "Cue Studio.xcodeproj" -scheme "Cue Studio" -destination "platform=iOS Simulator,name=iPhone 17" test`
- O build Release também precisa compilar: previews usam dados de `SupportFiles/Debug/` e ficam em `#if DEBUG`.
- Launch arguments (só em Debug, ver `SupportFiles/LaunchOptions.swift`): `-uiTestInMemory` (armazenamento
  em memória), `-uiTestSeedSamples` (scripts de exemplo), `-uiTestPro` (começa no Cue Pro),
  `-uiTestSampleVideo` (vídeos reais pequenos atrás dos takes de "3 morning habits", para o Quick edit),
  `-uiTestRemoteConnects` (um iPad de mentira entra logo depois do pareamento do Remote Control).
- Compras são testadas localmente com `CueStudio.storekit` (selecionado no scheme).
