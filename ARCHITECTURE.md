# Padrões de Arquitetura — Cue Studio (SwiftUI)

> Padrões extraídos do projeto **Bruma** (fonte original: `../PADROES_ARQUITETURA_IOS.md`), aplicados
> ao Cue Studio. Todo código novo ou alterado neste projeto segue este documento.
>
> Nomes concretos deste projeto: target `Cue Studio`, módulo Swift `Cue_Studio` (para `@testable import`),
> tipo do app `CueStudioApp`.
>
> O documento não depende de nenhum backend ou framework de terceiros. A seção 9 lista o que o Bruma
> fez de errado e que deve ser evitado aqui desde o início.

---

## 1. Base técnica

| Item | Padrão |
|------|--------|
| UI | SwiftUI puro. UIKit só via `UIViewRepresentable` / `@UIApplicationDelegateAdaptor` |
| Plataforma | iOS 26+ (Liquid Glass). Multiplataforma iOS + macOS quando fizer sentido |
| Linguagem | Swift 6 com strict concurrency |
| Estado | Observation (`@Observable`). Sem `ObservableObject`, `@Published` ou Combine |
| Projeto Xcode | Pastas sincronizadas (*folder references* do Xcode 16+): a pasta no disco **é** o grupo no Xcode. Criar o arquivo na pasta certa já o coloca no target |
| Localização | String Catalog (`Localizable.xcstrings`) + `String(localized:)` / `LocalizedStringKey` |
| Testes | Swift Testing (unitários) + XCUITest (UI) |
| Dependências externas | Nenhuma obrigatória; prefira frameworks da Apple. Se entrar alguma (backend, analytics, anúncios...), ela fica encapsulada num Service/Manager, atrás de protocolo. Views e ViewModels nunca importam o SDK direto |

---

## 2. Arquitetura: MVVM + Services, organizada por feature

```
CueStudioApp ──▶ RootView (gate de estado: onboarding → login → setup → app)
                │
                ▼
        MainView (TabView)  ── cria e injeta os Services com .environment()
                │
                ▼
 Screens/<Feature>/  View ──(@State, é dona)──▶ ViewModel ──▶ Services (protocolos)
                      │                                             │
                      └──(@Environment)──▶ Managers/ ◀──────────────┘
                                              │
                                              ▼
                                  backend / frameworks / hardware

 Views usam DesignSystem/ · todas as camadas usam Models/
```

### Camadas e dependências

| Camada | Pasta | Responsabilidade | Pode depender de |
|--------|-------|------------------|------------------|
| **Models** | `Models/` | Structs/enums de domínio. `Codable`, `Identifiable`, `Hashable`, computed properties, labels localizados. **Sem IO.** | Foundation e frameworks de valor (ex.: CoreLocation) |
| **Services / Managers** | `Managers/` | Estado compartilhado entre telas + acesso a rede, persistência, frameworks e hardware. **Único lugar que conversa com o mundo externo** | Models |
| **ViewModels** | `Screens/<Feature>/` | Estado e ações de **uma** tela (ou de um grupo de telas da mesma feature). Orquestra os Services | Models, Managers |
| **Views** | `Screens/<Feature>/` | Layout, bindings, navegação. Sem chamada de IO direta | Tudo acima + DesignSystem |
| **Design System** | `DesignSystem/` | Tokens, estilos, fundos e componentes visuais genéricos | Só os próprios tokens e infraestrutura (ex.: cache de imagem). **Nunca** Screens ou Managers |
| **SupportFiles** | `SupportFiles/` | Entrada do app, AppDelegate, plists, entitlements, assets, extensões, infraestrutura transversal | Frameworks da Apple |

**Regra de ouro:** nada depende "para cima". Model não conhece View; Design System não conhece nenhuma feature.

### 2.1 ViewModel

```swift
@MainActor
@Observable
final class HomeViewModel {
    // Estado que a View lê/escreve
    var profiles: [Profile] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = false
    var errorMessage: String?

    // Estado que só o VM altera
    private(set) var lastFetchDate: Date?

    // Dependências (injetadas, com a implementação real como default)
    private let repository: ProfileRepository

    init(repository: ProfileRepository = RemoteProfileRepository()) {
        self.repository = repository
    }

    // MARK: - Ações

    /// Versão "dispara e esquece", para botões.
    func fetch() {
        Task { await refresh() }
    }

    /// Versão aguardável, para `.refreshable` / `.task`.
    func refresh() async {
        guard !isLoading else { return }   // guarda de reentrância
        isLoading = true
        defer { isLoading = false }
        // ...
    }
}
```

