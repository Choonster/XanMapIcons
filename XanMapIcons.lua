--This mod is heavily inspired by the Group Icons found in the Mapster Mod.
--I wanted the functionality of the group icons without having to have Mapster installed.
--Full credit where due to Hendrik "Nevcairiel" Leppkes for his addon Mapster.

----------------------
--      Config      --
----------------------

-- If true, the Battlefield Minimap's icons will be changed
local ENABLE_BATTLEFIELD_MINIMAP = true

-- If true, the World Map's icons will be changed
local ENABLE_WORLD_MAP = true

----------------------
--   End of Config  --
----------------------

local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local UnitClass = UnitClass
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitAffectingCombat = UnitAffectingCombat
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local function replaceMethod(self, frame, methodName)
	local original = frame[methodName]

	frame[methodName] = function() end

	self[methodName] = function(self, ...) original(frame, ...) end
end

------------------------------
--        Base Mixin        --
------------------------------

local Base_HookManagerMixin = {}

function Base_HookManagerMixin:OnLoad(unitPositionFrame, onUpdateFrame)
	self.unitPositionFrame = unitPositionFrame

	replaceMethod(self, unitPositionFrame, "FinalizeUnits")
	replaceMethod(self, unitPositionFrame, "UpdateTooltips")

	onUpdateFrame:HookScript("OnUpdate", function(onUpdateFrame, elapsed)
		self:OnUpdate(elapsed)
	end)
end

function Base_HookManagerMixin:OnUpdate(elapsed)
	if self:ShowPlayers() then
		-- Adapted from UpdatePlayerPositions (in WorldMapFrame.lua) and BattlefieldMinimap_OnUpdate
		local timeNow = GetTime()
		local isInRaid = IsInRaid()
		local memberCount = 0
		local unitBase

		if isInRaid then
			memberCount = MAX_RAID_MEMBERS
			unitBase = "raid"
		elseif IsInGroup() then
			memberCount = MAX_PARTY_MEMBERS
			unitBase = "party"
		end

		for i = 1, memberCount do
			local unit = unitBase..i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") then
				self:UpdateIcon(unit, isInRaid, timeNow)
			end
		end
	end

	self:FinalizeUnits()

	self:UpdateTooltips(GameTooltip)
end

function Base_HookManagerMixin:UpdateIcon(unit, isInRaid, timeNow)
	local _, class = UnitClass(unit)
	if not class then return end

	local texture, r, g, b

	if isInRaid then
		local _, _, subgroup = GetRaidRosterInfo(unit:sub(5))
		if not subgroup then return end
		texture = ("Interface\\AddOns\\XanMapIcons\\Icons\\Group%d"):format(subgroup)
	else
		texture = "Interface\\AddOns\\XanMapIcons\\Icons\\Normal"
	end

	--set colors, flash if in combat
	local t = RAID_CLASS_COLORS[class]
	if t then
		r, g, b = t.r, t.g, t.b --class color
	else
		r, g, b = 0.8, 0.8, 0.8 --grey for default
	end

	if (GetTime() % 1 < 0.5) then
		if UnitAffectingCombat(unit) then
			r, g, b = 0.8, 0, 0 --red flash, unit in combat
		elseif UnitIsDeadOrGhost(unit) then
			r, g, b = 0.2, 0.2, 0.2 --grey for dead units
		elseif GetIsPVPInactive(unit, timeNow) then
			r, g, b = 0.5, 0.2, 0.8 --purple for inactives
		end
	end

	local groupMemberSize = self:GetGroupMemberSize()

	self.unitPositionFrame:AddUnit(unit, texture, groupMemberSize, groupMemberSize, r, g, b, 1)
end

-- Implementations that extend Base_HookManagerMixin must provide the following methods:
-- :ShowPlayers()
-- :GetGroupMemberSize()

------------------------------
--      World Map Mixin     --
------------------------------

local WorldMap_HookManagerMixin = CreateFromMixins(Base_HookManagerMixin)

function WorldMap_HookManagerMixin:OnLoad()
	Base_HookManagerMixin.OnLoad(self, WorldMapUnitPositionFrame, WorldMapButton)
end

function WorldMap_HookManagerMixin:ShowPlayers()
	return true
end

function WorldMap_HookManagerMixin:GetGroupMemberSize()
	return self.unitPositionFrame:GetGroupMemberSize()
end

local function CreateWorldMap_HookManager()
	local hookManager = CreateFromMixins(WorldMap_HookManagerMixin)
	hookManager:OnLoad()
	return hookManager
end

-------------------------------
-- Battlefield Minimap Mixin --
-------------------------------

local BattlefieldMinimap_HookManagerMixin = CreateFromMixins(Base_HookManagerMixin)

function BattlefieldMinimap_HookManagerMixin:OnLoad()
	Base_HookManagerMixin.OnLoad(self, BattlefieldMinimapUnitPositionFrame, BattlefieldMinimap)
end

function BattlefieldMinimap_HookManagerMixin:ShowPlayers()
	return BattlefieldMinimapOptions.showPlayers
end

function BattlefieldMinimap_HookManagerMixin:GetGroupMemberSize()
	return 8
end

local function CreateBattlefieldMinimap_HookManager()
	local hookManager = CreateFromMixins(BattlefieldMinimap_HookManagerMixin)
	hookManager:OnLoad()
	return hookManager
end

----------------------
--  Initialisation  --
----------------------

local f = CreateFrame("frame","XanMapIcons",UIParent)
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)

local WorldMap_HookManager, BattlefieldMinimap_HookManager

function f:PLAYER_LOGIN()
	if ENABLE_WORLD_MAP then
		WorldMap_HookManager = CreateWorldMap_HookManager()
	end

	if ENABLE_BATTLEFIELD_MINIMAP then
		if not IsAddOnLoaded("Blizzard_BattlefieldMinimap") then
			self:RegisterEvent("ADDON_LOADED")
		else
			BattlefieldMinimap_HookManager = CreateBattlefieldMinimap_HookManager()
		end
	end

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil

	local ver = GetAddOnMetadata("XanMapIcons","Version") or "1.0"
	DEFAULT_CHAT_FRAME:AddMessage(("|cFF99CC33%s|r [v|cFFDF2B2B%s|r] Loaded"):format("XanMapIcons", ver or "1.0"))
end

function f:ADDON_LOADED(event, addon)
	if addon == "Blizzard_BattlefieldMinimap" then
		BattlefieldMinimap_HookManager = CreateBattlefieldMinimap_HookManager()
		self:UnregisterEvent("ADDON_LOADED")
	end
end

if IsLoggedIn() then f:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end
