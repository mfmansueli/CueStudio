# ANIMACOES · como implementar o movimento de TODAS as telas

**Por que as versões anteriores saíram planas:** o movimento só estava descrito em texto. Aqui o movimento está nos próprios HTMLs (CSS `@keyframes`), extraído em dados (`motion/screens-motion.json`), com um motor em Swift, receitas de efeito e as animações que o protótipo cria por código (WAAPI). **Regra: nenhuma tela é entregue estática ou simplificada.**

## 1. Onde está o movimento
1. **Os HTMLs em `screens/`**: abra no navegador. Tudo que se mexe sozinho é CSS (`animation:` inline ou `@keyframes` no `<style>`) ou SVG SMIL (`<animateTransform>`, `<animateMotion>`). Use o inspetor (`document.getAnimations()`) para ver duração, atraso e curva reais de cada camada.
2. **`motion/screens-motion.json`**: `keyframes` (dicionário de faixas: cada quadro tem `t` em segundos e canais numéricos), `screens[arquivo].layers` (cada elemento animado: texto, caixa em pt, estilo, e a lista de animações com duração, atraso, curva e a chave `kf`) e os SMIL.
3. **Seção 2 abaixo**: animações criadas por JavaScript (Web Animations API). Elas **não** estão nos HTMLs congelados; os valores exatos estão aqui.
4. **`docs/09-Decisions.md`** (§6 a §18) e **`motion/README.md`**: gatilhos, hápticos, Reduzir Movimento e o que cada toque faz. Em conflito, os números do JSON e da seção 2 vencem.

## 2. Animações por código (valores exatos)
Tempos em ms, curvas em `cubic-bezier(x1,y1,x2,y2)`, todas com `fill: forwards`.

**8.2 · The send-off** (uma estrela por rede; para N redes a estrela i começa em 520 + i·350 ms)
| Elemento | Quando | Duração | Curva | Quadros |
|---|---|---|---|---|
| Cartão do vídeo vira estrela | 0 | 650 | (.5,0,.4,1) | translateY 0 → −16 (50%) → −30 pt, scale 1 → 1 → .12, opacidade 1 → 1 → 0 |
| Estrela voa ao planeta | 520 + i·350 | 1050 | (.45,.05,.35,1) | arco de Bézier do cartão até o planeta: posição e escala (1 → .65) amostradas em ~24 quadros; opacidade 0 → 1 nos primeiros 6% |
| Cauda (9 pontos) | 520 + i·350 + j·38 | 1050 | (.45,.05,.35,1) | mesma curva da estrela, opacidade máx. max(0, .55 − j·.06), último quadro opacidade 0 |
| Pulso do planeta | chegada da estrela | 600 | (.3,1.4,.5,1) | scale 1 → 1.35 (35%) → 1.12; o contador sobe +1 |
| Anel de impacto | chegada | 800 | (.2,.8,.2,1) | opacidade .9 → 0, scale 1 → 5 |
| "+1 · {REDE}" | chegada | 1400 (500 nas redes seguintes) | (.2,.9,.25,1) | opacidade 0 → 1 (30%), translateY 8 → 0 pt |
| Nova estrela pequena ao lado de YOU | 300 depois do pulso | 700 | (.2,.9,.25,1) | scale 0 → 1.8 (40%) → 1, opacidade 0 → 1 |
Hápticos: `.success` em cada chegada (só o primeiro se três chegarem em menos de 0,7 s). Reduzir Movimento: estado final.

