--===========================================================================
-- EzWoW - Chat Translator
-- Core/LocaleUI.lua : Localized Options Panel & Dictionary Labels
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local LocaleOptionsText = ns.LocaleOptionsText or {}
ns.LocaleOptionsText = LocaleOptionsText

ns.DEFAULTS.chat.copyAll = true        
ns.DEFAULTS.chat.playerTip = true      
ns.DEFAULTS.chat.channels = { public = true, say = true, guild = true, group = true, whisper = true }
ns.DEFAULTS.minimap = { show = true, angle = 205 }
ns.DEFAULTS.custom = {}                 

local resolveOptionsLocaleText = {
    ko = {
        optCopyAll = "모든 메시지 클릭해서 복사 (번역 안 하는 메시지 포함)",
        secLangs = "번역할 언어", secChannels = "번역할 채널", secMisc = "기타",
        chPublic = "공개 채널 (거래·파티찾기·공용)", chSay = "일반 대화·외치기", chGuild = "길드·관리자",
        chGroup = "파티·공격대·인스턴스", chWhisper = "귓속말",
        optPlayerTip = "채팅 이름에 캐릭터 정보 툴팁 (Shift+클릭 조회)",
        optMinimap = "미니맵 버튼 표시",
        resetIconPos = "아이콘·창 위치 초기화",
        btnUnknown = "미등록 표현", btnCollected = "수집 문장", btnStatus = "상태 복사", btnHelp = "명령어",
        langsShort = "번역할 언어 (현지 언어는 제외)",
        sameLang = "현지 언어",
        minimapTip = "왼쪽 클릭: 설정 열기/닫기\n오른쪽 클릭: 미등록 표현 보기\n드래그: 아이콘 위치 이동",
        panelDesc = "다국어 채팅과 미번역 아이템·주문 툴팁을 내장 와우 용어 사전으로 번역해 표시합니다.",
        panelBtn = "설정 (/ezct, /ezct)",
        panelHint = "채팅창에 /ezct, /ezct 또는 /번역을 입력해도 열립니다.",
        unknownEmpty = "아직 수집된 미등록 표현이 없습니다.",
        unknownCopyTitle = "미등록 표현 전체 복사: Ctrl+C",
        statusCopyTitle = "상태 정보 전체 복사: Ctrl+C",
        outDone = "%s(으)로 바꿨습니다 (풀이 %d%%). 채팅 입력창을 확인하고 Enter를 누르세요.",
        outLeft = "번역 못 한 부분: %s",
        outUsage = "사용법: /ezct en 보낼 문장  (en · de · fr · es · ru · zh · tw · ja · ko)",
        outNone = "사전에 있는 표현이 없어 바꾸지 못했습니다.",
        addDone = "단어 추가: %s → %s", addUsage = "사용법: /ezct add 단어=뜻   (삭제: /ezct del 단어, 목록: /ezct list)",
        delDone = "단어 삭제: %s", delNone = "내가 추가한 단어가 아닙니다: %s",
        listTitle = "내가 추가한 단어 %d개", listEmpty = "추가한 단어가 없습니다.",
        searchUsage = "사용법: /ezct search 검색할 단어",
        searchNone = "사전에서 일치하는 표현을 찾지 못했습니다: %s",
        searchTitle = "사전 검색 결과 (%s): %d개",
        toggleOn = "채팅 번역: 켜짐",
        toggleOff = "채팅 번역: 꺼짐",
        collectedTitle = "툴팁에서 모은 미번역 문장 %d개 (Ctrl+C로 복사)", collectedEmpty = "아직 모은 문장이 없습니다.",
        help = "/ezct (/ezct, /번역) - 설정창\n/ezct on|off - 채팅 번역 켜기/끄기\n/ezct lang <코드|auto> - 번역 대상 언어 변경\n/ezct en 문장 - 내 메시지를 외국어로 (en·de·fr·es·ru·zh·tw·ja·ko)\n/ezct search 단어 - 내장 사전 검색\n/ezct add 단어=뜻 - 나만의 단어 추가\n/ezct del 단어 - 삭제\n/ezct list - 추가한 단어 목록\n/ezct unknown - 채팅 미등록 표현\n/ezct collect - 툴팁 미번역 문장\n/ezct status - 상태 정보\n/ezct test 문장 - 풀이 시험",
        helpTitle = "명령어 목록",
    },
    en = {
        optCopyAll = "Click any message to copy it (even untranslated)",
        secLangs = "Languages to translate", secChannels = "Channels to translate", secMisc = "Other",
        chPublic = "Public channels (Trade, LFG, General)", chSay = "Say and yell", chGuild = "Guild and officer",
        chGroup = "Party, raid and instance", chWhisper = "Whispers",
        optPlayerTip = "Character info on chat names (Shift-click)",
        optCover = "Min. coverage to append: %d%%",
        optMinimap = "Show minimap button",
        resetIconPos = "Reset Icon & Window Pos",
        btnUnknown = "Unknown words", btnCollected = "Collected", btnStatus = "Copy status", btnHelp = "Commands",
        langsShort = "Languages to translate (local language excluded)",
        sameLang = "local language",
        minimapTip = "Left-click: Open/close settings\nRight-click: Unknown expressions\nDrag: Move icon",
        panelDesc = "Translates foreign chat and untranslated item/spell tooltips using a built-in WoW dictionary.",
        panelBtn = "Settings (/ezct, /ezct)",
        panelHint = "Type /ezct or /ezct in chat to open settings.",
        unknownEmpty = "No unknown expressions collected yet.",
        unknownCopyTitle = "Copy unknown expressions: Ctrl+C",
        statusCopyTitle = "Copy all status information: Ctrl+C",
        outDone = "Converted to %s (%d%% recognized). Check the chat box and press Enter.",
        outLeft = "Not translated: %s",
        outUsage = "Usage: /ezct en your message  (en, de, fr, es, ru, zh, tw, ja, ko)",
        outNone = "No dictionary expressions found; nothing was converted.",
        addDone = "Word added: %s → %s", addUsage = "Usage: /ezct add word=meaning   (remove: /ezct del word, list: /ezct list)",
        delDone = "Word removed: %s", delNone = "Not one of your words: %s",
        listTitle = "Your words: %d", listEmpty = "You have not added any words.",
        searchUsage = "Usage: /ezct search <word>",
        searchNone = "No matching dictionary entries found: %s",
        searchTitle = "Dictionary search (%s): %d matches",
        toggleOn = "Chat translation: ON",
        toggleOff = "Chat translation: OFF",
        collectedTitle = "Untranslated tooltip sentences: %d (Ctrl+C to copy)", collectedEmpty = "No sentences collected yet.",
        help = "/ezct (/ezct) - settings\n/ezct on|off - toggle chat translation\n/ezct lang <code|auto> - switch target language\n/ezct en text - convert your message (en, de, fr, es, ru, zh, tw, ja, ko)\n/ezct search word - search dictionary\n/ezct add word=meaning - add your own word\n/ezct del word - remove it\n/ezct list - your words\n/ezct unknown - unknown chat expressions\n/ezct collect - untranslated tooltip sentences\n/ezct status - status\n/ezct test text - test a message",
        helpTitle = "Commands",
    },
    zhCN = {
        optCopyAll = "点击任何消息都可复制（包括未翻译的）",
        secLangs = "要翻译的语言", secChannels = "要翻译的频道", secMisc = "其他",
        chPublic = "公共频道（交易、寻求组队、综合）", chSay = "说话和大喊", chGuild = "公会和官员",
        chGroup = "小队、团队和副本", chWhisper = "密语",
        optPlayerTip = "聊天角色名显示角色信息提示（Shift点击查询）",
        optMinimap = "显示小地图按钮",
        btnUnknown = "未登记词语", btnCollected = "收集的句子", btnStatus = "复制状态", btnHelp = "命令",
        langsShort = "要翻译的语言（排除本地语言）",
        sameLang = "本地语言",
        minimapTip = "左键：打开/关闭设置\n右键：查看未登记词语\n拖动：移动按钮",
        panelDesc = "使用内置魔兽世界词典翻译外语聊天与未翻译的物品/法术提示。",
        panelBtn = "设置 (/ezct, /ezct)",
        panelHint = "在聊天框输入 /ezct 或 /ezct 也可打开设置。",
        unknownEmpty = "尚未收集到未登记表达。",
        unknownCopyTitle = "复制全部未登记表达：Ctrl+C",
        statusCopyTitle = "复制全部状态信息：Ctrl+C",
        outDone = "已转换为%s（识别%d%%）。请检查聊天输入框后按回车。",
        outLeft = "未翻译部分：%s",
        outUsage = "用法：/ezct en 要发送的句子（en、de、fr、es、ru、zh、tw、ja、ko）",
        outNone = "没有找到词典中的表达，未转换。",
        addDone = "已添加词语：%s → %s", addUsage = "用法：/ezct add 词语=意思（删除：/ezct del 词语，列表：/ezct list）",
        delDone = "已删除词语：%s", delNone = "不是你添加的词语：%s",
        listTitle = "你添加的词语：%d个", listEmpty = "还没有添加词语。",
        searchUsage = "用法：/ezct search 要搜索的词语",
        searchNone = "词典中未找到匹配项：%s",
        searchTitle = "词典搜索结果（%s）：%d条",
        toggleOn = "聊天翻译：已开启",
        toggleOff = "聊天翻译：已关闭",
        collectedTitle = "收集的未翻译提示句子：%d个（Ctrl+C复制）", collectedEmpty = "还没有收集到句子。",
        help = "/ezct (/ezct) - 设置\n/ezct on|off - 开启/关闭聊天翻译\n/ezct lang <代码|auto> - 切换目标语言\n/ezct en 句子 - 把你的消息转换为外语（en、de、fr、es、ru、zh、tw、ja、ko）\n/ezct search 词语 - 搜索内置词典\n/ezct add 词语=意思 - 添加自定义词语\n/ezct del 词语 - 删除\n/ezct list - 自定义词语列表\n/ezct unknown - 未登记的聊天表达\n/ezct collect - 未翻译的提示句子\n/ezct status - 状态\n/ezct test 句子 - 测试",
        helpTitle = "命令列表",
    },
    ja = {
        optCopyAll = "どのメッセージもクリックでコピー（未翻訳も含む）",
        secLangs = "翻訳する言語", secChannels = "翻訳するチャンネル", secMisc = "その他",
        chPublic = "公開チャンネル（取引・LFG・全般）", chSay = "発言・叫び", chGuild = "ギルド・オフィサー",
        chGroup = "パーティ・レイド・インスタンス", chWhisper = "ささやき",
        optPlayerTip = "名前にキャラ情報を表示（Shift+クリック）",
        optMinimap = "ミニマップボタンを表示",
        btnUnknown = "未登録の表現", btnCollected = "収集した文", btnStatus = "状態をコピー", btnHelp = "コマンド",
        langsShort = "翻訳する言語（翻訳先の言語は除外）",
        sameLang = "翻訳先の言語",
        minimapTip = "左クリック：設定を開く/閉じる\n右クリック：未登録の表現を表示\nドラッグ：ボタンを移動",
        panelDesc = "内蔵のWoW用語辞書で外国語チャットや未翻訳のアイテム・呪文ツールチップを翻訳します。",
        panelBtn = "設定 (/ezct, /ezct)",
        panelHint = "チャット欄に /ezct または /ezct と入力しても開けます。",
        unknownEmpty = "まだ収集された未登録の表現はありません。",
        unknownCopyTitle = "未登録の表現をすべてコピー：Ctrl+C",
        statusCopyTitle = "状態情報をすべてコピー：Ctrl+C",
        outDone = "%sに変換しました（認識 %d%%）。入力欄を確認して Enter を押してください。",
        outLeft = "翻訳できなかった部分：%s",
        outUsage = "使い方：/ezct en 送る文（en・de・fr・es・ru・zh・tw・ja・ko）",
        outNone = "辞書にある表現がないため変換できませんでした。",
        addDone = "単語を追加：%s → %s", addUsage = "使い方：/ezct add 単語=意味（削除：/ezct del 単語、一覧：/ezct list）",
        delDone = "単語を削除：%s", delNone = "追加した単語ではありません：%s",
        listTitle = "追加した単語：%d個", listEmpty = "追加した単語はありません。",
        searchUsage = "使い方：/ezct search 検索する単語",
        searchNone = "辞書に一致する表現が見つかりませんでした：%s",
        searchTitle = "辞書検索結果（%s）：%d件",
        toggleOn = "チャット翻訳：オン",
        toggleOff = "チャット翻訳：オフ",
        collectedTitle = "収集した未翻訳の文：%d個（Ctrl+Cでコピー）", collectedEmpty = "まだ収集した文はありません。",
        help = "/ezct (/ezct) - 設定\n/ezct on|off - チャット翻訳のオン/オフ\n/ezct lang <コード|auto> - 翻訳先の言語を変更\n/ezct en 文 - 自分のメッセージを外国語に（en・de・fr・es・ru・zh・tw・ja・ko）\n/ezct search 単語 - 辞書を検索\n/ezct add 単語=意味 - 単語を追加\n/ezct del 単語 - 削除\n/ezct list - 追加した単語\n/ezct unknown - 未登録のチャット表現\n/ezct collect - 未翻訳のツールチップ文\n/ezct status - 状態\n/ezct test 文 - テスト",
        helpTitle = "コマンド一覧",
    },
    ru = {
        optCopyAll = "Копировать любое сообщение щелчком",
        secLangs = "Переводить с языков", secChannels = "Переводить каналы", secMisc = "Прочее",
        chPublic = "Общие каналы (торговля, поиск группы)", chSay = "Сказать и крик", chGuild = "Гильдия и офицеры",
        chGroup = "Группа, рейд, подземелье", chWhisper = "Шёпот",
        optPlayerTip = "Инфо о персонаже (Shift+щелчок)",
        optMinimap = "Кнопка у миникарты",
        btnUnknown = "Новые слова", btnCollected = "Собранное", btnStatus = "Статус", btnHelp = "Команды",
        langsShort = "Переводить с языков (кроме родного)",
        sameLang = "родной язык",
        minimapTip = "ЛКМ: открыть/закрыть настройки\nПКМ: неизвестные выражения\nПеретаскивание: переместить",
        panelDesc = "Переводит иноязычный чат и непереведённые подсказки предметов и заклинаний с помощью встроенного словаря WoW.",
        panelBtn = "Настройки (/ezct, /ezct)",
        panelHint = "Введите /ezct или /ezct в чате, чтобы открыть настройки.",
        unknownEmpty = "Неизвестные выражения ещё не собраны.",
        unknownCopyTitle = "Скопировать неизвестные выражения: Ctrl+C",
        statusCopyTitle = "Скопировать всю информацию о статусе: Ctrl+C",
        outDone = "Переведено на %s (распознано %d%%). Проверьте строку чата и нажмите Enter.",
        outLeft = "Не переведено: %s",
        outUsage = "Использование: /ezct en сообщение  (en, de, fr, es, ru, zh, tw, ja, ko)",
        outNone = "В словаре нет подходящих выражений, перевод не выполнен.",
        addDone = "Слово добавлено: %s → %s", addUsage = "Использование: /ezct add слово=значение   (удалить: /ezct del слово, список: /ezct list)",
        delDone = "Слово удалено: %s", delNone = "Это не ваше слово: %s",
        listTitle = "Ваши слова: %d", listEmpty = "Вы ещё не добавили слов.",
        searchUsage = "Использование: /ezct search <слово>",
        searchNone = "Совпадений в словаре не найдено: %s",
        searchTitle = "Поиск по словарю (%s): %d",
        toggleOn = "Перевод чата: ВКЛ",
        toggleOff = "Перевод чата: ВЫКЛ",
        collectedTitle = "Непереведённые фразы подсказок: %d (Ctrl+C — копировать)", collectedEmpty = "Фраз пока нет.",
        help = "/ezct (/ezct) - настройки\n/ezct on|off - вкл/выкл перевод чата\n/ezct lang <код|auto> - сменить язык\n/ezct en текст - перевести своё сообщение (en, de, fr, es, ru, zh, tw, ja, ko)\n/ezct search слово - поиск по словарю\n/ezct add слово=значение - добавить слово\n/ezct del слово - удалить\n/ezct list - ваши слова\n/ezct unknown - неизвестные выражения чата\n/ezct collect - непереведённые фразы подсказок\n/ezct status - статус\n/ezct test текст - проверка",
        helpTitle = "Команды",
        
        optTooltip = "Переводить описания предметов и заклинаний",
        optHover = "Подсказка при наведении на сообщение",
    },
    es = {
        optCopyAll = "Clic en cualquier mensaje para copiarlo",
        secLangs = "Idiomas que traducir", secChannels = "Canales que traducir", secMisc = "Otros",
        chPublic = "Canales públicos (Comercio, Buscar grupo)", chSay = "Decir y gritar", chGuild = "Hermandad y oficiales",
        chGroup = "Grupo, banda e instancia", chWhisper = "Susurros",
        optPlayerTip = "Info del personaje en nombres (Mayús+clic)",
        optTooltip = "Traducir descripciones de objetos y hechizos",
        optMinimap = "Mostrar botón del minimapa",
        btnUnknown = "Desconocidas", btnCollected = "Recopiladas", btnStatus = "Copiar estado", btnHelp = "Comandos",
        langsShort = "Idiomas que traducir (sin el idioma local)",
        sameLang = "idioma local",
        minimapTip = "Clic izquierdo: abrir/cerrar ajustes\nClic derecho: expresiones desconocidas\nArrastrar: mover el botón",
        panelDesc = "Traduce el chat en otros idiomas y las descripciones de objetos y hechizos mediante un diccionario integrado de WoW.",
        panelBtn = "Ajustes (/ezct, /ezct)",
        panelHint = "Escribe /ezct o /ezct en el chat para abrir los ajustes.",
        unknownEmpty = "Aún no se han recopilado expresiones desconocidas.",
        unknownCopyTitle = "Copiar expresiones desconocidas: Ctrl+C",
        statusCopyTitle = "Copiar toda la información de estado: Ctrl+C",
        outDone = "Convertido a %s (%d%% reconocido). Revisa el chat y pulsa Intro.",
        outLeft = "Sin traducir: %s",
        outUsage = "Uso: /ezct en tu mensaje  (en, de, fr, es, ru, zh, tw, ja, ko)",
        outNone = "No hay expresiones del diccionario; no se convirtió nada.",
        addDone = "Palabra añadida: %s → %s", addUsage = "Uso: /ezct add palabra=significado   (borrar: /ezct del palabra, lista: /ezct list)",
        delDone = "Palabra borrada: %s", delNone = "No es una de tus palabras: %s",
        listTitle = "Tus palabras: %d", listEmpty = "No has añadido palabras.",
        searchUsage = "Uso: /ezct search <palabra>",
        searchNone = "No se encontraron coincidencias en el diccionario: %s",
        searchTitle = "Búsqueda en el diccionario (%s): %d",
        toggleOn = "Traducción de chat: ACTIVADA",
        toggleOff = "Traducción de chat: DESACTIVADA",
        collectedTitle = "Frases de descripciones sin traducir: %d (Ctrl+C para copiar)", collectedEmpty = "Todavía no hay frases.",
        help = "/ezct (/ezct) - ajustes\n/ezct on|off - activar/desactivar traducción\n/ezct lang <código|auto> - cambiar idioma\n/ezct en texto - convertir tu mensaje (en, de, fr, es, ru, zh, tw, ja, ko)\n/ezct search palabra - buscar en el diccionario\n/ezct add palabra=significado - añadir palabra\n/ezct del palabra - borrar\n/ezct list - tus palabras\n/ezct unknown - expresiones desconocidas\n/ezct collect - frases sin traducir\n/ezct status - estado\n/ezct test texto - probar",
        helpTitle = "Comandos",
    },
    de = {
        optCopyAll = "Nachrichten per Klick kopieren (auch nicht übersetzte)",
        secLangs = "Zu übersetzende Sprachen", secChannels = "Zu übersetzende Kanäle", secMisc = "Sonstiges",
        chPublic = "Öffentliche Kanäle (Handel, SNG, Allgemein)", chSay = "Sagen und Schreien", chGuild = "Gilde und Offizier",
        chGroup = "Gruppe, Schlachtzug und Instanz", chWhisper = "Flüstern",
        optPlayerTip = "Charakter-Info bei Namen (Umschalt+Klick)",
        optTooltip = "Objekt- und Zauberbeschreibungen übersetzen",
        optMinimap = "Minikarten-Button anzeigen",
        btnUnknown = "Unbekannte", btnCollected = "Gesammelte", btnStatus = "Status kopieren", btnHelp = "Befehle",
        langsShort = "Zu übersetzende Sprachen (ohne Zielsprache)",
        sameLang = "Zielsprache",
        minimapTip = "Linksklick: Einstellungen öffnen/schließen\nRechtsklick: Unbekannte Ausdrücke\nZiehen: Button verschieben",
        panelDesc = "Übersetzt fremdsprachigen Chat sowie nicht übersetzte Gegenstands- und Zauber-Tooltips mit einem integrierten WoW-Wörterbuch.",
        panelBtn = "Einstellungen (/ezct, /ezct)",
        panelHint = "Gib /ezct oder /ezct im Chat ein, um die Einstellungen zu öffnen.",
        unknownEmpty = "Noch keine unbekannten Ausdrücke gesammelt.",
        unknownCopyTitle = "Unbekannte Ausdrücke kopieren: Strg+C",
        statusCopyTitle = "Alle Statusinformationen kopieren: Strg+C",
        outDone = "In %s umgewandelt (%d%% erkannt). Prüfe das Chatfeld und drücke Enter.",
        outLeft = "Nicht übersetzt: %s",
        outUsage = "Verwendung: /ezct en deine Nachricht  (en, de, fr, es, ru, zh, tw, ja, ko)",
        outNone = "Keine Wörterbuch-Ausdrücke gefunden; nichts umgewandelt.",
        addDone = "Wort hinzugefügt: %s → %s", addUsage = "Verwendung: /ezct add Wort=Bedeutung   (löschen: /ezct del Wort, Liste: /ezct list)",
        delDone = "Wort gelöscht: %s", delNone = "Keines deiner Wörter: %s",
        listTitle = "Deine Wörter: %d", listEmpty = "Du hast noch keine Wörter hinzugefügt.",
        searchUsage = "Verwendung: /ezct search <Wort>",
        searchNone = "Keine passenden Wörterbucheinträge gefunden: %s",
        searchTitle = "Wörterbuchsuche (%s): %d Treffer",
        toggleOn = "Chat-Übersetzung: EIN",
        toggleOff = "Chat-Übersetzung: AUS",
        collectedTitle = "Nicht übersetzte Tooltip-Sätze: %d (Strg+C zum Kopieren)", collectedEmpty = "Noch keine Sätze gesammelt.",
        help = "/ezct (/ezct) - Einstellungen\n/ezct on|off - Chat-Übersetzung ein/aus\n/ezct lang <Code|auto> - Sprache wechseln\n/ezct en Text - eigene Nachricht übersetzen (en, de, fr, es, ru, zh, tw, ja, ko)\n/ezct search Wort - Wörterbuch durchsuchen\n/ezct add Wort=Bedeutung - eigenes Wort hinzufügen\n/ezct del Wort - löschen\n/ezct list - eigene Wörter\n/ezct unknown - unbekannte Chat-Ausdrücke\n/ezct collect - nicht übersetzte Tooltip-Sätze\n/ezct status - Status\n/ezct test Text - Nachricht testen",
        helpTitle = "Befehle",
    },
    fr = {
        optCopyAll = "Cliquer sur un message pour le copier (même non traduit)",
        secLangs = "Langues à traduire", secChannels = "Canaux à traduire", secMisc = "Autres",
        chPublic = "Canaux publics (Commerce, RdG, Général)", chSay = "Dire et crier", chGuild = "Guilde et officier",
        chGroup = "Groupe, raid et instance", chWhisper = "Chuchotements",
        optPlayerTip = "Infos personnage sur les noms (Maj+clic)",
        optTooltip = "Traduire les descriptions d'objets et sorts",
        optMinimap = "Afficher le bouton de la minicarte",
        btnUnknown = "Inconnus", btnCollected = "Collectées", btnStatus = "Copier statut", btnHelp = "Commandes",
        langsShort = "Langues à traduire (sauf langue cible)",
        sameLang = "langue cible",
        minimapTip = "Clic gauche : ouvrir/fermer les options\nClic droit : expressions inconnues\nGlisser : déplacer le bouton",
        panelDesc = "Traduit le chat multilingue et les infobulles d'objets ou de sorts non traduites grâce à un dictionnaire WoW intégré.",
        panelBtn = "Options (/ezct, /ezct)",
        panelHint = "Tapez /ezct ou /ezct dans le chat pour ouvrir les options.",
        unknownEmpty = "Aucune expression inconnue collectée pour le moment.",
        unknownCopyTitle = "Copier les expressions inconnues : Ctrl+C",
        statusCopyTitle = "Copier toutes les informations de statut : Ctrl+C",
        outDone = "Converti en %s (%d%% reconnu). Vérifiez la saisie du chat et appuyez sur Entrée.",
        outLeft = "Non traduit : %s",
        outUsage = "Utilisation : /ezct en votre message  (en, de, fr, es, ru, zh, tw, ja, ko)",
        outNone = "Aucune expression du dictionnaire trouvée ; rien n'a été converti.",
        addDone = "Mot ajouté : %s → %s", addUsage = "Utilisation : /ezct add mot=sens   (suppr. : /ezct del mot, liste : /ezct list)",
        delDone = "Mot supprimé : %s", delNone = "Ce n'est pas l'un de vos mots : %s",
        listTitle = "Vos mots : %d", listEmpty = "Vous n'avez ajouté aucun mot.",
        searchUsage = "Utilisation : /ezct search <mot>",
        searchNone = "Aucune entrée correspondante dans le dictionnaire : %s",
        searchTitle = "Recherche dans le dictionnaire (%s) : %d résultats",
        toggleOn = "Traduction du chat : ACTIVÉE",
        toggleOff = "Traduction du chat : DÉSACTIVÉE",
        collectedTitle = "Phrases d'infobulles non traduites : %d (Ctrl+C pour copier)", collectedEmpty = "Aucune phrase collectée pour le moment.",
        help = "/ezct (/ezct) - options\n/ezct on|off - activer/désactiver la traduction\n/ezct lang <code|auto> - changer de langue\n/ezct en texte - convertir votre message (en, de, fr, es, ru, zh, tw, ja, ko)\n/ezct search mot - chercher dans le dictionnaire\n/ezct add mot=sens - ajouter votre mot\n/ezct del mot - supprimer\n/ezct list - vos mots\n/ezct unknown - expressions inconnues\n/ezct collect - phrases d'infobulles non traduites\n/ezct status - statut\n/ezct test texte - tester un message",
        helpTitle = "Commandes",
    },
}
resolveOptionsLocaleText.zhTW = {}
for entryKey, entryValue in pairs(resolveOptionsLocaleText.zhCN) do resolveOptionsLocaleText.zhTW[entryKey] = entryValue end

