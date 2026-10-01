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

## Unchecked hypotheses, in the shape above

These fit "replaces a paper table or an instrument, public or computable
data, offline, no sensors this repository cannot test". **None has been
checked.** Each needs the same treatment the tide idea got - find who is
already there and what happened to them - before anything is built.

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

The rule from here: **the search comes before the build, and the search is
not "is this empty" but "who tried this and what happened to them".**
