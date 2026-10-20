--===========================================================================
-- EzWoW - Chat Translator
-- Modules/BackgroundScanner.lua : Background Spellbook, Talent & Bag Term Harvester
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local LexiconBackgroundScanner = ns.LexiconBackgroundScanner or {}
ns.LexiconBackgroundScanner = LexiconBackgroundScanner

local inspectTip
local queue, running = {}, false
local PER_TICK = 8
function LexiconBackgroundScanner.isFeatureEnabled()
    return ns.db and ns.db.tooltip and ns.db.tooltip.collect
end

function LexiconBackgroundScanner.readable(v)
    if type(v) ~= "string" then return false end
    if issecretvalue then
        local isCallOk, secret = pcall(issecretvalue, v)
        if not isCallOk or secret then return false end
    end
    return true
end

function LexiconBackgroundScanner.resolveScanTip()
    if not inspectTip then
        inspectTip = CreateFrame("GameTooltip", "EzWoWChatTranslatorScanTip", nil, "GameTooltipTemplate")
        inspectTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
    end
    return inspectTip
end

function LexiconBackgroundScanner.extractTip(setter)
    local tooltipObj = LexiconBackgroundScanner.resolveScanTip()
    tooltipObj:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
    tooltipObj:ClearLines()
    if not pcall(setter, tooltipObj) then return end
    local targetKey = ns.ResolveTargetLanguageCode()
    if targetKey == "en" then targetKey = "ko" end 
    for index = 1, tooltipObj:NumLines() do
        local labelRegion = _G["EzWoWChatTranslatorScanTipTextLeft" .. index]
        local isCallOk, extractSafeTooltipText = false, nil
        if labelRegion and labelRegion.GetText then
            isCallOk, extractSafeTooltipText = pcall(labelRegion.GetText, labelRegion)
        end
        if isCallOk and ns.IsTooltipSectionBoundary and ns.IsTooltipSectionBoundary(extractSafeTooltipText) then break end
        if isCallOk and LexiconBackgroundScanner.readable(extractSafeTooltipText) and extractSafeTooltipText ~= "" and ns.TranslateTooltipLine then
            pcall(ns.TranslateTooltipLine, extractSafeTooltipText, targetKey)
        end
    end
end

function LexiconBackgroundScanner.processNextQueuedBatch()
    if not LexiconBackgroundScanner.isFeatureEnabled() then queue, running = {}, false; return end
    if #queue == 0 then running = false return end
    for _ = 1, PER_TICK do
        local job = table.remove(queue, 1)
        if not job then break end
        LexiconBackgroundScanner.extractTip(job)
    end
    C_Timer.After(0.05, LexiconBackgroundScanner.processNextQueuedBatch)
end

function LexiconBackgroundScanner.enqueue(job)
    if not LexiconBackgroundScanner.isFeatureEnabled() then return end
    queue[#queue + 1] = job
    if not running and C_Timer then
        running = true
        C_Timer.After(0.5, LexiconBackgroundScanner.processNextQueuedBatch)
    end
end

-----------------------------------------------------------------------------
-- Inspect Spellbook
-----------------------------------------------------------------------------
function LexiconBackgroundScanner.inspectSpellbook()
    if not LexiconBackgroundScanner.isFeatureEnabled() then return end
    local visitedMap = {}
    local function addSpell(id)
        if type(id) == "number" and id > 0 and not visitedMap[id] then
            visitedMap[id] = true
            LexiconBackgroundScanner.enqueue(function(tooltipObj) tooltipObj:SetSpellByID(id) end)
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() or 0 do
            local apiInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if apiInfo then
                for index = apiInfo.itemIndexOffset + 1, apiInfo.itemIndexOffset + apiInfo.numSpellBookItems do
                    local isCallOk, item = pcall(C_SpellBook.GetSpellBookItemInfo, index, Enum.SpellBookSpellBank.Player)
                    if isCallOk and item then addSpell(item.spellID or item.actionID) end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo then
        for tabWidget = 1, GetNumSpellTabs() do
            local _, _, offset, numericVal = GetSpellTabInfo(tabWidget)
            for index = (offset or 0) + 1, (offset or 0) + (numericVal or 0) do
                local isCallOk, _, id = pcall(GetSpellBookItemInfo, index, BOOKTYPE_SPELL or "spell")
                if isCallOk then addSpell(id) end
            end
        end
    end
end

-----------------------------------------------------------------------------
-- Inspect Talents
-----------------------------------------------------------------------------
function LexiconBackgroundScanner.inspectTalents()
    if not LexiconBackgroundScanner.isFeatureEnabled() then return end
    if not (GetNumTalentTabs and GetNumTalents) then return end
    for tabWidget = 1, GetNumTalentTabs() or 0 do
        for index = 1, GetNumTalents(tabWidget) or 0 do
            LexiconBackgroundScanner.enqueue(function(tooltipObj) tooltipObj:SetTalent(tabWidget, index) end)
        end
    end
end

-----------------------------------------------------------------------------
-- Inspect Bags
-----------------------------------------------------------------------------
local scannedItems = {}
function LexiconBackgroundScanner.inspectBags()
    if not LexiconBackgroundScanner.isFeatureEnabled() then return end
    local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local itemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
    if not (numSlots and itemID) then return end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, numSlots(bag) or 0 do
            local isCallOk, id = pcall(itemID, bag, slot)
            if isCallOk and type(id) == "number" and not scannedItems[id] then
                scannedItems[id] = true
                LexiconBackgroundScanner.enqueue(function(tooltipObj) tooltipObj:SetBagItem(bag, slot) end)
            end
        end
    end
end

-----------------------------------------------------------------------------
-- Restart Background Lexicon Scan
-----------------------------------------------------------------------------
local pendingBags, pendingSpells = false, false
function ns.RestartBackgroundLexiconScan()
    queue = {}
    scannedItems = {}
    -- option turned on mid-session: run the initial scan now instead of waiting for a loading screen
    if C_Timer and LexiconBackgroundScanner.isFeatureEnabled() then
        C_Timer.After(1, function()
            if not LexiconBackgroundScanner.isFeatureEnabled() then return end
            pcall(LexiconBackgroundScanner.inspectSpellbook); pcall(LexiconBackgroundScanner.inspectTalents); pcall(LexiconBackgroundScanner.inspectBags)
        end)
    end
end
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(self, event)
    if not LexiconBackgroundScanner.isFeatureEnabled() then return end
    if event == "PLAYER_ENTERING_WORLD" then
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        C_Timer.After(5, function() pcall(LexiconBackgroundScanner.inspectSpellbook); pcall(LexiconBackgroundScanner.inspectTalents); pcall(LexiconBackgroundScanner.inspectBags) end)
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        if not pendingSpells then
            pendingSpells = true
            C_Timer.After(2, function() pendingSpells = false; pcall(LexiconBackgroundScanner.inspectSpellbook) end)
        end
    elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" then
        if not pendingBags then
            pendingBags = true
            C_Timer.After(3, function() pendingBags = false; pcall(LexiconBackgroundScanner.inspectBags) end)
        end
    end
end)

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then prevLogin() end
    if not C_Timer then return end
    for _, recordEntry in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "BAG_UPDATE_DELAYED" }) do
        pcall(eventFrame.RegisterEvent, eventFrame, recordEntry)
    end
end

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
LexiconBackgroundScanner.RestartBackgroundLexiconScan = ns.RestartBackgroundLexiconScan
