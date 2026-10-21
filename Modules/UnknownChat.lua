--===========================================================================
-- EzWoW - Chat Translator
-- Modules/UnknownChat.lua : Untranslated Chat Segment Collector & Viewer
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local UnknownTermLogger = ns.UnknownTermLogger or {}
ns.UnknownTermLogger = UnknownTermLogger

local NOISE = {}
for boxWidth in ("wzzwjc lxqwzn tdzz mmm ny hanxiao crownless encore ing esw golhamz qjqtk qudtls shiling ou bing oldguard vae victis azerothcompendium dungeonjournal"):gmatch("%S+") do NOISE[boxWidth] = true end
local URL_PARTS = { http = true, https = true, www = true, com = true, co = true, net = true, org = true, youtube = true, youtu = true, google = true, twitch = true, tv = true }
function UnknownTermLogger.usefulUnknown(lang, word)
    if type(word) ~= "string" or word == "" then return false end
    if NOISE[word] then return false end
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

function ns.RecordUnknownChat(text, lang, gloss)
    if not ns.db or not gloss.unknown or #gloss.unknown == 0 then return end
    local savedDB = ns.db.unknownChat
    if type(savedDB) ~= "table" then savedDB = {words = {}, samples = {}}; ns.db.unknownChat = savedDB end
    
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
    for _, item in ipairs(sourceWords) do
        local lang, word = item[1], item[2]
        local lookupKey = lang .. ":" .. word
        if not visitedMap[lookupKey] and UnknownTermLogger.usefulUnknown(lang, word) then
            visitedMap[lookupKey] = true
            if savedDB.words[lookupKey] then savedDB.words[lookupKey] = savedDB.words[lookupKey] + 1
            elseif wordCount < 500 then savedDB.words[lookupKey], wordCount = 1, wordCount + 1 end
        end
    end
    ns.unknownCount = wordCount
    if UnknownTermLogger.containsUsefulUnknown(lang, gloss) and gloss.cover < 70 and #text <= 300 then
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
    local L = ns.L or {}
    if not savedDB then ns.OpenCopyableChatDialog(L.unknownEmpty or (GetLocale and GetLocale() == "koKR" and "아직 수집된 미등록 표현이 없습니다." or "No unknown expressions collected yet.")) return end
    local sorted = {}
    for word, totalCount in pairs(savedDB.words) do
        local lang, term = word:match("^([^:]+):(.*)$")
        if lang and UnknownTermLogger.usefulUnknown(lang, term) then sorted[#sorted + 1] = {word, totalCount} end
    end
    table.sort(sorted, function(a, b) if a[2] == b[2] then return a[1] < b[1] end return a[2] > b[2] end)
    local lineList = {"Untranslated chat expressions / 미등록 채팅 표현"}
    for index = 1, math.min(#sorted, 100) do lineList[#lineList + 1] = sorted[index][2] .. "  " .. sorted[index][1] end
    lineList[#lineList + 1] = "\nSamples / 문장 예시"
    local retained = {}
    for _, sample in ipairs(savedDB.samples) do
        local sourceVal, text = sample:match("^([^:]+):%s*(.*)$")

        local body = text and text:gsub("%b[]", "")
        local greenVal = sourceVal and body and ns.TranslateChatMessageLine and ns.TranslateChatMessageLine(body, sourceVal, ns.ResolveTargetLanguageCode(), {outgoing=true})
        if greenVal and UnknownTermLogger.containsUsefulUnknown(sourceVal, greenVal) then
            retained[#retained + 1] = sample
            lineList[#lineList + 1] = sample
        end
    end
    savedDB.samples = retained
    ns.OpenCopyableChatDialog(table.concat(lineList, "\n"), L.unknownCopyTitle or (GetLocale and GetLocale() == "koKR" and "미등록 표현 전체 복사: Ctrl+C" or "Copy unknown expressions: Ctrl+C"))
end