- Sempre `@MainActor @Observable final class <Feature>ViewModel`.
- A View é dona do VM: `@State private var viewModel = HomeViewModel()`. Se o VM precisar de parâmetros,
  use o init da View: `_viewModel = State(initialValue: ProfileEditViewModel(userId: uid))`.
- Estado padrão de carregamento/erro: `isLoading`, `isLoadingMore`, `hasMore`, `errorMessage: String?`.
- Dependências (ids, Services) entram pelo `init`, para que o VM seja testável com fakes.
- Um VM pode servir mais de uma View da mesma feature (ex.: `ProfileEditViewModel` usado por
  `SelfProfileView` e `ProfileEditView`).
- Nem toda tela precisa de VM. Telas só de apresentação ficam com `@State` locais.
- Seções internas separadas com `// MARK: -`.

### 2.2 Services e Managers

**Nomenclatura:**
- `<Domínio>Service`: regra de negócio e dados do próprio app (`LikeService`, `BlockService`,
  `PresenceService`, `OwnProfileStatusService`).
- `<Recurso>Manager`: wrapper de um framework ou recurso do sistema (`LocationManager` → CoreLocation,
  `StoreManager` → StoreKit, `AudioRecorderService` → AVFoundation).

**Padrão:**
- `@MainActor @Observable final class`.
- O que vem de fora (rede, banco, SDK) fica atrás de um **protocolo**, para permitir trocar a
  implementação e usar fakes nos testes.
- O Service vive enquanto vive o escopo que o criou. Ele é criado como `@State` na raiz desse escopo
  (`RootView` = sessão do app, `MainView` = usuário logado), distribuído com `.environment(service)` e
  lido com `@Environment(LikeService.self) private var likeService`.
- Services que dependem do usuário recebem o id no init: `LikeService(currentUserId:)`.
- Observação em tempo real vem em par: `startListening(userId:)` / `stopListening()`. O `stopListening`
  também **zera o estado**. Cada dado tem **uma** observação, compartilhada via environment; telas
  não abrem observações próprias para o mesmo dado.
- Cache local (UserDefaults, ou arquivo JSON em `.cachesDirectory`) fica dentro do Service, com chave
  escopada por usuário (`"likedExpiry_\(uid)"`) e limpeza de entradas expiradas no `init`.
- Só atualize o cache local **depois** que a fonte remota confirmar a escrita.
- Singleton (`static let shared`) só quando o tipo precisa ser chamado de fora da árvore SwiftUI (ex.:
  AppDelegate → `PushNotificationService`) ou é infraestrutura pura (`ImageCache`).

### 2.3 Models

```swift
struct Profile: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var boostedUntil: Date?          // definido só pelo servidor (ver 2.7)

    // Calculado depois do fetch, não é persistido
    var distance: Double?

    // Lógica dependente de tempo recebe `now`, para ser testável
    func isBoosted(at now: Date) -> Bool {
        guard let boostedUntil else { return false }
        return boostedUntil > now
    }
    var isBoosted: Bool { isBoosted(at: Date()) }
}
```

- Opcionais para tudo que pode faltar na fonte de dados.
- `CodingKeys` explícitas quando o `id` não vem no payload.
- Enums de opção seguem sempre o mesmo formato:

```swift
enum BodyType: String, Codable, CaseIterable, Identifiable {
    case slim, average, athletic, heavy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .slim: String(localized: "Slim")
        // ...
        }
    }
}
```

### 2.4 Lógica pura fora de framework

Regra de negócio que não precisa de IO vai para um tipo próprio, testável sem rede, sem StoreKit e
sem nenhum outro framework:
- `enum` sem cases com funções `static`, como em `PremiumPricing.savingsPercent(monthlyPrice:yearlyPrice:)`,
  que fica "free of StoreKit types so it can be unit-tested";
- ou uma `struct` de valor, como `ProfileFilter`, com `matches(_:)` e `activeCount`.

Esses tipos ficam em `Screens/<Feature>/Support/` enquanto só uma feature os usa.

### 2.5 Navegação e fluxo raiz

- `CueStudioApp` → `RootView`, que funciona como **gate de estado**: onboarding → login → setup de perfil →
  (bloqueado) → `MainView`. As flags ficam em `@AppStorage`.
