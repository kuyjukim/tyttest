# The plan

The goal is **#1 on a paid category chart**. That is a chart position, not a
business, and the two are different problems. This repository spent a day
answering the second one - can you out-earn an incumbent - and concluded no,
correctly, to a question nobody asked.

## What changed

Paid charts rank on **recent purchase velocity**, refreshed hourly, scoped to
**country × category × chart type × device**. Lifetime sales do not rank; a
burst does. A Korean developer's own account of holding #1 paid *overall* on
the Korean App Store puts it at **roughly 200 downloads in a day**, organic,
no ad spend.

A single category is a subset of overall, so its bar is lower. Eight Korean
category charts were measured, and every one judged thin was then re-measured
by a second agent that did not see the first one's working.

| Korean paid chart | Units in one day for #1 | Verdict |
| --- | --- | --- |
| **생산성 Productivity** | **~12–30** (two estimates: 30 and 12) | **confirmed thin** |
| 참고 Reference | 20–40, and 10–15 on a quiet day | confirmed thin |
| 교육 Education | 40–70 to take, 25–35 to hold | confirmed thin |
| 라이프스타일 Lifestyle | 70–110 | claimed thin, **overruled** |
| 유틸리티 Utilities | 80–150 | claimed thin, **overruled** |
| 건강·피트니스 Health | 80–150 | claimed thin, **overruled** |
| 금융 Finance | 60–80 | moderate |
| 그래픽·디자인 Graphics | 60–80 | moderate |

Twelve to thirty purchases in a day. Not twelve thousand.

## The seat in Productivity is vacant, and that is new

**Forest left the paid chart in December 2025.** Seekrtech moved it to
free-with-subscription, so the app that *was* the paid anchor of Korean
생산성 - a focus timer, 16,000 Korean ratings - is no longer on that chart at
all.

This repository's own `MARKET.md` declared Grove closed on the grounds that
"Forest is #2 in US paid Productivity *and* in Korea's top paid chart". The
second half of that is now false, and it was the half that mattered. That
verdict is withdrawn.

What is left on the chart behind it:

| # | App | Price | Korean ratings |
| --- | --- | --- | --- |
| 2 | DayDay 하루하루 | ₩4,400 | 5,188 |
| 3 | SFFE (a Safari font extension) | ₩3,300 | 142 |
| 4 | iFacialMocap (a VTuber mocap bridge) | ₩11,000 | ~55 worldwide |
| 5 | Highlight 하이라이트 | ₩2,900 | **32, lifetime, since 2021** |

A chart whose fifth place has thirty-two lifetime ratings is not defended.
And in a recent snapshot the **#1 slot was held by Paper Maker at ₩400** -
the cheapest price point on the store holding the top position, which is as
plain a demonstration as exists that this chart counts units and not revenue.

## The plan

**App:** Grove, the focus timer. Already built, already Korean-localised,
already passing its suite.

**Category:** 생산성 (Productivity). The fit is honest and the precedent is
Forest itself, which was filed there. Apple has no re-categorisation argument
against a focus timer in the category whose former #1 was a focus timer.

**Not Inkwell.** A private journal in 생산성 is a stretch: Apple files Day One
under Health & Fitness, and Korean diary apps sit in Lifestyle. A reviewer
would have a fair case to move it, and a re-categorised app loses the chart
it was aimed at.

**Price: ₩1,100–₩1,500 for the run.** The chart counts units, so the cheapest
credible price wins the most positions per unit of demand. The chart's median
is ₩4,400, so this undercuts everything on it but two. Not ₩400 - against a
₩4,400 median that reads as disposable and buys little extra conversion. If
the goal later shifts from position to earnings, ₩4,400 is where this chart's
actual residents sit.

(A correction to an earlier note here: Korea's conventional floor is ₩1,500,
not ₩1,100. Apple raised Tier 1 from ₩1,200 to ₩1,500 in October 2022, and
the 2023 move to ~900 price points is what makes sub-floor points like ₩1,100
and ₩400 available at all.)

**Volume: plan for 25–40 purchases inside one day.** The two independent
estimates were ~12 and ~30; 25 covers the pessimistic one and 40 makes it
unambiguous through an hourly refresh. Thirty honest purchases in a day is
one Korean community thread that lands, one newsletter send, or one mid-sized
productivity YouTuber mentioning it.

**Velocity, not volume.** Thirty units bought inside one day beats three
hundred spread across a month. Pick the day, then concentrate everything on
it.

**iPad is a separate and thinner chart.** Korea-iPad-생산성-paid is its own
pool, and both DayDay and Forest charted there at lower ranks than on iPhone.
It is a second shot at the same work.

### What this does not include

No purchased installs, no incentivised downloads, no review farming. Those
breach the App Store Review Guidelines, and the penalty is the developer
account. The whole plan above needs ordinary launch-day demand, concentrated.

## How much of this is solid

The anchor is one developer's self-report from one month. Both estimates for
Productivity are the agents' own curve-fitting from that anchor plus rating
counts, and they differ from each other by 2.5×. The qualitative finding -
that this chart is thin and that Forest has left it - is much firmer than any
specific number, and is what the plan rests on.

## Work remaining on Grove

It has never had the submission pass Ledger got:

- [ ] Its own icon. `tool/make_icon.py` draws Ledger's mark only, and
      `make_app_icons.sh` now refuses to run for another app rather than
      silently giving it the wrong one.
- [ ] `PrivacyInfo.xcprivacy`, and `tool/wire_ios_resources.rb` generalised
      past Ledger to put it in the bundle.
- [ ] Korean and English App Store listing copy, through
      `tool/check_listing.py`.
- [ ] Screenshots, through the golden harness.
- [ ] Android config to Ledger's standard, if Play is wanted later.
- [ ] A bundle id, signing, and a real device run.
