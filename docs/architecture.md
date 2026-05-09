# Architecture Design: Open Shelf

> A privacy-first, local-first personal book tracker for iOS 26+.

---

## Architecture Decision Records

### ADR-001: iOS 26+ minimum, zero third-party dependencies

**Context:** We're building a native iOS app that should feel like an Apple app, last for years without maintenance burden, and have zero supply chain risk.

**Decision:**
- Deployment target: iOS 26.0
- Swift 6 with strict concurrency checking
- SwiftUI for all UI
- Zero SPM/CocoaPods/Carthage dependencies
- Apple frameworks only: SwiftData, SwiftUI, Swift Charts, VisionKit, WidgetKit, CloudKit

**Rationale:** Zero dependencies means no version conflicts, no security advisories from transitive deps, no abandoned packages, no build time overhead. Every framework we use ships with the OS and is maintained by Apple. The app's binary stays small.

**Trade-offs accepted:** We write our own CSV parser, image cache, and HTTP layer. These are trivial for our use case (simple GET requests, basic CSV, file-system image cache).

---

### ADR-002: Local-first with SwiftData

**Context:** Privacy is the core value proposition. User data must never leave the device unless the user explicitly opts in (iCloud sync).

**Decision:**
- All user data stored in SwiftData (on-device SQLite)
- API metadata cached in SwiftData alongside user data
- CloudKit sync via SwiftData's built-in integration (opt-in, uses user's own iCloud)
- No server, no backend, no database we operate

**Rationale:** Local-first means the app works offline, launches instantly, and we literally cannot access user data. This is privacy by architecture, not by policy.

