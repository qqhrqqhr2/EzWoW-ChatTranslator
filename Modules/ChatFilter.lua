--===========================================================================
-- EzWoW - Chat Translator
-- Modules/ChatFilter.lua : Real-Time Chat Channel Filter & Copyable Link Injector
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local ChatStreamFilter = ns.ChatStreamFilter or {}
ns.ChatStreamFilter = ChatStreamFilter
-- ns.L is replaced when the target language changes, so always read the current table
local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })
local hasSecret = ns.IsSecret
local safeString = ns.SafeString
local detectDominantScriptLang = ns.DetectDominantScriptLanguage
local translateTokenSequence = ns.TranslateChatMessageLine

-----------------------------------------------------------------------------
-- Clean Codes
-----------------------------------------------------------------------------
local KEEP = 600
local entryList, nextId = {}, 0
local lineCache, lineOrder = {}, {}

-----------------------------------------------------------------------------
-- Link Format
-- Current clients reserve the "addon" hyperlink type for addons: a click on
-- |Haddon:<addon>:...|h is handed to EventRegistry "SetItemRef" callbacks and
-- the default handler opens nothing for it, so SetItemRef never has to be
-- replaced. Links in the old private format ("wct:<id>" = translation,
-- "wctcopy:<id>" = copy) are still recognized when clicked.
-----------------------------------------------------------------------------
local LINK_GLOSS, LINK_COPY = "gloss", "copy"
local ADDON_LINK_HEAD = "addon:EzWoW-ChatTranslator:"
local ADDON_LINK_PATTERN = "^addon:EzWoW%-ChatTranslator:(%a+):(%d+)"
local useAddonLinks = type(EventRegistry) == "table" and type(EventRegistry.RegisterCallback) == "function"

function ChatStreamFilter.linkCode(action, id)
    if useAddonLinks then return ("|H%s%s:%d|h"):format(ADDON_LINK_HEAD, action, id) end
    return ("|H%s:%d|h"):format(action == LINK_COPY and "wctcopy" or "wct", id)
end

-- Returns action, numeric id, isLegacy for any link this addon has ever printed.
function ChatStreamFilter.parseLink(link)
    if not safeString(link) then return nil end
    local action, id = link:match(ADDON_LINK_PATTERN)
    if action then return action, tonumber(id), false end
    id = link:match("^wctcopy:(%d+)")
    if id then return LINK_COPY, tonumber(id), true end
    id = link:match("^wct:(%d+)")
    if id then return LINK_GLOSS, tonumber(id), true end
    return nil
end

function ChatStreamFilter.hasLegacyLink(msg)
    return msg:find("|Hwct:", 1, true) ~= nil or msg:find("|Hwctcopy:", 1, true) ~= nil
end

function ChatStreamFilter.hasOwnLink(msg)
    return msg:find("|H" .. ADDON_LINK_HEAD, 1, true) ~= nil or ChatStreamFilter.hasLegacyLink(msg)
end

function ChatStreamFilter.findLinkId(text)
    return text:match("|Haddon:EzWoW%-ChatTranslator:%a+:(%d+)") or text:match("|Hwctcopy:(%d+)") or text:match("|Hwct:(%d+)")
end

function ChatStreamFilter.cleanCodes(msg)
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    msg = msg:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    -- Protected text (|K...|k, e.g. names in bridged community chat) is
    -- unreadable to addons: keep it out of detection and copy text.
    msg = msg:gsub("|K.-|k", " "):gsub("|n", " ")
    return msg
end

function ChatStreamFilter.plainTextEntry(msg)
    return (ChatStreamFilter.cleanCodes(msg):gsub("|H.-|h(.-)|h", "%1"):gsub("||", "|"))
end

function ChatStreamFilter.detectText(msg)
    
    return (ChatStreamFilter.cleanCodes(msg):gsub("|H.-|h.-|h", " "))
end

function ChatStreamFilter.newEntry(text, lang, author)
    nextId = nextId + 1
    entryList[nextId] = { text = text, lang = lang, author = author }
    entryList[nextId - KEEP] = nil
    return nextId
end

