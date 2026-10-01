# Where to look next

Researched 2026-10-01 by web search, after three market claims in this
repository were falsified in a row. The method here is the one that failure
taught: **do not look for an empty chart position. Look for proven paid
demand with an incumbent you can name.** An empty position has always turned
out to be the market having already answered. See `MARKET.md`.

## The redirect

The chart that rewards this repository's shape is not Finance. It is
**Navigation, Travel and Utilities**, and it looks like this:

| App | Price | Who made it | Since |
| --- | --- | --- | --- |
| MilGPS | $12.99 | one person (Cascode Labs) | ~2011 |
| Sun Seeker | $11.99, 4.8★, **13,000 ratings**, #6 Navigation | one person (ozPDA) | 2009 |
| Theodolite | $8.99, 4.7★, 902 ratings, #9 Navigation | one person (Craig Hunter) | 2009 |
| Sporty's E6B Flight Computer | $9.99 | a pilot shop | |
| aprs.fi | $6.99 | one person | |
| Cachly (geocaching) | $4.99 | one person | |
| PeakFinder | $4.99, top paid Travel | one person | |
| Boondocking / USFS & BLM Campgrounds / RV Dump Stations | $0.99 and up, three of the top ten paid Travel | **the same one person** | |

Every one of these is a **computational instrument**: sensors or public data
plus arithmetic, offline, bought once, built by an individual. Several are
fifteen years old and still ranking. That is a market where a small, correct,
well-made app is the whole product - which is what this repository is good
at, and what it spent four apps proving in a category where it did not
matter.

What they have in common is sharper than "narrow". **Each one replaces a
physical instrument or a paper table.** The E6B replaces a flight computer.
MilGPS replaces a map and protractor. Theodolite replaces a surveying scope.
A tide app replaces the tide book.

## What was checked and is taken

Checking first is the point of this file, so here is what checking killed
before a line of code:

- **Tides, offline, no subscription.** The shape was perfect: NOAA harmonic
  constituents are public domain, about 3,400 stations, prediction is
  harmonic synthesis from Schureman SP-98, and it is brutally timezone- and
  DST-sensitive, which this repository has already proved it handles. The
  market leader, Tide Alert, has 44,000 ratings and moved to **$19.99/yr**
  for public-domain data, with users publicly angry about it.
  **Taken: Ebb.** $9.99, one time, no subscription, no account, "offline
  tide charts and solunar fishing times computed on your phone from NOAA
  data". That is the specification, written by someone else, already
  shipped. AyeTides also holds the ground at $7.99 with 4.8★ over 15 years.
- **Sun and moon ephemeris.** Taken twice over: PhotoPills at $10.99 is #1
  in Photography, Sun Seeker at $11.99 is #6 in Navigation with 13,000
  ratings.
- **Hunting and public land.** onX charges $34.99–$99.99 a year, but the
  moat is parcel ownership data, which is fragmented county-level licensing
  and not obtainable.
- **Korean 물때 (tide tables for sea fishing).** 바다타임, 물때와날씨,
  오늘의물때, 어신 - all free, all ad-supported. The same structure as
  Korean budgeting apps, and the same conclusion: not a paid market.

## Checked. All seven are occupied.

Seven candidates in the shape above went to seven agents in parallel, each
told to answer "who already tried this and what happened to them" rather than
"is this empty", and each required to produce named apps with prices from
search results rather than from memory. Any verdict of *open* would then have
gone to two skeptics whose job was to find the app that disproves it.

**The skeptics never ran. Nothing came back open.** Between them the seven
agents found about 108 competing apps - eleven to nineteen per idea.

| Idea | Verdict | Apps found | The number that settles it |
| --- | --- | --- | --- |
| Celestial navigation | crowded | 13 | StarPilot, $49.99, **8 US ratings in 16 years**. Navimatics' Celestial - the one sailors recommended for a decade - was removed from the App Store in January 2025. And Sextant (Stolk.cc) shipped the exact pitched product in 2025 for **$1.99**. |
| Satellite passes | taken | 11 | Orbitrack $4.99, by the SkySafari developer. The whole niche's best paid data point is an ISS tracker at $1.99 with 1.2K ratings - low tens of thousands of dollars across ten years. |
| Aviation performance | crowded | 18 | Sporty's E6B, $9.99, 4.9★, **5.4K ratings**, top five of all paid Navigation. Two more E6B apps sit at #8 and #16 of the same chart. |
| Ham radio | crowded | 17 | HamStudy.org $3.99, 4.9★, 2.5K ratings, #10 in paid Education. |
| COLREGs | taken | 19 | NavRules $15.99, #16 in paid Navigation. COLREG 72 at $3.99 has 3,110 Play reviews after a decade. |
| Trade field maths | taken | 13 | QuickBend $6.99, 4.8★, 3.9K ratings, **#1 top paid Productivity in the US**. Construction Master Pro has ~40K ratings. |
| Film development | taken | 17 | Massive Dev Chart Timer, $9.99, **55 US ratings in sixteen years**. |

### The law underneath all of it

Read the right-hand column twice and the two kinds of niche separate:

- **Small enough to be empty**: celestial navigation (about a hundred
  ratings across every dedicated app in existence), film developing (55
  ratings in sixteen years), satellite passes (a decade for tens of
  thousands of dollars). Nobody strong is competing *because there is
  nothing there to win*.
- **Big enough to be worth it, and therefore already won**: the E6B at 5.4K
  ratings, QuickBend at #1 paid Productivity, Construction Master at 40K
  ratings, NavRules in the paid Navigation chart.

**Market size and incumbent strength are the same variable.** Emptiness is
not an opportunity that the strong overlooked; emptiness is *caused by*
smallness. Which is why ten attempts at "find the niche nobody has taken"
have now failed ten times, and why the eleventh will fail too unless the
question changes.

The question that is left is not "what is unoccupied". It is "what can be
done better than an incumbent who is making real money" - against named
apps, with their complaints in hand. That is a different and much harder
question, and it is the only one with anything behind it.

## The original three hypotheses, now answered

All three were in the seven above. All three are dead. They are kept here
because the reasoning that produced them was sound and still produced seven
wrong answers, which is the most useful thing in this file.

1. **Celestial navigation.** Sight reduction and the Nautical Almanac are
   still taught and still carried on paper. US Naval Observatory ephemeris
   data is public domain and the arithmetic is exacting, which is the kind
   of correctness this repository can demonstrate. Small, serious audience.
2. **Satellite pass prediction.** Orbital elements are published freely by
   Celestrak; SGP4 propagation is a documented algorithm and runs offline
   forever from one download.
3. **Aviation performance tables** - weight and balance, density altitude,
   crosswind components. Sporty's E6B at $9.99 proves pilots buy
   calculators; FAA data is public domain.

The rule from here: **the search comes before the build, the search is not
"is this empty" but "who tried this and what happened to them" - and a niche
with no strong incumbent is a niche with no money in it.**
