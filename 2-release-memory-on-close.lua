-- Gives memory back after closing a document, so a large PDF (or DjVu, CBZ…)
-- no longer keeps KOReader's resident memory high once you're back in the
-- file browser.
--
-- Why it stays high without this patch: the global document cache
-- (frontend/document/doccache.lua) keeps rendered pages in RAM after the book
-- is closed. It is sized at startup to 40% of the free RAM (up to 512 MB) and
-- is only trimmed when less than 20% of the RAM is free. Even pages that are
-- freed often stay in the process (the C allocator keeps them), so the
-- "High memory usage" alert keeps firing in the file browser.
--
-- What it does, right after a document is closed:
--   1. empties the in-memory document cache (the page shown last is still
--      saved to the disk cache first, as KOReader normally does, so reopening
--      the book stays fast);
--   2. runs two full Lua garbage collections;
--   3. calls glibc's malloc_trim(0) to hand the freed memory back to the
--      system (silently skipped where it doesn't exist, e.g. Android).
--
-- MAX_CACHE_MB also caps the document cache while reading (64 MB holds
-- ~80 pages of a 6" screen and suits 256-512 MB devices such as the Kobo
-- Aura). Set it to nil to keep KOReader's own size.

local MAX_CACHE_MB = 64

local ffi = require("ffi")
local logger = require("logger")
local DocCache = require("document/doccache")
local ReaderUI = require("apps/reader/readerui")

if MAX_CACHE_MB and DocCache.size and DocCache.size > MAX_CACHE_MB * 1024 * 1024 then
    local cap = MAX_CACHE_MB * 1024 * 1024
    DocCache.cache:resize_bytes(cap)
    DocCache.size = cap
    logger.info("release-memory patch: document cache capped to", MAX_CACHE_MB, "MB")
end

local malloc_trim
do
    local ok = pcall(ffi.cdef, "int malloc_trim(size_t pad);")
    if ok then
        local found, fn = pcall(function() return ffi.C.malloc_trim end)
        if found then malloc_trim = fn end
    end
end

local function releaseMemory()
    DocCache:clear()
    collectgarbage()
    collectgarbage()
    if malloc_trim then
        pcall(malloc_trim, 0)
    end
    logger.dbg("release-memory patch: document cache emptied")
end

local orig_onClose = ReaderUI.onClose

function ReaderUI:onClose(...)
    -- onClose serializes the last page to the disk cache and closes the
    -- document; only empty the cache once that's done.
    local had_document = self.document ~= nil
    local ret = orig_onClose(self, ...)
    if had_document then
        releaseMemory()
    end
    return ret
end