- `MainView` é uma `TabView` com `Tab(...)`, e cada aba tem o **próprio** `NavigationStack`.
- Fluxos secundários abrem em `sheet`. Celebrações e visualizadores de mídia abrem em `fullScreenCover`.
- Push e deep links: o AppDelegate posta uma `Notification.Name` (declarada em extensão) e a UI escuta.

### 2.6 Concorrência (Swift 6)

- `@MainActor` em todo VM e Service.
- Callbacks de API baseada em closure/delegate não garantem main actor, então use
  `Task { @MainActor in ... }`. Métodos de delegate ficam `nonisolated`. Quando der, prefira embrulhar
  a API em `async` com `withCheckedContinuation`.
- Conformidades `@retroactive @unchecked Sendable` para tipos externos que ainda não são `Sendable`
  ficam **centralizadas em um arquivo** (ex.: `SupportFiles/SendableConformances.swift`), com
  comentário dizendo por que existem e quando remover.
- `nonisolated(unsafe)` só com justificativa em comentário (ex.: cancelar uma `Task` no `deinit`).
- Recursos cujo teardown não pode depender do main actor ficam numa classe "handle" separada
  (ex.: `AudioPlaybackHandle` com o `deinit` do `AVPlayer`).

### 2.7 Servidor como fonte da verdade (se houver backend)

- Campos sensíveis (premium, boost, bloqueio, recompensas) são definidos **só pelo servidor**. O
  cliente apenas lê, e o backend rejeita escrita do cliente nesses campos. Isso fica documentado no
  próprio Model.
- Compras (StoreKit 2) são reverificadas no servidor antes de liberar algo. A verificação local não basta.
- Configuração e regras de acesso do backend ficam versionadas no mesmo repositório do app.

### 2.8 Multiplataforma

`#if os(iOS)` / `#if os(macOS)` ficam encapsulados. Modificadores que diferem por plataforma viram
extensões de `View` (`inlineNavigationTitle()`, `macOSPlainButton()`, `adaptiveImageScale()`), para que
as telas não espalhem `#if`.

---

## 3. Estrutura de pastas

```
Cue Studio/
├── Cue Studio/                         # target do app
│   ├── DesignSystem/
│   │   ├── Tokens/                     # Palette, CueStudioFont, Color+Dynamic
│   │   ├── Styles/                     # ButtonStyles (CueStudioButtonStyle)
│   │   ├── Components/                 # views genéricas: ScreenHeader, EmptyStateView, SurfaceCard...
│   │   ├── Backgrounds/                # fundos e elementos de marca
│   │   └── Fonts/                      # .ttf + licença
│   ├── Managers/                       # Services e Managers app-wide (+ protocolos)
│   ├── Models/                         # entidades de domínio + enums de opção
│   ├── Screens/
│   │   ├── Main/                       # RootView, MainView
│   │   │   └── Support/                # telas de estado raiz (ex.: BannedAccountView)
│   │   ├── Shared/<Conceito>/          # telas usadas por várias features (ex.: visualizador de imagem)
│   │   └── <Feature>/
│   │       ├── <Feature>View.swift
│   │       ├── <Feature>ViewModel.swift
│   │       ├── Cards/                  # células de grid
│   │       ├── Rows/                   # células de lista
│   │       ├── Sheets/                 # telas apresentadas modalmente
│   │       ├── Support/                # tipos auxiliares da feature (filtros, enums, PreferenceKeys, formatadores)
│   │       ├── <Conceito>/             # agrupamento por conceito (ex.: Chat/Audio/, Chat/Video/, Chat/Bubbles/)
│   │       └── <SubFeature>/           # sub-feature com View + VM próprios (ex.: Setting/AdminReports/)
│   └── SupportFiles/
│       ├── CueStudioApp.swift
│       ├── AppDelegate.swift
│       ├── Info.plist · Cue Studio.entitlements · PrivacyInfo.xcprivacy
│       ├── Localizable.xcstrings · Assets.xcassets · Preview Content/
│       ├── ViewExtensions.swift
│       └── <Conceito>/                 # infra com várias peças (ex.: ImageLoading/)
├── Cue StudioTests/                    # Swift Testing, espelha subpastas quando cresce (DesignSystem/)
├── Cue StudioUITests/                  # XCUITest, um arquivo por fluxo
└── DESIGN_PROJECT.md                   # fonte de verdade do design (ver seção 5)
```

**Subpastas de uma feature:** só crie a subpasta quando houver arquivo para ela. Uma feature pequena
pode ter apenas `View` + `ViewModel`.

---

## 4. Regras para criar arquivos

### 4.1 Um tipo por arquivo

