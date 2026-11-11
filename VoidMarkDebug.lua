local addonName = ...
local addon = CreateFrame("Frame")
local DB, ui, output, status, filterBox, indicator
local toggle, refresh
local sessionErrors = 0
local priorHandler, recording = nil, false
local bySignature = {}
local LIMIT, MAXTEXT = 250, 5500
local VERSION = "1.3.1-forever"
local problemFrame

local function now()
    if date then return date("%Y-%m-%d %H:%M:%S") end
    return tostring(time and time() or "?")
end
local function readable(v)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if not ok or secret then return nil end
    end
    return type(v) == "string" and v ~= "" and v or nil
end
-- Forever names are "First Surname"; UnitName returns the surname second.
local function character()
    local first, second
    if UnitName then
        local ok, a, b = pcall(UnitName, "player")
        if ok then first, second = readable(a), readable(b) end
    end
    local realm = GetRealmName and readable(GetRealmName()) or nil
    local name = first or "Unknown"
    if second and (not realm or second:gsub("%s", ""):lower() ~= realm:gsub("%s", ""):lower()) then
        name = name .. " " .. second
    end
    return name .. "-" .. (realm or "Unknown")
end
local function owner(message)
    local path = tostring(message or ""):match("([%w_%-]+)\\[^\\\r\n]+%.lua")
        or tostring(message or ""):match("AddOns/([%w_%-]+)/")
        or tostring(message or ""):match("Interface[/\\]AddOns[/\\]([%w_%-]+)")
    return path or "Unknown"
end
local function signature(message)
    return tostring(message or ""):gsub("0x%x+", "0x?"):gsub(":%d+:", ":#:")
end
local function init()
    if type(VoidMarkDebugDB) ~= "table" then VoidMarkDebugDB = {} end
    DB = VoidMarkDebugDB
    DB.entries = type(DB.entries) == "table" and DB.entries or {}
    DB.settings = type(DB.settings) == "table" and DB.settings or {}
    DB.reports = type(DB.reports) == "table" and DB.reports or {}
    DB.session = (tonumber(DB.session) or 0) + 1
    DB.started = now()
    if DB.settings.suppressBlizzard == nil then DB.settings.suppressBlizzard = true end
    if DB.settings.notify == nil then DB.settings.notify = true end
    sessionErrors = 0
    wipe(bySignature)
    for _, entry in ipairs(DB.entries) do
        if type(entry) == "table" and type(entry.key) == "string" then
            bySignature[entry.key] = entry
        end
    end
