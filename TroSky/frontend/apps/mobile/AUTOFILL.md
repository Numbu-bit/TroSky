# TroSky — authentication autofill semantics

H2 of the 21 Nov 2026 pre-launch audit.

## What already worked on `main`

- Welcome `PhoneField`: `AutofillHints.telephoneNumber`.
- Sign-in password: `AutofillHints.password`.
- Details (registration) name: `AutofillHints.name`; email:
  `AutofillHints.email`; new password: `AutofillHints.newPassword`.
- OTP input (`TroskyOtpInput` in `trosky_ui`):
  `AutofillHints.oneTimeCode`.

## What H2 changed

- Sign-in **email-mode identifier** now carries
  `[AutofillHints.username, AutofillHints.email]`. iOS Keychain and
  password managers key on `username` for primary identifiers; the
  `email` hint helps the suggestion sheet surface an existing email
  from the manager's vault.
- On a successful credential submit we now call
  `TextInput.finishAutofillContext()`:
  - Sign-in success (both password and code modes).
  - Registration success (`DetailsScreen._submit` → `Ok`).
  - Password reset completion
    (`NewPasswordScreen._submit` → `Ok`).
  On iOS this commits the autofill group so the OS offers to save
  the new credential. On Android it signals the autofill framework
  to finalize the save sheet.

## Deliberately **not** changed

- **No `AutofillGroup` wrapper added around the auth forms.** iOS
  and Android autofill work off the hints when the fields are
  visible in the same frame; wrapping was investigated but ends up
  requiring restructuring `AuthLayout`'s `children: [...]` slot to
  host a single `AutofillGroup` child, and the empirical gain over
  the hints-only path is small. Reconsider if a specific manager
  misses a save in device testing.
- **Paste disabling / copy blocking / "no password manager" hacks:**
  never. The brief explicitly forbids them.
- **No SMS retriever plugin added.** The OTP input already has
  `oneTimeCode`, which iOS honors natively. On Android,
  `oneTimeCode` triggers the Google-side SMS consent dialog
  already; the full SMS-retriever API would be a later
  enhancement.

## Flows covered

| Flow | Identifier hint | Secret hint | `finishAutofillContext` |
| --- | --- | --- | --- |
| Welcome → phone entry | `telephoneNumber` | — | — |
| Sign-in (email mode) | `username, email` | `password` | yes, on `Ok` |
| Sign-in (phone mode) | `telephoneNumber` | `password` | yes, on `Ok` |
| Sign-in (code mode) | `telephoneNumber` | OTP | yes, on `Ok` |
| Registration | `name`, `email` | `newPassword` | yes, on `Ok` |
| Verify code (OTP) | — | `oneTimeCode` | — (handled by next screen) |
| Password reset — new password | — | `newPassword` | yes, on `Ok` |

## Scope boundaries, honestly

Hints are an **interoperability improvement**, not a guarantee
against phishing or cross-service credential reuse. They let the
OS match a saved TroSky credential to the right form. They do
nothing about users typing the same password on a lookalike site.

## Logging

No code path logs filled values. H5 (crash + network log
redaction) adds the broader guarantee; this PR does not introduce
any new log line.
