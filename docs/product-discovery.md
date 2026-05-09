# Product Discovery: Privacy-First iOS Apps for Open APIs

## Desired Outcome

Identify the highest-value iOS app opportunities where a clean, privacy-first UI over a free/open API can decisively beat bloated, ad-heavy incumbents.

**Success metric:** App reaches 10K+ downloads within 6 months with 4.7+ star rating, sustained by paid model (no ads/tracking).

---

## Opportunity Solution Tree

### Outcome: Users get fast, private, ad-free access to public data

---

### Tier 1 Opportunities (Strongest)

#### 1. Dictionary & Thesaurus
**API:** Free Dictionary API, Wiktionary API (free, no key required)
**Why this is ripe:**
- Dictionary.com and Merriam-Webster iOS apps are aggressively ad-heavy — full-screen interstitials, banner ads, video ads, extensive tracking
- High-frequency use case (students, writers, ESL learners, professionals)
- The data is simple and fast to render — a clean app would feel transformatively better
- Apple's built-in dictionary exists but is buried and limited (no thesaurus browsing, no word-of-the-day, no history)

**Existing pain (evidence):**
- Dictionary.com has ~2.5 stars in recent reviews, complaints centre on ads and bloat
- "I just want to look up a word without watching a video ad" is a recurring sentiment
- Users resort to Safari → Google as a workaround, which signals unmet need for a native app

**Feasibility:** Low complexity. Text-based UI, small payloads, offline caching is straightforward.
**Differentiation:** Instant lookup, offline mode, clean typography, zero tracking, search history stays on-device.

---

#### 2. Movie & TV Reference (TMDB)
**API:** TMDB (The Movie Database) — free API key, excellent data, community-maintained
**Why this is ripe:**
- IMDB app is Amazon-owned, bloated, heavy tracking, cluttered UI pushing Prime content
- No clean, privacy-respecting movie/TV reference app exists
- Letterboxd is good but focused on social logging, not quick reference
- High-frequency casual use ("who was in that movie?", "what should I watch?")

**Existing pain:**
- IMDB app is slow, pushes Amazon content, collects extensive behavioural data
- Users want cast/crew/ratings lookup without a commerce platform attached

**Feasibility:** Moderate. Image-heavy but TMDB API is well-documented and generous with rate limits.
**Differentiation:** Fast search, clean detail pages, no algorithmic recommendations pushing paid content, watchlist stays on-device.

---

#### 3. Book Discovery & Tracking (Open Library)
**API:** Open Library API — fully free and open, part of Internet Archive
**Why this is ripe:**
- Goodreads (Amazon-owned) is notoriously slow, bloated, buggy, and tracking-heavy
- Goodreads hasn't had a meaningful update in years — deeply frustrated user base
- Book community has been vocally seeking alternatives
- Open Library has solid book metadata, covers, and reading lists API

**Existing pain:**
- "Goodreads is the worst app I use daily" is practically a meme among readers
- App crashes, slow loads, aggressive Amazon integration, heavy tracking
- StoryGraph exists as web alternative but its iOS experience is limited

**Feasibility:** Moderate. Social features (reviews, lists) add complexity, but a focused "personal library" app avoids that.
**Differentiation:** Fast, private reading tracker. No Amazon recommendations. Local-first data with optional sync.

---

#### 4. Drug & Food Safety (OpenFDA)
**API:** OpenFDA — free, no key required, FDA-maintained
**Why this is ripe:**
- Drug lookup apps (Drugs.com, WebMD, GoodRx) are extremely ad-heavy and collect sensitive health data
- Users searching drug interactions are in a vulnerable moment — ads and tracking feel especially exploitative
- Food recall data is useful but buried in government websites
- OpenFDA covers: drug labels, interactions, adverse events, food/device recalls

**Existing pain:**
- Health apps are among the worst privacy offenders on iOS
- Users avoid drug lookup apps specifically because of data collection fears
- No clean, trustworthy drug reference exists that doesn't monetise health queries

**Feasibility:** Moderate. Requires careful UX to present medical data responsibly (disclaimers, clarity). But the API is excellent.
**Differentiation:** Zero health data collection. No pharmacy upsells. Just clean drug info with a privacy promise users can trust.

---

#### 5. Air Quality (AirNow / OpenAQ)
**API:** EPA AirNow API (free key), OpenAQ (free, open)
**Why this is ripe:**
- Air quality awareness has surged (wildfires, urban pollution)
- Existing AQ apps request excessive permissions, run background tracking, serve ads
- IQAir, AirVisual etc. have been caught sharing location data
- Simple data that benefits from simple presentation

