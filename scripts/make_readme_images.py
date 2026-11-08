#!/usr/bin/env python3
"""Draws the README mock-ups of EzWoW - Chat Translator (docs/images/ui_*.png, settings_*.png).

The settings window is rebuilt from the sizes, positions, colours and texts in UI/OptionsWindow.lua,
Core/LocaleCore.lua and Core/LocaleUI.lua (game pixels x SCALE). The chat page uses the tag colours,
tooltip lines and colours of Modules/ChatFilter.lua, Modules/TooltipTranslator.lua,
Modules/PlayerTooltip.lua and UI/MinimapButton.lua. Character names and chat lines are made-up examples.

usage: python scripts/make_readme_images.py .
Renders with headless Chrome (set CHROME to its path if it is not in the default place).
Standard library only.
"""
import base64
import html
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from string import Template

SCALE = 1.36
PAGE_W = 1600

# UI/OptionsWindow.lua colours
C = {
    "bgPrimary": "rgba(18,24,31,.97)", "bgSecondary": "rgba(29,40,49,.96)", "bgAccent": "rgba(31,56,59,.96)",
    "border": "#344c5b", "textBody": "#edf4f7", "textMuted": "#a7b9c5", "accent": "#7adad4",
    "fontDisable": "#808080",
}
CALL = C["accent"]
GLOSS = "#88dd88"                       # meaning after the message (|cff88dd88)
# ChatFilter.lua TAG_COLOR
TAG_COLOR = {"es": "#ffbb88", "ko": "#a0e8a0", "zh": "#ffcc66", "ja": "#ff99cc", "ru": "#99ccff", "en": "#cccccc"}
# default chat colours of the game
CH = {"channel": "#ffc0c0", "party": "#aaaaff", "guild": "#40ff40", "say": "#ffffff", "system": "#ffff00"}

# Core/LocaleCore.lua + Core/LocaleUI.lua (ko / en) - only the strings these pictures show
L = {
    "ko": {
        "secTarget": "현지 언어 (번역 결과 언어)", "auto": "자동 - 게임 언어 (%s)", "client": "한국어",
        "targetNote": "다른 언어 채팅을 모두 이 언어로 풀어 줍니다. 화면 문구도 이 언어로 바뀝니다.",
        "secChat": "채팅 번역", "optEnabled": "채팅 번역 사용", "optInline": "메시지 뒤에 대략적인 뜻 바로 붙이기",
        "optCover": "뜻을 붙일 최소 풀이 비율: %d%%", "optTag": "메시지 앞에 언어 표시 붙이기 ([中] [RU] 등)",
        "optHover": "메시지 전체에 마우스를 올려도 풀이 보기", "optSelf": "내가 보낸 메시지는 제외",
        "optCopyAll": "모든 메시지 클릭해서 복사 (번역 안 하는 메시지 포함)",
        "optPlayerTip": "채팅 이름에 캐릭터 정보 툴팁 (Shift+클릭 조회)",
        "chatNote": "설정은 새로 들어오는 메시지부터 바로 적용됩니다. 상태 확인: /ezct 상태",
        "secLangs": "번역할 언어", "secChannels": "번역할 채널", "secMisc": "기타",
        "chPublic": "공개 채널 (거래·파티찾기·공용)", "chSay": "일반 대화·외치기", "chGuild": "길드·관리자",
        "chGroup": "파티·공격대·인스턴스", "chWhisper": "귓속말",
        "secTooltip": "툴팁 번역", "optTooltip": "아이템·주문 툴팁의 영어 문장 번역",
        "optCollect": "번역 못 한 문장 모으기 (/ezct 수집)",
        "tooltipNote": "포에버 신규 아이템처럼 번역이 없는 설명을 툴팁 아래 EzWoW - Chat Translator 칸에 보여 줍니다.",
        "optMinimap": "미니맵 버튼 표시",
        "btnUnknown": "미등록 표현", "btnCollected": "수집 문장", "btnStatus": "상태 복사", "btnHelp": "명령어",
        "donate": "후원하기", "resetIconPos": "아이콘·창 위치 초기화", "close": "닫기",
        "langName": {"ko": "한국어", "zh": "중국어", "ja": "일본어", "ru": "러시아어", "en": "영어", "es": "스페인어"},
        "tag": {"ko": "韓", "zh": "中", "ja": "日", "ru": "RU", "en": "EN", "es": "ES"},
        "glossTitle": "%s → 한국어", "rough": "대략적인 뜻", "terms": "찾은 표현",
        "clickHint": "클릭: 복사창 열기 (번역기에 붙여넣기)",
        "minimapTip": ["왼쪽 클릭: 설정 열기/닫기", "오른쪽 클릭: 미등록 표현 보기", "드래그: 아이콘 위치 이동"],
        "outDone": "%s(으)로 바꿨습니다 (풀이 %d%%). 채팅 입력창을 확인하고 Enter를 누르세요.",
        "level": "레벨 %s",
    },
    "en": {
        "secTarget": "Local language (translate into)", "auto": "Auto - game language (%s)", "client": "English",
        "targetNote": "All other languages are translated into this language. The interface switches to it too.",
        "secChat": "Chat translation", "optEnabled": "Enable chat translation",
        "optInline": "Append the rough meaning after the message", "optCover": "Min. coverage to append: %d%%",
        "optTag": "Add a language tag before messages ([ZH] [RU] ...)",
        "optHover": "Show glossary when hovering the whole message", "optSelf": "Skip my own messages",
        "optCopyAll": "Click any message to copy it (even untranslated)",
        "optPlayerTip": "Character info on chat names (Shift-click)",
        "chatNote": "Changes apply to new messages immediately. Status: /ezct status",
        "secLangs": "Languages to translate", "secChannels": "Channels to translate", "secMisc": "Other",
        "chPublic": "Public channels (Trade, LFG, General)", "chSay": "Say and yell", "chGuild": "Guild and officer",
        "chGroup": "Party, raid and instance", "chWhisper": "Whispers",
        "secTooltip": "Tooltip translation", "optTooltip": "Translate English text in item and spell tooltips",
        "optCollect": "Collect untranslated sentences (/ezct collect)",
        "tooltipNote": "Untranslated descriptions (e.g. new Forever items) are shown in an EzWoW - Chat Translator "
                       "section at the bottom of the tooltip.",
        "optMinimap": "Show minimap button",
        "btnUnknown": "Unknown words", "btnCollected": "Collected", "btnStatus": "Copy status", "btnHelp": "Commands",
        "donate": "Donate", "resetIconPos": "Reset Icon & Window Pos", "close": "Close",
        "langName": {"ko": "Korean", "zh": "Chinese", "ja": "Japanese", "ru": "Russian", "en": "English", "es": "Spanish"},
        "tag": {"ko": "KO", "zh": "ZH", "ja": "JA", "ru": "RU", "en": "EN", "es": "ES"},
        "glossTitle": "%s → English", "rough": "Rough meaning", "terms": "Known terms",
        "clickHint": "Click: open copy box (paste into a translator)",
        "minimapTip": ["Left-click: Open/close settings", "Right-click: Unknown expressions", "Drag: Move icon"],
        "outDone": "Converted to %s (%d%% recognized). Check the chat box and press Enter.",
        "level": "Level %s",
    },
}

