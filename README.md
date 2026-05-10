# Open Shelf

A privacy-first book tracking app for iOS. Your books, on your device.

Open Shelf is a native iOS app that helps you track your reading life without the bloat, ads, or data harvesting of mainstream alternatives. Built entirely with SwiftUI, SwiftData, and Apple frameworks — zero third-party dependencies.

## Why Open Shelf?

### The Problem with Goodreads

Goodreads was acquired by Amazon in 2013 and has been functionally abandoned since. Amazon treats it as a data-collection funnel to sell books, not a product worth investing in. A decade of user frustration with no meaningful improvements.

### Pain Points We're Solving

#### UX Friction

| # | Pain Point | Severity |
|---|-----------|----------|
| 1 | **Five taps to add a book to a shelf** — the most common action is buried in UI layers | Critical |
| 2 | **No half-star ratings** — the #1 most-requested feature, still only whole stars (1-5) | Critical |
| 3 | **Dated, sluggish interface** — feels like a 2014 web app wrapped in a native shell | High |
| 4 | **Batch shelf management is painful** — reorganising books requires individual taps per book | High |

#### Missing Features

| # | Pain Point | Severity |
|---|-----------|----------|
| 5 | **No "Did Not Finish" (DNF) status** — no first-class way to track abandoned books | High |
| 6 | **No re-read tracking** — can't log a second read with its own date, rating, and notes | High |
| 7 | **No content/trigger warnings** — readers can't warn each other about sensitive content | Medium |
| 8 | **Weak reading analytics** — no mood charts, pace tracking, genre breakdowns | Medium |

#### Trust & Privacy

| # | Pain Point | Severity |
|---|-----------|----------|
| 9 | **Amazon data harvesting** — reading behaviour feeds Amazon's commercial ecosystem | High |
| 10 | **Review manipulation & spam** — ratings on unreleased books, review bombing, fake reviews | High |

### How Open Shelf Addresses Each

| Pain Point | Open Shelf Solution |
|-----------|-------------------|
| 5 taps to add | **1 tap** via barcode scan, or search -> tap -> add |
| No half-star ratings | **Half-star ratings** (0.5 to 5.0 in 0.5 increments) |
| Dated interface | **Native SwiftUI** — fast, modern, feels like an Apple app |
| Painful shelf management | **Quick shelf picker** on every book row + batch operations |
| No DNF status | **DNF is a first-class shelf** with optional page number and reason |
| No re-read tracking | **ReadEntry model** — each read gets its own date, rating, and notes |
| No content warnings | **User-created tags** that can serve as content warnings |
| Weak analytics | **Swift Charts dashboard** — books/month, genre breakdown, pace, streaks |
| Amazon tracking | **Zero tracking** — no analytics SDK, no telemetry, no account required |
| Review spam | **No public reviews** — your ratings and notes are yours alone |

## Competitive Landscape

| App | Strengths | Weaknesses |
|-----|-----------|------------|
| **Goodreads** | Massive community, network effects | Stagnant, Amazon-owned, bloated, tracking |
| **StoryGraph** | Best analytics, mood discovery, quarter-star ratings | Smaller community, some features paywalled |
| **Hardcover** | Half-star, DNF, actively developed, indie | Small user base, still maturing |
| **Literal** | Clean UI, annotations, book clubs | Smallest community, limited analytics |
| **BookWyrm** | Open-source, federated, anti-corporate | No iOS app, confusing for non-technical users |

### Our Angle

Every alternative fights for "community" — the dimension Goodreads wins by inertia. We fight on **personal utility**: the best private reading companion for the individual reader. No account, no server, no social feed. Just your books, on your device.

## Tech Stack

- **UI**: SwiftUI (iOS 26+)
- **Persistence**: SwiftData + CloudKit sync
- **API**: Open Library (free, open, community-maintained)
- **Analytics**: Swift Charts
- **Dependencies**: Zero — Apple frameworks only

## Evidence Sources

- App Store reviews for Goodreads iOS app (~720K ratings, recurring complaints on UX friction)
- StoryGraph, Hardcover, Literal, BookWyrm feature comparison
- Reddit/community sentiment analysis
- Open Library API coverage test: 60/60 books found (100%), 59/60 with covers (98%)
