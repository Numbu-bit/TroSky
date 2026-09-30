# TroSky Design Tokens

**Source:** the Figma Make file (`design/figma-make/globals.css`) plus the design-system side panel in the screenshots.

This is the only source for visual values. The brand identity PDF is **superseded** wherever it differs from this file (for example, its emerald `#00A86B` is replaced by `#0E9E6D`).

## Colors
| Token (Dart) | CSS var | Hex | Figma name | Seen used for |
|---|---|---|---|---|
| `green` | `--green` | `#0E9E6D` | Emerald Green | Primary buttons, splash/onboarding-1 background, header of sign up, active nav, links |
| `greenDark` | `--green-dk` | `#0B7E57` | — | Pressed/hover, gradient dark end |
| `greenLight` | `--green-lt` | `rgba(14,158,109,0.12)` → `Color(0x1F0E9E6D)` | — | Tinted backgrounds (e.g. selected sidebar item, info cards) |
| `blue` | `--blue` | `#1F6FB2` | Sky Blue | "See all" links, gradient end on the promo card |
| `navy` | `--navy` | `#12263B` | Deep Navy | Home header, onboarding 2–3 backgrounds, promo card |
| `ink` | `--ink` | `#1D2027` | — | Primary text, text on amber |
| `amber` | `--amber` | `#F4B333` | Amber Gold | Onboarding-3 CTA, active page indicator, "Try it", badges, "NEW FEATURE" label |
| `red` | `--red` | `#E23D3D` | Error Red | Errors, **SOS button** |
| `success` | `--success` | `#16A34A` | — | Success states |
| `textPrimary` | `--txt` | `#1D2027` | — | Body text |
| `textSecondary` | `--txt-2` | `#5B6472` | — | Secondary text, labels |
| `border` | `--border` | `#E4E8EE` | — | Input and card borders, dividers |
| `surface` | `--surface` | `#FFFFFF` | — | Cards, inputs, bottom sheets |
| `background` | `--bg` | `#F5F7FA` | App Background | Screen background |

## Typography
| Role | Family | Weight | Notes |
|---|---|---|---|
| Headings (h1–h5, screen titles, onboarding titles) | **Plus Jakarta Sans** | **800 ExtraBold** (700 also available) | e.g. "Book a Seat, Not a Whole Car", "Welcome to TroSky" |
| Body, buttons, inputs | **Inter** | 400 Regular (300–700 available) | Buttons look 600–700 |

Both fonts are **bundled as assets** (`trosky_ui/assets/fonts/`, from the Google Fonts OFL releases), never fetched at runtime.

Exact per-element sizes are **not in the CSS**. Take them from the Figma Make component code (see "Still needed"). Until then, measure from the screenshots against the 390 × 844 frame and mark each measured value `// measured` so it can be corrected later.

## Frame and layout
- The design frame is **390 × 844** (iPhone 14/15), iOS 17+. The layout must scale to Android widths from 360 to 430.
- Light theme: Splash, Onboarding 1, Sign Up, Home.
- Dark (navy) theme: Onboarding 2 and 3 only. These are dark *screens* inside a light app, not a separate dark mode.

## Motion (from the Figma CSS)
| Name | Spec | Flutter |
|---|---|---|
| pulse-dot | 2 s ease-in-out infinite, scale 1 → 1.6, opacity 0.8 → 0.3 | Live location dot, "live" indicators |
| slide-up | 0.4 s, `cubic-bezier(0.16,1,0.3,1)`, translateY 20 → 0, fade in | Entrance of cards and content |
| float | 3 s ease-in-out infinite, translateY 0 → −6 | Onboarding illustrations |
| spin-slow | linear 360° rotation | Loaders, decorative rings |
| price-flash | 0.5 s, ink → green, scale 1.05 | Fare changing (fare split) |
| ripple | scale 1 → 3, opacity 0.6 → 0 | Splash rings, SOS, map pins |

Respect the device's reduce-motion setting (`MediaQuery.disableAnimations`).

## Accessibility notes (flagged, not changed)
- White on green `#0E9E6D` is **3.43:1**. That's fine for the bold 16 px+ button labels in the design (large text). Never use it for small body text.
- Green text on white or on `#F5F7FA` is 3.4 / 3.2:1, so use it for bold links only.
- Ink on amber is 8.8:1 ✓. White on navy and white on blue ✓.

## Still needed from Figma Make
1. **Component code for each screen** (the TSX files behind the screens). This gives exact font sizes, radii, shadows, paddings, and the **gradient stops** (the splash background runs from dark green at the top to a lighter green at the bottom; the promo card runs navy → blue).
2. **Assets:** the TroSky logo (SVG), and the onboarding illustrations (bus, fare-split circle, calendar). If these are drawn in code in Make, the code is enough, because they can be rebuilt as Flutter widgets or exported as SVG.
3. **Icon set** used in Make (probably `lucide-react`; check the imports). We'll use the same set in Flutter (`lucide_icons_flutter`) so icons match exactly.