# page texts (title, lead, callout notes)
T = {
    "ko": {
        "head": "외국어 채팅에 언어 태그와 대략적인 뜻을 바로 붙여 주는 사전 번역기 · 툴팁 번역 · 외국어로 보내기",
        "sBadge": "설정창", "sHead": "/ezct · 현지 언어, 채팅 번역 방식, 번역할 언어·채널, 툴팁 번역",
        "tabs": ["일반", "전투 기록", "거래"],
        "chTrade": "2. 거래", "chLFG": "4. 파티찾기", "chGeneral": "1. 공개", "chParty": "파티", "chGuild": "길드",
        "say": "말하기",
        "notes": [
            ("메시지 뒤 풀이", "외국어 채팅 앞에 언어 태그를, 뒤에 초록색 괄호로 대략적인 뜻을 붙입니다. 한국어로 볼 때 중국어·일본어 채팅은 "
                             "뜻을 ↳ 아래 줄에 따로 보여 줍니다. 한국어 채팅은 그대로 둡니다."),
            ("마우스오버 단어장", "태그나 메시지에 마우스를 올리면 원문 · 대략적인 뜻 · 찾은 표현과 현재 인식률이 나옵니다. "
                               "클릭하면 원문 복사창(Ctrl+C)이 열립니다."),
            ("미니맵 버튼", "왼쪽 클릭: 설정창, 오른쪽 클릭: 미등록 표현 목록, 드래그: 위치 이동."),
            ("외국어로 보내기", "/ezct en 문장 처럼 쓰면 사전으로 바꾼 문장이 채팅 입력창에 들어갑니다. 확인한 뒤 Enter로 보냅니다."),
            ("툴팁 번역", "번역이 없는 영어 아이템·주문 문장을 툴팁 아래에 번역해 보여 줍니다. 아이템 이름은 금색, 문장은 초록색."),
            ("캐릭터 정보", "채팅 이름을 Shift+클릭하면 게임 기본 /who 조회로 레벨·종족·직업·길드·지역을 이름 툴팁에 보여 줍니다."),
        ],
        "itemNote": "예: 한국어 클라이언트에서 번역이 없는 아이템",
        "note": "애드온 코드의 창 크기·좌표·색상·문구로 재현한 예시 화면입니다. 캐릭터 이름과 채팅 내용은 예시입니다.",
        "sNotes": [
            ("현지 언어", "번역 결과를 보여 줄 언어. 상자를 누르면 목록에서 자동(게임 언어) 또는 9개 언어 중 하나를 고릅니다. 애드온 화면 문구도 이 언어로 바뀝니다."),
            ("채팅 번역", "뜻 붙이기, 최소 풀이 비율(0~100%, 10% 단위), 언어 태그, 메시지 전체 마우스오버, 내 메시지 제외, 클릭해서 복사, Shift+클릭 캐릭터 정보."),
            ("번역할 언어", "원문 언어별로 켜고 끕니다. 현지 언어와 같은 언어는 자동으로 꺼지고 회색이 됩니다."),
            ("번역할 채널", "공개 채널, 일반 대화·외치기, 길드·관리자, 파티·공격대·인스턴스, 귓속말을 따로 고릅니다."),
            ("툴팁 번역 · 기타", "아이템·주문 툴팁의 영어 문장 번역, 번역 못 한 문장 모으기, 미니맵 버튼 표시."),
            ("도구 버튼", "미등록 표현, 수집 문장, 상태 복사, 명령어 목록 창을 엽니다. 아래 줄: 후원하기, 아이콘·창 위치 초기화, 닫기."),
        ],
    },
    "en": {
        "head": "Dictionary translator that tags foreign chat and appends a rough meaning · tooltip translation · send in another language",
        "sBadge": "Settings", "sHead": "/ezct · local language, chat translation style, source languages & channels, tooltip translation",
        "tabs": ["General", "Combat Log", "Trade"],
        "chTrade": "2. Trade", "chLFG": "4. LookingForGroup", "chGeneral": "1. General", "chParty": "Party",
        "chGuild": "Guild", "say": "says",
        "notes": [
            ("Inline meaning", "A language tag before foreign chat and the rough meaning in green brackets after it. "
                               "Chat already in your language is left alone."),
            ("Hover glossary", "Hover the tag or the message for the original, rough meaning and known terms. "
                               "Click to open a copy box (Ctrl+C)."),
            ("Minimap button", "Left-click: settings, right-click: unknown expressions, drag: move."),
            ("Send in another language", "/ezct ko text converts your text with the dictionary and puts it into the chat box. "
                                         "Check it and press Enter."),
            ("Tooltip translation", "Untranslated English item and spell text is translated at the bottom of the tooltip "
                                    "(here on a Korean client): item name in gold, sentences in green."),
            ("Character info", "Shift-click a name in chat to run the game's /who lookup; level, race, class, guild and zone "
                               "appear in the name tooltip."),
        ],
        "itemNote": "Example: an untranslated item on a Korean game client",
        "note": "Mock-ups rebuilt from the window sizes, coordinates, colours and strings in the addon code. Character names and chat lines are made up.",
        "sNotes": [
            ("Local language", "The language results are shown in. Click the box and pick Auto (game language) or one of 9 languages from the list. The addon UI follows it."),
            ("Chat translation", "Append meaning, minimum coverage (0–100% in 10% steps), language tag, hover the whole message, skip own messages, click to copy, Shift-click character info."),
            ("Languages to translate", "Per source language. The one equal to your local language is turned off and greyed out."),
            ("Channels to translate", "Public channels, say/yell, guild/officer, party/raid/instance and whispers separately."),
            ("Tooltips · other", "Translate English item/spell tooltip text, collect untranslated sentences, minimap button."),
            ("Tool buttons", "Unknown expressions, collected sentences, copy status, command list. Bottom: Donate, Reset Icon & Window Pos, Close."),
        ],
    },
}

