--===========================================================================
-- EzWoW - Chat Translator
-- Core/LocaleExtra.lua : Extended Multilingual UI & Notification Strings
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local LocaleExtended = ns.LocaleExtended or {}
ns.LocaleExtended = LocaleExtended
ns.TARGETS = {"ko", "en", "de", "fr", "es", "ru", "zhCN", "zhTW", "ja"}
ns.TARGET_NAME.de, ns.TARGET_NAME.fr, ns.TARGET_NAME.ja, ns.TARGET_NAME.es = "Deutsch", "Français", "日本語", "Español"
ns.SAME_SOURCE.de, ns.SAME_SOURCE.fr, ns.SAME_SOURCE.ja, ns.SAME_SOURCE.es = "de", "fr", "ja", "es"
ns.DEFAULTS.chat.langs.es = true
local locale = GetLocale()
if locale == "deDE" then ns.CLIENT_TARGET = "de"
elseif locale == "frFR" then ns.CLIENT_TARGET = "fr"
elseif locale == "esES" or locale == "esMX" then ns.CLIENT_TARGET = "es"
elseif locale == "jaJP" then ns.CLIENT_TARGET = "ja" end
ns.STR.de = {
 tipUse="Benutzen:", tipEquip="Anlegen:", tipProc="Trefferchance:", title="EzWoW - Chat Translator",
 secTooltip="Tooltip-Übersetzung", optTooltip="Englische Objekt- und Zauberbeschreibungen übersetzen",
 optCollect="Nicht übersetzte Sätze sammeln (/ezct collect)",
 tooltipNote="Nicht übersetzte Beschreibungen werden unten im Tooltip im Abschnitt EzWoW - Chat Translator angezeigt.",
 collectCount="Gesammelte nicht übersetzte Sätze: %d", collectCleared="Gesammelte Sätze gelöscht.",
 collectHow="Wird beim Ausloggen in WTF\\Account\\(account)\\SavedVariables\\EzWoW-ChatTranslator.lua gespeichert. (/ezct collect clear)",
 glossTitle="%s → Deutsch", rough="Ungefähre Bedeutung", terms="Bekannte Begriffe", noTerms="Keine bekannten Begriffe im Wörterbuch gefunden.",
 clickHint="Klick: Kopierfenster öffnen", copyTitle="Strg+C drücken und in einen Übersetzer einfügen",
 copyDonate="Strg+C drücken und im Browser einfügen", close="Schließen", donate="Spenden",
 secTarget="Zielsprache", auto="Automatisch - Spielsprache (%s)",
 targetNote="Andere Sprachen werden in diese Sprache übersetzt. Auch die Oberfläche wechselt die Sprache.",
 secChat="Chat-Übersetzung", optEnabled="Chat-Übersetzung aktivieren", optInline="Ungefähre Bedeutung nach der Nachricht anfügen",
 optCover="Mindestabdeckung des Wörterbuchs: %d%%", optTag="Sprach-Tag vor Nachrichten anzeigen",
 optHover="Bedeutung beim Überfahren der gesamten Nachricht anzeigen", optSelf="Eigene Nachrichten überspringen",
 langs="Zu übersetzende Sprachen (Zielsprache wird übersprungen)", chatNote="Änderungen gelten sofort für neue Nachrichten. Status: /ezct status",
 langName={ko="Koreanisch",en="Englisch",zh="Chinesisch",ja="Japanisch",ru="Russisch",es="Spanisch",de="Deutsch",fr="Französisch"},
 tag={ko="KO",en="EN",zh="ZH",ja="JA",ru="RU",es="ES",de="DE",fr="FR"},
}
ns.STR.fr = {
 tipUse="Utiliser :", tipEquip="Équiper :", tipProc="Chance à l'impact :", title="EzWoW - Chat Translator",
 secTooltip="Traduction des infobulles", optTooltip="Traduire les descriptions en anglais des objets et sorts",
 optCollect="Collecter les phrases non traduites (/ezct collect)",
 tooltipNote="Les descriptions non traduites sont affichées au bas de l'infobulle dans la section EzWoW - Chat Translator.",
 collectCount="Phrases non traduites collectées : %d", collectCleared="Phrases collectées effacées.",
 collectHow="Enregistrées à la déconnexion dans WTF\\Account\\(account)\\SavedVariables\\EzWoW-ChatTranslator.lua. (/ezct collect clear)",
 glossTitle="%s → Français", rough="Sens approximatif", terms="Termes reconnus", noTerms="Aucun terme connu trouvé dans le dictionnaire.",
 clickHint="Clic : ouvrir la fenêtre de copie", copyTitle="Appuyez sur Ctrl+C et collez dans un traducteur",
 copyDonate="Appuyez sur Ctrl+C et collez dans votre navigateur", close="Fermer", donate="Faire un don",
 secTarget="Langue cible", auto="Auto - langue du jeu (%s)",
 targetNote="Les autres langues sont traduites dans cette langue. L'interface change également de langue.",
 secChat="Traduction du chat", optEnabled="Activer la traduction du chat", optInline="Ajouter le sens approximatif après le message",
 optCover="Couverture minimale du dictionnaire : %d%%", optTag="Afficher une balise de langue avant le message",
 optHover="Afficher le sens au survol du message", optSelf="Ignorer mes propres messages",
 langs="Langues à traduire (la langue cible est ignorée)", chatNote="Les modifications s'appliquent immédiatement aux nouveaux messages. Statut : /ezct status",
 langName={ko="Coréen",en="Anglais",zh="Chinois",ja="Japonais",ru="Russe",es="Espagnol",de="Allemand",fr="Français"},
 tag={ko="KO",en="EN",zh="ZH",ja="JA",ru="RU",es="ES",de="DE",fr="FR"},
}
ns.STR.ja = {
 tipUse="使用:", tipEquip="装備:", tipProc="命中時:", title="EzWoW - Chat Translator",
 secTooltip="ツールチップ翻訳", optTooltip="アイテム・呪文の英語説明を翻訳",
 optCollect="未翻訳の文を収集 (/ezct collect)",
 tooltipNote="未翻訳の説明をツールチップ下部の EzWoW - Chat Translator 欄に表示します。",
 collectCount="収集した未翻訳の文: %d", collectCleared="収集した文を削除しました。",
 collectHow="ログアウト後、WTF\\Account\\(account)\\SavedVariables\\EzWoW-ChatTranslator.lua に保存されます。作者に送信すると辞書を補強できます。(/ezct collect clear)",
 glossTitle="%s → 日本語", rough="おおよその意味", terms="登録された表現", noTerms="辞書に登録された表現がありません。",
 clickHint="クリック: コピー画面を開く", copyTitle="Ctrl+C でコピーして翻訳サービスに貼り付けてください",
 copyDonate="Ctrl+C でコピーしてブラウザーに貼り付けてください", close="閉じる", donate="寄付",
 secTarget="翻訳先の言語", auto="自動 - ゲーム言語 (%s)",
 targetNote="他の言語のチャットを選択した言語に翻訳します。画面の言語も切り替わります。",
 secChat="チャット翻訳", optEnabled="チャット翻訳を有効にする", optInline="メッセージの後に意味を表示",
 optCover="意味を表示する最低辞書一致率: %d%%", optTag="メッセージの前に言語タグを表示",
 optHover="メッセージにマウスを重ねて意味を表示", optSelf="自分のメッセージを除外",
 langs="翻訳する言語（翻訳先と同じ言語は除外）", chatNote="設定は新しいメッセージに適用されます。状態: /ezct status",
 langName={ko="韓国語",en="英語",zh="中国語",ja="日本語",ru="ロシア語",es="スペイン語",de="ドイツ語",fr="フランス語"},
 tag={ko="KO",en="EN",zh="ZH",ja="JA",ru="RU",es="ES",de="DE",fr="FR"},
}
ns.STR.es = {
 tipUse="Uso:", tipEquip="Equipar:", tipProc="Probabilidad al golpear:", title="EzWoW - Chat Translator",
 secTooltip="Traducción de descripciones", optTooltip="Traducir las descripciones en inglés de objetos y hechizos",
 optCollect="Recopilar frases sin traducir (/ezct collect)",
 tooltipNote="Las descripciones sin traducir se muestran al final en la sección EzWoW - Chat Translator.",
 collectCount="Frases sin traducir recopiladas: %d", collectCleared="Se borraron las frases recopiladas.",
 collectHow="Se guardan al salir en WTF\\Account\\(account)\\SavedVariables\\EzWoW-ChatTranslator.lua. Envía el archivo al autor para ampliar el diccionario. (/ezct collect clear)",
 glossTitle="%s → Español", rough="Significado aproximado", terms="Expresiones conocidas", noTerms="No hay expresiones conocidas en el diccionario.",
 clickHint="Clic: abrir la ventana de copia", copyTitle="Pulsa Ctrl+C y pega el texto en un traductor",
 copyDonate="Pulsa Ctrl+C y pega el texto en tu navegador", close="Cerrar", donate="Donar",
 secTarget="Idioma de destino", auto="Automático - idioma del juego (%s)",
 targetNote="Los otros idiomas se traducen al seleccionado. La interfaz también cambia de idioma.",
 secChat="Traducción del chat", optEnabled="Activar traducción del chat", optInline="Añadir el significado al mensaje",
 optCover="Cobertura mínima del diccionario: %d%%", optTag="Mostrar una etiqueta de idioma antes del mensaje",
 optHover="Mostrar el significado al pasar el ratón", optSelf="Excluir mis mensajes",
 langs="Idiomas que traducir (se excluye el idioma de destino)", chatNote="Los cambios se aplican a los mensajes nuevos. Estado: /ezct status",
 langName={ko="Coreano",en="Inglés",zh="Chino",ja="Japonés",ru="Ruso",es="Español",de="Alemán",fr="Francés"},
 tag={ko="KO",en="EN",zh="ZH",ja="JA",ru="RU",es="ES",de="DE",fr="FR"},
}
local extraLangNames={
 ko={es="스페인어",de="독일어",fr="프랑스어"},
 en={es="Spanish",de="German",fr="French"},
 zhCN={es="西班牙语",de="德语",fr="法语"},
 zhTW={es="西班牙語",de="德語",fr="法語"},
 ru={es="испанский",de="немецкий",fr="французский"},
}
for langCode,map in pairs(extraLangNames) do
 for entryKey,formatLocalizedLabel in pairs(map) do
  ns.STR[langCode].langName[entryKey]=formatLocalizedLabel
  ns.STR[langCode].tag[entryKey]=entryKey:upper()
 end