function ChatStreamFilter.cacheLine(lineID, value)
    if not lineID then return end
    if lineCache[lineID] == nil then
        lineOrder[#lineOrder + 1] = lineID
        if #lineOrder > KEEP then
            lineCache[table.remove(lineOrder, 1)] = nil
        end
    end
    lineCache[lineID] = value
end

function ChatStreamFilter.injectClickableCopyLinks(msg, id)
    local outputList, index = {}, 1
    while index <= #msg do
        local rest = msg:sub(index)
        local code = rest:match("^|H.-|h.-|h") or rest:match("^|T.-|t")
            or rest:match("^|A.-|a") or rest:match("^|c%x%x%x%x%x%x%x%x") or rest:match("^|r")
            or rest:match("^|K.-|k") or rest:match("^|n")
        if code then
            outputList[#outputList + 1] = code
            index = index + #code
        else
            local start = index
            repeat
                if msg:sub(index, index + 1) == "||" then index = index + 2 else index = index + 1 end
            until index > #msg or (msg:sub(index, index) == "|" and msg:sub(index, index + 1) ~= "||")
            local text = msg:sub(start, index - 1)
            if text:find("%S") then
                outputList[#outputList + 1] = ChatStreamFilter.linkCode(LINK_COPY, id) .. text .. "|h"
            else
                outputList[#outputList + 1] = text
            end
        end
    end
    return table.concat(outputList)
end

local TAG_COLOR = { es = "ffbb88", ko = "a0e8a0", zh = "ffcc66", ja = "ff99cc", ru = "99ccff", en = "cccccc" }
local myName

ns.status = { method = "none", seen = 0, tagged = 0, lastError = nil, filterEvents = 0 }

local CHANNEL_KIND = {
    CHAT_MSG_CHANNEL = "public",
    CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "say", CHAT_MSG_EMOTE = "say",
    CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
    CHAT_MSG_PARTY = "group", CHAT_MSG_PARTY_LEADER = "group", CHAT_MSG_RAID = "group",
    CHAT_MSG_RAID_LEADER = "group", CHAT_MSG_RAID_WARNING = "group",
    CHAT_MSG_INSTANCE_CHAT = "group", CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
    CHAT_MSG_WHISPER = "whisper", CHAT_MSG_BN_WHISPER = "whisper",
}
ns.CHANNEL_KIND = CHANNEL_KIND

function ChatStreamFilter.copyOnly(msg, author)
    if not ns.db.chat.copyAll then return nil end
    if ChatStreamFilter.hasOwnLink(msg) then return nil end
    local id = ChatStreamFilter.newEntry(ChatStreamFilter.plainTextEntry(msg), nil, author)
    return ChatStreamFilter.injectClickableCopyLinks(msg, id)
end

function ChatStreamFilter.processIncomingEntry(msg, author, event)
    local savedDB = ns.db
    if not savedDB or not savedDB.chat.enabled or type(msg) ~= "string" or msg == "" then return nil end
    if ChatStreamFilter.hasOwnLink(msg) then return nil end
    local kind = event and CHANNEL_KIND[event]
    if kind and savedDB.chat.channels and savedDB.chat.channels[kind] == false then return ChatStreamFilter.copyOnly(msg, author) end
    ns.status.seen = ns.status.seen + 1
    if savedDB.chat.skipSelf and type(author) == "string" and author ~= "" then
        myName = myName or UnitName("player")
        if author:match("^[^%-]+") == myName then return ChatStreamFilter.copyOnly(msg, author) end
    end
    local lang = detectDominantScriptLang(ChatStreamFilter.detectText(msg))
    if not lang then return ChatStreamFilter.copyOnly(msg, author) end
    local targetKey = ns.ResolveTargetLanguageCode()

    local clean = ChatStreamFilter.detectText(msg):gsub("||", "|")
    local greenVal = translateTokenSequence(clean, lang, targetKey)
    if greenVal.foreignFound == 0 and (ns.SAME_SOURCE[targetKey] == lang or not savedDB.chat.langs[lang]) then return ChatStreamFilter.copyOnly(msg, author) end
    
    if ns.SAME_SOURCE[targetKey] == lang and (greenVal.foreignChars or 0) < 3 then return ChatStreamFilter.copyOnly(msg, author) end
    -- a translation that reads the same as the line itself is not shown again
    -- (a line in the reader's own language with words like "PvP" kept as they are)
    local function squash(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%s%p]", ""):lower()) end
    local sameText = squash(greenVal.plain) == squash(clean)
    if sameText and ns.SAME_SOURCE[targetKey] == lang then return ChatStreamFilter.copyOnly(msg, author) end
    if not savedDB.chat.langs[lang] or ns.SAME_SOURCE[targetKey] == lang then
        for _, sourceVal in ipairs({"en", "es", "ru", "zh", "ja", "ko"}) do
            if greenVal.languages[sourceVal] and savedDB.chat.langs[sourceVal] and ns.SAME_SOURCE[targetKey] ~= sourceVal then lang = sourceVal; break end
        end
    end
    local plainText = ChatStreamFilter.plainTextEntry(msg)
    local id = ChatStreamFilter.newEntry(plainText, lang, author)
    entryList[id].gloss = greenVal
    entryList[id].glossTarget = targetKey
    entryList[id].glossText = ChatStreamFilter.detectText(msg):gsub("||", "|")
    if ns.RecordUnknownChat then ns.RecordUnknownChat(plainText, lang, greenVal) end
    local body, wrapped = ChatStreamFilter.injectClickableCopyLinks(msg, id), true
    if savedDB.chat.hoverAll and not msg:find("|", 1, true) then
        body = ChatStreamFilter.linkCode(LINK_GLOSS, id) .. msg .. "|h"
        wrapped = true
    end
    local tag = ""
    if savedDB.chat.tag then
        tag = ("|cff%s%s[%s]|h|r "):format(TAG_COLOR[lang], ChatStreamFilter.linkCode(LINK_GLOSS, id), L.tag[lang])
    end
    local suffix, separate = "", nil
    if not sameText and savedDB.chat.inline and greenVal.found > 0 and greenVal.cover >= (savedDB.chat.minCover or 40) then
        
        local hanSource = (lang == "zh" or lang == "ja" or greenVal.languages.zh or greenVal.languages.ja)
        local conflict = (hanSource and targetKey == "ko") or (lang == "ko" and (targetKey == "zhCN" or targetKey == "zhTW"))
        if conflict then
            local meaning = (hanSource and greenVal.plainNoCJK or greenVal.plain):gsub("|", "||")
            separate = ChatStreamFilter.injectClickableCopyLinks(("    |cff88dd88↳ %s|r"):format(meaning), id)
        else
            local meaning = greenVal.plain:gsub("|", "||")
            suffix = ChatStreamFilter.injectClickableCopyLinks((" |cff88dd88(%s)|r"):format(meaning), id)
        end
    end
    ns.status.tagged = ns.status.tagged + 1
    return tag .. body .. suffix, separate
end

function ChatStreamFilter.noteError(err)
    ns.status.lastError = tostring(err)
end

-- Per-frame state lives in weak-keyed side tables: writing fields onto chat
-- frames would taint them for the default UI.
local separatePendingByFrame = setmetatable({}, { __mode = "k" })
local legacySweepQueued = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })

-----------------------------------------------------------------------------
-- Separate Translation Line
-- Chat frames never get an AddMessage hook. When the client opens or re-opens
-- a chat window it fills it in its own copy loop (read line, compare its
-- access id, AddMessage, next line); any addon hook on AddMessage runs inside
-- that loop and makes the next compare fail, and a hook can never be removed.
-- Instead the message filter queues the "↳" line, and on the next frame it is
-- printed with a plain AddMessage call from this addon's own timer, but only
-- if the chat line it belongs to really reached that frame (a filter also runs
-- for frames that later drop the line, e.g. another channel or a whisper that
-- went to its own window).
-----------------------------------------------------------------------------
local SEPARATE_SCAN = 40
local SEPARATE_MAX = 200

-- True when one of the newest lines of the frame carries the link id.
function ChatStreamFilter.frameShowsLink(frame, id, skipText)
    if type(frame.GetNumMessages) ~= "function" or type(frame.GetMessageInfo) ~= "function" then return true end
    local count = frame:GetNumMessages()
    if type(count) ~= "number" or hasSecret(count) then return true end
    local last = count - SEPARATE_SCAN + 1
    if last < 1 then last = 1 end
    for index = count, last, -1 do
        local text = frame:GetMessageInfo(index)
        if safeString(text) and text ~= skipText and ChatStreamFilter.findLinkId(text) == id then return true end
    end
    return false
end

function ChatStreamFilter.flushSeparate(frame)
    local pending = separatePendingByFrame[frame]
    separatePendingByFrame[frame] = nil
    if not pending then return end
    for _, item in ipairs(pending.list) do
        local isCallOk, shown = pcall(ChatStreamFilter.frameShowsLink, frame, item.id, item.text)
        if not isCallOk then ChatStreamFilter.noteError(shown) shown = false end
        if shown then
            local addOk, err = pcall(frame.AddMessage, frame, item.text)
            if not addOk then ChatStreamFilter.noteError(err) end
        end
    end
end

function ChatStreamFilter.queueSeparate(frame, outputList, separate)
    if not frame or type(frame.AddMessage) ~= "function" then return end
    if not (C_Timer and C_Timer.After) then return end
    local id = ChatStreamFilter.findLinkId(outputList)
    if not id then return end
    -- A window opened since the last pass gets its hover handlers next frame.
    if not hooked[frame] then ChatStreamFilter.queueBindAll() end
    local pending = separatePendingByFrame[frame]
    if not pending then
        pending = { list = {}, ids = {} }
        separatePendingByFrame[frame] = pending
        C_Timer.After(0, function() ChatStreamFilter.flushSeparate(frame) end)
    end
    if pending.ids[id] or #pending.list >= SEPARATE_MAX then return end
    pending.ids[id] = true
    pending.list[#pending.list + 1] = { id = id, text = separate }
end

function ChatStreamFilter.handleChatMessageEvent(self, event, msg, author, ...)
    
    if not safeString(msg) or hasSecret(author) or (author ~= nil and type(author) ~= "string") then return false end
    local lineID = select(9, ...)
    
    if hasSecret(lineID) or type(lineID) ~= "number" or lineID <= 0 then lineID = nil end
    local outputList, separate
    local activeCfg = ns.db and ns.db.chat
    local settings = activeCfg and table.concat({tostring(ns.ResolveTargetLanguageCode()), tostring(activeCfg.enabled), tostring(activeCfg.inline),
        tostring(activeCfg.minCover), tostring(activeCfg.tag), tostring(activeCfg.hoverAll), tostring(activeCfg.skipSelf),
        tostring(activeCfg.langs.ko), tostring(activeCfg.langs.zh), tostring(activeCfg.langs.ja), tostring(activeCfg.langs.ru), tostring(activeCfg.langs.en), tostring(activeCfg.langs.es),
        tostring(ns.customVersion or 0), tostring(activeCfg.copyAll),
        tostring((activeCfg.channels or {}).public), tostring((activeCfg.channels or {}).say),
        tostring((activeCfg.channels or {}).guild), tostring((activeCfg.channels or {}).group),
        tostring((activeCfg.channels or {}).whisper)}, ":")
    local cached = lineID and lineCache[lineID]
    if cached and cached.msg == msg and cached.author == author and cached.event == event and cached.settings == settings then
        outputList, separate = cached[1], cached[2]
    else
        local isCallOk, optionRef, sep = pcall(ChatStreamFilter.processIncomingEntry, msg, author, event)
        if not isCallOk then ChatStreamFilter.noteError(optionRef) optionRef, sep = nil, nil end
        outputList, separate = optionRef, sep
        ChatStreamFilter.cacheLine(lineID, { outputList, separate, msg = msg, author = author, event = event, settings = settings })
    end
    if not outputList then return false end
    if separate then ChatStreamFilter.queueSeparate(self, outputList, separate) end
    return false, outputList, author, ...
end

-- Note on CHAT_MSG_BN_WHISPER: the client only calls message filters when
-- every event argument is readable by addons. Battle.net whispers carry a
-- secret sender, so this filter is normally skipped for them and those lines
-- stay untranslated (no error, nothing rewritten). The registration is kept
-- so translation works again whenever the arguments are readable.
local EVENTS = {
    "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER",
}

function ChatStreamFilter.resolveAddFilter()
    if type(ChatFrame_AddMessageEventFilter) == "function" then
        return ChatFrame_AddMessageEventFilter
    end
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.AddMessageEventFilter) == "function" then
        return function(ev, fn) return ChatFrameUtil.AddMessageEventFilter(ev, fn) end
    end
end

function ChatStreamFilter.registerFilters()
    if ns.status.method == "filter" then return true end
    local add = ChatStreamFilter.resolveAddFilter()
    if not add then return false end
    local totalCount = 0
    for _, ev in ipairs(EVENTS) do
        local isCallOk, err = pcall(add, ev, ChatStreamFilter.handleChatMessageEvent)
        if isCallOk then totalCount = totalCount + 1 else ChatStreamFilter.noteError(err) end
    end
    ns.status.filterEvents = totalCount
    if totalCount > 0 then ns.status.method = "filter" return true end
    return false
end

pcall(ChatStreamFilter.registerFilters)

-----------------------------------------------------------------------------
-- Present Gloss
-----------------------------------------------------------------------------
function ChatStreamFilter.presentGloss(owner, id)
    local recordEntry = entryList[id]
    if not recordEntry then return end
    local targetKey = ns.ResolveTargetLanguageCode()
    if not recordEntry.gloss or recordEntry.glossTarget ~= targetKey then
        recordEntry.gloss = translateTokenSequence(recordEntry.glossText or recordEntry.text, recordEntry.lang, targetKey)
        recordEntry.glossTarget = targetKey
    end
    local greenVal = recordEntry.gloss
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.glossTitle:format(L.langName[recordEntry.lang]), 0.478, 0.855, 0.831)
    GameTooltip:AddLine(recordEntry.text, 0.929, 0.957, 0.969, true)
    if greenVal.found > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.rough, 1, 0.82, 0)
        GameTooltip:AddLine(greenVal.rough, 1, 1, 1, true)
        if #greenVal.terms > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.terms, 1, 0.82, 0)
            for _, resolvedValue in ipairs(greenVal.terms) do
                GameTooltip:AddDoubleLine(resolvedValue[1], resolvedValue[2], 0.9, 0.9, 0.9, 0.6, 1, 0.6)
            end
        end
    else
        GameTooltip:AddLine(L.noTerms, 0.655, 0.725, 0.773)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.clickHint, 0.655, 0.725, 0.773)
    if ns.ResolveTargetLanguageCode() == "ko" then
        local activeCfg = ns.db.chat
        local reason = not activeCfg.inline and "풀이 표시 꺼짐" or (greenVal.found == 0 and "인식한 표현 없음")
            or (greenVal.cover < (activeCfg.minCover or 40) and "인식률이 표시 기준보다 낮음") or "풀이 표시 조건 충족"
        GameTooltip:AddLine(("현재 설정: 인식률 %d%% / 기준 %d%% · %s"):format(greenVal.cover, activeCfg.minCover or 40, reason), 0.655, 0.725, 0.773, true)
    end
    GameTooltip:AddDoubleLine(" ", "EzWoW - Chat Translator", 0, 0, 0, 0.5, 0.5, 0.5)
    GameTooltip:Show()
    if _G.EzWoWTooltipTagSizer and _G.EzWoWTooltipTagSizer.Refit then pcall(_G.EzWoWTooltipTagSizer.Refit, GameTooltip) end
