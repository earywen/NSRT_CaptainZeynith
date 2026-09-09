--[[
    NSRT_CaptainZeynith - ReportWindow
    Fenêtre de restitution des résultats sous forme de tableau interactif (style NSRT).
--]]

local addonName, CZ = ...

local reportFrame = nil

--------------------------------------------------------------------------------
-- Utilitaires de style & polices
--------------------------------------------------------------------------------
local function SetUIFont(fs, size, flags)
    local NSI = _G.NorthernSkyRaidTools
    if NSI and NSI.SetUIFont then
        NSI:SetUIFont(fs, size or 11, flags or "")
    else
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, flags or "")
    end
end

local function GetPlayerClassColor(playerName)
    if not playerName then return "FFFFFFFF" end
    -- Vérification dans le raid
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) then
                local uName = GetUnitName(unit, true)
                if uName and (uName:match("^([^%-]+)") == playerName or uName == playerName) then
                    local _, classFile = UnitClass(unit)
                    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
                        return RAID_CLASS_COLORS[classFile].colorStr or "FFFFFFFF"
                    end
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                local uName = GetUnitName(unit, true)
                if uName and (uName:match("^([^%-]+)") == playerName or uName == playerName) then
                    local _, classFile = UnitClass(unit)
                    if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
                        return RAID_CLASS_COLORS[classFile].colorStr or "FFFFFFFF"
                    end
                end
            end
        end
    end

    -- Joueur local
    local localName = UnitName("player")
    if localName and (localName:match("^([^%-]+)") == playerName or localName == playerName) then
        local _, classFile = UnitClass("player")
        if classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
            return RAID_CLASS_COLORS[classFile].colorStr or "FFFFFFFF"
        end
    end

    return "FFFFFFFF"
end

local function FormatVer(v)
    if not v or v == "" or v == "?" then return "?" end
    local s = tostring(v)
    if s:sub(1, 1):lower() == "v" then
        return s
    end
    return "v" .. s
end

local function CreateStyledButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = [[Interface\Buttons\WHITE8x8]],
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        tile     = true,
        tileSize = 16,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    btn:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
    btn:SetBackdropBorderColor(0, 0.8, 1, 0.35)

    local txt = btn:CreateFontString(nil, "OVERLAY")
    SetUIFont(txt, 11, "")
    txt:SetPoint("CENTER", btn, "CENTER", 0, 0)
    txt:SetText(text)
    btn.Text = txt

    btn:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then return end
        self:SetBackdropColor(0, 0.45, 0.65, 0.4)
        self:SetBackdropBorderColor(0, 1, 1, 0.8)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.12, 0.15, 0.95)
        self:SetBackdropBorderColor(0, 0.8, 1, 0.35)
    end)
    btn:HookScript("OnDisable", function(self)
        if self.Text then self.Text:SetTextColor(0.5, 0.5, 0.5, 1) end
    end)
    btn:HookScript("OnEnable", function(self)
        if self.Text then self.Text:SetTextColor(1, 1, 1, 1) end
    end)
    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if onClick then onClick(self) end
    end)

    return btn
end

