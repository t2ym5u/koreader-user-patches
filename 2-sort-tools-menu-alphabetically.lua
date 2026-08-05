-- Alphabetizes plugin entries that land in a submenu via `sorting_hint`
-- (e.g. Tools > More tools) instead of leaving them ordered by internal
-- plugin id, which rarely matches the displayed label (e.g. "SSH", "2048",
-- or any custom plugin not explicitly placed in reader_menu_order.lua /
-- filemanager_menu_order.lua).
--
-- This overrides MenuSorter:sort() with a copy of KOReader's own
-- implementation (frontend/ui/menusorter.lua), changed only in how
-- "orphaned" items (those attached via sorting_hint rather than an
-- explicit order table entry) are appended: they're now grouped by
-- sorting_hint and sorted with KOReader's own natural-sort comparator
-- on their displayed text, instead of relying on FFIUtil.orderedPairs'
-- by-id ordering. Explicitly-ordered core menu entries are untouched.

local FFIUtil = require("ffi/util")
local logger = require("logger")
local sort = require("sort")
local MenuSorter = require("ui/menusorter")

local separator_id = "----------------------------"

function MenuSorter:sort(item_table, order)
    local menu_table = {}
    local sub_menus = {}
    -- the actual sorting of menu items
    for order_id, order_item in pairs(order) do
        -- user might define non-existing menu item
        if item_table[order_id] ~= nil then
            local tmp_menu_table = {}
            menu_table[order_id] = item_table[order_id]
            menu_table[order_id].id = order_id
            for order_number, order_number_id in ipairs(order_item) do
                -- this is a submenu, mark it for later
                if item_table[order_number_id] ~= nil and order[order_number_id] then
                    table.insert(sub_menus, order_number_id)
                    tmp_menu_table[order_number] = {
                        id = order_number_id,
                    }
                -- regular, just insert a menu action
                else
                    if order_number_id == separator_id then
                        -- it's a separator
                        tmp_menu_table[order_number] = self.separator
                    elseif item_table[order_number_id] ~= nil then
                        item_table[order_number_id].id = order_number_id
                        tmp_menu_table[order_number] = item_table[order_number_id]
                        -- remove reference from item_table so it won't show up as orphaned
                        item_table[order_number_id] = nil
                    end
                end
            end
            -- compress menus
            -- if menu_items were missing we might have a table with gaps
            -- but ipairs doesn't like that and quits when it hits nil
            local i = 1
            local new_index = 1
            while i <= table.maxn(tmp_menu_table) do
                local v = tmp_menu_table[i]
                if v then
                    if v.id == separator_id then
                        new_index = new_index - 1
                        -- ignore separator if the menu starts with it
                        if new_index > 0 then
                            menu_table[order_id][new_index].separator = true
                        end
                    else
                        -- fix the index
                        menu_table[order_id][new_index] = tmp_menu_table[i]
                    end

                    new_index = new_index + 1
                end
                i = i + 1
            end
        else
            if order_id ~= "KOMenu:disabled" and order_id ~="plus_menu" then
                --"plus_menu" break an assumption of the menu_sorter, but it's ok, so ignore it.
                --See : https://github.com/koreader/koreader/pull/3844#issuecomment-383092219
                logger.warn("menu id not found:", order_id)
            end
        end
    end

    -- We should not rely on Lua to magically order the items as we expected:
    --     Some menu items cannot be referred until its parent menu item is inserted into
    --     menu_table["KOMenu:menu_buttons"].
    -- So we loop until nothing changed anymore.
    local changed = true
    while changed do
        changed = false
        -- now do the submenus
        for i, sub_menu in ipairs(sub_menus) do
            if menu_table[sub_menu] ~= nil then
                local sub_menu_position = self:findById(menu_table["KOMenu:menu_buttons"], sub_menu)
                if sub_menu_position then
                    changed = true
                    local sub_menu_content = menu_table[sub_menu]
                    sub_menu_position.text = sub_menu_content.text
                    sub_menu_position.hold_callback = sub_menu_content.hold_callback
                    sub_menu_position.sub_item_table = sub_menu_content
                    -- remove reference from top level output
                    menu_table[sub_menu] = nil
                    -- remove reference from input so it won't show up as orphaned
                    item_table[sub_menu] = nil
                end
            end
        end
    end
    -- cleanup, top-level items shouldn't have sub_item_table
    -- they should, however have one going in
    -- Also, compress the menu table.
    local menu_buttons_offset = 0
    for i, top_menu in ipairs(menu_table["KOMenu:menu_buttons"]) do
        local menu_button = menu_table["KOMenu:menu_buttons"][i].sub_item_table
        menu_table["KOMenu:menu_buttons"][i] = nil
        if menu_button then
            menu_table["KOMenu:menu_buttons"][i-menu_buttons_offset] = menu_button
        else
            menu_buttons_offset = menu_buttons_offset + 1
        end
    end
    -- handle disabled
    if order["KOMenu:disabled"] then
        for _, item in ipairs(order["KOMenu:disabled"]) do
            if item_table[item] then
                -- remove reference from input so it won't show up as orphaned
                item_table[item] = nil
            end
        end
    end

    -- remove top level reference before orphan handling
    item_table["KOMenu:menu_buttons"] = nil

    -- attach orphans based on sorting_hint, or with a NEW prefix in the first menu if none found
    -- PATCHED: orphans sharing the same sorting_hint are grouped and alphabetized
    -- by their displayed text instead of by FFIUtil.orderedPairs' by-id ordering.
    local orphans_by_hint = {}
    for k, v in FFIUtil.orderedPairs(item_table) do
        local sorting_hint = v.sorting_hint

        -- normally there should be menu text but check to be sure
        if v.text and v.new ~= true then
            v.id = k
            if not sorting_hint then v.text = self.orphaned_prefix .. v.text end
            -- prevent text being prepended to item on menu reload, i.e., on switching between reader and filemanager
            v.new = true
            -- deal with orphaned submenus
            if #v > 0 then
                v.sub_item_table = {}
                for i=1, #v do
                    v.sub_item_table[i] = v[i]
                end
            end
        end
        if sorting_hint then
            local orphans = orphans_by_hint[sorting_hint]
            if not orphans then
                orphans = {}
                orphans_by_hint[sorting_hint] = orphans
            end
            table.insert(orphans, v)
        else
            table.insert(menu_table["KOMenu:menu_buttons"][1], v)
        end
    end
    local natsort_cmp = sort.natsort_cmp()
    for sorting_hint, orphans in pairs(orphans_by_hint) do
        table.sort(orphans, function(a, b) return natsort_cmp(a.text or "", b.text or "") end)
        local sorting_hint_menu = self:findById(menu_table["KOMenu:menu_buttons"], sorting_hint)
        sorting_hint_menu = sorting_hint_menu.sub_item_table or sorting_hint_menu
        for _, v in ipairs(orphans) do
            table.insert(sorting_hint_menu, v)
        end
    end
    return menu_table["KOMenu:menu_buttons"]
end
