--===========================================================================
-- EzWoW - Chat Translator
-- Modules/OutgoingAndDict.lua : Outgoing Chat Translator & Custom User Dictionary
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local OutgoingChatComposer = ns.OutgoingChatComposer or {}
ns.OutgoingChatComposer = OutgoingChatComposer
local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })

function OutgoingChatComposer.printAddonChatMessage(s) DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. s) end
function OutgoingChatComposer.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-----------------------------------------------------------------------------
-- Resolve Script Lang
-----------------------------------------------------------------------------
function OutgoingChatComposer.resolveScriptLang(text)
    if text:find("\234[\176-\191]") or text:find("\235") or text:find("\236") or text:find("\237[\128-\158]") or text:find("\227\132[\177-\191]") or text:find("\227\133") or text:find("\227\134[\128-\142]") then
        return "ko"
    end
    if text:find("\227\129") or text:find("\227\130") or text:find("\227\131") then return "ja" end
    if text:find("[\228-\233][\128-\191][\128-\191]") then return "zh" end
    if text:find("\208") or text:find("\209") then return "ru" end
    if text:find("%a") then return "en" end
end

-----------------------------------------------------------------------------
-- Resolve Langs For
-----------------------------------------------------------------------------
local backup = {}   
ns.customVersion = 0

function OutgoingChatComposer.resolveLangsFor(term)
    local langCode = OutgoingChatComposer.resolveScriptLang(term)
    if langCode == "en" then return { "en", "es" } end   
    if langCode then return { langCode } end
    return {}
end

function OutgoingChatComposer.insertDictionaryTerm(langCode, key, len, term, meaning)
    local dict = ns.Dict[langCode]
    if not dict then dict = {}; ns.Dict[langCode] = dict end
    local entityID = langCode .. "\1" .. key
    if backup[entityID] == nil then backup[entityID] = dict[key] or false end
    dict[key] = { "", "", term, custom = meaning }
    if ns.DictMaxLen and (ns.DictMaxLen[langCode] or 1) < len then ns.DictMaxLen[langCode] = len end
end

function OutgoingChatComposer.removeDictionaryTerm(langCode, key)
    local dict = ns.Dict[langCode]
    local entityID = langCode .. "\1" .. key
    if dict then dict[key] = backup[entityID] or nil end
    backup[entityID] = nil
end

local syncCustomIndex

function ns.CompileCustomGlossaryIndex()
    local savedDB = ns.db
    if not savedDB or not ns.Dict or not ns.NormalizeGlossaryLookupKey then return end
    savedDB.custom = savedDB.custom or {}
    for langCode, words in pairs(savedDB.custom) do
        for key, boxWidth in pairs(words) do
            local _, len = ns.NormalizeGlossaryLookupKey(boxWidth[1])
            OutgoingChatComposer.insertDictionaryTerm(langCode, key, len, boxWidth[1], boxWidth[2])
        end
    end
    syncCustomIndex()
    ns.customVersion = (ns.customVersion or 0) + 1
end

syncCustomIndex = function()
    local entryList, prefixes, maxLen = {}, {}, 0
    for _, words in pairs(ns.db.custom or {}) do
        for key, boxWidth in pairs(words) do
            local _, len = ns.NormalizeGlossaryLookupKey(boxWidth[1])
            entryList[key] = { "", "", boxWidth[1], custom = boxWidth[2] }
            maxLen = math.max(maxLen, len)
            for index = 1, #key do prefixes[key:sub(1, index)] = true end
        end
    end
    ns.CustomEntries, ns.CustomPrefixes, ns.CustomMaxLen = entryList, prefixes, maxLen
end