resolveOptionsLocaleText.zhTW.secLangs, resolveOptionsLocaleText.zhTW.secChannels, resolveOptionsLocaleText.zhTW.secMisc = "要翻譯的語言", "要翻譯的頻道", "其他"
resolveOptionsLocaleText.zhTW.chPublic, resolveOptionsLocaleText.zhTW.chSay, resolveOptionsLocaleText.zhTW.chGuild = "公共頻道（交易、尋求組隊、綜合）", "說話和大喊", "公會和幹部"
resolveOptionsLocaleText.zhTW.chGroup, resolveOptionsLocaleText.zhTW.chWhisper = "隊伍、團隊和副本", "密語"
resolveOptionsLocaleText.zhTW.optPlayerTip, resolveOptionsLocaleText.zhTW.optMinimap = "聊天角色名顯示角色資訊提示（Shift點擊查詢）", "顯示小地圖按鈕"
resolveOptionsLocaleText.zhTW.btnUnknown, resolveOptionsLocaleText.zhTW.btnCollected, resolveOptionsLocaleText.zhTW.btnStatus, resolveOptionsLocaleText.zhTW.btnHelp = "未登記詞語", "收集的句子", "複製狀態", "指令"
resolveOptionsLocaleText.zhTW.langsShort, resolveOptionsLocaleText.zhTW.sameLang = "要翻譯的語言（排除本地語言）", "本地語言"
resolveOptionsLocaleText.zhTW.minimapTip = "左鍵：開啟/關閉設定\n右鍵：查看未登記詞語\n拖曳：移動按鈕"
resolveOptionsLocaleText.zhTW.panelDesc = "使用內建魔獸世界詞典翻譯外語聊天與未翻譯的物品/法術提示。"
resolveOptionsLocaleText.zhTW.panelBtn = "設定 (/ezct, /ezct)"
resolveOptionsLocaleText.zhTW.panelHint = "在聊天框輸入 /ezct 或 /ezct 也可開啟設定。"
resolveOptionsLocaleText.zhTW.unknownEmpty = "尚未收集到未登記表達。"
resolveOptionsLocaleText.zhTW.unknownCopyTitle = "複製全部未登記表達：Ctrl+C"
resolveOptionsLocaleText.zhTW.statusCopyTitle = "複製全部狀態資訊：Ctrl+C"
resolveOptionsLocaleText.zhTW.outDone = "已轉換為%s（辨識%d%%）。請檢查聊天輸入框後按Enter。"
resolveOptionsLocaleText.zhTW.outLeft = "未翻譯部分：%s"
resolveOptionsLocaleText.zhTW.outUsage = "用法：/ezct en 要傳送的句子（en、de、fr、es、ru、zh、tw、ja、ko）"
resolveOptionsLocaleText.zhTW.outNone = "沒有找到詞典中的表達，未轉換。"
resolveOptionsLocaleText.zhTW.addDone = "已新增詞語：%s → %s"
resolveOptionsLocaleText.zhTW.addUsage = "用法：/ezct add 詞語=意思（刪除：/ezct del 詞語，列表：/ezct list）"
resolveOptionsLocaleText.zhTW.delDone, resolveOptionsLocaleText.zhTW.delNone = "已刪除詞語：%s", "不是你新增的詞語：%s"
resolveOptionsLocaleText.zhTW.listTitle, resolveOptionsLocaleText.zhTW.listEmpty = "你新增的詞語：%d個", "還沒有新增詞語。"
resolveOptionsLocaleText.zhTW.searchUsage = "用法：/ezct search 要搜尋的詞語"
resolveOptionsLocaleText.zhTW.searchNone = "詞典中未找到符合項目：%s"
resolveOptionsLocaleText.zhTW.searchTitle = "詞典搜尋結果（%s）：%d筆"
resolveOptionsLocaleText.zhTW.toggleOn = "聊天翻譯：已開啟"
resolveOptionsLocaleText.zhTW.toggleOff = "聊天翻譯：已關閉"
resolveOptionsLocaleText.zhTW.collectedTitle, resolveOptionsLocaleText.zhTW.collectedEmpty = "收集的未翻譯提示句子：%d個（Ctrl+C複製）", "還沒有收集到句子。"
resolveOptionsLocaleText.zhTW.help = "/ezct (/ezct) - 設定\n/ezct on|off - 開啟/關閉聊天翻譯\n/ezct lang <代碼|auto> - 切換目標語言\n/ezct en 句子 - 把你的訊息轉換為外語（en、de、fr、es、ru、zh、tw、ja、ko）\n/ezct search 詞語 - 搜尋內建詞典\n/ezct add 詞語=意思 - 新增自訂詞語\n/ezct del 詞語 - 刪除\n/ezct list - 自訂詞語列表\n/ezct unknown - 未登記的聊天表達\n/ezct collect - 未翻譯的提示句子\n/ezct status - 狀態\n/ezct test 句子 - 測試"
resolveOptionsLocaleText.zhTW.helpTitle = "指令列表"
resolveOptionsLocaleText.zhTW.optCopyAll = "點擊任何訊息都可複製（包括未翻譯的）"

for langCode, strings in pairs(resolveOptionsLocaleText) do
    local resolvedValue = ns.STR[langCode]
    if resolvedValue then
        for entryKey, entryValue in pairs(strings) do resolvedValue[entryKey] = entryValue end
    end
end
ns.SynchronizeTargetLanguage()
