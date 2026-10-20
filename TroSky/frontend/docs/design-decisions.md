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
| 18 | SOS on Home | 1 Oct 2026 | In force (SOS placeholder); G19 landed in 0.13.0, used when the SOS screen is built |
| 19 | Search entry screen | 2 Oct 2026 | In force (`SearchScreen`, P-02) |
| 20 | Fare display | 2 Oct 2026 | **Ended 10 Oct 2026**: G20 landed (backend 0.13.0), live shows the full design |
| 21 | Approaching / passed | 2 Oct 2026 | **Ended 10 Oct 2026**: G21 landed, live shows the full design |
| 22 | Filter pills | 2 Oct 2026 | In force; since 10 Oct 2026 the backend sorts and filters |
| 23 | Passenger names | 2 Oct 2026 | In force (`SeatSelectionScreen`) |
| 24 | Price on the seat screen | 2 Oct 2026 | **Ended 10 Oct 2026**: the fare quote landed, live shows the full design |
| 25 | Seat layout | 2 Oct 2026 | In force (`SeatMapLayout`) |
| 26 | Admin web | 11 Oct 2026 | In force: `apps/admin_web` removed |
| 27 | Sign-up location | 20 Oct 2026 | In force (`SignUpLocator`, Your details S-06) |

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

## 19. Search entry screen

The screen where the passenger enters a journey (P-02) **is not in Figma**. It is built from existing components in the style of the Search Results header (P6): the navy header with the round back button, the from/to block, and the filter-pill style for "Now" / "Schedule".

- **From** is "Current location" by default: the search sends the phone's position (`pickup_latitude`/`pickup_longitude`) and the backend picks the stop to board at. The passenger can choose a stop instead. Without location permission, From must be a chosen stop.
- **To** is required.
- Stops are found by name (`GET /stops?q=`, 2 characters or more, after 300 ms without typing). Below the fields: favourite routes (a tap fills both fields), nearby stops, and the last 5 searches (kept on the phone).

## 20. Fare display

> **Ended 10 Oct 2026.** G20 landed in backend 0.13.0: every search result has `fare {current, solo, minimum, platform_fee, total, …}` for the passenger's pickup and drop-off. Mock and live now follow one rule:
> - The main price is `fare.current` (one seat, before the platform fee).
> - The solo fare is crossed out and "Save X%" shows, with X = (solo − current) / solo rounded to a whole percent, **only when solo is higher than current**. When they're equal (nobody to share with yet) neither shows; when the saving rounds to 0 %, only the crossed-out price shows.
> - A result without `fare` (an older backend) shows `fare_amount`.

What applied until then:

- **Live mode:** the backend's `fare_amount` is the main price. The crossed-out solo price and "Save X%" show only when the API provides a solo and a shared fare for the passenger's stretch (backend gap G20).
- **Mock mode:** the full design: ₵38 crossed out, ₵14, "Save 63%".

## 21. Approaching and passed vehicles

> **Ended 10 Oct 2026.** G21 landed in backend 0.13.0: trips already on the road are in the results, with `vehicle_eta_to_pickup_minutes` and `has_passed_pickup`. Mock and live now show the full design whenever a vehicle is on the road:
> - The banner shows when any result is approaching or has passed the stop.
> - A vehicle on the road gets "~N min away · approaching your stop". A trip that hasn't set off still gets "Board at <stop> · <distance> away" in that slot.
> - Passed vehicles are greyed "Passed" cards behind "Show N vehicles that already passed your stop". The backend sends them **last**, so that block now closes the list instead of following the approaching vehicles as in P6.

What applied until then:

The "Showing vehicles still approaching your stop" banner, the "~N min away · approaching your stop" badge, the "Passed" cards and the "Show N vehicles that already passed your stop" button appear **only when the API provides them** (backend gap G21).

In live mode the badge slot shows where the passenger boards, from the search result, in the same badge style: **"Board at Accra Madina · 350 m away"**. It is left out when the result has no pickup stop. Mock mode shows the full design.

## 22. Filter pills

| Pill | Does |
|---|---|
| **Now** (default) | Departures from now, today |
| **Schedule** | Pick a date and time; departures from then, that day |
| **Cheapest** | Sorts the loaded results by price |
| **Fastest** | Sorts the loaded results by arrival time (ETA), then departure |
| **Minibus** | Shows only minibuses (`vehicle_type`) |

Now and Schedule pick the time; Cheapest and Fastest pick the order (tap again for departure order); Minibus is an on/off filter. Several pills can be on at once.

**Since 10 Oct 2026 (backend 0.13.0) the backend sorts and filters**, across every page rather than the loaded ones: Cheapest sends `sort=cheapest` (lowest current fare), Fastest `sort=fastest`, Minibus `vehicle_type=minibus`. The backend's **fastest is the shortest scheduled ride**, not the earliest arrival as first written above. Vehicles that passed the stop always come last.

