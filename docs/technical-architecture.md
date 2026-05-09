# Technical Architecture Plan: Open Shelf

A privacy-first, local-first personal book tracker for iOS.

---

## Design Principles

1. **Local-first** — all user data lives on-device in SwiftData. No server, no account.
2. **Network-lazy** — the API is only hit to find a book. Once added, the book is cached forever.
3. **Privacy by architecture** — no analytics SDK, no telemetry, no crash reporting that phones home. Can't leak what you don't collect.
4. **Native iOS** — SwiftUI, no cross-platform. Feels like an Apple app.

---

## Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| **UI** | SwiftUI | Modern, declarative, excellent for data-driven lists. iOS 17+ minimum. |
| **Persistence** | SwiftData | Apple's native ORM. Swift macros, CloudKit sync built in, no boilerplate. |
| **Sync** | CloudKit (via SwiftData) | Free, automatic, user's own iCloud. Zero infrastructure on our side. |
| **Networking** | URLSession + async/await | Stdlib. No Alamofire needed for simple JSON GET requests. |
| **Barcode scanning** | VisionKit (DataScannerViewController) | System framework, no third-party dependency. Camera → ISBN in one tap. |
| **Image caching** | SwiftUI AsyncImage + local file cache | Cache cover images to ~/Library/Caches/ after first fetch. |
| **Charts** | Swift Charts | Native framework, iOS 16+. Reading analytics. |
| **Search** | Combine debounce → Open Library API | Debounce 300ms, then hit /search.json. |
| **Import** | CSV parser (stdlib) | Parse Goodreads export CSV. No dependencies. |
| **Dependencies** | **Zero** | No SPM packages. Stdlib + Apple frameworks only. |

Zero third-party dependencies is a feature, not a constraint. It means no supply chain risk, no dependency rot, no bloat.

---

## Data Model (SwiftData)

```swift
@Model
class Book {
    // Identity
    var olWorkKey: String          // "/works/OL21745884W"
    var olEditionKey: String?      // "/books/OL..." (user's specific edition)
    var isbn13: String?
    var isbn10: String?
    var goodreadsID: String?       // For import matching

    // Metadata (cached from API, immutable after fetch)
    var title: String
    var authorName: String
    var coverImageID: Int?         // Open Library cover ID
    var coverCached: Bool          // Whether we've downloaded the cover locally
    var pageCount: Int?
    var firstPublishYear: Int?
    var synopsis: String?
    var subjects: [String]
    var publisher: String?
    var language: String?

    // User data (the valuable stuff — never leaves the device except via iCloud)
    var shelf: Shelf               // .wantToRead, .reading, .read, .dnf
    var userRating: Double?        // 0.5 to 5.0 in 0.5 increments
    var dateAdded: Date
    var dateStarted: Date?
    var dateFinished: Date?
    var currentPage: Int?          // Reading progress
    var isFavourite: Bool
    var notes: String?
    var tags: [String]             // User-created tags

    // Relationships
    @Relationship(deleteRule: .cascade)
    var reads: [ReadEntry]         // Re-read tracking
}

@Model
class ReadEntry {
    var book: Book?
    var startDate: Date?
    var finishDate: Date?
    var rating: Double?            // Per-read rating
    var notes: String?
    var dnfPage: Int?              // If abandoned, where
    var dnfReason: String?
}

enum Shelf: String, Codable, CaseIterable {
    case wantToRead
    case reading
    case read
    case dnf                       // Did Not Finish — first-class citizen
}

@Model
class UserTag {
    var name: String
    var colour: String             // Hex colour for visual grouping
    var sortOrder: Int
}
```

### Model Design Rationale
- `Book` stores cached API data + user data in one object. After the initial API fetch, the book is self-contained.
- `ReadEntry` is separate from `Book` so you can read The Great Gatsby three times with different dates, ratings, and notes each time.
- `Shelf` has `dnf` as a first-class enum case, not a hack.
- Tags are user-created, not predefined categories.

---

## API Layer

