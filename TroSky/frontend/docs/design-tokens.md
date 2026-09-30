# TroSky Design Tokens

**Source:** the Figma Make code in `design/figma-make/`: `globals.css` and `src/designs/{PassengerDesigns,DriverDesigns,AdminDesigns,Shared}.tsx`, extracted on 30 Sep 2026 by walking the TSX syntax tree, so every value below appears in that code.
**Dart:** `packages/trosky_ui/lib/src/tokens/`. Token names here match the Dart names.

This is the only source for visual values. The brand identity PDF is **superseded** wherever it differs (for example, its emerald `#00A86B` is replaced by `#0E9E6D`). The design is followed exactly: near-duplicate values are flagged below but all kept.

**Screen IDs:** Splash, P1–P16 (`PassengerDesigns.tsx`), D1–D9 (`DriverDesigns.tsx`), `A:<panel>` (`AdminDesigns.tsx`: Overview, Fleet, Analytics, Fraud, Demand, Login, Drivers, Reports; A:Shell is the sidebar and layout), plus the shared `Chip`, `BusPin` and `AcraMap` from `Shared.tsx`.

## Counts

| | Count |
|---|---|
| Distinct colour values | 149 (→ 157 colour tokens: 14 core, 40 extra solids, 96 translucent, 4 accent tints, plus role aliases) |
| Gradients | 22 |
| Text styles | 103 (88 UI styles + 15 from SVG illustration text) |
| Box shadows | 37 (plus 4 blur values) |
| Radii | 21 |
| Spacing values | 28 |

## Frame

- `PhoneFrame` in `Shared.tsx` draws a **320 × 694** phone with a 4 px bezel (`inset: 4`), so the screen the designs are drawn on is **312 × 686**. All sizes in the code are relative to a 312 px wide screen. The earlier note here said 390 × 844; that was wrong.
- A few elements were authored for a 390 px width and overflow the 312 px screen: the Home map overlay (`<svg width="390">`, P5), the Sign Up header wave (`viewBox="0 0 390 24"`, P4) and the `AcraMap` overlay (`viewBox="0 0 390 240"`, scaled with `slice`).
- How sizes map from 312 to real phones (360–430 px) is **not decided yet**: either scale everything by screen width ÷ 312, or use the values as-is and let layouts stretch. The tokens hold the raw Figma values either way.
- Device chrome is not tokenised: `StatusBar`, `HomeBar` and `PhoneFrame` mock the iPhone, and the real OS draws those. `StatusBar light` marks screens that need light status-bar icons.
- Light screens: Sign Up, Home and most inner screens. Dark screens inside the light app: Splash and Onboarding 1 (green), Onboarding 2–3 (navy), live tracking (P8), SOS (P15), QR scanner (D6).

## Fonts

| Role | Family | CSS | Loaded weights |
|---|---|---|---|
| Headings, buttons, prices | **Plus Jakarta Sans** | `var(--heading)` | 400–800 |
| Everything else (body, labels, inputs) | **Inter** | `var(--body)`, the `body` default | 300–700 |
| Codes and IDs (A:Fraud, A:Reports, D2, D6, P12) | CSS `monospace` | `fontFamily: 'monospace'` | platform font, not bundled |

- **Bundled** in `trosky_ui/assets/fonts/` as static TTFs, never fetched at runtime. The official Google Fonts repo now only ships variable fonts, so the static files come from the upstream repos Google Fonts builds from, at the same versions: Plus Jakarta Sans 2.7.1 (`tokotype/PlusJakartaSans` @ `18d1cd2`) and Inter 4.1 (`rsms/inter`). Each folder has its OFL licence; neither font has a Reserved Font Name.
- **Weights beyond the loaded fonts:** the SOS label asks for Plus Jakarta Sans **900** (P15) and one avatar initial asks for Inter **800** (A:Drivers). Browsers render the nearest loaded weight (800 and 700), so the tokens use those and note the original.
- **Line height:** `globals.css` pulls in Tailwind v4, whose preflight sets `line-height: 1.5` on everything. Text without an explicit `lineHeight` therefore uses 1.5, rendered with CSS-style even leading (`TextLeadingDistribution.even`).
- **Letter spacing:** `em` values are converted to logical pixels (em × font size).
- **Arial** appears only in the payment-brand logos drawn as SVG text in the wallet (P9: MTN, MoMo, Telecel, VISA). Those are logos, not type; they should become brand assets and are not tokenised.

## Colours

### Core palette (`globals.css`)
| Token | CSS | Value | Dart | Role | Screens |
|---|---|---|---|---|---|
| `green` | `--green` | `#0E9E6D` | `Color(0xFF0E9E6D)` | Primary brand green: primary buttons, active dots, links, available seats, map pins | Splash, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, AcraMap |
| `greenDark` | `--green-dk` | `#0B7E57` | `Color(0xFF0B7E57)` | Dark green: text on the white onboarding button, selected seat, green chip text, gradient dark ends | P1, P4, P6, P7, P12, P13, P14, D2, D6, D7, D9, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, Chip |
| `blue` | `--blue` | `#1F6FB2` | `Color(0xFF1F6FB2)` | Sky blue: "See all" links, promo and wallet gradient ends, info accents | P5, P8, P9, P12, D2, D4, D6, D7, D8, A:Analytics, A:Drivers, A:Fraud, A:Overview, A:Reports |
| `navy` | `--navy` | `#12263B` | `Color(0xFF12263B)` | Deep navy: headers, onboarding 2–3 backgrounds, logo pin | P2, P3, P5, P6, P7, P9, P10, P11, P12, P13, P16, D1, D2, D3, D4, D5, D6, D9, A:Demand, A:Fleet, A:Login, A:Shell |
| `ink` | `--ink` | `#1D2027` | `Color(0xFF1D2027)` | Ink: headings and text on amber | P1, P2, P3, P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports |
| `amber` | `--amber` | `#F4B333` | `Color(0xFFF4B333)` | Amber gold: onboarding-3 CTA, active page dot, "Try it", badges, "NEW FEATURE" label | P1, P2, P3, P5, P6, P7, P8, P9, P10, P11, P15, P16, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Overview, A:Reports |
| `red` | `--red` | `#E23D3D` | `Color(0xFFE23D3D)` | Error red: SOS button, errors, high-severity alerts | P5, P6, P7, P8, P11, P13, P15, D2, D8, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports, A:Shell |
| `success` | `--success` | `#16A34A` | `Color(0xFF16A34A)` | Success green (only used for one "₵" glyph in the wallet) | P9 |
| `textPrimary` | `--txt` | `#1D2027` | `Color(0xFF1D2027)` | Primary text (same value as ink) | P1, P2, P3, P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports |
| `textSecondary` | `--txt-2` | `#5B6472` | `Color(0xFF5B6472)` | Secondary text, labels, placeholder text, icons | P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, Chip |
| `border` | `--border` | `#E4E8EE` | `Color(0xFFE4E8EE)` | Input and card borders, dividers, inactive progress | P4, P5, P6, P7, P9, P10, P11, P14, P16, D1, D2, D3, D4, D5, D8, D9, A:Analytics, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, Chip |
| `surface` | `--surface` | `#FFFFFF` | `Color(0xFFFFFFFF)` | Cards, inputs, bottom sheets | Splash, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell, AcraMap, BusPin |
| `background` | `--bg` | `#F5F7FA` | `Color(0xFFF5F7FA)` | Screen background | P4, P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D8, D9, A:Demand, A:Drivers, A:Fraud, A:Login, A:Overview, A:Reports, A:Shell |
| `greenLight` | `--green-lt` | `rgba(14,158,109,0.12)` | `Color(0x1F0E9E6D)` | Tinted backgrounds (same value as greenA12) | D2, Chip |

### Role aliases
| Token | Value | Role |
|---|---|---|
| `white` | `#FFFFFF` | White text and icons on dark or coloured backgrounds (CSS `white`) |
| `seatTaken` | `#E4E8EE` | Taken seat body (P7); same value as border |
| `transparent` | `transparent` | CSS `transparent` (seat borders, tab backgrounds) |

