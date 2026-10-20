--===========================================================================
-- EzWoW - Chat Translator
-- UI/MinimapButton.lua : Draggable Minimap Ring & Free-Position Button
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local MinimapLauncherButton = ns.MinimapLauncherButton or {}
ns.MinimapLauncherButton = MinimapLauncherButton
local L = setmetatable({}, { __index = function(_, k) return ns.L[k] end })
local iconTex = "Interface\\AddOns\\" .. ADDON .. "\\Media\\icon"

local button
local RADIUS = 80
local grabDX, grabDY = 0, 0

local function GetMinimapRadius()
    local r = ((Minimap and Minimap:GetWidth()) or 140) / 2 + 10
    if r < 60 or r > 140 then r = RADIUS end
    return r
end

function MinimapLauncherButton.updateWidgetAnchorPosition()
    if not button or not Minimap then return end
    button:SetScale(1)
    button:ClearAllPoints()
    local mm = ns.db and ns.db.minimap
    if mm and mm.freeX and mm.freeY then
        button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mm.freeX, mm.freeY)
        return
    end
    local angle = math.rad((mm and mm.angle) or 205)
    local rowEntry = GetMinimapRadius()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * rowEntry, math.sin(angle) * rowEntry)
end

function MinimapLauncherButton.onDragUpdate(self)
    local btn = self or button
    if not btn or not Minimap then return end
    local bScale = btn:GetEffectiveScale() or 1
    local mScale = Minimap:GetEffectiveScale() or 1
    local rawX, rawY = GetCursorPosition()
    local curX, curY = rawX / bScale + grabDX, rawY / bScale + grabDY

    local mxVal, myVal = Minimap:GetCenter()
    if mxVal and myVal then
        -- Convert cursor+grab into Minimap coordinate space to check distance from Minimap ring
        local curMX = (curX * bScale) / mScale
        local curMY = (curY * bScale) / mScale
        local dx, dy = curMX - mxVal, curMY - myVal
        local dist = math.sqrt(dx * dx + dy * dy)
        local ringRadius = GetMinimapRadius()
        if dist <= ringRadius + 28 then
            ns.db.minimap.freeX = nil
            ns.db.minimap.freeY = nil
            ns.db.minimap.angle = math.deg(math.atan2(dy, dx)) % 360
            MinimapLauncherButton.updateWidgetAnchorPosition()
            return
        end
    end

    local uiW = (UIParent and UIParent:GetWidth()) or 1920
    local uiH = (UIParent and UIParent:GetHeight()) or 1080
    if curX < 16 then curX = 16 elseif curX > uiW - 16 then curX = uiW - 16 end
    if curY < 16 then curY = 16 elseif curY > uiH - 16 then curY = uiH - 16 end
    ns.db.minimap.freeX = curX
    ns.db.minimap.freeY = curY
    MinimapLauncherButton.updateWidgetAnchorPosition()
end

function MinimapLauncherButton.createPrimaryWidget()
    if button or not Minimap then return end
    button = CreateFrame("Button", "EzWoWChatTranslatorMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetScale(1)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local iconTex2 = button:CreateTexture(nil, "BACKGROUND")
    iconTex2:SetTexture(iconTex)
    iconTex2:SetSize(20, 20)
    iconTex2:SetPoint("TOPLEFT", 6, -5)
    local borderTex = button:CreateTexture(nil, "OVERLAY")
    borderTex:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    borderTex:SetSize(53, 53)
    borderTex:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(self, mouse)
        if self.dragging then return end
        if mouse == "RightButton" and ns.ShowUnknownChat then
            ns.ShowUnknownChat()
        else
            ns.ToggleOptions()
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScale(1)
        self.dragging = true
        GameTooltip:Hide()
        local bScale = self:GetEffectiveScale() or 1
        local rawX, rawY = GetCursorPosition()
        local cx, cy = rawX / bScale, rawY / bScale
        local bx, by = self:GetCenter()
        if bx and by then
            grabDX = bx - cx
            grabDY = by - cy
        else
            grabDX, grabDY = 0, 0
        end
        self:SetScript("OnUpdate", MinimapLauncherButton.onDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.dragging = false
    end)
    button:SetScript("OnEnter", function(self)
        if self.dragging then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("EzWoW - Chat Translator", 0.478, 0.855, 0.831)
        local tipWidget = L.minimapTip
        if tipWidget then
            local first = true
            for line in tipWidget:gmatch("[^\n]+") do
                if first then
                    GameTooltip:AddLine(line, 0.929, 0.957, 0.969)
                    first = false
                else
                    GameTooltip:AddLine(line, 0.655, 0.725, 0.773)
                end
            end
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    MinimapLauncherButton.updateWidgetAnchorPosition()
end


function ns.ResetMinimapButton()
    if not ns.db then return end
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.show = true
    ns.db.minimap.angle = 205
    ns.db.minimap.freeX = nil
    ns.db.minimap.freeY = nil
    MinimapLauncherButton.createPrimaryWidget()
    if button then
        button:Show()
        MinimapLauncherButton.updateWidgetAnchorPosition()
    end
end

function ns.UpdateMinimapButton()
    if not ns.db then return end
    ns.db.minimap = ns.db.minimap or { show = true, angle = 205 }
    if ns.db.minimap.show == false then
        if button then button:Hide() end
        return
    end
    MinimapLauncherButton.createPrimaryWidget()
    if button then button:Show(); MinimapLauncherButton.updateWidgetAnchorPosition() end
end

local prevLogin = ns.OnLogin
ns.OnLogin = function()
    if prevLogin then prevLogin() end
    pcall(ns.UpdateMinimapButton)
end
