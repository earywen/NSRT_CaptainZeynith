--[[
    NSRT_CaptainZeynith
    Plugin d'automatisation pour NorthernSkyRaidTools (NSRT).
    Vérifie automatiquement les versions d'addons clés lors des Ready Checks.
--]]

local addonName, CZ = ...
_G["CaptainZeynith"] = CZ

local PREFIX = "|cFF00FFFF[CaptainZeynith]|r "
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

-- Configuration par défaut
local DEFAULT_CONFIG = {
    enabled = false,                -- Désactivé par défaut sur Ready Check (privilégie le bouton dédié "Check Addons")
    checkOnMyReadyCheckOnly = true, -- Vérifie uniquement quand le joueur lance le ready check
    stepDelay = 1.4,                -- Délai en secondes par addon en raid (1.4s permet la réception complète des réponses réseau sans décalage)
    announceNoNSRT = true,          -- Signaler les joueurs sans NSRT (No Response)
    addons = {
        "WowUtils",
        "NorthernSkyRaidTools",
        "BigWigs",
        "RCLootCouncil",
    }
}

-- État interne
local state = {
    isChecking = false,
    queue = {},
    currentIndex = 0,
    activeAddon = nil,
    responses = {},     -- [addonName][playerName] = versionString
    referenceVer = {},  -- [addonName] = referenceVersion
    lastReport = nil,   -- Données pré-formatées prêtes pour annonce en raid
    onlineCount = 0,
    knownNSRTPlayers = {},
    stepTimer = nil,
}

--------------------------------------------------------------------------------
-- Utilitaires de noms et versions
--------------------------------------------------------------------------------
local function CleanName(name)
    if not name then return "" end
    local shortName = strsplit("-", name)
    return shortName
end

local function GetLocalVersion(name)
    -- Recherche directe
    local ver = C_AddOns.GetAddOnMetadata(name, "Version")
    local exactName = name

    -- Si non trouvé, tentative en minuscules
    if not ver then
        ver = C_AddOns.GetAddOnMetadata(name:lower(), "Version")
        if ver then exactName = name:lower() end
    end

    if not ver then
        return "Addon Missing"
    end

    if not C_AddOns.IsAddOnLoaded(exactName) then
        return "Addon not enabled"
    end

    return ver
end

local function ParseVersion(verStr)
    if type(verStr) ~= "string" then return nil end
    local parts = {}
    for num in verStr:gmatch("(%d+)") do
        table.insert(parts, tonumber(num))
    end
    if #parts == 0 then return nil end
    return parts
end

