--===========================================================================
-- EzWoW - Chat Translator
-- Modules/TooltipTranslator.lua : GameTooltip Bilingual Line & Title Translator
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local TooltipTranslationHook = ns.TooltipTranslationHook or {}
ns.TooltipTranslationHook = TooltipTranslationHook
local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })

local COLLECT_MAX = 3000
local HEADER = "EzWoW - Chat Translator"

-----------------------------------------------------------------------------
-- Readable
-----------------------------------------------------------------------------
function TooltipTranslationHook.readable(v)
    if type(v) ~= "string" then return false end
    if issecretvalue then
        local isCallOk, secret = pcall(issecretvalue, v)
        if not isCallOk or secret then return false end
    end
    return true
end

-----------------------------------------------------------------------------
-- Trim
-----------------------------------------------------------------------------
function TooltipTranslationHook.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function TooltipTranslationHook.cleanCodes(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|H.-|h(.-)|h", "%1")
    
    s = s:gsub("\194\160", " "):gsub("\r", ""):gsub("\n", " ")
    return s
end

local UNIT_FIX = {
    { "(%d+)%s*시간", "%1 hr" }, { "(%d+)%s*분", "%1 min" }, { "(%d+)%s*초", "%1 sec" },
    { "(%d+)%s*小时", "%1 hr" }, { "(%d+)%s*小時", "%1 hr" }, { "(%d+)%s*分钟", "%1 min" }, { "(%d+)%s*分鐘", "%1 min" }, { "(%d+)%s*秒", "%1 sec" },
    { "(%d+)%s*ч%.?", "%1 hr" }, { "(%d+)%s*мин%.?", "%1 min" }, { "(%d+)%s*сек%.?", "%1 sec" },
    { "(%d+)%s+hours?", "%1 hr" }, { "(%d+)%s+hrs?", "%1 hr" },
    { "(%d+)%s+minutes?", "%1 min" }, { "(%d+)%s+mins?", "%1 min" },
    { "(%d+)%s+seconds?", "%1 sec" }, { "(%d+)%s+secs?", "%1 sec" },
}

function TooltipTranslationHook.canonEntry(s)
    s = s:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    
    s = s:gsub("\194\160", " "):gsub("\\n", " "):gsub("%s+", " ")
    for _, unitRef in ipairs(UNIT_FIX) do s = s:gsub(unitRef[1], unitRef[2]) end
    s = TooltipTranslationHook.trim(s)
    s = TooltipTranslationHook.trim(s:gsub('^"', ""):gsub('"$', ""))
    s = s:gsub("[%.!]+$", "")
    return s
end

function TooltipTranslationHook.resolveKeyOf(canon)
    local nums = {}
    local lookupKey = canon:gsub("%d+%.?%d*", function(n) nums[#nums + 1] = n; return "#" end)
    return lookupKey, nums
end

function TooltipTranslationHook.populateGlossaryTable(tpl, nums)
    return (tpl:gsub("{(%d)}", function(i) return nums[tonumber(i)] or "?" end))
end

-----------------------------------------------------------------------------
-- Assemble Fuzzy
-----------------------------------------------------------------------------
local STOP = {}
for boxWidth in ("a an the of to and or in on by for with your you is are be it its this that from as at into"):gmatch("%S+") do STOP[boxWidth] = true end
local fuzzyIndex, fuzzySize

local KEYWORD = {}
for boxWidth in ([[attack healing heal spell spells stamina strength agility intellect spirit mana health energy rage
    fire frost nature shadow arcane holy physical damage armor critical crit hit dodge parry block speed movement
    defense resistance haste power ranged melee weapon shield bear cat moonkin travel aquatic party raid enemy
    enemies friendly target targets increases increased decreases decreased reduces reduced]]):gmatch("%S+") do KEYWORD[boxWidth] = true end

function TooltipTranslationHook.assembleFuzzy()
    fuzzyIndex, fuzzySize = {}, {}
    for i, recordEntry in ipairs(ns.TipDBFuzzy or {}) do
        local n = 0
        for boxWidth in recordEntry[1]:gmatch("%S+") do
            n = n + 1
            local itemList = fuzzyIndex[boxWidth]
            if not itemList then itemList = {}; fuzzyIndex[boxWidth] = itemList end
            itemList[#itemList + 1] = i
        end
        fuzzySize[i] = n
    end
end

function ns.FindSimilarGlossaryEntries(lookupKey, target)
    if not ns.TipDBFuzzy then return nil end
    if not fuzzyIndex then TooltipTranslationHook.assembleFuzzy() end
    local words, nqVal = {}, 0
    for boxWidth in lookupKey:gmatch("[%a']+") do
        if #boxWidth > 1 and not STOP[boxWidth] and not words[boxWidth] then words[boxWidth] = true; nqVal = nqVal + 1 end
    end
    if nqVal < 4 then return nil end
    local sigParts = {}
    for pct in lookupKey:gmatch("#(%%?)") do sigParts[#sigParts + 1] = (pct == "%") and "p" or "n" end
    local sig = table.concat(sigParts, ",")
    local totalCount = {}
    for boxWidth in pairs(words) do
        local itemList = fuzzyIndex[boxWidth]
        if itemList and #itemList <= 600 then
            for _, i in ipairs(itemList) do totalCount[i] = (totalCount[i] or 0) + 1 end
        end
    end
    local best, bestScore = nil, 0
    for i, themeColor in pairs(totalCount) do
        if themeColor >= 4 then
            local score = themeColor / (nqVal + fuzzySize[i] - themeColor)
            local recordEntry = ns.TipDBFuzzy[i]
            if score > bestScore and recordEntry[2][target] and (recordEntry[3] or "") == sig then best, bestScore = i, score end
        end
    end
    if not best or bestScore < 0.85 then return nil end
    
    local cand = {}
    for boxWidth in ns.TipDBFuzzy[best][1]:gmatch("%S+") do cand[boxWidth] = true end
    for boxWidth in pairs(words) do if not cand[boxWidth] and KEYWORD[boxWidth] then return nil end end
    for boxWidth in pairs(cand) do if not words[boxWidth] and KEYWORD[boxWidth] then return nil end end
    return ns.TipDBFuzzy[best][2][target]
end

-----------------------------------------------------------------------------
-- Translate Name
-----------------------------------------------------------------------------
function TooltipTranslationHook.translateName(name, target)
    local n = TooltipTranslationHook.trim(name):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local recordEntry = ns.TipNames and ns.TipNames[n:lower()]
    if recordEntry and recordEntry[target] then return recordEntry[target], true end
    recordEntry = ns.TipDBNames and ns.TipDBNames[n:lower()]
    if recordEntry and recordEntry[target] then return recordEntry[target], true end
    if not (ns.TranslateChatMessageLine and n:find("%a")) then return nil end
    local function full(x)
        local greenVal = ns.TranslateChatMessageLine(x, "en", target)
        if greenVal and greenVal.found > 0 and greenVal.cover >= 100 then
            
            if target == "zhCN" or target == "zhTW" then return (greenVal.plain:gsub(" ", "")) end
            return greenVal.plain
        end
    end
    
    local head, tail = n:match("^(.+) of the (.+)$")
    if not head then head, tail = n:match("^(.+) of (.+)$") end
    if head then
        local headerBar, resolvedValue = full(head), full(tail)
        if headerBar and resolvedValue then
            if target == "ko" then return resolvedValue .. "의 " .. headerBar, false end
            if target == "zhCN" or target == "zhTW" then return resolvedValue .. "之" .. headerBar, false end
            return headerBar .. " " .. resolvedValue, false
        end
    end
    local greenVal = full(n)
    if greenVal then return greenVal, false end
    return nil
end
ns.TranslateName = TooltipTranslationHook.translateName

-----------------------------------------------------------------------------
-- Translate Piece
-----------------------------------------------------------------------------
function TooltipTranslationHook.translatePiece(piece, target)
    local canon = TooltipTranslationHook.canonEntry(piece)
    if canon == "" then return nil end
    local lookupKey, nums = TooltipTranslationHook.resolveKeyOf(canon)

    local recordEntry = ns.TipText and ns.TipText[lookupKey]
    if recordEntry and recordEntry[target] then return TooltipTranslationHook.populateGlossaryTable(recordEntry[target], nums), "exact" end
    recordEntry = ns.TipDBText and ns.TipDBText[lookupKey]
    if recordEntry and recordEntry[target] then return TooltipTranslationHook.populateGlossaryTable(recordEntry[target], nums), "exact" end

    local fzVal = ns.FindSimilarGlossaryEntries and ns.FindSimilarGlossaryEntries(lookupKey, target)
    if fzVal then
        local outputList = TooltipTranslationHook.populateGlossaryTable(fzVal, nums)
        if not outputList:find("?", 1, true) then return outputList, "similar" end
    end

    if ns.TipPatterns then
        for _, anchorTarget in ipairs(ns.TipPatterns) do
            local caps = { canon:match(anchorTarget[1]) }
            if caps[1] ~= nil and anchorTarget[2][target] then
                
                local low = TooltipTranslationHook.trim(piece):lower()
                local raw = anchorTarget[2][target]:gsub("%%=(%d)", function(i)
                    local themeColor = caps[tonumber(i)] or ""
                    local stateEntry = low:find(themeColor, 1, true)
                    local orig = stateEntry and TooltipTranslationHook.trim(piece):sub(stateEntry, stateEntry + #themeColor - 1) or themeColor
                    local recordEntry = (ns.TipNames and ns.TipNames[themeColor]) or (ns.TipDBNames and ns.TipDBNames[themeColor])
                    return (recordEntry and recordEntry[target]) or orig
                end)
                local outputList = raw:gsub("%%(%d)", function(i)
                    local themeColor = caps[tonumber(i)] or ""
                    if themeColor:find("%a") and ns.TranslateChatMessageLine then
                        
                        local greenVal = ns.TranslateChatMessageLine(themeColor, "en", target)
                        if greenVal and greenVal.found > 0 then return greenVal.plain end
                    end
                    return themeColor
                end)
                outputList = outputList:gsub("%%%%", "%%")
                return outputList, "pattern"
            end
        end
    end

    local words = 0
    for _ in canon:gmatch("%a+") do words = words + 1 end
    if words >= 2 and ns.TranslateChatMessageLine then
        local greenVal = ns.TranslateChatMessageLine(piece, "en", target)
        if greenVal and greenVal.found > 0 then return greenVal.plain, "gloss" end
    end
    return nil
end

-----------------------------------------------------------------------------
-- Resolve English Words
-----------------------------------------------------------------------------
function TooltipTranslationHook.resolveEnglishWords(text)
    
    local low = text:lower()
    if low:find("id[%s:#]*%d") then return 0 end
    if text:find("^■") or text:find("^◆") or text:find("^◇") then return 0 end
    local n = 0
    for boxWidth in text:gmatch("%a+") do
        if #boxWidth >= 2 then n = n + 1 end
    end
    return n
end

function TooltipTranslationHook.looksEnglishName(text)
    return not text:find("[\228-\239][\128-\191][\128-\191]") and text:find("%a%a") ~= nil
end

function TooltipTranslationHook.looksEnglish(piece)
    local latin = select(2, piece:gsub("%a", ""))
    local other = select(2, piece:gsub("[\228-\239][\128-\191][\128-\191]", ""))
    return latin >= 6 and latin > other * 3
end

function TooltipTranslationHook.splitPrefix(text)
    local kinds = { ["ITEM_SPELL_TRIGGER_ONUSE"] = "use", ["ITEM_SPELL_TRIGGER_ONEQUIP"] = "equip", ["ITEM_SPELL_TRIGGER_ONPROC"] = "proc" }
    for greenVal, kind in pairs(kinds) do
        local anchorTarget = _G[greenVal]
        if type(anchorTarget) == "string" and anchorTarget ~= "" and text:sub(1, #anchorTarget) == anchorTarget then
            return kind, TooltipTranslationHook.trim(text:sub(#anchorTarget + 1))
        end
    end
    local enVal, rest = text:match("^(%a[%a ]-:)%s*(.+)$")
    local map = { ["Use:"] = "use", ["Equip:"] = "equip", ["Chance on hit:"] = "proc" }
    if enVal and map[enVal] then return map[enVal], rest end
    return nil, text
end

function TooltipTranslationHook.resolveSentences(text)
    local outputList, buf = {}, text
    while true do
        
        local s, recordEntry = buf:find("[%.!%?]%s+[^%s%d]")
        if not s then break end
        outputList[#outputList + 1] = buf:sub(1, s)
        buf = buf:sub(recordEntry)
    end
    outputList[#outputList + 1] = buf
    return outputList
end

-----------------------------------------------------------------------------
-- Collect Matching Entries
-----------------------------------------------------------------------------
function TooltipTranslationHook.collectMatchingEntries(piece)
    local savedDB = ns.db
    if not savedDB or not savedDB.tooltip or not savedDB.tooltip.collect then return end
    if not TooltipTranslationHook.looksEnglish(piece) then return end
    savedDB.collected = savedDB.collected or {}
    local lookupKey = TooltipTranslationHook.resolveKeyOf(TooltipTranslationHook.canonEntry(piece))
    if savedDB.collected[lookupKey] then return end
    if not savedDB.collectedCount or savedDB.collectedCount > COLLECT_MAX then
        local n = 0; for _ in pairs(savedDB.collected) do n = n + 1 end
        savedDB.collectedCount = n
    end
    if savedDB.collectedCount >= COLLECT_MAX then return end
    savedDB.collected[lookupKey] = TooltipTranslationHook.trim(piece)
    savedDB.collectedCount = savedDB.collectedCount + 1
end

-----------------------------------------------------------------------------
-- Translate Line
-----------------------------------------------------------------------------
local lookupCache, cacheTarget, cacheCollect = {}, nil, nil

function TooltipTranslationHook.translateLine(text, target)
    local collecting = ns.db and ns.db.tooltip and ns.db.tooltip.collect or false
    if cacheTarget ~= target or cacheCollect ~= collecting then
        lookupCache, cacheTarget, cacheCollect = {}, target, collecting
    end
    local themeColor = lookupCache[text]
    if themeColor ~= nil then return themeColor or nil end
    local original = text
    text = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(text))
    if TooltipTranslationHook.resolveEnglishWords(text) == 0 then lookupCache[original] = false return nil end

    local assignCount, assignBody
    for _, formatLocalizedLabel in ipairs({ "세트 효과", "Set", "set" }) do
        assignCount, assignBody = text:match("^%((%d+)%)%s*" .. formatLocalizedLabel .. ":%s*(.+)$")
        if assignCount then break end
    end
    local prefix, body = TooltipTranslationHook.splitPrefix(assignBody or text)
    local parts, full = {}, true
    local wholeKey, wholeNums = TooltipTranslationHook.resolveKeyOf(TooltipTranslationHook.canonEntry(body))
    local whole = (ns.TipText and ns.TipText[wholeKey]) or (ns.TipDBText and ns.TipDBText[wholeKey])
    local pieces = TooltipTranslationHook.resolveSentences(body)
    if whole and whole[target] then
        parts[1] = TooltipTranslationHook.populateGlossaryTable(whole[target], wholeNums)
        pieces = {}
    elseif #pieces > 1 then
        
        local fzVal = ns.FindSimilarGlossaryEntries and ns.FindSimilarGlossaryEntries(wholeKey, target)
        if fzVal then
            local outputList = TooltipTranslationHook.populateGlossaryTable(fzVal, wholeNums)
            if not outputList:find("?", 1, true) then parts[1] = outputList; pieces = {} end
        end
    end
    
    local merged, i = {}, 1
    while i <= #pieces do
        local hit
        for subIndex = #pieces, i + 1, -1 do
            local k, nums = TooltipTranslationHook.resolveKeyOf(TooltipTranslationHook.canonEntry(table.concat(pieces, " ", i, subIndex)))
            local recordEntry = (ns.TipText and ns.TipText[k]) or (ns.TipDBText and ns.TipDBText[k])
            if recordEntry and recordEntry[target] then hit = { done = TooltipTranslationHook.populateGlossaryTable(recordEntry[target], nums) }; i = subIndex + 1; break end
        end
        if not hit then hit = pieces[i]; i = i + 1 end
        merged[#merged + 1] = hit
    end
    for _, piece in ipairs(merged) do
        if type(piece) == "table" then
            parts[#parts + 1] = piece.done
        elseif TooltipTranslationHook.resolveEnglishWords(piece) > 0 then
            local translationMap, how = TooltipTranslationHook.translatePiece(piece, target)
            if translationMap then
                parts[#parts + 1] = translationMap
                if how == "gloss" then full = false; TooltipTranslationHook.collectMatchingEntries(piece) end
            else
                full = false
                TooltipTranslationHook.collectMatchingEntries(piece)
                
                parts[#parts + 1] = { raw = TooltipTranslationHook.trim(piece) }
            end
        end
    end
    local any = false
    for i, anchorTarget in ipairs(parts) do
        if type(anchorTarget) == "table" then parts[i] = anchorTarget.raw else any = true end
    end
    local result = false
    if any then
        local cjk = (target == "zhCN" or target == "zhTW")
        if #parts > 1 then
            
            for i = 1, #parts - 1 do
                if not parts[i]:find("[%.!%?。！？…%)]$") and not parts[i]:find("\227\128\130$") then
                    parts[i] = parts[i] .. (cjk and "。" or ".")
                end
            end
        end
        local joined = table.concat(parts, cjk and "" or " ")
        if prefix then
            
            local localPrefix = (prefix == "use" and L.tipUse) or (prefix == "equip" and L.tipEquip) or L.tipProc
            joined = localPrefix .. " " .. joined
        end
        if assignCount then
            local labels = {ko="세트 효과", en="Set", de="Set", fr="Ensemble", zhCN="套装", zhTW="套裝", ru="Комплект", ja="セット効果", es="Conjunto"}
            joined = "(" .. assignCount .. ") " .. (labels[target] or "Set") .. ": " .. joined
        end
        result = { text = joined, full = full }
    end
    lookupCache[original] = result
    return result or nil
end
ns.TranslateTooltipLine = TooltipTranslationHook.translateLine

-----------------------------------------------------------------------------
-- Has Addon Label
-----------------------------------------------------------------------------

local addonLabels
function TooltipTranslationHook.hasAddonLabel(text)
    local formatLocalizedLabel = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(text)):lower():gsub("%s+", " ")
    if formatLocalizedLabel == "wow smart fishing" or formatLocalizedLabel == "ezwow - smart fishing"
        or formatLocalizedLabel == "ezwow - best gear finder" or formatLocalizedLabel == "ezwow - tooltip"
        or formatLocalizedLabel == "ezwow - chat translator" then return true end
    if not addonLabels then
        addonLabels = {}
        local api = C_AddOns or {}
        local totalCount = api.GetNumAddOns or GetNumAddOns
        local apiInfo = api.GetAddOnInfo or GetAddOnInfo
        if totalCount and apiInfo then
            local isCallOk, grandTotal = pcall(totalCount)
            if isCallOk and type(grandTotal) == "number" then
                for i = 1, grandTotal do
                    local success, name, titleStr = pcall(apiInfo, i)
                    if success then
                        if type(name) == "table" then name, titleStr = name.name, name.title end
                        for _, value in ipairs({name or "", titleStr or ""}) do
                            if TooltipTranslationHook.readable(value) then
                                value = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(value)):lower():gsub("%s+", " ")
                                if #value >= 4 then addonLabels[value] = true end
                            end
                        end
                    end
                end
            end
        end
    end
    return addonLabels[formatLocalizedLabel] == true
end

function ns.IsTooltipSectionBoundary(text)
    if not TooltipTranslationHook.readable(text) then return false end
    text = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(text))
    local lower = text:lower()
    if TooltipTranslationHook.hasAddonLabel(text) then return true end
    for _, lookupKey in ipairs({ "ITEM_MIN_LEVEL", "SELL_PRICE", "SELL_PRICE_COLON", "ITEM_SELL_PRICE", "ITEM_REQ_SKILL", "ITEM_REQ_SKILL_RANK" }) do
        local fmt = _G[lookupKey]
        if TooltipTranslationHook.readable(fmt) then
            local prefix = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(fmt)):match("^(.-)%%") or TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(fmt))
            prefix = TooltipTranslationHook.trim(prefix):lower()
            if prefix ~= "" and lower:sub(1, #prefix) == prefix then return true end
        end
    end
    for _, prefix in ipairs({ "최소 요구 레벨", "요구 레벨", "판매 가격", "판매가격", "상점가:", "상점가",
        "requires level", "required level", "sell price", "selling price", "요구 사항:", "요구사항:",
        "erfordert stufe", "stufe benötigt", "verkaufspreis", "niveau requis", "prix de vente",
        "necesita nivel", "precio de venta", "需要等级", "需要等級", "售价", "售價", "требуется уровень", "цена продажи" }) do
        if lower:sub(1, #prefix) == prefix then return true end
    end
    
    return lower:match("^att%s*>") ~= nil or lower:match("^all the things") ~= nil
        or lower:match("^best gear finder") ~= nil or lower:match("^ezwow%s*%-") ~= nil or lower:match("^item%s*id") ~= nil
        or lower:find("item%s*id%s*#?%d") ~= nil or lower:find("spell%s*id%s*#?%d") ~= nil
        or lower:match("^아이템%s*id") ~= nil or lower:match("^주문%s*id") ~= nil
        or text:find("^■") ~= nil or text:find("^◆") ~= nil or text:find("^◇") ~= nil
        or lower:match("^added with patch") ~= nil
        or lower:match("^icon%s*id") ~= nil or lower:match("^itemlevel") ~= nil
        or text == HEADER or text == "WoW Chat Translator"
end

function TooltipTranslationHook.processIncomingEntry(tooltip)
    local savedDB = ns.db
    if not savedDB or not savedDB.tooltip or not savedDB.tooltip.enabled then return end
    local target = ns.ResolveTargetLanguageCode()
    if target == "en" then return end  
    if tooltip.wctDone then return end
    
    if tooltip.GetUnit then
        local isCallOk, _, unit = pcall(tooltip.GetUnit, tooltip)
        if isCallOk and unit then return end
    end
    local name = tooltip.GetName and tooltip:GetName()
    if not name then return end
    local n = tooltip.NumLines and tooltip:NumLines() or 0
    local outputList = {}
    for i = 1, n do
        local labelRegion = _G[name .. "TextLeft" .. i]
        local isCallOk, text = false, nil
        if labelRegion and labelRegion.GetText then
            isCallOk, text = pcall(labelRegion.GetText, labelRegion)
        end
        if isCallOk and TooltipTranslationHook.readable(text) then text = TooltipTranslationHook.trim(TooltipTranslationHook.cleanCodes(text)) end
        if isCallOk and ns.IsTooltipSectionBoundary(text) then
            
            if TooltipTranslationHook.readable(text) and text:lower():match("^requires ") then
                local lookupKey, nums = TooltipTranslationHook.resolveKeyOf(TooltipTranslationHook.canonEntry(text))
                local entry = ns.TipText and ns.TipText[lookupKey]
                if entry and entry[target] then outputList[#outputList + 1] = {text=TooltipTranslationHook.populateGlossaryTable(entry[target], nums), full=true} end
            end
            break
        end
        if i == 1 and isCallOk and TooltipTranslationHook.readable(text) and text ~= "" then
            
            local okc, itemCount = pcall(TooltipTranslationHook.resolveEnglishWords, text)
            if okc and itemCount > 0 and TooltipTranslationHook.looksEnglishName(text) then
                local okn, translationMap, full = pcall(TooltipTranslationHook.translateName, text, target)
                if okn and translationMap then
                    outputList[#outputList + 1] = { text = translationMap .. " |cff999999(" .. TooltipTranslationHook.trim(text) .. ")|r", full = full, name = true }
                else
                    pcall(TooltipTranslationHook.collectMatchingEntries, text)
                end
            end
        elseif isCallOk and TooltipTranslationHook.readable(text) and text ~= "" and text ~= HEADER then
            local okc, itemCount = pcall(TooltipTranslationHook.resolveEnglishWords, text)
            if okc and itemCount > 0 then
                local okt, rowEntry = pcall(TooltipTranslationHook.translateLine, text, target)
                if okt and rowEntry then outputList[#outputList + 1] = rowEntry end
            end
        end
    end
    if #outputList == 0 then return end
    tooltip.wctDone = true
    tooltip:AddLine(" ")
    tooltip:AddLine(HEADER, 0.478, 0.855, 0.831)
    for _, rowEntry in ipairs(outputList) do
        if rowEntry.name then
            tooltip:AddLine(rowEntry.text, 1, 0.82, 0, true)
        elseif rowEntry.full then
            tooltip:AddLine(rowEntry.text, 0.6, 1, 0.6, true)
        else
            local formatLocalizedLabel = target == "ko" and "용어 풀이: " or ""
            tooltip:AddLine(formatLocalizedLabel .. rowEntry.text, 0.62, 0.8, 0.62, true)
        end
    end
    tooltip:Show()
end

local hooked = {}

local SETTERS = {
    "SetAction", "SetBagItem", "SetInventoryItem", "SetHyperlink", "SetItemByID", "SetSpellByID",
    "SetSpellBookItem", "SetShapeshift", "SetPetAction", "SetTalent", "SetUnitAura", "SetUnitBuff",
    "SetUnitDebuff", "SetTotem", "SetTrainerService", "SetCraftSpell", "SetCraftItem", "SetTradeSkillItem",
    "SetMerchantItem", "SetBuybackItem", "SetLootItem", "SetLootRollItem", "SetQuestItem", "SetQuestLogItem",
    "SetQuestRewardSpell", "SetQuestLogRewardSpell", "SetAuctionItem", "SetInboxItem", "SetSendMailItem",
    "SetTradePlayerItem", "SetTradeTargetItem", "SetMountBySpellID", "SetToyByItemID", "SetCompanionPet",
}

function TooltipTranslationHook.bindTooltip(tt, useSetters)
    if not tt or hooked[tt] then return end
    hooked[tt] = true
    tt:HookScript("OnTooltipCleared", function(self) self.wctDone = nil end)
    
    tt:HookScript("OnShow", function(self) pcall(TooltipTranslationHook.processIncomingEntry, self) end)
    if useSetters then
        pcall(tt.HookScript, tt, "OnTooltipSetItem", TooltipTranslationHook.processIncomingEntry)
        pcall(tt.HookScript, tt, "OnTooltipSetSpell", TooltipTranslationHook.processIncomingEntry)
        for _, resolveCallback in ipairs(SETTERS) do
            if type(tt[resolveCallback]) == "function" then
                pcall(hooksecurefunc, tt, resolveCallback, function(self) pcall(TooltipTranslationHook.processIncomingEntry, self) end)
            end
        end
    end
end

function TooltipTranslationHook.registerTooltipHooks()
    local processor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
    for _, tt in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2,
        ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, EmbeddedItemTooltip }) do
        
        pcall(TooltipTranslationHook.bindTooltip, tt, true)
    end
    if processor then
        local function post(tt, data)
            
            if data and Enum.TooltipDataType.Unit and data.type == Enum.TooltipDataType.Unit then return end
            pcall(TooltipTranslationHook.processIncomingEntry, tt)
        end
        if TooltipDataProcessor.AllTypes then
            TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, post)
        else
            for name, entityID in pairs(Enum.TooltipDataType) do
                if name ~= "Unit" and type(entityID) == "number" then
                    pcall(TooltipDataProcessor.AddTooltipPostCall, entityID, post)
                end
            end
        end
    end
end

-----------------------------------------------------------------------------
-- Handle Tooltip Collect Command
-----------------------------------------------------------------------------
function ns.HandleTooltipCollectCommand(arg)
    local savedDB = ns.db
    if not savedDB then return end
    local anchorTarget = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. s) end
    if arg == "clear" or arg == "초기화" or arg == "reset" then
        savedDB.collected, savedDB.collectedCount = {}, 0
        lookupCache = {}
        if ns.RestartBackgroundLexiconScan then ns.RestartBackgroundLexiconScan() end
        anchorTarget(L.collectCleared)
        return
    end
    local n = 0
    for _ in pairs(savedDB.collected or {}) do n = n + 1 end
    anchorTarget(L.collectCount:format(n))
    anchorTarget(L.collectHow)
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then prevLogin() end
    local isCallOk, errorObj = pcall(TooltipTranslationHook.registerTooltipHooks)
    if not isCallOk and ns.status then ns.status.lastError = "tooltip: " .. tostring(errorObj) end
end

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
TooltipTranslationHook.HandleTooltipCollectCommand = ns.HandleTooltipCollectCommand
TooltipTranslationHook.FindSimilarGlossaryEntries = ns.FindSimilarGlossaryEntries
TooltipTranslationHook.IsTooltipSectionBoundary = ns.IsTooltipSectionBoundary
