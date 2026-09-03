--[[
    NSRT_CaptainZeynith - Options
    Module d'intégration de l'interface de configuration dans NorthernSkyRaidTools.
--]]

local addonName, CZ = ...

local function GetNSI()
    return _G.NorthernSkyRaidTools
end

local injected = false

--------------------------------------------------------------------------------
-- Utilitaires de texte & séparateurs (style natif NSRT)
--------------------------------------------------------------------------------
local function CreateSimpleText(parent, text, size, color, fontFlags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local NSI = GetNSI()
    if NSI and NSI.SetUIFont then
        NSI:SetUIFont(fs, size or 12, fontFlags or "")
    else
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, fontFlags or "")
    end
    if color then
        fs:SetTextColor(unpack(color))
    else
        fs:SetTextColor(1, 1, 1, 1)
    end
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateSeparator(parent, x, y, width)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0, 1, 1, 0.20)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sep:SetWidth(width)
    return sep
end

--------------------------------------------------------------------------------
-- Construction du panneau d'options
--------------------------------------------------------------------------------
local function BuildOptionsPanel(contentFrame)
    local NSI = GetNSI()
    local C = NSI and NSI.UI and NSI.UI.Components
    if not C then return end

    ----------------------------------------------------------------------------
    -- COLONNE GAUCHE : Paramètres Généraux & Actions (X = 20, Largeur = 450)
    ----------------------------------------------------------------------------
    local colLeftX = 20
    local curY = -15

    -- En-tête gauche
    local titleLeft = CreateSimpleText(contentFrame, "|cFF00FFFFCaptain Zeynith|r - Paramètres", 16, nil, "OUTLINE")
    titleLeft:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 24

    local subLeft = CreateSimpleText(contentFrame, "Automatisation du contrôle des addons en groupe et raid.", 11.5, {0.6, 0.6, 0.6, 1})
    subLeft:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 18

    CreateSeparator(contentFrame, colLeftX, curY, 440)
    curY = curY - 15

    -- Section 1 : Options automatiques
    local sec1Title = CreateSimpleText(contentFrame, "Déclenchement & Options :", 13, {1, 0.8, 0, 1})
    sec1Title:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 25

    local chkEnabled = C.CreateCheckButton(contentFrame, "Activer aussi la vérification automatique au Ready Check",
        function() return NSRT_CaptainZeynithDB.enabled end,
        function(v) NSRT_CaptainZeynithDB.enabled = v end,
        420, 22)
    chkEnabled:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 28

    local chkMyCheckOnly = C.CreateCheckButton(contentFrame, "Déclencher uniquement sur mes propres Ready Checks",
        function() return NSRT_CaptainZeynithDB.checkOnMyReadyCheckOnly end,
        function(v) NSRT_CaptainZeynithDB.checkOnMyReadyCheckOnly = v end,
        420, 22)
    chkMyCheckOnly:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 28

    local chkNoNSRT = C.CreateCheckButton(contentFrame, "Signaler les joueurs sans NSRT (aucune réponse)",
        function() return NSRT_CaptainZeynithDB.announceNoNSRT ~= false end,
        function(v) NSRT_CaptainZeynithDB.announceNoNSRT = v end,
        420, 22)
    chkNoNSRT:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 34

    -- Slider de délai réseau
    local sliderDelay = C.CreateSlider(contentFrame, "Délai réseau max par addon (s)",
        function() return NSRT_CaptainZeynithDB.stepDelay or 0.8 end,
        function(v) NSRT_CaptainZeynithDB.stepDelay = v end,
        420, 22, 0.4, 2.5, 0.1, nil, "Délai de sécurité maximal. Grâce à la détection réactive, le scan avance automatiquement dès que les membres ont répondu.", true, 1, true)
    sliderDelay:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 45

    CreateSeparator(contentFrame, colLeftX, curY, 440)
    curY = curY - 15

    -- Section 2 : Actions manuelles
    local sec2Title = CreateSimpleText(contentFrame, "Actions Immédiates :", 13, {1, 0.8, 0, 1})
    sec2Title:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 28

    local btnScan = C.CreateButton(contentFrame, "Lancer un scan immédiat", function()
        CZ:StartCheck(true)
    end, 260, 28)
    btnScan:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 34

    local btnShowReport = C.CreateButton(contentFrame, "Afficher le tableau des résultats", function()
        if CZ.ShowReportWindow then
            CZ:ShowReportWindow()
        end
    end, 260, 28)
    btnShowReport:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 34

    local btnAnnounce = C.CreateButton(contentFrame, "Annoncer le dernier bilan en Raid", function()
        CZ:AnnounceToRaid()
    end, 260, 28)
    btnAnnounce:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)
    curY = curY - 38

    local infoLabel = CreateSimpleText(contentFrame, "Astuce : Vous pouvez aussi taper /cz report ou /cz check.", 10.5, {0.5, 0.5, 0.5, 1})
    infoLabel:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colLeftX, curY)

    ----------------------------------------------------------------------------
    -- COLONNE DROITE : Addons surveillés (X = 500, Largeur = 480)
    ----------------------------------------------------------------------------
    local colRightX = 500
    local rightY = -15

    local titleRight = CreateSimpleText(contentFrame, "Addons Surveillés en Raid", 16, nil, "OUTLINE")
    titleRight:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colRightX, rightY)
    rightY = rightY - 24

    local subRight = CreateSimpleText(contentFrame, "Votre version installée sert de référence minimale pour le raid.", 11.5, {0.6, 0.6, 0.6, 1})
    subRight:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colRightX, rightY)
    rightY = rightY - 18

    CreateSeparator(contentFrame, colRightX, rightY, 480)
    rightY = rightY - 15

    -- Conteneur dynamique de la liste des addons
    local listContainer = CreateFrame("Frame", nil, contentFrame)
    listContainer:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colRightX, rightY)
    listContainer:SetSize(480, 280)

    local rows = {}
    local RefreshAddonList

    RefreshAddonList = function()
        -- Masquer les anciennes lignes
        for _, r in ipairs(rows) do
            r:Hide()
        end

        local addons = NSRT_CaptainZeynithDB.addons or {}
        local rowY = 0

        for idx, addon in ipairs(addons) do
            local row = rows[idx]
            if not row then
                row = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
                row:SetSize(480, 28)
                row:SetBackdrop({
                    bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
                    edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
                    tile = true, tileSize = 16, edgeSize = 10,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 }
                })
                row:SetBackdropColor(0.12, 0.12, 0.12, 0.7)
                row:SetBackdropBorderColor(0, 1, 1, 0.25)

                -- Nom de l'addon
                row.nameText = CreateSimpleText(row, "", 12)
                row.nameText:SetPoint("LEFT", row, "LEFT", 10, 0)

                -- Version locale
                row.verText = CreateSimpleText(row, "", 11.5)
                row.verText:SetPoint("LEFT", row, "LEFT", 220, 0)

                -- Bouton Supprimer
                row.delBtn = C.CreateSubButton(row, "Retirer", function()
                    if row.addonIndex then
                        table.remove(NSRT_CaptainZeynithDB.addons, row.addonIndex)
                        RefreshAddonList()
                    end
                end, 65)
                row.delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

                table.insert(rows, row)
            end

            row.addonIndex = idx
            row:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, rowY)
            row.nameText:SetText(string.format("|cFFFFFFFF%d. %s|r", idx, addon))

            local localVer = CZ.GetLocalVersion and CZ.GetLocalVersion(addon) or "Inconnu"
            if localVer == "Addon Missing" then
                row.verText:SetText("|cFFFF5555Non installé|r")
            elseif localVer == "Addon not enabled" then
                row.verText:SetText("|cFFFFFF00Désactivé|r")
            else
                row.verText:SetText(string.format("|cFF00FF00v%s (OK)|r", localVer))
            end

            row:Show()
            rowY = rowY - 32
        end
    end

    RefreshAddonList()
    contentFrame.RefreshOptions = RefreshAddonList

    -- Zone d'ajout en bas de la colonne droite
    local addY = rightY - 290
    CreateSeparator(contentFrame, colRightX, addY, 480)
    addY = addY - 15

    local addTitle = CreateSimpleText(contentFrame, "Ajouter un nouvel addon à surveiller :", 12.5, {1, 0.8, 0, 1})
    addTitle:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colRightX, addY)
    addY = addY - 24

    local newAddonName = ""
    local txtEntry = C.CreateTextEntry(contentFrame, "Dossier :",
        function() return newAddonName end,
        function(v) newAddonName = strtrim(v or "") end,
        280, 22, false, nil, nil, nil, "Nom exact du dossier de l'addon dans Interface\\AddOns", 180)
    txtEntry:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", colRightX, addY)

    local btnAdd = C.CreateButton(contentFrame, "+ Ajouter", function()
        local nameToAdd = strtrim(newAddonName or "")
        if nameToAdd ~= "" then
            for _, exist in ipairs(NSRT_CaptainZeynithDB.addons) do
                if exist:lower() == nameToAdd:lower() then
                    return
                end
            end
            table.insert(NSRT_CaptainZeynithDB.addons, nameToAdd)
            newAddonName = ""
            if txtEntry.editBox then
                txtEntry.editBox:SetText("")
            end
            RefreshAddonList()
        end
    end, 100, 22)
    btnAdd:SetPoint("LEFT", txtEntry.frame, "RIGHT", 10, 0)