**"BEST MATCH"** is the first card after sorting that can still be booked (free seats, not passed).

## 23. Passenger names

The design has no passenger-details step (P-06 is skipped for now). A booking names one passenger per seat:

- **Seat 1:** the signed-in user's full name and phone number.
- **Every other seat:** "<first name>'s guest 2", "<first name>'s guest 3" and so on, with no phone number.
- **At most 10 seats** per booking, the backend's limit.

## 24. Price on the seat screen

> **Ended 10 Oct 2026.** The seat screen prices the choice with `GET /trips/{id}/fare-quote` for the passenger's stops and the number of seats (one when none is chosen), in mock and live mode alike:
> - "You pay now" (or "₵X × N seats") and the big price are `current` × seats, before the platform fee. The booking response's `fare_amount` is the same number; its total adds the fee.
> - The solo fare × seats is crossed out only when it's higher than `current`. "↓ Drops to ₵<minimum> / as more riders join" shows only when `minimum` is lower than `current`. No "Estimated" label.
> - The quote is fetched again with every 10 s seat refresh and whenever the number of seats changes (the backend shares the fare within a group too). The price flashes when it changes. While a new quote loads, the last one stays.
> - If the quote fails, the search result's `fare` is used, so the screen stays usable.

What applied until then:

- **Mock mode:** the full design. The fare drops as other riders book, the solo price is crossed out, and "↓ Drops to ₵6.00 / as more riders join" shows. The price flashes green when it changes (`.anim-price`).
- **Live mode, until backend gap G20:** the trip's fare × the seats chosen, with a small "Estimated" label where the "Drops to" badge would be. No crossed-out price and no "Drops to". The exact total, with the platform fee, comes from the booking response on the next screen.

## 25. Seat layout

The seat map is drawn from `GET /trips/{id}/seats` (`row_number`, `column_number`, `seat_type`), not from the design's fixed 14 seats. Each seat sits in its row and column; a missing seat leaves its place empty, so seats line up in columns.

The backend has no aisle field: a layout is just seats on a grid, and `seat_type` (`standard`, `vip`, `window`, `aisle`) is optional. The aisle is found in this order:

1. **A column with no seats in most rows** (such as column 3 in a 2 + 2 bus coded as 5 columns) is the aisle. A seat in it (the middle of a back bench) is drawn in the aisle's place.
2. Otherwise, **two neighbouring columns of `aisle` seats**: the aisle is between them.
3. Otherwise, by width: **4 columns → between 2 and 3** (as in the design); 3 columns → between 2 and 3 (2 + 1); 5 or more → after the middle column; 1–2 columns → no aisle.

**A shorter last row** (fewer seats than the rows before it, such as the design's 2-seat back bench) is centred under the others without an aisle, as P7 draws seats 13 and 14. A grid wider than the card shrinks to fit.

## 26. Admin web

Admin web = React app in TroSky/admin-dashboard (Maahir). Flutter admin_web removed.

- The dashboard has its own README, tests and CI (`.github/workflows/admin-dashboard.yml`).
- `apps/admin_web` was only a placeholder ("TroSky Admin — setup OK"); its planned screens A-01 to
  A-14 are gone from `frontend-inventory.md`.
- `apps/fleet_web` stays for now; the fleet-owner app is decided later.

## 27. Sign-up location

Since backend 0.21.0 a **passenger** signs up only with the phone's position, and it must be in
Ghana (`PASSENGER_SIGNUP_COUNTRIES`, default `GH`; `422 LOCATION_REQUIRED` without one,
`422 LOCATION_NOT_SERVED` outside). Drivers are approved by an admin and send no position.

On **Create account** (S-06), for a passenger only:

1. **Without location permission**, the Home location sheet explains why first ("Confirm you're in
   Ghana"); only "Allow location" opens the phone's own dialog.
2. **One position:** the phone's last fix if it has one (a country check needs no precision),
   otherwise a fresh fix for up to 10 s.
3. **It goes only into `POST /auth/register`** (`latitude`, `longitude`). It is never stored on
   the phone (not in Home's location state, not in preferences), and the backend only checks it.
4. **No position, no request.** Under the form:
   - refused, or the server says `LOCATION_REQUIRED`: "TroSky needs your location once to confirm
     you're in Ghana." with **Try again**;
   - refused for good: the same, with "allow it in Settings", **Try again** and **Open settings**;
   - location off: the same, with "turn on your phone's location";
   - no fix in 10 s: "couldn't find your location";
   - outside Ghana (`LOCATION_NOT_SERVED`): "TroSky is only available in Ghana for now."

The mock backend checks the same outline as the backend (Ghana plus about 15 km, so Lomé passes and
Lagos doesn't).

