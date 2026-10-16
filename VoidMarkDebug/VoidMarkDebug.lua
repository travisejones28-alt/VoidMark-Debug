local addonName = ...
local addon = CreateFrame("Frame")
local DB, ui, output, status, filterBox
local priorHandler, recording = nil, false
local LIMIT, MAXTEXT = 250, 5500
local VERSION = "1.0.0"

local function now()
    if date then return date("%Y-%m-%d %H:%M:%S") end
    return tostring(time and time() or "?")
end
local function character()
    local name = UnitName and UnitName("player") or "Unknown"
    local realm = GetRealmName and GetRealmName() or "Unknown"
    return tostring(name or "Unknown") .. "-" .. tostring(realm or "Unknown")
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
    DB.session = (tonumber(DB.session) or 0) + 1
    DB.started = now()
end
local function record(message)
    if recording or not DB then return end
    recording = true
    local ok = pcall(function()
        local raw = tostring(message or "(empty error)"):sub(1, MAXTEXT)
        local key = signature(raw)
        local hit
        for _, item in ipairs(DB.entries) do
            if item.key == key then hit = item; break end
        end
        if hit then
            hit.count = (tonumber(hit.count) or 1) + 1
            hit.last = now()
            hit.character = character()
            hit.session = DB.session
        else
            local item = { key=key, message=raw, first=now(), last=now(),
                count=1, character=character(), session=DB.session, addon=owner(raw) }
            table.insert(DB.entries, 1, item)
            if #DB.entries > LIMIT then table.remove(DB.entries) end
        end
        if status then status:SetText("Errors: " .. tostring(#DB.entries) .. " groups") end
    end)
    recording = false
    return ok
end
local handler
handler = function(message)
    record(message)
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
        "Session: " .. tostring(DB.session) .. " | Error groups: " .. tostring(#DB.entries),
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
local function refresh()
    if not output or not DB then return end
    output:SetText(report(filterBox and filterBox:GetText() or "", DB.settings.redact))
    output:HighlightText(0, 0)
    if status then status:SetText("Error groups: " .. #DB.entries .. " | Session " .. DB.session) end
end
local function button(parent, text, x, width, fn)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -47)
    b:SetText(text)
    b:SetScript("OnClick", fn)
    return b
end
local function createUI()
    if ui then return end
    ui = CreateFrame("Frame", "VoidMarkDebugWindow", UIParent, "BackdropTemplate")
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
    button(ui,"Select report",15,120,function() refresh(); output:SetFocus(); output:HighlightText() end)
    button(ui,"Refresh",140,82,refresh)
    button(ui,"Clear logs",226,100,function()
        if not DB then return end
        wipe(DB.entries)
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
    output:SetMultiLine(true)
    output:SetFontObject(ChatFontNormal)
    output:SetWidth(690)
    output:SetAutoFocus(false)
    output:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    output:SetScript("OnTextChanged",function(self) self:SetHeight(math.max(300,self:GetStringHeight()+30)) end)
    scroll:SetScrollChild(output)
    ui:Hide()
    refresh()
end
local function toggle()
    createUI()
    if ui:IsShown() then ui:Hide() else refresh(); ui:Show() end
end
SLASH_VOIDMARKDEBUG1="/vmd"
SLASH_VOIDMARKDEBUG2="/voidmarkdebug"
SlashCmdList.VOIDMARKDEBUG=function(command)
    local cmd=tostring(command or ""):lower():match("^%s*(.-)%s*$")
    if cmd=="clear" then
        if DB then wipe(DB.entries) end
        refresh()
        print("|cffb388ffVoidMark Debug:|r Logs cleared.")
    elseif cmd=="report" or cmd=="export" then
        createUI(); refresh(); ui:Show(); output:SetFocus(); output:HighlightText()
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
        install()
    elseif event=="PLAYER_LOGIN" then
        if not DB then init() end
        install()
    end
end)