### Solid colours found only in the screen code
| Token | Value | Role | Screens |
|---|---|---|---|
| `splashGreenDeep` | `#0A6E4C` | Splash gradient start | Splash |
| `splashGreenBright` | `#12B87E` | Splash gradient end | Splash |
| `onboardingGreenEnd` | `#0D8A61` | Onboarding 1 gradient end | P1 |
| `busWheel` | `#0A5E42` | Onboarding 1 illustration: bus wheels | P1 |
| `riderMint` | `#7DD3B8` | Onboarding 2 illustration: rider avatar | P2 |
| `riderSky` | `#89C4F0` | Onboarding 2 illustration: rider avatar | P2 |
| `riderLavender` | `#C3A6F4` | Onboarding 2 illustration: rider avatar | P2 |
| `navyHeaderEnd` | `#1A3A5C` | Navy header gradient end (Home, Driver home); Onboarding 2 gradient middle | P2, P5, D1 |
| `seatHeaderNavyEnd` | `#1A3358` | Seat selection header gradient end | P7 |
| `navySlate` | `#1F3A5A` | Profile header gradient end; wallet and earnings card middle stop | P9, P11, D4, D5 |
| `historyNavyEnd` | `#1D3A5B` | Trip history and withdrawal header gradient end | P13, D9 |
| `rateDriverNavyEnd` | `#1F3A5B` | Rate driver header gradient end | P16 |
| `navyDeep` | `#0D1F35` | Onboarding 2 gradient end, Onboarding 3 gradient start | P2, P3 |
| `onboarding3NavyEnd` | `#1A2840` | Onboarding 3 gradient end | P3 |
| `adminLoginNavyStart` | `#0D1A28` | Admin login background gradient start | A:Login |
| `adminLoginNavyEnd` | `#0A1820` | Admin login background gradient end | A:Login |
| `mapNight` | `#13181F` | Live tracking dark map background (P8) | P8 |
| `sosBackground` | `#0D1117` | SOS screen background (P15) | P15 |
| `scannerBackground` | `#0D1420` | QR scanner background (D6) | D6 |
| `mintSurface` | `#F0F7F4` | QR scanner result panel (D6) | D6 |
| `redDark` | `#C12B2B` | Red chip text, SOS gradient end, incident header gradient start | P15, D8, A:Drivers, A:Fleet, A:Fraud, A:Reports, Chip |
| `blueDark` | `#1557A0` | Blue chip text, favourite routes info text | P14, Chip |
| `goldText` | `#B8860B` | Amber chip text, "idle/flagged/medium" status text, mid ratings | P6, P7, P14, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Reports, Chip |
| `amberTextDeep` | `#7A5F00` | Incident report: passenger-count heading on amber | D8 |
| `amberTextMid` | `#A07A00` | Incident report: notice text on amber | D8 |
| `amberDeep` | `#E8920A` | Amber avatar gradient end | P16, D9 |
| `ratingOrange` | `#E2924A` | Admin rating chart: 2★ slice | A:Analytics |
| `textBody` | `#3D4552` | Admin detail labels (performance, documents) | A:Drivers, A:Reports |
| `textMuted` | `#A0AAB4` | Muted captions (QR scanner captions, search results) | P6, D6 |
| `chevron` | `#C0C8D2` | List chevrons; ticket reference code (P12) | P11, P12, D1 |
| `seatTakenHeadrest` | `#B0B8C2` | Taken seat headrest (P7) | P7 |
| `seatTakenCushion` | `#C4CDD6` | Taken seat cushion (P7) | P7 |
| `seatLegendTaken` | `#D0D7DF` | Seat legend "Taken" swatch (P7) | P7 |
| `qrFrame` | `#E8EAF0` | QR card border and placeholder (P12) | P12 |
| `dividerSubtle` | `#F0F2F5` | Admin list dividers | A:Drivers, A:Reports |
| `skyLink` | `#7ABDE8` | "Share Trip Link" text on the dark SOS screen | P15 |
| `black` | `#000000` | MoMo logo text and fill (P9) | P9 |
| `mtnYellow` | `#FFCC00` | MTN MoMo brand yellow (P9 logo, D9 payout option) | P9, D9 |
| `telecelRed` | `#E8001C` | Telecel brand red (P9 logo) | P9 |
| `visaNavy` | `#1A1F71` | VISA brand navy (P9 logo) | P9 |

### Translucent colours
Named base colour + alpha in hundredths (`whiteA06` = `rgba(255,255,255,0.06)`). `midnight` is `#121A26` and `slate` is `#5A6472`; neither appears as a solid colour.