**11.4 · Pro, abertura (2,4 s, toque liberado a partir de 1,4 s)**
| Elemento | Atraso | Duração | Curva | Quadros |
|---|---|---|---|---|
| 42 riscos de warp | 0–240 ms (aleatório por risco) | 900 | (.5,0,.8,.4) | rotate(a), translateX −(300…380) → −4 pt; largura 2 → len (70%) → 4 pt; opacidade 0 → 1 (25%) → .9 (70%) → 0 |
| Núcleo dourado (ignição) | 700 | 700 | (.2,.9,.25,1) | scale .2 → 1 (60%) → 1.6; opacidade 0 → 1 |
| Clarão | 1250 | 900 | ease-out | opacidade 0 → 1 (30%) → 0 |
| Anel dourado | 1250 | 1100 | (.2,.8,.2,1) | scale .4 → 14, opacidade .9 → 0 |
| Núcleo sobe ao planeta "você" | 1500 | 760 | (.5,0,.3,1) | translateY 0 → dy (85%) → dy, scale 1.6 → 2.6 → 4.2, opacidade 1 → 1 → 0 (dy = distância até o centro do planeta) |
| Arte do planeta "você" acende | 2050 | 700 | (.2,.9,.25,1) | scale .6 → 1.04 (70%) → 1, opacidade 0 → 1 |
| Conteúdo (título, lista, planos, CTA, rodapé) | 1350 + 70 ms por item | 700 | (.2,.9,.25,1) | translateY 18 → 0, blur 8 → 0, opacidade 0 → 1 |
| Brilho do CTA | a cada 3,6 s desde 2,4 s | — | (.4,0,.2,1) | varredura de luz |
Hápticos: `.soft` em 1,25 s e `.success` quando o CTA aparece. Pro calmo (11.4_pro-calm): sem warp, núcleo, anel ou clarão; só o conteúdo, fade de 0,3 s.

**9.2 · Year in review**: a barra de cada slide (3 pt, topo) anima `width` 0 → 100% em 3200 ms **linear**; ao fim avança o slide (entrada `yvIn` 0,4 s, ease-out, escala .94 → 1). Reduzir Movimento: barras cheias e sem avanço automático.

**Sheets (Share my universe, Share to universe, Your video is ready, Edit Profile)**: `translateY(100%) → 0` em 0,36–0,38 s, (.2,.9,.25,1); fundo escurece 0,25 s. No SwiftUI use `.sheet` nativo (a animação do sistema), não replique.

## 3. Canais do JSON
`opacity` · `tx`, `ty` (pt) · `sx`, `sy` (escala) · `rot` (graus) · `blur` (pt) · `dashOffset` (0–100, traço desenhado: use `trim`) · `letterSpacingEm` · `offsetDistancePct` (posição ao longo de um caminho: veja `style` do layer, `offset-path`) · `clipInset` ([topo, direita, base, esquerda] em px/%, revela texto) · `color`/`background` (rgba 0–255, 0–1). Campos em `raw` são texto CSS (sombras, gradientes): troque no quadro mais próximo. Um canal só interpola entre os quadros que o definem. A curva de cada trecho é `easing` do quadro (ou da animação): `"linear"` ou `[x1,y1,x2,y2]` (`UnitCurve.bezier`).

## 4. Motor (SwiftUI, iOS 27)
Não escreva um `withAnimation` por elemento. Use um relógio único e avalie as faixas do JSON:

```swift
import SwiftUI

enum Easing: Decodable {
  case linear, bezier(Double, Double, Double, Double), steps
  init(from d: Decoder) throws {
    let c = try d.singleValueContainer()
    if let a = try? c.decode([Double].self), a.count == 4 { self = .bezier(a[0], a[1], a[2], a[3]) }
    else { self = .linear }            // "linear" or steps(): treat steps as linear and hold manually
  }
  func apply(_ x: Double) -> Double {
    switch self {
    case .linear, .steps: return x
    case let .bezier(a, b, c, d): return UnitCurve.bezier(startControlPoint: .init(x: a, y: b), endControlPoint: .init(x: c, y: d)).value(at: x)
    }
  }
}
struct Key: Decodable {
  var t: Double
  var opacity, tx, ty, sx, sy, rot, blur, dashOffset, letterSpacingEm, offsetDistancePct: Double?
  var color, background: [Double]?
  var easing: Easing?
}
struct Anim: Decodable { var name: String; var duration: Double?; var delay: Double; var easing: Easing; var iteration: Iter }
enum Iter: Decodable { case once, infinite
  init(from d: Decoder) throws { let c = try d.singleValueContainer(); self = ((try? c.decode(String.self)) == "infinite") ? .infinite : .once } }
struct Layer: Decodable { var id: String; var text: String?; var animations: [Anim]? }
struct ScreenClip: Decodable { var keyframes: [String: [Key]]; var layers: [Layer] }

struct Pose { var opacity = 1.0, tx = 0.0, ty = 0.0, sx = 1.0, sy = 1.0, rot = 0.0, blur = 0.0, dash: Double? = nil, ls: Double? = nil, along: Double? = nil }

extension ScreenClip {
  /// value of one channel at time t (seconds, already minus delay) for one animation
  func sample(_ ch: KeyPath<Key, Double?>, _ keys: [Key], _ anim: Anim, at t: Double) -> Double? {
    let ks = keys.filter { $0[keyPath: ch] != nil }
    guard let first = ks.first, let last = ks.last else { return nil }
    if t <= first.t { return first[keyPath: ch] }
    if t >= last.t { return last[keyPath: ch] }
    let i = ks.lastIndex { $0.t <= t }!
    let a = ks[i], b = ks[i + 1]
    let x = (t - a.t) / max(b.t - a.t, 0.0001)
    let e = (a.easing ?? anim.easing).apply(x)
    return a[keyPath: ch]! + (b[keyPath: ch]! - a[keyPath: ch]!) * e
  }
  func pose(_ layer: Layer, clock: Double, playOnce: Bool, holdAt: Double) -> Pose {
    var p = Pose()
    for an in layer.animations ?? [] {
      guard let keys = keyframes[an.name], let dur = an.duration else { continue }
      var t = (playOnce ? min(clock, holdAt) : clock) - an.delay
      if t < 0 { t = 0 }                                   // fill-mode backwards: first frame
      if !playOnce, an.iteration == .infinite { t = t.truncatingRemainder(dividingBy: dur) }
      t = min(t, dur)
      if let v = sample(\.opacity, keys, an, at: t) { p.opacity *= v }
      if let v = sample(\.tx, keys, an, at: t) { p.tx += v }
      if let v = sample(\.ty, keys, an, at: t) { p.ty += v }
      if let v = sample(\.sx, keys, an, at: t) { p.sx *= v }
      if let v = sample(\.sy, keys, an, at: t) { p.sy *= v }
      if let v = sample(\.rot, keys, an, at: t) { p.rot += v }
      if let v = sample(\.blur, keys, an, at: t) { p.blur = v }
      if let v = sample(\.dashOffset, keys, an, at: t) { p.dash = v }
      if let v = sample(\.letterSpacingEm, keys, an, at: t) { p.ls = v }
      if let v = sample(\.offsetDistancePct, keys, an, at: t) { p.along = v }
    }
    return p
  }
}

struct MotionLayer: ViewModifier {
  let clip: ScreenClip, layer: Layer, clock: Double, holdAt: Double
  var anchor: UnitPoint = .center
  func body(content: Content) -> some View {
    let p = clip.pose(layer, clock: clock, playOnce: true, holdAt: holdAt)
    content.opacity(p.opacity)
      .scaleEffect(x: p.sx, y: p.sy, anchor: anchor)
      .rotationEffect(.degrees(p.rot), anchor: anchor)
      .offset(x: p.tx, y: p.ty)
      .blur(radius: p.blur)
  }
}
extension View { func motion(_ clip: ScreenClip, _ id: String, clock: Double, hold: Double, anchor: UnitPoint = .center) -> some View {
  modifier(MotionLayer(clip: clip, layer: clip.layers.first { $0.id == id }!, clock: clock, holdAt: hold, anchor: anchor)) } }

struct MotionScreen<Content: View>: View {
  @Environment(\.accessibilityReduceMotion) var reduce
  let hold: Double; @State private var start = Date()
  @ViewBuilder var content: (Double) -> Content
  var body: some View {
    TimelineView(.animation) { ctx in
      content(reduce ? hold : ctx.date.timeIntervalSince(start))   // Reduce Motion: final frame
    }
  }
}
```
Regras: (a) um `TimelineView(.animation)` por tela, nunca vários; (b) `transform-origin` do CSS está no `style` do layer: passe como `anchor`; (c) a ordem do CSS é translate → rotate → scale; o motor acima aplica escala, rotação e deslocamento, que serve para os layers do onboarding (verifique a ordem nos que combinam rotação com deslocamento grande); (d) `dashOffset` desenha traço: `Shape.trim(from: 0, to: 1 - dash/100)`; (e) `offsetDistancePct` move um ponto sobre o `Path` indicado: `path.trimmedPath(from: 0, to: f).currentPoint`; (f) clip de texto: `.mask` com retângulo cuja largura segue `clipInset`.