end

--------------------------------------------------------------------------------
-- Injection dans la Sidebar et le TabSystem de NSRT
--------------------------------------------------------------------------------
local function TryInjectTab()
    if injected then return true end

    local NSI = GetNSI()
    if not (NSI and NSI.NSUI and NSI.NSUI.MenuFrame and _G["NSUISidebar"]) then
        return false
    end

    local tabSystem = NSI.NSUI.MenuFrame
    local sidebarBg = _G["NSUISidebar"]
    local Core = NSI.UI and NSI.UI.Core
    local C = NSI.UI and NSI.UI.Components

    if not (tabSystem and sidebarBg and Core and C) then
        return false
    end

    local versionsBtn = tabSystem.AllButtonsByName and tabSystem.AllButtonsByName["Versions"]
    if not versionsBtn then
        return false
    end

    -- 1. Création de la frame de contenu du module
    local content_width = Core.content_width or 1036
    local tab_content_height = Core.tab_content_height or 540
    local tab_content_y = -25 - (Core.TAB_HEADER_HEIGHT or 55)

    local tabFrame = CreateFrame("Frame", "NSUI_TabFrame_CaptainZeynith", NSI.NSUI, "BackdropTemplate")
    tabFrame:SetPoint("TOPLEFT", NSI.NSUI, "TOPLEFT", 162, tab_content_y)
    tabFrame:SetSize(content_width, tab_content_height)
    tabFrame:Hide()
    tabFrame:EnableMouse(false)

    -- Enregistrement dans tabSystem
    tabSystem.AllFramesByName["CaptainZeynith"] = tabFrame
    table.insert(tabSystem.AllFrames, tabFrame)

    -- Construction du contenu
    BuildOptionsPanel(tabFrame)

    -- 2. Injection du bouton dans la sidebar sous "Version Check"
    local _, _, _, _, vBtnY = versionsBtn.frame:GetPoint(1)
    vBtnY = vBtnY or -300

    local sepY = vBtnY - 22 - 7
    local myBtnY = vBtnY - 22 - 14

    -- Séparateur subtil
    local rule = sidebarBg:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(0, 1, 1, 0.15)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", sidebarBg, "TOPLEFT", 8, sepY)
    rule:SetPoint("TOPRIGHT", sidebarBg, "TOPRIGHT", -8, sepY)

    -- Bouton de navigation
    local czBtn = C.CreateButton(
        sidebarBg,
        "Captain Zeynith",
        function() tabSystem:SelectTabByName("CaptainZeynith") end,
        148, 22,
        "NSUITabBtn_CaptainZeynith"
    )
    czBtn:SetPoint("TOPLEFT", sidebarBg, "TOPLEFT", 5, myBtnY)
    czBtn._textKey = "Captain Zeynith"

    tabSystem.AllButtonsByName["CaptainZeynith"] = czBtn
    table.insert(tabSystem.AllButtons, czBtn)

    injected = true
    if tabSystem.CurrentName == "CaptainZeynith" or (NSI.NSUI and NSI.NSUI.PendingTabName == "CaptainZeynith") then
        tabSystem:SelectTabByName("CaptainZeynith")
    end
    return true
