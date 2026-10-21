--===========================================================================
-- EzWoW - Chat Translator
-- UI/OptionsWindow.lua : EzWoW Style Settings Dialog, Language Matrix & Slash Commands
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local SettingsDialog = ns.SettingsDialog or {}
ns.SettingsDialog = SettingsDialog
local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })

local containerFrame
local iconTex = "Interface\\AddOns\\" .. ADDON .. "\\Media\\icon"

local FRAME_W = 840
local LEFT, RIGHT = 22, 432      
local COL_W = 390                
local HALF = 195                 
local ROW = 24

local texts = {}      
local checks = {}     
local langChecks = {}

-- fitW/fitLines: optional space the text must fit in (long translations shrink).
function SettingsDialog.registerRefreshCallback(obj, fn, fitW, fitLines)
    texts[#texts + 1] = { obj, fn, fitW, fitLines }
    obj:SetText(fn())
    if fitW then ns.UIKit:FitFontString(obj, fitW, fitLines or 1) end
    return obj
end

function SettingsDialog.check(parent, resolveLabel, x, y, get, set, maxW, createOptionRadioButton)
    local checkWidget
    if createOptionRadioButton then
        local isCallOk, rowEntry = pcall(CreateFrame, "CheckButton", nil, parent, "UIRadioButtonTemplate")
        if isCallOk and rowEntry then checkWidget = rowEntry; checkWidget:SetSize(20, 20) end
    end
    if not checkWidget then
        checkWidget = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        checkWidget:SetSize(26, 26)
    end
    checkWidget:SetPoint("TOPLEFT", createOptionRadioButton and x + 3 or x, createOptionRadioButton and y - 3 or y)
    if type(checkWidget.text) == "table" and checkWidget.text.SetText then checkWidget.text:SetText("") end
    if type(checkWidget.Text) == "table" and checkWidget.Text.SetText then checkWidget.Text:SetText("") end
    local labelRegion = checkWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelRegion:SetPoint("LEFT", checkWidget, "RIGHT", createOptionRadioButton and 5 or 2, 1)
    labelRegion:SetJustifyH("LEFT")
    if maxW then
        labelRegion:SetWidth(maxW)
        if labelRegion.SetWordWrap then labelRegion:SetWordWrap(false) end
    end
    SettingsDialog.registerRefreshCallback(labelRegion, resolveLabel, maxW, 1)
    checkWidget.label = labelRegion
    checkWidget.get = get
    checkWidget:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    checkWidget:SetScript("OnEnter", function(self)
        if GameTooltip and self.label and self.label:GetText() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.label:GetText(), 0.478, 0.855, 0.831, 1, true)
            GameTooltip:Show()
        end
    end)
    checkWidget:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    checks[#checks + 1] = checkWidget
    return checkWidget
end

function SettingsDialog.createSectionHeaderLabel(parent, key, x, y)
    local labelRegion = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    labelRegion:SetPoint("TOPLEFT", x, y)
    labelRegion:SetWidth(COL_W)
    labelRegion:SetJustifyH("LEFT")
    labelRegion:SetTextColor(0.478, 0.855, 0.831)
    if labelRegion.SetWordWrap then labelRegion:SetWordWrap(false) end
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.204, 0.298, 0.357, 0.85)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 18)
    line:SetSize(COL_W, 1)
    return SettingsDialog.registerRefreshCallback(labelRegion, function() return L[key] end)
end

function SettingsDialog.createMutedNoteLabel(parent, key, x, y)
    local labelRegion = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelRegion:SetPoint("TOPLEFT", x, y)
    labelRegion:SetWidth(COL_W - 20)
    labelRegion:SetJustifyH("LEFT")
    labelRegion:SetJustifyV("TOP")
    labelRegion:SetTextColor(0.655, 0.725, 0.773)
    return SettingsDialog.registerRefreshCallback(labelRegion, function() return L[key] end)
end

