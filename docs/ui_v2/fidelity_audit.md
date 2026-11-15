# Fidelity audit (static), 15 Nov 2026, branch head `68980c3`

Scope: the code on `redesign-v2`, read against the flagship demo checklist in `design_target.md`.
**Not measured:** how it looks or feels on a device, frame rate, blur cost, side-by-side with the demo.
No Flutter SDK was available, so nothing has been rendered. Scores are an estimate from the code.

## Scorecard
| Area | Score | Evidence |
|---|---|---|
| Foundations (tokens, fonts, radii, curves, contrast) | 9/10 | All table rows done; fonts bundled; contrast checked for the token pairs. Not seen on screen. |
| Demo elements built | 15 of 17 rows done | Spotlight search and Reports not built. |
| Demo elements actually on screens | 12 of 15 signature pieces | Never shown on any screen: `PillTabBar` (and `GlassSurface`, which only it uses) and `StatusIsland`. |
| Same feel across the screens | Home 8, Plan 8, Receipt 8, Switcher 7, POS 6, History 6 (of 10) | Hero, swipe rows, quick actions and plan card exist only on Retail home. POS and History use cards, chips and skeletons but not the hero feel. |
| Material leakage (default look) | 5/10 | POS: 12 SnackBars, 6 IconButtons, 2 default page routes. History: 3 SnackBars, 1 AlertDialog, default date picker, 2 default spinners. Price editor: AlertDialog. 9 TextFields on default Material shape with local colours. |
| Animation coverage vs demo | 10 of 16 | See list below. |
| Reduced motion | 6/10 | Honoured in stagger, skeleton, tick, tilt, glass. No reduced-motion check in odometer, sparkline, swipe, press, pill tab bar, island. |
| Accessibility | 7/10 | 29 semantic labels, controls 44 px or more. Gaps: price tap target in catalogue row is 32 px high; header icon buttons use default ink, not the tactile press. |

## Animation inventory
In the app and visible on screen: press scale, staggered entrance, skeleton shimmer, hero tilt, counting
figure, self-drawing sparkline, swipe rows, drawn tick on the receipt, sheet and phase cross-fade.

Built but never shown: Dynamic Island pill, sliding tab pill.

Missing against the demo: cart stepper pop, add-to-cart feedback, cart bar slide in and out, totals that
roll when they change (cart bar, checkout total, history stats), list row add and remove, page transition
between screens, chip pop.

## Fix order (largest gain first)
1. Fire `StatusIsland` for sale recorded, offline saved, synced and failed, replacing the 15 SnackBars.
2. Use `OdometerText` for cart total, checkout total and history stats.
3. Stepper pop, cart bar enter and exit, add feedback.
4. Styled input fields, date range and confirm dialogs (one `ManageField`, one `ManageDialog`).
5. A v2 page route with the demo's curve, replacing `MaterialPageRoute` in v2 screens.
6. Tab bar shell with `PillTabBar` (needs approval: it changes app navigation).
7. Reduced-motion checks in the six components; 44 px price target; tactile header buttons.
8. Device pass: low-end Android, light and dark, blur cost, side-by-side with the demo.