| Token | CSS | Dart | Used as | Screens |
|---|---|---|---|---|
| `amberA04` | `rgba(244,179,51,0.04)` | `Color(0x0AF4B333)` | background | P2 |
| `amberA06` | `rgba(244,179,51,0.06)` | `Color(0x0FF4B333)` | array | A:Fraud |
| `amberA10` | `rgba(244,179,51,0.1)` | `Color(0x1AF4B333)` | background | P10, D3, D8, A:Demand |
| `amberA12` | `rgba(244,179,51,0.12)` | `Color(0x1FF4B333)` | idle, bg, flagged, medium | P11, P14, A:Drivers, A:Fleet, A:Fraud, A:Reports |
| `amberA15` | `rgba(244,179,51,0.15)` | `Color(0x26F4B333)` | background, amber, bg | P6, P7, Chip |
| `amberA20` | `rgba(244,179,51,0.2)` | `Color(0x33F4B333)` | background | P11 |
| `amberA25` | `rgba(244,179,51,0.25)` | `Color(0x40F4B333)` | border | P10 |
| `amberA30` | `rgba(244,179,51,0.3)` | `Color(0x4DF4B333)` | border | D8 |
| `amberA35` | `rgba(244,179,51,0.35)` | `Color(0x59F4B333)` | boxShadow | P3, D9 |
| `amberA50` | `rgba(244,179,51,0.5)` | `Color(0x80F4B333)` | filter | BusPin |
| `blackA04` | `rgba(0,0,0,0.04)` | `Color(0x0A000000)` | boxShadow | P4 |
| `blackA05` | `rgba(0,0,0,0.05)` | `Color(0x0D000000)` | boxShadow | P9, P10, P11, D1, D2, D4, D5, A:Drivers, A:Reports |
| `blackA06` | `rgba(0,0,0,0.06)` | `Color(0x0F000000)` | boxShadow | P6, P7, P14, D3, A:Analytics, A:Demand, A:Fleet, A:Fraud, A:Overview |
| `blackA08` | `rgba(0,0,0,0.08)` | `Color(0x14000000)` | boxShadow, background | Splash, P1, P5, P7, P16, D2, D7 |
| `blackA10` | `rgba(0,0,0,0.1)` | `Color(0x1A000000)` | boxShadow | P12 |
| `blackA12` | `rgba(0,0,0,0.12)` | `Color(0x1F000000)` | boxShadow | A:Analytics |
| `blackA15` | `rgba(0,0,0,0.15)` | `Color(0x26000000)` | boxShadow | P5 |
| `blackA20` | `rgba(0,0,0,0.2)` | `Color(0x33000000)` | boxShadow | P1, P5 |
| `blackA25` | `rgba(0,0,0,0.25)` | `Color(0x40000000)` | boxShadow | Splash |
| `blackA30` | `rgba(0,0,0,0.3)` | `Color(0x4D000000)` | boxShadow | D2 |
| `blackA40` | `rgba(0,0,0,0.4)` | `Color(0x66000000)` | boxShadow | A:Login |
| `blackA55` | `rgba(0,0,0,0.55)` | `Color(0x8C000000)` | svg fill | A:Demand, A:Fleet, A:Overview |
| `blueA06` | `rgba(31,111,178,0.06)` | `Color(0x0F1F6FB2)` | background | D2 |
| `blueA08` | `rgba(31,111,178,0.08)` | `Color(0x141F6FB2)` | background, boxShadow | P14, D1, A:Reports |
| `blueA10` | `rgba(31,111,178,0.1)` | `Color(0x1A1F6FB2)` | background | P9, D1, A:Drivers |
| `blueA12` | `rgba(31,111,178,0.12)` | `Color(0x1F1F6FB2)` | blue, bg | Chip |
| `blueA20` | `rgba(31,111,178,0.2)` | `Color(0x331F6FB2)` | border, background | P15, D2 |
| `blueA25` | `rgba(31,111,178,0.25)` | `Color(0x401F6FB2)` | border | D1 |
| `blueA30` | `rgba(31,111,178,0.3)` | `Color(0x4D1F6FB2)` | border | P15 |
| `greenA00` | `rgba(14,158,109,0)` | `Color(0x000E9E6D)` | svg stopOpacity | A:Analytics |
| `greenA04` | `rgba(14,158,109,0.04)` | `Color(0x0A0E9E6D)` | background | P10, A:Drivers |
| `greenA06` | `rgba(14,158,109,0.06)` | `Color(0x0F0E9E6D)` | array, background | P7, A:Fraud |
| `greenA07` | `rgba(14,158,109,0.07)` | `Color(0x120E9E6D)` | background | P4, D1, D2 |
| `greenA08` | `rgba(14,158,109,0.08)` | `Color(0x140E9E6D)` | background | P6, P13, D3, D4, D9, A:Reports |
| `greenA10` | `rgba(14,158,109,0.1)` | `Color(0x1A0E9E6D)` | moving, bg, active, low | P6, P9, P10, P12, P14, D1, D3, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports |
| `greenA12` | `rgba(14,158,109,0.12)` | `Color(0x1F0E9E6D)` | boxShadow, green, bg | D2, Chip |
| `greenA15` | `rgba(14,158,109,0.15)` | `Color(0x260E9E6D)` | border, borderBottom, background | P4, P6, P15, D6 |
| `greenA18` | `rgba(14,158,109,0.18)` | `Color(0x2E0E9E6D)` | border | D2 |
| `greenA20` | `rgba(14,158,109,0.2)` | `Color(0x330E9E6D)` | background, border | D1, D6 |
| `greenA25` | `rgba(14,158,109,0.25)` | `Color(0x400E9E6D)` | border | D1, D3, D6 |
| `greenA30` | `rgba(14,158,109,0.3)` | `Color(0x4D0E9E6D)` | boxShadow, background, border | P6, P13, D3, D4, D6 |
| `greenA35` | `rgba(14,158,109,0.35)` | `Color(0x590E9E6D)` | boxShadow, border | P4, P7, P10, D2, D6, A:Login |
| `greenA40` | `rgba(14,158,109,0.4)` | `Color(0x660E9E6D)` | border, boxShadow | P2, D1 |
| `greenA50` | `rgba(14,158,109,0.5)` | `Color(0x800E9E6D)` | filter | BusPin |
| `greenA60` | `rgba(14,158,109,0.6)` | `Color(0x990E9E6D)` | background | A:Demand |
| `greenA85` | `rgba(14,158,109,0.85)` | `Color(0xD90E9E6D)` | svg fill | P8 |
| `greenDarkA40` | `rgba(11,126,87,0.4)` | `Color(0x660B7E57)` | boxShadow | P7 |
| `midnightA82` | `rgba(18,26,38,0.82)` | `Color(0xD1121A26)` | background | D1 |
| `midnightA90` | `rgba(18,26,38,0.9)` | `Color(0xE6121A26)` | background | D3 |
| `midnightA97` | `rgba(18,26,38,0.97)` | `Color(0xF7121A26)` | background | P8 |
| `navyA08` | `rgba(18,38,59,0.08)` | `Color(0x1412263B)` | background | P10 |
| `navyA30` | `rgba(18,38,59,0.3)` | `Color(0x4D12263B)` | boxShadow | D4 |
| `navyA35` | `rgba(18,38,59,0.35)` | `Color(0x5912263B)` | boxShadow | P9 |
| `navyA60` | `rgba(18,38,59,0.6)` | `Color(0x9912263B)` | color | D9 |
| `navyA70` | `rgba(18,38,59,0.7)` | `Color(0xB312263B)` | color | D9 |
| `navyA92` | `rgba(18,38,59,0.92)` | `Color(0xEB12263B)` | background | P8 |
| `navyA95` | `rgba(18,38,59,0.95)` | `Color(0xF212263B)` | background | P9 |
| `redA06` | `rgba(226,61,61,0.06)` | `Color(0x0FE23D3D)` | array, background | P11, A:Fraud |
| `redA07` | `rgba(226,61,61,0.07)` | `Color(0x12E23D3D)` | background | P6 |
| `redA08` | `rgba(226,61,61,0.08)` | `Color(0x14E23D3D)` | background | P13, D2, A:Drivers |
| `redA10` | `rgba(226,61,61,0.1)` | `Color(0x1AE23D3D)` | suspended, bg, high, open | A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Reports |
| `redA12` | `rgba(226,61,61,0.12)` | `Color(0x1FE23D3D)` | borderBottom, red, bg | P6, Chip |
| `redA15` | `rgba(226,61,61,0.15)` | `Color(0x26E23D3D)` | border | P11 |
| `redA20` | `rgba(226,61,61,0.2)` | `Color(0x33E23D3D)` | border | P15 |
| `redA25` | `rgba(226,61,61,0.25)` | `Color(0x40E23D3D)` | border | D2 |
| `redA35` | `rgba(226,61,61,0.35)` | `Color(0x59E23D3D)` | border | P15 |
| `redA40` | `rgba(226,61,61,0.4)` | `Color(0x66E23D3D)` | boxShadow | D1 |
| `redA45` | `rgba(226,61,61,0.45)` | `Color(0x73E23D3D)` | boxShadow | P8 |
| `redA50` | `rgba(226,61,61,0.5)` | `Color(0x80E23D3D)` | boxShadow | P5, P15 |
| `redA90` | `rgba(226,61,61,0.9)` | `Color(0xE6E23D3D)` | background | D1 |
| `slateA85` | `rgba(90,100,114,0.85)` | `Color(0xD95A6472)` | background | D1 |
| `whiteA04` | `rgba(255,255,255,0.04)` | `Color(0x0AFFFFFF)` | border | P9 |
| `whiteA05` | `rgba(255,255,255,0.05)` | `Color(0x0DFFFFFF)` | border | P2 |
| `whiteA06` | `rgba(255,255,255,0.06)` | `Color(0x0FFFFFFF)` | borderBottom, border, borderTop, background | Splash, P1, P8, P9, P15, D3, D4, D6, A:Shell |
| `whiteA07` | `rgba(255,255,255,0.07)` | `Color(0x12FFFFFF)` | background, borderBottom | Splash, P8 |
| `whiteA08` | `rgba(255,255,255,0.08)` | `Color(0x14FFFFFF)` | background, svg stroke, svg fill, border | Splash, P1, P2, P3, P6, P8, P9, P15, D1, D6 |
| `whiteA10` | `rgba(255,255,255,0.1)` | `Color(0x1AFFFFFF)` | background, border, svg stroke, svg fill | Splash, P2, P3, P5, P6, P7, P15, D1, A:Shell |
| `whiteA12` | `rgba(255,255,255,0.12)` | `Color(0x1FFFFFFF)` | background, border, svg fill, svg stroke | P1, P2, P3, P5, P6, P11, P12, P13, P15, D5, D6 |
| `whiteA15` | `rgba(255,255,255,0.15)` | `Color(0x26FFFFFF)` | background, svg stroke | P1, P8, D2 |
| `whiteA20` | `rgba(255,255,255,0.2)` | `Color(0x33FFFFFF)` | border, svg fill, background | P2, P8, P11, P14, D5 |
| `whiteA25` | `rgba(255,255,255,0.25)` | `Color(0x40FFFFFF)` | background | P2, P3, P7 |
| `whiteA30` | `rgba(255,255,255,0.3)` | `Color(0x4DFFFFFF)` | svg fill, background, border | P1, P3, P5 |
| `whiteA35` | `rgba(255,255,255,0.35)` | `Color(0x59FFFFFF)` | color, background | Splash, P7, D6, A:Shell |
| `whiteA40` | `rgba(255,255,255,0.4)` | `Color(0x66FFFFFF)` | color, svg fill | P2, P3, P9, P15, D4, D6 |
| `whiteA45` | `rgba(255,255,255,0.45)` | `Color(0x73FFFFFF)` | color | P8, D6, A:Login |
| `whiteA50` | `rgba(255,255,255,0.5)` | `Color(0x80FFFFFF)` | color, svg stroke | P2, P6, P8, P9, P10, P15, D1, D3, D4, D5, D6, A:Shell |
| `whiteA55` | `rgba(255,255,255,0.55)` | `Color(0x8CFFFFFF)` | color | Splash, P2, P3, P5, P7, P11 |
| `whiteA60` | `rgba(255,255,255,0.6)` | `Color(0x99FFFFFF)` | color, array, svg fill | P2, P5, P6, P12, P16, D2, D6, D9 |
| `whiteA65` | `rgba(255,255,255,0.65)` | `Color(0xA6FFFFFF)` | color | P1, P2, P3 |
| `whiteA70` | `rgba(255,255,255,0.7)` | `Color(0xB3FFFFFF)` | color, svg fill | P2, P4, P7, P15, D2, D7 |
| `whiteA72` | `rgba(255,255,255,0.72)` | `Color(0xB8FFFFFF)` | color | P1 |
| `whiteA75` | `rgba(255,255,255,0.75)` | `Color(0xBFFFFFFF)` | color | P14, D8 |
| `whiteA80` | `rgba(255,255,255,0.8)` | `Color(0xCCFFFFFF)` | color, svg fill | P9, D6 |
| `whiteA85` | `rgba(255,255,255,0.85)` | `Color(0xD9FFFFFF)` | color, svg fill | Splash, P1, P6, D1 |
| `whiteA90` | `rgba(255,255,255,0.9)` | `Color(0xE6FFFFFF)` | color | P5 |
| `whiteA95` | `rgba(255,255,255,0.95)` | `Color(0xF2FFFFFF)` | background | P1 |

