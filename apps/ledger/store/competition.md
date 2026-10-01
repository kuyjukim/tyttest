# Who else is already there

Checked 2026-10-01 by web search. The store hosts themselves
(apps.apple.com, play.google.com, Apple's chart RSS) are denied by this
environment's network policy, so none of this comes from the stores
directly - it comes from search results and the pages indexing them. Numbers
below should be re-read off a phone before anyone spends money on them, but
they are consistent across two independent searches and with each other.

## The claim this app was built on was wrong

The claim: **the paid Finance chart is uncontested by budgeting apps,
because they all moved to subscriptions.** It was true. It was observed on
the *US* chart and then applied to Korea, which is where the whole plan went
wrong.

### Korea - paid Finance, top of the chart

| # | App | Price | Reviews |
| --- | --- | --- | --- |
| 1 | **위플 가계부 Pro** | ₩17,000 | 4.8★ / 8,400 |
| 2 | **편한가계부 (광고제거)** | ₩8,800 | 4.8★ / **87,000** |
| 3 | 멤버십 위젯 Pro | | |
| 4 | 보안카드 위젯 | | |
| 5 | CryptoWatch | | |
| 6 | 편한가계부 Classic | | |

Three of the top six are 가계부 apps. Not "no budgeting apps in the paid
chart" - they *are* the paid chart.

And look at what those two are: both are the **paid unlock of a free app**.
편한가계부 (광고제거) is the ad-free SKU of an app with an enormous free base;
87,000 reviews is what that base looks like from the paid side. In Korea the
paid 가계부 market is not a separate market a new app can enter. It is the
monetisation tail of the free one, and the way in is a free app with years
of users, not a cold ₩8,000 purchase.

### United States - paid Finance, top of the chart

Military Retirement ($5.99), Compoundee ($2.99), 10bii Financial Calculator
($5.99), My Currency Converter Pro ($3.99), US Debt Clock ($4.99), HP 12c
($14.99).

Calculators and converters. **No budgeting app.** Because the budgeting apps
are all subscriptions and a subscription app is a free download - YNAB
$14.99/mo or $109/yr, Monarch $14.99/mo or $99.99/yr, Copilot $13/mo or
$95/yr, Goodbudget Premium $10/mo or $80/yr. Every one of them sits in the
*free* chart and charges inside.

So the original observation holds, for the market it was made in.

## Every differentiator that was claimed is occupied in Korea

| Claimed difference | Status |
| --- | --- |
| "Korean 가계부 apps are retrospective, no prospective app exists" | **False.** 편한가계부 has per-category monthly budgets. |
| Rollover of what is left | **Occupied.** 편한가계부 has a carryover setting. |
| Rollover of an *overspend* too | **Occupied.** 위플 carries 마이너스 forward as well. |
| "How much can I spend today" as the headline number | **Occupied.** 하루용돈 (`com.moneydaily.app`) is built entirely around it - "은행 계좌나 카드 연동 없이, 오늘 얼마까지 써도 안전한지만 알려주는" - and 마진 (하루 예산 가계부) is another. |
| Offline, no account, data on the device | **Occupied.** 하루용돈 again: "모든 데이터는 기기에만 저장되며, 별도 회원가입이나 계좌 연동이 필요 없습니다." |
| No ads | **Occupied.** Several, e.g. "가계부: 수입 지출 내역, 예산 관리, 저축 계획, 광고 없음". |

The only mechanic not yet found in a Korean app is **moving money between
envelopes mid-month** - the thing that makes an envelope a pot rather than a
target. That is one mechanic, and it is not a product.

Against all that, Ledger also has **no automatic entry**, where 편한가계부
reads the card-approval SMS and fills the row in for you. On Android that is
most of the daily work of keeping a 가계부. On iOS no app can read SMS, so
the gap is much smaller there - but "smaller" is not "an advantage".

## What the English-speaking market looks like instead

The subscription incumbents have left the one-time-payment slot open, and
what is in it is small: Forge (zero-based, offline, no subscription),
BudgetVault (free, browser storage), Actual Budget (free, self-hosted),
FinancialAha (a $139 spreadsheet). Goodbudget is the envelope incumbent and
is freemium at $80/yr for premium.

None of them is a ₩/$ paid-upfront native app sitting in the chart. A $5.99
paid app entering the US Finance chart is not trying to outsell YNAB - it is
trying to outsell a currency converter and an HP calculator emulator.

## What this means

**Korea is the wrong lead market for this app, and it was chosen on a US
observation.** Taking Korean paid Finance #1 means outselling an app with
87,000 reviews and a decade of free-tier funnel behind it. Nothing in this
repo makes that likely.

The thesis was not wrong - it was pointed at the wrong country. The place
where "a paid budgeting app has an empty chart to climb" is true is the
English-speaking App Store.

That makes the Korean localisation a free extra rather than the plan: it is
already built, it costs nothing to ship, and it may find the people who want
an envelope app specifically. It just should not be what the listing leads
with, and the Korean chart should not be what success is measured against.

The Android advice follows the same way, and more strongly than before: the
one quadrant where the competition is strongest is Korean Android, where
SMS auto-entry works and the incumbents are free. See `RELEASE.md`.
