## Phase 1 · Foundation — report
Built: ✓ (clean build, new derived data) · Warnings: 0 · Tests: 1931 passed (unit suite; the one failure, `ScriptAIServiceTests/privateCloudComputeIsOnOnlyWithTheEntitlement`, is the known environment issue: the sandbox can't read the entitlements file under ~/Desktop) / 2 new (`TabBarUITests`, rewritten) · UI: `TabBarUITests`, `DesignCatalogueUITests` pass

### Verification against the acceptance criteria
- Tokens (02 §1.2), `CueSlider` (§6 ranges in `CueSliderSpec`), `ThemeRail`, `PlatformDot`, `RecPill`, `StateChip`, `EmptyState`, microcopy: present, as committed.
- `PaletteContrastTests` covers the new pairs (selection bar, state strip, chips, slider parts, REC, empty state).
- **Fixed in this pass, reported by the user:** the tab bar was a custom view (`CueTabBar`) in a `VStack` under the content. Content never ran beneath it, the capsule had a stray top highlight line and dragging across the tabs (native Liquid Glass) did nothing. It is now the **system `TabView`**: content scrolls under the bar, the selection slides with a drag, the capsule is the system's. Icons are the v29 `CueIcon` rasterized as template images (`CueTabImage`), Record is a two-colour image, and the bar hides through `toolbarVisibility(.hidden, for: .tabBar)`.
- The generator `design/cue-v29/tools/generate_cue_icons.py` had been deleted from the working tree by the new package; restored from git.

### Done
- Native tab bar: `Screens/Main/MainView.swift`, `DesignSystem/Tokens/CueIcon+TabImage.swift`; removed `CueTabBar`, `glassBar*`/`tabCapsule*` tokens, `CueMotion.tabCapsule`, the tab bar contrast test.
- UI tests now use `app.tabBars` (`CueApp.cueTabBar`, `TabBarUITests`, `OnboardingUITests`).
- `DESIGN_PROJECT.md` §5 and §13 updated.

### Captures (`design/cue-v29/reports/captures/`)
- `tabbar-scripts.png`, `tabbar-takes.png`, `tabbar-profile.png`, `tabbar-settings.png`: each tab active; the list runs under the bar
- `catalogue-sliders.png` (min 80 / default 150 / max 220 wpm, stepped, from centre), `catalogue-parts.png` (ThemeRail, PlatformDot, RecPill, StateChip, EmptyState), `catalogue-icons.png`, `catalogue-colors.png`, `catalogue-tabbar.png` (tab icons), `catalogue-effects.png`, `catalogue-sky.png`

### Animations (measured)
| name | duration | curve | Reduce Motion |
| tab selection capsule | system (native) | system | system |
| empty-state orbiter | 9 s / turn | linear | static |
| slider snap | 0.28 s | spring .72 | no animation |

### Not matched exactly
- Tab bar "26 pt from the bottom edge", the 56 pt capsule and the 10 pt labels of 02-Tokens §3: the user requires the native bar, so the system decides geometry, glass and label size · only icon size (26 / 30 pt) and the yellow tint are ours.
- Icon shapes are the v27 ones: `icons/` of the v29 package (stage 4) hasn't been delivered.

### Kept from v27 that the board doesn't show
- Nothing removed.

### Next phase starts with
- Models and migration (`Script.isFinished/state`, `ScriptType.mythFact/.pov`, `BrandBrief/BrandStore`, `CreatorProfile` fields, `PrompterSettings` box/line, `SkyMemory`) with v27 fixtures.