**Existing pain:**
- Apps request location even when user wants to check a specific city
- Background tracking and push notification spam
- Ad-supported models feel wrong for health/safety data

**Feasibility:** Low complexity. AQI is a single number + forecast. Map view is nice-to-have.
**Differentiation:** Check AQ without surrendering your location history. Widget support. No notifications unless you opt in.

---

### Tier 2 Opportunities (Strong but niche)

| # | Opportunity | API | Why it's underserved | Niche size |
|---|------------|-----|---------------------|------------|
| 6 | **Earthquake monitor** | USGS Earthquake API (free) | Existing apps are ad-heavy, permission-greedy | Seismically active regions |
| 7 | **Tide & marine conditions** | NOAA CO-OPS API (free) | Tide apps are ad-heavy, coastal users are passionate | Fishers, surfers, boaters |
| 8 | **Hacker News reader** | HN Firebase API (free) | Some good apps exist but most have ads or stale UX | Tech community |
| 9 | **NASA daily / Mars rover** | NASA Open APIs (free key) | Existing apps are mediocre, content is visually stunning | Space enthusiasts |
| 10 | **Satellite / ISS tracker** | Where the ISS At, N2YO (free) | Ad-heavy incumbents, fun visual app | Hobbyist / education |

---

## UK-Specific Opportunities

### Tier 1: Strong UK Opportunities

#### 1. Train Times & Live Departures
**APIs:** National Rail Darwin (real-time departures/arrivals), Network Rail Data Feeds (disruptions, timetables)
**Why this is ripe:**
- Trainline is the dominant app and it's aggressively commercial — upsells on every screen, pushing ticket purchases when you just want to check if your train is on time
- National Rail's own app is mediocre and slow
- Checking live departures is a daily use case for millions of commuters
- The existing apps all treat "check departure time" as a funnel into "buy a ticket"

**The gap:** No app just answers "is my train on time?" cleanly. Every existing app monetises the anxiety.

**Feasibility:** National Rail's Darwin API requires registration but is free for non-commercial use. Real-time push feeds available via OpenLDBWS.

#### 2. Food Hygiene Ratings (Scores on the Doors)
**API:** Food Standards Agency FHRS API — completely free, no key required, excellent documentation
**Why this is ripe:**
- "What's the hygiene rating of this restaurant?" — people check this constantly
- No good dedicated app exists. The FSA's own app was discontinued
- Data covers every food establishment in England, Wales, and Northern Ireland

**Feasibility:** Very low complexity. Could be a fully functional app in days.

#### 3. Flood Warnings & River Levels
**API:** Environment Agency Real Time Flood API — free, no key, real-time data
**Why this is ripe:**
- Real-time river levels, flood warnings, rainfall, and groundwater levels for thousands of monitoring stations
- Critical for people in flood-risk areas (5.2M properties in England)
- Existing apps are few and poor

#### 4. UK Air Quality (Defra AURN)
**API:** Defra UK-AIR / AURN API — free, UK monitoring stations

#### 5. Police Crime Data
**API:** Police UK API (data.police.uk) — free, no key, monthly crime data by location

### Tier 2: Solid UK Opportunities

| # | Opportunity | API |
|---|------------|-----|
| 6 | Companies House lookup | Companies House API (free key) |
| 7 | Parliament / MP tracker | Parliament API + TheyWorkForYou API |
| 8 | GP & pharmacy finder | NHS API (Organisation Data Service) |
| 9 | School ratings (Ofsted) | Ofsted data |
| 10 | UK tides | UKHO Admiralty API + EA coastal data |

---

## Assumption Map

| Assumption | Category | Risk | Certainty | Test |
|-----------|----------|------|-----------|------|
| Users will pay £2-4 for an ad-free book tracker | Desirability | High | Low | Landing page with payment intent button |
| Open Library data is complete enough for 90% of books | Feasibility | High | Low | API coverage test against real book lists |
| Goodreads CSV import works reliably | Feasibility | Medium | Low | Collect 5 real exports and test parsing |
| Users value "private & local" over "social & connected" | Desirability | High | Medium | Interview 10 privacy-conscious readers |
| Barcode scanning is fast enough to feel magical | Feasibility | Low | Medium | SwiftUI prototype with VisionKit |
| Single developer can maintain this long-term | Viability | Medium | Medium | Estimate API change frequency + support load |

---

## Recommended Starting Point

**Book Tracker (Open Shelf)** selected as first app to build. Reasons:
- Goodreads is universally hated but has no clean alternative
- Open Library API validated at 100% coverage (60/60 books found)
- Local-first architecture means zero server costs
- Clear monetisation: £2.99 upfront
- Validates the "clean UI over public API" thesis for future apps
