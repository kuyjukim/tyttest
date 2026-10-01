# App Store Connect — the rest of the form

| Field | Value | Why |
|---|---|---|
| Primary category | Finance | The paid Finance chart is the target: its incumbents are single-purpose calculators, because every real budgeting app went to a subscription and so lives in the *free* chart. |
| Secondary category | Productivity | |
| Age rating | 4+ | No user-generated content, no web view, no ads. |
| Price | ₩8,000 / US$5.99 | The US paid Finance incumbents sit at $2.99–$5.99, and the subscriptions this is an alternative to charge $80–$109 a year. ₩8,000 sits under 편한가계부 (광고제거) at ₩8,800 and 위플 가계부 Pro at ₩17,000 - but those two *are* the top of Korea's paid Finance chart, so see `competition.md` before counting on that market. |
| In-app purchases | None | |
| Sign in required | No | |
| Account deletion | Not applicable - there is no account | |

## App Privacy — answer "Data Not Collected"

Every question gets the same answer, and in this app it is literal rather
than a position: the binary contains no HTTP client, so there is nowhere for
data to be collected to.

- Data used to track you: **none**
- Data linked to you: **none**
- Data not linked to you: **none**

## Export compliance

`ITSAppUsesNonExemptEncryption = false` is already in `Info.plist`, so the
question is answered at build time rather than on every upload. This is true
for Ledger: it contains no encryption. **Inkwell must not copy it** - it uses
AES-256-GCM and Argon2id and has to answer properly, which for a standard
algorithm in an app that is not exporting cryptography usually means claiming
the exemption rather than denying encryption.

## Review notes

> The app stores everything locally and has no network access, so there is no
> demo account to provide. Launch the app, tap "Add an envelope", give it a
> name and a monthly amount, then tap the envelope to record spending against
> it.
