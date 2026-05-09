# Open Library API Coverage Test Results

Test date: 2026-05-06

## Methodology

Tested 60 books across 5 categories against the Open Library search API. Books selected to represent the full range a typical reader would track: recent bestsellers, UK popular fiction, niche literary titles, non-fiction, and classics.

---

## Book Discovery: 100% Hit Rate (with correct search approach)

| Category | Found | With Cover | Notes |
|----------|-------|------------|-------|
| **NYT Bestsellers / Popular Fiction** | 20/20 (100%) | 20/20 | 2 initially timed out, succeeded on retry |
| **UK Popular (Waterstones)** | 10/10 (100%) | 10/10 | "The Salt Path" found via `q` param, not `title` param |
| **Niche / Literary / Indie** | 10/10 (100%) | 10/10 | Even Booker winners like Prophet Song and Orbital present |
| **Non-Fiction** | 10/10 (100%) | 10/10 | Solid |
| **Classics** | 10/10 (100%) | 9/10 | One Hundred Years of Solitude missing cover |
| **TOTAL** | **60/60 (100%)** | **59/60 (98%)** | |

---

## Critical Finding: Extended Fields Must Be Requested

The search API returns minimal data by default. Pass the `fields` parameter to get full metadata:

```
fields=key,title,author_name,first_publish_year,number_of_pages_median,cover_i,edition_count,isbn,subject,ratings_average,ratings_count,readinglog_count,want_to_read_count,currently_reading_count,already_read_count,id_goodreads,id_amazon,id_wikidata,first_sentence
```

### Fields Available With Extended Request

| Field | Available? | Example (Project Hail Mary) |
|-------|-----------|---------------------------|
| Title, author, year | Yes | "Project Hail Mary", Andy Weir, 2021 |
| Cover image ID | Yes (98%) | `11200092` |
| ISBNs | Yes | Hundreds across editions |
| Page count (median) | Yes | 496 |
| Subjects/genres | Yes | "hard science-fiction", "sci-fi" |
| Languages | Yes | 8 languages |
| Edition count | Yes | 28 editions |
| Description | Yes (via /works endpoint) | Full synopsis |
| Goodreads IDs | Yes | `58033783` — enables import |
| Ratings | Yes, but thin | 157 ratings, 4.48 avg |
| Reading log counts | Yes | 1,043 total, 773 want-to-read |

---

## ISBN Barcode Lookup

Direct ISBN lookup via `/isbn/{isbn}.json` works perfectly:

```
GET https://openlibrary.org/isbn/9780593135204.json

Returns:
  Title: Project Hail Mary
  Publishers: Ballantine Books
  Pages: 496
  Covers: [12455001, 12455000, 10415294]
  Works key: /works/OL21745884W
```

Fast, reliable, returns everything needed for one-tap book add via barcode scan.

---

## API Endpoints Summary

| Endpoint | Purpose | Rate Limit |
|----------|---------|-----------|
| `GET /search.json?q={query}&fields={fields}` | Full-text search | 3 req/sec (with User-Agent) |
| `GET /isbn/{isbn}.json` | ISBN lookup (barcode scan) | 3 req/sec |
| `GET /works/{key}.json` | Work detail (description, subjects) | 3 req/sec |
| `GET /works/{key}/editions.json` | Edition list (ISBNs, publishers) | 3 req/sec |
| `GET /works/{key}/ratings.json` | Rating breakdown | 3 req/sec |
| `GET covers.openlibrary.org/b/id/{id}-{S|M|L}.jpg` | Cover images | 100 per IP per 5 min |

---

## Data Quality Issues to Design Around

| Issue | Impact | Mitigation |
|-------|--------|-----------|
| Title search sometimes misses books | Medium | Use `q` (full-text) as primary, `title` as refinement |
| Ratings are thin (157 for a massive bestseller) | Low | Don't surface OL ratings — this is a personal tracker |
| Cover gaps on some titles (2%) | Low | Genre-coloured placeholder; user can photograph their copy |
| Duplicate/split editions | Medium | Group by work ID, present best match first |
| Rate limit: 3 req/sec | Medium | Cache aggressively in SwiftData; after add, no re-fetch needed |
| Page counts missing on some editions | Low | Use `number_of_pages_median` from search |

---

## Strategic Assessment

