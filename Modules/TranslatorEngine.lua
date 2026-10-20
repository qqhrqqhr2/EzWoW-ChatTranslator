--===========================================================================
-- EzWoW - Chat Translator
-- Modules/TranslatorEngine.lua : UTF-8 Tokenizer, Script Detector & Glossary Matcher
--===========================================================================
local ADDON, ns = ...

local TranslationEngine = ns.TranslationEngine or {}
ns.TranslationEngine = TranslationEngine

local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })

function TranslationEngine.hasSecret(v)
    if not issecretvalue then return false end
    local isCallOk, rowEntry = pcall(issecretvalue, v)
    return not isCallOk or rowEntry
end
ns.IsSecret = TranslationEngine.hasSecret
function TranslationEngine.safeString(v) return type(v) == "string" and not TranslationEngine.hasSecret(v) end

-----------------------------------------------------------------------------
-- Decode Utf8 Codepoint
-----------------------------------------------------------------------------
local byte, char, floor = string.byte, string.char, math.floor

function TranslationEngine.decodeUtf8Codepoint(s, i)
    local themeColor = byte(s, i)
    if not themeColor then return nil, i end
    if themeColor < 0x80 then return themeColor, i + 1 end
    local c2Val, c3Val, c4Val = byte(s, i + 1) or 128, byte(s, i + 2) or 128, byte(s, i + 3) or 128
    if themeColor < 0xE0 then return (themeColor % 32) * 64 + c2Val % 64, i + 2 end
    if themeColor < 0xF0 then return (themeColor % 16) * 4096 + (c2Val % 64) * 64 + c3Val % 64, i + 3 end
    return (themeColor % 8) * 262144 + (c2Val % 64) * 4096 + (c3Val % 64) * 64 + c4Val % 64, i + 4
end

