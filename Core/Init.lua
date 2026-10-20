--===========================================================================
-- EzWoW - Chat Translator
-- Core/Init.lua : SavedVariables Bootstrap & Login Lifecycle Dispatcher
--===========================================================================
local ADDON_NAME, ns = ...
local type, pairs, pcall, tostring = type, pairs, pcall, tostring

local CoreBootstrap = ns.CoreBootstrap or {}
ns.CoreBootstrap = CoreBootstrap

function CoreBootstrap.MergeDefaults(targetTbl, defaultTbl)
    for k, v in pairs(defaultTbl) do
        if type(v) == "table" then
            if type(targetTbl[k]) ~= "table" then
                targetTbl[k] = {}
            end
            CoreBootstrap.MergeDefaults(targetTbl[k], v)
        elseif targetTbl[k] == nil then
            targetTbl[k] = v
        end
    end
    return targetTbl
end

local bootFrame = CreateFrame("Frame")
ns.UIKit:BindEvents(bootFrame, {
    ADDON_LOADED = function(selfFrame, loadedName)
        if loadedName ~= ADDON_NAME and loadedName ~= "EzWoW-ChatTranslator" then
            return
        end
        if type(EzWoW_ChatTranslatorDB) ~= "table" then
            EzWoW_ChatTranslatorDB = {}
        end
        ns.db = CoreBootstrap.MergeDefaults(EzWoW_ChatTranslatorDB, ns.DEFAULTS or {})
        if ns.SynchronizeTargetLanguage then
            ns.SynchronizeTargetLanguage()
        end
        selfFrame:UnregisterEvent("ADDON_LOADED")
    end,
    PLAYER_LOGIN = function()
        if type(ns.OnLogin) == "function" then
            local ok, err = pcall(ns.OnLogin)
            if not ok and ns.status then
                ns.status.lastError = tostring(err)
            end
        end
    end,
})