# Chat lines: (channel key, channel colour, name, lang or None, text, meaning, separate line)
CHAT = {
    "ko": [
        ("chTrade", "channel", "Edrin Ashvale", "en", "WTS Arcanite Bar 30g each, CoD ok",
         "팝니다 아케이나이트 주괴 30골드 개당, 착불 우편 좋아", False),
        ("chLFG", "channel", "Corvin Hale", "en", "lfg RFC quest", "파티 구함 성난불길 협곡 퀘스트", False),
        ("chLFG", "channel", "晨星 白岚", "zh", "黑上 来个奶 速度 门口集合", "검은바위 첨탑 상층 힐러 와요 빨리 입구 집합", True),
        ("chTrade", "channel", "Мирон Зорин", "ru", "Продам руну 2з за стак, пишите в лс",
         "팝니다 룬매듭 천을 2골드 한 묶음에, 귓말 주세요", False),
        ("chParty", "party", "カナデ 霧島", "ja", "ストラトホルム タンク 募集", "스트라솔름 탱커 모집", True),
        ("chGuild", "guild", "하늘 윤슬", None, "내일 화심 가실 분?", "", False),
    ],
    "en": [
        ("chTrade", "channel", "Мирон Зорин", "ru", "Продам руну 2з за стак, пишите в лс",
         "WTS runecloth 2g per stack, whisper me", False),
        ("chLFG", "channel", "晨星 白岚", "zh", "黑上 来个奶 速度 门口集合", "UBRS need healer, hurry, meet at entrance", False),
        ("chGeneral", "channel", "Lucía Ferrán", "es", "busco grupo para minas, soy sanadora",
         "LFG Deadmines, I am healer", False),
        ("chParty", "party", "カナデ 霧島", "ja", "ストラトホルム タンク 募集", "Stratholme LF tank", False),
        ("chGuild", "guild", "하늘 윤슬", "ko", "내일 화심 가실 분?", "tomorrow Molten Core anyone?", False),
        ("chTrade", "channel", "Edrin Ashvale", None, "WTS Arcanite Bar 30g each, CoD ok", "", False),
    ],
}
HOVER = {"ko": 3, "en": 0}            # line whose glossary tooltip is shown
TERMS = {
    "ko": [("Продам", "팝니다"), ("руну", "룬매듭 천"), ("2з", "2골드"), ("за стак", "한 묶음에"), ("пишите в лс", "귓말 주세요")],
    "en": [("Продам", "WTS"), ("руну", "runecloth"), ("2з", "2g"), ("за стак", "per stack"), ("пишите в лс", "whisper me")],
}
COVER_KO = "현재 설정: 인식률 100% / 기준 40% · 풀이 표시 조건 충족"   # Korean-only line of presentGloss
OUTGOING = {
    "ko": ("English", "/ezct en 개당 30골드 팝니다 착불 가능", "WTS 30g each, CoD ok"),
    "en": ("한국어", "/ezct ko WTS Arcanite Bar 30g each", "팝니다 아케이나이트 주괴 개당 30골드"),
}
PLAYER = {   # PlayerTooltip.lua: title, name, <guild>, level race class, zone
    "ko": ("Edrin Ashvale", "은빛 등불", "인간 전사", 32, "아라시 고원"),
    "en": ("Edrin Ashvale", "Silver Lantern", "Human Warrior", 32, "Arathi Highlands"),
}
# Data/TooltipText.lua entries (ko) for an untranslated item
ITEM = {
    "name": "Fishing Rack",
    "lines": [("Use: Places a fishing rack that grants the ability to catch uncommon fish for 1 hr, provides fishing "
               "skill lures, and provides all of the benefits of a fish bowl.", "#1eff00"),
              ("Requires a campfire nearby", "#ffffff")],
    "trName": "낚시 선반",
    "tr": ["사용 효과: 낚시 선반을 설치합니다. 1시간 동안 고급 물고기를 낚을 수 있고, 낚시 숙련도를 올려 주는 미끼를 "
           "제공하며, 물고기 그릇의 모든 효과를 받습니다.", "근처에 모닥불이 필요합니다."],
}