end
ns.PlayerLookupText = {
 ko={level="레벨 %s",loading="불러오는 중… (최대 %d초)",busy="%s 조회 중… (최대 %d초)\n완료 후 Shift+클릭으로 조회하세요.",wait="다음 조회까지 %d초 · 이후 Shift+클릭으로 조회",failed="조회 응답이 없습니다. Shift+클릭으로 다시 조회하세요.",hint="Shift+클릭으로 캐릭터 정보를 조회하세요."},
 en={level="Level %s",loading="Loading… (up to %ds)",busy="Looking up %s (up to %ds).\nShift-click after completion.",wait="Next lookup in %ds; Shift-click after the wait",failed="No response. Shift-click to retry.",hint="Shift-click to look up character details."},
 de={level="Stufe %s",loading="Lädt… (bis zu %ds)",busy="Suche %s (bis zu %ds).\nNach Abschluss Umschalt-Klick.",wait="Nächste Abfrage in %ds; danach Umschalt-Klick",failed="Keine Antwort. Umschalt-Klick für erneuten Versuch.",hint="Umschalt-Klick, um Charakterdetails abzufragen."},
 fr={level="Niveau %s",loading="Chargement… (jusqu'à %ds)",busy="Recherche de %s (jusqu'à %ds).\nMaj-clic une fois terminé.",wait="Prochaine recherche dans %ds ; Maj-clic ensuite",failed="Aucune réponse. Maj-clic pour réessayer.",hint="Maj-clic pour consulter les infos du personnage."},
 zhCN={level="等级 %s",loading="读取中…（最多%d秒）",busy="正在查询%s（最多%d秒）\n完成后按Shift点击查询。",wait="下次查询还需%d秒；之后按Shift点击",failed="查询无响应。按Shift点击重试。",hint="按Shift点击查询角色信息。"},
 zhTW={level="等級 %s",loading="讀取中…（最多%d秒）",busy="正在查詢%s（最多%d秒）\n完成後按Shift點擊查詢。",wait="下次查詢還需%d秒；之後按Shift點擊",failed="查詢無回應。按Shift點擊重試。",hint="按Shift點擊查詢角色資訊。"},
 ja={level="レベル %s",loading="読み込み中…（最大%d秒）",busy="%sを検索中（最大%d秒）\n完了後にShift+クリックしてください。",wait="次の検索まで%d秒・その後Shift+クリック",failed="応答がありません。Shift+クリックで再試行。",hint="Shift+クリックでキャラクター情報を検索します。"},
 ru={level="Уровень %s",loading="Загрузка… (до %d с)",busy="Поиск %s (до %d с)\nПосле завершения нажмите Shift+щелчок.",wait="До следующего поиска %d с; затем Shift+щелчок",failed="Нет ответа. Shift+щелчок для повтора.",hint="Shift+щелчок для поиска персонажа."},
 es={level="Nivel %s",loading="Cargando… (hasta %d s)",busy="Buscando a %s (hasta %d s)\nPulsa Mayús+clic cuando termine.",wait="Próxima consulta en %d s; después Mayús+clic",failed="Sin respuesta. Mayús+clic para reintentar.",hint="Mayús+clic para consultar el personaje."},
}
ns.SynchronizeTargetLanguage()