function OutgoingChatComposer.addWord(arg)
    local term, meaning = arg:match("^(.-)%s*=%s*(.+)$")
    term = term and OutgoingChatComposer.trim(term)
    if not term or term == "" or not meaning or OutgoingChatComposer.trim(meaning) == "" then OutgoingChatComposer.printAddonChatMessage(L.addUsage) return end
    meaning = OutgoingChatComposer.trim(meaning)
    local key, len = ns.NormalizeGlossaryLookupKey(term)
    local langs = OutgoingChatComposer.resolveLangsFor(term)
    if key == "" or #langs == 0 then OutgoingChatComposer.printAddonChatMessage(L.addUsage) return end
    ns.db.custom = ns.db.custom or {}
    for _, langCode in ipairs(langs) do
        ns.db.custom[langCode] = ns.db.custom[langCode] or {}
        ns.db.custom[langCode][key] = { term, meaning }
        OutgoingChatComposer.insertDictionaryTerm(langCode, key, len, term, meaning)
    end
    syncCustomIndex()
    ns.customVersion = (ns.customVersion or 0) + 1
    OutgoingChatComposer.printAddonChatMessage(L.addDone:format(term, meaning))
end

function OutgoingChatComposer.delWord(arg)
    local term = OutgoingChatComposer.trim(arg or "")
    if term == "" then OutgoingChatComposer.printAddonChatMessage(L.addUsage) return end
    local key = ns.NormalizeGlossaryLookupKey(term)
    local found = false
    for langCode, words in pairs(ns.db.custom or {}) do
        if words[key] then
            words[key] = nil
            OutgoingChatComposer.removeDictionaryTerm(langCode, key)
            found = true
        end
    end
    syncCustomIndex()
    ns.customVersion = (ns.customVersion or 0) + 1
    OutgoingChatComposer.printAddonChatMessage((found and L.delDone or L.delNone):format(term))
end