def px(v):
    return f"{v * SCALE:.1f}px"


def at(x, y, w=None, h=None):
    s = f"left:{px(x)};top:{px(y)};"
    if w is not None:
        s += f"width:{px(w)};"
    if h is not None:
        s += f"height:{px(h)};"
    return s


def esc(s):
    return html.escape(s, quote=False)


def fit(inner, base, minimum, max_w=None, style=""):
    """UIKit:FitFontString: shrinks from base to minimum font size (game px), then cuts with an ellipsis."""
    mw = f"max-width:{px(max_w)};" if max_w else ""
    return (f'<span class="fit" data-min="{minimum * SCALE:.2f}" data-step="{0.5 * SCALE:.2f}" '
            f'style="font-size:{px(base)};{mw}{style}">{inner}</span>')


def button(x, y, w, h, label, size=12, accent=False, align="center"):
    """SettingsDialog.createTranslatorButton."""
    if accent:
        bg, bd, fg = C["bgAccent"], C["accent"], C["accent"]
    else:
        bg, bd, fg = C["bgSecondary"], C["border"], C["textBody"]
    return (f'<div class="btn" style="{at(x, y, w, h)}background:{bg};border-color:{bd};color:{fg};justify-content:{align}">'
            f'{fit(esc(label), size, 8, w - 8)}</div>')