```swift
actor OpenLibraryClient {
    private let baseURL = "https://openlibrary.org"
    private let session: URLSession
    private let searchFields = "key,title,author_name,first_publish_year,number_of_pages_median,cover_i,edition_count,isbn,subject,id_goodreads"

    // Primary search — user types in search bar
    func search(query: String) async throws -> [SearchResult] {
        // GET /search.json?q={query}&fields={fields}&limit=20
    }

    // ISBN lookup — barcode scan result
    func lookupISBN(_ isbn: String) async throws -> Book? {
        // GET /isbn/{isbn}.json → edition → work
    }

    // Full detail — user taps a search result
    func fetchWorkDetail(key: String) async throws -> WorkDetail {
        // GET /works/{key}.json → description, full subjects
    }

    // Cover image URL construction (no API call needed)
    func coverURL(id: Int, size: CoverSize) -> URL {
        // https://covers.openlibrary.org/b/id/{id}-{L|M|S}.jpg
    }
}
```

Rate limit strategy: 3 req/sec is generous for our use case. A user searching for a book generates 1 search + 1 detail fetch. Barcode scan is a single request. No throttling logic needed.

---

## Project Structure

```
OpenShelf/
├── App/
│   ├── OpenShelfApp.swift           // @main, SwiftData container setup
│   └── ContentView.swift            // Tab bar root
│
├── Models/
│   ├── Book.swift                   // SwiftData @Model
│   ├── ReadEntry.swift
│   └── UserTag.swift
│
├── API/
│   ├── OpenLibraryClient.swift      // Actor, async/await
│   ├── SearchResult.swift           // Codable DTO
│   └── WorkDetail.swift             // Codable DTO
│
├── Features/
│   ├── Library/
│   │   ├── LibraryView.swift        // Main shelf view with filter tabs
│   │   ├── BookRow.swift            // List row component
│   │   └── ShelfFilter.swift        // Shelf picker
│   │
│   ├── BookDetail/
│   │   ├── BookDetailView.swift     // Full book view
│   │   ├── RatingView.swift         // Half-star rating picker
│   │   ├── ReadHistorySection.swift // Re-reads list
│   │   └── NotesEditor.swift        // Reading journal
│   │
│   ├── Search/
│   │   ├── SearchView.swift         // Search + results
│   │   ├── BarcodeScannerView.swift // VisionKit camera
│   │   └── SearchResultRow.swift
│   │
│   ├── Stats/
│   │   ├── StatsView.swift          // Reading analytics dashboard
│   │   ├── BooksPerMonthChart.swift
│   │   ├── GenreBreakdownChart.swift
│   │   └── PaceChart.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       ├── GoodreadsImporter.swift  // CSV parser
│       └── ExportView.swift         // Export your own data
│
├── Components/
│   ├── CoverImage.swift             // Async image + local cache + placeholder
│   ├── HalfStarRating.swift         // Tap/drag 0.5-5.0 rating
│   └── ShelfPicker.swift            // Quick shelf assignment
│
├── Cache/
│   └── CoverImageCache.swift        // File-based cover image cache
│
└── Widgets/
    ├── CurrentlyReadingWidget.swift  // Lock screen / home screen
    └── ReadingGoalWidget.swift       // Annual goal progress
```

---

## Key User Flows

### Flow 1: Add a Book (Barcode — the magic moment)

```
[Library tab] → tap "+" → [Camera opens]
    → Point at barcode → ISBN detected instantly
    → /isbn/{isbn}.json → match found
    → [Book confirmation sheet slides up]
        Title, cover, author, page count pre-filled
        Shelf picker: Want to Read | Reading | Read
        → Tap "Add" → book saved to SwiftData
        → Cover image cached in background
    → Back to library. Book appears. < 3 seconds total.
```

### Flow 2: Add a Book (Search)

```
[Library tab] → tap "+" → [Search bar]
    → Type "project hail" → 300ms debounce → API search
    → Results list with covers
    → Tap result → /works/{key}.json for synopsis
    → [Book detail sheet]
        → "Add to Shelf" → shelf picker → saved
```

### Flow 3: Track Reading Progress

```
[Library tab] → tap book with shelf=.reading
    → [Book Detail]
        → "Update Progress" → page number input or % slider
        → Progress bar updates
        → If page == pageCount → prompt "Finished?"
            → Yes → move to .read, set dateFinished, prompt for rating
```

### Flow 4: Goodreads Import

```
[Settings] → "Import from Goodreads"
    → Instructions: "Go to goodreads.com/review/import → Export"
    → "Select CSV file" → document picker
    → Parse CSV: title, author, ISBN, rating, date_read, shelves
    → For each row:
        → Match by ISBN (fastest) or title+author via API
        → Create Book with user's Goodreads rating, shelf, dates
    → Progress bar → "Imported 247 of 253 books (6 not found)"
    → Show unmatched books for manual resolution
```

