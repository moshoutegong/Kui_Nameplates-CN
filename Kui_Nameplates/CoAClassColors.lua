-- CoAClassColors.lua
--
-- Forwards the live client's RAID_CLASS_COLORS palette into
-- _G.CUSTOM_CLASS_COLORS so Kui_Nameplates renders Conquest-of-Azeroth
-- class names and bars correctly when the !ClassColors addon is
-- loaded.
--
-- Background
-- ----------
-- The CoA Voljin client (and the Ascension classic+ client) ship
-- Interface/SharedXML/SharedConstants.lua with all 32 class
-- file_strings populated in _G.RAID_CLASS_COLORS — 10 vanilla + HERO +
-- 21 CoA customs (BARBARIAN, WITCHDOCTOR, DEMONHUNTER, FLESHWARDEN,
-- MONK = Templar, PROPHET = Venomancer, …).
--
-- Kui_Nameplates picks its source table once in
-- Modules/ClassColours.lua:90 with
--     cc_table = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
-- and Libs/Kui/Kui.lua:56-60 has the same shape:
--     if CUSTOM_CLASS_COLORS then class = CUSTOM_CLASS_COLORS[class]
--     else                         class = RAID_CLASS_COLORS[class]
--     end
-- When !ClassColors is loaded it injects a separate
-- _G.CUSTOM_CLASS_COLORS populated from its own (vanilla-10-only)
-- defaults plus user overrides. There is *no* per-key fallback to
-- RAID_CLASS_COLORS, so on a !ClassColors-equipped client the 22 CoA
-- tokens silently miss and SetTextColor is called with a nil colour
-- (no class-coloured friendly names; nil-arg error in
-- kui.GetClassColour for the str path).
--
-- Strategy
-- --------
-- If CUSTOM_CLASS_COLORS exists at file-load time (i.e. !ClassColors
-- already loaded — Kui_Nameplates.toc declares it as an OptionalDep,
-- so it loads first when installed), copy any RAID_CLASS_COLORS entry
-- that CUSTOM_CLASS_COLORS is missing. Never overwrite —
-- !ClassColors user preferences and any other addon's earlier write
-- win.
--
-- We deliberately don't touch RAID_CLASS_COLORS itself: the client
-- already populates it, and any value we'd choose here would be a
-- guess relative to the realm-authoritative palette in
-- SharedConstants.lua.
--
-- Source of truth: _G.RAID_CLASS_COLORS at FrameXML load time
-- (Voljin/PTR realm: patch-B.MPQ → SharedXML/SharedConstants.lua).

local CCC = _G.CUSTOM_CLASS_COLORS
if type(CCC) ~= "table" then return end

local CC = _G.RAID_CLASS_COLORS
if type(CC) ~= "table" then return end

local function colorStr(r, g, b)
	return string.format("ff%02x%02x%02x", r * 255 + 0.5, g * 255 + 0.5, b * 255 + 0.5)
end

local function unpackColor(c)
	if type(c) ~= "table" then return end
	if c.GetRGB then return c:GetRGB() end
	return c.r, c.g, c.b
end

for token, src in pairs(CC) do
	if CCC[token] == nil then
		local r, g, b = unpackColor(src)
		if r and g and b then
			CCC[token] = {
				r = r, g = g, b = b,
				colorStr = colorStr(r, g, b),
			}
		end
	end
end