CSS = Template("""
* { box-sizing: border-box; margin: 0; padding: 0; }
html { background: #0b1014; }
body { width: ${PAGE_W}px; background: radial-gradient(ellipse at 30% 0%, #1b2b2c 0%, #10171d 60%, #0b1014 100%);
  font-family: 'Noto Sans KR', 'Malgun Gothic', 'Microsoft YaHei', 'Yu Gothic', sans-serif; color: ${textBody};
  overflow: hidden; min-height: 100vh; }
.page { position: relative; padding: 34px 50px 0; }
h1 { color: ${accent}; font-size: 40px; font-weight: 700; letter-spacing: .3px; display: flex; align-items: center; gap: 14px; }
h1 .badge { font-size: 15px; background: ${accent}; color: #0d2219; padding: 2px 9px; border-radius: 5px; }
.lead { color: #d5dde2; font-size: 19px; margin-top: 6px; }
.abs { position: absolute; }
.rel { position: relative; }
.win { position: absolute; background: ${bgPrimary}; border: 1px solid ${border}; }
.lbl { position: absolute; white-space: nowrap; line-height: 1.2; }
.btn { position: absolute; border: 1px solid; display: flex; align-items: center; overflow: hidden; }
.fit { display: inline-block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; vertical-align: middle; line-height: 1.25; }
.check { position: absolute; width: ${chk}; height: ${chk}; border: 1px solid #6d6a5d; background: #191919; border-radius: 2px; }
.check::after { content: '\\2714'; position: absolute; left: ${chkL}; top: ${chkT}; font-size: ${chkF}; color: #ffd200; text-shadow: 0 0 1px #000; line-height: 1; }
.check.off::after { content: ''; }
.check.dis { border-color: #4a4a44; background: #222; }
.call { position: absolute; width: 30px; height: 30px; border-radius: 50%; background: ${CALL}; color: #0d2219; font-weight: 700;
  font-size: 16px; display: flex; align-items: center; justify-content: center; border: 2px solid #0d2219; box-shadow: 0 0 0 2px ${CALL}55; z-index: 5; }
.note { display: flex; gap: 12px; margin-bottom: 11px; font-size: 16.5px; line-height: 1.5; color: #dfe6ea; }
.note .n { flex: none; width: 28px; height: 28px; border-radius: 50%; background: ${CALL}; color: #0d2219; font-weight: 700;
  font-size: 15px; display: flex; align-items: center; justify-content: center; margin-top: 1px; }
.note b { color: #fff; }
.foot { color: #7d8d98; font-size: 13.5px; margin-top: 18px; }
.tip { background: rgba(4,8,14,.95); border: 2px solid #5d6d7a; border-radius: 4px; padding: 10px 12px;
  font-size: 15px; line-height: 1.5; }
.tip .dl { display: flex; justify-content: space-between; gap: 22px; }
.tip .tag { text-align: right; font-size: 11px; color: #808080; }
.chat { background: rgba(0,0,0,.55); padding: 12px 16px 14px; font-size: 18px; line-height: 1.55;
  text-shadow: 1px 1px 0 #000; min-height: 330px; }
.chat div { padding-left: 1.3em; text-indent: -1.3em; }
.tabs { display: flex; gap: 6px; }
.tabs span { background: rgba(0,0,0,.55); color: #ffd200; padding: 3px 26px 2px; font-size: 15px; border-radius: 5px 5px 0 0; }
.tabs span + span { color: #c8c8c8; background: rgba(0,0,0,.35); }
.editbox { margin-top: 12px; border: 2px solid #5d6d7a; background: rgba(0,0,0,.7); padding: 6px 12px; font-size: 18px;
  text-shadow: 1px 1px 0 #000; }
.mm { position: relative; width: 190px; height: 190px; border-radius: 50%; border: 9px solid #6e5a2c;
  background: radial-gradient(circle at 40% 35%, #3f6e3a, #20381e 70%); box-shadow: 0 0 0 2px #2a2214; }
.mmbtn { position: absolute; width: 44px; height: 44px; border-radius: 50%; border: 5px solid #c9a34a; background: #10171d;
  display: flex; align-items: center; justify-content: center; box-shadow: 0 0 0 1px #000; }
.mmbtn img { width: 28px; height: 28px; }
""").substitute(PAGE_W=PAGE_W, CALL=CALL, chk=px(18), chkL=px(1), chkT=px(-2), chkF=px(17), **C)

# FitFontString in the browser, then the page height for the screenshot
JS = """
document.querySelectorAll('.fit').forEach(function (el) {
  var s = parseFloat(el.style.fontSize), m = parseFloat(el.dataset.min), st = parseFloat(el.dataset.step);
  while (el.scrollWidth > el.clientWidth + 0.5 && s - st >= m - 0.01) { s -= st; el.style.fontSize = s + 'px'; }
});
var b = 0;
document.querySelectorAll('body *').forEach(function (el) { b = Math.max(b, el.getBoundingClientRect().bottom); });
document.body.setAttribute('data-h', String(Math.ceil(b + 34)));
"""


def notes_html(items, start=1):
    return "".join(f'<div class="note"><span class="n">{start + i}</span><div><b>{esc(a)}</b> — {esc(b)}</div></div>'
                   for i, (a, b) in enumerate(items))


def call(n, left, top):
    return f'<div class="call" style="left:{left}px;top:{top}px">{n}</div>'


# ---------------------------------------------------------------------------
# Chat page: chat frame, glossary tooltip, outgoing text, item tooltip, name tooltip, minimap button
# ---------------------------------------------------------------------------
def chat_line(lang, entry):
    s, t = L[lang], T[lang]
    chan, kind, name, src, text, meaning, separate = entry
    col = CH[kind]
    prefix = f'[{esc(t[chan])}] [{esc(name)}]: '
    body = f'<span style="color:{col}">{prefix}</span>'
    if src:
        body += f'<span style="color:{TAG_COLOR[src]}">[{esc(s["tag"][src])}]</span> '
    body += f'<span style="color:{col}">{esc(text)}</span>'
    out = f'<div>{body}'
    if meaning and not separate:
        out += f' <span style="color:{GLOSS}">({esc(meaning)})</span>'
    out += '</div>'
    if meaning and separate:
        out += f'<div style="color:{GLOSS}">&nbsp;&nbsp;&nbsp;&nbsp;↳ {esc(meaning)}</div>'
    return out


def gloss_tip(lang):
    s = L[lang]
    entry = CHAT[lang][HOVER[lang]]
    rows = "".join(f'<div class="dl"><span style="color:#e6e6e6">{esc(a)}</span><span style="color:#99ff99">{esc(b)}</span></div>'
                   for a, b in TERMS[lang])
    extra = f'<div style="color:{C["textMuted"]}">{esc(COVER_KO)}</div>' if lang == "ko" else ""
    return (f'<div class="tip">'
            f'<div style="color:{C["accent"]}">{esc(s["glossTitle"] % s["langName"][entry[3]])}</div>'
            f'<div style="color:{C["textBody"]}">{esc(entry[4])}</div><div>&nbsp;</div>'
            f'<div style="color:#ffd100">{esc(s["rough"])}</div><div style="color:#fff">{esc(entry[5])}</div><div>&nbsp;</div>'
            f'<div style="color:#ffd100">{esc(s["terms"])}</div>{rows}<div>&nbsp;</div>'
            f'<div style="color:{C["textMuted"]}">{esc(s["clickHint"])}</div>{extra}'
            f'<div class="tag">EzWoW - Chat Translator</div></div>')