end

CZ.TryInjectTab = TryInjectTab

--------------------------------------------------------------------------------
-- Écoute du chargement de l'interface NSRT
--------------------------------------------------------------------------------
local uiWatcher = CreateFrame("Frame")
uiWatcher:RegisterEvent("ADDON_LOADED")
uiWatcher:RegisterEvent("PLAYER_LOGIN")

uiWatcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "NorthernSkyRaidTools_UI" then
        C_Timer.After(0.1, function()
            TryInjectTab()
        end)
    end

    local NSI = GetNSI()
    if NSI then
        -- Hook de LoadUI pour injecter dès que l'UI se prépare
        if NSI.LoadUI and not self.hookedLoadUI then
            self.hookedLoadUI = true
            hooksecurefunc(NSI, "LoadUI", function()
                C_Timer.After(0.05, function()
                    TryInjectTab()
                    if NSI.NSUI and not self.hookedOnShow then
                        self.hookedOnShow = true
                        NSI.NSUI:HookScript("OnShow", function()
                            TryInjectTab()
                        end)
                    end
                end)
            end)
        end

        -- Si NSUI est déjà présent
        if NSI.NSUI then
            if not self.hookedOnShow then
                self.hookedOnShow = true
                NSI.NSUI:HookScript("OnShow", function()
                    TryInjectTab()
                end)
            end
            TryInjectTab()
        end
    end
end)
