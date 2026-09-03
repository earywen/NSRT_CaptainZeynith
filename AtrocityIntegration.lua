--[[
    NSRT_CaptainZeynith - AtrocityIntegration
    Intégration d'un bouton dédié "Check Addons" dans le panneau Raid Control d'atrocityEssentials.
--]]

local addonName, CZ = ...

local injected = false

local function TryInjectAtrocity()
    if injected then return true end

    local AE = _G.atrocityEssentials
    if not AE then return false end

    local RC = AE.GetModule and AE:GetModule("RaidControl", true)
    if not (RC and RC.setup and RC.Panel) then
        return false
    end

    if _G.AES_RaidControlCheckAddons then
        injected = true
        return true
    end

    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            TryInjectAtrocity()
        end)
        return false
    end

    local panel = RC.Panel
    local S = AE.Skins
    local BUTTON_HEIGHT = 20
    local BUTTON_WIDTH = panel:GetWidth() - 4 -- 246px

    -- Déterminer le dernier bouton sous lequel s'ancrer
    local anchorTo = _G.AES_RaidControlNSRTNotes or _G.AES_RaidControlVantus or _G.AES_RaidControlSplitGroups or _G.AES_RaidControlReadyCheck
    if not anchorTo then return false end

    -- Création du bouton
    local btn = CreateFrame("Button", "AES_RaidControlCheckAddons", panel)
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    btn:SetFrameLevel(panel:GetFrameLevel() + 5)
    btn:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -3)

    if S and S.Button then
        S.Button(btn)
    end

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if S and S.SetFont then
        S.SetFont(text, 12, "")
    else
        text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    end
    text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetText("Check Addons")
    btn:SetFontString(text)
    btn.Text = text

    -- Interactions souris
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouseButton)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if mouseButton == "RightButton" then
            CZ:OpenOptions()
        else
            CZ:StartCheck(true)
        end
    end)

    -- Tooltip d'aide
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Captain Zeynith", 0, 1, 1)
        GameTooltip:AddLine("Vérification des versions d'addons des membres du raid.", 1, 1, 1)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFFFF00Clic gauche :|r Lancer la vérification", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cFFFFFF00Clic droit :|r Ouvrir les options (/cz)", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Enregistrement dans RaidOnlyRows de RaidControl
    local rowHeight = BUTTON_HEIGHT + 3
    RC._panelHeightFull = (RC._panelHeightFull or panel:GetHeight()) + rowHeight

    if RC.RaidOnlyRows then
        table.insert(RC.RaidOnlyRows, { h = rowHeight, btn })
    end

    -- Forcer le recalcul complet de la hauteur du panneau et le repositionnement des sections
    RC._inRaidApplied = nil
    if RC.ApplyGroupContext then
        RC:ApplyGroupContext()
    end

    local inRaid = UnitInRaid("player") and true or false
    btn:SetShown(inRaid)
    if inRaid then
        panel:SetHeight(RC._panelHeightFull)
    end

    if RC.PositionSections then
        RC:PositionSections()
    end

    -- Hook pour garantir le maintien des dimensions lors de l'ouverture du panneau
    panel:HookScript("OnShow", function()
        C_Timer.After(0.02, function()
            local inRaidNow = UnitInRaid("player") and true or false
            btn:SetShown(inRaidNow)
            if inRaidNow and RC._panelHeightFull then
                panel:SetHeight(RC._panelHeightFull)
            end
            if RC.PositionSections then
                RC:PositionSections()
            end
        end)
    end)

    injected = true
    return true
end

CZ.TryInjectAtrocity = TryInjectAtrocity

--------------------------------------------------------------------------------
-- Écoute du cycle de chargement
--------------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")

watcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "atrocityEssentials" then
        C_Timer.After(0.1, TryInjectAtrocity)
    end

    local AE = _G.atrocityEssentials
    if AE then
        local RC = AE.GetModule and AE:GetModule("RaidControl", true)
        if RC then
            if RC.setup then
                TryInjectAtrocity()
            elseif not self.hookedSetup then
                self.hookedSetup = true
                hooksecurefunc(RC, "Setup", function()
                    C_Timer.After(0.05, TryInjectAtrocity)
                end)
            end
        end
    end
end)