- Todo arquivo Swift declara **exatamente um** `struct` / `class` / `enum` / `actor` / `protocol` de
  top-level, mesmo que existam vários tipos pequenos e relacionados. Ex.: um `UIViewRepresentable` e a
  `UIView` de suporte ficam em dois arquivos; um protocolo e sua implementação também.
- Tipos **aninhados** (inclusive privados) dentro do tipo top-level são permitidos (ex.: o
  `enum Variant` dentro do `ButtonStyle`, a `struct` de cache privada dentro do VM).
- Extensões não contam como tipo. Um componente pode trazer o `ViewModifier` + `extension View
  { func surfaceCard() }` no mesmo arquivo.
- Quando a divisão gerar vários arquivos fortemente relacionados (ex.: cache + loader + view que os
  consome), eles vão para **uma subpasta própria, nomeada pelo conceito** (`ImageLoading/`). Não
  espalhe esses arquivos soltos numa pasta genérica. Agrupe por feature ou conceito, não por "tipo
  de arquivo".
- Ao tocar num arquivo que viola a regra, aproveite para corrigir.

### 4.2 Onde colocar cada coisa

| Vou criar... | Vai em... |
|--------------|-----------|
| Tela nova | `Screens/<Feature>/<Feature>View.swift` (+ `<Feature>ViewModel.swift` se houver estado ou IO não trivial) |
| Célula de grid / lista | `Screens/<Feature>/Cards/` ou `Rows/` |
| Tela modal (sheet) | `Screens/<Feature>/Sheets/<Nome>Sheet.swift` |
| Sub-feature com View + VM próprios dentro de outra | `Screens/<Feature>/<SubFeature>/` |
| Tela usada por várias features | `Screens/Shared/<Conceito>/` |
| Tipo auxiliar usado só por uma feature (filtro, enum de ordenação, `PreferenceKey`, formatador, cálculo puro) | `Screens/<Feature>/Support/` |
| Várias peças de um mesmo conceito dentro da feature (player, gravador, waveform) | `Screens/<Feature>/<Conceito>/` |
| Entidade de domínio ou enum de opção usado por mais de uma feature | `Models/` |
| Estado compartilhado, rede, persistência, framework ou hardware | `Managers/<Nome>Service.swift` ou `<Nome>Manager.swift` (protocolo em arquivo próprio ao lado) |
| Componente visual genérico, **sem regra de negócio** | `DesignSystem/Components/` |
| Cor, fonte, espaçamento | `DesignSystem/Tokens/` (**nunca** valor solto na tela) |
| `ButtonStyle` / `ViewModifier` de estilo | `DesignSystem/Styles/` |
| Extensão transversal, conformidade `Sendable`, infra | `SupportFiles/` (subpasta por conceito se tiver 2+ arquivos) |

**Promoção:** quando um tipo de `Screens/<Feature>/Support/` passar a ser usado por 2+ features, mova
para `Models/` (se for dado ou regra) ou para `DesignSystem/` (se for visual e genérico).

### 4.3 Nomenclatura

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Tela | `<Feature>View` | `HomeView`, `ChatMessageView` |
| ViewModel | `<Feature>ViewModel` | `HomeViewModel` |
| Service de domínio | `<Domínio>Service` | `LikeService` |
| Wrapper de framework/recurso | `<Recurso>Manager` | `LocationManager`, `StoreManager` |
| Protocolo de acesso a dados | `<Entidade>Repository` / `<Domínio>Servicing` | `ProfileRepository` |
| Implementação real / fake | `Remote<Entidade>Repository` / `Fake<Entidade>Repository` (fake só no target de testes) | `RemoteProfileRepository` |
| Célula | `<Coisa>Card` / `<Coisa>Row` | `ProfileCard`, `ConversationRow` |
| Modal | `<Coisa>Sheet` | `PremiumSheet`, `ReportUserSheet` |
| Extensão de tipo | `<Tipo>+<Assunto>.swift` | `Color+Dynamic.swift` |
| Extensões gerais de View | `ViewExtensions.swift` | |
| Teste unitário | `<Tipo>Tests.swift` | `LikeServiceTests.swift` |
| Teste de UI | `<Fluxo>UITests.swift` | `OnboardingLoginUITests.swift` |
| Accessibility identifier | `"<tela>.<elemento>[.<id>]"`, em camelCase | `"login.continueWithPhoneButton"`, `"chat.conversationRow.\(id)"`, `"mainTab.home"` |
| Chave de UserDefaults por usuário | `"<chave>_\(uid)"` | `"likedExpiry_\(uid)"` |

