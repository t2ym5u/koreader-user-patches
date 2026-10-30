# koreader-user-patches

## How to use these patches
- Create the `patches` folder in the `koreader` directory if it doesn't exist.
- Place the related `.lua` file in the `patches` folder in the `koreader` directory.
- Follow other steps (like editing the lua file) if mentioned below.
- Restart KOReader.

## 2-sort-tools-menu-alphabetically.lua
Alphabetizes plugin entries that land in a submenu via `sorting_hint` (e.g. Tools > More tools) instead of leaving them ordered by internal plugin id, which rarely matches the displayed label (e.g. `SSH`, `2048`, or any custom plugin not explicitly placed in `reader_menu_order.lua` / `filemanager_menu_order.lua`).

**How it works:**
- Overrides `MenuSorter:sort()` — a copy of KOReader's own implementation (`frontend/ui/menusorter.lua`), changed only in how "orphaned" items (attached via `sorting_hint` rather than an explicit `order` table entry) are appended: they're grouped by `sorting_hint` and sorted with KOReader's own natural-sort comparator (`sort.natsort_cmp()`) on their displayed text, instead of `FFIUtil.orderedPairs`' by-id ordering.
- Explicitly-ordered core menu entries (e.g. Read timer, Calibre, Statistics under Tools) keep their curated position — only the unordered/plugin-added entries get alphabetized.

**Requirements:**
- None. Useful as soon as you have more than a couple of plugins registering menu entries via `sorting_hint` (e.g. several game plugins under Tools).

## 2-release-memory-on-close.lua
Gives memory back once a document is closed, so a large PDF (or DjVu, CBZ…) no longer keeps KOReader's memory high in the file browser — and the "High memory usage… Restart KOReader?" alert stops firing after you've closed the book.

**How it works:**
- KOReader's global document cache (`frontend/document/doccache.lua`) keeps rendered pages in RAM after the book is closed. It is sized at startup to 40% of the free RAM (up to 512 MB) and only trimmed when less than 20% of the RAM is free.
- The patch wraps `ReaderUI:onClose()`: once KOReader has saved the last displayed page to the disk cache and closed the document, it empties the in-memory cache, runs a full garbage collection and calls glibc's `malloc_trim(0)` so the freed memory goes back to the system (skipped where unavailable, e.g. Android).
- Reopening a book stays fast: the page you were on is still restored from the disk cache.

**Cache cap:** `MAX_CACHE_MB` at the top of the file also caps the cache while reading. It defaults to `64` (about 80 pages of a 6" screen, suits 256–512 MB devices such as the Kobo Aura); set it to `nil` to keep KOReader's own size.

**Requirements:**
- None. If you use the memory alert (Device status alerts > High memory usage > Threshold), note its default of 100 MB, which is low for PDFs; 300–400 MB is more realistic.

---

## Credits
`2-sort-tools-menu-alphabetically.lua` is based on KOReader's own `frontend/ui/menusorter.lua` (GPL-3.0).

Repo layout and README convention based on [omer-faruq/koreader-user-patches](https://github.com/omer-faruq/koreader-user-patches).