### Flow 5: Reading Stats

```
[Stats tab]
    → Books read this year: 23 (goal: 40)
    → Pages read: 7,842
    → Books per month bar chart (Swift Charts)
    → Genre breakdown pie chart
    → Average rating: 3.8
    → Longest book: Demon Copperhead (560pp)
    → Fastest read: The Midnight Library (3 days)
    → DNF rate: 12%
    → Reading streak: 14 days
```

---

## CloudKit Sync Strategy

SwiftData + CloudKit gives us free cross-device sync with zero server code:

```swift
@main
struct OpenShelfApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Book.self, ReadEntry.self, UserTag.self],
                        isAutosaveEnabled: true,
                        isUndoEnabled: true)
        // CloudKit sync is automatic when user is signed into iCloud
    }
}
```

- **What syncs:** All user data — books, ratings, notes, shelves, tags, read history.
- **What doesn't sync:** Cover image cache (re-fetched per device, small bandwidth cost).
- **Conflict resolution:** SwiftData's default last-writer-wins. For a single-user app, conflicts are effectively impossible.

---

## Widgets

| Widget | Size | Content |
|--------|------|---------|
| **Currently Reading** | Small / Medium | Cover image + title + progress % |
| **Reading Goal** | Small | "23 of 40 books" circular progress |
| **Recent Reads** | Medium / Large | Last 3-4 finished books with covers |

Widgets use SwiftData queries via `@Query` in the widget timeline provider. No network calls — purely local data.

---

## Build Phases

### Phase 1: Core (2 weeks)
Ship a working app with the core loop.

- SwiftData models (Book, ReadEntry, Shelf)
- Open Library search + results display
- Book detail view with synopsis
- Add to shelf (want to read / reading / read / DNF)
- Library view with shelf tabs
- Cover image loading + caching
- Half-star rating component
- Basic reading progress tracking

**Ship gate:** Can search, add, shelve, rate, and track a book.

### Phase 2: Delight (1 week)
The features that make people love it.

- Barcode scanning (VisionKit)
- Reading notes / journal per book
- Re-read tracking (ReadEntry model)
- Goodreads CSV import
- Tags (user-created)
- Currently Reading widget

### Phase 3: Analytics (1 week)
The features that make people stay.

- Stats dashboard
- Books per month/year charts (Swift Charts)
- Genre breakdown
- Reading pace analysis
- Annual reading goal + progress
- Reading Goal widget

### Phase 4: Polish (1 week)
Ready for App Store.

- CloudKit sync (SwiftData container config)
- Data export (JSON/CSV — own your data)
- Onboarding flow
- App Store screenshots + description
- Privacy nutrition label (all zeros)
- Accessibility audit (VoiceOver, Dynamic Type)

**Total: ~5 weeks from zero to App Store submission.**

---

## App Store Positioning

**Price:** £2.99 (one-time purchase)

**Privacy Nutrition Label:**
```
Data Not Collected
This app does not collect any data.
```

**Subtitle:** "Track your reading. Privately."

**Keywords:** book tracker, reading log, goodreads alternative, no ads, private, reading list, book journal, DNF tracker

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Open Library API goes down temporarily | Medium | Medium | All data cached locally. App works fully offline. Show "search unavailable" |
| Open Library changes API schema | Low | Medium | Abstraction layer (DTOs separate from SwiftData models). Easy to update mapping |
| Open Library rate-limits us specifically | Very Low | High | Well within limits. Fall back to Google Books API (1,000 free/day) |
| Apple rejects the app | Low | High | No content concerns. No web scraping. Clean privacy story. |
| Users expect social features | Medium | Low | Out of scope by design. Marketing leads with "personal" not "social" |
| Cover images unavailable for some books | Low | Low | Genre-coloured placeholder with title text. User can photograph their copy |

---

## What We Deliberately Don't Build

| Feature | Why not |
|---------|---------|
| User accounts / server | Complexity, cost, privacy risk. iCloud handles sync. |
| Social feed / followers | Network effect trap. Goodreads wins that fight. |
| Book reviews visible to others | Privacy-first means your opinions stay yours. |
| Recommendation engine | Algorithmic recommendations push towards engagement, not reading. |
| In-app book purchasing | No affiliate links, no Amazon integration. |
| Analytics/telemetry SDK | Can't leak data we don't collect. TestFlight feedback is enough. |