end

-----------------------------------------------------------------------------
-- Legacy Link Cleanup
-- Lines printed by an older version (or restored by a chat-history addon after
-- /reload) can still carry the old private link types. Their entries are gone
-- after a reload, and the default click handler does not know those types, so
-- on clients using addon links they are turned back into plain text in the
-- chat history. Skipped silently when the chat frame cannot rewrite history.
-- Without an AddMessage hook the history is checked when a window is first
-- bound and a few times after login (when restored lines arrive). The history
-- is only read first; it is rewritten only when an old link is really there.
-----------------------------------------------------------------------------
function ChatStreamFilter.stripLegacyLinks(text)
    return (text:gsub("|Hwctcopy:%d+|h(.-)|h", "%1"):gsub("|Hwct:%d+|h(.-)|h", "%1"))
end

function ChatStreamFilter.hasLegacyHistory(frame)
    if type(frame.GetNumMessages) ~= "function" or type(frame.GetMessageInfo) ~= "function" then return false end
    local count = frame:GetNumMessages()
    if type(count) ~= "number" or hasSecret(count) then return false end
    for index = 1, count do
        local text = frame:GetMessageInfo(index)
        if safeString(text) and ChatStreamFilter.hasLegacyLink(text) then return true end
    end
    return false
end

function ChatStreamFilter.sweepLegacyLinks(frame)
    if not frame then return end
    legacySweepQueued[frame] = nil
    if type(frame.TransformMessages) ~= "function" then return end
    local scanOk, found = pcall(ChatStreamFilter.hasLegacyHistory, frame)
    if not scanOk then ChatStreamFilter.noteError(found) return end
    if not found then return end
    local isCallOk, err = pcall(frame.TransformMessages, frame, function(entry)
        local message = type(entry) == "table" and entry.message
        return safeString(message) and ChatStreamFilter.hasLegacyLink(message) or false
    end, function(entry)
        if type(entry) == "table" and safeString(entry.message) then
            entry.message = ChatStreamFilter.stripLegacyLinks(entry.message)
        end
        return entry
    end)
    if not isCallOk then ChatStreamFilter.noteError(err) end