function SettingsDialog.createTranslatorButton(parent, w, h, isAccent, onClick)
    local buttonWidget = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    buttonWidget:SetSize(w or 140, h or 26)
    if buttonWidget.SetBackdrop then
        ns.UIKit:ApplyBackdrop(buttonWidget, 1, 1)
    end
    local function applyNormalButtonLook()
        if not buttonWidget.SetBackdropColor then return end
        if isAccent then
            buttonWidget:SetBackdropColor(0.12, 0.22, 0.23, 0.96)
            buttonWidget:SetBackdropBorderColor(0.478, 0.855, 0.831, 1)
        else
            buttonWidget:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
            buttonWidget:SetBackdropBorderColor(0.204, 0.298, 0.357, 1)
        end
    end
    applyNormalButtonLook()
    buttonWidget.normalStyle = applyNormalButtonLook
    local formatLocalizedLabel = buttonWidget:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    formatLocalizedLabel:SetPoint("CENTER")
    if isAccent then
        formatLocalizedLabel:SetTextColor(0.478, 0.855, 0.831)
    else
        formatLocalizedLabel:SetTextColor(0.929, 0.957, 0.969)
    end
    buttonWidget.label = formatLocalizedLabel
    buttonWidget:SetScript("OnEnter", function()
        if buttonWidget.SetBackdropColor then
            buttonWidget:SetBackdropColor(0.17, 0.26, 0.30, 1)
            buttonWidget:SetBackdropBorderColor(0.478, 0.855, 0.831, 1)
        end
    end)
    buttonWidget:SetScript("OnLeave", applyNormalButtonLook)
    buttonWidget:SetScript("OnMouseDown", function() formatLocalizedLabel:SetPoint("CENTER", 1, -1) end)
    buttonWidget:SetScript("OnMouseUp", function() formatLocalizedLabel:SetPoint("CENTER", 0, 0) end)
    if onClick then buttonWidget:SetScript("OnClick", onClick) end
    return buttonWidget
end

function SettingsDialog.createActionButton(parent, key, w, isAccent)
    local buttonWidget = SettingsDialog.createTranslatorButton(parent, w or 140, 26, isAccent)
    SettingsDialog.registerRefreshCallback(buttonWidget.label, function() return L[key] end, (w or 140) - 8, 1)
    return buttonWidget
end

local syncAll
local BlizzardOptionsCanvas

function SettingsDialog.layoutLangs()
    local same = ns.SAME_SOURCE[ns.ResolveTargetLanguageCode()]
    for _, lcVal in ipairs(langChecks) do
        if lcVal.lang == same then
            lcVal:SetChecked(false)
            if lcVal.Disable then lcVal:Disable() end
            lcVal.label:SetTextColor(0.655, 0.725, 0.773)
        else
            if lcVal.Enable then lcVal:Enable() end
            lcVal:SetChecked(ns.db.chat.langs[lcVal.lang] and true or false)
            lcVal.label:SetTextColor(0.929, 0.957, 0.969)
        end
    end
end

function SettingsDialog.assignTarget(value)
    ns.db.target = value
    ns.SynchronizeTargetLanguage()
    syncAll()
end
ns.SetTarget = SettingsDialog.assignTarget