### Accent + hex alpha 18
The code builds some tints at runtime with `${color}18`, which appends hex alpha `18` (≈ 9.4 %).

| Token | Dart | Role |
|---|---|---|
| `greenTint18` | `Color(0x180E9E6D)` | Icon tiles and selected options tinted with the accent colour + hex alpha 18 (admin KPIs and stat cards, incident type) |
| `blueTint18` | `Color(0x181F6FB2)` | Same pattern, blue accent |
| `amberTint18` | `Color(0x18F4B333)` | Same pattern, amber accent |
| `redTint18` | `Color(0x18E23D3D)` | Same pattern, red accent |

### Near-duplicates (kept, flagged)
Solid colours within an RGB distance of 10:
- `#1F3A5A` (navySlate) vs `#1F3A5B` (rateDriverNavyEnd), distance 1.0
- `#1D3A5B` (historyNavyEnd) vs `#1F3A5B` (rateDriverNavyEnd), distance 2.0
- `#1F3A5A` (navySlate) vs `#1D3A5B` (historyNavyEnd), distance 2.2
- `#1A3A5C` (navyHeaderEnd) vs `#1D3A5B` (historyNavyEnd), distance 3.2
- `#E4E8EE` (border) vs `#E8EAF0` (qrFrame), distance 4.9
- `#0A1820` (adminLoginNavyEnd) vs `#0D1420` (scannerBackground), distance 5.0
- `#1A3A5C` (navyHeaderEnd) vs `#1F3A5B` (rateDriverNavyEnd), distance 5.1
- `#F0F7F4` (mintSurface) vs `#F0F2F5` (dividerSubtle), distance 5.1
- `#1A3A5C` (navyHeaderEnd) vs `#1F3A5A` (navySlate), distance 5.4
- `#13181F` (mapNight) vs `#0D1420` (scannerBackground), distance 7.3
- `#C0C8D2` (chevron) vs `#C4CDD6` (seatTakenCushion), distance 7.5
- `#F5F7FA` (background) vs `#F0F7F4` (mintSurface), distance 7.8
- `#1A3A5C` (navyHeaderEnd) vs `#1A3358` (seatHeaderNavyEnd), distance 8.1
- `#1A3358` (seatHeaderNavyEnd) vs `#1D3A5B` (historyNavyEnd), distance 8.2
- `#F5F7FA` (background) vs `#F0F2F5` (dividerSubtle), distance 8.7
- `#0D1A28` (adminLoginNavyStart) vs `#0A1820` (adminLoginNavyEnd), distance 8.8
- `#1A3358` (seatHeaderNavyEnd) vs `#1F3A5A` (navySlate), distance 8.8
- `#0A1820` (adminLoginNavyEnd) vs `#13181F` (mapNight), distance 9.1
- `#1A3358` (seatHeaderNavyEnd) vs `#1F3A5B` (rateDriverNavyEnd), distance 9.1
- `#0D1117` (sosBackground) vs `#0D1420` (scannerBackground), distance 9.5
- `#12263B` (navy) vs `#1A2840` (onboarding3NavyEnd), distance 9.6
- `#0D1A28` (adminLoginNavyStart) vs `#0D1420` (scannerBackground), distance 10.0

Also:
- The seat legend's "Taken" swatch is `#D0D7DF` (seatLegendTaken), but taken seats themselves are `#E4E8EE` (seatTaken).
- `#5A6472` (slate, D1 "Go Offline" disabled) is one step from textSecondary `#5B6472`.
- `ink` and `textPrimary` are both `#1D2027`; `surface` and `white` are both `#FFFFFF`; `greenLight` and `greenA12` are the same value.

Runs of translucent values on the same base that sit within 0.02 alpha of each other:
- amber: 0.04 / 0.06
- amber: 0.1 / 0.12
- black: 0.04 / 0.05 / 0.06 / 0.08 / 0.1 / 0.12
- blue: 0.06 / 0.08 / 0.1 / 0.12
- green: 0.04 / 0.06 / 0.07 / 0.08 / 0.1 / 0.12
- green: 0.18 / 0.2
- red: 0.06 / 0.07 / 0.08 / 0.1 / 0.12
- white: 0.04 / 0.05 / 0.06 / 0.07 / 0.08 / 0.1 / 0.12
- white: 0.7 / 0.72

## Gradients
All gradients are CSS `linear-gradient`s converted with `cssLinearGradient`, which keeps the CSS angle for any box size (0deg = to top, 90deg = to right, 160deg = mostly down, slightly right).

| Token | CSS | Used on |
|---|---|---|
| `splash` | `linear-gradient(160deg, #0A6E4C 0%, #0E9E6D 50%, #12B87E 100%)` | Splash background |
| `onboarding1` | `linear-gradient(160deg, #0B7E57 0%, #0E9E6D 45%, #0d8a61 100%)` | Onboarding 1 background |
| `onboarding2` | `linear-gradient(160deg, #12263B 0%, #1a3a5c 50%, #0d1f35 100%)` | Onboarding 2 background |
| `onboarding3` | `linear-gradient(160deg, #0d1f35 0%, #12263B 40%, #1a2840 100%)` | Onboarding 3 background |
| `greenHeader` | `linear-gradient(160deg, #0B7E57 0%, #0E9E6D 100%) · same as linear-gradient(160deg,#0B7E57,#0E9E6D)` | Sign up header (P4); receipt (D7) and favourite routes (P14) headers |
| `navyHeader` | `linear-gradient(180deg, var(--navy) 0%, #1a3a5c 100%)` | Home header (P5), driver home header (D1) |
| `seatSelectionHeader` | `linear-gradient(180deg, var(--navy) 0%, #1a3358 100%)` | Seat selection header (P7) |
| `profileHeader` | `linear-gradient(160deg, var(--navy) 0%, #1F3A5A 100%)` | Profile headers (P11, D5) |
| `historyHeader` | `linear-gradient(160deg,#12263B,#1D3A5B)` | Trip history (P13) and withdrawal (D9) headers |
| `rateDriverHeader` | `linear-gradient(160deg,#12263B,#1F3A5B)` | Rate driver header (P16) |
| `qrBoardingHeader` | `linear-gradient(160deg,#12263B 0%,#1F6FB2 100%)` | QR boarding header (P12) |
| `walletCard` | `linear-gradient(135deg, #12263B 0%, #1F3A5A 60%, #1F6FB2 100%)` | Wallet balance card (P9), earnings card (D4) |
| `promoCard` | `linear-gradient(120deg, var(--navy) 0%, #1F6FB2 100%)` | Home promo card "Subscribe your commute" (P5) |
| `avatar` | `linear-gradient(135deg,#0E9E6D,#1F6FB2)` | Initial avatars (admin drivers, D2, D6, D7, P12) |
| `amberAvatar` | `linear-gradient(135deg,#F4B333,#E8920A)` | Amber initial avatars (D9, P16) |
| `spendingSummary` | `linear-gradient(135deg,#0E9E6D,#0B7E57)` | Trip history spending summary card (P13) |
| `sos` | `linear-gradient(135deg,#E23D3D,#C12B2B)` | SOS hold button (P15) |
| `incidentHeader` | `linear-gradient(160deg,#C12B2B,#E23D3D)` | Incident report header (D8) |
| `rideAcceptedHeader` | `linear-gradient(180deg, #0B7E57 0%, var(--green) 100%)` | Ride accepted header (D2) |
| `demandLegend` | `linear-gradient(to right, rgba(14,158,109,0.6), #F4B333, #E23D3D)` | Demand map legend bar (admin) |
| `adminLogin` | `linear-gradient(160deg, #0d1a28 0%, #12263B 50%, #0a1820 100%)` | Admin login background |
| `revenueArea` | `<linearGradient x2="0" y2="1">: #0E9E6D @ 0.2 opacity at 5% → 0 at 95%` | Admin revenue chart area fill (SVG `<linearGradient>`, x1=0 y1=0 x2=0 y2=1) |

