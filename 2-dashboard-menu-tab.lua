-- Adds a Dashboard button as the first (leftmost) icon of the top menu, in
-- the file browser and while reading. Tapping it closes the menu and opens
-- the dashboard plugin (t2ym5u/dashboard.koplugin); nothing is added when
-- that plugin isn't installed or is disabled.
--
-- The button is a menu tab with a callback and `remember = false`, the same
-- kind as the reader's "file browser" icon. One catch: when the menu opens,
-- KOReader re-selects the last used tab and falls back to the FIRST tab when
-- that one can't be remembered, which would now be our button and would open
-- the dashboard on its own. TouchMenuBar:switchToTab is wrapped so that such
-- an automatic switch lands on the next tab instead; only a real tap on the
-- icon opens the dashboard.
--
-- Change ICON below to use another icon from resources/icons/mdlight/
-- (without the .svg extension).

local ICON = "home"

local FileManagerMenu = require("apps/filemanager/filemanagermenu")
local ReaderMenu = require("apps/reader/modules/readermenu")
local TouchMenu = require("ui/widget/touchmenu")
local logger = require("logger")

local TouchMenuBar = TouchMenu.TouchMenuBar
if not TouchMenuBar then
    -- TouchMenuBar is local to touchmenu.lua; reach it through a menu's bar.
    local upvalue_i = 1
    while true do
        local name, value = debug.getupvalue(TouchMenu.init, upvalue_i)
        if not name then break end
        if name == "TouchMenuBar" then TouchMenuBar = value break end
        upvalue_i = upvalue_i + 1
    end
end

local function makeTab(menu, close)
    return {
        icon = ICON,
        remember = false,
        is_dashboard_tab = true,
        callback = function()
            close(menu)
            local dashboard = menu.ui and menu.ui.dashboard
            if dashboard and dashboard.show then
                dashboard:show()
            end
        end,
    }
end

local function addTab(menu_class, close)
    local orig = menu_class.setUpdateItemTable
    menu_class.setUpdateItemTable = function(self, ...)
        local ret = orig(self, ...)
        local tabs = self.tab_item_table
        if tabs and self.ui and self.ui.dashboard
                and not (tabs[1] and tabs[1].is_dashboard_tab) then
            table.insert(tabs, 1, makeTab(self, close))
        end
        return ret
    end
end

if TouchMenuBar and TouchMenuBar.switchToTab then
    addTab(FileManagerMenu, function(menu) menu:onCloseFileManagerMenu() end)
    addTab(ReaderMenu, function(menu) menu:onTapCloseMenu() end)

    local orig_switch = TouchMenuBar.switchToTab
    TouchMenuBar.switchToTab = function(self, index)
        local tabs = self.menu and self.menu.tab_item_table
        if tabs and tabs[1] and tabs[1].is_dashboard_tab then
            if index > #self.icon_widgets then index = #self.icon_widgets end
            local tab = tabs[index]
            if index <= 1 or (tab and tab.remember == false) then
                index = 2
            end
            -- Never land on a second non-rememberable tab either
            -- (the reader's "file browser" icon sits right after ours).
            while tabs[index] and tabs[index].remember == false and index < #tabs do
                index = index + 1
            end
            self.icon_widgets[index].callback()
            return
        end
        return orig_switch(self, index)
    end
else
    -- Without the guard the menu could open the dashboard on its own, so
    -- add nothing rather than risk it.
    logger.warn("dashboard-menu-tab patch: TouchMenuBar not found, button not added")
end