def item_tip(lang):
    lines = "".join(f'<div style="color:{c}">{esc(x)}</div>' for x, c in ITEM["lines"])
    tr = "".join(f'<div style="color:#99ff99">{esc(x)}</div>' for x in ITEM["tr"])
    return (f'<div class="tip"><div style="color:#fff;font-size:17px">{esc(ITEM["name"])}</div>{lines}<div>&nbsp;</div>'
            f'<div style="color:#ffd100">{esc(ITEM["trName"])} <span style="color:#999">({esc(ITEM["name"])})</span></div>'
            f'{tr}<div class="tag">EzWoW - Chat Translator</div></div>'
            f'<div style="color:#7d8d98;font-size:13.5px;margin-top:6px">{esc(T[lang]["itemNote"])}</div>')


def player_tip(lang):
    s = L[lang]
    name, guild, rc, level, zone = PLAYER[lang]
    return (f'<div class="tip"><div style="color:{C["accent"]}">EzWoW - Chat Translator</div>'
            f'<div style="color:#fff">{esc(name)}</div><div style="color:#4dff4d">&lt;{esc(guild)}&gt;</div>'
            f'<div style="color:#ffd100">{esc(s["level"] % level)} {esc(rc)}</div>'
            f'<div style="color:#b3b3b3">{esc(zone)}</div></div>')


def minimap(lang, icon_uri):
    s = L[lang]
    tip = "".join(f'<div style="color:{C["textBody"] if i == 0 else C["textMuted"]}">{esc(x)}</div>'
                  for i, x in enumerate(s["minimapTip"]))
    return (f'<div class="rel" style="width:300px;height:380px">'
            f'<div class="mm" style="position:absolute;left:96px;top:0"></div>'
            f'<div class="mmbtn" style="left:78px;top:150px"><img src="{icon_uri}"></div>'
            f'<div class="tip" style="position:absolute;left:0;top:214px;width:300px">'
            f'<div style="color:{C["accent"]}">EzWoW - Chat Translator</div>{tip}</div>'
            f'{call(3, 40, 156)}</div>')


def ui_page(lang, icon_uri):
    s, t = L[lang], T[lang]
    lines = "".join(chat_line(lang, e) for e in CHAT[lang])
    target, cmd, result = OUTGOING[lang]
    sysline = (f'<div style="color:{CH["system"]}"><span style="color:{C["accent"]}">[EzWoW - Chat Translator]</span> '
               f'{esc(s["outDone"] % (target, 100))}</div>')
    tabs = "".join(f'<span>{esc(x)}</span>' for x in t["tabs"])
    trade = t["chTrade"]
    chat = (f'<div class="rel" style="width:900px;flex:none">'
            f'<div class="tabs">{tabs}</div>'
            f'<div class="chat">{lines}{sysline}</div>'
            f'<div class="editbox"><span style="color:{CH["channel"]}">[{esc(trade)}]: {esc(result)}</span>'
            f'<span style="color:#9aa">&nbsp;&nbsp;←&nbsp;&nbsp;{esc(cmd)}</span></div>'
            f'{call(1, -42, 44)}{call(4, -42, 0)}</div>')
    # the 4th callout sits on the edit box: position it after layout via bottom offset
    chat = chat.replace(call(4, -42, 0), f'<div class="call" style="left:-42px;bottom:8px">4</div>')
    gloss = (f'<div class="rel" style="flex:1;margin-top:70px">{gloss_tip(lang)}'
             f'{call(2, -16, -16)}</div>')
    row1 = f'<div style="display:flex;gap:36px;padding:26px 50px 0 92px;align-items:flex-start">{chat}{gloss}</div>'
    row2 = (f'<div style="display:flex;gap:34px;padding:34px 50px 0 92px;align-items:flex-start">'
            f'<div class="rel" style="width:560px;flex:none">{item_tip(lang)}{call(5, -42, 8)}</div>'
            f'<div class="rel" style="width:330px;flex:none">{player_tip(lang)}{call(6, -16, -16)}</div>'
            f'{minimap(lang, icon_uri)}</div>')
    notes = (f'<div style="padding:30px 50px 0">'
             f'<div style="display:flex;gap:50px"><div style="flex:1">{notes_html(t["notes"][:3])}</div>'
             f'<div style="flex:1">{notes_html(t["notes"][3:], 4)}</div></div>'
             f'<div class="foot">{esc(t["note"])}</div></div>')
    head = f'<div class="page"><h1>EzWoW - Chat Translator</h1><div class="lead">{esc(t["head"])}</div></div>'
    return head + row1 + row2 + notes


