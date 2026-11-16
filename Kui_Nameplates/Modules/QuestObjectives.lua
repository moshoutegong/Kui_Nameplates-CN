--[[
-- Kui_Nameplates
-- By Kesava at curse.com
-- Backported by: Kader at https://github.com/bkader
--
-- QuestObjectives module (Ascension client)
--
-- Adds the built-in "Ascension NamePlates" quest icon behaviour to Kui
-- nameplates. It talks to the same server-driven API the default plates use
-- (C_QuestLog.GetUnitQuestInfo, implemented inside the Ascension client
-- binary). When that API has no data, match unit-tooltip objectives against
-- unfinished objectives in the player's quest log instead.
--   * bag icon    ("banker" atlas)     - unit drops a required quest item
--   * knife icon  ("questkill" atlas)  - unit must be slain for an objective
--   * ! / ? icons                      - quest NPCs (pick up / turn in)
--   * greyed icons                     - unavailable / incomplete states
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("QuestObjectives", addon.Prototype, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplates")

mod.uiName = L["Quest objectives"]

local BASE_SIZE = 20        -- fallback icon size when atlases are unsupported
local UPDATE_INTERVAL = .5  -- seconds between periodic refreshes
local MAX_EMPTY_RETRIES = 6 -- bounded API retries while initial data arrives
local questRevision = 0

-- classic fallback textures, only used if the client lacks atlas support
local atlas_fallbacks = {
    banker        = [[Interface\GossipFrame\BankerGossipIcon]],
    questkill     = [[Interface\GossipFrame\BattleMasterGossipIcon]],
    questturnin   = [[Interface\GossipFrame\ActiveQuestIcon]],
    questnormal   = [[Interface\GossipFrame\AvailableQuestIcon]],
    trivialquests = [[Interface\GossipFrame\AvailableQuestIcon]],
}

local GetUnitQuestInfo = (C_QuestLog and C_QuestLog.GetUnitQuestInfo) or nil

local function isNilOrEmpty(s)
    return not s or s == ""
end

-- status -> atlas mapping; prefer the client's own QuestUtil so any custom
-- Ascension statuses keep working
local function GetStatusIcon(status)
    if QuestUtil and QuestUtil.GetQuestStatusIcon then
        return QuestUtil.GetQuestStatusIcon(status)
    end
    return "questnormal", false
end

----------------------------------------------------- objective fallback --
local objectiveCache
local scanTooltip
local scanningTooltip = false

local function CleanObjectiveText(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("：", ":"):gsub("%s+", "")
end

local function GetIncompleteObjectives()
    if objectiveCache then return objectiveCache end
    objectiveCache = {}
    for index = 1, GetNumQuestLogEntries() do
        local _, _, _, _, isHeader, _, complete = GetQuestLogTitle(index)
        if not isHeader and complete ~= true
            and not (type(complete) == "number" and complete > 0) then
            for objective = 1, GetNumQuestLeaderBoards(index) do
                local text, kind, finished = GetQuestLogLeaderBoard(objective, index)
                local clean = CleanObjectiveText(text)
                local current, required = clean:match("(%d+)/(%d+)")
                if not finished and current and tonumber(current) < tonumber(required)
                    and (kind == "monster" or kind == "item") then
                    objectiveCache[#objectiveCache + 1] = {
                        text = clean,
                        atlas = kind == "item" and "banker" or "questkill",
                    }
                end
            end
        end
    end
    return objectiveCache
end

local function GetTooltipObjectiveIcon(unit, diagnosticLines)
    local objectives = GetIncompleteObjectives()
    if scanningTooltip or (#objectives == 0 and not diagnosticLines) then return end
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "KuiNameplatesQuestScanTooltip",
            UIParent, "GameTooltipTemplate")
    end
    -- Prefer a standard alias for clients whose tooltip code does not handle
    -- nameplateN tokens. Identity must match; never match creatures by name.
    for _, alias in ipairs({"mouseover", "target"}) do
        if UnitExists(alias) and UnitIsUnit(alias, unit) then unit = alias break end
    end
    scanningTooltip = true
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTooltip:ClearLines()
    scanTooltip:SetUnit(unit)
    local atlas
    for line = 1, scanTooltip:NumLines() do
        for _, side in ipairs({"Left", "Right"}) do
            local fontString = _G["KuiNameplatesQuestScanTooltipText" .. side .. line]
            local text = fontString and fontString:GetText()
            if text then
                if diagnosticLines then diagnosticLines[#diagnosticLines + 1] = text end
                local clean = CleanObjectiveText(text)
                for _, objective in ipairs(objectives) do
                    -- Exact objective text (including current progress) must be
                    -- present in this unit's tooltip. Health fractions alone
                    -- and other creatures with similar names cannot match.
                    if clean:find(objective.text, 1, true) then
                        atlas = objective.atlas
                        break
                    end
                end
            end
        end
    end
    scanTooltip:Hide()
    scanningTooltip = false
    return atlas
end

---------------------------------------------------------- unit resolution --
-- find the real (Blizzard) plate frame a kui frame belongs to
local function GetPlateForFrame(f)
    if f.questPlate and f.questPlate.kui == f then
        return f.questPlate
    end

    for _, plate in pairs(addon.frameList) do
        if plate.kui == f then
            f.questPlate = plate
            return plate
        end
    end
end

-- resolve the unit token of a real plate frame. the Ascension client's
-- C_NamePlateManager stamps _unit (and a "unit" attribute) on every active
-- nameplate; fall back to a nameplateN scan for safety.
local function IsSamePlate(mappedPlate, plate)
    if not mappedPlate or not plate then return false end

    -- Depending on the Ascension client build this API may return either the
    -- legacy WorldFrame child itself or a wrapper whose UnitFrame is it.
    return mappedPlate == plate
        or (mappedPlate.kui and mappedPlate.kui == plate.kui)
        or mappedPlate.UnitFrame == plate
        or mappedPlate.unitFrame == plate
end

local function UnitMatchesPlate(unit, plate)
    if not unit or not UnitExists(unit) then return false end

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local mappedPlate = C_NamePlate.GetNamePlateForUnit(unit)
        -- When reverse lookup exists, a missing mapping is not proof that
        -- the plate's private token is still current.
        return IsSamePlate(mappedPlate, plate)
    end

    -- Older Ascension builds may not expose a reverse lookup. In that case
    -- these are the best authoritative fields available on the legacy plate.
    return plate._unit == unit
        or (plate.GetAttribute and plate:GetAttribute("unit") == unit)
end

local function GetPlateUnit(plate)
    if not plate then return end

    -- Validate cheap candidates before scanning; never trust recycled tokens.
    local unit = plate._unit
    if UnitMatchesPlate(unit, plate) then return unit end
    if plate.GetAttribute then
        unit = plate:GetAttribute("unit")
        if UnitMatchesPlate(unit, plate) then return unit end
    end

    -- The client's active-plate iterator has no hard-coded token limit.
    if C_NamePlateManager and C_NamePlateManager.EnumerateActiveNamePlates then
        for active in C_NamePlateManager.EnumerateActiveNamePlates() do
            if IsSamePlate(active, plate) then
                unit = active._unit or (active.GetAttribute and active:GetAttribute("unit"))
                    or (active.UnitFrame and active.UnitFrame.unit)
                if UnitMatchesPlate(unit, plate) then return unit end
            end
        end
    end
    for i = 1, 40 do
        unit = "nameplate" .. i
        if UnitMatchesPlate(unit, plate) then return unit end
    end
end

------------------------------------------------------------------- layout --
-- place the icon next to the visible name text (name is centred on the
-- plate, so offsets are computed from its pixel width)
local function PositionIcon(f, icon, size)
    icon:ClearAllPoints()

    local text = addon.db.profile.text or {}
    local nap  = text.nameanchorpoint or "TOP"
    local offy = text.nameoffsety or 0

    -- vertical centre of the name string, relative to f.health
    local y
    if nap == "TOP" then
        y = offy + 5
    elseif nap == "BOTTOM" then
        y = -offy - 5
    else -- LEFT / RIGHT: name is centred on the bar
        y = 0
    end

    local anchor = mod.db.profile.anchor
    local nw = (f.name and f.name.GetStringWidth and f.name:GetStringWidth()) or 0
    local x = nw / 2 + size / 2 + 2

    -- manual fine tuning offsets
    local ox = mod.db.profile.offset_x or 0
    local oy = mod.db.profile.offset_y or 0

    if anchor == "RIGHT" then
        icon:SetPoint("CENTER", f.health, "CENTER", x + ox, y + oy)
    elseif anchor == "TOP" then
        local nh = (f.name and f.name.GetStringHeight and f.name:GetStringHeight()) or 10
        icon:SetPoint("BOTTOM", f.health, "TOP", ox, offy + nh + 2 + oy)
    else -- LEFT (default)
        icon:SetPoint("CENTER", f.health, "CENTER", -x + ox, y + oy)
    end
end

------------------------------------------------------------------ updates --
local function UpdateFrame(f, knownUnit)
    local icon = f.questIcon
    if not icon then return end

    local plate = GetPlateForFrame(f)
    local unit = knownUnit or f.questUnit
    if not UnitMatchesPlate(unit, plate) then
        unit = GetPlateUnit(plate)
    end

    if not unit or UnitIsPlayer(unit) then
        f.questUnit = nil
        f.questCheck = nil
        icon:Hide()
        return
    end

    f.questUnit = unit

    local guid = UnitGUID(unit)
    local now = GetTime()
    local check = f.questCheck
    if guid and check and check.guid == guid and check.revision == questRevision then
        -- Stable results (including no objective) need no repeated query or
        -- tooltip scan. Only retry initially empty API data for three seconds.
        if not check.nativeMissing or check.attempts >= MAX_EMPTY_RETRIES
            or now < check.nextRetry then return end
    else
        check = {guid = guid, revision = questRevision, attempts = 0}
        f.questCheck = check
    end

    local questStatus, questID, talkToMe
    if GetUnitQuestInfo then
        questStatus, questID, talkToMe = GetUnitQuestInfo(unit)
    end

    check.attempts = check.attempts + 1
    check.nativeMissing = isNilOrEmpty(talkToMe) and not questStatus
    check.nextRetry = now + UPDATE_INTERVAL

    local fallbackAtlas
    if isNilOrEmpty(talkToMe) and not questStatus and mod.db.profile.show_objectives then
        if not check.tooltipScanned then
            check.fallbackAtlas = GetTooltipObjectiveIcon(unit)
            check.tooltipScanned = true
        end
        fallbackAtlas = check.fallbackAtlas
    end
    f.questSource = fallbackAtlas and "tooltip"
        or (not check.nativeMissing and "native" or "none")
    if isNilOrEmpty(talkToMe) and not questStatus and not fallbackAtlas then
        icon:Hide()
        return
    end

    if not fallbackAtlas and isNilOrEmpty(talkToMe) and questID and questID > 0 then
        -- Filter objective units only; quest NPCs may offer quests not in
        -- the log, or turn in completed quests. A failed quest (-1) is not complete.
        local questLogIndex = GetQuestLogIndexByID(questID)
        if not questLogIndex or questLogIndex == 0 then
            icon:Hide()
            return
        end

        local isComplete = select(7, GetQuestLogTitle(questLogIndex))
        if isComplete == true or (type(isComplete) == "number" and isComplete > 0) then
            icon:Hide()
            return
        end
    end

    local atlas, desaturate

    if fallbackAtlas then
        atlas, desaturate = fallbackAtlas, false
    elseif not isNilOrEmpty(talkToMe) then
        -- quest NPC (pick up / turn in)
        if not mod.db.profile.show_npcs then
            icon:Hide()
            return
        end

        if QuestUtil and QuestUtil.GetTalkToMeQuestIcon then
            atlas, desaturate = QuestUtil.GetTalkToMeQuestIcon(talkToMe)
        end
        if not atlas then
            atlas, desaturate = GetStatusIcon(questStatus)
        end
    elseif questStatus then
        -- collect / kill objective unit
        if not mod.db.profile.show_objectives then
            icon:Hide()
            return
        end

        atlas, desaturate = GetStatusIcon(questStatus)
    end

    atlas = atlas or "questnormal"

    local size
    if icon.SetAtlas then
        -- the Ascension client supports atlas textures
        icon:SetAtlas(atlas, true)
        local w, h = icon:GetSize()
        local scale = mod.db.profile.scale
        size = w * scale
        icon:SetSize(size, h * scale)
    else
        icon:SetTexture(atlas_fallbacks[atlas] or atlas_fallbacks.questnormal)
        size = BASE_SIZE * mod.db.profile.scale
        icon:SetSize(size, size)
    end

    if icon.SetDesaturated then
        icon:SetDesaturated(desaturate and true or false)
    end

    -- Reset vertex tint because this texture object is reused by the plate.
    -- Keep the client-provided quest icons in their native white colour.
    if icon.SetVertexColor then
        icon:SetVertexColor(1, 1, 1, 1)
    end

    PositionIcon(f, icon, size)
    icon:Show()
end

local function UpdateAll(refresh)
    if refresh then questRevision = questRevision + 1 end
    GetUnitQuestInfo = C_QuestLog and C_QuestLog.GetUnitQuestInfo

    for _, plate in pairs(addon.frameList) do
        local f = plate.kui
        if f and f.questIcon and plate:IsShown() then
            UpdateFrame(f)
        end
    end
end

------------------------------------------------------------- event wiring --
local updater = CreateFrame("Frame", "KuiNameplatesQuestObjectivesUpdater", UIParent)
updater:Hide()
updater.elapsed = 0
updater:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= UPDATE_INTERVAL then
        self.elapsed = 0
        UpdateAll()
    end
end)

function mod:PostCreate(msg, f)
    if f.questIcon then return end
    -- icon lives on the overlay (same layer as name/health text)
    local icon = f.overlay:CreateTexture(nil, "OVERLAY")
    icon:SetDrawLayer("OVERLAY", 5)
    icon:Hide()
    f.questIcon = icon

    -- cache the real plate frame
    for _, plate in pairs(addon.frameList) do
        if plate.kui == f then
            f.questPlate = plate
            break
        end
    end

    UpdateFrame(f)
end

function mod:PostShow(msg, f)
    -- A legacy plate may have been recycled since its previous appearance.
    f.questUnit = nil
    f.questCheck = nil
    UpdateFrame(f)
end

function mod:PostHide(msg, f)
    f.questUnit = nil
    f.questCheck = nil
    if f.questIcon then f.questIcon:Hide() end
end

function mod:NamePlateUnitAdded(event, unit)
    if not unit or not UnitExists(unit) then return end

    local plate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit(unit)
    if plate and plate.kui then
        UpdateFrame(plate.kui, unit)
        return
    end

    -- Some client builds return a wrapper rather than Kui's legacy plate.
    for _, candidate in pairs(addon.frameList) do
        if candidate.kui and UnitMatchesPlate(unit, candidate) then
            UpdateFrame(candidate.kui, unit)
            return
        end
    end
end

function mod:NamePlateUnitRemoved(event, unit)
    for _, plate in pairs(addon.frameList) do
        local f = plate.kui
        if f and f.questUnit == unit then
            f.questUnit = nil
            f.questCheck = nil
            if f.questIcon then f.questIcon:Hide() end
        end
    end
end

function mod:OnQuestEvent(event)
    objectiveCache = nil
    UpdateAll(true)
end

function mod:OnUnitFocus(event)
    local unit = event == "UPDATE_MOUSEOVER_UNIT" and "mouseover" or "target"
    if not UnitExists(unit) then return end
    for _, plate in pairs(addon.frameList) do
        if plate.kui and plate:IsShown() and UnitMatchesPlate(unit, plate) then
            plate.kui.questCheck = nil
            UpdateFrame(plate.kui, unit)
            return
        end
    end
end

--------------------------------------------------------------- lifecycle --
function mod:OnInitialize()
    self.db = addon.db:RegisterNamespace(self.moduleName, {profile = {
        enabled         = true,
        show_npcs       = true,
        show_objectives = true,
        scale           = 1,
        anchor          = "LEFT",
        offset_x        = 0,
        offset_y        = 0,
    }})

    addon:InitModuleOptions(self)

    self:SetEnabledState(self.db.profile.enabled)
end

function mod:OnEnable()
    objectiveCache = nil
    questRevision = questRevision + 1
    if C_QuestLog and C_QuestLog.GetUnitQuestInfo then
        GetUnitQuestInfo = C_QuestLog.GetUnitQuestInfo
    end

    self:RegisterMessage("KuiNameplates_PostCreate", "PostCreate")
    self:RegisterMessage("KuiNameplates_PostShow", "PostShow")
    self:RegisterMessage("KuiNameplates_PostHide", "PostHide")

    self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestEvent")
    self:RegisterEvent("QUEST_WATCH_UPDATE", "OnQuestEvent")
    self:RegisterEvent("QUEST_ACCEPTED", "OnQuestEvent")
    self:RegisterEvent("QUEST_QUERY_COMPLETE", "OnQuestEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnQuestEvent")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitFocus")
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT", "OnUnitFocus")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "NamePlateUnitAdded")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "NamePlateUnitRemoved")

    for _, plate in pairs(addon.frameList) do
        if plate.kui then self:PostCreate(nil, plate.kui) end
    end
    updater:Show()
    UpdateAll()
end

function mod:OnDisable()
    self:UnregisterMessage("KuiNameplates_PostCreate", "PostCreate")
    self:UnregisterMessage("KuiNameplates_PostShow", "PostShow")
    self:UnregisterMessage("KuiNameplates_PostHide", "PostHide")

    self:UnregisterEvent("QUEST_LOG_UPDATE")
    self:UnregisterEvent("QUEST_WATCH_UPDATE")
    self:UnregisterEvent("QUEST_ACCEPTED")
    self:UnregisterEvent("QUEST_QUERY_COMPLETE")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    self:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")

    updater:Hide()

    for _, plate in pairs(addon.frameList) do
        if plate.kui and plate.kui.questIcon then
            plate.kui.questIcon:Hide()
        end
    end
end

--------------------------------------------------------------- options ui --
function mod:GetOptions()
    return {
        enabled = {
            type = "toggle",
            name = L["Quest objectives"],
            desc = L["Show quest icons on nameplates, using the quest data provided by the Ascension client"],
            width = "double",
            order = 10
        },
        show_npcs = {
            type = "toggle",
            name = L["Show quest NPC icons"],
            desc = L["Show quest pick up and turn in icons on quest NPCs"],
            order = 20
        },
        show_objectives = {
            type = "toggle",
            name = L["Show quest objective icons"],
            desc = L["Show collect and kill quest objective icons on nameplates"],
            order = 30
        },
        anchor = {
            type = "select",
            name = L["Icon anchor"],
            desc = L["Sets where the quest icon should appear next to the unit's name"],
            values = {
                LEFT  = L["Left"],
                RIGHT = L["Right"],
                TOP   = L["Top"]
            },
            order = 40
        },
        scale = {
            type = "range",
            name = L["Quest icon scale"],
            desc = L["The scale of the quest icon"],
            min = 0.5,
            max = 2,
            step = 0.05,
            order = 50
        },
        offset_x = {
            type = "range",
            name = L["X Offset"],
            desc = L["Sets where the quest icon should appear next to the unit's name"],
            min = -30,
            max = 30,
            step = 1,
            order = 60
        },
        offset_y = {
            type = "range",
            name = L["Y Offset"],
            desc = L["Sets where the quest icon should appear next to the unit's name"],
            min = -30,
            max = 30,
            step = 1,
            order = 70
        }
    }
end

mod:AddConfigChanged("enabled", function(v) mod:Toggle(v) end)
mod:AddConfigChanged("show_npcs", function() UpdateAll(true) end)
mod:AddConfigChanged("show_objectives", function() UpdateAll(true) end)
mod:AddConfigChanged("anchor", function() UpdateAll(true) end)
mod:AddConfigChanged("scale", function() UpdateAll(true) end)
mod:AddConfigChanged("offset_x", function() UpdateAll(true) end)
mod:AddConfigChanged("offset_y", function() UpdateAll(true) end)

-- Read-only diagnosis for the currently selected monster.
SLASH_KUIQUESTDEBUG1 = "/knpquest"
SlashCmdList.KUIQUESTDEBUG = function()
    local function report(text)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffff00Kui任务检查：|r" .. text)
    end
    if not UnitExists("target") then report("请先选中漏图标的怪物。") return end
    local mapped = C_NamePlate and C_NamePlate.GetNamePlateForUnit
        and C_NamePlate.GetNamePlateForUnit("target")
    local f, unit
    for _, plate in pairs(addon.frameList) do
        local candidate = GetPlateUnit(plate)
        if (mapped and IsSamePlate(mapped, plate))
            or (candidate and UnitIsUnit(candidate, "target")) then
            f, unit = plate.kui, candidate
            break
        end
    end
    local api = C_QuestLog and C_QuestLog.GetUnitQuestInfo
    local status, id, talk
    if api then status, id, talk = api(unit or "target") end
    report("目标=" .. tostring(UnitName("target")) .. "；血条对应单位=" .. tostring(unit)
        .. "；找到Kui血条=" .. tostring(f ~= nil))
    report("游戏返回：状态=" .. tostring(status) .. "；任务ID=" .. tostring(id)
        .. "；NPC标记=" .. tostring(talk))
    local index = id and id > 0 and GetQuestLogIndexByID(id)
    local complete = index and index > 0 and select(7, GetQuestLogTitle(index))
    report("任务日志序号=" .. tostring(index) .. "；完成值=" .. tostring(complete)
        .. "；游戏判定玩家=" .. tostring(UnitIsPlayer("target")))
    report("模块开启=" .. tostring(mod:IsEnabled()) .. "；显示任务目标="
        .. tostring(mod.db.profile.show_objectives) .. "；图标已显示="
        .. tostring(f and f.questIcon and f.questIcon:IsShown() or false))
    report("当前识别来源=" .. tostring(f and f.questSource)
        .. "；当前轮接口查询次数=" .. tostring(f and f.questCheck and f.questCheck.attempts))
    objectiveCache = nil
    local lines = {}
    local fallbackAtlas = GetTooltipObjectiveIcon(unit or "target", lines)
    report("后备识别图标=" .. tostring(fallbackAtlas)
        .. "；未完成目标数=" .. tostring(#GetIncompleteObjectives()))
    if not fallbackAtlas then
        for _, text in ipairs(lines) do report("提示内容：" .. text) end
    end
end