## 5. Efeitos que fazem a tela parecer viva
Cada efeito abaixo aparece em várias telas. Sem eles a cena fica plana.
- **Brilho aditivo:** estrelas, faíscas e núcleos são `RadialGradient` + `.blendMode(.plusLighter)` + 1 a 3 `.shadow(color:radius:)` empilhadas (raio 6, 14, 28), nunca um círculo chapado.
- **Estrela com cauda:** 4 cópias da mesma cabeça atrasadas 0,05 / 0,10 / 0,15 s (tamanhos 11, 7,5, 6, 5 pt; opacidade 1, .6, .4, .25). Em SwiftUI: o mesmo `clock` com `clock - lag`. Veja os layers com nome `unst`, `vyst`, `obstar`.
- **Rajada de faíscas:** 8 a 12 pontos de 2 a 3 pt, cada um com ângulo fixo (`--a`) e distância (`--d`), saindo com `translateX` 6 → 16 pt (escala 1,3) e indo até `--d` (escala .3, opacidade 0) em 0,5 a 0,6 s, `cubic-bezier(.1,.7,.3,1)`. Desenhe em um `Canvas` por rajada.
- **Anel de impacto:** círculo de 1 a 1,5 pt, escala .3 → 3 (ou 5) em 0,6 a 1,2 s, opacidade .9 → 0, `cubic-bezier(.1,.7,.3,1)`.
- **Cruz de brilho (flare):** duas linhas finas de 44 a 70 pt com gradiente que some nas pontas (`transparent → cor → transparent`), escala 0 → 1,15 → .2 com rotação 45° → 0 → −20° em 0,5 s.
- **Desfoque que revela:** textos entram com `blur` 10 → 0, `ty` +16 → 0 e `opacity` 0 → 1 em 0,75 s `cubic-bezier(.16,1,.3,1)`, com 0,13 s entre linhas. Em listas grandes use `.compositingGroup()`.
- **Profundidade (parallax):** o céu faz zoom menor que o conteúdo (1,5 → 1 contra 3,8 → 1) e as camadas de estrelas rolam em velocidades diferentes (260, 160 e 85 s). Sem isso o zoom parece um simples redimensionamento.
- **Galáxia YOU (1.3):** vetor, desenhada grande (360 pt) e reduzida (0,263). Gere as estrelas com um gerador pseudoaleatório com semente (mulberry32, semente 7) para que seja igual sempre:
```swift
struct RNG { var s: UInt32
  mutating func next() -> Double { s &+= 0x6D2B79F5; var t = (s ^ (s >> 15)) &* (1 | s); t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t; return Double((t ^ (t >> 14))) / 4294967296 } }
// two logarithmic arms: r = 11·exp(0.5·θ), θ ∈ [0.35, 5.05]; 520 stars per arm, scatter σ ≈ (4 + 0.075·r) around the arm
// + 260 bulge stars (radius |N|·20) + 140 halo stars (radius √u·170, opacity .15–.45)
// size = (0.45 + u^2.2·1.7)·(1.25 − r/190); opacity = (0.35 + 0.65·u)·(1 − r/200); colours #FFF6D6 .4, #FFE08A .25, #E4DEFF .2, #FFC46B .15
// tilt −18°, vertical squash .52, arms rotate 360° in 140 s (linear); two blurred gas strokes under the stars (σ 9 pt, 30 pt wide), core 20 pt sphere, 3 orbits 52×27, 92×48, 132×69 pt
```
- **Planetas e núcleos esféricos:** `RadialGradient` com centro de luz em (34%, 28%), borda de luz de 0,8 pt e um brilho especular elíptico. Nunca cor sólida.
- **Letras que chegam:** cada letra é uma view própria com escala (3,2 × .3), blur 8 → 0, e o espaçamento do bloco fecha de 1 em para .16 em; brilho amarelo que percorre as letras (0,12 s cada).
- **Contagem 3 · 2 · 1 (1.6):** número 92 pt com pop de ×1,5 → 1 e anel (track + arco amarelo `trim` 0 → 1 em 1 s linear), que aparecem e somem com cada número.


## 6. Como conferir
1. Grave a tela do app e a do HTML lado a lado e compare quadros em 0,5 / 1 / 2 / 3 / 5 s.
2. Cada fase entrega um vídeo curto da tela em movimento e a lista do que ficou diferente do HTML. Tela estática não vale.
3. Telas capturadas (todas as 11.1_*, 9.x, 8.1, 8.2, 6.x, 11.4): o JavaScript foi removido; o HTML mostra o estado final e as animações CSS. Os estados intermediários (por exemplo, o voo das estrelas do 8.2) estão na seção 2.