**Near-duplicates:** navyHeader vs seatSelectionHeader (`#1a3a5c` vs `#1a3358` end); profileHeader vs historyHeader vs rateDriverHeader (`#1F3A5A` / `#1D3A5B` / `#1F3A5B` end); greenHeader (160deg) vs rideAcceptedHeader (180deg), same colours; spendingSummary (135deg green → greenDark) vs greenHeader (160deg greenDark → green); sos (135deg red → redDark) vs incidentHeader (160deg redDark → red).

## Typography
Names read family, size, weight, then modifiers: `H120` = line-height 1.2, `Ls4` = letter-spacing 0.04em, `LsNeg0p3px` = -0.3px. No `H` means line-height 1.5. `svg*` styles come from SVG `<text>` in illustrations and have no line height. Colours are applied where a style is used.

| Token | Family | Size | Weight | Line height | Letter spacing | Screens | Example |
|---|---|---|---|---|---|---|---|
| `body32Regular` | Inter | 32 | 400 | 1.5 |  | P11 | 👨🏿‍💼 |
| `body30Regular` | Inter | 30 | 400 | 1.5 |  | D5 | 👩🏿‍💼 |
| `body28Regular` | Inter | 28 | 400 | 1.5 |  | A:Fraud |  |
| `body24Regular` | Inter | 24 | 400 | 1.5 |  | P8, P10, P11, D8 | 📷 |
| `body22Regular` | Inter | 22 | 400 | 1.5 |  | D1 | 📍 |
| `body20Regular` | Inter | 20 | 400 | 1.5 |  | D1, A:Overview, A:Reports | 📲 |
| `body20ExtraBold` | Inter | 20 | 800 → 700 | 1.5 |  | A:Drivers |  |
| `body18Regular` | Inter | 18 | 400 | 1.5 |  | P4, D1, D5, D8 | 📄 |
| `body17Regular` | Inter | 17 | 400 | 1.5 |  | P11, A:Shell |  |
| `body16Regular` | Inter | 16 | 400 | 1.5 |  | P4, P5, P8, P9, P14, D2, D4, A:Fraud, A:Reports, A:Shell | 👤 |
| `body14Regular` | Inter | 14 | 400 | 1.5 |  | P4, P5, P7, P10, P15, D2, D3, A:Login | 👤 |
| `body14RegularH160` | Inter | 14 | 400 | 1.6 |  | P1, P2, P3 | Find a shared vehicle going your w |
| `body14Medium` | Inter | 14 | 500 | 1.5 |  | P4 | Continue with Email |
| `body14SemiBold` | Inter | 14 | 600 | 1.5 |  | P4, P8, P11, P15 | +233 |
| `body14Bold` | Inter | 14 | 700 | 1.5 |  | P9, P12, D2 | Decline |
| `body13Regular` | Inter | 13 | 400 | 1.5 |  | Splash, P4, P6, P7, P11, P12, P14, P15, P16, D5, D7, D8, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports | Thursday, 31 Jul 2026 · Refreshed  |
| `body13Medium` | Inter | 13 | 500 | 1.5 |  | P1, P2, P3, P9, P10, D4, A:Analytics, A:Fraud, A:Overview, A:Shell | Skip |
| `body13SemiBold` | Inter | 13 | 600 | 1.5 |  | P8, P9, P13, P15, D1, D5, D6, D7, D8, D9, A:Fleet, A:Fraud, A:Overview, A:Shell | Export CSV |
| `body13Bold` | Inter | 13 | 700 | 1.5 |  | P16, D3, D4, D6, D7, A:Drivers, A:Fleet, A:Fraud, A:Reports | ⭐ |
| `body12Regular` | Inter | 12 | 400 | 1.5 |  | P4, P5, P6, P7, P8, P9, P10, P11, P12, P13, P14, P15, P16, D2, D4, D5, D7, D8, D9, A:Analytics, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports | 184 vehicles online |
| `body12RegularLs5` | Inter | 12 | 400 | 1.5 | 0.05em | P9 | TROSKY WALLET |
| `body12MediumH140` | Inter | 12 | 500 | 1.4 |  | D2 | No new ride requests while a trip  |
| `body12Medium` | Inter | 12 | 500 | 1.5 |  | P5, P6, D2, A:Fraud | Dismiss |
| `body12SemiBoldH133` | Inter | 12 | 600 | 1.3333 |  | Chip | Chip label |
| `body12SemiBoldH140` | Inter | 12 | 600 | 1.4 |  | D3 |  |
| `body12SemiBold` | Inter | 12 | 600 | 1.5 |  | P5, P6, P9, P13, P14, P16, D1, D3, D6, D8, D9, A:Demand, A:Drivers, A:Fraud, A:Overview, A:Reports | Review |
| `body12SemiBoldLs4` | Inter | 12 | 600 | 1.5 | 0.04em | P4, A:Login | PHONE NUMBER |
| `body12Bold` | Inter | 12 | 700 | 1.5 |  | P5, P10, P11, P12, D3, D5, D7, A:Demand, A:Drivers | % |
| `body11Regular` | Inter | 11 | 400 | 1.5 |  | P5, P6, P7, P9, P10, P11, P12, P13, P14, P15, D1, D2, D3, D4, D5, D6, D7, D8, D9, A:Analytics, A:Demand, A:Overview, A:Reports, A:Shell | Low → High demand |
| `body11Medium` | Inter | 11 | 500 | 1.5 |  | P5, P7, A:Drivers | Madina, Accra |
| `body11SemiBold` | Inter | 11 | 600 | 1.5 |  | P6, P10, P14, P15, D2, D4, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports | ↑ |
| `body11SemiBoldLs4` | Inter | 11 | 600 | 1.5 | 0.04em | D6, A:Fleet, A:Fraud, A:Overview | SHOW THIS TO BOARDING PASSENGERS |
| `body11BoldLs4` | Inter | 11 | 700 | 1.5 | 0.04em | A:Drivers, A:Reports |  |
| `body11BoldLs5` | Inter | 11 | 700 | 1.5 | 0.05em | P10, D7, D8, D9, A:Drivers | PERFORMANCE |
| `body11Bold` | Inter | 11 | 700 | 1.5 |  | P6, P7, P10, P12, D2 | Save |
| `body11BoldLs6` | Inter | 11 | 700 | 1.5 | 0.06em | P15 | TRUSTED CONTACTS NOTIFIED |
| `body10RegularH140` | Inter | 10 | 400 | 1.4 |  | D3 | Seat · → |
| `body10Regular` | Inter | 10 | 400 | 1.5 |  | P6, P7, P8, P10, P12, P13, P14, P16, D1, D6, D7, D8, D9, A:Analytics, A:Drivers, A:Overview | GR- |
| `body10RegularLs6` | Inter | 10 | 400 | 1.5 | 0.06em | A:Shell | ADMIN CONSOLE |
| `body10Medium` | Inter | 10 | 500 | 1.5 |  | D1, D4 |  |
| `body10SemiBold` | Inter | 10 | 600 | 1.5 |  | P6, P7, D1, D2 | Drop off passengers first |
| `body10Bold` | Inter | 10 | 700 | 1.5 |  | P6, P7, P11, P13, D1, A:Reports, A:Shell | Drop Off |
| `body10BoldLs7` | Inter | 10 | 700 | 1.5 | 0.07em | D6 | RECENTLY BOARDED |
| `body10BoldLs6` | Inter | 10 | 700 | 1.5 | 0.06em | P5 | NEW FEATURE |
| `body10BoldLs5` | Inter | 10 | 700 | 1.5 | 0.05em | P11 |  |
| `body9Regular` | Inter | 9 | 400 | 1.5 |  | D2, D6 | BOARDED |
| `body9RegularLs5` | Inter | 9 | 400 | 1.5 | 0.05em | P15 | HOLD 3 SEC |
| `body9Bold` | Inter | 9 | 700 | 1.5 |  | P10 | BEST VALUE |
| `heading42ExtraBoldH100` | Jakarta | 42 | 800 | 1 |  | D5 | 4.9 |
| `heading38ExtraBoldH100` | Jakarta | 38 | 800 | 1 |  | P9, D4 | ₵1,414.00 |
| `heading38ExtraBold` | Jakarta | 38 | 800 | 1.5 |  | D9 | ₵1,414.50 |
| `heading34ExtraBold` | Jakarta | 34 | 800 | 1.5 |  | D7 | ₵48.00 |
| `heading32ExtraBold` | Jakarta | 32 | 800 | 1.5 |  | P13 | ₵128.50 |
| `heading30ExtraBoldH100` | Jakarta | 30 | 800 | 1 |  | P7 | ₵ |
| `heading28ExtraBoldH100` | Jakarta | 28 | 800 | 1 |  | A:Fraud, A:Overview |  |
| `heading28ExtraBold` | Jakarta | 28 | 800 | 1.5 |  | P16 | K |
| `heading26ExtraBoldH100` | Jakarta | 26 | 800 | 1 |  | A:Reports |  |
| `heading26ExtraBoldH120` | Jakarta | 26 | 800 | 1.2 |  | P1, P2, P3 | Book a Seat, Not a Whole Car |
| `heading26ExtraBold` | Jakarta | 26 | 800 | 1.5 |  | A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports | Overview |
| `heading24ExtraBoldH120` | Jakarta | 24 | 800 | 1.2 |  | P4 | Welcome to TroSky |
| `heading24ExtraBold` | Jakarta | 24 | 800 | 1.5 |  | D2, D9 | ₵28.50 |
| `heading22ExtraBoldH100` | Jakarta | 22 | 800 | 1 |  | P6, D2 | ₵ |
| `heading22ExtraBold` | Jakarta | 22 | 800 | 1.5 |  | P9, P10, P15, D4, A:Login | Admin Console |
| `heading22BlackLs5` | Jakarta | 22 | 900 → 800 | 1.5 | 0.05em | P15 | SOS |
| `heading20Bold` | Jakarta | 20 | 700 | 1.5 |  | P5, D1 | Akosua Boateng |
| `heading20ExtraBoldH100` | Jakarta | 20 | 800 | 1 |  | D6 | / |
| `heading20ExtraBold` | Jakarta | 20 | 800 | 1.5 |  | P10, P11, P13, P14, D2, D7, D8, D9 | Payment Receipts |
| `heading19ExtraBold` | Jakarta | 19 | 800 | 1.5 |  | P16, D2, D5 | Show QR to Passengers |
| `heading18Bold` | Jakarta | 18 | 700 | 1.5 |  | D2 | Incoming Request |
| `heading18ExtraBoldLsNeg0p3px` | Jakarta | 18 | 800 | 1.5 | -0.3px | A:Login | TroSky |
| `heading18ExtraBold` | Jakarta | 18 | 800 | 1.5 |  | D2, D6 | Madina → Circle |
| `heading17SemiBoldLs1` | Jakarta | 17 | 600 | 1.5 | 0.01em | Splash | Your Journey. On Time. |
| `heading17Bold` | Jakarta | 17 | 700 | 1.5 |  | P7, P16, D3 | Active Route |
| `heading17ExtraBold` | Jakarta | 17 | 800 | 1.5 |  | P12 | Madina → Circle |
| `heading16Bold` | Jakarta | 16 | 700 | 1.5 |  | P1, P2, P3, P6, P8, P13, A:Drivers | Next |
| `heading16ExtraBold` | Jakarta | 16 | 800 | 1.5 |  | P7, P12, D1 | K |
| `heading15Bold` | Jakarta | 15 | 700 | 1.5 |  | P4, P5, P8, P10, P14, P16, D7, D8, D9, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Login, A:Overview, A:Reports | Live Fleet Map |
| `heading14Bold` | Jakarta | 14 | 700 | 1.5 |  | P6, P7, P10, P11, P12, P13, P14, D1, D2, D4, D7, D9, A:Analytics | Revenue Over Time |
| `heading14ExtraBoldH100` | Jakarta | 14 | 800 | 1 |  | A:Shell | TroSky |
| `heading14ExtraBold` | Jakarta | 14 | 800 | 1.5 |  | D9 | M |
| `heading13SemiBold` | Jakarta | 13 | 600 | 1.5 |  | D2 | Passengers boarding |
| `heading13Bold` | Jakarta | 13 | 700 | 1.5 |  | P5, P8, P9, P16, D1, D2, D3, D5, D6, D9 | QR Boarding Active |
| `heading12ExtraBold` | Jakarta | 12 | 800 | 1.5 |  | P15, A:Demand | TroSky |
| `heading11Bold` | Jakarta | 11 | 700 | 1.5 |  | P7 |  |
| `heading10ExtraBold` | Jakarta | 10 | 800 | 1.5 |  | P5 | SOS |
| `mono12BoldLs10` | mono | 12 | 700 | 1.5 | 0.1em | D6 | TSKY-2026-8431 |
| `mono11Regular` | mono | 11 | 400 | 1.5 |  | P12, A:Fraud, A:Reports | TRO-2024-MDN-CCL-004 |
| `mono11BoldLs5` | mono | 11 | 700 | 1.5 | 0.05em | D2 | TSKY-2026-8431 |
| `svgBody16Regular` | Inter | 16 | 400 | — |  | P8 | 🚌 |
| `svgBody14Regular` | Inter | 14 | 400 | — |  | D1, D2, D3 | 🚌 |
| `svgBody13Regular` | Inter | 13 | 400 | — |  | A:Demand, A:Fleet, A:Overview | 🚌 |
| `svgBody10Regular` | Inter | 10 | 400 | — |  | A:Demand, A:Fleet, A:Overview |  |
| `svgBody10SemiBold` | Inter | 10 | 600 | — |  | P2 | price drops |
| `svgBody9Regular` | Inter | 9 | 400 | — |  | P3 | Madina → Circle |
| `svgBody9SemiBold` | Inter | 9 | 600 | — |  | P8 | DESTINATION |
| `svgBody9Bold` | Inter | 9 | 700 | — |  | P1 | YOUR SEAT |
| `svgBody8Regular` | Inter | 8 | 400 | — |  | P3 |  |
| `svgBody8Medium` | Inter | 8 | 500 | — |  | P3 |  |
| `svgBody8SemiBold` | Inter | 8 | 600 | — |  | P3 | 07:15 |
| `svgBody8Bold` | Inter | 8 | 700 | — |  | BusPin |  |
| `svgBody7Bold` | Inter | 7 | 700 | — |  | P2 | ₵ |
| `svgHeading16ExtraBold` | Jakarta | 16 | 800 | — |  | P2 | ₵ |
| `svgHeading13Bold` | Jakarta | 13 | 700 | — |  | P3 | July 2026 |