--------------------------------------------------------------------------------
-- Création de la fenêtre principale du tableau
--------------------------------------------------------------------------------
local function CreateReportFrame()
    if reportFrame then return reportFrame end

    local f = CreateFrame("Frame", "CZ_ReportFrame", UIParent, "BackdropTemplate")
    f:SetSize(760, 500)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    -- Fermeture avec la touche Échap
    table.insert(UISpecialFrames, "CZ_ReportFrame")

    -- Fond totalement opaque & solide
    local bgTex = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bgTex:SetAllPoints(f)
    bgTex:SetColorTexture(0.06, 0.06, 0.08, 0.98)
    f.bgTex = bgTex

    -- Bordure fine cyan style NSRT
    f:SetBackdrop({
        edgeFile = [[Interface\Buttons\WHITE8x8]],
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    f:SetBackdropBorderColor(0, 0.85, 1, 0.60)

    -- En-tête : Titre
    local title = f:CreateFontString(nil, "OVERLAY")
    SetUIFont(title, 15, "OUTLINE")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -14)
    title:SetText("|cFF00FFFFCaptain Zeynith|r  |cFFFFFFFF— Bilan des Addons du Raid|r")
    f.Title = title

    -- Bouton de fermeture "X"
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    SetUIFont(closeTxt, 13, "OUTLINE")
    closeTxt:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeTxt:SetText("|cFF888888X|r")
    closeBtn:SetScript("OnEnter", function() closeTxt:SetText("|cFFFF5555X|r") end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetText("|cFF888888X|r") end)
    closeBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        f:Hide()
    end)

    -- Barre de résumé (statistiques globales)
    local statsBar = f:CreateFontString(nil, "OVERLAY")
    SetUIFont(statsBar, 11, "")
    statsBar:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -38)
    f.StatsBar = statsBar

    -- Séparateur sous l'en-tête
    local sepTop = f:CreateTexture(nil, "ARTWORK")
    sepTop:SetColorTexture(0, 1, 1, 0.20)
    sepTop:SetHeight(1)
    sepTop:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -58)
    sepTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -58)

    -- Conteneur d'en-têtes de colonnes
    local headerContainer = CreateFrame("Frame", nil, f)
    headerContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -62)
    headerContainer:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -62)
    headerContainer:SetHeight(26)
    f.HeaderContainer = headerContainer

    -- Séparateur sous les en-têtes de colonnes
    local sepHeader = f:CreateTexture(nil, "ARTWORK")
    sepHeader:SetColorTexture(0, 1, 1, 0.25)
    sepHeader:SetHeight(1)
    sepHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -90)
    sepHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -90)

    -- ScrollFrame pour le tableau
    local scrollFrame = CreateFrame("ScrollFrame", "CZ_ReportScrollFrame", f)
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -94)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 48)
    f.ScrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(732, 1)
    scrollFrame:SetScrollChild(scrollChild)
    f.ScrollChild = scrollChild

    -- Molette de la souris pour défiler
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = math.max(0, scrollChild:GetHeight() - self:GetHeight())
        local new = math.min(maxScroll, math.max(0, current - (delta * 36)))
        self:SetVerticalScroll(new)
    end)

    -- Séparateur bas
    local sepBottom = f:CreateTexture(nil, "ARTWORK")
    sepBottom:SetColorTexture(0, 1, 1, 0.20)
    sepBottom:SetHeight(1)
    sepBottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 44)
    sepBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 44)

    -- Boutons du bas
    local btnAnnounce = CreateStyledButton(f, "Annoncer en Raid", 150, 26, function()
        CZ:AnnounceToRaid()
    end)
    btnAnnounce:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 10)
    f.BtnAnnounce = btnAnnounce

    local btnRescan = CreateStyledButton(f, "Relancer le scan", 140, 26, function()
        CZ:StartCheck(true)
    end)
    btnRescan:SetPoint("LEFT", btnAnnounce, "RIGHT", 10, 0)

    local btnConfig = CreateStyledButton(f, "Options (/cz)", 110, 26, function()
        f:Hide()
        CZ:OpenOptions()
    end)
    btnConfig:SetPoint("LEFT", btnRescan, "RIGHT", 10, 0)

    local btnClose = CreateStyledButton(f, "Fermer", 90, 26, function()
        f:Hide()
    end)
    btnClose:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 10)

    f.headerLabels = {}
    f.rows = {}

    reportFrame = f
    return f
end

