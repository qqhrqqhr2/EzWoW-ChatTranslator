--===========================================================================
-- EzWoW - Chat Translator
-- Core/LocaleCore.lua : Target Language Resolution & Core String Table
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local LocaleRegistry = ns.LocaleRegistry or {}
ns.LocaleRegistry = LocaleRegistry

ns.DONATE_URL = "https://buymeacoffee.com/qqhrqqhr2"

ns.TARGETS = { "ko", "en", "zhCN", "zhTW", "ru" }
ns.TARGET_NAME = {
    ko = "한국어", en = "English", zhCN = "简体中文", zhTW = "繁體中文", ru = "Русский",
}

local CLIENT_TO_TARGET = { koKR = "ko", zhCN = "zhCN", zhTW = "zhTW", ruRU = "ru" }
ns.CLIENT_TARGET = CLIENT_TO_TARGET[GetLocale()] or "en"

ns.SAME_SOURCE = { ko = "ko", en = "en", zhCN = "zh", zhTW = "zh", ru = "ru" }

ns.DEFAULTS = {
    target = "auto",        
    tooltip = {
        enabled = true,     
        collect = true,     
    },
    chat = {
        enabled = true,     
        inline = true,      
        minCover = 40,      
        tag = true,         
        hoverAll = true,    
        skipSelf = true,    
        langs = { ko = true, zh = true, ja = true, ru = true, en = true },
    },
}

local STR = {}

STR.ko = {
    tipUse = "사용 효과:", tipEquip = "착용 효과:", tipProc = "적중 시 발동:",
    secTooltip = "툴팁 번역",
    optTooltip = "아이템·주문 툴팁의 영어 문장 번역",
    optCollect = "번역 못 한 문장 모으기 (/ezct 수집)",
    tooltipNote = "포에버 신규 아이템처럼 번역이 없는 설명을 툴팁 아래 EzWoW - Chat Translator 칸에 보여 줍니다.",
    collectCount = "모은 미번역 문장: %d개",
    collectHow = "게임을 끄면 WTF\\Account\\(계정)\\SavedVariables\\EzWoW-ChatTranslator.lua 에 저장됩니다. 이 파일을 보내 주시면 사전에 추가합니다. (/ezct 수집 초기화)",
    collectCleared = "모은 문장을 비웠습니다.",
    title = "EzWoW - Chat Translator",
    tag = { ko = "韓", zh = "中", ja = "日", ru = "RU", en = "EN" },
    langName = { ko = "한국어", zh = "중국어", ja = "일본어", ru = "러시아어", en = "영어" },
    glossTitle = "%s → 한국어",
    rough = "대략적인 뜻",
    terms = "찾은 표현",
    noTerms = "사전에 있는 표현이 없습니다.",
    clickHint = "클릭: 복사창 열기 (번역기에 붙여넣기)",
    copyTitle = "Ctrl+C로 복사한 뒤 번역기에 붙여넣으세요",
    copyDonate = "Ctrl+C로 복사해서 브라우저에 붙여넣으세요",
    close = "닫기",
    secTarget = "현지 언어 (번역 결과 언어)",
    auto = "자동 - 게임 언어 (%s)",
    targetNote = "다른 언어 채팅을 모두 이 언어로 풀어 줍니다. 화면 문구도 이 언어로 바뀝니다.",
    secChat = "채팅 번역",
    optEnabled = "채팅 번역 사용",
    optInline = "메시지 뒤에 대략적인 뜻 바로 붙이기",
    optCover = "뜻을 붙일 최소 풀이 비율: %d%%",
    optTag = "메시지 앞에 언어 표시 붙이기 ([中] [RU] 등)",
    optHover = "메시지 전체에 마우스를 올려도 풀이 보기",
    optSelf = "내가 보낸 메시지는 제외",
    langs = "번역할 언어 (현지 언어와 같은 언어는 제외)",
    chatNote = "설정은 새로 들어오는 메시지부터 바로 적용됩니다. 상태 확인: /ezct 상태",
    donate = "후원하기",
}