**Consequences:**
- No server costs. Ever.
- No user accounts to manage.
- No GDPR data requests to handle (we don't have the data).
- Cross-device sync limited to iCloud (no Android, no web).

---

### ADR-003: Actor-based API client

**Context:** Network calls must be thread-safe. Swift 6 strict concurrency makes this non-optional.

**Decision:** Open Library API client is a Swift `actor` using `URLSession` + `async/await`.

**Rationale:** Actors provide compile-time data race safety. `async/await` is the modern Swift networking pattern — no callback pyramids, no Combine publishers for simple request/response. Task cancellation is built in (critical for debounced search).

---

### ADR-004: Feature-based module structure

**Context:** The app has clear feature boundaries (Library, Search, Detail, Stats, Settings). Code should be organised by feature, not by layer.

**Decision:** Feature-based structure where each feature owns its views, and shared components are extracted to `Components/`.

**Rationale:** Feature folders are self-contained — when working on Search, everything you need is in `Features/Search/`. Contrast with layer-based (all views in `Views/`, all models in `Models/`) where related code is scattered.

---

### ADR-005: Repository pattern for data access

**Context:** Views shouldn't directly manage `ModelContext` operations or API calls. We need a single abstraction for "get/save books".

**Decision:** `BookRepository` as an `@Observable` class injected via SwiftUI environment. It wraps SwiftData operations and the API client.

**Rationale:** Keeps views declarative (they call repository methods, not raw SwiftData). Makes previews and testing possible (can stub the repository). Single point of coordination between local and remote data.

---

### ADR-006: Caching strategy

**Context:** The Open Library API is rate-limited (3 req/sec) and should only be hit to find new books. Once a book is in the library, it should never need the network again.

**Decision:** Three-layer caching:

| Layer | What | Where | Lifetime |
|-------|------|-------|----------|
| **SwiftData** | Book metadata (title, author, subjects, synopsis, ISBNs) | App's SQLite database | Permanent (until user deletes book) |
| **File cache** | Cover images | `~/Library/Caches/Covers/` | Persistent but system-purgeable under storage pressure |
| **In-memory** | Search results during active session | `OpenLibraryClient` actor state | Session-scoped, cleared on app terminate |

**API call lifecycle:**
1. User searches → API call → results held in memory
2. User adds book → metadata saved to SwiftData → cover fetched and cached to disk
3. User opens book later → everything served from SwiftData + file cache → zero network

**Consequence:** After the initial book add, the app is fully offline for that book. A user with 200 books and spotty internet sees zero loading spinners in their library.

---

## System Architecture

```
┌─────────────────────────────────────────────┐
│                  SwiftUI Views               │
│  ┌──────────┐ ┌────────┐ ┌──────┐ ┌───────┐ │
│  │ Library  │ │ Search │ │Detail│ │ Stats │ │
│  └────┬─────┘ └───┬────┘ └──┬───┘ └───┬───┘ │
│       │           │         │         │      │
│  ┌────▼───────────▼─────────▼─────────▼────┐ │
│  │          BookRepository (@Observable)    │ │
│  └────┬──────────────────────────┬─────────┘ │
│       │                          │           │
│  ┌────▼──────────┐    ┌─────────▼─────────┐ │
│  │  SwiftData    │    │ OpenLibraryClient  │ │
│  │  ModelContext  │    │     (actor)        │ │
│  └────┬──────────┘    └─────────┬─────────┘ │
│       │                         │            │
│  ┌────▼──────────┐    ┌────────▼──────────┐ │
│  │ SQLite (local) │    │  URLSession       │ │
│  └───────────────┘    │  → openlibrary.org │ │
│                        └───────────────────┘ │
│  ┌─────────────────┐                        │
│  │ CoverImageCache │ → ~/Library/Caches/    │
│  │    (actor)      │                        │
│  └─────────────────┘                        │
│                                             │
│  ┌─────────────────┐                        │
│  │ CloudKit (opt-in)│ → User's iCloud       │
│  └─────────────────┘                        │
└─────────────────────────────────────────────┘
```

---

## Data Flow

### Search → Add Book

```
SearchView
  │ user types "project hail mary"
  │ 300ms debounce (Task.sleep + cancellation)
  ▼
BookRepository.search(query:)
  │
  ▼
OpenLibraryClient.search(query:)
  │ GET /search.json?q=project+hail+mary&fields=...&limit=20
  ▼
[SearchResult] returned to view
  │ user taps result
  ▼
BookRepository.fetchDetail(for:)
  │ GET /works/OL21745884W.json
  ▼
WorkDetail (synopsis, full subjects) shown in sheet
  │ user taps "Add to Want to Read"
  ▼
BookRepository.addBook(from: searchResult, detail: workDetail, shelf: .wantToRead)
  │ 1. Create Book @Model from DTO
  │ 2. Insert into ModelContext
  │ 3. ModelContext.save()
  │ 4. Task { coverImageCache.prefetch(coverID) }
  ▼
LibraryView updates via @Query
```

### Barcode Scan → Add Book

```
BarcodeScannerView (DataScannerViewController)
  │ camera detects EAN-13 barcode
  │ extract ISBN: "9780593135204"
  ▼
BookRepository.lookupISBN("9780593135204")
  │ GET /isbn/9780593135204.json
  ▼
EditionDetail → extract work key → GET /works/{key}.json
  ▼
Confirmation sheet → shelf picker → save (same as search flow)
```

---

## Project Structure

```
OpenShelf/
├── OpenShelfApp.swift              # @main, ModelContainer, environment injection
│
├── Models/
│   ├── Book.swift                  # @Model — core entity
│   ├── ReadEntry.swift             # @Model — per-read tracking
│   ├── UserTag.swift               # @Model — user-created tags
│   └── Shelf.swift                 # Enum: wantToRead, reading, read, dnf
│
├── Services/
│   ├── BookRepository.swift        # @Observable — data access facade
│   ├── OpenLibraryClient.swift     # Actor — API calls
│   ├── CoverImageCache.swift       # Actor — file-based image cache
│   ├── GoodreadsImporter.swift     # CSV parser for Goodreads export
│   └── DTOs/
│       ├── SearchResponse.swift    # Codable API response types
│       ├── WorkDetail.swift
│       └── EditionDetail.swift
│
├── Features/
│   ├── Library/
│   │   ├── LibraryView.swift       # Main shelf view with tab filtering
│   │   ├── BookRow.swift           # List row: cover + title + rating
│   │   └── ShelfFilter.swift       # Shelf segmented control
│   │
│   ├── Search/
│   │   ├── SearchView.swift        # Debounced search + results
│   │   ├── SearchResultRow.swift   # Result row component
│   │   └── BarcodeScannerView.swift # VisionKit camera wrapper
│   │
│   ├── BookDetail/
│   │   ├── BookDetailView.swift    # Full book view
│   │   ├── ReadHistorySection.swift # Re-reads list
│   │   ├── ProgressEditor.swift    # Page input + progress bar
│   │   └── NotesEditor.swift       # Reading journal
│   │
│   ├── Stats/
│   │   ├── StatsView.swift         # Analytics dashboard
│   │   ├── BooksPerMonthChart.swift
│   │   ├── GenreBreakdownChart.swift
│   │   └── ReadingGoalView.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       ├── ImportView.swift        # Goodreads import flow
│       ├── ExportView.swift        # Data export
│       └── OnboardingView.swift    # First-launch experience
│
├── Components/
│   ├── CoverImage.swift            # Async image + cache + placeholder
│   ├── HalfStarRating.swift        # 0.5-5.0 interactive rating
│   ├── ShelfPicker.swift           # Shelf selection control
│   └── EmptyStateView.swift        # Reusable empty state
│
└── Widgets/
    ├── OpenShelfWidgetBundle.swift
    ├── CurrentlyReadingWidget.swift
    └── ReadingGoalWidget.swift
```

---

## Privacy Architecture

### Data classification

| Data type | Storage | Leaves device? | We can access? |
|-----------|---------|----------------|---------------|
| Books, ratings, notes, shelves | SwiftData (SQLite) | Only via iCloud (user's container) | No |
| Cover images | File cache | No | No |
| Reading goal | UserDefaults | Via iCloud KV sync (user's account) | No |
| Search queries | In-memory only | Sent to openlibrary.org | No (we don't run OL) |
| Camera feed (barcode) | Never stored | No | No |

### What we send to Open Library
- HTTP GET requests with search terms
- User-Agent header: `OpenShelf/1.0 (contact@openshelf.app)`
- No cookies, no auth tokens, no user identifiers

### What we never do
- No analytics SDK (no Firebase, no Mixpanel, no Amplitude)
- No crash reporting that phones home (no Sentry, no Crashlytics)
- No advertising identifiers
- No device fingerprinting
- No background network activity
- No location access
- No contacts access
- No tracking across apps

### App Store privacy label
```
Data Not Collected
This app does not collect any data.
```

---

## Error Handling Strategy

### Network errors
- Transient (timeout, no connection): show inline "Search unavailable" with retry
- 404 (book not found): "Book not found — try a different search"
- Rate limited (429): back off 2 seconds, retry once, then show error
- All errors are user-facing messages, never raw HTTP codes or stack traces

### Data errors
- SwiftData save failure: retry once, log to console (debug only)
- Corrupt cover image: delete cached file, re-fetch on next display
- Malformed API response: skip the result, show remaining results

### Import errors
- Invalid CSV: "This doesn't look like a Goodreads export"
- Unmatched books: save matched books, show unmatched for manual resolution
- Never fail the entire import due to individual book failures

### Principle: degrade gracefully, never crash
- The app must always launch, even with empty/corrupt data
- Offline mode is the default — network is a bonus, not a requirement

---

## Performance Targets

| Metric | Target |
|--------|--------|
| App launch to library visible | < 200ms |
| Search results appear | < 500ms (300ms debounce + 200ms API) |
| Add book to library | < 100ms (SwiftData insert) |
| Stats dashboard load (500 books) | < 100ms |
| Barcode → book identified | < 1 second |
| Goodreads import (250 books) | < 3 minutes |
| Memory usage (idle) | < 50MB |
| App binary size | < 10MB |

---

## Testing Strategy

### Unit tests
- `OpenLibraryClient`: mock URLSession, verify request construction and DTO parsing
- `BookRepository`: mock ModelContext, verify CRUD operations
- `GoodreadsImporter`: test CSV parsing with real export samples
- `CoverImageCache`: test cache hit/miss/clear with temp directory
- Genre mapping logic: subject strings → display genres

### UI tests
- Search → add book → appears in library
- Shelf change via swipe
- Rating interaction (half-star)
- Barcode scan flow (limited — requires camera)

### Preview-driven development
- Every view has a SwiftUI preview with sample data
- Previews use a stubbed repository with in-memory SwiftData container
- This is the primary development feedback loop — previews over simulator

---

## Milestones

| Milestone | Issues | Focus |
|-----------|--------|-------|
| [M1: Foundation & Data Layer](https://github.com/jonnydford/open-shelf/milestone/1) | 5 | Project setup, models, API client, cache, repository |
| [M2: Core Library Experience](https://github.com/jonnydford/open-shelf/milestone/2) | 5 | Library view, search, add flow, book rows, shelf management |
| [M3: Book Detail & Reading Tracking](https://github.com/jonnydford/open-shelf/milestone/3) | 6 | Detail view, ratings, progress, notes, re-reads, DNF |
| [M4: Import & Quick Add](https://github.com/jonnydford/open-shelf/milestone/4) | 3 | Barcode scanner, Goodreads import, manual entry |
| [M5: Analytics & Goals](https://github.com/jonnydford/open-shelf/milestone/5) | 4 | Stats dashboard, charts, reading goal |
| [M6: Polish & Ship](https://github.com/jonnydford/open-shelf/milestone/6) | 7 | Widgets, CloudKit, export, onboarding, a11y, App Store |
| [M7: Social Features (Future)](https://github.com/jonnydford/open-shelf/milestone/7) | 4 | Share cards, lists, recommendations, activity |
| **Total** | **34** | |