# ---------------------------------------------------------------------------
# Settings window (UI/OptionsWindow.lua): 840 wide, LEFT 22 / RIGHT 432, column 390, ROW 24
# ---------------------------------------------------------------------------
def settings_page(lang, icon_uri):
    s, t = L[lang], T[lang]
    W = 840
    LEFT, RIGHT, COL_W, HALF, ROW = 22, 432, 390, 195, 24
    LW, HW = COL_W - 40, HALF - 36
    p = []

    # header bar 56 high, accent line, icon, title, subtitle (L.secChat), close
    p.append(f'<div class="abs" style="{at(1, 1, W - 2, 56)}background:rgba(29,40,49,.96)"></div>')
    p.append(f'<div class="abs" style="{at(1, 55, W - 2, 2)}background:{C["accent"]}"></div>')
    p.append(f'<img class="abs" src="{icon_uri}" style="{at(15, 15, 28, 28)}">')
    p.append(f'<div class="lbl" style="{at(49, 10)}font-size:{px(16)};color:{C["accent"]}">EzWoW - Chat Translator</div>')
    p.append(f'<div class="lbl" style="{at(49, 31)}font-size:{px(10)};color:{C["textMuted"]}">{esc(s["secChat"])}</div>')
    p.append(button(W - 1 - 10 - 24, 11, 24, 24, "X"))

    def section(key, x, y):
        p.append(f'<div class="lbl" style="{at(x, y, COL_W)}color:{C["accent"]}">{fit(esc(s[key]), 12, 9, COL_W)}</div>')
        p.append(f'<div class="abs" style="{at(x, y + 18, COL_W, 1)}background:rgba(52,76,91,.85)"></div>')

    def check(label, x, y, on=True, maxw=LW, disabled=False):
        cls = "check" + ("" if on else " off") + (" dis" if disabled else "")
        p.append(f'<div class="{cls}" style="{at(x + 4, y + 4)}"></div>')
        col = C["textMuted"] if disabled else C["textBody"]
        p.append(f'<div class="lbl" style="{at(x + 28, y, None, 26)}display:flex;align-items:center;color:{col}">'
                 f'{fit(esc(label), 12, 8, maxw)}</div>')

    def note(key, x, y):
        p.append(f'<div class="abs" style="{at(x, y, COL_W - 20)}font-size:{px(10)};line-height:1.25;color:{C["textMuted"]}">'
                 f'{esc(s[key])}</div>')

    # column divider (RIGHT - 16, -70), height = -bottom - 70
    # left column
    y = 72
    section("secTarget", LEFT, y); y += 26
    p.append(button(LEFT, y, LW, 26, (s["auto"] % s["client"]) + " ▼"))
    y += 34
    note("targetNote", LEFT + 4, y); y += 40
    section("secChat", LEFT, y); y += 26
    check(s["optEnabled"], LEFT, y); y += ROW
    check(s["optInline"], LEFT, y); y += ROW + 2
    p.append(button(LEFT + 28, y, 26, 22, "-"))
    p.append(button(LEFT + 58, y, 26, 22, "+"))
    p.append(f'<div class="lbl" style="{at(LEFT + 92, y, None, 22)}display:flex;align-items:center;color:{C["textBody"]}">'
             f'{fit(esc(s["optCover"] % 40), 12, 8, COL_W - 100)}</div>')
    y += ROW + 4
    for key in ("optTag", "optHover", "optSelf", "optCopyAll"):
        check(s[key], LEFT, y); y += ROW
    check(s["optPlayerTip"], LEFT, y); y += ROW + 4
    note("chatNote", LEFT + 4, y); y += 30
    left_bottom = y

    # right column
    y = 72
    section("secLangs", RIGHT, y); y += 26
    same = "ko" if lang == "ko" else "en"
    for i, code in enumerate(("ko", "zh", "ja", "ru", "en", "es")):
        dis = code == same
        check(s["langName"][code], RIGHT + (i % 2) * HALF, y + (i // 2) * ROW, on=not dis, maxw=HW, disabled=dis)
    y += 3 * ROW + 8
    section("secChannels", RIGHT, y); y += 26
    for key in ("chPublic", "chSay", "chGuild", "chGroup", "chWhisper"):
        check(s[key], RIGHT, y); y += ROW
    y += 8
    section("secTooltip", RIGHT, y); y += 26
    check(s["optTooltip"], RIGHT, y); y += ROW
    check(s["optCollect"], RIGHT, y); y += ROW + 4
    note("tooltipNote", RIGHT + 4, y); y += 40
    section("secMisc", RIGHT, y); y += 26
    check(s["optMinimap"], RIGHT, y); y += ROW + 6
    bottom = max(left_bottom, y)
    p.append(f'<div class="abs" style="{at(RIGHT - 16, 70, 1, bottom - 70)}background:rgba(52,76,91,.65)"></div>')

    bottom += 10
    for i, key in enumerate(("btnUnknown", "btnCollected", "btnStatus", "btnHelp")):
        p.append(button(LEFT + i * 148, bottom, 140, 26, s[key]))
    tools_y = bottom
    bottom += 28
    H = bottom + 66
    p.append(button(22, H - 24 - 26, 160, 26, s["donate"], accent=True))
    p.append(button(192, H - 24 - 26, 160, 26, s["resetIconPos"]))
    p.append(button(W - 22 - 120, H - 24 - 26, 120, 26, s["close"]))
    p.append(f'<div class="lbl" style="right:{px(22)};bottom:{px(6)};font-size:{px(10)};color:{C["textMuted"]}">'
             f'EzWoW - Chat Translator · /ezct</div>')

    ox, oy = 230, 160
    win = f'<div class="win" style="left:{ox}px;top:{oy}px;width:{px(W)};height:{px(H)}">' + "".join(p) + '</div>'

    def cy(v): return oy + v * SCALE - 15
    lx, rx = ox - 46, ox + W * SCALE + 16
    calls = (call(1, lx, cy(100)) + call(2, lx, cy(280)) + call(3, rx, cy(120)) + call(4, rx, cy(250))
             + call(5, rx, cy(370)) + call(6, lx, cy(tools_y + 13)))
    notes_top = oy + H * SCALE + 36
    notes = (f'<div class="abs" style="left:50px;top:{notes_top:.0f}px;width:{PAGE_W - 100}px">'
             f'<div style="display:flex;gap:50px"><div style="flex:1">{notes_html(t["sNotes"][:3])}</div>'
             f'<div style="flex:1">{notes_html(t["sNotes"][3:], 4)}</div></div>'
             f'<div class="foot">{esc(t["note"])}</div></div>')
    head = (f'<div class="page"><h1>EzWoW - Chat Translator <span class="badge">{esc(t["sBadge"])}</span></h1>'
            f'<div class="lead">{esc(t["sHead"])}</div></div>')
    return head + win + calls + notes


# ---------------------------------------------------------------------------
# Rendering (headless Chrome: one pass to measure the height, one to capture)
# ---------------------------------------------------------------------------
def chrome_path():
    env = os.environ.get("CHROME")
    if env:
        return env
    for cand in (r"C:\Program Files\Google\Chrome\Application\chrome.exe",
                 r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
                 "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                 shutil.which("google-chrome") or "", shutil.which("chromium") or ""):
        if cand and Path(cand).exists():
            return cand
    sys.exit("Chrome not found; set CHROME to its path")


def stop(proc):
    """Ends Chrome with all its child processes."""
    if proc.poll() is None:
        if os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
        else:
            proc.kill()
    proc.wait()


def render(chrome, profile, html_file, png, height=None):
    # a fresh profile per call: a Chrome left running must not lock the next one
    profile = Path(tempfile.mkdtemp(prefix="profile_", dir=profile))
    args = [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars", f"--user-data-dir={profile}",
            "--force-device-scale-factor=1", "--no-first-run", "--no-default-browser-check"]
    if height is None:
        dom = profile / "dom.html"
        with open(dom, "wb") as fh:
            proc = subprocess.Popen(args + ["--window-size=1600,2000", "--dump-dom", html_file.as_uri()],
                                    stdout=fh, stderr=subprocess.DEVNULL)
            deadline = time.time() + 120
            m = None
            while time.time() < deadline:
                done = proc.poll() is not None
                m = re.search(rb'data-h="(\d+)"', dom.read_bytes())
                if m or done:
                    break
                time.sleep(0.5)
            stop(proc)
        if not m:
            sys.exit("could not measure " + str(html_file))
        return int(m.group(1))
    # Chrome sometimes keeps running after writing the screenshot: wait for the file, then stop it.
    png = Path(png)
    if png.exists():
        png.unlink()
    proc = subprocess.Popen(args + [f"--window-size={PAGE_W},{height}", f"--screenshot={png}", html_file.as_uri()],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline, last = time.time() + 120, -1
    while time.time() < deadline:
        if proc.poll() is not None and png.exists():
            break
        if png.exists():
            size = png.stat().st_size
            if size > 0 and size == last:
                break
            last = size
        time.sleep(0.5)
    stop(proc)
    if not png.exists():
        sys.exit("could not capture " + str(html_file))
    return height


def main(root: Path):
    root = root.resolve()
    out = root / "docs" / "images"
    out.mkdir(parents=True, exist_ok=True)
    icon_uri = "data:image/png;base64," + base64.b64encode((root / "Media" / "icon.png").read_bytes()).decode()
    chrome = chrome_path()
    work = Path(tempfile.mkdtemp(prefix="ezct_readme_"))
    profile = work
    try:
        for lang in ("ko", "en"):
            for name, fn in (("ui", ui_page), ("settings", settings_page)):
                body = fn(lang, icon_uri)
                page = (f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>{CSS}</style></head>'
                        f'<body>{body}<script>{JS}</script></body></html>')
                html_file = work / f"{name}_{lang}.html"
                html_file.write_text(page, encoding="utf-8")
                png = out / f"{name}_{lang}.png"
                h = render(chrome, profile, html_file, png)
                render(chrome, profile, html_file, png, h)
                print("wrote", png, h)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main(Path(sys.argv[1] if len(sys.argv) > 1 else "."))