STR.en = {
    tipUse = "Use:", tipEquip = "Equip:", tipProc = "Chance on hit:",
    secTooltip = "Tooltip translation",
    optTooltip = "Translate English text in item and spell tooltips",
    optCollect = "Collect untranslated sentences (/ezct collect)",
    tooltipNote = "Untranslated descriptions (e.g. new Forever items) are shown in an EzWoW - Chat Translator section at the bottom of the tooltip.",
    collectCount = "Collected untranslated sentences: %d",
    collectHow = "They are saved to WTF\\Account\\(account)\\SavedVariables\\EzWoW-ChatTranslator.lua when you log out. Send that file to the author to add them. (/ezct collect clear)",
    collectCleared = "Collected sentences cleared.",
    title = "EzWoW - Chat Translator",
    tag = { ko = "KO", zh = "ZH", ja = "JA", ru = "RU", en = "EN" },
    langName = { ko = "Korean", zh = "Chinese", ja = "Japanese", ru = "Russian", en = "English" },
    glossTitle = "%s → English",
    rough = "Rough meaning",
    terms = "Known terms",
    noTerms = "No known terms found.",
    clickHint = "Click: open copy box (paste into a translator)",
    copyTitle = "Press Ctrl+C, then paste into a translator",
    copyDonate = "Press Ctrl+C and paste into your browser",
    close = "Close",
    secTarget = "Local language (translate into)",
    auto = "Auto - game language (%s)",
    targetNote = "All other languages are translated into this language. The interface switches to it too.",
    secChat = "Chat translation",
    optEnabled = "Enable chat translation",
    optInline = "Append the rough meaning after the message",
    optCover = "Minimum glossary coverage to append: %d%%",
    optTag = "Add a language tag before messages ([ZH] [RU] ...)",
    optHover = "Show glossary when hovering the whole message",
    optSelf = "Skip my own messages",
    langs = "Languages to translate (your local language is skipped)",
    chatNote = "Changes apply to new messages immediately. Status: /ezct status",
    donate = "Donate",
}

STR.zhCN = {
    tipUse = "使用：", tipEquip = "装备：", tipProc = "击中时可能：",
    secTooltip = "鼠标提示翻译",
    optTooltip = "翻译物品和法术提示中的英文",
    optCollect = "收集未翻译的句子 (/ezct collect)",
    tooltipNote = "没有翻译的说明（如怀旧新物品）会显示在鼠标提示底部的 EzWoW - Chat Translator 栏中。",
    collectCount = "已收集未翻译句子：%d 条",
    collectHow = "退出游戏后保存在 WTF\\Account\\(账号)\\SavedVariables\\EzWoW-ChatTranslator.lua。把文件发给作者即可加入词典。(/ezct collect clear)",
    collectCleared = "已清空收集的句子。",
    title = "EzWoW - Chat Translator",
    tag = { ko = "韩", zh = "中", ja = "日", ru = "俄", en = "英" },
    langName = { ko = "韩语", zh = "中文", ja = "日语", ru = "俄语", en = "英语" },
    glossTitle = "%s → 中文",
    rough = "大致意思",
    terms = "识别到的词",
    noTerms = "词典中没有找到相关词语。",
    clickHint = "点击：打开复制框（粘贴到翻译器）",
    copyTitle = "按 Ctrl+C 复制后粘贴到翻译器",
    copyDonate = "按 Ctrl+C 复制后粘贴到浏览器",
    close = "关闭",
    secTarget = "本地语言（翻译成）",
    auto = "自动 - 游戏语言 (%s)",
    targetNote = "其他语言的聊天都会翻译成这个语言，界面文字也会切换。",
    secChat = "聊天翻译",
    optEnabled = "启用聊天翻译",
    optInline = "在消息后面直接显示大致意思",
    optCover = "显示意思的最低识别比例：%d%%",
    optTag = "在消息前显示语言标记（[韩] [俄] 等）",
    optHover = "鼠标悬停在整条消息上也显示解释",
    optSelf = "不处理自己发送的消息",
    langs = "要翻译的语言（与本地语言相同的除外）",
    chatNote = "设置对新消息立即生效。状态检查：/ezct status",
    donate = "赞助",
}