end

function ChatStreamFilter.queueLegacySweep(frame)
    if not frame or legacySweepQueued[frame] then return end
    legacySweepQueued[frame] = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() ChatStreamFilter.sweepLegacyLinks(frame) end)
    else
        ChatStreamFilter.sweepLegacyLinks(frame)
    end
end

-- Whisper windows are refilled by the client when reused, so only numbered
-- windows are checked.
function ChatStreamFilter.sweepAllLegacy()
    if not useAddonLinks then return end
    for frame in pairs(hooked) do
        if not frame.isTemporary then ChatStreamFilter.queueLegacySweep(frame) end
    end
end

-- Frames are bound (hover handlers only) once they are open; newly opened
-- ones are picked up by queueBindAll from the event frame below.
function ChatStreamFilter.isFrameOpen(frame)
    if not frame then return false end
    if frame.isTemporary then return frame.inUse == true end
    local id = frame.GetID and frame:GetID()
    if type(id) == "number" and id > 0 and type(FCF_IsChatWindowIndexActive) == "function" then
        local isCallOk, active = pcall(FCF_IsChatWindowIndexActive, id)
        if isCallOk then return active and true or false end
    end
    return frame.IsShown and frame:IsShown() or false
end

function ChatStreamFilter.bindFrame(frame)
    if not frame or hooked[frame] then return end
    if not ChatStreamFilter.isFrameOpen(frame) then return end
    hooked[frame] = true
    frame:HookScript("OnHyperlinkEnter", function(self, link)
        if not safeString(link) then return end
        local action, id = ChatStreamFilter.parseLink(link)
        if action == LINK_COPY then
            local recordEntry = id and entryList[id]
            if recordEntry and recordEntry.lang then ChatStreamFilter.presentGloss(self, id) end
        elseif action == LINK_GLOSS then
            if id then ChatStreamFilter.presentGloss(self, id) end
        elseif ns.ShowPlayerTooltip and ns.db and ns.db.chat.playerTip ~= false then
            ns.ShowPlayerTooltip(self, link)
        end
    end)
    frame:HookScript("OnHyperlinkLeave", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        if ns.HidePlayerTooltip then ns.HidePlayerTooltip(self) end
    end)
    -- No AddMessage hook on any chat frame (see "Separate Translation Line").
    if useAddonLinks and not frame.isTemporary then ChatStreamFilter.queueLegacySweep(frame) end