function OutgoingChatComposer.listWords()
    local visitedMap, lineList = {}, {}
    for _, words in pairs(ns.db.custom or {}) do
        for key, boxWidth in pairs(words) do
            if not visitedMap[key] then
                visitedMap[key] = true
                lineList[#lineList + 1] = boxWidth[1] .. " = " .. boxWidth[2]
            end
        end
    end
    if #lineList == 0 then OutgoingChatComposer.printAddonChatMessage(L.listEmpty) return end
    table.sort(lineList)
    ns.OpenCopyableChatDialog(table.concat(lineList, "\n"), L.listTitle:format(#lineList))
end

local OUT_CODES = {
    en = "en", eng = "en", ["영어"] = "en",
    de = "de", ger = "de", ["독일어"] = "de",
    fr = "fr", fre = "fr", ["프랑스어"] = "fr",
    zh = "zhCN", cn = "zhCN", ["중국어"] = "zhCN",
    tw = "zhTW",
    ru = "ru", ["러시아어"] = "ru",
    ja = "ja", jp = "ja", ["일본어"] = "ja",
    es = "es", ["스페인어"] = "es",
    ko = "ko", kr = "ko", ["한국어"] = "ko",
}
ns.OUT_CODES = OUT_CODES

function OutgoingChatComposer.normalizeWhitespaceText(s, target)
    s = s:gsub("%s+", " ")
    if target == "zhCN" or target == "zhTW" or target == "ja" then
        local prev
        repeat
            prev = s
            s = s:gsub("([\227-\233][\128-\191][\128-\191]) ([\227-\233][\128-\191][\128-\191])", "%1%2")
        until s == prev
    end
    return OutgoingChatComposer.trim(s)
end

function ns.TranslateOutgoing(text, target)
    text = OutgoingChatComposer.trim(text or "")
    if text == "" then return nil end
    local sourceData = (ns.DetectDominantScriptLanguage and ns.DetectDominantScriptLanguage(text)) or OutgoingChatComposer.resolveScriptLang(text) or ns.SAME_SOURCE[ns.CLIENT_TARGET]
    local greenVal = ns.TranslateChatMessageLine(text, sourceData, target, { outgoing = true })
    if greenVal and greenVal.coverageTotal == 0 then return OutgoingChatComposer.normalizeWhitespaceText(greenVal.plain, target), 100, {} end
    if not greenVal or greenVal.found == 0 then return nil, 0, {} end
    return OutgoingChatComposer.normalizeWhitespaceText(greenVal.plain, target), greenVal.cover or 0, greenVal.unknown or {}
end

function OutgoingChatComposer.launchChatWith(text)
    local function goVal()
        if ChatFrame_OpenChat then
            ChatFrame_OpenChat(text)
        elseif ChatFrameUtil and ChatFrameUtil.OpenChat then
            ChatFrameUtil.OpenChat(text)
        else
            local inputBox = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
                or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
            if inputBox and inputBox.Insert then
                inputBox:Insert(text)
            end
        end
    end
    
    if C_Timer and C_Timer.After then C_Timer.After(0, goVal) else goVal() end
end

function OutgoingChatComposer.translateOutgoingChatHook(target, text)
    if not text or OutgoingChatComposer.trim(text) == "" then OutgoingChatComposer.printAddonChatMessage(L.outUsage) return end
    local outputList, cover, unknown = ns.TranslateOutgoing(text, target)
    if not outputList then OutgoingChatComposer.printAddonChatMessage(L.outNone) return end
    OutgoingChatComposer.printAddonChatMessage(L.outDone:format(ns.TARGET_NAME[target] or target, cover))
    if unknown and #unknown > 0 then OutgoingChatComposer.printAddonChatMessage(L.outLeft:format(table.concat(unknown, ", "))) end
    OutgoingChatComposer.launchChatWith(outputList)
end

-----------------------------------------------------------------------------
-- Search Dictionary
-----------------------------------------------------------------------------
local SEARCH_LANG_ORDER = { "en", "ko", "zh", "ru", "ja", "es" }

function ns.SearchDictionary(query)
    query = OutgoingChatComposer.trim(query or "")
    if query == "" or not ns.Dict or not ns.NormalizeGlossaryLookupKey then return {} end
    local qKey = ns.NormalizeGlossaryLookupKey(query)
    local qLow = query:lower()
    local target = (ns.ResolveTargetLanguageCode and ns.ResolveTargetLanguageCode()) or "ko"
    local translationMap = ns.TR and ns.TR[target]
    local exact, partial, visitedMap = {}, {}, {}

    local function addMatch(tag, term, meaning, isExact)
        local line = ("[%s] %s → %s"):format(tag, term, meaning)
        if visitedMap[line] then return end
        visitedMap[line] = true
        if isExact then
            exact[#exact + 1] = line
        else
            partial[#partial + 1] = line
        end
    end

    for _, langCode in ipairs(SEARCH_LANG_ORDER) do
        local dict = ns.Dict[langCode]
        if dict then
            local tag = (ns.L and ns.L.tag and ns.L.tag[langCode]) or langCode:upper()
            for key, entry in pairs(dict) do
                local term = entry[3] or key
                local koVal = entry[1] or ""
                local enVal = entry[2] or ""
                local tMeaning = entry.custom or (target == "ko" and koVal) or (target == "en" and enVal)
                    or (translationMap and translationMap[enVal:lower()]) or enVal
                local display = tMeaning
                if not entry.custom and target ~= "ko" and koVal ~= "" and koVal ~= tMeaning then
                    display = display .. " (" .. koVal .. ")"
                elseif not entry.custom and target == "ko" and enVal ~= "" and enVal:lower() ~= term:lower() and enVal ~= koVal then
                    display = display .. " (" .. enVal .. ")"
                end
                if key == qKey or term:lower() == qLow or koVal:lower() == qLow or enVal:lower() == qLow or tMeaning:lower() == qLow then
                    addMatch(tag, term, display, true)
                elseif (qKey ~= "" and key:find(qKey, 1, true))
                    or term:lower():find(qLow, 1, true)
                    or koVal:lower():find(qLow, 1, true)
                    or enVal:lower():find(qLow, 1, true)
                    or tMeaning:lower():find(qLow, 1, true) then
                    addMatch(tag, term, display, false)
                end
            end
        end
    end
    table.sort(exact)
    table.sort(partial)
    local outputList = {}
    for index = 1, #exact do outputList[#outputList + 1] = exact[index] end
    for index = 1, #partial do outputList[#outputList + 1] = partial[index] end
    return outputList
end

function OutgoingChatComposer.searchWords(arg)
    local query = OutgoingChatComposer.trim(arg or "")
    if query == "" then
        OutgoingChatComposer.printAddonChatMessage(L.searchUsage or "Usage: /ezct search <word>")
        return
    end
    local results = ns.SearchDictionary(query)
    if #results == 0 then
        OutgoingChatComposer.printAddonChatMessage((L.searchNone or "No matching dictionary entries found: %s"):format(query))
        return
    end
    OutgoingChatComposer.printAddonChatMessage((L.searchTitle or "Dictionary search (%s): %d matches"):format(query, #results))
    for index = 1, math.min(#results, 15) do
        OutgoingChatComposer.printAddonChatMessage("  " .. results[index])
    end
end

function OutgoingChatComposer.assignChatEnabled(state)
    if not ns.db or not ns.db.chat then return end
    ns.db.chat.enabled = state and true or false
    if ns.RefreshOptionsUI then ns.RefreshOptionsUI() end
    OutgoingChatComposer.printAddonChatMessage(state and (L.toggleOn or "Chat translation: ON") or (L.toggleOff or "Chat translation: OFF"))
end

-----------------------------------------------------------------------------
-- Show Collected
-----------------------------------------------------------------------------
function ns.ShowCollected()
    local lineList = {}
    for _, entryValue in pairs((ns.db and ns.db.collected) or {}) do lineList[#lineList + 1] = entryValue end
    if #lineList == 0 then OutgoingChatComposer.printAddonChatMessage(L.collectedEmpty) return end
    table.sort(lineList)
    ns.OpenCopyableChatDialog(table.concat(lineList, "\n"), L.collectedTitle:format(#lineList))
end

function ns.ShowHelp()
    ns.OpenCopyableChatDialog(L.help, L.helpTitle)
end

function ns.HandleGlossarySlashCommand(raw)
    local cmd, rest = raw:match("^(%S+)%s*(.-)$")
    if not cmd then return false end
    local lcVal = cmd:lower()
    if lcVal == "on" or lcVal == "enable" or lcVal == "켜기" then OutgoingChatComposer.assignChatEnabled(true) return true end
    if lcVal == "off" or lcVal == "disable" or lcVal == "끄기" then OutgoingChatComposer.assignChatEnabled(false) return true end
    if lcVal == "search" or lcVal == "find" or lcVal == "검색" or lcVal == "찾기" then OutgoingChatComposer.searchWords(rest) return true end
    if lcVal == "add" or lcVal == "추가" then OutgoingChatComposer.addWord(rest) return true end
    if lcVal == "del" or lcVal == "delete" or lcVal == "삭제" then OutgoingChatComposer.delWord(rest) return true end
    if lcVal == "list" or lcVal == "목록" then OutgoingChatComposer.listWords() return true end
    if lcVal == "help" or lcVal == "도움말" or lcVal == "명령어" then ns.ShowHelp() return true end
    if lcVal == "collected" then ns.ShowCollected() return true end
    local target = OUT_CODES[lcVal]
    if target then OutgoingChatComposer.translateOutgoingChatHook(target, rest) return true end
    return false
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then prevLogin() end
    pcall(ns.CompileCustomGlossaryIndex)
end

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
OutgoingChatComposer.CompileCustomGlossaryIndex = ns.CompileCustomGlossaryIndex
OutgoingChatComposer.HandleGlossarySlashCommand = ns.HandleGlossarySlashCommand