-- Retourne :
--   1 si v1 > v2 (v1 plus récente)
--  -1 si v1 < v2 (v1 plus ancienne / obsolète)
--   0 si v1 == v2
local function CompareVersions(v1Str, v2Str)
    if not v1Str or not v2Str then return 0 end
    if v1Str == v2Str then return 0 end

    local p1 = ParseVersion(v1Str)
    local p2 = ParseVersion(v2Str)

    if not p1 or not p2 then
        return (v1Str == v2Str) and 0 or -1
    end

    local maxLen = math.max(#p1, #p2)
    for i = 1, maxLen do
        local n1 = p1[i] or 0
        local n2 = p2[i] or 0
        if n1 > n2 then return 1 end
        if n1 < n2 then return -1 end
    end
    return 0
end

--------------------------------------------------------------------------------
-- Récupération des membres du groupe / raid
--------------------------------------------------------------------------------
local function GetRosterMembers()
    local members = {}
    local seen = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name then
                local clean = CleanName(name)
                if not seen[clean] then
                    seen[clean] = true
                    table.insert(members, { name = clean, fullName = name, online = online })
                end
            end
        end
    elseif IsInGroup() then
        local myClean = CleanName(UnitName("player"))
        seen[myClean] = true
        table.insert(members, { name = myClean, fullName = UnitName("player"), online = true })

        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            if UnitExists(unit) then
                local name = UnitName(unit)
                if name then
                    local clean = CleanName(name)
                    if not seen[clean] then
                        seen[clean] = true
                        table.insert(members, { name = clean, fullName = name, online = UnitIsConnected(unit) })
                    end
                end
            end
        end
    else
        -- Solo (pour test)
        local myClean = CleanName(UnitName("player"))
        table.insert(members, { name = myClean, fullName = UnitName("player"), online = true })
    end
    return members
end

--------------------------------------------------------------------------------
-- Déroulement de la vérification (Queue séquentielle)
--------------------------------------------------------------------------------
function CZ:StartCheck(isManual)
    if state.isChecking then
        Print("|cFFFFFF00Une vérification est déjà en cours...|r")
        return
    end

    local NSI = _G.NorthernSkyRaidTools
    if not NSI then
        Print("|cFFFF0000Erreur : NorthernSkyRaidTools n'est pas chargé.|r")
        return
    end

    -- Vérification des privilèges de lead/assist si en groupe
    if IsInRaid() or IsInGroup() then
        local isLeader = UnitIsGroupLeader("player")
        local isAssist = UnitIsGroupAssistant("player")
        local isDebug = NSRT and NSRT.Settings and NSRT.Settings["Debug"]
        if not (isLeader or isAssist or isDebug) then
            Print("|cFFFF5555Attention : Vous n'êtes ni Chef de Raid ni Assistant.|r")
            Print("|cFFFF8888Pour pouvoir lancer une requête NSRT, soyez RL/Assist ou activez le mode debug NSRT ('/ns debug').|r")
            if not isManual then return end
        end
    end

    local addonsToCheck = NSRT_CaptainZeynithDB.addons or DEFAULT_CONFIG.addons
    if #addonsToCheck == 0 then
        Print("|cFFFF5555Aucun addon configuré pour la vérification.|r")
        return
    end

    state.isChecking = true
    state.queue = {}
    for _, addon in ipairs(addonsToCheck) do
        table.insert(state.queue, addon)
    end
    state.currentIndex = 0
    state.responses = {}
    state.referenceVer = {}
    state.lastReport = nil
    state.knownNSRTPlayers = {}
    if state.stepTimer then
        state.stepTimer:Cancel()
        state.stepTimer = nil
    end

    -- Compter les membres en ligne
    local roster = GetRosterMembers()
    local onlineCount = 0
    for _, m in ipairs(roster) do
        if m.online then onlineCount = onlineCount + 1 end
    end
    state.onlineCount = math.max(1, onlineCount)

    -- Initialiser les données et afficher immédiatement le tableau avec l'état de scan
    CZ.reportData = {
        roster = roster,
        addons = state.queue,
        responses = state.responses,
        refVersions = state.referenceVer,
        playerIssues = {},
        noNSRTPlayers = {},
        hasIssues = false,
        isScanning = true,
        progressText = string.format("Contrôle en cours : %s (1/%d)...", state.queue[1] or "", #state.queue),
    }
    if CZ.ShowReportWindow then
        CZ:ShowReportWindow()
    end

    Print(string.format("Démarrage du contrôle des addons (%d addons à vérifier)...", #state.queue))
    CZ:ProcessNextAddon()
end

function CZ:ProcessNextAddon()
    if state.stepTimer then
        state.stepTimer:Cancel()
        state.stepTimer = nil
    end

    state.currentIndex = state.currentIndex + 1

    if state.currentIndex > #state.queue then
        -- Fin de la queue : court délai de 0.2s pour clore proprement
        local waitTime = IsInGroup() and 0.2 or 0.05
        C_Timer.After(waitTime, function()
            CZ:FinishCheck()
        end)
        return
    end

    local addon = state.queue[state.currentIndex]
    state.activeAddon = addon
    state.responses[addon] = {}

    local myClean = CleanName(UnitName("player"))

    -- 1. Récupération directe de notre version locale (fonctionne toujours, même en solo !)
    local myLocalVer = GetLocalVersion(addon)
    state.responses[addon][myClean] = myLocalVer
    state.knownNSRTPlayers[myClean] = true

    if myLocalVer and myLocalVer ~= "Addon Missing" and myLocalVer ~= "Addon not enabled" then
        state.referenceVer[addon] = myLocalVer
    end

    -- 2. Si on est en groupe/raid, diffusion de la requête réseau via NSRT
    local NSI = _G.NorthernSkyRaidTools
    if NSI and NSI.RequestVersionNumber and IsInGroup() then
        local userData = NSI:RequestVersionNumber("Addon", addon)
        if userData then
            NSI.VersionCheckData = {
                version = userData.version,
                type = "Addon",
                name = addon,
                lastclick = {}
            }
        end
    end

    -- Mise à jour de l'indicateur d'avancement dans le tableau
    if CZ.reportData then
        CZ.reportData.isScanning = true
        CZ.reportData.progressText = string.format("Contrôle en cours : %s (%d/%d)...", addon, state.currentIndex, #state.queue)
        if CZ.UpdateReportWindow then
            CZ:UpdateReportWindow()
        end
    end

    -- 3. Minuteur dédié par addon (1.4s par défaut en groupe pour garantir que toutes les réponses arrivent sans chevauchement)
    local stepDelay = IsInGroup() and (NSRT_CaptainZeynithDB.stepDelay or 1.4) or 0.05
    state.stepTimer = C_Timer.NewTimer(stepDelay, function()
        state.stepTimer = nil
        CZ:ProcessNextAddon()
    end)
end

--------------------------------------------------------------------------------
-- Analyse & Restitution des résultats
--------------------------------------------------------------------------------
function CZ:FinishCheck()
    state.isChecking = false
    local currentActive = state.activeAddon
    state.activeAddon = nil

    local roster = GetRosterMembers()
    local addons = state.queue

    -- 1. Déterminer la version de référence maximale si le joueur ne l'a pas lui-même
    for _, addon in ipairs(addons) do
        if not state.referenceVer[addon] then
            local highestVer = nil
            for _, ver in pairs(state.responses[addon] or {}) do
                if ver and ver ~= "Addon Missing" and ver ~= "Addon not enabled" and ver ~= "No Response" and ver ~= "Offline" then
                    if not highestVer or CompareVersions(ver, highestVer) > 0 then
                        highestVer = ver
                    end
                end
            end
            state.referenceVer[addon] = highestVer
        end
    end

    -- 2. Analyser l'état de chaque joueur
    local playerIssues = {}       -- [playerName] = { "BigWigs (Manquant)", ... }
    local noNSRTPlayers = {}      -- { "Player1", "Player2" }
    local totalIssuesCount = 0
    local myClean = CleanName(UnitName("player"))

    for _, member in ipairs(roster) do
        local pName = member.name
        if member.online then
            local allNoResponse = true
            local issues = {}

            for _, addon in ipairs(addons) do
                local ver = state.responses[addon] and state.responses[addon][pName]
                local ref = state.referenceVer[addon]

                if ver and ver ~= "No Response" and ver ~= "Offline" then
                    allNoResponse = false
                end

                if ver == "Addon Missing" then
                    table.insert(issues, string.format("%s (Manquant)", addon))
                elseif ver == "Addon not enabled" then
                    table.insert(issues, string.format("%s (Désactivé)", addon))
                elseif ver and ver ~= "No Response" and ver ~= "Offline" then
                    if ref and CompareVersions(ver, ref) < 0 then
                        table.insert(issues, string.format("%s (%s < %s)", addon, ver, ref))
                    end
                end
            end

            if allNoResponse and pName ~= myClean then
                table.insert(noNSRTPlayers, pName)
            elseif #issues > 0 then
                playerIssues[pName] = issues
                totalIssuesCount = totalIssuesCount + #issues
            end
        end
    end

    -- 3. Préparation et stockage des données du rapport
    local hasAnyIssue = (totalIssuesCount > 0) or (#noNSRTPlayers > 0)

    state.lastReport = {
        playerIssues = playerIssues,
        noNSRTPlayers = noNSRTPlayers,
        hasIssues = hasAnyIssue,
    }

    CZ.reportData = {
        roster = roster,
        addons = addons,
        responses = state.responses,
        refVersions = state.referenceVer,
        playerIssues = playerIssues,
        noNSRTPlayers = noNSRTPlayers,
        hasIssues = hasAnyIssue,
    }

    -- 4. Message concis dans le chat et ouverture du tableau
    local affectedCount = 0
    for _ in pairs(playerIssues) do affectedCount = affectedCount + 1 end

    if not hasAnyIssue then
        Print("|cFF00FF00Contrôle terminé : Tout le monde est parfaitement à jour !|r")
    else
        Print(string.format("|cFFFF8000Contrôle terminé : %d joueur(s) à mettre à jour, %d sans réponse.|r (Tableau affiché)", affectedCount, #noNSRTPlayers))
    end

    if CZ.ShowReportWindow then
        CZ:ShowReportWindow()
    end
end

--------------------------------------------------------------------------------
-- Annonce dans le chat de Raid / Groupe
--------------------------------------------------------------------------------
function CZ:AnnounceToRaid()
    if not state.lastReport then
        Print("|cFFFFFF00Aucun bilan disponible. Lancez d'abord '/cz check' ou un Ready Check.|r")
        return
    end

    local channel = IsInRaid() and "RAID" or (IsInGroup() and "PARTY" or nil)
    if not channel then
        Print("|cFFFFFF00Vous n'êtes ni en raid ni en groupe. Annonce impossible.|r")
        return
    end

    local report = state.lastReport
    if not report.hasIssues then
        SendChatMessage("[NSRT] Vérification des addons terminée : Tout le monde est à jour !", channel)
        return
    end

    SendChatMessage("[NSRT] Addons requis à mettre à jour / activer :", channel)

    -- Annonce des addons manquants ou obsolètes
    for pName, issues in pairs(report.playerIssues) do
        local msg = string.format("• %s : %s", pName, table.concat(issues, ", "))
        SendChatMessage(msg, channel)
    end

    -- Annonce des personnes sans NSRT
    if #report.noNSRTPlayers > 0 and (NSRT_CaptainZeynithDB.announceNoNSRT ~= false) then
        local msg = string.format("• Sans NSRT (aucune réponse) : %s", table.concat(report.noNSRTPlayers, ", "))
        SendChatMessage(msg, channel)
    end
end

--------------------------------------------------------------------------------
-- Hook d'interactivité : Clic sur le lien dans le chat
--------------------------------------------------------------------------------
hooksecurefunc("SetItemRef", function(link)
    if link == "nsrtcz:announce" then
        CZ:AnnounceToRaid()
    end
end)

--------------------------------------------------------------------------------
-- Gestion des Événements WoW
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("READY_CHECK")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            NSRT_CaptainZeynithDB = NSRT_CaptainZeynithDB or {}
            for k, v in pairs(DEFAULT_CONFIG) do
                if NSRT_CaptainZeynithDB[k] == nil then
                    NSRT_CaptainZeynithDB[k] = v
                end
            end
            if not NSRT_CaptainZeynithDB.v11Migrated then
                NSRT_CaptainZeynithDB.enabled = false
                NSRT_CaptainZeynithDB.v11Migrated = true
            end
            if not NSRT_CaptainZeynithDB.v13ReliableScan or (NSRT_CaptainZeynithDB.stepDelay and NSRT_CaptainZeynithDB.stepDelay < 1.2) then
                NSRT_CaptainZeynithDB.stepDelay = 1.4
                NSRT_CaptainZeynithDB.v13ReliableScan = true
            end
        end
    elseif event == "PLAYER_LOGIN" then
        local NSI = _G.NorthernSkyRaidTools
        if NSI and NSI.VersionResponse then
            hooksecurefunc(NSI, "VersionResponse", function(_, data)
                if not state.isChecking or not state.activeAddon then return end
                if data and data.name and data.version then
                    local currentAddon = state.activeAddon
                    state.responses[currentAddon] = state.responses[currentAddon] or {}

                    local clean = CleanName(data.name)
                    local prev = state.responses[currentAddon][clean]
                    if data.version ~= "No Response" and data.version ~= "Offline" then
                        state.responses[currentAddon][clean] = data.version
                        state.knownNSRTPlayers[clean] = true
                    elseif prev == nil then
                        state.responses[currentAddon][clean] = data.version
                    end
                end
            end)
        end
    elseif event == "READY_CHECK" then
        local initiator, duration = ...
        if NSRT_CaptainZeynithDB and NSRT_CaptainZeynithDB.enabled then
            local isMyCheck = (initiator == UnitName("player"))
            if isMyCheck or (not NSRT_CaptainZeynithDB.checkOnMyReadyCheckOnly) then
                Print(string.format("Ready Check détecté (%s) -> Lancement automatique du contrôle...", initiator or "Inconnu"))
                CZ:StartCheck(false)
            end
        end
    end
end)

CZ.GetLocalVersion = GetLocalVersion
CZ.CompareVersions = CompareVersions

function CZ:OpenOptions()
    local NSI = _G.NorthernSkyRaidTools
    if not NSI then
        Print("|cFFFF0000Erreur : NorthernSkyRaidTools n'est pas chargé.|r")
        return
    end

    if NSI.LoadUI then
        NSI:LoadUI(true, "CaptainZeynith")
    end

    C_Timer.After(0.1, function()
        if CZ.TryInjectTab then
            CZ.TryInjectTab()
        end
        if NSI.NSUI then
            if not NSI.NSUI:IsShown() then
                NSI.NSUI:Show()
            end
            if NSI.NSUI.MenuFrame and NSI.NSUI.MenuFrame.SelectTabByName then
                NSI.NSUI.MenuFrame:SelectTabByName("CaptainZeynith")
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Commandes Slash (/cz, /zeynith)
--------------------------------------------------------------------------------
SLASH_CAPTAINZEYNITH1 = "/cz"
SLASH_CAPTAINZEYNITH2 = "/zeynith"

SlashCmdList["CAPTAINZEYNITH"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "config" or cmd == "options" or cmd == "opt" or cmd == "ui" then
        CZ:OpenOptions()
    elseif cmd == "report" or cmd == "table" or cmd == "window" or cmd == "tab" then
        if CZ.ShowReportWindow then
            CZ:ShowReportWindow()
        else
            Print("|cFFFF0000Le module de tableau n'est pas disponible.|r")
        end
    elseif cmd == "check" then
        CZ:StartCheck(true)
    elseif cmd == "announce" then
        CZ:AnnounceToRaid()
    elseif cmd == "list" then
        Print("Addons surveillés actuellement :")
        for i, addon in ipairs(NSRT_CaptainZeynithDB.addons) do
            local myVer = GetLocalVersion(addon)
            local color = (myVer ~= "Addon Missing" and myVer ~= "Addon not enabled") and "|cFF00FF00" or "|cFFFF5555"
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  %d. |cFFFFFFFF%s|r (votre version : %s%s|r)", i, addon, color, myVer))
        end
    elseif cmd == "add" and arg ~= "" then
        table.insert(NSRT_CaptainZeynithDB.addons, arg)
        Print(string.format("Addon '|cFFFFFFFF%s|r' ajouté à la liste.", arg))
    elseif cmd == "remove" and arg ~= "" then
        for i, addon in ipairs(NSRT_CaptainZeynithDB.addons) do
            if addon:lower() == arg:lower() then
                table.remove(NSRT_CaptainZeynithDB.addons, i)
                Print(string.format("Addon '|cFFFFFFFF%s|r' retiré de la liste.", addon))
                return
            end
        end
        Print(string.format("Addon '|cFFFFFFFF%s|r' introuvable dans la liste.", arg))
    elseif cmd == "toggle" then
        NSRT_CaptainZeynithDB.enabled = not NSRT_CaptainZeynithDB.enabled
        Print("Contrôle automatique sur Ready Check : " .. (NSRT_CaptainZeynithDB.enabled and "|cFF00FF00Activé|r" or "|cFFFF5555Désactivé|r"))
    else
        Print("Commandes disponibles :")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz|r : Ouvrir les options dans NorthernSkyRaidTools")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz report|r : Afficher le tableau des résultats du dernier contrôle")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz check|r : Lancer immédiatement une vérification")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz announce|r : Annoncer le dernier bilan en raid")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz list|r : Voir les addons surveillés et vos versions")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz add <Nom>|r : Ajouter un addon à surveiller")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz remove <Nom>|r : Retirer un addon")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFF00FFFF/cz toggle|r : Activer/désactiver l'auto-check sur Ready Check")
    end
end
