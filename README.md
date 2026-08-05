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

---

## Credits
`2-sort-tools-menu-alphabetically.lua` is based on KOReader's own `frontend/ui/menusorter.lua` (GPL-3.0).

Repo layout and README convention based on [omer-faruq/koreader-user-patches](https://github.com/omer-faruq/koreader-user-patches).
