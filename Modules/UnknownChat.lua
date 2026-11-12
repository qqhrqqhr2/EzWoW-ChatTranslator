--===========================================================================
-- EzWoW - Chat Translator
-- Modules/UnknownChat.lua : Untranslated Chat Segment Collector & Viewer
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local UnknownTermLogger = ns.UnknownTermLogger or {}
ns.UnknownTermLogger = UnknownTermLogger

-- what /ezct unknown puts in the copy box (sized to fit one comment)
local MAX_EXPORT_WORDS, MAX_EXPORT_SAMPLES = 80, 15
-- a chat line with a "copy list" link once this many new expressions are collected
local NOTICE_STEP = 20
-- where players send the list (the addon's official project page)
ns.COMMENTS_URL = "https://www.curseforge.com/wow/addons/wowchattranslator/comments"

local NOISE = {}
for boxWidth in ("wzzwjc lxqwzn tdzz mmm ny hanxiao crownless encore ing esw golhamz qjqtk qudtls shiling ou bing oldguard vae victis azerothcompendium dungeonjournal showtooltip castsequence lua"):gmatch("%S+") do NOISE[boxWidth] = true end
local URL_PARTS = { http = true, https = true, www = true, com = true, co = true, net = true, org = true, youtube = true, youtu = true, google = true, twitch = true, tv = true }
function UnknownTermLogger.usefulUnknown(lang, word)
    if type(word) ~= "string" or word == "" then return false end
    if NOISE[word] then return false end
    -- keyboard mashing ("asdf", "aaaa") and long joined-up settings words
    if #word >= 3 and word:match("^%a+$") and word == word:sub(1, 1):rep(#word) then return false end
    if word:find("asdf", 1, true) or word:find("qwer", 1, true) or word:find("zxcv", 1, true) then return false end
    if #word > 20 and word:match("^%a+$") then return false end
    if word:find("%a") and word:find("%d") then return false end
    if word:find("discord.gg",1,true) or word:find("https?://") then return false end
    -- pieces of web links ("https", "www", "gg/foreverwow", "com/watch") are not chat words
    if word:find("/", 1, true) or URL_PARTS[word] then return false end
    
    if #word <= 1 or (#word == 3 and word:byte(1) >= 224) then return false end
    if ns.LookupSlashCompoundTranslation and ns.LookupSlashCompoundTranslation(word, lang, "ko") then return false end
    if ns.MatchChatPhrasePattern and ns.MatchChatPhrasePattern(word, lang, "ko") then return false end
    local dictionaries = ns.Dict or {}
    if dictionaries[lang] and dictionaries[lang][word] then return false end
    if word:match("^[%w%p%s]+$") and dictionaries.en and dictionaries.en[word] then return false end
    if lang == "en" and dictionaries.es and dictionaries.es[word] then return false end
    return true
end
function UnknownTermLogger.containsUsefulUnknown(lang, gloss)
    if not gloss then return false end
    for sourceVal, words in pairs(gloss.unknownByLanguage or {[lang] = gloss.unknown or {}}) do
        for _, word in ipairs(words) do
            if UnknownTermLogger.usefulUnknown(sourceVal, word) then return true end
        end
    end
    return false
end

-- The player's own language and how its letters look in UTF-8: a line with
-- them was written by someone who speaks it (e.g. a Korean guild ad with an
-- English guild name), so its foreign words are names, not chat to learn.
local OWN_SCRIPT = {
    koKR = { "ko", "[\234-\237][\128-\191][\128-\191]" },
    zhCN = { "zh", "[\228-\233][\128-\191][\128-\191]" },
    zhTW = { "zh", "[\228-\233][\128-\191][\128-\191]" },
    ruRU = { "ru", "[\208\209][\128-\191]" },
}

function UnknownTermLogger.writtenInOwnLanguage(text, lang)
    local own = OWN_SCRIPT[GetLocale and GetLocale() or ""]
    if not own or lang == own[1] then return false end
    return text:find(own[2]) ~= nil
end

-- words inside <...>, {...}, [...], "..." and similar are guild, item or
-- player names
local NAME_BRACKETS = { "%b<>", "%b{}", "%b[]", "%b()", '"[^"]*"', "\227\128\140.-\227\128\141", "\194\171.-\194\187" }
function UnknownTermLogger.namesInBrackets(text)
    local names = {}
    for _, pattern in ipairs(NAME_BRACKETS) do
        for part in text:gmatch(pattern) do
            for word in part:lower():gmatch("[%w'%-]+") do names[word] = true end
        end
    end
    return names
end

-- the list was first collected without the rules above: start it again once
local UNKNOWN_LIST_VERSION = 2

function ns.RecordUnknownChat(text, lang, gloss)
    if not ns.db or not gloss.unknown or #gloss.unknown == 0 then return end
    if type(text) ~= "string" or UnknownTermLogger.writtenInOwnLanguage(text, lang) then return end
    local savedDB = ns.db.unknownChat
    if type(savedDB) ~= "table" or savedDB.v ~= UNKNOWN_LIST_VERSION then
        savedDB = { v = UNKNOWN_LIST_VERSION, words = {}, samples = {} }
        ns.db.unknownChat = savedDB
        ns.db.unknownNoticed = nil
        ns.unknownCount = nil
    end
    local inBrackets = UnknownTermLogger.namesInBrackets(text)
    
    if ns.unknownCount == nil or ns.unknownCustom ~= ns.customVersion then
        local wordCount = 0
        for lookupKey in pairs(savedDB.words) do
            local sourceVal, term = lookupKey:match("^([^:]+):(.*)$")
            if sourceVal and UnknownTermLogger.usefulUnknown(sourceVal, term) then wordCount = wordCount + 1
            else savedDB.words[lookupKey] = nil end
        end
        ns.unknownCount, ns.unknownCustom = wordCount, ns.customVersion
    end
    local wordCount = ns.unknownCount
    local visitedMap = {}
    local sourceWords = {}
    for sourceVal, words in pairs(gloss.unknownByLanguage or {[lang] = gloss.unknown}) do
        for _, word in ipairs(words) do sourceWords[#sourceWords+1] = {sourceVal, word} end
    end
    local recorded = false
    for _, item in ipairs(sourceWords) do
        local lang, word = item[1], item[2]
        local lookupKey = lang .. ":" .. word
        if not visitedMap[lookupKey] and not inBrackets[word] and UnknownTermLogger.usefulUnknown(lang, word) then
            visitedMap[lookupKey] = true
            recorded = true
            if savedDB.words[lookupKey] then savedDB.words[lookupKey] = savedDB.words[lookupKey] + 1
            elseif wordCount < 500 then savedDB.words[lookupKey], wordCount = 1, wordCount + 1 end
        end
    end
    ns.unknownCount = wordCount
    if recorded and gloss.cover < 70 and #text <= 300 then
        local sample = lang .. ": " .. text
        for index, previousVal in ipairs(savedDB.samples) do
            if previousVal == sample then table.remove(savedDB.samples, index); break end
        end
        while #savedDB.samples >= 100 do table.remove(savedDB.samples, 1) end
        savedDB.samples[#savedDB.samples + 1] = sample
    end
end
function ns.ShowUnknownChat()
    local savedDB = ns.db and ns.db.unknownChat
    if type(savedDB) == "table" and savedDB.v ~= UNKNOWN_LIST_VERSION then savedDB = nil end
    local L = ns.L or {}
    if not savedDB or not next(savedDB.words or {}) then ns.OpenCopyableChatDialog(L.unknownEmpty or (GetLocale and GetLocale() == "koKR" and "아직 수집된 미등록 표현이 없습니다." or "No unknown expressions collected yet.")) return end
    local sorted = {}
    for word, totalCount in pairs(savedDB.words) do
        local lang, term = word:match("^([^:]+):(.*)$")
        if lang and UnknownTermLogger.usefulUnknown(lang, term) then sorted[#sorted + 1] = {word, totalCount} end
    end
    table.sort(sorted, function(a, b) if a[2] == b[2] then return a[1] < b[1] end return a[2] > b[2] end)

    -- Players on other regions' realms send this list in (their chat never
    -- reaches the developer), so it is shaped to paste into one comment:
    -- a header, the most frequent words grouped by language, recent samples.
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local okMeta, version = false, nil
    if type(getMeta) == "function" then okMeta, version = pcall(getMeta, ADDON, "Version") end
    local lineList = {
        string.format("EzWoW - Chat Translator %s | client %s | result %s | %d words",
            okMeta and tostring(version) or "?", GetLocale and GetLocale() or "?",
            tostring(ns.ResolveTargetLanguageCode and ns.ResolveTargetLanguageCode() or "?"), #sorted),
    }
    local byLang, langOrder = {}, {}
    for index = 1, math.min(#sorted, MAX_EXPORT_WORDS) do
        local lang, term = sorted[index][1]:match("^([^:]+):(.*)$")
        if not byLang[lang] then byLang[lang] = {}; langOrder[#langOrder + 1] = lang end
        local list = byLang[lang]
        list[#list + 1] = sorted[index][2] .. " " .. term
    end
    for _, lang in ipairs(langOrder) do
        lineList[#lineList + 1] = ""
        lineList[#lineList + 1] = "[" .. lang .. "]"
        for _, row in ipairs(byLang[lang]) do lineList[#lineList + 1] = row end
    end
    local retained, shown = {}, {}
    for _, sample in ipairs(savedDB.samples) do
        local sourceVal, text = sample:match("^([^:]+):%s*(.*)$")

        local body = text and text:gsub("%b[]", "")
        local greenVal = sourceVal and body and ns.TranslateChatMessageLine and ns.TranslateChatMessageLine(body, sourceVal, ns.ResolveTargetLanguageCode(), {outgoing=true})
        if greenVal and UnknownTermLogger.containsUsefulUnknown(sourceVal, greenVal) then
            retained[#retained + 1] = sample
            shown[#shown + 1] = sample
        end
    end
    savedDB.samples = retained
    if #shown > 0 then
        lineList[#lineList + 1] = ""
        lineList[#lineList + 1] = "[samples]"
        for index = math.max(1, #shown - MAX_EXPORT_SAMPLES + 1), #shown do lineList[#lineList + 1] = shown[index] end
    end
    ns.OpenCopyableChatDialog(table.concat(lineList, "\n"),
        L.unknownCopyTitle or (GetLocale and GetLocale() == "koKR" and "미등록 표현 전체 복사: Ctrl+C" or "Copy unknown expressions: Ctrl+C"),
        L.unknownSendHint, true)
end

function ns.CountUnknownChat()
    local savedDB = ns.db and ns.db.unknownChat
    if type(savedDB) ~= "table" or savedDB.v ~= UNKNOWN_LIST_VERSION or type(savedDB.words) ~= "table" then return 0 end
    local count = 0
    for lookupKey in pairs(savedDB.words) do
        local lang, term = lookupKey:match("^([^:]+):(.*)$")
        if lang and UnknownTermLogger.usefulUnknown(lang, term) then count = count + 1 end
    end
    return count
end

-- After login, when enough new expressions have piled up since the last
-- notice: one chat line asking to send them in, with a link that opens the
-- copy box. Only in this chat window; nothing is sent anywhere.
function UnknownTermLogger.noticeIfPending()
    if not ns.db or not ns.UnknownListLink or not ns.CommentsPageLink then return end
    local count = ns.CountUnknownChat()
    local last = tonumber(ns.db.unknownNoticed) or 0
    if count < last then last = count; ns.db.unknownNoticed = count end
    if count < NOTICE_STEP or count < last + NOTICE_STEP then return end
    local L = ns.L or {}
    local fmt = L.unknownNotice
    if type(fmt) ~= "string" then return end
    local link = "|cff7ADAD4" .. ns.UnknownListLink(L.unknownNoticeLink or "[Copy list]") .. "|r"
    local page = "|cff7ADAD4" .. ns.CommentsPageLink(L.commentsLink or "[comment page]") .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. string.format(fmt, count, link, page))
    ns.db.unknownNoticed = count
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then pcall(prevLogin) end
    if C_Timer and C_Timer.After then
        C_Timer.After(15, function() pcall(UnknownTermLogger.noticeIfPending) end)
    end
end