end

function ChatStreamFilter.bindAllFrames()
    for index = 1, (NUM_CHAT_WINDOWS or 10) do ChatStreamFilter.bindFrame(_G["ChatFrame" .. index]) end
    if CHAT_FRAMES then
        for _, displayName in ipairs(CHAT_FRAMES) do ChatStreamFilter.bindFrame(_G[displayName]) end
    end
end

local bindQueued = false
function ChatStreamFilter.queueBindAll()
    if bindQueued then return end
    bindQueued = true
    local function run()
        bindQueued = false
        local isCallOk, err = pcall(ChatStreamFilter.bindAllFrames)
        if not isCallOk then ChatStreamFilter.noteError(err) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end

-- Whisper windows and new chat windows are noticed through events on this
-- addon's own frame (never by hooking the window-opening functions, which run
-- in the middle of the default whisper handling), and bound on the next frame.
local windowWatcher = CreateFrame("Frame")
for _, eventName in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_BN_WHISPER_INFORM", "UPDATE_CHAT_WINDOWS" }) do
    pcall(windowWatcher.RegisterEvent, windowWatcher, eventName)
end
windowWatcher:SetScript("OnEvent", function()
    if ChatStreamFilter.loggedIn then ChatStreamFilter.queueBindAll() end
end)

-----------------------------------------------------------------------------
-- Open Copyable Chat Dialog
-----------------------------------------------------------------------------
local copy
function ns.OpenCopyableChatDialog(text, title)
    if not copy then
        copy = CreateFrame("Frame", "EzWoWChatTranslatorCopy", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        copy:SetSize(540, 96)
        copy:SetPoint("CENTER", 0, 120)
        ns.UIKit:ElevateModal(copy, 260)
        if copy.SetBackdrop then
            ns.UIKit:ApplyBackdrop(copy, 1, 1)
            copy:SetBackdropColor(0.071, 0.094, 0.122, 0.97)
            copy:SetBackdropBorderColor(0.478, 0.855, 0.831, 1.00)
        end
        copy:EnableMouse(true)
        copy:SetMovable(true)
        copy:RegisterForDrag("LeftButton")
        copy:SetScript("OnDragStart", copy.StartMoving)
        copy:SetScript("OnDragStop", copy.StopMovingOrSizing)

        copy.title = copy:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        copy.title:SetPoint("TOP", 0, -18)
        copy.title:SetTextColor(0.478, 0.855, 0.831)

        local inputBox = CreateFrame("EditBox", nil, copy, BackdropTemplateMixin and "BackdropTemplate" or nil)
        inputBox:SetSize(480, 24)
        inputBox:SetPoint("TOP", 0, -44)
        inputBox:SetFontObject(ChatFontNormal)
        inputBox:SetTextInsets(6, 6, 4, 4)
        inputBox:SetAutoFocus(false)
        inputBox:SetMaxLetters(0)
        if inputBox.SetBackdrop then
            ns.UIKit:ApplyBackdrop(inputBox, 1, 1)
            inputBox:SetBackdropColor(0.047, 0.067, 0.086, 0.96)
            inputBox:SetBackdropBorderColor(0.204, 0.298, 0.357, 1.00)
        end
        inputBox:SetScript("OnEditFocusGained", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.478, 0.855, 0.831, 1.00)
            end
        end)
        inputBox:SetScript("OnEditFocusLost", function(self)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0.204, 0.298, 0.357, 1.00)
            end
        end)
        inputBox:SetScript("OnEscapePressed", function() copy:Hide() end)
        inputBox:SetScript("OnEnterPressed", function() copy:Hide() end)
        
        inputBox:SetScript("OnTextChanged", function(self, userInput)
            if userInput and self:GetText() ~= copy.text then
                self:SetText(copy.text)
                self:HighlightText()
            end
        end)
        inputBox:SetScript("OnKeyUp", function(self, lookupKey)
            if lookupKey == "C" and IsControlKeyDown() then
                C_Timer.After(0.15, function() copy:Hide() end)
            end
        end)
        copy.eb = inputBox

        local close = CreateFrame("Button", nil, copy, BackdropTemplateMixin and "BackdropTemplate" or nil)
        close:SetSize(22, 22)
        close:SetPoint("TOPRIGHT", copy, "TOPRIGHT", -6, -6)
        if close.SetBackdrop then
            ns.UIKit:ApplyBackdrop(close, 1, 1)
            close:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
            close:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        end
        local dismissTxt = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        dismissTxt:SetPoint("CENTER")
        dismissTxt:SetText("X")
        dismissTxt:SetTextColor(0.929, 0.957, 0.969)
        close:SetScript("OnEnter", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.17, 0.26, 0.30, 1)
                self:SetBackdropBorderColor(0.478, 0.855, 0.831, 1)
            end
        end)
        close:SetScript("OnLeave", function(self)
            if self.SetBackdropColor then
                self:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
                self:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
            end
        end)
        close:SetScript("OnClick", function() copy:Hide() end)

        tinsert(UISpecialFrames, "EzWoWChatTranslatorCopy")
    end
    local multiline = text:find("\n", 1, true) ~= nil
    copy:SetSize(540, multiline and 360 or 96)
    copy.eb:SetMultiLine(multiline)
    copy.eb:SetSize(480, multiline and 280 or 24)
    copy.text = text
    copy.title:SetText(title or L.copyTitle)
    ns.UIKit:ElevateModal(copy, 260)
    copy.eb:SetFrameLevel(copy:GetFrameLevel() + 5)
    copy:Show()
    if copy.Raise then copy:Raise() end
    copy.eb:SetText(text)
    copy.eb:SetFocus()
    copy.eb:HighlightText()
    copy.eb:SetCursorPosition(0)
    copy.eb:HighlightText()
