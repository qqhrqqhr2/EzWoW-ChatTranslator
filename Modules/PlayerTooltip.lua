--===========================================================================
-- EzWoW - Chat Translator
-- Modules/PlayerTooltip.lua : Unit Hover /who Inspector & Localized Class/Zone Card
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local UnitHoverInspector = ns.UnitHoverInspector or {}
ns.UnitHoverInspector = UnitHoverInspector
local lookupCache, totalCount = {}, 0
local tipWidget
local hoveredOwner, hoveredLink
local pending
local failedUntil = {}
local buildPlayerCacheKey
local nextAllowed = 0
local REQUEST_INTERVAL, RESPONSE_TIMEOUT = 3, 2
local whoMode, ownRequest, ownRouting = 0, false, false
function UnitHoverInspector.hasSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end
function UnitHoverInspector.getCurrentTimestamp() return GetTime and GetTime() or 0 end
ns.playerLookupStatus = {state = "idle"}
function UnitHoverInspector.updateLookupStatusText(state, detail)
    ns.playerLookupStatus.state, ns.playerLookupStatus.detail = state, detail
end
function UnitHoverInspector.extractSafeTooltipText(key, ...)
    local langCode = ns.ResolveTargetLanguageCode and ns.ResolveTargetLanguageCode() or (GetLocale() == "koKR" and "ko" or "en")
    local dict = ns.PlayerLookupText and (ns.PlayerLookupText[langCode] or ns.PlayerLookupText.en)
    if not dict then return key end
    return string.format(dict[key], ...)
end
buildPlayerCacheKey = function(name)
    if UnitHoverInspector.hasSecret(name) or type(name) ~= "string" then return nil end
    local short, realm = name:match("^([^%-]+)%-(.+)$")
    local localRealm = GetRealmName and GetRealmName()
    if short and localRealm and realm:gsub("%s", ""):lower() == localRealm:gsub("%s", ""):lower() then name = short end
    return name:lower()
end
function UnitHoverInspector.recordDiscoveredEntry(name, data)
    local key = buildPlayerCacheKey(name)
    if not key or key == "" then return end
    if not lookupCache[key] then
        if totalCount >= 500 then lookupCache, totalCount = {}, 0 end
        lookupCache[key], totalCount = {}, totalCount + 1
    end
    for field, value in pairs(data) do
        if not UnitHoverInspector.hasSecret(value) and value ~= nil then lookupCache[key][field] = value end
    end