### 4.4 Anatomia de um arquivo

```swift
//
//  HomeView.swift
//  Cue Studio
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    // 1. Estado próprio (@State) e VM
    @State private var viewModel = HomeViewModel()
    @State private var showingFilter = false
    // 2. Dependências do ambiente
    @Environment(BlockService.self) private var blockService
    @Environment(\.scenePhase) private var scenePhase
    // 3. Constantes
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 10)]

    // 4. Computed properties / helpers de dados
    private var visibleProfiles: [Profile] { ... }

    // 5. body
    var body: some View { ... }

    // 6. Subviews privadas por seção
    private var header: some View { ... }

    // 7. Funções privadas
    private func openSettings() { ... }
}

#Preview {
    HomeView()
        .environment(BlockService())   // injete tudo que a View lê do environment
}
```

- Cabeçalho padrão com o nome do arquivo e o target.
- `// MARK: -` para separar seções em VMs e Services.
- `#Preview` no fim do arquivo, com os `.environment(...)` necessários.
- **Comentários explicam o "porquê"** (motivação, tentativa anterior que não funcionou, trade-off,
  referência à regra do servidor), não o "o quê". `///` em APIs públicas de componentes e Services.

### 4.5 Quando dividir

- **View crescendo:** primeiro extraia seções como `private var header: some View`. Se a seção tiver
  estado próprio, for reutilizada ou a View passar de ~400 linhas, mova para um arquivo em
  `Cards/`, `Rows/`, `Sheets/` ou `<Conceito>/`.
- **Lógica de negócio dentro da View ou do VM** (filtro, ordenação, cálculo): extraia para um tipo
  em `Support/` e teste esse tipo. Cada regra vive em **um** lugar só.
- **3+ arquivos de um mesmo conceito** numa pasta genérica: crie uma subpasta com o nome do conceito.

---

## 5. Design System

- **Tokens:**
  - `Palette`: `enum` com `static let`, cores light/dark via `Color(light:dark:)` e nomes semânticos
    (`bg`, `surf`, `ink`, `ink2`, `acc`, `accInk`, `danger`...);
  - `CueStudioFont`: fonte display com `relativeTo:` para escalar com Dynamic Type, registrada no launch;
  - `Color+Dynamic`: inits de hex e HSL.
- **Estilos:** um `ButtonStyle` com `enum Variant` + helpers estáticos (`.appPrimary()`, `.appSoft()`...),
  para as telas nunca construírem o estilo na mão.
- **Componentes:** views genéricas e modificadores expostos como extensão de `View` (`surfaceCard()`,
  `appSheetBackground()`).
- **Regras:**
  - nenhuma cor hex, fonte ou raio ad-hoc em `Screens/`: se faltar, crie o token;
  - um componente só entra no Design System se for genérico (sem regra de negócio);
  - um único estilo "primário" por tela.
- **`DESIGN_PROJECT.md` na raiz** é a fonte de verdade do design: identidade, cores, tipografia,
  espaçamento, formas, ícones (SF Symbols por significado), biblioteca de componentes, inventário de
  telas, árvore de navegação, estados vazios/loading/erro, motion, acessibilidade, do's & don'ts e
  checklist. Atualize junto com a UI.

---

## 6. Strings, acessibilidade e flags de debug

- Todo texto visível passa por localização: `Text("...")` (`LocalizedStringKey`) ou
  `String(localized:)`. Os `label` de enums também.
- Botão só com ícone sempre tem `accessibilityLabel`. Cards combinam os filhos
  (`.accessibilityElement(children: .ignore)` + label único). Área de toque mínima de 44×44pt.
  Animações contínuas respeitam Reduce Motion.
- Elementos usados em UI tests têm `accessibilityIdentifier` no padrão da seção 4.3.
- Ferramentas de admin e geração de dados de teste ficam atrás de permissão de admin ou `#if DEBUG`.
  Overrides locais (ex.: "fingir premium") nunca saem do aparelho.
- Hooks para UI test ficam dentro de `#if DEBUG` no `init` do App (ex.: `-uiTestResetOnboarding`
  limpa uma flag de `@AppStorage`).

---

## 7. Testes

Testes são escritos **junto com a feature**, não como etapa posterior.

```
Cue StudioTests/
├── <Tipo>Tests.swift          # um arquivo por tipo testado (Model, VM, Service, helper)
├── Fakes/                     # implementações fake dos protocolos de Service/Repository
└── DesignSystem/              # espelha subpastas quando a pasta crescer
Cue StudioUITests/
└── <Fluxo>UITests.swift       # um arquivo por fluxo de usuário
```

