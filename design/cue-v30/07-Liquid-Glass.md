# 07 · Liquid Glass (mandatory rule, v30)

**Rule:** Cue uses **native Liquid Glass (iOS 26+/27) wherever it exists**. Only when a component is custom (not a system control) do you **simulate** glass with the recipe below. Never draw solid buttons in navigation bars, toolbars or tab bars.

## 1. Native first (SwiftUI) — use these, not custom views
| Place | Use | Do not |
|---|---|---|
| Tab bar | `TabView` + `Tab`, `.tabBarMinimizeBehavior(.onScrollDown)`; Record stays a normal tab in the middle (never `role: .search`; see 09 §4) | draw your own capsule/orb |
| Navigation bar | `NavigationStack` + `.toolbar { ToolbarItem }` — the system draws the glass circles/capsules | put a `Button` with background in a custom header |
| Back | system back button (chevron in a glass circle, no title) | text "‹ Scripts" |
| Close a sheet | `Button(role: .close)` in `ToolbarItem(placement: .cancellationAction)` → xmark in a glass circle, leading | a text “Close” / “Not now” link |
| Close a tip | TipKit’s own xmark (`TipView`) | a custom ✕ glyph |
| Toolbar text actions (Done, Cancel, Edit) | `ToolbarItem(placement: .confirmationAction / .cancellationAction)` → automatic glass | text without glass |
| Grouped toolbar buttons | `ToolbarItemGroup` (shared glass) + `ToolbarSpacer` | separate solid circles |
| Primary action button (yellow) | `.buttonStyle(.glassProminent).tint(.cueYellow)` | flat fill with no highlight |
| Secondary buttons | `.buttonStyle(.glass)` | `rgba` fill without blur |
| Sheets | `.sheet` + `.presentationDetents` (system glass background on iOS 26+) | custom modal over a rectangle |
| Menus / pickers / context menus | `Menu`, `Picker`, `.contextMenu` | custom popovers |
| Search | `.searchable` (glass search field in the toolbar) | custom search field in the header |
| Custom glass shapes | `.glassEffect(.regular.interactive(), in: .capsule)` and `GlassEffectContainer` to group/merge; `.glassEffectID` + `@Namespace` for morphing | `.ultraThinMaterial` for controls |
| Scripts AI dock (fixed above the tab bar, only on Scripts) | `.safeAreaInset(edge: .bottom)` with `.glassEffect(.regular, in: .rect(cornerRadius: 28))` inside a `GlassEffectContainer` | `tabViewBottomAccessory` (a one-line capsule; too small for the dock’s chips + field) |

Lists and content cards are **not** glass (Apple guidance: glass is for the control layer). Content cards use the translucent card tokens in §3.

## 2. Simulated glass for custom components (when no native control fits)
Use only for: the Scripts dock, the recorder bar, editor panels, the state strip, floating chips over video.
| Layer | Value |
|---|---|
| Fill | white 18% → 4% (top 0–48%) → 9% vertical gradient, over `rgba(30,32,50,0.34)` |
| Blur | 14 pt, saturation 185%, brightness 1.08 (`.glassEffect` when available; otherwise `Material.ultraThin` + overlays) |
| Rim | 0.5 pt, white 24% |
| Specular highlight | inner top line 1 pt, white 38% |
| Inner shadow | inner bottom line 1 pt, black 22% |
| Drop shadow | y 4, blur 14, black 26% |
| Press | scale 1.10 with spring (response 0.32, damping 0.6) + brightness +15%; haptic `.soft` |
| Prominent (yellow) | yellow fill + white 42%→0% top highlight, rim white 50%, glow yellow 22% |
| Reduce Transparency | fill becomes `#1F2236` solid, rim stays; blur off |
| Increase Contrast | rim 1 pt white 50% |

## 3. Content cards (not glass, but translucent so the sky shows through)
| Token | Value |
|---|---|
| card | `rgba(22,24,38,0.64)` + blur 3 pt, saturation 140% |
| card raised | `rgba(31,34,54,0.68)` |
| card high | `rgba(42,44,64,0.70)` |
| AI aurora card | aurora gradients over `rgba(26,24,64,0.60)` |
| Reduce Transparency | the same colours, alpha 1.0 |

## 4. Never
- A navigation or toolbar button with a solid background.
- Glass on top of glass (use `GlassEffectContainer` to merge instead).
- Glass in list rows or content cards.
- Text on glass below 4.5:1 — test over the brightest part of the sky.
- Hiding the system back button to draw your own.

## 5. In the prototype
`prototype/CueBoard30.dc.html` simulates §1 and §2 on every board: nav buttons become glass circles/capsules (`.__lg`, `.__lgp`), back links become a chevron in a glass circle, and content cards turn translucent (§3). In SwiftUI, replace every one of these with the native API in §1.
