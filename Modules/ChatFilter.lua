--===========================================================================
-- EzWoW - Chat Translator
-- Modules/ChatFilter.lua : Real-Time Chat Channel Filter & Copyable Link Injector
--===========================================================================
local _, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local ChatStreamFilter = ns.ChatStreamFilter or {}
ns.ChatStreamFilter = ChatStreamFilter
local L = ns.L
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

function ChatStreamFilter.cleanCodes(msg)
    msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    msg = msg:gsub("|T.-|t", ""):gsub("|A.-|a", "")
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
                outputList[#outputList + 1] = ("|Hwctcopy:%d|h%s|h"):format(id, text)
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
    if msg:find("|Hwct:", 1, true) or msg:find("|Hwctcopy:", 1, true) then return nil end
    local id = ChatStreamFilter.newEntry(ChatStreamFilter.plainTextEntry(msg), nil, author)
    return ChatStreamFilter.injectClickableCopyLinks(msg, id)
end

function ChatStreamFilter.processIncomingEntry(msg, author, event)
    local savedDB = ns.db
    if not savedDB or not savedDB.chat.enabled or type(msg) ~= "string" or msg == "" then return nil end
    if msg:find("|Hwct:", 1, true) or msg:find("|Hwctcopy:", 1, true) then return nil end
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
        body = ("|Hwct:%d|h%s|h"):format(id, msg)
        wrapped = true
    end
    local tag = ""
    if savedDB.chat.tag then
        tag = ("|cff%s|Hwct:%d|h[%s]|h|r "):format(TAG_COLOR[lang], id, L.tag[lang])
    end
    local suffix, separate = "", nil
    if savedDB.chat.inline and greenVal.found > 0 and greenVal.cover >= (savedDB.chat.minCover or 40) then
        
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

function ChatStreamFilter.queueSeparate(frame, outputList, separate)
    if not frame or type(frame.AddMessage) ~= "function" then return end
    local id = outputList:match("|Hwctcopy:(%d+)") or outputList:match("|Hwct:(%d+)")
    if not id then return end
    local pending = frame.wctSeparatePending
    if not pending then
        pending = { values = {}, order = {} }
        frame.wctSeparatePending = pending
        
        local function after(self, text, ...)
            if not safeString(text) then return end
            local lookupKey = text:match("|Hwctcopy:(%d+)") or text:match("|Hwct:(%d+)")
            local meaning = lookupKey and pending.values[lookupKey]
            if meaning then
                pending.values[lookupKey] = nil
                self:AddMessage(meaning, ...)
            end
        end
        if hooksecurefunc then
            hooksecurefunc(frame, "AddMessage", after)
        else
            local original = frame.AddMessage
            frame.AddMessage = function(self, text, ...)
                local result = original(self, text, ...)
                after(self, text, ...)
                return result
            end
        end
    end
    if not pending.values[id] then
        pending.order[#pending.order + 1] = id
        if #pending.order > 200 then
            pending.values[table.remove(pending.order, 1)] = nil
        end
    end
    pending.values[id] = separate
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

function ChatStreamFilter.processLine(text)
    local _, recordEntry = text:find("|Hplayer:.-|h.-|h")
    if not recordEntry then return nil end
    local rest = text:sub(recordEntry + 1)
    local sep, body = rest:match("^(.-:%s*)(.+)$")
    if not sep or #sep > 40 then return nil end
    local author = text:match("|Hplayer:([^:|]+)")
    local outputList, separate = ChatStreamFilter.processIncomingEntry(body, author)
    if not outputList then return nil end
    return text:sub(1, recordEntry) .. sep .. outputList, separate
end

function ChatStreamFilter.bindAddMessage(frame)
    if not frame or frame.wctOrigAddMessage or type(frame.AddMessage) ~= "function" then return end
    local orig = frame.AddMessage
    frame.wctOrigAddMessage = orig
    frame.AddMessage = function(self, text, ...)
        if safeString(text) and text:find("|Hplayer:", 1, true) then
            local isCallOk, outputList, separate = pcall(ChatStreamFilter.processLine, text)
            if isCallOk and outputList then
                text = outputList
                if separate then
                    local rowEntry = orig(self, text, ...)
                    orig(self, separate, ...)
                    return rowEntry
                end
            elseif not isCallOk then ChatStreamFilter.noteError(outputList) end
        end
        return orig(self, text, ...)
    end
end

function ChatStreamFilter.bindAllAddMessage()
    for index = 1, (NUM_CHAT_WINDOWS or 10) do ChatStreamFilter.bindAddMessage(_G["ChatFrame" .. index]) end
    if CHAT_FRAMES then
        for _, displayName in ipairs(CHAT_FRAMES) do ChatStreamFilter.bindAddMessage(_G[displayName]) end
    end
end

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
    GameTooltip:Show()
end

local hooked = {}
function ChatStreamFilter.bindFrame(frame)
    if not frame or hooked[frame] then return end
    hooked[frame] = true
    frame:HookScript("OnHyperlinkEnter", function(self, link)
        if not safeString(link) then return end
        local id = type(link) == "string" and link:match("^wct:(%d+)")
        local copyID = type(link) == "string" and link:match("^wctcopy:(%d+)")
        if copyID then
            local recordEntry = entryList[tonumber(copyID)]
            if recordEntry and recordEntry.lang then ChatStreamFilter.presentGloss(self, tonumber(copyID)) end
        elseif id then
            ChatStreamFilter.presentGloss(self, tonumber(id))
        elseif ns.ShowPlayerTooltip and ns.db and ns.db.chat.playerTip ~= false then
            ns.ShowPlayerTooltip(self, link)
        end
    end)
    frame:HookScript("OnHyperlinkLeave", function(self)
        if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
        if ns.HidePlayerTooltip then ns.HidePlayerTooltip(self) end
    end)
end

function ChatStreamFilter.bindAllFrames()
    for index = 1, (NUM_CHAT_WINDOWS or 10) do ChatStreamFilter.bindFrame(_G["ChatFrame" .. index]) end
    if CHAT_FRAMES then
        for _, displayName in ipairs(CHAT_FRAMES) do ChatStreamFilter.bindFrame(_G[displayName]) end
    end
end

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
function ChatStreamFilter.bindItemRef()
    local orig = SetItemRef
    SetItemRef = function(link, text, button, chatFrame, ...)
        if not safeString(link) then return orig(link, text, button, chatFrame, ...) end
        if type(link) == "string" and (link:sub(1, 4) == "wct:" or link:sub(1, 8) == "wctcopy:") then
            local recordEntry = entryList[tonumber(link:match("^wct:(%d+)") or link:match("^wctcopy:(%d+)"))]
            if recordEntry then ns.OpenCopyableChatDialog(recordEntry.text) end
            return
        end
        
        if type(link) == "string" and link:match("^player:") and button == "LeftButton"
            and IsShiftKeyDown and IsShiftKeyDown() and ns.RequestPlayerInfo
            and ns.db and ns.db.chat.playerTip ~= false
            and not (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) then
            if ns.RequestPlayerInfo(link) then return end
        end
        return orig(link, text, button, chatFrame, ...)
    end
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then pcall(prevLogin) end
    if not ChatStreamFilter.registerFilters() then
        ns.status.method = "addmessage"
        ChatStreamFilter.bindAllAddMessage()
    end
    local isCallOk, err = pcall(ChatStreamFilter.bindItemRef)
    if not isCallOk then ChatStreamFilter.noteError(err) end
    ChatStreamFilter.bindAllFrames()
    if FCF_OpenTemporaryWindow then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            ChatStreamFilter.bindAllFrames()
            if ns.status.method == "addmessage" then ChatStreamFilter.bindAllAddMessage() end
        end)
    end
end

function ns.PrintStatus()
    local stateEntry = ns.status
    local lineList = {}
    local anchorTarget = function(s)
        lineList[#lineList + 1] = ChatStreamFilter.cleanCodes(s)
        DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. s)
    end
    anchorTarget("version=" .. tostring(GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version") or "1.5.0"))
    if GetBuildInfo then
        local version, build, _, interface = GetBuildInfo()
        anchorTarget("clientVersion=" .. tostring(version) .. " build=" .. tostring(build) .. " interface=" .. tostring(interface))
    end
    anchorTarget("db=" .. tostring(ns.db ~= nil) .. "  enabled=" .. tostring(ns.db and ns.db.chat.enabled)
        .. "  method=" .. stateEntry.method .. "  filterEvents=" .. stateEntry.filterEvents)
    anchorTarget("seen=" .. stateEntry.seen .. "  tagged=" .. stateEntry.tagged .. "  target=" .. tostring(ns.ResolveTargetLanguageCode())
        .. " (setting=" .. tostring(ns.db and ns.db.target) .. ", client=" .. tostring(GetLocale()) .. ")")
    anchorTarget("ChatFrame_AddMessageEventFilter=" .. type(ChatFrame_AddMessageEventFilter)
        .. "  ChatFrameUtil=" .. type(ChatFrameUtil) .. "  SetItemRef=" .. type(SetItemRef))
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
