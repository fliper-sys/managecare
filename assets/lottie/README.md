Lottie Assets mapping for Manage Care

This file documents recommended usage for the Lottie files in `assets/lottie/`.

Top-5 (implemented):
- `success.json` — Success states and confirmations (forms submitted, payments succeeded, order completed).
  - Used in: `New Sale` quick action, `Customers` quick action.
- `error.json` — Error dialogs and failure states (save failed, network error).
  - Helper: `showErrorLottieDialog(context, ...)` and `runWithLottieErrorHandling(context, action)`.
- `onboard1.json` — Welcome / large onboarding banner.
  - Used in: Owner Dashboard welcome banner.
- `onboard2.json` — Micro onboarding / hint dialogs and short tips.
  - Used in: `Inventory` and `Reports` quick-action hint dialogs.
- `loop.json` — Subtle background loops / decorative motion for headers and empty states.
  - Used in: Dashboard header (small loop animation).
  - Used in: Dashboard header (small loop animation), product icons and empty-state illustrations in `sales` and `inventory` screens.

Other suggestions:
- `onboard3.json` — Onboarding step animations (use in multi-step walkthroughs).
- `delivery-boy.json` — Delivery/order assignment states and delivery screens.
- `farm-animation.json` — Agriculture vertical screens (farm hints, tips, empty states).
- `singing-contract.json` — Contract signed/agreements completed flows.
- `web-design-layout.json`, `website-building-of-shopping-sale.json` — E-commerce/web onboarding and screens.
- `woman-shopping-online.json` — Shopping empty-states and customer CTAs.
  - Used in: Customer avatar animation in `customer_card.dart`.

Usage patterns:
- For success dialogs: `await showSuccessLottieDialog(context, title: 'Done', message: 'Saved successfully');`
- For errors: prefer `await runWithLottieErrorHandling(context, () async { await mySave(); });`
- For simple hints: `await showHintLottieDialog(context, title: 'Tip', message: 'You can scan barcodes...');`

Notes:
- Keep long Lottie loops subtle and low opacity when used in background or header.
- Non-blocking hints should be `barrierDismissible: true` and `repeat: false` in the dialog.
- If you want me to wire `error.json` into specific failing flows (e.g., save in product editor, login failure), tell me which screens and I will add safe error handling wrappers.