function TranslationEngine.encodeUtf8Codepoint(cp)
    if cp < 0x80 then return char(cp) end
    if cp < 0x800 then return char(0xC0 + floor(cp / 64), 0x80 + cp % 64) end
    if cp < 0x10000 then
        return char(0xE0 + floor(cp / 4096), 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
    end
    return char(0xF0 + floor(cp / 262144), 0x80 + floor(cp / 4096) % 64, 0x80 + floor(cp / 64) % 64, 0x80 + cp % 64)
end

function TranslationEngine.normalizeFullwidthCodepoint(cp)
    if cp >= 0xFF01 and cp <= 0xFF5E then cp = cp - 0xFEE0 end
    if cp >= 65 and cp <= 90 then return cp + 32 end
    if cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7 then return cp + 32 end
    if cp >= 0x0410 and cp <= 0x042F then return cp + 32 end
    if cp == 0x0401 or cp == 0x0451 then return 0x0435 end
    if cp == 0x3001 then return 44 end  
    if cp == 0x3002 then return 46 end  
    if cp == 0x2019 or cp == 0x2018 or cp == 0x02BC or cp == 0x60 then return 39 end  
    
    local t2s = ns.T2S and ns.T2S[cp]
    if t2s then return t2s end
    return cp
end

function TranslationEngine.hasHan(cp)
    return (cp >= 0x3400 and cp <= 0x4DBF) or (cp >= 0x4E00 and cp <= 0x9FFF)
        or (cp >= 0xF900 and cp <= 0xFAFF) or (cp >= 0x20000 and cp <= 0x2FFFF)
end
function TranslationEngine.hasKana(cp)
    return (cp >= 0x3040 and cp <= 0x30FF) or (cp >= 0x31F0 and cp <= 0x31FF) or (cp >= 0xFF66 and cp <= 0xFF9F)
end
function TranslationEngine.hasHangul(cp)
    return (cp >= 0xAC00 and cp <= 0xD7AF) or (cp >= 0x1100 and cp <= 0x11FF) or (cp >= 0x3130 and cp <= 0x318F)
end
function TranslationEngine.hasCyr(cp) return cp >= 0x0400 and cp <= 0x04FF end
function TranslationEngine.hasLatin(cp) return (cp >= 97 and cp <= 122) or (cp >= 0xC0 and cp <= 0x24F) end
function TranslationEngine.hasDigit(cp) return cp >= 48 and cp <= 57 end

-----------------------------------------------------------------------------
-- Segment Chat Into Tokens
-----------------------------------------------------------------------------
function TranslationEngine.segmentChatIntoTokens(text)
    local tokens, i, nodeEntry = {}, 1, #text
    local cps = {}
    while i <= nodeEntry do
        local cp, subIndex = TranslationEngine.decodeUtf8Codepoint(text, i)
        if not cp then break end
        cps[#cps + 1] = { cp = cp, n = TranslationEngine.normalizeFullwidthCodepoint(cp), s = text:sub(i, subIndex - 1) }
        i = subIndex
    end
    local k = 1
    while k <= #cps do
        local themeColor = cps[k]
        local ncVal = themeColor.n
        if TranslationEngine.hasHan(ncVal) or TranslationEngine.hasKana(ncVal) or TranslationEngine.hasHangul(ncVal) then
            tokens[#tokens + 1] = { kind = "cjk", text = themeColor.s, key = TranslationEngine.encodeUtf8Codepoint(ncVal) }
            k = k + 1
        elseif TranslationEngine.hasLatin(ncVal) or TranslationEngine.hasCyr(ncVal) or TranslationEngine.hasDigit(ncVal) then
            local raw, lookupKey = {}, {}
            while k <= #cps do
                local dataEntry = cps[k]
                local dnVal = dataEntry.n
                local inWord = TranslationEngine.hasLatin(dnVal) or TranslationEngine.hasCyr(dnVal) or TranslationEngine.hasDigit(dnVal)
                
                if not inWord and #raw > 0 then
                    local nxVal = cps[k + 1]
                    local prevN = cps[k - 1] and cps[k - 1].n
                    if dnVal == 47 then
                        inWord = true
                    elseif dnVal == 45 or dnVal == 39 then
                        
                        inWord = nxVal and (TranslationEngine.hasLatin(nxVal.n) or TranslationEngine.hasCyr(nxVal.n)) or false
                    elseif dnVal == 46 then
                        
                        inWord = (prevN and TranslationEngine.hasDigit(prevN) and nxVal and TranslationEngine.hasDigit(nxVal.n)) or false
                    end
                end
                if not inWord then break end
                raw[#raw + 1] = dataEntry.s
                lookupKey[#lookupKey + 1] = TranslationEngine.encodeUtf8Codepoint(dnVal)
                k = k + 1
            end
            tokens[#tokens + 1] = { kind = "word", text = table.concat(raw), key = table.concat(lookupKey) }
        elseif ncVal == 32 or ncVal == 9 or ncVal == 10 or ncVal == 13 or ncVal == 0xA0 or ncVal == 0x3000 then
            if not tokens[#tokens] or tokens[#tokens].kind ~= "space" then
                tokens[#tokens + 1] = { kind = "space", text = " ", key = " " }
            end
            k = k + 1
        else
            tokens[#tokens + 1] = { kind = "other", text = (ncVal < 128) and char(ncVal) or themeColor.s, key = TranslationEngine.encodeUtf8Codepoint(ncVal) }
            k = k + 1
        end
    end
    
    local merged, subIndex = {}, 1
    while subIndex <= #tokens do
        local resolvedValue, nxVal = tokens[subIndex], tokens[subIndex + 1]
        if resolvedValue.key == "/" and nxVal and nxVal.kind == "word" and (nxVal.key == "w" or nxVal.key == "whisper") then
            merged[#merged + 1] = {kind="word",text=resolvedValue.text..nxVal.text,key="/"..nxVal.key};subIndex=subIndex+2
        else merged[#merged + 1] = resolvedValue;subIndex=subIndex+1 end
    end
    return merged
end

-----------------------------------------------------------------------------
-- Resolve Norm Key
-----------------------------------------------------------------------------
local activeLanguageDict = {}
local resolveMaxLen = {}
local normKeyCache, normLenCache, normCacheCount = {}, {}, 0

function TranslationEngine.resolveNormKey(term)
    local cachedKey = normKeyCache[term]
    if cachedKey ~= nil then
        return cachedKey, normLenCache[term]
    end
    local parts = {}
    for _, resolvedValue in ipairs(TranslationEngine.segmentChatIntoTokens(term)) do
        if resolvedValue.kind == "space" then
            if #parts > 0 and parts[#parts] ~= " " then parts[#parts + 1] = " " end
        else
            parts[#parts + 1] = resolvedValue.key
        end
    end
    while parts[#parts] == " " do parts[#parts] = nil end
    local resKey, resLen = table.concat(parts), #parts
    if #term <= 160 then
        if normCacheCount > 4096 then
            wipe(normKeyCache)
            wipe(normLenCache)
            normCacheCount = 0
        end
        normKeyCache[term] = resKey
        normLenCache[term] = resLen
        normCacheCount = normCacheCount + 1
    end
    return resKey, resLen
end

function TranslationEngine.compileLanguageDictionaries()
    for langCode, raw in pairs(ns.RawGlossary) do
        local dataEntry, maxLen = {}, 1
        for line in raw:gmatch("[^\r\n]+") do
            local term, koVal, enVal = line:match("^%s*(.-)%s*=%s*(.-)%s*=%s*(.-)%s*$")
            if term and term ~= "" then
                local lookupKey, strLength = TranslationEngine.resolveNormKey(term)
                dataEntry[lookupKey] = { koVal, enVal, term }
                if strLength > maxLen then maxLen = strLength end
            end
        end
        activeLanguageDict[langCode], resolveMaxLen[langCode] = dataEntry, maxLen
    end
end
TranslationEngine.compileLanguageDictionaries()
ns.Dict = activeLanguageDict
ns.DictMaxLen = resolveMaxLen
ns.NormalizeGlossaryLookupKey = TranslationEngine.resolveNormKey

function TranslationEngine.resolveTermMeaning(e, target)
    
    if e.custom then return e.custom end
    local koVal, enVal = e[1], e[2]
    if enVal == "" and koVal == "" then return "" end
    if target == "ko" then return koVal ~= "" and koVal or enVal end
    if target == "en" or enVal == "" then return enVal ~= "" and enVal or koVal end
    local translationMap = ns.TR and ns.TR[target]
    local lower = enVal:lower()
    local v = translationMap and translationMap[lower]
    if not v and target == "zhTW" and ns.TR and ns.TR.zhCN then v = ns.TR.zhCN[lower] end
    return v or enVal
end
ns.LookupGlossaryTranslation = TranslationEngine.resolveTermMeaning

-----------------------------------------------------------------------------
-- Detect Dominant Script Lang
-----------------------------------------------------------------------------
local SPANISH_STRONG_WORDS = {buscas=true,busques=true,prepararte=true,lanzamiento=true,recluta=true,latinos=true,unite=true,preparate=true,busco=true,buscamos=true,vendo=true,compro=true,necesito=true,necesitamos=true,puedes=true,tienes=true,tenemos=true,quiero=true,queremos=true,invitarme=true,["invítame"]=true,sanador=true,sanadores=true,tanque=true,mazmorra=true,hermandad=true,gracias=true,hola=true}
local SPANISH_MARKER_WORDS = {para=true,quiero=true,con=true,por=true,favor=true,grupo=true,["misión"]=true,misiones=true,["maná"]=true,["raíz"]=true,terrenal=true,alguien=true,puedo=true}

local SPANISH_STRONG_WORDS = {buscas=true,busques=true,prepararte=true,lanzamiento=true,recluta=true,latinos=true,unite=true,preparate=true,busco=true,buscamos=true,vendo=true,compro=true,necesito=true,necesitamos=true,puedes=true,tienes=true,tenemos=true,quiero=true,queremos=true,invitarme=true,["invítame"]=true,sanador=true,sanadores=true,tanque=true,mazmorra=true,hermandad=true,gracias=true,hola=true}
local SPANISH_MARKER_WORDS = {para=true,quiero=true,con=true,por=true,favor=true,grupo=true,["misión"]=true,misiones=true,["maná"]=true,["raíz"]=true,terrenal=true,alguien=true,puedo=true}

function TranslationEngine.detectDominantScriptLang(text)
    local han, kana, hangul, cyr, lat = 0, 0, 0, 0, 0
    local i, nodeEntry = 1, #text
    while i <= nodeEntry do
        local cp, subIndex = TranslationEngine.decodeUtf8Codepoint(text, i)
        if not cp then break end
        cp = TranslationEngine.normalizeFullwidthCodepoint(cp)
        if TranslationEngine.hasHangul(cp) then hangul = hangul + 1
        elseif TranslationEngine.hasKana(cp) then kana = kana + 1
        elseif TranslationEngine.hasHan(cp) then han = han + 1
        elseif TranslationEngine.hasCyr(cp) then cyr = cyr + 1
        elseif TranslationEngine.hasLatin(cp) then lat = lat + 1 end
        i = subIndex
    end
    if hangul > 0 and hangul >= han + kana + cyr then return "ko" end
    if kana > 0 then return "ja" end
    if han > 0 then
        local lookupKey = TranslationEngine.resolveNormKey(text)
        if activeLanguageDict.ja and activeLanguageDict.ja[lookupKey] and not (activeLanguageDict.zh and activeLanguageDict.zh[lookupKey]) then return "ja" end
        return "zh"
    end
    if cyr > 0 then return "ru" end
    if lat >= 2 and hangul == 0 then
        local lookupKey = TranslationEngine.resolveNormKey(text)
        if activeLanguageDict.es and activeLanguageDict.es[lookupKey] and not activeLanguageDict.en[lookupKey] then return "es" end
        local score = 0
        for _, token in ipairs(TranslationEngine.segmentChatIntoTokens(text)) do
            if SPANISH_STRONG_WORDS[token.key] then return "es" end
            if SPANISH_MARKER_WORDS[token.key] then score = score + 1 end
        end
        if score >= 2 then return "es" end
        return "en"
    end
    return nil
end
ns.DetectDominantScriptLanguage = TranslationEngine.detectDominantScriptLang

local PATTERN_LOCALES = {
    ["%1 gold"] = { ja = "%1ゴールド", es = "%1 oro", de = "%1 Gold", fr = "%1 or" },
    ["%1 silver"] = { ja = "%1シルバー", es = "%1 plata", de = "%1 Silber", fr = "%1 argent" },
    ["%1 copper"] = { ja = "%1カッパー", es = "%1 cobre", de = "%1 Kupfer", fr = "%1 cuivre" },
    ["%1k"] = { ja = "%1k", es = "%1k", de = "%1k", fr = "%1k" },
    ["%1k gold"] = { ja = "%1kゴールド", es = "%1k oro", de = "%1k Gold", fr = "%1k or" },
    ["%1 x10k"] = { ja = "%1万", es = "%1 x10k", de = "%1 x10k", fr = "%1 x10k" },
    ["x%1"] = { ja = "%1個", es = "x%1", de = "%1x", fr = "x%1" },
    ["level %1"] = { ja = "Lv%1", es = "nivel %1", de = "Stufe %1", fr = "niveau %1" },
    ["need %1 more"] = { ja = "あと%1人募集", es = "faltan %1", de = "suche noch %1", fr = "cherche encore %1" },
    ["need %1"] = { ja = "%1人必要", es = "necesito %1", de = "brauche %1", fr = "besoin de %1" },
    ["%1-man"] = { ja = "%1人用", es = "de %1", de = "%1er", fr = "%1 joueurs" },
    ["%1 min"] = { ja = "%1分", es = "%1 min", de = "%1 Min.", fr = "%1 min" },
    ["%1 sec"] = { ja = "%1秒", es = "%1 seg", de = "%1 Sek.", fr = "%1 s" },
    ["around %1"] = { ja = "%1前後", es = "unos %1", de = "ca. %1", fr = "environ %1" },
    ["%1 PM"] = { ja = "午後%1時", es = "%1 PM", de = "%1 Uhr (nachm.)", fr = "%1h (après-midi)" },
    ["%1 AM"] = { ja = "午前%1時", es = "%1 AM", de = "%1 Uhr (vorm.)", fr = "%1h (matin)" },
    ["%1st"] = { ja = "第%1", es = "%1.º", de = "%1.", fr = "%1er" },
    ["%1nd"] = { ja = "第%1", es = "%1.º", de = "%1.", fr = "%1e" },
    ["%1rd"] = { ja = "第%1", es = "%1.º", de = "%1.", fr = "%1e" },
    ["%1th"] = { ja = "第%1", es = "%1.º", de = "%1.", fr = "%1e" },
    ["rank %1"] = { ja = "ランク%1", es = "rango %1", de = "Rang %1", fr = "rang %1" },
}
function TranslationEngine.platformHelper(pat, koVal, enVal, zhCN, zhTW, ru, src)
    local extra = (ns.PatternLocales and ns.PatternLocales[enVal]) or PATTERN_LOCALES[enVal] or {}
    return { pat, { ko = koVal, en = enVal, zhCN = zhCN, zhTW = zhTW, ru = ru, ja = extra.ja, es = extra.es, de = extra.de, fr = extra.fr }, src }
end
local PATTERNS = {
    TranslationEngine.platformHelper("^(%d[%d%.]*)g$", "%1골드", "%1 gold", "%1金", "%1金", "%1 золотых"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)gold$", "%1골드", "%1 gold", "%1金", "%1金", "%1 золотых"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)s$", "%1실버", "%1 silver", "%1银", "%1銀", "%1 серебра"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)c$", "%1코퍼", "%1 copper", "%1铜", "%1銅", "%1 меди"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)k$", "%1천", "%1k", "%1千", "%1千", "%1 тыс."),
    TranslationEngine.platformHelper("^(%d[%d%.]*)kg$", "%1천 골드", "%1k gold", "%1千金", "%1千金", "%1 тыс. золотых"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)w$", "%1만", "%1 x10k", "%1万", "%1萬", "%1 x10 тыс.", "zh"),
    TranslationEngine.platformHelper("^x(%d+)$", "%1개", "x%1", "%1个", "%1個", "%1 шт."),
    TranslationEngine.platformHelper("^(%d+)x$", "%1개", "x%1", "%1个", "%1個", "%1 шт."),
    TranslationEngine.platformHelper("^lvl(%d+)$", "레벨 %1", "level %1", "%1级", "%1級", "%1 ур."),
    TranslationEngine.platformHelper("^lv(%d+)$", "레벨 %1", "level %1", "%1级", "%1級", "%1 ур."),
    TranslationEngine.platformHelper("^level(%d+)$", "레벨 %1", "level %1", "%1级", "%1級", "%1 ур."),
    TranslationEngine.platformHelper("^lf(%d+)m$", "%1명 구함", "need %1 more", "缺%1人", "缺%1人", "нужно ещё %1"),
    TranslationEngine.platformHelper("^need(%d+)$", "%1명 필요", "need %1", "需要%1人", "需要%1人", "нужно %1"),
    TranslationEngine.platformHelper("^(%d+)m$", "%1명", "%1-man", "%1人", "%1人", "%1 чел."),
    TranslationEngine.platformHelper("^(%d+)man$", "%1인", "%1-man", "%1人", "%1人", "на %1"),
    TranslationEngine.platformHelper("^(%d+)min$", "%1분", "%1 min", "%1分钟", "%1分鐘", "%1 мин"),
    TranslationEngine.platformHelper("^(%d+)mins$", "%1분", "%1 min", "%1分钟", "%1分鐘", "%1 мин"),
    TranslationEngine.platformHelper("^(%d+)sec$", "%1초", "%1 sec", "%1秒", "%1秒", "%1 сек"),
    TranslationEngine.platformHelper("^(%d+)ish$", "%1쯤", "around %1", "%1左右", "%1左右", "около %1"),
    TranslationEngine.platformHelper("^(%d+)pm$", "오후 %1시", "%1 PM", "下午%1点", "下午%1點", "%1 вечера"),
    TranslationEngine.platformHelper("^(%d+)am$", "오전 %1시", "%1 AM", "上午%1点", "上午%1點", "%1 утра"),
    TranslationEngine.platformHelper("^(%d+)st$", "%1번째", "%1st", "第%1", "第%1", "%1-й"),
    TranslationEngine.platformHelper("^(%d+)nd$", "%1번째", "%1nd", "第%1", "第%1", "%1-й"),
    TranslationEngine.platformHelper("^(%d+)rd$", "%1번째", "%1rd", "第%1", "第%1", "%1-й"),
    TranslationEngine.platformHelper("^(%d+)th$", "%1번째", "%1th", "第%1", "第%1", "%1-й"),
    TranslationEngine.platformHelper("^r(%d+)$", "%1계급", "rank %1", "%1级军衔", "%1級軍銜", "ранг %1"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)г$", "%1골드", "%1 gold", "%1金", "%1金", "%1 золотых", "ru"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)з$", "%1골드", "%1 gold", "%1金", "%1金", "%1 золотых", "ru"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)с$", "%1실버", "%1 silver", "%1银", "%1銀", "%1 серебра", "ru"),
    TranslationEngine.platformHelper("^(%d[%d%.]*)к$", "%1천", "%1k", "%1千", "%1千", "%1 тыс.", "ru"),
    TranslationEngine.platformHelper("^(%d+)лвл$", "레벨 %1", "level %1", "%1级", "%1級", "%1 ур.", "ru"),
    TranslationEngine.platformHelper("^(%d+)ур$", "레벨 %1", "level %1", "%1级", "%1級", "%1 ур.", "ru"),
}

function TranslationEngine.matchChatPhrasePattern(lookupKey, langCode, target)
    target = target or ns.ResolveTargetLanguageCode()
    
    if langCode == "en" then
        local base = lookupKey:match("^invv+$") and "inv" or lookupKey:match("^anyyy+$") and "any"
        local entry = base and activeLanguageDict.en and activeLanguageDict.en[base]
        if entry then return TranslationEngine.resolveTermMeaning(entry, target) end
    end
    for _, anchorTarget in ipairs(PATTERNS) do
        if not anchorTarget[3] or anchorTarget[3] == langCode then
            local outputList, nodeEntry = lookupKey:gsub(anchorTarget[1], anchorTarget[2][target] or anchorTarget[2].en)
            if nodeEntry > 0 then return outputList end
        end
    end
end
ns.MatchChatPhrasePattern = TranslationEngine.matchChatPhrasePattern

function TranslationEngine.lookup(dicts, lookupKey)
    for _, dataEntry in ipairs(dicts) do
        local e = dataEntry and dataEntry[lookupKey]
        if e then return e end
    end
end

function TranslationEngine.resolveSlashMeaning(lookupKey, langCode, target)
    
    if lookupKey:sub(-1) == "/" and lookupKey:sub(-2) ~= "//" then lookupKey = lookupKey:sub(1, -2) end
    if not lookupKey:find("/", 1, true) or lookupKey:find(":", 1, true)
        or lookupKey:sub(1,1) == "/" or lookupKey:sub(-1) == "/" or lookupKey:find("//",1,true) then return end
    local meanings = {}
    for part in lookupKey:gmatch("[^/]+") do
        local entry = TranslationEngine.lookup({activeLanguageDict[langCode] or {}, activeLanguageDict.en or {}}, part)
        local value = entry and TranslationEngine.resolveTermMeaning(entry, target) or TranslationEngine.matchChatPhrasePattern(part, langCode, target)
        if not value or value == "" then return end
        meanings[#meanings+1] = value
        if #meanings > 5 then return end
    end
    if #meanings >= 2 then return table.concat(meanings, "/") end
end
ns.LookupSlashCompoundTranslation = TranslationEngine.resolveSlashMeaning

local REPEAT_JAMO = { "ㅋ", "ㅎ", "ㅠ", "ㅜ", "ㄷ", "ㅡ" }
function TranslationEngine.collapseKo(text)
    for _, subIndex in ipairs(REPEAT_JAMO) do
        local three = subIndex .. subIndex .. subIndex
        while text:find(three, 1, true) do
            text = text:gsub(three, subIndex .. subIndex)
        end
    end
    return text
end

local KEY_JAMO = {
    q="ㅂ", w="ㅈ", e="ㄷ", r="ㄱ", t="ㅅ", y="ㅛ", u="ㅕ", i="ㅑ", o="ㅐ", p="ㅔ",
    a="ㅁ", s="ㄴ", d="ㅇ", f="ㄹ", g="ㅎ", h="ㅗ", j="ㅓ", k="ㅏ", l="ㅣ",
    z="ㅋ", x="ㅌ", c="ㅊ", v="ㅍ", b="ㅠ", n="ㅜ", m="ㅡ",
    Q="ㅃ", W="ㅉ", E="ㄸ", R="ㄲ", T="ㅆ", O="ㅒ", P="ㅖ",
}
function TranslationEngine.findSequenceMatchIndex(list)
    local resolvedValue = {}
    for i, v in ipairs(list) do resolvedValue[v] = i - 1 end
    return resolvedValue
end
local CHO = TranslationEngine.findSequenceMatchIndex({ "ㄱ","ㄲ","ㄴ","ㄷ","ㄸ","ㄹ","ㅁ","ㅂ","ㅃ","ㅅ","ㅆ","ㅇ","ㅈ","ㅉ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ" })
local JUNG = TranslationEngine.findSequenceMatchIndex({ "ㅏ","ㅐ","ㅑ","ㅒ","ㅓ","ㅔ","ㅕ","ㅖ","ㅗ","ㅘ","ㅙ","ㅚ","ㅛ","ㅜ","ㅝ","ㅞ","ㅟ","ㅠ","ㅡ","ㅢ","ㅣ" })
local JONG = TranslationEngine.findSequenceMatchIndex({ "", "ㄱ","ㄲ","ㄳ","ㄴ","ㄵ","ㄶ","ㄷ","ㄹ","ㄺ","ㄻ","ㄼ","ㄽ","ㄾ","ㄿ","ㅀ","ㅁ","ㅂ","ㅄ","ㅅ","ㅆ","ㅇ","ㅈ","ㅊ","ㅋ","ㅌ","ㅍ","ㅎ" })
local VOWEL_PAIR = { ["ㅗㅏ"]="ㅘ", ["ㅗㅐ"]="ㅙ", ["ㅗㅣ"]="ㅚ", ["ㅜㅓ"]="ㅝ", ["ㅜㅔ"]="ㅞ", ["ㅜㅣ"]="ㅟ", ["ㅡㅣ"]="ㅢ" }
local FINAL_PAIR = { ["ㄱㅅ"]="ㄳ", ["ㄴㅈ"]="ㄵ", ["ㄴㅎ"]="ㄶ", ["ㄹㄱ"]="ㄺ", ["ㄹㅁ"]="ㄻ", ["ㄹㅂ"]="ㄼ",
    ["ㄹㅅ"]="ㄽ", ["ㄹㅌ"]="ㄾ", ["ㄹㅍ"]="ㄿ", ["ㄹㅎ"]="ㅀ", ["ㅂㅅ"]="ㅄ" }

function TranslationEngine.assembleHangulFromQwerty(word)
    local jamo = {}
    for chVal in word:gmatch(".") do
        local subIndex = KEY_JAMO[chVal] or KEY_JAMO[chVal:lower()]
        if not subIndex then return nil end
        jamo[#jamo + 1] = subIndex
    end
    local outputList, i, nodeEntry = {}, 1, #jamo
    local function hasV(x) return x and JUNG[x] ~= nil end
    while i <= nodeEntry do
        local themeColor, v = jamo[i], jamo[i + 1]
        if not CHO[themeColor] or not hasV(v) then return nil end
        i = i + 2
        if hasV(jamo[i]) and VOWEL_PAIR[v .. jamo[i]] then v = VOWEL_PAIR[v .. jamo[i]]; i = i + 1 end
        local windowFrame = ""
        local alphaVal, buttonWidget = jamo[i], jamo[i + 1]
        if alphaVal and not hasV(alphaVal) and not hasV(buttonWidget) and JONG[alphaVal] then
            windowFrame = alphaVal; i = i + 1
            local c2Val = jamo[i]
            if c2Val and not hasV(c2Val) and not hasV(jamo[i + 1]) and FINAL_PAIR[windowFrame .. c2Val] then windowFrame = FINAL_PAIR[windowFrame .. c2Val]; i = i + 1 end
        end
        outputList[#outputList + 1] = TranslationEngine.encodeUtf8Codepoint(0xAC00 + (CHO[themeColor] * 21 + JUNG[v]) * 28 + JONG[windowFrame])
    end
    if #outputList < 2 then return nil end
    return table.concat(outputList)
end
ns.AssembleHangulFromQwerty = TranslationEngine.assembleHangulFromQwerty

local PARTY_COUNT = {
    ko = "%d명 있음, %d명 구함", en = "have %d, need %d", zhCN = "已有%d人，缺%d人", zhTW = "已有%d人，缺%d人",
    ja = "%d人いる・あと%d人", ru = "есть %d, нужно ещё %d", es = "somos %d, faltan %d",
    de = "%d vorhanden, %d gesucht", fr = "%d présents, cherche %d",
}

function TranslationEngine.translateTokenSequence(text, langCode, target, options)
    target = target or ns.ResolveTargetLanguageCode()
    if langCode == "ko" then text = TranslationEngine.collapseKo(text) end
    local tokens = TranslationEngine.segmentChatIntoTokens(text)
    
    if langCode == "ru" then
        local merged, i = {}, 1
        while i <= #tokens do
            local keys, raw, subIndex = {}, {}, i
            while tokens[subIndex] and tokens[subIndex].kind == "word" do
                local cp, nextByte = TranslationEngine.decodeUtf8Codepoint(tokens[subIndex].key, 1)
                if not cp or not TranslationEngine.hasCyr(cp) or nextByte <= #tokens[subIndex].key then break end
                keys[#keys + 1] = tokens[subIndex].key; raw[#raw + 1] = tokens[subIndex].text
                if not tokens[subIndex + 1] or tokens[subIndex + 1].kind ~= "space" then subIndex = subIndex + 1; break end
                raw[#raw + 1] = " "; subIndex = subIndex + 2
            end
            local lookupKey = table.concat(keys)
            if #keys >= 3 and activeLanguageDict.ru and activeLanguageDict.ru[lookupKey] then
                merged[#merged + 1] = { kind = "word", key = lookupKey, text = table.concat(raw):gsub(" $", "") }
                
                if raw[#raw] == " " then merged[#merged + 1] = {kind="space",text=" ",key=" "} end
                i = subIndex
            else merged[#merged + 1] = tokens[i]; i = i + 1 end
        end
        tokens = merged
    end

    local tokenLanguages = {}
    local function classifyCodepointScript(resolvedValue)
        local cp = resolvedValue and TranslationEngine.decodeUtf8Codepoint(resolvedValue.key, 1)
        if not cp then return end
        if TranslationEngine.hasHangul(cp) then return "ko" end
        if TranslationEngine.hasCyr(cp) then return "ru" end
        if TranslationEngine.hasKana(cp) then return "ja" end
        if TranslationEngine.hasHan(cp) then return "han" end
        if TranslationEngine.hasLatin(cp) then return "latin" end
    end
    local start = 1
    while start <= #tokens do
        local script = classifyCodepointScript(tokens[start])
        if not script then start = start + 1
        else
            local finish, text, japanese = start, {}, script == "ja"
            while finish <= #tokens do
                local current = classifyCodepointScript(tokens[finish])
                local compatible = current == script or
                    ((script == "han" or script == "ja") and (current == "han" or current == "ja"))
                if not compatible and tokens[finish].kind ~= "space" then break end
                if current == "ja" then japanese = true end
                text[#text+1] = tokens[finish].text
                finish = finish + 1
            end
            local sourceVal = script
            if sourceVal == "latin" then sourceVal = TranslationEngine.detectDominantScriptLang(table.concat(text)) or "en" end
            if sourceVal == "han" or sourceVal == "ja" then sourceVal = japanese and "ja" or "zh" end
            for slotIndex2 = start, finish - 1 do tokenLanguages[slotIndex2] = sourceVal end
            start = finish
        end
    end
    local foreignFound = 0
    local foreignChars = 0   
    local usedLanguages = {}
    local unknownByLanguage = {}
    local currentLanguage = langCode
    local cjkOut = (target == "zhCN" or target == "zhTW")

    local pieces, terms, visitedMap, found = {}, {}, {}, 0
    local coverHit, coverMiss = 0, 0
    local unknown = {}
    local unknownRun = ""
    local unknownLanguage = langCode
    local function flushUnknown()
        if unknownRun ~= "" then
            unknown[#unknown + 1] = unknownRun
            unknownByLanguage[unknownLanguage] = unknownByLanguage[unknownLanguage] or {}
            table.insert(unknownByLanguage[unknownLanguage], unknownRun)
            unknownRun = ""
        end
    end
    local function hasNumber(tok) return tok.kind == "word" and tok.key:find("^[%d%p]+$") ~= nil end
    local function emit(kind, s)
        if kind ~= "miss" then flushUnknown() end
        pieces[#pieces + 1] = { kind = kind, s = s }
    end
    local function addTerm(term, meaning, strLength)
        found = found + 1
        if meaning ~= "" and not visitedMap[term] and #terms < 14 and strLength > 0 and meaning:lower() ~= term:lower() then
            visitedMap[term] = true
            terms[#terms + 1] = { term, meaning }
        end
    end

    local i, nodeEntry = 1, #tokens
    while i <= nodeEntry do
        local resolvedValue = tokens[i]
        local matched = false
        currentLanguage = tokenLanguages[i] or langCode
        local sourceVal = currentLanguage
        
        if langCode == "zh" and resolvedValue.kind == "word" and ({fm=true,t=true,n=true,dps=true,dz=true,fs=true,lr=true,ms=true,qs=true,sm=true,ss=true,xd=true,zs=true})[resolvedValue.key] then
            sourceVal = "zh"
            currentLanguage = sourceVal
        end
        local cjkMode = sourceVal == "zh" or sourceVal == "ja" or sourceVal == "ko"
        local mainDicts = sourceVal == "ja" and {activeLanguageDict.ja, activeLanguageDict.zh} or {activeLanguageDict[sourceVal] or {}}
        local wordDicts = {activeLanguageDict[sourceVal] or {}, activeLanguageDict.en or {}}
        
        if sourceVal == "en" and activeLanguageDict.es then wordDicts[3] = activeLanguageDict.es end
        local maxLen = resolveMaxLen[sourceVal] or 1
        if sourceVal == "ja" then maxLen = math.max(maxLen, resolveMaxLen.zh or 1) end
        local localSource = ns.SAME_SOURCE and ns.SAME_SOURCE[target] == sourceVal
        local disabled = not (options and options.outgoing) and ns.db and ns.db.chat and ns.db.chat.langs and ns.db.chat.langs[sourceVal] == false
        if disabled then mainDicts, wordDicts = {}, {} end
        
        local t2Val, t3Val = tokens[i + 1], tokens[i + 2]
        if (sourceVal == "zh" or sourceVal == "ja") and not localSource and not disabled and resolvedValue.kind == "word" and resolvedValue.key:find("^%d%d?$")
            and t2Val and t2Val.key == "=" and t3Val and t3Val.kind == "word" and t3Val.key:find("^%d%d?$") then
            local have, need = tonumber(resolvedValue.key), tonumber(t3Val.key)
            if have >= 1 and need >= 1 and have + need <= 40 then
                local fmt = PARTY_COUNT[target] or PARTY_COUNT.en
                emit("hit", fmt:format(have, need))
                foreignFound = foreignFound + 1
                foreignChars = foreignChars + 3
                usedLanguages[sourceVal] = true
                found = found + 1
                coverHit = coverHit + 1
                i = i + 3
                matched = true
            end
        end
        if matched then
            
        elseif resolvedValue.kind == "cjk" or resolvedValue.kind == "word" then
            
            local keys, last = {}, nil
            local subIndex, used = i, 0
            local best, bestJ = nil, nil
            while subIndex <= nodeEntry and used < maxLen do
                local tjVal = tokens[subIndex]
                
                if tjVal.kind ~= "space" and tokenLanguages[subIndex] and tokenLanguages[subIndex] ~= sourceVal
                    and not ((sourceVal == "zh" or sourceVal == "ja") and tjVal.kind == "word" and subIndex > i
                        and (tokens[subIndex - 1].kind == "cjk" or (sourceVal == "zh" and langCode == "zh")))
                    and not (sourceVal == "zh" and langCode == "zh" and subIndex == i) then break end
                if tjVal.kind == "space" then
                    
                    local nxVal = tokens[subIndex + 1]
                    if not nxVal or (nxVal.kind ~= "word" and nxVal.key ~= "(" and not (cjkMode and nxVal.kind == "cjk")) then break end
                    keys[#keys + 1] = " "
                elseif tjVal.kind == "cjk" or tjVal.kind == "word" then
                    if cjkMode and tjVal.kind == "word" and last == "word" then break end
                    keys[#keys + 1] = tjVal.key
                    used = used + 1
                    last = tjVal.kind
                    local lookupKey = table.concat(keys)
                    local e = TranslationEngine.lookup(mainDicts, lookupKey)
                    if not e and used == 1 and tjVal.kind == "word" then e = TranslationEngine.lookup(wordDicts, lookupKey) end
                    if e then best, bestJ = e, subIndex end
                elseif tjVal.kind == "other" and (tjVal.key:match("^[%p]$")) then
                    
                    keys[#keys + 1] = tjVal.key
                    used = used + 1
                    local e = TranslationEngine.lookup(mainDicts, table.concat(keys))
                    if e then best, bestJ = e, subIndex end
                else
                    break
                end
                if not cjkMode and tjVal.kind == "cjk" then break end
                subIndex = subIndex + 1
            end
            
            if not disabled and ns.CustomEntries then
                local parts = {}
                for x = i, math.min(nodeEntry, i + (ns.CustomMaxLen or 0) - 1) do
                    local txVal = tokens[x]
                    if txVal.kind ~= "space" and txVal.kind ~= "word" and txVal.kind ~= "cjk"
                        and not (txVal.kind == "other" and txVal.key:match("^[%p]$")) then break end
                    local xlVal = tokenLanguages[x]
                    if not (options and options.outgoing) and xlVal and ns.db and ns.db.chat
                        and ns.db.chat.langs and ns.db.chat.langs[xlVal] == false then break end
                    parts[#parts + 1] = txVal.key
                    local lookupKey = table.concat(parts)
                    if not ns.CustomPrefixes[lookupKey] then break end
                    if ns.CustomEntries[lookupKey] then best, bestJ = ns.CustomEntries[lookupKey], x end
                end
            end
            if best then
                local orig = {}
                for x = i, bestJ do orig[#orig + 1] = tokens[x].text end
                local term = table.concat(orig)
                for x = i, bestJ do
                    if tokens[x].kind ~= "space" and not hasNumber(tokens[x])
                        and (not localSource or best.custom) then coverHit = coverHit + 1 end
                end
                local meaning = (localSource and not best.custom) and term or TranslationEngine.resolveTermMeaning(best, target)
                usedLanguages[sourceVal] = true
                if not localSource or best.custom then foreignFound = foreignFound + 1; foreignChars = foreignChars + #term end
                if meaning ~= "" then emit("hit", meaning) end
                
                local short = (resolvedValue.kind == "word" and i == bestJ and #resolvedValue.key <= 2 and not cjkMode)
                addTerm(term, meaning, short and 0 or 1)
                i = bestJ + 1
                matched = true
            end
        end
        if not matched and not disabled and not localSource and resolvedValue.kind == "word" then
            local anchorTarget = TranslationEngine.resolveSlashMeaning(resolvedValue.key, sourceVal, target) or TranslationEngine.matchChatPhrasePattern(resolvedValue.key, sourceVal, target)
            if anchorTarget then
                emit("hit", anchorTarget)
                foreignFound = foreignFound + 1
                foreignChars = foreignChars + #resolvedValue.key
                usedLanguages[sourceVal] = true
                found = found + 1
                coverHit = coverHit + 1
                i = i + 1
                matched = true
            end
        end
        
        if not matched and sourceVal == "en" and resolvedValue.text == resolvedValue.text:lower() and resolvedValue.kind == "word" and #resolvedValue.text >= 4
            and resolvedValue.text:find("^%a+$") and not disabled then
            local headerBar = TranslationEngine.assembleHangulFromQwerty(resolvedValue.text)
            if headerBar then
                local e = activeLanguageDict.ko and activeLanguageDict.ko[TranslationEngine.resolveNormKey(headerBar)]
                local meaning = (target == "ko") and headerBar or (e and TranslationEngine.resolveTermMeaning(e, target))
                if meaning and meaning ~= "" then
                    emit("hit", meaning)
                    foreignFound = foreignFound + 1
                    foreignChars = foreignChars + #resolvedValue.text
                    usedLanguages.ko = true
                    found = found + 1
                    coverHit = coverHit + 1
                    i = i + 1
                    matched = true
                end
            end
        end
        if not matched then
            if resolvedValue.kind == "space" then emit("space", " ")
            elseif resolvedValue.kind == "other" then emit("other", resolvedValue.text)
            else
                emit("miss", resolvedValue.text)
                if not hasNumber(resolvedValue) and not localSource and not disabled then
                    coverMiss = coverMiss + 1
                    if resolvedValue.kind == "cjk" then
                        if unknownLanguage ~= sourceVal then flushUnknown() end
                        unknownLanguage = sourceVal; unknownRun = unknownRun .. resolvedValue.key
                    else
                        flushUnknown(); unknown[#unknown + 1] = resolvedValue.key
                        unknownByLanguage[sourceVal] = unknownByLanguage[sourceVal] or {}
                        table.insert(unknownByLanguage[sourceVal], resolvedValue.key)
                    end
                end
            end
            i = i + 1
        end
    end

    flushUnknown()
    
    local outputList, plain, prev, prevS = {}, {}, nil, nil
    for _, anchorTarget in ipairs(pieces) do
        if anchorTarget.kind == "space" then
            if prev and prev ~= "space" then outputList[#outputList + 1] = " "; plain[#plain + 1] = " " end
        else
            if prev and prev ~= "space" and prev ~= "other" and anchorTarget.kind ~= "other"
                and (anchorTarget.kind == "hit" or prev == "hit")
                and not (cjkOut and anchorTarget.kind == "hit" and prev == "hit") then
                outputList[#outputList + 1] = " "; plain[#plain + 1] = " "
            elseif prev == "other" and anchorTarget.kind ~= "other" and prevS and prevS:find("^[,%.!%?:;]$") then
                outputList[#outputList + 1] = " "; plain[#plain + 1] = " "
            end
            plain[#plain + 1] = anchorTarget.s
            if anchorTarget.kind == "hit" then
                outputList[#outputList + 1] = "|cff99ff99" .. anchorTarget.s .. "|r"
            else
                outputList[#outputList + 1] = anchorTarget.s
            end
        end
        prev, prevS = anchorTarget.kind, anchorTarget.s
    end
    
    local alt, prevAlt = {}, nil
    for _, anchorTarget in ipairs(pieces) do
        local s2Val, k = anchorTarget.s, anchorTarget.kind
        if k == "miss" and s2Val:find("[\227-\233]") then s2Val, k = "…", "hit" end
        if k == "space" then
            if prevAlt and prevAlt ~= "space" then alt[#alt + 1] = " " end
        elseif not (s2Val == "…" and alt[#alt] == "…") and not (s2Val == "…" and alt[#alt] == " " and alt[#alt - 1] == "…") then
            if prevAlt and prevAlt ~= "space" and prevAlt ~= "other" and k ~= "other" and not (cjkOut and k == "hit" and prevAlt == "hit") then
                alt[#alt + 1] = " "
            end
            alt[#alt + 1] = s2Val
        end
        prevAlt = k
    end
    local grandTotal = coverHit + coverMiss
    return {
        plainNoCJK = table.concat(alt),
        rough = table.concat(outputList),
        plain = table.concat(plain),
        terms = terms,
        unknown = unknown,
        unknownByLanguage = unknownByLanguage,
        foreignFound = foreignFound,
        foreignChars = foreignChars,
        languages = usedLanguages,
        found = found,
        coverageTotal = grandTotal,
        cover = grandTotal > 0 and floor(coverHit * 100 / grandTotal) or 0,
    }
end
ns.TranslateChatMessageLine = TranslationEngine.translateTokenSequence

ns.IsSecret = TranslationEngine.hasSecret
ns.SafeString = TranslationEngine.safeString

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
TranslationEngine.DetectDominantScriptLanguage = ns.DetectDominantScriptLanguage
TranslationEngine.TranslateChatMessageLine = ns.TranslateChatMessageLine
TranslationEngine.AssembleHangulFromQwerty = ns.AssembleHangulFromQwerty
TranslationEngine.MatchChatPhrasePattern = ns.MatchChatPhrasePattern
TranslationEngine.LookupGlossaryTranslation = ns.LookupGlossaryTranslation
TranslationEngine.NormalizeGlossaryLookupKey = ns.NormalizeGlossaryLookupKey
TranslationEngine.LookupSlashCompoundTranslation = ns.LookupSlashCompoundTranslation