STR.zhTW = {
    tipUse = "使用：", tipEquip = "裝備：", tipProc = "擊中時可能：",
    secTooltip = "滑鼠提示翻譯",
    optTooltip = "翻譯物品和法術提示中的英文",
    optCollect = "收集未翻譯的句子 (/ezct collect)",
    tooltipNote = "沒有翻譯的說明（如懷舊新物品）會顯示在滑鼠提示底部的 EzWoW - Chat Translator 欄中。",
    collectCount = "已收集未翻譯句子：%d 條",
    collectHow = "離開遊戲後儲存在 WTF\\Account\\(帳號)\\SavedVariables\\EzWoW-ChatTranslator.lua。把檔案傳給作者即可加入詞典。(/ezct collect clear)",
    collectCleared = "已清空收集的句子。",
    title = "EzWoW - Chat Translator",
    tag = { ko = "韓", zh = "中", ja = "日", ru = "俄", en = "英" },
    langName = { ko = "韓語", zh = "中文", ja = "日語", ru = "俄語", en = "英語" },
    glossTitle = "%s → 中文",
    rough = "大致意思",
    terms = "辨識到的詞",
    noTerms = "詞典中沒有找到相關詞語。",
    clickHint = "點擊：開啟複製框（貼到翻譯器）",
    copyTitle = "按 Ctrl+C 複製後貼到翻譯器",
    copyDonate = "按 Ctrl+C 複製後貼到瀏覽器",
    close = "關閉",
    secTarget = "本地語言（翻譯成）",
    auto = "自動 - 遊戲語言 (%s)",
    targetNote = "其他語言的聊天都會翻譯成這個語言，介面文字也會切換。",
    secChat = "聊天翻譯",
    optEnabled = "啟用聊天翻譯",
    optInline = "在訊息後面直接顯示大致意思",
    optCover = "顯示意思的最低辨識比例：%d%%",
    optTag = "在訊息前顯示語言標記（[韓] [俄] 等）",
    optHover = "滑鼠停在整條訊息上也顯示解釋",
    optSelf = "不處理自己發送的訊息",
    langs = "要翻譯的語言（與本地語言相同的除外）",
    chatNote = "設定對新訊息立即生效。狀態檢查：/ezct status",
    donate = "贊助",
}

STR.ru = {
    tipUse = "Использование:", tipEquip = "Если на персонаже:", tipProc = "Вероятность при попадании:",
    secTooltip = "Перевод подсказок",
    optTooltip = "Переводить английский текст в подсказках предметов и заклинаний",
    optCollect = "Собирать непереведённые фразы (/ezct collect)",
    tooltipNote = "Описания без перевода (например, новые предметы Forever) показываются внизу подсказки в разделе EzWoW - Chat Translator.",
    collectCount = "Собрано непереведённых фраз: %d",
    collectHow = "Сохраняются при выходе в WTF\\Account\\(аккаунт)\\SavedVariables\\EzWoW-ChatTranslator.lua. Отправьте файл автору, чтобы их добавить. (/ezct collect clear)",
    collectCleared = "Собранные фразы очищены.",
    title = "EzWoW - Chat Translator",
    tag = { ko = "KO", zh = "ZH", ja = "JA", ru = "RU", en = "EN" },
    langName = { ko = "корейский", zh = "китайский", ja = "японский", ru = "русский", en = "английский" },
    glossTitle = "%s → русский",
    rough = "Примерный смысл",
    terms = "Найденные слова",
    noTerms = "В словаре ничего не найдено.",
    clickHint = "Клик: окно копирования (вставьте в переводчик)",
    copyTitle = "Нажмите Ctrl+C и вставьте в переводчик",
    copyDonate = "Нажмите Ctrl+C и вставьте в браузер",
    close = "Закрыть",
    secTarget = "Родной язык (переводить на)",
    auto = "Авто - язык игры (%s)",
    targetNote = "Сообщения на других языках переводятся на этот язык. Интерфейс тоже переключится.",
    secChat = "Перевод чата",
    optEnabled = "Включить перевод чата",
    optInline = "Показывать смысл сразу после сообщения",
    optCover = "Мин. доля распознанных слов: %d%%",
    optTag = "Метка языка перед сообщением ([ZH] [KO] ...)",
    optHover = "Подсказка при наведении на всё сообщение",
    optSelf = "Не обрабатывать мои сообщения",
    langs = "Переводить с языков (родной язык пропускается)",
    chatNote = "Настройки действуют для новых сообщений сразу. Статус: /ezct status",
    donate = "Поддержать",
}

ns.STR = STR

function ns.ResolveTargetLanguageCode()
    local resolvedValue = ns.db and ns.db.target
    if not resolvedValue or resolvedValue == "auto" or not STR[resolvedValue] then return ns.CLIENT_TARGET end
    return resolvedValue
end

function ns.SynchronizeTargetLanguage()
    local targetKey = ns.ResolveTargetLanguageCode()
    local base = STR[targetKey] or STR.en
    if base ~= STR.en then
        setmetatable(base, { __index = STR.en })
        if base.langName and STR.en.langName then
            setmetatable(base.langName, { __index = STR.en.langName })
        end
        if base.tag and STR.en.tag then
            setmetatable(base.tag, { __index = STR.en.tag })
        end
    end
    ns.L = base
end

ns.SynchronizeTargetLanguage()

-----------------------------------------------------------------------------
-- Module Class Exports
-----------------------------------------------------------------------------
LocaleRegistry.SynchronizeTargetLanguage = ns.SynchronizeTargetLanguage
LocaleRegistry.ResolveTargetLanguageCode = ns.ResolveTargetLanguageCode
