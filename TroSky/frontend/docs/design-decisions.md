# TroSky Design Decisions

Product decisions that settle questions the Figma Make file leaves open. These rules override any conflicting note in `design-tokens.md`, and they apply to every screen.

| # | Topic | Decided | Status |
|---|---|---|---|
| 1 | Logo | 30 Sep 2026 | In force (`TroskyLogo`), until a designer-exported SVG replaces the images |
| 2 | Sizing | 30 Sep 2026 | In force |
| 3 | Button states | 30 Sep 2026 | In force (`TroskyButton`) |
| 4 | Splash timing | 1 Oct 2026 | In force (`launchDestinationProvider`) |

## 1. Logo

**The logo in the Figma screens is the official TroSky logo.** It is a green pin with a front-view bus and an italic "TroSky" wordmark.

The Figma Make code draws it from two raster images:

| Figma import | Source file (`design/figma-make/src/imports/`) | Used for |
|---|---|---|
| `troSkyLogoBright` | `Screenshot_2026-08-02_124000.png` | Full logo on the white splash card, 200 px wide |
| `troSkyLogo` | `WhatsApp_Image_2026-07-29_at_16.20.47.jpeg` | Small logo (for example in headers and inside the QR code) |

`TroskyLogo.bright()` and `TroskyLogo.mark()` in `trosky_ui` use these images, copied unchanged to `packages/trosky_ui/assets/logo/`:

| Widget | Asset | Pixels | Largest use | Sharpness |
|---|---|---|---|---|
| `TroskyLogo.bright()` | `trosky_logo_bright.png` | 611 × 277 | 200 px wide on the splash card | About 3 px per logical px, enough for 3× screens. It is a screenshot, so edges are slightly soft when zoomed in |
| `TroskyLogo.mark()` | `trosky_logo_small.jpg` | 853 × 271 | 36 px tall (admin) | 7.5 px per logical px at 36 tall. JPEG with a dark background baked in and no transparency |

Both images carry the tagline "Your Journey. On Tiine. Every Tiine." with the "Tiine" typo. It is part of the artwork, so it stays until the SVG arrives.

Replace them with the designer-exported SVG when it exists (`TODO(logo)` in `trosky_logo.dart`).

**Not used:** `design/assets/trosky-logo.svg` and `design/assets/trosky-icon.svg`, and their copies in `packages/trosky_ui/assets/logo/`. They are **not the brand logo**. They show a navy pin, a side-view bus and an upright wordmark. They stay in the repo for reference only, and `trosky_ui` doesn't bundle them. Do not use them in any screen.

## 2. Sizing

- **1 CSS px in the Figma code = 1 Flutter logical px.** Use every size, spacing, radius and font size exactly as the design gives it.
- **Don't scale by screen width.** The design is drawn on a 312 px wide screen (see "Frame" in `design-tokens.md`). Real phones are wider, and sizes stay the same on them.
- **Layouts stretch horizontally to fill the screen.** Full-width elements take the real screen width. Fixed-size elements keep their design size.
- **Content must fit a 360 px wide phone without overflow.**
- **Respect the phone's text-size setting.** Don't clamp or ignore `TextScaler`. Every screen must have no overflow at 1.3× text scale.

## 3. Button states

The Figma code defines no pressed, disabled or loading state for buttons. The states built in Step 3 in `TroskyButton` are approved as they are:

| State | Look |
|---|---|
| Pressed | The shadow is removed. The green variants switch to `greenDark`. |
| Disabled (`onPressed` is null) | 70 % opacity (`TroskyOpacity.disabled`) and no shadow, following the "Go Offline" button in D1. |
| Loading | A spinner in the label colour replaces the label, and taps are ignored. Screen readers hear "<label>, loading". |

## 4. Splash timing

The splash's 1.5 s minimum is a **soft target**. The timer starts when Flutter reports that its first frame is drawn (`firstFrameShown` in `launchDestinationProvider`). Android removes its own launch screen a little after that and fades it out, and Flutter can't see either step.

Measured on a TECNO BG6 (Android 13) on 1 Oct 2026, the splash was on screen for about 1.3 s: a 0.18 s fade-in, then about 1.1 s fully visible. **This is accepted.** Don't add a native Android hook to stretch it to a full 1.5 s.
