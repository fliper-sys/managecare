Previewing the landing page

To preview the landing page locally:

1. Open the file directly in your browser:
   - Open `web/landing/index.html` in Chrome/Edge/Firefox.
   - Note: Some features (fonts) require internet access.

2. Serve using a local HTTP server (recommended):
   - Python: `python -m http.server 8080` (run from `web/landing` and open http://localhost:8080)
   - Node: `npx serve .` (run from `web/landing`)

Files added:
- `index.html` — main landing page
- `styles.css` — page styles and animations
- `app.js` — small scripts for scroll reveal and nav

Next steps:
- Replace text and assets with your brand copy and logos
- Hook up forms or CTA actions to your web backend or contact flow
- Add images or Lottie animations in `hero-art` for richer visuals