**The API is a GO.** 100% book coverage across all categories tested. The key architecture insight: don't try to replace Goodreads' social/ratings data — replace Goodreads' job as a personal reading tool. Open Library provides everything needed for finding and identifying books. User data (shelves, ratings, notes, progress) is stored locally.

### Recommended Search Strategy

```
User types query
  → Debounce 300ms
  → GET /search.json?q={query}&fields={extended}&limit=20
  → Display results with covers

User taps result
  → GET /works/{key}.json for description
  → Show detail sheet with "Add to Shelf" button

User scans barcode
  → GET /isbn/{isbn}.json → instant match
  → Show confirmation sheet → one-tap add
```

After initial lookup, the app is fully offline. The API is only needed for finding new books.

---

## Books Tested

### NYT Bestsellers / Popular Fiction (20)
- Intermezzo (Sally Rooney) ✓
- The Women (Kristin Hannah) ✓
- Iron Flame (Rebecca Yarros) ✓
- Fourth Wing (Rebecca Yarros) ✓
- A Court of Thorns and Roses (Sarah J. Maas) ✓
- Atomic Habits (James Clear) ✓
- The Housemaid (Freida McFadden) ✓
- It Ends with Us (Colleen Hoover) ✓
- Holly (Stephen King) ✓
- Tomorrow and Tomorrow and Tomorrow (Gabrielle Zevin) ✓
- Lessons in Chemistry (Bonnie Garmus) ✓
- The Thursday Murder Club (Richard Osman) ✓
- Hamnet (Maggie O'Farrell) ✓
- Shuggie Bain (Douglas Stuart) ✓
- The Midnight Library (Matt Haig) ✓
- Project Hail Mary (Andy Weir) ✓
- Klara and the Sun (Kazuo Ishiguro) ✓
- The Maid (Nita Prose) ✓
- Demon Copperhead (Barbara Kingsolver) ✓
- The Covenant of Water (Abraham Verghese) ✓

### UK Popular / Waterstones (10)
- Small Things Like These (Claire Keegan) ✓
- The Salt Path (Raynor Winn) ✓ (via `q` param)
- Normal People (Sally Rooney) ✓
- Girl Woman Other (Bernardine Evaristo) ✓
- Piranesi (Susanna Clarke) ✓
- A Gentleman in Moscow (Amor Towles) ✓
- The Seven Husbands of Evelyn Hugo (Taylor Jenkins Reid) ✓
- Circe (Madeline Miller) ✓
- Where the Crawdads Sing (Delia Owens) ✓
- The Tattooist of Auschwitz (Heather Morris) ✓

### Niche / Literary / Indie (10)
- Pigeon English (Stephen Kelman) ✓
- The Bees (Laline Paull) ✓
- Sorrow and Bliss (Meg Mason) ✓
- The Wren the Wren (Anne Enright) ✓
- Prophet Song (Paul Lynch) ✓
- Orbital (Samantha Harvey) ✓
- James (Percival Everett) ✓
- The Trees (Percival Everett) ✓
- My Year of Rest and Relaxation (Ottessa Moshfegh) ✓
- Yellowface (R.F. Kuang) ✓

### Non-Fiction (10)
- Sapiens (Yuval Noah Harari) ✓
- Educated (Tara Westover) ✓
- Why We Sleep (Matthew Walker) ✓
- The Body (Bill Bryson) ✓
- Invisible Women (Caroline Criado Perez) ✓
- Empire of Pain (Patrick Radden Keefe) ✓
- Breath (James Nestor) ✓
- Four Thousand Weeks (Oliver Burkeman) ✓
- Ultra-Processed People (Chris van Tulleken) ✓
- Stolen Focus (Johann Hari) ✓

### Classics (10)
- 1984 (George Orwell) ✓
- To Kill a Mockingbird (Harper Lee) ✓
- Pride and Prejudice (Jane Austen) ✓
- The Great Gatsby (F. Scott Fitzgerald) ✓
- One Hundred Years of Solitude (Gabriel Garcia Marquez) ✓ (no cover)
- Beloved (Toni Morrison) ✓
- The Handmaid's Tale (Margaret Atwood) ✓
- Norwegian Wood (Haruki Murakami) ✓
- Things Fall Apart (Chinua Achebe) ✓
- Rebecca (Daphne du Maurier) ✓