end
function UnitHoverInspector.gatherWho()
    local api = C_FriendList
    local resolveCount = GetNumWhoResults or (api and api.GetNumWhoResults)
    local resolveInfo = GetWhoInfo or (api and api.GetWhoInfo)
    if not resolveCount or not resolveInfo then return end
    local isCallOk, nodeEntry = pcall(resolveCount)
    ns.playerLookupStatus.resultCount = nodeEntry
    if not isCallOk or type(nodeEntry) ~= "number" then
        ns.playerLookupStatus.readError = isCallOk and "GetNumWhoResults returned no number" or tostring(nodeEntry)
        return
    end
    for index = 1, math.min(nodeEntry, 100) do
        local success, name, guild, level, race, class, zone = pcall(resolveInfo, index)
        if index == 1 then
            if type(name) == "table" then
                local fields = {}
                for entryKey, entryValue in pairs(name) do fields[#fields + 1] = tostring(entryKey) .. "=" .. tostring(entryValue) end
                table.sort(fields)
                ns.playerLookupStatus.firstResult = table.concat(fields, ", ")
            else ns.playerLookupStatus.firstResult = tostring(name) .. "/" .. tostring(level) end
        end
        if success then
            if type(name) == "table" then
                local rowWidget = name
                name, guild, level, race, class, zone = rowWidget.fullName or rowWidget.name,
                    rowWidget.fullGuildName or rowWidget.guild, rowWidget.level, rowWidget.raceStr or rowWidget.race,
                    rowWidget.classStr or rowWidget.class, rowWidget.area or rowWidget.zone
            end
            if type(name) == "string" and type(level) == "number" and level > 0 then
                UnitHoverInspector.recordDiscoveredEntry(name, {level = level, guild = guild or "", race = race,
                    class = class, zone = zone or "", who = true})
            end
        end
    end
end
function UnitHoverInspector.resolveWhoAPI(method)
    return _G[method] or (C_FriendList and (C_FriendList[method] or (method == "SetWhoToUI" and C_FriendList.SetWhoToUi)))
end
function UnitHoverInspector.assignRouting(mode)
    local setter = UnitHoverInspector.resolveWhoAPI("SetWhoToUI")
    if setter then
        ownRouting = true
        local value = mode
        if C_FriendList and setter == C_FriendList.SetWhoToUi then value = mode == true or mode == 1 end
        local isCallOk, errorObj = pcall(setter, value)
        if not isCallOk then UnitHoverInspector.updateLookupStatusText("routing-error", tostring(errorObj)) end
        ownRouting = false
    end
end
function UnitHoverInspector.finishRequest(restoreRouting)
    local previousVal = pending
    pending = nil
    if not previousVal then return end
    if previousVal.frame and previousVal.registered then previousVal.frame:RegisterEvent("WHO_LIST_UPDATE") end
    if restoreRouting then UnitHoverInspector.assignRouting(previousVal.mode) end
end
local socialLoaded = false
function UnitHoverInspector.prepareSocialUI()
    if socialLoaded then return end
    if FriendsFrame then socialLoaded = true return end
    local loader = UIParentLoadAddOn or (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if loader then
        local isCallOk, loaded, reason = pcall(loader, "Blizzard_FriendsFrame")
        ns.playerLookupStatus.socialLoad = tostring(isCallOk) .. "/" .. tostring(loaded) .. "/" .. tostring(reason)
        socialLoaded = FriendsFrame ~= nil
    else ns.playerLookupStatus.socialLoad = "loader unavailable" end
end
function UnitHoverInspector.startRequest(name, attempt)
    UnitHoverInspector.prepareSocialUI()
    local sender = UnitHoverInspector.resolveWhoAPI("SendWho")
    if not sender then UnitHoverInspector.updateLookupStatusText("unsupported", "SendWho unavailable") return false end
    
    if WhoFrame and WhoFrame.IsShown and WhoFrame:IsShown() then return false end
    local containerFrame = FriendsFrame
    local registered = containerFrame and containerFrame.IsEventRegistered and containerFrame:IsEventRegistered("WHO_LIST_UPDATE")
    pending = {name = name, attempt = attempt or 1, started = UnitHoverInspector.getCurrentTimestamp(), mode = whoMode, frame = containerFrame, registered = registered}
    if registered then containerFrame:UnregisterEvent("WHO_LIST_UPDATE") end
    UnitHoverInspector.assignRouting(1)
    ownRequest = true
    local queryName = name:match("^[^%-]+") or name
    queryName = queryName:gsub('["\\]', '')
    local query = 'n-"' .. queryName .. '"'
    ns.playerLookupStatus.query = query
    UnitHoverInspector.updateLookupStatusText("requested", name)
    local isCallOk, errorObj = pcall(sender, query)
    ownRequest = false
    nextAllowed = UnitHoverInspector.getCurrentTimestamp() + REQUEST_INTERVAL
    if not isCallOk then
        UnitHoverInspector.updateLookupStatusText("send-error", tostring(errorObj))
        failedUntil[buildPlayerCacheKey(name)] = UnitHoverInspector.getCurrentTimestamp() + 30
        UnitHoverInspector.finishRequest(true)
        return false
    end
    return true
end

function ns.RequestPlayerInfo(link)
    local name = type(link) == "string" and link:match("^player:([^:]+)")
    if not name then return false end
    ns.playerLookupStatus.clicks = (ns.playerLookupStatus.clicks or 0) + 1
    local currentTime = UnitHoverInspector.getCurrentTimestamp()
    local apiInfo = lookupCache[buildPlayerCacheKey(name)]
    if pending and currentTime - pending.started >= RESPONSE_TIMEOUT then
        failedUntil[buildPlayerCacheKey(pending.name)] = currentTime + 60
        UnitHoverInspector.finishRequest(true)
    end
    if not (apiInfo and apiInfo.level) and not pending and currentTime >= nextAllowed then
        failedUntil[buildPlayerCacheKey(name)] = nil
        ns.playerLookupStatus.requestSource = "shift-click"
        UnitHoverInspector.startRequest(name, 1)
    end
    ns.playerLookupStatus.tooltipDirty = true
    return true
end

local tooltipDirty = false
function UnitHoverInspector.syncHoveredTooltip()
    if not hoveredOwner or not hoveredLink or not tipWidget then return end
    local isCallOk, errorObj = pcall(ns.ShowPlayerTooltip, hoveredOwner, hoveredLink, true)
    if not isCallOk then
        ns.playerLookupStatus.tooltipError = tostring(errorObj)
        tooltipDirty = false
    end
end

if hooksecurefunc then
    local function manualQuery()
        if not ownRequest then
            UnitHoverInspector.finishRequest(false)
            nextAllowed = UnitHoverInspector.getCurrentTimestamp() + REQUEST_INTERVAL
        end
    end
    local function manualRouting(mode)
        if not ownRouting then whoMode = mode end
    end
    if SendWho then pcall(hooksecurefunc, "SendWho", manualQuery)
    elseif C_FriendList and C_FriendList.SendWho then pcall(hooksecurefunc, C_FriendList, "SendWho", manualQuery) end
    if SetWhoToUI then pcall(hooksecurefunc, "SetWhoToUI", manualRouting)
    elseif C_FriendList and C_FriendList.SetWhoToUI then pcall(hooksecurefunc, C_FriendList, "SetWhoToUI", manualRouting)
    elseif C_FriendList and C_FriendList.SetWhoToUi then pcall(hooksecurefunc, C_FriendList, "SetWhoToUi", manualRouting) end
end
function UnitHoverInspector.matches(unit, name)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
    local nodeEntry, realm = UnitName(unit)
    return buildPlayerCacheKey(name) == buildPlayerCacheKey(nodeEntry) or (realm and realm ~= "" and buildPlayerCacheKey(name) == buildPlayerCacheKey(nodeEntry .. "-" .. realm))
end
function UnitHoverInspector.locateUnit(name)
    for _, unit in ipairs({"player", "target", "focus", "mouseover"}) do
        if UnitHoverInspector.matches(unit, name) then return unit end
    end
    for index = 1, 40 do
        local unit = "raid" .. index
        if UnitHoverInspector.matches(unit, name) then return unit end
        if index <= 4 and UnitHoverInspector.matches("party" .. index, name) then return "party" .. index end
    end
end
function UnitHoverInspector.resolveTip(owner)
    if not tipWidget then
        tipWidget = CreateFrame("GameTooltip", "EzWoWChatTranslatorPlayerTooltip", UIParent, "GameTooltipTemplate")
    end
    
    if tipWidget:GetOwner() ~= owner then
        tipWidget:SetOwner(owner, "ANCHOR_CURSOR")
    end
    tipWidget:ClearLines()
    return tipWidget
end
function ns.ShowPlayerTooltip(owner, link, fromRefresh)
    local name = type(link) == "string" and link:match("^player:([^:]+)")
    if not name then return end
    hoveredOwner, hoveredLink = owner, link
    local tooltipObj = UnitHoverInspector.resolveTip(owner)
    local unit = UnitHoverInspector.locateUnit(name)
    if unit then
        tooltipObj:SetUnit(unit)
        
        local titleStr = _G["EzWoWChatTranslatorPlayerTooltipTextLeft1"]
        if titleStr then
            local nameText = titleStr:GetText()
            titleStr:SetText("|cff7ADAD4EzWoW - Chat Translator|r\n" .. (nameText or name))
        else
            tooltipObj:AddLine("EzWoW - Chat Translator", 0.478, 0.855, 0.831)
        end
        tooltipObj:Show()
        return
    end
    local apiInfo = lookupCache[buildPlayerCacheKey(name)] or {}
    local level, class, race, guild, zone = apiInfo.level, apiInfo.class, apiInfo.race, apiInfo.guild, apiInfo.zone
    if not fromRefresh and GetNumGuildMembers and GetGuildRosterInfo then
        for index = 1, GetNumGuildMembers() do
            local nodeEntry, _, _, leftPos, themeColor, zoneRef = GetGuildRosterInfo(index)
            if buildPlayerCacheKey(nodeEntry) == buildPlayerCacheKey(name) then
                level, class, zone = leftPos, themeColor, zoneRef
                guild = GetGuildInfo("player")
                if level and level > 0 then UnitHoverInspector.recordDiscoveredEntry(name, {level = level, class = class, guild = guild, zone = zone}) end
                break
            end
        end
    end
    tooltipObj:AddLine("EzWoW - Chat Translator", 0.478, 0.855, 0.831)
    tooltipObj:AddLine(name, 1, 1, 1)
    if guild and guild ~= "" then tooltipObj:AddLine("<" .. guild .. ">", 0.3, 1, 0.3) end
    local details = {}
    if level and level > 0 then details[#details + 1] = UnitHoverInspector.extractSafeTooltipText("level", level) end
    if race and race ~= "" then details[#details + 1] = race end
    if class and class ~= "" then details[#details + 1] = class end
    if #details > 0 then tooltipObj:AddLine(table.concat(details, " "), 1, 0.82, 0) end
    if zone and zone ~= "" then tooltipObj:AddLine(zone, 0.7, 0.7, 0.7) end
    if not level then
        local currentTime, message = UnitHoverInspector.getCurrentTimestamp()
        if pending then
            local remaining = math.max(0, math.ceil(RESPONSE_TIMEOUT - (currentTime - pending.started)))
            if buildPlayerCacheKey(pending.name) == buildPlayerCacheKey(name) then
                message = UnitHoverInspector.extractSafeTooltipText("loading", remaining)
            else
                message = UnitHoverInspector.extractSafeTooltipText("busy", pending.name, remaining)
            end
        elseif currentTime < nextAllowed then
            local remaining = math.ceil(nextAllowed - currentTime)
            message = UnitHoverInspector.extractSafeTooltipText("wait", remaining)
        elseif (failedUntil[buildPlayerCacheKey(name)] or 0) > currentTime then
            message = UnitHoverInspector.extractSafeTooltipText("failed")
        else
            message = UnitHoverInspector.extractSafeTooltipText("hint")
        end
        tooltipObj:AddLine(message, 0.6, 0.6, 0.6, true)
    end
    tooltipObj:Show()
end
function ns.HidePlayerTooltip(owner)
    if hoveredOwner == owner then hoveredOwner, hoveredLink = nil, nil end
    if tipWidget and tipWidget:GetOwner() == owner then tipWidget:Hide() end
end

local events = CreateFrame("Frame")
pcall(events.RegisterEvent, events, "WHO_LIST_UPDATE")
pcall(events.RegisterEvent, events, "CHAT_MSG_SYSTEM")
for _, event in ipairs({"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_CHANNEL"}) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(self, event, ...)
    if event == "WHO_LIST_UPDATE" then
        ns.playerLookupStatus.events = (ns.playerLookupStatus.events or 0) + 1
    end
    if event == "WHO_LIST_UPDATE" or event == "CHAT_MSG_SYSTEM" then
        local function refresh()
            UnitHoverInspector.gatherWho()
            if event == "WHO_LIST_UPDATE" and pending then
                local apiInfo = lookupCache[buildPlayerCacheKey(pending.name)]
                if apiInfo and apiInfo.level then
                    UnitHoverInspector.updateLookupStatusText("received", pending.name)
                    UnitHoverInspector.finishRequest(true)
                end
            end
            tooltipDirty = true
        end
        if C_Timer and C_Timer.After then C_Timer.After(0, refresh) else refresh() end
        return
    end
    local name, guid = select(2, ...), select(12, ...)
    if UnitHoverInspector.hasSecret(name) or UnitHoverInspector.hasSecret(guid) then return end
    if type(name) ~= "string" or type(guid) ~= "string" or guid == "" or not GetPlayerInfoByGUID then return end
    local isCallOk, class, _, race = pcall(GetPlayerInfoByGUID, guid)
    if not isCallOk or UnitHoverInspector.hasSecret(class) or UnitHoverInspector.hasSecret(race) or not class then return end
    UnitHoverInspector.recordDiscoveredEntry(name, {class = class, race = race})
end)

local elapsed, lastDisplaySecond = 0, nil
events:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    local currentTime = UnitHoverInspector.getCurrentTimestamp()
    if pending then
        UnitHoverInspector.gatherWho()
        local apiInfo = lookupCache[buildPlayerCacheKey(pending.name)]
        if apiInfo and apiInfo.level then
            UnitHoverInspector.updateLookupStatusText("received", pending.name)
            UnitHoverInspector.finishRequest(true)
            tooltipDirty = true
        end
    end
    if pending and currentTime - pending.started >= RESPONSE_TIMEOUT then
        local name = pending.name
        UnitHoverInspector.updateLookupStatusText("timeout", name)
        failedUntil[buildPlayerCacheKey(name)] = currentTime + 60
        UnitHoverInspector.finishRequest(true)
        tooltipDirty = true
    end
    local second = math.floor(currentTime)
    
    local needTick = false
    if hoveredOwner and hoveredLink and second ~= lastDisplaySecond then
        local hname = hoveredLink:match("^player:([^:]+)")
        local hinfo = hname and lookupCache[buildPlayerCacheKey(hname)]
        needTick = not (hinfo and hinfo.level) and (pending ~= nil or currentTime < nextAllowed + 1.5)
    end
    if tooltipDirty or ns.playerLookupStatus.tooltipDirty or needTick then
        lastDisplaySecond = second
        tooltipDirty, ns.playerLookupStatus.tooltipDirty = false, false
        UnitHoverInspector.syncHoveredTooltip()
    end
    ns.playerLookupStatus.mode = "shift-click"
    ns.playerLookupStatus.pending = pending and pending.name or nil
    ns.playerLookupStatus.pendingAge = pending and math.floor(currentTime - pending.started) or nil
    ns.playerLookupStatus.nextDelay = math.max(0, math.ceil(nextAllowed - currentTime))
end)