function SettingsDialog.constructMainFrame()
    containerFrame = CreateFrame("Frame", "EzWoWChatTranslatorOptions", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    containerFrame:SetSize(FRAME_W, 640)
    containerFrame:SetPoint("CENTER")
    containerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    containerFrame:SetToplevel(true)
    if containerFrame.SetBackdrop then
        ns.UIKit:ApplyBackdrop(containerFrame, 1, 1)
        containerFrame:SetBackdropColor(0.071, 0.094, 0.122, 0.97)
        containerFrame:SetBackdropBorderColor(0.204, 0.298, 0.357, 1.00)
    end

    local top = CreateFrame("Frame", nil, containerFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    top:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", containerFrame, "TOPRIGHT", -1, -1)
    top:SetHeight(56)
    if top.SetBackdrop then
        top:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        top:SetBackdropColor(0.114, 0.157, 0.192, 0.96)
    end
    top:EnableMouse(true)
    top:RegisterForDrag("LeftButton")
    top:SetScript("OnDragStart", function() containerFrame:StartMoving() end)
    top:SetScript("OnDragStop", function() containerFrame:StopMovingOrSizing() end)

    local headerAccent = top:CreateTexture(nil, "ARTWORK")
    headerAccent:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 0, 0)
    headerAccent:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", 0, 0)
    headerAccent:SetHeight(2)
    headerAccent:SetColorTexture(0.478, 0.855, 0.831, 0.95)

    containerFrame:EnableMouse(true)
    containerFrame:SetMovable(true)
    containerFrame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "EzWoWChatTranslatorOptions")

    local iconTex2 = top:CreateTexture(nil, "ARTWORK")
    iconTex2:SetTexture(iconTex)
    iconTex2:SetSize(28, 28)
    iconTex2:SetPoint("TOPLEFT", 14, -14)

    local titleStr = top:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleStr:SetPoint("TOPLEFT", 48, -11)
    titleStr:SetTextColor(0.478, 0.855, 0.831)
    titleStr:SetText("EzWoW - Chat Translator")

    local subtitleRegion = top:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitleRegion:SetPoint("TOPLEFT", titleStr, "BOTTOMLEFT", 0, -3)
    subtitleRegion:SetWidth(600)
    subtitleRegion:SetJustifyH("LEFT")
    subtitleRegion:SetTextColor(0.655, 0.725, 0.773)
    SettingsDialog.registerRefreshCallback(subtitleRegion, function() return L.secChat end)

    local close = SettingsDialog.createTranslatorButton(top, 24, 24, false, function() containerFrame:Hide() end)
    close:SetPoint("TOPRIGHT", top, "TOPRIGHT", -10, -10)
    close:SetFrameLevel(top:GetFrameLevel() + 3)
    close.label:SetText("X")

    local line = containerFrame:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.204, 0.298, 0.357, 0.65)
    line:SetSize(1, 420)
    line:SetPoint("TOPLEFT", RIGHT - 16, -70)

    local savedDB = ns.db
    local LW = COL_W - 40           
    local HW = HALF - 36            

    local y = -72
    SettingsDialog.createSectionHeaderLabel(containerFrame, "secTarget", LEFT, y); y = y - 26
    local function createOptionRadioButton(value, x, yy, w)
        local resolveLabel
        if value == "auto" then
            resolveLabel = function() return L.auto:format(ns.TARGET_NAME[ns.CLIENT_TARGET]) end
        else
            resolveLabel = function() return ns.TARGET_NAME[value] end
        end
        SettingsDialog.check(containerFrame, resolveLabel, x, yy,
            function() return (savedDB.target or "auto") == value end,
            function() SettingsDialog.assignTarget(value) end, w, true)
    end
    createOptionRadioButton("auto", LEFT, y, LW); y = y - ROW
    local order = { "ko", "en", "de", "fr", "es", "ru", "zhCN", "zhTW", "ja" }
    for index, resolvedValue in ipairs(order) do
        createOptionRadioButton(resolvedValue, LEFT + ((index - 1) % 2) * HALF, y - math.floor((index - 1) / 2) * ROW, HW)
    end
    y = y - 5 * ROW - 4
    SettingsDialog.createMutedNoteLabel(containerFrame, "targetNote", LEFT + 4, y); y = y - 40

    SettingsDialog.createSectionHeaderLabel(containerFrame, "secChat", LEFT, y); y = y - 26
    SettingsDialog.check(containerFrame, function() return L.optEnabled end, LEFT, y, function() return savedDB.chat.enabled end, function(v) savedDB.chat.enabled = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optInline end, LEFT, y, function() return savedDB.chat.inline end, function(v) savedDB.chat.inline = v end, LW); y = y - ROW - 2

    local minus = SettingsDialog.createTranslatorButton(containerFrame, 26, 22, false, function()
        savedDB.chat.minCover = math.max(0, (savedDB.chat.minCover or 40) - 10); syncAll()
    end)
    minus.label:SetText("-")
    minus:SetPoint("TOPLEFT", LEFT + 28, y)
    local plus = SettingsDialog.createTranslatorButton(containerFrame, 26, 22, false, function()
        savedDB.chat.minCover = math.min(100, (savedDB.chat.minCover or 40) + 10); syncAll()
    end)
    plus.label:SetText("+")
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    local cover = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cover:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    cover:SetWidth(COL_W - 100)
    cover:SetJustifyH("LEFT")
    cover:SetTextColor(0.929, 0.957, 0.969)
    if cover.SetWordWrap then cover:SetWordWrap(false) end
    SettingsDialog.registerRefreshCallback(cover, function() return L.optCover:format(savedDB.chat.minCover or 40) end, COL_W - 100, 1)
    y = y - ROW - 4

    SettingsDialog.check(containerFrame, function() return L.optTag end, LEFT, y, function() return savedDB.chat.tag end, function(v) savedDB.chat.tag = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optHover end, LEFT, y, function() return savedDB.chat.hoverAll end, function(v) savedDB.chat.hoverAll = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optSelf end, LEFT, y, function() return savedDB.chat.skipSelf end, function(v) savedDB.chat.skipSelf = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optCopyAll end, LEFT, y, function() return savedDB.chat.copyAll end, function(v) savedDB.chat.copyAll = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optPlayerTip end, LEFT, y, function() return savedDB.chat.playerTip ~= false end, function(v) savedDB.chat.playerTip = v end, LW); y = y - ROW - 4
    SettingsDialog.createMutedNoteLabel(containerFrame, "chatNote", LEFT + 4, y); y = y - 30
    local leftBottom = y

    y = -72
    SettingsDialog.createSectionHeaderLabel(containerFrame, "secLangs", RIGHT, y); y = y - 26
    for index, langCode in ipairs({ "ko", "zh", "ja", "ru", "en", "es" }) do
        local checkWidget = SettingsDialog.check(containerFrame, function() return L.langName[langCode] end,
            RIGHT + ((index - 1) % 2) * HALF, y - math.floor((index - 1) / 2) * ROW,
            function() return savedDB.chat.langs[langCode] end,
            function(v) savedDB.chat.langs[langCode] = v end, HW)
        checkWidget.lang = langCode
        langChecks[#langChecks + 1] = checkWidget
    end
    y = y - 3 * ROW - 8

    SettingsDialog.createSectionHeaderLabel(containerFrame, "secChannels", RIGHT, y); y = y - 26
    for _, kind in ipairs({ "public", "say", "guild", "group", "whisper" }) do
        local key = "ch" .. kind:sub(1, 1):upper() .. kind:sub(2)
        SettingsDialog.check(containerFrame, function() return L[key] end, RIGHT, y,
            function() return savedDB.chat.channels[kind] ~= false end,
            function(v) savedDB.chat.channels[kind] = v end, LW)
        y = y - ROW
    end
    y = y - 8

    SettingsDialog.createSectionHeaderLabel(containerFrame, "secTooltip", RIGHT, y); y = y - 26
    SettingsDialog.check(containerFrame, function() return L.optTooltip end, RIGHT, y, function() return savedDB.tooltip.enabled end, function(v) savedDB.tooltip.enabled = v end, LW); y = y - ROW
    SettingsDialog.check(containerFrame, function() return L.optCollect end, RIGHT, y, function() return savedDB.tooltip.collect end, function(v)
        savedDB.tooltip.collect = v
        if ns.RestartBackgroundLexiconScan then ns.RestartBackgroundLexiconScan() end
    end, LW); y = y - ROW - 4
    SettingsDialog.createMutedNoteLabel(containerFrame, "tooltipNote", RIGHT + 4, y); y = y - 40

    SettingsDialog.createSectionHeaderLabel(containerFrame, "secMisc", RIGHT, y); y = y - 26
    SettingsDialog.check(containerFrame, function() return L.optMinimap end, RIGHT, y, function() return savedDB.minimap.show ~= false end, function(v)
        savedDB.minimap.show = v
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    end, LW); y = y - ROW - 6

    local bottom = math.min(leftBottom, y)
    line:SetHeight(-bottom - 70)

    bottom = bottom - 10
    local tools = {
        { "btnUnknown", function() if ns.ShowUnknownChat then ns.ShowUnknownChat() end end },
        { "btnCollected", function() if ns.ShowCollected then ns.ShowCollected() end end },
        { "btnStatus", function() if ns.PrintStatus then ns.PrintStatus() end end },
        { "btnHelp", function() if ns.ShowHelp then ns.ShowHelp() end end },
    }
    local bwVal = 140
    for index, resolvedValue in ipairs(tools) do
        local buttonWidget = SettingsDialog.createActionButton(containerFrame, resolvedValue[1], bwVal)
        buttonWidget:SetPoint("TOPLEFT", LEFT + (index - 1) * (bwVal + 8), bottom)
        buttonWidget:SetScript("OnClick", resolvedValue[2])
    end
    bottom = bottom - 28

    containerFrame:SetHeight(-bottom + 66)

    local donate = SettingsDialog.createActionButton(containerFrame, "donate", 160, true)
    donate:SetPoint("BOTTOMLEFT", 22, 24)
    donate:SetScript("OnClick", function() ns.OpenCopyableChatDialog(ns.DONATE_URL, L.copyDonate) end)

    local resetIconBtn = SettingsDialog.createActionButton(containerFrame, "resetIconPos", 160, false)
    resetIconBtn:SetPoint("LEFT", donate, "RIGHT", 10, 0)
    resetIconBtn:SetScript("OnClick", function()
        if ns.ResetMinimapButton then ns.ResetMinimapButton() end
        containerFrame:ClearAllPoints()
        containerFrame:SetPoint("CENTER")
        syncAll()
    end)

    local isCallOk = SettingsDialog.createActionButton(containerFrame, "close", 120, false)
    isCallOk:SetPoint("BOTTOMRIGHT", -22, 24)
    isCallOk:SetScript("OnClick", function() containerFrame:Hide() end)

    local footerRegion = containerFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footerRegion:SetPoint("BOTTOMRIGHT", -22, 8)
    footerRegion:SetText("EzWoW - Chat Translator · /ezct")
    footerRegion:SetTextColor(0.655, 0.725, 0.773)

    containerFrame:SetScript("OnShow", function() syncAll() end)
    containerFrame:Hide()
end

syncAll = function()
    if not containerFrame then
        if BlizzardOptionsCanvas and BlizzardOptionsCanvas.RefreshTexts then BlizzardOptionsCanvas:RefreshTexts() end
        return
    end
    for _, resolvedValue in ipairs(texts) do
        resolvedValue[1]:SetText(resolvedValue[2]())
        if resolvedValue[3] then ns.UIKit:FitFontString(resolvedValue[1], resolvedValue[3], resolvedValue[4] or 1) end
    end
    for _, checkWidget in ipairs(checks) do checkWidget:SetChecked(checkWidget.get() and true or false) end
    SettingsDialog.layoutLangs()
    if BlizzardOptionsCanvas and BlizzardOptionsCanvas.RefreshTexts then
        BlizzardOptionsCanvas:RefreshTexts()
    end
end
ns.RefreshOptionsUI = syncAll

function ns.ToggleOptions()
    if not ns.db then return end
    if not containerFrame then SettingsDialog.constructMainFrame() end
    if containerFrame:IsShown() then
        containerFrame:Hide()
    else
        containerFrame:Show()
        containerFrame:Raise()
    end
end

local LANG_ARG_MAP = {
    auto = "auto",
    ko = "ko", kr = "ko", kokr = "ko",
    en = "en", enus = "en", engb = "en",
    de = "de", dede = "de",
    fr = "fr", frfr = "fr",
    es = "es", eses = "es", esmx = "es",
    ru = "ru", ruru = "ru",
    zh = "zhCN", cn = "zhCN", zhcn = "zhCN",
    tw = "zhTW", zhtw = "zhTW",
    ja = "ja", jp = "ja", jajp = "ja",
}

SLASH_EZWOWCHATTRANSLATOR1 = "/ezct"
SLASH_EZWOWCHATTRANSLATOR2 = "/ezct"
SLASH_EZWOWCHATTRANSLATOR3 = "/번역"
SLASH_EZWOWCHATTRANSLATOR4 = "/외국어"
SlashCmdList.EZWOWCHATTRANSLATOR = function(raw)
    raw = (raw or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local rawMessage = raw:lower()
    if rawMessage == "status" or rawMessage == "상태" or rawMessage == "debug" then
        if ns.PrintStatus then ns.PrintStatus() end
        return
    end
    if rawMessage == "미등록" or rawMessage == "unknown" then
        if ns.ShowUnknownChat then ns.ShowUnknownChat() end
        return
    end
    local cmd, rest = rawMessage:match("^(%S+)%s*(.-)$")
    if cmd == "lang" or cmd == "language" or cmd == "locale" or cmd == "언어" then
        local mapped = LANG_ARG_MAP[rest]
        if mapped and ns.db then
            SettingsDialog.assignTarget(mapped)
            local formatLocalizedLabel = mapped == "auto" and L.auto:format(ns.TARGET_NAME[ns.CLIENT_TARGET]) or (ns.TARGET_NAME[mapped] or mapped)
            DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r " .. L.secTarget .. ": " .. formatLocalizedLabel)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff7ADAD4[EzWoW - Chat Translator]|r /ezct lang <auto|ko|en|de|fr|es|ru|zhCN|zhTW|ja>")
        end
        return
    end
    if cmd == "test" or cmd == "테스트" then
        if ns.TestChat and rest ~= "" then ns.TestChat(raw:match("^%S+%s*(.-)$")) end
        return
    end
    if cmd == "collect" or cmd == "수집" then
        if rest == "" or rest == "clear" or rest == "초기화" or rest == "reset" then
            if ns.HandleTooltipCollectCommand then ns.HandleTooltipCollectCommand(rest) end
            return
        end
    end
    
    if ns.HandleGlossarySlashCommand and raw ~= "" and ns.HandleGlossarySlashCommand(raw) then return end
    ns.ToggleOptions()
end

-----------------------------------------------------------------------------
-- Register Panel
-----------------------------------------------------------------------------
function SettingsDialog.registerPanel()
    if BlizzardOptionsCanvas then return end
    local panelFrame = CreateFrame("Frame", "EzWoWChatTranslatorOptionsPanel", UIParent)
    panelFrame.name = "EzWoW - Chat Translator"
    BlizzardOptionsCanvas = panelFrame

    local icVal = panelFrame:CreateTexture(nil, "ARTWORK")
    icVal:SetTexture(iconTex)
    icVal:SetSize(32, 32)
    icVal:SetPoint("TOPLEFT", 18, -18)

    local resolvedValue = panelFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    resolvedValue:SetPoint("LEFT", icVal, "RIGHT", 10, 0)
    resolvedValue:SetTextColor(0.478, 0.855, 0.831)
    resolvedValue:SetText("EzWoW - Chat Translator")

    local desc = panelFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", icVal, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")

    local buttonWidget = SettingsDialog.createTranslatorButton(panelFrame, 220, 28, true, function()
        ns.ToggleOptions()
    end)
    buttonWidget:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)
    function buttonWidget:SetText(txt)
        buttonWidget.label:SetText(txt or "")
        ns.UIKit:FitFontString(buttonWidget.label, 212, 1)
    end

    local hint = panelFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", buttonWidget, "BOTTOMLEFT", 0, -14)
    hint:SetTextColor(0.655, 0.725, 0.773)

    function panelFrame:RefreshTexts()
        desc:SetText(L.panelDesc or "Translates foreign chat and untranslated item/spell tooltips using a built-in WoW dictionary.")
        buttonWidget:SetText(L.panelBtn or ((SETTINGS or "Settings") .. " (/ezct, /ezct)"))
        hint:SetText(L.panelHint or "Type /ezct or /ezct in chat to open settings.")
    end
    panelFrame:SetScript("OnShow", function(self) self:RefreshTexts() end)
    panelFrame:RefreshTexts()

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local categoryKey = Settings.RegisterCanvasLayoutCategory(panelFrame, panelFrame.name)
        Settings.RegisterAddOnCategory(categoryKey)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panelFrame)
    end
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then prevLogin() end
    pcall(SettingsDialog.registerPanel)
end