--------------------------------------------------------------------------------
-- Mise à jour du contenu du tableau
--------------------------------------------------------------------------------
function CZ:UpdateReportWindow()
    local f = CreateReportFrame()
    local reportData = CZ.reportData
    if not reportData then
        f.StatsBar:SetText("|cFF888888Aucun bilan récent disponible. Lancez un scan.|r")
        return
    end

    local addons = reportData.addons or {}
    local roster = reportData.roster or {}
    local responses = reportData.responses or {}
    local refVersions = reportData.refVersions or {}
    local playerIssues = reportData.playerIssues or {}
    local noNSRTPlayers = reportData.noNSRTPlayers or {}

    -- 1. Calcul des largeurs de colonnes dynamiques
    local tableW = f.HeaderContainer:GetWidth()
    if tableW <= 10 then tableW = 732 end

    local colPlayerW = 145
    local colStatusW = 95
    local numAddons = math.max(1, #addons)
    local availableW = tableW - colPlayerW - colStatusW - 10
    local colAddonW = math.max(85, math.floor(availableW / numAddons))

    -- 2. Mise à jour des en-têtes de colonnes
    for _, lbl in ipairs(f.headerLabels) do
        lbl:Hide()
    end

    local function GetHeaderLabel(idx)
        if not f.headerLabels[idx] then
            local lbl = f.HeaderContainer:CreateFontString(nil, "OVERLAY")
            SetUIFont(lbl, 11, "OUTLINE")
            f.headerLabels[idx] = lbl
        end
        return f.headerLabels[idx]
    end

    -- En-tête Joueur
    local hPlayer = GetHeaderLabel(1)
    hPlayer:ClearAllPoints()
    hPlayer:SetPoint("LEFT", f.HeaderContainer, "LEFT", 4, 0)
    hPlayer:SetWidth(colPlayerW)
    hPlayer:SetJustifyH("LEFT")
    hPlayer:SetText("|cFF00FFFFJoueur|r")
    hPlayer:Show()

    -- En-têtes Addons
    local curX = colPlayerW + 4
    for aIdx, addon in ipairs(addons) do
        local hAddon = GetHeaderLabel(1 + aIdx)
        hAddon:ClearAllPoints()
        hAddon:SetPoint("LEFT", f.HeaderContainer, "LEFT", curX, 0)
        hAddon:SetWidth(colAddonW)
        hAddon:SetJustifyH("LEFT")

        local refVer = refVersions[addon] or "?"
        hAddon:SetText(string.format("|cFFFFFFFF%s|r\n|cFF00FF00(%s)|r", addon, FormatVer(refVer)))
        hAddon:Show()
        curX = curX + colAddonW
    end

    -- En-tête Bilan
    local hStatus = GetHeaderLabel(2 + #addons)
    hStatus:ClearAllPoints()
    hStatus:SetPoint("LEFT", f.HeaderContainer, "LEFT", curX, 0)
    hStatus:SetWidth(colStatusW)
    hStatus:SetJustifyH("CENTER")
    hStatus:SetText("|cFF00FFFFBilan|r")
    hStatus:Show()

    -- 3. Tri des joueurs : Problèmes en haut, puis sans NSRT, puis à jour
    local sortedPlayers = {}
    for _, p in ipairs(roster) do
        local nameStr = (type(p) == "table" and (p.name or p.fullName)) or tostring(p)
        table.insert(sortedPlayers, nameStr)
    end

    local noNSRTSet = {}
    for _, name in ipairs(noNSRTPlayers) do
        noNSRTSet[name] = true
    end

    table.sort(sortedPlayers, function(a, b)
        local aHasIssues = (playerIssues[a] and #playerIssues[a] > 0)
        local bHasIssues = (playerIssues[b] and #playerIssues[b] > 0)
        local aNoNSRT = noNSRTSet[a]
        local bNoNSRT = noNSRTSet[b]

        local rankA = aHasIssues and 1 or (aNoNSRT and 2 or 3)
        local rankB = bHasIssues and 1 or (bNoNSRT and 2 or 3)

        if rankA ~= rankB then
            return rankA < rankB
        else
            return a < b
        end
    end)

    -- 4. Génération des lignes de joueurs
    for _, row in ipairs(f.rows) do
        row:Hide()
    end

    local rowHeight = 26
    local totalH = #sortedPlayers * rowHeight
    f.ScrollChild:SetHeight(math.max(1, totalH))

    local okCount = 0
    local issueCount = 0
    local noNSRTCount = #noNSRTPlayers

    for rIdx, pName in ipairs(sortedPlayers) do
        local row = f.rows[rIdx]
        if not row then
            row = CreateFrame("Frame", nil, f.ScrollChild, "BackdropTemplate")
            row:SetSize(tableW, rowHeight)
            row:SetBackdrop({
                bgFile = [[Interface\Buttons\WHITE8x8]],
                tile = true, tileSize = 16,
            })

            row.playerName = row:CreateFontString(nil, "OVERLAY")
            SetUIFont(row.playerName, 11, "")
            row.playerName:SetJustifyH("LEFT")

            row.addonTexts = {}

            row.statusText = row:CreateFontString(nil, "OVERLAY")
            SetUIFont(row.statusText, 11, "")
            row.statusText:SetJustifyH("CENTER")

            f.rows[rIdx] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.ScrollChild, "TOPLEFT", 0, -((rIdx - 1) * rowHeight))
        row:SetWidth(tableW)

        -- Alternance de couleur de ligne
        if (rIdx % 2) == 1 then
            row:SetBackdropColor(0.12, 0.12, 0.14, 0.75)
        else
            row:SetBackdropColor(0.16, 0.16, 0.19, 0.75)
        end

        -- Nom du joueur avec couleur de classe
        local colorHex = GetPlayerClassColor(pName)
        row.playerName:ClearAllPoints()
        row.playerName:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.playerName:SetWidth(colPlayerW)
        row.playerName:SetText(string.format("|c%s%d. %s|r", colorHex, rIdx, pName))

        -- Cellules des addons
        local isNoNSRT = noNSRTSet[pName]
        local pIssues = playerIssues[pName]
        local curCellX = colPlayerW + 4

        for aIdx, addon in ipairs(addons) do
            local cell = row.addonTexts[aIdx]
            if not cell then
                cell = row:CreateFontString(nil, "OVERLAY")
                SetUIFont(cell, 10.5, "")
                cell:SetJustifyH("LEFT")
                row.addonTexts[aIdx] = cell
            end

            cell:ClearAllPoints()
            cell:SetPoint("LEFT", row, "LEFT", curCellX, 0)
            cell:SetWidth(colAddonW)

            local pVer = responses[addon] and responses[addon][pName]
            local refVer = refVersions[addon]

            if isNoNSRT or not pVer or pVer == "No Response" then
                cell:SetText("|cFF666666—|r")
            elseif pVer == "Addon Missing" then
                cell:SetText("|cFFFF3333Manquant|r")
            elseif pVer == "Addon not enabled" then
                cell:SetText("|cFFFFFF00Désactivé|r")
            else
                local cmp = CZ.CompareVersions and CZ.CompareVersions(pVer, refVer) or 0
                if cmp >= 0 then
                    cell:SetText(string.format("|cFF00FF00%s|r", FormatVer(pVer)))
                else
                    cell:SetText(string.format("|cFFFF5555%s|r", FormatVer(pVer)))
                end
            end

            cell:Show()
            curCellX = curCellX + colAddonW
        end

        -- Masquer les cellules d'addons excédentaires
        for aIdx = #addons + 1, #row.addonTexts do
            row.addonTexts[aIdx]:Hide()
        end

        -- Cellule de statut global
        row.statusText:ClearAllPoints()
        row.statusText:SetPoint("LEFT", row, "LEFT", curCellX, 0)
        row.statusText:SetWidth(colStatusW)

        if isNoNSRT then
            row.statusText:SetText("|cFF888888Sans NSRT|r")
        elseif pIssues and #pIssues > 0 then
            issueCount = issueCount + 1
            row.statusText:SetText("|cFFFF5555À corriger|r")
        else
            okCount = okCount + 1
            row.statusText:SetText("|cFF00FF00À jour|r")
        end

        row:Show()
    end

    -- 5. Mise à jour de la barre de statistiques
    if reportData.isScanning then
        f.StatsBar:SetText(string.format(
            "Membres : |cFFFFFFFF%d|r  |  |cFFFFFF00%s|r",
            #sortedPlayers, reportData.progressText or "Contrôle en cours..."
        ))
        if f.BtnAnnounce and f.BtnAnnounce.Disable then f.BtnAnnounce:Disable() end
        if f.BtnRescan and f.BtnRescan.Disable then f.BtnRescan:Disable() end
    else
        f.StatsBar:SetText(string.format(
            "Membres : |cFFFFFFFF%d|r  |  À jour : |cFF00FF00%d|r  |  À corriger : |cFFFF5555%d|r  |  Sans NSRT : |cFF888888%d|r",
            #sortedPlayers, okCount, issueCount, noNSRTCount
        ))
        if f.BtnAnnounce and f.BtnAnnounce.Enable then f.BtnAnnounce:Enable() end
        if f.BtnRescan and f.BtnRescan.Enable then f.BtnRescan:Enable() end

        -- Mettre à jour l'état du bouton d'annonce
        if (issueCount > 0) or (noNSRTCount > 0 and NSRT_CaptainZeynithDB.announceNoNSRT ~= false) then
            f.BtnAnnounce.Text:SetText("Annoncer les problèmes en Raid")
        else
            f.BtnAnnounce.Text:SetText("Annoncer que tout est OK")
        end
    end
end

--------------------------------------------------------------------------------
-- Affichage / Masquage
--------------------------------------------------------------------------------
function CZ:ShowReportWindow()
    local f = CreateReportFrame()
    CZ:UpdateReportWindow()
    f:Show()
end

function CZ:HideReportWindow()
    if reportFrame then
        reportFrame:Hide()
    end
end

function CZ:ToggleReportWindow()
    local f = CreateReportFrame()
    if f:IsShown() then
        f:Hide()
    else
        CZ:ShowReportWindow()
    end
end
