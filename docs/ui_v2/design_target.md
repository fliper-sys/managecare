# Design target: the Flagship Tactile-Luxury demo

**The flagship demo is the goal and the end-result priority.** Every v2 screen must have exactly the
same design feel and motion as the demo, and go further. If anything in the proposal, blueprint or
earlier code differs from the demo, the demo wins.

Reference files (open in a browser):
- `reference/flagship_demo_chatgpt.html`: the original demo (Retail).
- `reference/flagship_demo_12_businesses.html`: the same look across 12 business types, driven by a profile per business.

## Acceptance rule
A screen is done only after a side-by-side review against the demo, in light and dark, on a
low-end Android phone. "Close enough" fails the review. "More" means the things the demo does not
show: every business type, offline use, reduced motion, accessibility, real data and real plan prices.

## What the demo contains, and where it lands in Flutter
| Demo element | Flutter piece | Phase | Status |
|---|---|---|---|
| Colour, radii (12, 16, 28, 32), soft card shadow, glass fill | `AppTokens` | 1 | done |
| Tactile press (0.945 buttons, 0.975 cards) | `TactilePressable`, `ManageCard` | 1 | done |
| Status chips, skeleton loading, bottom sheet | `StatusChip`, `SkeletonBlock`, `SheetScaffold` | 1 | done (sheet radius 32) |
| Spring curves, reduce motion | `Motion` | 1 | done |
| Plus Jakarta Sans, JetBrains Mono, tabular figures, 9 to 11 px micro labels | `AppType` | 2 | done; variable fonts bundled in assets/fonts |
| Page ground: accent glow and fine grain | `AmbientBackground`, `GrainOverlay` | 2 | done |
| Glass surfaces with specular 1 px hairline | `GlassSurface` (BackdropFilter blur 24, gradient border, solid fallback) | 2 | done |
| Staggered entrance (42 ms steps, 480 ms) | `StaggerIn` | 2 | done |
| Dynamic Island status pill (114x30 to 248x42, 3.3 s) | `StatusIsland` overlay | 2 | done |
| Sliding pill in the tab bar, raised centre action | `PillTabBar` | 2 | done |
| Hero card: accent gradient, tilt sheen, counting figure, self-drawing sparkline | `HeroKpiCard`, `HoloTilt`, `OdometerText`, `SparklineDraw` | 3 | done (pointer tilt; gyroscope tilt not yet) |
| Swipe rows (action at 56 px, clamp 96 px) with a visible button too | `SwipeRow` | 3 | done |
| Spotlight search sheet | `SpotlightSheet` | 3 | todo |
| Plan card with ring and usage line | `PlanSummaryCard` | 3 | done; tier cards and confirm sheet still todo (`plan_journey/`) |
| Quick actions row, Retail home screen | `QuickActionsGrid`, `RetailHomeView` | 3 | done (view); connector to providers todo (3b) |
| Cart steppers with pop, payment chips, perforated thermal receipt, drawn tick | `CatalogueCart`, `CheckoutSheet`, `ReceiptPaper`, `CheckDraw` | 4 | todo |
| Reports: period pills, payment split bars, top items | `reports/` | 4 | todo |
| Per-business accent, wording and work feed | `BusinessProfile` | 1 onward | contract done, Retail profile done |

## Notes
- Hardware frame, status bar and the physical island in the demo are presentation only. In the app the island pill sits just under the system status bar.
- Backdrop blur is costly on low-end phones. `GlassSurface` takes a `blur` setting and falls back to a solid `AppTokens.glass` fill when motion is reduced or the device is slow. Measure on the baseline device before shipping.
- Pointer tilt on the hero card becomes a gyroscope-driven tilt on phones, off when motion is reduced.

- Not yet compared against the demo on a device. `GlassSurface` omits the demo's 180% backdrop saturation; revisit after a side-by-side review.