end

-----------------------------------------------------------------------------
-- Bind Item Ref
-----------------------------------------------------------------------------
-- Clicking a translation or copy link opens the copy box for that chat line.
function ChatStreamFilter.activateLink(link)
    local action, id = ChatStreamFilter.parseLink(link)
    if not action then return false end
    local recordEntry = id and entryList[id]
    if recordEntry then ns.OpenCopyableChatDialog(recordEntry.text) end
    return true
end

local lastHandledLink, lastHandledAt
local function clickTime() return GetTime and GetTime() or 0 end

-- EventRegistry "SetItemRef" callback. The argument layout (owner first or
-- not) differs between client versions, so take the first argument that is
-- one of this addon's links.
function ChatStreamFilter.onRegistryItemRef(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if safeString(value) and value:find(ADDON_LINK_HEAD, 1, true) == 1 then
            if ChatStreamFilter.activateLink(value) then
                lastHandledLink, lastHandledAt = value, clickTime()
            end
            return
        end
    end
end

local function shiftClickModifier()
    if IsModifiedClick then
        local isCallOk, isDown = pcall(IsModifiedClick, "CHATLINK")
        if isCallOk then return isDown end
    end
    return IsShiftKeyDown and IsShiftKeyDown()
end

-- Post-hook on the default SetItemRef: it never changes what the default
-- handler does.
-- * Own addon links: normally already handled by the EventRegistry callback in
--   the same click; handled here only if that callback did not run.
-- * Old-format links (only from restored chat history): the default handler has
--   nothing to show for them, so close the empty reference tooltip it opened.
-- * Shift + left-click on a player name: the default handler already sends its
--   own /who for that name (or inserts the name into an open chat input). The
--   addon no longer sends a second /who; it only shows "loading" in the name
--   tooltip and fills it from the result of that default /who.
function ChatStreamFilter.afterItemRef(link, text, button, chatFrame)
    if not safeString(link) then return end
    local action, _, legacy = ChatStreamFilter.parseLink(link)
    if action then
        local handled = not legacy and lastHandledLink == link and lastHandledAt == clickTime()
        lastHandledLink, lastHandledAt = nil, nil
        if handled then return end
        if not legacy then ChatStreamFilter.activateLink(link) end
        if ItemRefTooltip and ItemRefTooltip.IsShown and ItemRefTooltip:IsShown() then
            pcall(ItemRefTooltip.Hide, ItemRefTooltip)
        end
        return
    end
    if button == "LeftButton" and link:find("player:", 1, true) == 1 and ns.NotePlayerLookupClick
        and ns.db and ns.db.chat.playerTip ~= false and shiftClickModifier()
        and not (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) then
        ns.NotePlayerLookupClick(link)
    end
end

function ChatStreamFilter.bindItemRef()
    if ChatStreamFilter.itemRefBound then return end
    ChatStreamFilter.itemRefBound = true
    if useAddonLinks then
        -- Never replaces SetItemRef: listen for addon-link clicks and post-hook the default handler.
        ns.status.linkMode = "addon"
        local isCallOk, err = pcall(EventRegistry.RegisterCallback, EventRegistry, "SetItemRef", ChatStreamFilter.onRegistryItemRef, ChatStreamFilter)
        if not isCallOk then ChatStreamFilter.noteError(err) end
        if hooksecurefunc and type(SetItemRef) == "function" then
            hooksecurefunc("SetItemRef", function(...)
                local hookOk, hookErr = pcall(ChatStreamFilter.afterItemRef, ...)
                if not hookOk then ChatStreamFilter.noteError(hookErr) end
            end)
        end
        return
    end

    -- Without EventRegistry there is no safe way to receive link clicks;
    -- SetItemRef is never replaced, so translation links simply stay inactive.
    ns.status.linkMode = "none"
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then pcall(prevLogin) end
    -- Chat frames are never rewritten: without message filters, chat lines
    -- are left untranslated.
    ChatStreamFilter.registerFilters()
    local isCallOk, err = pcall(ChatStreamFilter.bindItemRef)
    if not isCallOk then ChatStreamFilter.noteError(err) end
    ChatStreamFilter.loggedIn = true
    ChatStreamFilter.bindAllFrames()
    -- Restored chat history can arrive a little after login.
    if useAddonLinks and C_Timer and C_Timer.After then
        C_Timer.After(5, ChatStreamFilter.sweepAllLegacy)
        C_Timer.After(20, ChatStreamFilter.sweepAllLegacy)
    end
end

function ns.PrintStatus()
    local stateEntry = ns.status
    local lineList = {}
    local anchorTarget = function(s)
        lineList[#lineList + 1] = ChatStreamFilter.cleanCodes(s)
        DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. s)
    end
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local okMeta, version = false, nil
    if type(getMetadata) == "function" then okMeta, version = pcall(getMetadata, ADDON or "EzWoW-ChatTranslator", "Version") end
    anchorTarget("version=" .. tostring(okMeta and version or "unknown"))
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        anchorTarget("clientVersion=" .. tostring(version) .. " build=" .. tostring(build) .. " interface=" .. tostring(interface))
    end
    anchorTarget("db=" .. tostring(ns.db ~= nil) .. "  enabled=" .. tostring(ns.db and ns.db.chat.enabled)
        .. "  method=" .. stateEntry.method .. "  filterEvents=" .. stateEntry.filterEvents)
    anchorTarget("seen=" .. stateEntry.seen .. "  tagged=" .. stateEntry.tagged .. "  target=" .. tostring(ns.ResolveTargetLanguageCode())
        .. " (setting=" .. tostring(ns.db and ns.db.target) .. ", client=" .. tostring(GetLocale()) .. ")")
    anchorTarget("ChatFrame_AddMessageEventFilter=" .. type(ChatFrame_AddMessageEventFilter)
        .. "  ChatFrameUtil=" .. type(ChatFrameUtil) .. "  SetItemRef=" .. type(SetItemRef)
        .. "  links=" .. tostring(stateEntry.linkMode) .. "  EventRegistry=" .. type(EventRegistry))
    local sample = "lfg RF Quest"
    anchorTarget("test: \"" .. sample .. "\" -> " .. tostring(detectDominantScriptLang(sample)))
    if ns.playerLookupStatus then
        anchorTarget("who=" .. tostring(ns.playerLookupStatus.state) .. "  detail=" .. tostring(ns.playerLookupStatus.detail))
        anchorTarget("SendWho=" .. type(SendWho) .. "  C_FriendList=" .. type(C_FriendList)
            .. "  GetWhoInfo=" .. type(GetWhoInfo))
    end
    if ns.playerLookupStatus then
        local who = ns.playerLookupStatus
        anchorTarget("whoMode=" .. tostring(who.mode) .. " requestSource=" .. tostring(who.requestSource)
            .. " clicks=" .. tostring(who.clicks or 0))
        anchorTarget("whoPending=" .. tostring(who.pending)
            .. " pendingAge=" .. tostring(who.pendingAge) .. " nextDelay=" .. tostring(who.nextDelay))
        anchorTarget("whoQuery=" .. tostring(who.query) .. " whoEvents=" .. tostring(who.events or 0)
            .. " whoResults=" .. tostring(who.resultCount))
        anchorTarget("socialLoad=" .. tostring(who.socialLoad) .. " readError=" .. tostring(who.readError))
        if who.firstResult then anchorTarget("firstWhoResult=" .. who.firstResult) end
    end
    if C_FriendList then
        anchorTarget("C.SendWho=" .. type(C_FriendList.SendWho) .. " C.GetWhoInfo=" .. type(C_FriendList.GetWhoInfo)
            .. " C.GetNumWhoResults=" .. type(C_FriendList.GetNumWhoResults))
        anchorTarget("SetWhoToUI=" .. type(SetWhoToUI) .. " C.SetWhoToUI=" .. type(C_FriendList.SetWhoToUI)
            .. " C.SetWhoToUi=" .. type(C_FriendList.SetWhoToUi))
    end
    if stateEntry.lastError then anchorTarget("|cffff6666error:|r " .. stateEntry.lastError) end
    ns.OpenCopyableChatDialog(table.concat(lineList, "\n"), (ns.L and ns.L.statusCopyTitle) or (GetLocale and GetLocale() == "koKR" and "상태 정보 전체 복사: Ctrl+C" or "Copy all status information: Ctrl+C"))
end

function ns.TestChat(text)
    local anchorTarget = function(s) DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. s:gsub("|", "||")) end
    -- The edit box sends a typed "|" as "||"; undo it so codes can be tested.
    text = text:gsub("||", "|")
    -- Chat line as the filter would rewrite it, with codes shown raw.
    local isCallOk, output = pcall(ChatStreamFilter.processIncomingEntry, text, "Tester", "CHAT_MSG_SAY")
    anchorTarget("out=" .. tostring(isCallOk and output or ("error: " .. tostring(output))))
    -- The same line rendered as a real chat line would be.
    if isCallOk and type(output) == "string" then DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. output) end
    local lang = detectDominantScriptLang(ChatStreamFilter.detectText(text))
    if not lang then anchorTarget("언어를 감지하지 못했습니다.");return end
    local greenVal = translateTokenSequence(ChatStreamFilter.detectText(text), lang, ns.ResolveTargetLanguageCode())
    local activeCfg = ns.db.chat
    local reason = not activeCfg.enabled and "채팅 번역 꺼짐" or not activeCfg.langs[lang] and "원문 언어 제외"
        or ns.SAME_SOURCE[ns.ResolveTargetLanguageCode()] == lang and "번역 대상과 같은 언어"
        or not activeCfg.inline and "풀이 표시 꺼짐" or greenVal.found == 0 and "인식한 표현 없음"
        or greenVal.cover < (activeCfg.minCover or 40) and "인식률 부족" or "풀이 표시 조건 충족"
    anchorTarget(("감지=%s / 인식률=%d%% / 기준=%d%% / %s"):format(lang,greenVal.cover,activeCfg.minCover or 40,reason))
    anchorTarget(greenVal.plain)
end

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
ChatStreamFilter.OpenCopyableChatDialog = ns.OpenCopyableChatDialog