end
local function record(message)
    if recording or not DB then return end
    recording = true
    local ok = pcall(function()
        local raw = tostring(message or "(empty error)"):sub(1, MAXTEXT)
        local key = signature(raw)
        local hit = bySignature[key]
        if hit then
            hit.count = (tonumber(hit.count) or 1) + 1
            hit.last = now()
            hit.character = character()
            hit.session = DB.session
        else
            local item = { key=key, message=raw, first=now(), last=now(),
                count=1, character=character(), session=DB.session, addon=owner(raw) }
            table.insert(DB.entries, 1, item)
            bySignature[key] = item
            if #DB.entries > LIMIT then
                local removed = table.remove(DB.entries)
                if removed then bySignature[removed.key] = nil end
            end
        end
        sessionErrors = sessionErrors + 1
        if indicator and DB.settings.notify then
            indicator.text:SetText("VMD  |cffff7777"..sessionErrors.."|r")
            indicator:Show()
        end
        if status then status:SetText("Errors: " .. tostring(#DB.entries) .. " groups | Session: " .. sessionErrors) end
    end)
    recording = false
    return ok
end
local handler
handler = function(message)
    record(message)
    if DB and DB.settings and DB.settings.suppressBlizzard then return end
    if priorHandler and priorHandler ~= handler then
        pcall(priorHandler, message)
    end
end
local function install()
    if type(geterrorhandler) ~= "function" or type(seterrorhandler) ~= "function" then return end
    local current = geterrorhandler()
    if current ~= handler then
        priorHandler = current
        seterrorhandler(handler)
    end
end
local function report(search, redacted)
    if not DB then return "VoidMark Debug not initialized" end
    local lines = {
        "VoidMark Debug " .. VERSION .. " | " .. now(),
        "Client: " .. tostring(select(1, GetBuildInfo())) .. " | Build: " .. tostring(select(2, GetBuildInfo())),
        "Session: " .. tostring(DB.session) .. " | Error groups: " .. tostring(#DB.entries) .. " | Problem reports: " .. tostring(#(DB.reports or {})),
        "Character: " .. (redacted and "[hidden]" or character()),
        "Note: Each WoW account/client has separate SavedVariables. Export each account separately.",
        "-----"
    }
    search = tostring(search or ""):lower()
    local found = 0
    for _, e in ipairs(DB.entries) do
        local tag = tostring(e.addon or "Unknown")
        if search == "" or tag:lower():find(search, 1, true) or tostring(e.message or ""):lower():find(search,1,true) then
            found = found + 1
            local msg = tostring(e.message or "")
            if redacted then
                msg = msg:gsub("[%w_%-]+%-[%w_%-]+", "[character-realm]")
            end
            lines[#lines+1] = string.format("[%d] %s | %s | x%d | session %s", found, tag, tostring(e.last), tonumber(e.count) or 1, tostring(e.session or "?"))
            lines[#lines+1] = msg
            lines[#lines+1] = "-----"
        end
    end
    if found == 0 then lines[#lines+1] = "No matching errors." end
    return table.concat(lines, "\n")
end
refresh = function()
    if not output or not DB then return end
    output:SetText(report(filterBox and filterBox:GetText() or "", DB.settings.redact))
    output:HighlightText(0, 0)
    if status then status:SetText("Error groups: " .. #DB.entries .. " | Session errors: " .. sessionErrors) end
end
local function button(parent, text, x, width, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -47)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end
local function createIndicator()
    if indicator then return end
    indicator = CreateFrame("Button", "VoidMarkDebugIndicator", UIParent)
    indicator:SetSize(88, 25)
    indicator:SetPoint("TOP", UIParent, "TOP", 0, -110)
    indicator:SetFrameStrata("HIGH")
    indicator:SetMovable(true)
    indicator:RegisterForDrag("LeftButton")
    indicator:SetScript("OnDragStart", function(self)
        if not InCombatLockdown or not InCombatLockdown() then self:StartMoving() end
    end)
    indicator:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    local bg = indicator:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    bg:SetVertexColor(0.06, 0.06, 0.08, 0.82)
    indicator.text = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    indicator.text:SetPoint("CENTER")
    indicator.text:SetText("VMD  |cffff77770|r")
    indicator:SetScript("OnClick", function() toggle() end)
    indicator:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("VoidMark Debug")
        GameTooltip:AddLine("Click: view errors  |  Drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    indicator:SetScript("OnLeave", function() GameTooltip:Hide() end)
    indicator:Hide()
end
-- Player-written problem reports (not Lua errors). WoW can't send them anywhere;
-- they are saved in VoidMarkDebugDB.reports and VoidMark Warpath sends them.
local function saveProblem(text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or not DB then return false end
    DB.reports = DB.reports or {}
    table.insert(DB.reports, { text=text:sub(1, 2000), time=now(), character=character(), session=DB.session })
    while #DB.reports > 50 do table.remove(DB.reports, 1) end
    return true
end
local function showProblem()
    if not problemFrame then
        local template = BackdropTemplateMixin and "BackdropTemplate" or nil
        local f = CreateFrame("Frame", "VoidMarkDebugProblem", UIParent, template)
        problemFrame = f
        f:SetSize(480, 320); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if f.SetBackdrop then
            f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16,
                insets={left=4,right=4,top=4,bottom=4}})
        end
        if UISpecialFrames then table.insert(UISpecialFrames, "VoidMarkDebugProblem") end
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 16, -16); t:SetText("|cffb388ffREPORT A PROBLEM|r")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 0, 0)
        local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        hint:SetPoint("TOPLEFT", 16, -44); hint:SetWidth(448); hint:SetJustifyH("LEFT")
        hint:SetText("What's wrong? Example: \"sound doesn't play\", \"Market window won't open\".")
        local box = CreateFrame("Frame", nil, f, template)
        box:SetPoint("TOPLEFT", 16, -70); box:SetPoint("BOTTOMRIGHT", -16, 82)
        if box.SetBackdrop then
            box:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
            if box.SetBackdropColor then box:SetBackdropColor(0, 0, 0, 0.6) end
        end
        local sc = CreateFrame("ScrollFrame", "VoidMarkDebugProblemScroll", box, "UIPanelScrollFrameTemplate")
        sc:SetPoint("TOPLEFT", 8, -8); sc:SetPoint("BOTTOMRIGHT", -28, 8)
        local edit = CreateFrame("EditBox", nil, sc)
        if edit.SetMultiLine then edit:SetMultiLine(true) end
        if edit.SetFontObject then edit:SetFontObject(ChatFontNormal) end
        if edit.SetMaxLetters then edit:SetMaxLetters(2000) end
        if edit.SetAutoFocus then edit:SetAutoFocus(false) end
        edit:SetWidth(400); edit:SetHeight(140)
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        sc:SetScrollChild(edit)
        box:EnableMouse(true); box:SetScript("OnMouseDown", function() edit:SetFocus() end)
        f.edit = edit
        f.note = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.note:SetPoint("BOTTOMLEFT", 16, 56); f.note:SetWidth(448); f.note:SetJustifyH("LEFT")
        local function submit(reload)
            if not saveProblem(edit:GetText()) then f.note:SetText("|cffff7777Type what's wrong first.|r"); return end
            edit:SetText(""); f:Hide()
            print("|cffb388ffVoidMark Debug:|r Problem saved. It goes out the next time VoidMark Warpath opens, after a /reload or logout.")
            -- Addons can't call ReloadUI on this client (protected), so pre-type /reload for the player.
            if reload then
                if ChatFrame_OpenChat then ChatFrame_OpenChat("/reload")
                else print("|cffb388ffVoidMark Debug:|r Type /reload to send it sooner.") end
            end
        end
        local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        save:SetSize(210, 28); save:SetPoint("BOTTOMLEFT", 16, 18); save:SetText("Save + /reload (send sooner)")
        save:SetScript("OnClick", function() submit(true) end)
        local later = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        later:SetSize(120, 28); later:SetPoint("LEFT", save, "RIGHT", 8, 0); later:SetText("Save")
        later:SetScript("OnClick", function() submit(false) end)
        local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancel:SetSize(96, 28); cancel:SetPoint("BOTTOMRIGHT", -16, 18); cancel:SetText("Cancel")
        cancel:SetScript("OnClick", function() f:Hide() end)
    end
    problemFrame.note:SetText("Save + /reload puts /reload in your chat box - just press Enter.")
    problemFrame:Show(); problemFrame.edit:SetFocus()
end
local function createUI()
    if ui then return end
    -- Older Forever-derived clients may not provide BackdropTemplate.
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    ui = CreateFrame("Frame", "VoidMarkDebugWindow", UIParent, template)
    ui:SetSize(760, 480)
    ui:SetPoint("CENTER")
    ui:SetFrameStrata("DIALOG")
    ui:EnableMouse(true)
    ui:SetMovable(true)
    ui:RegisterForDrag("LeftButton")
    ui:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ui:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if ui.SetBackdrop then
        ui:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=16,
            insets={left=4,right=4,top=4,bottom=4}})
    end
    local title = ui:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 17, -16)
    title:SetText("|cffb388ffVOIDMARK DEBUG|r")
    local close = CreateFrame("Button", nil, ui, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    status = ui:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", ui, "TOPLEFT", 18, -82)
    status:SetText("Loading...")
    button(ui,"Copy report",15,120,function()
        refresh()
        output:SetFocus()
        output:HighlightText(0, -1)
        print("|cffb388ffVoidMark Debug:|r Report selected. Press Ctrl+C to copy, then paste it into ChatGPT.")
    end)
    button(ui,"Refresh",140,82,refresh)
    local problemButton = CreateFrame("Button", nil, ui, "UIPanelButtonTemplate")
    problemButton:SetSize(150, 24); problemButton:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -36, -12)
    problemButton:SetText("Report a problem"); problemButton:SetScript("OnClick", showProblem)
    button(ui,"Clear logs",226,100,function()
        if not DB then return end
        wipe(DB.entries)
        wipe(bySignature)
        refresh()
    end)
    button(ui,"Redact: OFF",332,122,function(self)
        DB.settings.redact = not DB.settings.redact
        self:SetText(DB.settings.redact and "Redact: ON" or "Redact: OFF")
        refresh()
    end)
    local label=ui:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetPoint("TOPLEFT",ui,"TOPLEFT",470,-53)
    label:SetText("Filter addon/text:")
    filterBox=CreateFrame("EditBox",nil,ui,"InputBoxTemplate")
    filterBox:SetSize(140,22)
    filterBox:SetPoint("TOPLEFT",ui,"TOPLEFT",570,-48)
    filterBox:SetAutoFocus(false)
    filterBox:SetScript("OnEnterPressed",function(self) self:ClearFocus(); refresh() end)
    local scroll=CreateFrame("ScrollFrame","VoidMarkDebugScroll",ui,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",ui,"TOPLEFT",16,-104)
    scroll:SetPoint("BOTTOMRIGHT",ui,"BOTTOMRIGHT",-34,14)
    output=CreateFrame("EditBox",nil,scroll)
    -- Forever client compatibility: guard optional EditBox methods.
    if output.SetMultiLine then output:SetMultiLine(true) end
    if output.SetFontObject then output:SetFontObject(ChatFontNormal) end
    output:SetWidth(690)
    if output.SetAutoFocus then output:SetAutoFocus(false) end
    output:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    output:SetScript("OnTextChanged",function(self)
        local value = self:GetText() or ""
        local _, breaks = value:gsub("\n", "\n")
        local estimate = math.max(300, (breaks + 1) * 15 + 30)
        self:SetHeight(math.min(200000, estimate))
    end)
    scroll:SetScrollChild(output)
    ui:Hide()
    refresh()
end
toggle = function()
    createUI()
    if ui:IsShown() then ui:Hide() else refresh(); ui:Show() end
end
SLASH_VOIDMARKDEBUG1="/vmd"
SLASH_VOIDMARKDEBUG2="/voidmarkdebug"
SlashCmdList.VOIDMARKDEBUG=function(command)
    local cmd=tostring(command or ""):lower():match("^%s*(.-)%s*$")
    if cmd=="clear" then
        if DB then wipe(DB.entries) end
        wipe(bySignature)
        refresh()
        print("|cffb388ffVoidMark Debug:|r Logs cleared.")
    elseif cmd=="problem" or cmd=="bug" then
        showProblem()
    elseif cmd=="report" or cmd=="export" then
        createUI(); refresh(); ui:Show(); output:SetFocus(); output:HighlightText()
    elseif cmd=="top" then
        if not DB then return end
        local sorted = {}
        for _, entry in ipairs(DB.entries) do sorted[#sorted+1] = entry end
        table.sort(sorted, function(a,b) return (tonumber(a.count) or 0) > (tonumber(b.count) or 0) end)
        print("|cffb388ffVoidMark Debug:|r Most frequent Lua errors:")
        for i=1, math.min(5, #sorted) do
            local e = sorted[i]
            local firstLine = tostring(e.message or ""):match("([^\r\n]+)") or ""
            print(string.format("%d. x%d [%s] %s", i, tonumber(e.count) or 0, tostring(e.addon or "?"), firstLine:sub(1, 180)))
        end
    elseif cmd=="notify" then
        DB.settings.notify = not DB.settings.notify
        createIndicator()
        if DB.settings.notify and sessionErrors > 0 then indicator:Show() else indicator:Hide() end
        print("|cffb388ffVoidMark Debug:|r Indicator " .. (DB.settings.notify and "ON" or "OFF"))
    elseif cmd=="blizzard" then
        DB.settings.suppressBlizzard = not DB.settings.suppressBlizzard
        print("|cffb388ffVoidMark Debug:|r Blizzard error handler " .. (DB.settings.suppressBlizzard and "SUPPRESSED" or "ENABLED"))
    elseif cmd=="count" then
        print("|cffb388ffVoidMark Debug:|r "..tostring(DB and #DB.entries or 0).." error groups.")
    elseif cmd=="test" then
        local msg="VoidMark Debug intentional test error"
        record("Interface\\AddOns\\VoidMarkDebug\\Test.lua:1: "..msg)
        print("|cffb388ffVoidMark Debug:|r Test record created (not a real Lua failure).")
        refresh()
    else toggle() end
end
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name==addonName then
        init()
        createIndicator()
        install()
    elseif event=="PLAYER_LOGIN" then
        if not DB then init() end
        createIndicator()
        install()
    end
end)
