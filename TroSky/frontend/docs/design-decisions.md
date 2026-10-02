# TroSky Design Decisions

Product decisions that settle questions the Figma Make file leaves open. These rules override any conflicting note in `design-tokens.md`, and they apply to every screen.

| # | Topic | Decided | Status |
|---|---|---|---|
| 1 | Logo | 30 Sep 2026 | In force (`TroskyLogo`), until a designer-exported SVG replaces the images |
| 2 | Sizing | 30 Sep 2026 | In force |
| 3 | Button states | 30 Sep 2026 | In force (`TroskyButton`) |
| 4 | Splash timing | 1 Oct 2026 | In force (`launchDestinationProvider`) |
| 5 | Insets | 1 Oct 2026 | In force (reference: Onboarding) |
| 6 | Sign-up flow | 1 Oct 2026 | Decided; built in Step 7 |
| 7 | Driver entry | 1 Oct 2026 | Decided; built in Step 7 |
| 8 | Onboarding quirks | 1 Oct 2026 | Kept as designed; to raise with the designer |
| 9 | Offline start | 1 Oct 2026 | In force (`SessionController`) |
| 10 | OTP sign-in | 1 Oct 2026 | In force (Sign in screen) |
| 11 | Welcome button label | 1 Oct 2026 | In force (Welcome screen) |
| 12 | Passenger navigation | 1 Oct 2026 | In force (`PassengerShell`, `TroskyTabBar`) |
| 13 | Map | 1 Oct 2026 | In force (`HomeMap`); needs a tile provider before launch |
| 14 | Vehicle pins | 1 Oct 2026 | In force; G16 landed, so live mode shows real vehicles |
| 15 | Favourite routes | 1 Oct 2026 | In force; G4 landed, so they come from the backend |
| 16 | Subscribe banner | 1 Oct 2026 | In force (`Feature.subscriptions`) |
| 17 | Emoji | 1 Oct 2026 | In force |
| 18 | SOS on Home | 1 Oct 2026 | In force (SOS placeholder); backend gap G19 |

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

## 5. Insets

This is the standard for every screen. **The phone's real status bar and home bar replace the bars drawn in the Figma frames.**

- **Top:** keep the design's spacing. The drawn `StatusBar` is 48 px, so content starts 48 px from the top, unless the phone's own status bar is taller.
- **Bottom:** keep the design's bottom padding (for example `pb-6` = 24 px under the last button), unless the phone's own bottom inset is larger, such as with three-button navigation.

The reference implementation is `OnboardingScreen`. In code that is `max(design spacing, MediaQuery.viewPadding)` for the top and for the bottom.

## 6. Sign-up flow

**The backend stays as it is.** The frontend adapts to its endpoints.

1. **Welcome** (Sign Up, S-06): phone number, as designed.
2. **Your details:** full name, email and password. This screen is not in Figma, so it is built from existing `trosky_ui` components.
3. **OTP:** the code sent to the phone.
4. **Signed in.**

## 7. Driver entry

**There is no role-chooser screen.** The Welcome screen gets one small link: "Driving for TroSky? Sign up as a driver". The link switches the app mode to driver and runs the same sign-up flow with `role=driver`.

## 8. Onboarding quirks

The quirks in the onboarding illustrations and layout stay as designed. They are listed in the Step 5 report, for example "YOUR SEAT" being wider than its pill and every weekday being ticked. They will be raised with the designer later.

The illustration labels ("YOUR SEAT", "price drops", "July 2026" and so on) stay untranslated for now.

## 9. Offline start

**When the app starts with a saved session but no network, it opens Home in an offline state.** The last `GET /users/me` is cached on the device so Home can show who is signed in, with an offline banner and a Retry.

The app signs the user out **only when the backend rejects the session**:
- 401 on refresh (including `REFRESH_TOKEN_REUSE_DETECTED`)
- `ACCOUNT_SUSPENDED`

It **never signs out because of a network error**. Timeouts, no connection and server errors keep the session.

## 10. OTP sign-in

Signing in with a one-time code is kept as a **secondary** option. It is reached from the Sign in screen through **"Forgot password? Sign in with a code"**. This is the only way to recover an account until backend gap G1 (password reset) is fixed.

The backend sends nothing to a number with no account but answers the same way (see the Step 6 report). So once the 60 s resend cooldown ends, the code screen shows **"No code? Check this number has a TroSky account."**

## 11. Welcome button label

The Welcome screen's main button says **"Continue"** instead of the design's "Send OTP", because no code is sent at that step. The code is only sent after "Your details" (decision 6). Everything else on the Welcome screen follows the design.

## 12. Passenger navigation

The passenger app has a **bottom tab bar: Home, Trips, Wallet, Profile.** The passenger designs have no tab bar, so it is styled exactly like the one in Driver Home (D1): emoji over a 10 px label, green for the selected tab with a 16 × 3 bar under it. Wallet takes D1's 💰, which D1 uses for Earnings.

Trips, Wallet and Profile are placeholders for now. "Sign out" is on the Profile placeholder. Android back on Home leaves the app; on another tab it goes back to Home first.

## 13. Map

The map is **flutter_map with OpenStreetMap tiles**, because the design embeds OpenStreetMap. The tile URL comes from the build settings (`MAP_TILE_URL`, see `env/README.md`), and the map always shows "© OpenStreetMap contributors".

**The public OpenStreetMap tiles are for development only.** Their usage policy doesn't allow an app's production traffic, so a tile provider (hosted or our own) is needed before launch. Changing `MAP_TILE_URL` is enough to switch.

## 14. Vehicle pins

The Home map shows vehicles as the design's `BusPin` (Shared.tsx): green, or amber when 2 seats or fewer are free.

- **Mock mode:** the mock backend places three vehicles around the map centre, where the design draws them.
- **Live mode:** only vehicles from `GET /vehicles/nearby` (backend gap G16). **Never show invented vehicles in live mode.**

G16 landed in backend 0.12.0 (1 Oct 2026), so live mode shows real vehicles out on trips with a GPS ping from the last 5 minutes. With none, the map has no pins.

## 15. Favourite routes

The rule was: keep favourite routes on the device until backend gap G4 exists; when there are none, show a short empty line instead of the chips.

G4 landed in backend 0.12.0 (1 Oct 2026), so favourites come from `GET /users/me/favourite-routes`. The last list is kept on the device for offline starts. The empty line still applies.

## 16. Subscribe banner

The "Subscribe your commute" banner on Home is behind the feature flag `subscriptions` (`FEATURES` in the build settings). By default it is **on in mock mode and off in live mode**, because the backend has no subscriptions (gap G14) and the product decision is still open.

## 17. Emoji

The design's emoji stay exactly as drawn (👋, 🔔, the tab bar's 🏠 🗺️ 💰 👤, and so on). They render with the phone's emoji font.

## 18. SOS on Home

The SOS button on the Home map opens the SOS screen (a placeholder for now). The backend can only raise an SOS for a trip (`POST /trips/{trip_id}/sos`), but the Home design shows SOS at all times, so backend gap G19 asks for an SOS without an active trip.

