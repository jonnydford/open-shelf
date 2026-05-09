# Why Goodreads Is Hated — And Where The Opportunity Is

## The Core Problem: Amazon Killed It

Goodreads was acquired by Amazon in 2013 and has been functionally abandoned since. Amazon treats it as a data-collection funnel to sell books on Amazon, not as a product worth investing in. The result: a decade of user frustration with no meaningful improvements.

---

## The 10 Pain Points (Ranked by Severity)

### UX Friction

| # | Pain Point | Severity | Goodreads Status |
|---|-----------|----------|-----------------|
| 1 | **Five taps to add a book to a shelf** — the single most common action is buried in UI layers | Critical | Unfixed for years |
| 2 | **No half-star ratings** — the #1 most-requested feature, still only whole stars (1-5) | Critical | Refused to implement |
| 3 | **Dated, sluggish interface** — feels like a 2014 web app wrapped in a native shell | High | No redesign planned |
| 4 | **Batch shelf management is painful** — reorganising books requires individual taps per book | High | Never addressed |

### Missing Features

| # | Pain Point | Severity | Goodreads Status |
|---|-----------|----------|-----------------|
| 5 | **No "Did Not Finish" (DNF) status** — no first-class way to track abandoned books | High | Not implemented |
| 6 | **No re-read tracking** — can't log a second read with its own date, rating, and notes | High | Not implemented |
| 7 | **No content/trigger warnings** — readers can't warn each other about sensitive content | Medium | Not implemented |
| 8 | **Weak reading analytics** — no mood charts, pace tracking, genre breakdowns | Medium | Minimal stats only |

### Trust & Privacy

| # | Pain Point | Severity | Goodreads Status |
|---|-----------|----------|-----------------|
| 9 | **Amazon data harvesting** — reading behaviour feeds Amazon's commercial ecosystem | High | By design |
| 10 | **Review manipulation & spam** — ratings on unreleased books, review bombing, fake reviews | High | Poorly moderated |

---

## The Competitive Landscape

| App | Strengths | Weaknesses |
|-----|-----------|------------|
| **StoryGraph** | Best analytics, mood-based discovery, quarter-star ratings, "Amazon-free" | Smaller community, some features paywalled, book database gaps for niche/international titles |
| **Hardcover** | Half-star ratings, DNF, per-book privacy, actively developed, indie | Small user base, still maturing |
| **Literal** | Clean modern UI, annotations, book clubs | Smallest community, limited discovery/analytics |
| **BookWyrm** | Open-source, federated (ActivityPub), anti-corporate | No native iOS app, confusing for non-technical users, requires choosing an instance |

**Key insight:** Every alternative is trying to be a social network first. They're all fighting for the "community" angle that Goodreads has locked up via network effects. That's the wrong fight.

---

## Where We Win: The Anti-Social Book App

Instead of competing on community (where Goodreads wins by sheer inertia), build a personal reading companion — a private, local-first tool that's exceptional for the individual reader.

### Value Proposition
> "Your reading life, on your device. No account required. No tracking. No Amazon."

### What We Build (and What We Don't)

**Build — Personal tools that Goodreads neglects:**
- One-tap book add via barcode scan or search
- Half/quarter-star ratings
- DNF tracking as a first-class status with optional "stopped at page X" and reason
- Re-read logging — each read gets its own date, rating, and notes
- Rich reading analytics — books/month, pages/year, genre breakdown, pace, mood trends
- Reading journal — private notes and highlights tied to each book
- Content warnings via community tags
- Series tracking — progress through a series, next-in-series prompts
- Smart shelves — auto-shelves based on rules

**Don't build — Avoid the social trap:**
- No social feed, no followers, no activity stream
- No reviews visible to others
- No recommendation algorithm pushing purchases
- No account required — all data lives on-device, synced via iCloud

### Comparison

| Dimension | Goodreads | StoryGraph | Open Shelf |
|-----------|-----------|------------|------------|
| Speed | Slow | Moderate | Instant (local-first) |
| Privacy | Amazon tracking | Independent but account-required | Zero tracking, no account |
| Add a book | 5 taps | 3 taps | 1 tap (barcode) |
| Half-star ratings | No | Yes | Yes |
| DNF tracking | No | Yes | Yes |
| Re-read logging | No | Limited | Full |
| Offline use | No | No | Full (local-first) |
| Analytics | Minimal | Excellent | Excellent |
| Data ownership | Amazon's | Their servers | Your device + iCloud |
| Business model | Your data is the product | Freemium | Paid upfront (£2.99) |