The chip style `body12SemiBoldH133` comes from Tailwind `text-xs font-semibold` (12px on a 16px line). Emoji-only text sizes (e.g. 24/400 for 📷) are included because the design draws icons as emoji; see below.

## Radii
| Radius | Screens |
|---|---|
| 2px | P5, P8, D1 |
| 3px | D5, A:Demand, A:Drivers, A:Fleet, A:Overview, A:Reports |
| 4px | P1, P2, P3, P6, P7, P10, P15, A:Reports |
| 6px | P7, P13, A:Drivers, A:Reports |
| 8px | P6, P10, P11, P14, D1, D4, D6, D9, A:Drivers, A:Reports |
| 10px | P9, P10, P12, P13, P14, P15, P16, D1, D2, D3, D4, D9, A:Drivers, A:Shell |
| 12px | P4, P6, P7, P9, P10, P13, P15, D1, D6, A:Analytics, A:Fleet, A:Login, A:Overview, A:Reports, A:Shell |
| 13px | D9 |
| 14px | P4, P5, P8, P13, P14, P15, D1, D2, D6, D7, D8, D9, A:Demand, A:Fleet, A:Login, A:Overview |
| 16px | P5, P6, P7, P8, P10, P11, P12, P13, P16, D1, D2, D7, D8, D9, A:Drivers, A:Reports |
| 18px | P11, D1, D2 |
| 20px | P5, P6, P7, P9, P10, P11, P12, P13, P14, P16, D1, D2, D3, D4, D5, D7, D9, A:Analytics, A:Demand, A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports |
| 22px | D2, D6 |
| 24px | P7, P9, P12, D4, A:Login |
| 25px | P8, D1, D3 |
| 26px | P7, D2 |
| 27px | P1, P2, P3, P4, P10 |
| 32px | Splash |
| `50%` | Splash, P1, P2, P5, P6, P7, P8, P9, P10, P11, P12, P15, P16, D1, D2, D3, D4, D5, D6, D7, A:Analytics, A:Demand, A:Drivers, A:Fraud, A:Overview, A:Shell |
| `6px 6px 0 0` | D4 |
| `20px 20px 0 0` | P5, P7 |
| `18px 18px 0 0` | P6 |
| `50% 50% 0 0` | P7 |
| `28px 28px 0 0` | P8 |
| `9999 (rounded-full)` | Chip |