### Unitários: Swift Testing

```swift
import Foundation
import Testing
@testable import Cue_Studio

@MainActor                                   // quando o tipo testado é @MainActor
@Suite("OwnProfileStatusService")
struct OwnProfileStatusServiceTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)   // tempo fixo

    private func makeService() -> OwnProfileStatusService { OwnProfileStatusService() }

    @Test func premiumWhileSubscriptionIsActive() {
        let service = makeService()
        service.premiumUntil = now.addingTimeInterval(3600)
        #expect(service.isPremium(at: now, pretendPremium: false))
    }
}
```

- `@Suite("<Tipo>")` + `struct <Tipo>Tests`. Nomes de teste descrevem o comportamento
  (`initPrunesExpiredLikeFromCache`).
- Factories `makeVM()` / `makeProfile(...)` para montar cenários. VMs recebem fakes no `init`, nunca
  a implementação real.
- Tempo fixo e injetado (`now`), nunca `Date()` dentro da asserção.
- Isole UserDefaults com ids únicos por teste (`"user-\(UUID())"`) e limpe com `defer`.
- Priorize a lógica pura (seção 2.4): ela é a parte mais fácil e mais valiosa de testar.

### UI: XCUITest

- Estado inicial controlado por launch arguments (`-hasSeenOnboarding YES` via *arguments domain*, ou
  um hook `#if DEBUG` quando o app precisa escrever a flag depois).
- Elementos localizados por `accessibilityIdentifier`, não por texto.
- `XCTSkip` quando a pré-condição do ambiente não existe (ex.: simulador já logado).
- Helpers de launch e asserção agrupados em `// MARK: - Helpers`.

---

## 8. Checklist de nova feature

- [ ] Pasta `Screens/<Feature>/` com `View` (+ `ViewModel` se necessário)
- [ ] Um tipo por arquivo; subpastas (`Cards/`, `Sheets/`, `Support/`, `<Conceito>/`) só quando necessárias
- [ ] Services compartilhados lidos via `@Environment`, não recriados na tela
- [ ] Acesso externo atrás de protocolo; nenhum SDK importado em View ou ViewModel
- [ ] Regra de negócio extraída para tipo puro em `Support/` (ou `Models/`)
- [ ] Cores, fontes e componentes do `DesignSystem/`; nenhum valor solto
- [ ] Estados vazio, carregando e erro definidos
- [ ] Textos localizados; labels e identifiers de acessibilidade
- [ ] Light e dark mode conferidos; Reduce Motion respeitado
- [ ] Campos sensíveis definidos só pelo servidor (quando houver backend)
- [ ] Testes unitários (Swift Testing) e de UI (XCUITest) na mesma entrega
- [ ] `DESIGN_PROJECT.md` atualizado se a UI mudou

---

## 9. O que fazer melhor do que no Bruma

Pontos em que o Bruma cresceu de forma orgânica e que valem corrigir desde o início no projeto novo:

1. **Nenhum SDK fora dos Services.** No Bruma, VMs e Views chamam o SDK do backend direto, então
   trocar de backend exigiria mexer em dezenas de arquivos, e os testes dependem de ids falsos para
   não bater na rede. No novo projeto, todo acesso externo fica atrás de protocolo (seção 2.2) e é
   injetado no `init`.
2. **Sessão centralizada.** O id do usuário logado é lido direto do SDK de autenticação em várias
   Views. Crie um `SessionService` no environment, que expõe o usuário atual e é o único que conhece
   a autenticação.
3. **Chaves de UserDefaults num lugar só.** Strings como `"hasSeenOnboarding"` e
   `"adminPretendPremium"` aparecem repetidas. Use um `enum DefaultsKey` com `static let`.
4. **Views grandes.** `ProfileDetailView` (~950 linhas) e `ChatMessageView` (~700) passaram muito do
   ponto. Aplique a regra de divisão da seção 4.5 cedo.
5. **`SupportFiles/` não é gaveta.** Telas reutilizáveis (visualizador de imagem em tela cheia, câmera)
   foram parar lá. Deixe `SupportFiles/` só para entrada do app, configuração e infraestrutura. Telas
   compartilhadas vão para `Screens/Shared/<Conceito>/`.
6. **Regra de ordenação duplicada.** O sort de perfis existe na View e no VM. Cada regra de negócio
   deve ter um único dono (tipo em `Support/`).
