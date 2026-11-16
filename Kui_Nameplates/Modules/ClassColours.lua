--[[
-- Kui_Nameplates
-- By Kesava at curse.com
-- All rights reserved
-- Backported by: Kader at https://github.com/bkader
--
-- Provides class colours for friendly targets and for hostile players'
-- health bars (the latter resolved from the guid, since the CoA client
-- does not class-colour hostile custom-class nameplates)
]]
local addon = LibStub("AceAddon-3.0"):GetAddon("KuiNameplates")
local mod = addon:NewModule("ClassColours", addon.Prototype, "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("KuiNameplates")

local select, GetPlayerInfoByGUID, tinsert = select, GetPlayerInfoByGUID, tinsert

local cc_table

mod.uiName = L["Class colours"]

local function SetCVars()
	SetCVar("ShowClassColorInNameplate", mod.db.profile.enemy and 1 or 0)
end
-- functions ###################################################################
function mod:SetClassColour(frame, cc)
	frame.name.class_coloured = true
	frame.name:SetTextColor(cc.r, cc.g, cc.b)
end
-- message handlers ############################################################
function mod:GUIDAssumed(msg, f)
	if not f.guid then
		return
	end
	local class = select(2, GetPlayerInfoByGUID(f.guid))
	local cc = class and cc_table[class]
	if not cc then
		return
	end

	if f.friend and f.player then
		self:SetClassColour(f, cc)
	elseif not f.friend and self.db.profile.enemy then
		-- hostile player: force a health colour reparse. Now that the guid
		-- is known, the layout resolves the class colour via
		-- addon:GetHostileClassColour — hostile CoA-class plates are not
		-- class-coloured by the client, so the default UI colour is wrong.
		f.health.reset = true
		f:SetHealthColour()
	end
end
function mod:PostShow(msg, f)
	if not (f.friend and f.player) then
		return
	end
	-- a friendly player; make their name slightly gray
	-- will be overwritten when GUIDStored/Assumed fires
	f.name:SetTextColor(.7, .7, .7)
end
function mod:PostHide(msg, f)
	f.name.class_coloured = nil
	f.name:SetTextColor(1, 1, 1, 1)
end
-- config changed hooks ########################################################
mod:AddConfigChanged(
	"friendly",
	function(v)
		if v then
			mod:Enable()
		else
			mod:Disable()
		end
	end,
	function(f, v)
		if v then
			mod:PostShow(nil, f)
		else
			mod:PostHide(nil, f)
		end
	end
)
mod:AddConfigChanged("enemy", function(v) SetCVars() end)
-- config hooks ################################################################
function mod:GetOptions()
	return {
		friendly = {
			type = "toggle",
			name = L["Class colour friendly player names"],
			desc = L["Class colour the names of friendly players and dim the names of friendly players with no class information. Note that friendly players will only become class coloured once you mouse over their frames, at which point their class will be cached."],
			width = "double",
			order = 10
		},
		enemy = {
			type = "toggle",
			name = L["Class colour hostile players' health bars"],
			desc = L["Class colour the health bars of hostile players, where they are attackable. Based on the default interface option, with the class resolved from the player's GUID for classes the client does not colour itself (CoA custom classes)."],
			width = "double",
			order = 20
		}
	}
end
function mod:OnInitialize()
	cc_table = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
	self.db = addon.db:RegisterNamespace(self.moduleName, {profile = {friendly = true, enemy = true}})

	addon:InitModuleOptions(self)
	self:SetEnabledState(self.db.profile.friendly)

	-- handle default interface cvars & checkboxes
	-- The CoA client's reworked Settings panel does not expose the legacy
	-- InterfaceOptionsCombatPanel / NameplateClassColors checkbox, so guard
	-- every access to avoid indexing a nil global.
	if InterfaceOptionsCombatPanel then
		InterfaceOptionsCombatPanel:HookScript("OnShow", function()
			if InterfaceOptionsCombatPanelNameplateClassColors then
				InterfaceOptionsCombatPanelNameplateClassColors:Disable()
				InterfaceOptionsCombatPanelNameplateClassColors:SetChecked(mod.db.profile.enemy)
				InterfaceOptionsCombatPanelNameplateClassColors.Enable = function() return end
			end
		end)
	end
	if InterfaceOptionsFrame then
		InterfaceOptionsFrame:HookScript("OnHide", function() SetCVars() end)
	end
	SetCVars()
end
function mod:OnEnable()
	self:RegisterMessage("KuiNameplates_GUIDAssumed", "GUIDAssumed")
	self:RegisterMessage("KuiNameplates_GUIDStored", "GUIDAssumed")
	self:RegisterMessage("KuiNameplates_PostShow", "PostShow")
	self:RegisterMessage("KuiNameplates_PostHide", "PostHide")
end
function mod:OnDisable()
	self:UnregisterMessage("KuiNameplates_GUIDAssumed")
	self:UnregisterMessage("KuiNameplates_GUIDStored")
	self:UnregisterMessage("KuiNameplates_PostShow")
	self:UnregisterMessage("KuiNameplates_PostHide")
end