SVG `rx` values in illustrations: 1, 1.25, 2, 3, 4, 6, 7, 8, 10, 16. `TroskyRadii.full` (9999) covers `border-radius: 50%` on squares and Tailwind `rounded-full`. `50% 50% 0 0` is the elliptical top of a seat headrest (P7).

## Borders
| CSS | Screens |
|---|---|
| `border: 1.5px dashed #E4E8EE` | P6 |
| `border: 1.5px dashed var(--amber)` | P11 |
| `border: 1.5px dashed var(--border)` | D8 |
| `border: 1.5px solid #E4E8EE` | P6, A:Login |
| `border: 1.5px solid rgba(14,158,109,0.2)` | D1 |
| `border: 1.5px solid rgba(14,158,109,0.25)` | D1, D3 |
| `border: 1.5px solid rgba(14,158,109,0.3)` | P6 |
| `border: 1.5px solid rgba(226,61,61,0.25)` | D2 |
| `border: 1.5px solid rgba(244,179,51,0.25)` | P10 |
| `border: 1.5px solid rgba(31,111,178,0.25)` | D1 |
| `border: 1.5px solid transparent` | P6 |
| `border: 1.5px solid var(--border)` | P4, P10, D8 |
| `border: 1.5px solid` | P10, D9 |
| `border: 1px solid #E4E8EE` | A:Drivers |
| `border: 1px solid #E8EAF0` | P12 |
| `border: 1px solid rgba(14,158,109,0.15)` | P4, D6 |
| `border: 1px solid rgba(14,158,109,0.35)` | D6 |
| `border: 1px solid rgba(226,61,61,0.15)` | P11 |
| `border: 1px solid rgba(244,179,51,0.3)` | D8 |
| `border: 1px solid rgba(255,255,255,0.04)` | P9 |
| `border: 1px solid rgba(255,255,255,0.05)` | P2 |
| `border: 1px solid rgba(255,255,255,0.06)` | Splash, P1, P8, P9, D3, D4, A:Shell |
| `border: 1px solid rgba(255,255,255,0.08)` | Splash, P1 |
| `border: 1px solid rgba(255,255,255,0.1)` | Splash |
| `border: 1px solid rgba(255,255,255,0.12)` | P15, D6 |
| `border: 1px solid rgba(31,111,178,0.2)` | D2 |
| `border: 1px solid rgba(31,111,178,0.3)` | P15 |
| `border: 1px solid transparent` | A:Shell |
| `border: 1px solid var(--border)` | P5 |
| `border: 1px solid` | A:Reports |
| `border: 2.5px solid var(--amber)` | P7 |
| `border: 2px solid rgba(14,158,109,0.3)` | D6 |
| `border: 2px solid rgba(226,61,61,0.2)` | P15 |
| `border: 2px solid rgba(226,61,61,0.35)` | P15 |
| `border: 2px solid rgba(255,255,255,0.2)` | P11, D5 |
| `border: 2px solid rgba(255,255,255,0.3)` | P5 |
| `border: 2px solid transparent` | P7 |
| `border: 2px solid var(--amber)` | P7 |
| `border: 2px solid white` | P11, D5 |
| `border: 3px solid rgba(14,158,109,0.2)` | D1 |
| `border: 3px solid rgba(14,158,109,0.25)` | D6 |
| `border: 4px solid rgba(14,158,109,0.18)` | D2 |
| `border: `1.5px solid ${t.color}`` | D8 |
| `border: `1px solid ${days.includes(d) ? 'var(--navy)' : 'var(--border)'}`` | P10 |
| `border: `1px solid ${i === 0 ? 'var(--navy)' : 'var(--border)'}`` | P6 |
| `border: `1px solid ${online ? 'rgba(14,158,109,0.4)' : 'rgba(255,255,255,0.1)'}`` | D1 |
| `border: `2px solid ${p.best ? 'var(--green)' : 'var(--border)'}`` | P10 |
| `borderBottom: 1px solid #E4E8EE` | A:Drivers, A:Fleet, A:Fraud, A:Overview, A:Reports |
| `borderBottom: 1px solid #F0F2F5` | A:Drivers, A:Reports |
| `borderBottom: 1px solid rgba(14,158,109,0.15)` | P6 |
| `borderBottom: 1px solid rgba(226,61,61,0.12)` | P6 |
| `borderBottom: 1px solid rgba(255,255,255,0.06)` | A:Shell |
| `borderBottom: 1px solid rgba(255,255,255,0.07)` | P8 |
| `borderBottom: 1px solid var(--border)` | P6, P9, P14, P16, D2 |
| `borderRight: 1px solid var(--border)` | P4 |
| `borderTop: 1px solid rgba(255,255,255,0.06)` | A:Shell |
| `borderTop: 1px solid var(--border)` | P11, P16, D1, D2, D3, D4, D5 |

Widths (`TroskyBorders`): 1, 1.5, 2, 2.5, 3, 4. SVG stroke widths in illustrations and icons: 1, 1.2, 1.5, 2, 2.5, 4, 28, 34.

## Shadows
Converted with `cssBoxShadow`: CSS blurs with σ = blur / 2, while Flutter derives σ from `blurRadius` as r × 0.57735 + 0.5, so the radius is converted to land on the CSS σ.

