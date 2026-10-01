# Who else is already there

> **Nothing in this file has been verified.** Every store host - itunes.apple.com,
> apps.apple.com, play.google.com, Apple's own chart RSS - is denied by this
> environment's network policy, so none of it could be looked up. It is
> written down because an unrecorded assumption is worse than a recorded
> guess, and because the checks at the bottom take ten minutes on a phone and
> settle the question properly.

## The claim this app was built on, and what is wrong with it

The pitch was: Korean 가계부 apps are **retrospective** - you record what you
already spent - while envelope budgeting is **prospective**, and no
established Korean app does the prospective thing. On that reading Ledger
was carrying a known-good foreign genre into a market with no incumbent.

Three names put that in serious doubt:

| App | Confidence it exists | What it means for the claim |
| --- | --- | --- |
| **편한가계부** (Realbyte; sold abroad as Money Manager) | High | A major Korean 가계부 with a **per-category monthly budget**. So "Korean apps have no budget feature" is simply false. Free with advertising, paid tier to remove it. |
| **위플가계부** | Fairly high it exists; **low** on its feature emphasis | Remembered as budget-leaning rather than ledger-leaning. If that is right, the "no prospective Korean app" line is gone outright. |
| **오늘쓸돈** | Moderate | The name *is* "money to spend today" - Ledger's headline number. If the app is what its name says, 안심 지출 한도 is not a differentiator in Korea at all. |

Treat the claim as **falsified until someone checks**, not as merely
doubtful. Planning around it as though it still held is the expensive
mistake.

## What might still be a real difference

A budget field is a **target**: a number to compare against at month end,
coloured red when you pass it. An envelope is a **pot**: money that is
somewhere, that runs out, and that has to come from another pot if you want
more. Three mechanics follow from that, and a budget field has none of them:

1. **Moving money between envelopes mid-month.** Overspending is not an
   error message, it is a decision about where the money comes from instead.
2. **Rollover in both directions.** What is left carries, and so does an
   overspend. A budget that resets on the 1st forgives going over, which is
   the moment a budget mattered most.
3. **All income assigned.** Income minus allocations is zero by
   construction, rather than a budget that can quietly sum to less than you
   earn.

Whether the Korean incumbents do any of these is exactly what has not been
checked. If 편한가계부 lets you move budget between categories mid-month and
carries the remainder forward, Ledger has no mechanical story left and is
competing on being paid, quiet and offline - which is a position, but a much
smaller one.

## The thing that cuts the other way

Ledger has **no automatic entry at all**. Korean 가계부 apps on Android read
the card-approval SMS and fill the entry in for you, which is most of the
daily work of keeping a 가계부. Against that, "type it in yourself" is a
genuine disadvantage, not a philosophical stance.

But it is a disadvantage with a shape. **iOS gives no app access to SMS**,
so on iPhone the Korean incumbents cannot do it either - they fall back to
open-banking connections, which need accounts and usually a subscription, or
to the same manual entry. The gap is therefore:

| | Korea | English-speaking markets |
| --- | --- | --- |
| **iOS** | Small gap. Nobody reads SMS; a paid, offline, no-account app is a fair fight. | Smallest gap. Manual entry reads as privacy, and the subscription incumbents (YNAB and friends) have left the one-time-payment slot empty. |
| **Android** | **Largest gap.** Competitors auto-fill from SMS and are free with ads. | Middling. |

This reverses the advice given earlier in the same week - that Android
matters more for a Korean app because Korea's Android share is high. It
does, for most apps. For *this* app the one quadrant where the competition
is strongest is the Korean Android one, because that is the only quadrant
where the incumbent's biggest advantage is switched on.

## What to check, and what each answer changes

Ten minutes with a Korean App Store account:

1. **Search 봉투, 봉투예산, 제로베이스 in the Korean App Store.** Nothing
   envelope-specific ranking means the genre really is unoccupied, whatever
   the 가계부 apps do. Something ranking means read it first.
2. **Open 편한가계부 → can you move this month's budget from one category to
   another?** No means mechanic (1) survives as a difference.
3. **Same app → does an unspent category budget carry into next month?**
   No means mechanic (2) survives.
4. **오늘쓸돈 → is the daily number the whole product, and is it free?** If
   it is a free app built entirely around that number, drop it from Ledger's
   headline and lead with the envelopes instead.
5. **Korean paid Finance chart, top 20 - how many are 가계부?** This is the
   finding the whole plan rests on. If the answer is still "none", a paid
   envelope app has an uncontested chart to climb whatever the free apps do.

**Decision rule.** Questions 2 and 3 decide the product story: two noes and
the envelope mechanics are the pitch. Question 5 decides the market: it is
the only one that says whether a *paid* app has anywhere to rank. Question 5
mattering more than 1-4 is the point - Ledger does not have to beat
편한가계부 at being a 가계부. It has to be the best paid app in a chart the
free ones are not in.