| Token | CSS | Used on |
|---|---|---|
| `card` | `0 2px 12px rgba(0,0,0,0.05)` | Standard white card (admin drivers/reports, D2, D4, D5, P9, P10, P11) |
| `cardSubtle` | `0 2px 12px rgba(0,0,0,0.06)` | Card (D3, P6, P7 booked counter) |
| `adminCard` | `0 2px 16px rgba(0,0,0,0.06)` | Admin dashboard cards; favourite routes card (P14) |
| `driverStatTile` | `0 2px 10px rgba(0,0,0,0.05)` | Driver home stat tiles (D1) |
| `input` | `0 2px 8px rgba(0,0,0,0.04)` | Phone number input (P4) |
| `primaryButton` | `0 6px 20px rgba(14,158,109,0.35)` | Green form CTA: Send OTP (P4), Sign In (admin), Accept Trip (D2), Book (P7), Subscribe (P10) |
| `onboardingLightButton` | `0 8px 24px rgba(0,0,0,0.2)` | White "Next" button (P1) |
| `onboardingGreenButton` | `0 8px 24px rgba(14,158,109,0.4)` | Green "Next" button (P2) |
| `amberButton` | `0 8px 24px rgba(244,179,51,0.35)` | "Get Started" (P3); withdrawal amber card (D9) |
| `goOnlineButton` | `0 6px 20px rgba(14,158,109,0.4)` | "Go Online" button (D1) |
| `goOfflineButton` | `0 6px 20px rgba(226,61,61,0.4)` | "Go Offline" button (D1) |
| `completeTripButton` | `0 4px 16px rgba(14,158,109,0.3)` | "Complete Trip" button (D3) |
| `seatSelected` | `0 4px 16px rgba(11,126,87,0.4)` | Selected seat (P7) |
| `splashLogoCard` | `0 24px 64px rgba(0,0,0,0.25)` | White logo card on the splash |
| `bottomSheet` | `0 -4px 20px rgba(0,0,0,0.08)` | Bottom sheet / fare panel (P5, P7) |
| `searchBar` | `0 4px 16px rgba(0,0,0,0.2)` | Home search bar on the navy header (P5) |
| `mapFab` | `0 2px 10px rgba(0,0,0,0.15)` | My-location map button (P5) |
| `sosButton` | `0 4px 16px rgba(226,61,61,0.5)` | Map SOS button (P5) |
| `liveTrackingSos` | `0 4px 16px rgba(226,61,61,0.45)` | SOS button on live tracking (P8) |
| `sosHoldGlow` | `0 0 40px rgba(226,61,61,0.5)` | SOS hold button glow (P15) |
| `seatMapCard` | `0 4px 24px rgba(0,0,0,0.08)` | Seat map card (P7) |
| `receiptCard` | `0 8px 24px rgba(0,0,0,0.08)` | Receipt card (D7), rate driver card (P16) |
| `qrCard` | `0 8px 32px rgba(0,0,0,0.1)` | QR ticket card (P12) |
| `walletCard` | `0 12px 40px rgba(18,38,59,0.35)` | Wallet balance card (P9) |
| `earningsCard` | `0 12px 40px rgba(18,38,59,0.3)` | Earnings card (D4) |
| `spendingSummary` | `0 8px 24px rgba(14,158,109,0.3)` | Spending summary card (P13) |
| `verifyCard` | `0 2px 12px rgba(244,179,51,0.12)` | Verify Ghana Card card (P11) |
| `tripActiveCard` | `0 4px 20px rgba(14,158,109,0.1)` | Active trip card (D1) |
| `qrBoardingCard` | `0 4px 20px rgba(31,111,178,0.08)` | QR boarding active card (D1) |
| `driverQrCard` | `0 6px 24px rgba(0,0,0,0.08)` | Driver boarding QR card (D2) |
| `boardingHintCard` | `0 2px 12px rgba(14,158,109,0.12)` | "Passengers scan this to board" card (D2) |
| `incomingRequestHeader` | `0 4px 16px rgba(0,0,0,0.3)` | Incoming request card header (D2) |
| `incomingRequestCard` | `0 4px 20px rgba(0,0,0,0.08)` | Incoming request card (D2) |
| `chartTooltip` | `0 8px 24px rgba(0,0,0,0.12)` | Admin chart tooltips |
| `adminLoginCard` | `0 40px 80px rgba(0,0,0,0.4)` | Admin login card |
| `busPinGreen` | `0 3px 6px rgba(14,158,109,0.5)` | Map bus pin (CSS filter drop-shadow) |
| `busPinAmber` | `0 3px 6px rgba(244,179,51,0.5)` | Map bus pin, amber (CSS filter drop-shadow) |

**Blurs:** splash glow `filter: blur(40px)` (σ 40); `backdrop-filter: blur(8px)` on D1 and D3 panels, `blur(12px)` and `blur(20px)` on P8.
**Near-duplicates:** card (`0 2px 12px` 0.05) vs cardSubtle (0.06) vs adminCard (`0 2px 16px` 0.06); onboardingGreenButton (`0 8px 24px` green 0.4) vs goOnlineButton (`0 6px 20px` green 0.4) vs primaryButton (`0 6px 20px` green 0.35); sosButton (red 0.5) vs liveTrackingSos (red 0.45).

## Spacing
Padding, margin and gap values (Tailwind classes at 4px per unit): -16, -14, -12, -8, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22, 24, 28, 32, 36. Negative values are margins that pull an element up.

## Opacity
Element opacity values: 0, 0.14, 0.15, 0.18, 0.2, 0.25, 0.3, 0.4, 0.45, 0.5, 0.6, 0.7, 0.8, 0.9, 0.92, 0.95. `TroskyOpacity.disabled` = 0.7 (the "Go Offline" button while passengers are on board, D1) and `seatTaken` = 0.6 (P7).

## Motion
| Name | Spec | Used on |
|---|---|---|
| pulse-dot (`.anim-pulse`) | 2s ease-in-out infinite; scale 1 → 1.6, opacity 0.8 → 0.3 | Live location dot (AcraMap, P8) |
| float (`.anim-float`) | 3s ease-in-out infinite; translateY 0 → −6px | Onboarding illustrations; delays 0.5s (P2) and 1s (P3) |
| slide-up (`.anim-slide`) | 0.4s cubic-bezier(0.16,1,0.3,1); translateY 20px → 0, fade in | Defined, not used yet |
| price-flash (`.anim-price`) | 0.5s ease; ink → green → ink, scale 1.05 at 40% | Defined, not used yet |
| spin-slow | rotate 0 → 360deg, **no duration or easing defined** | No class uses it |
| ripple | scale 1 → 3, opacity 0.6 → 0, **no duration defined** | No class uses it |

Inline transitions (CSS `ease`): 0.15s (P10 plan cards), 0.2s (P7 seats, D1 online button), 0.25s (P7), 0.3s (P1 page dots, D2 background), 0.4s (P7 booked counter, D4). Respect the reduce-motion setting (`MediaQuery.disableAnimations`).

## Emoji and symbols used as icons (not replaced yet)
| Glyph | Where |
|---|---|
| 🚌 | Map markers and sidebar (A:Overview, A:Fleet, A:Demand, A:Shell), D1–D4 stat tiles and cards, P7 seat map cab, P8 map, P9 |
| 👤 👥 | Avatars and passenger counts: A:Fraud, A:Overview, A:Shell, D1–D3, D8, P7 (taken seat), P11, P15 |
| 👨🏿‍💻 👨🏿 👨🏿‍💼 👩🏿‍💼 | Profile avatars: A:Shell, P8 (driver), P11, D5 |
| 🔔 | Notifications: P5, P11 |
| 📞 💬 📤 | Call, chat, share trip: P8, P11, P15 |
| 🗺️ 💰 📄 📊 📈 ✅ ⏱️ 🔍 | Admin KPIs, report cards and navigation (A:Overview, A:Reports, A:Shell), D1 stats, D5, P11 |
| ⭐ ★ | Ratings: A:Fraud, A:Analytics, A:Drivers, D1, P8, P11 |
| 🚨 🔧 ⚠️ 🚫 | Incidents and warnings: A:Reports, D1, D8, P8 ("🚨 SOS") |
| 📷 📲 🏠 📍 | Scan QR, QR boarding, home, location: D1, D3, D8, P11 |
| 🪪 🇬🇭 | Ghana Card note and +233 prefix flag: P4, P11 |
| 👋 | Greeting "Kwame Asante 👋": P5 |
| 🔒 🌍 💡 📱 | Security, language, tips, mobile money: A:Shell, D2, P9, P11, P14 |
| 🌅 🌆 🎉 | Morning/evening commute and success: P10 |
| 🔴 🟡 🟢 | Severity cards: A:Fraud |
| ⏳ | Pending status: admin chips, D3, D5 |
| ✓ ● ○ ⚠ ✕ ↗ • | Text symbols in status chips (admin), "↗ Send" (P9), password dots (A:Login) |

## What the tokens can't reproduce exactly
- **Logo:** the Figma screens show raster images (`troSkyLogoBright` PNG, `troSkyLogo` JPEG); `TroskyLogo` uses the SVGs in `design/assets` instead, and those are a **different artwork** (navy pin with a side-view bus and an upright wordmark, versus the green pin with a front-view bus and an italic wordmark in the screenshots). In the SVG, "Sky" is placed for Arial Black metrics, so with Plus Jakarta Sans there is a gap ("Tro Sky"). The package copy has its text converted to outlines and the tagline typo "Tiine" corrected to "Time".
- **Pressed, disabled and loading states** are not designed. The buttons use the one disabled pattern in the code (D1: opacity 0.7, no shadow), drop the shadow when pressed (green buttons also switch to greenDark), and show a spinner in the label colour when loading.
- **Weights 900 and Inter 800** render at 800 and 700, as they do in the browser.
- **Monospace** uses the platform font; CSS `monospace` also varies by browser.
- **spin-slow and ripple** have no duration, so there is nothing to reproduce until one is chosen.
- **Brand logos in the wallet** (P9) are drawn with Arial SVG text; real brand assets are needed.

## Accessibility notes (flagged, not changed)
- White on green `#0E9E6D` is **3.43:1**. That's fine for the bold 16 px+ button labels in the design (large text). Never use it for small body text.
- Green text on white or on `#F5F7FA` is 3.4 / 3.2:1, so use it for bold links only.
- Ink on amber is 8.8:1 ✓. White on navy and white on blue ✓.
