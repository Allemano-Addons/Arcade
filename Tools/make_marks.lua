-- Makes Allemano Arcade's mark and icon: AltBoard's mark with the blue part recoloured lime (A3E635).
--   Media/mark.tga   transparent background (the window, the Hub's list)
--   Media/icon.tga   a dark tile, for the addon list (## IconTexture)
-- Run from the AllemanoArcade folder (needs the sibling AltBoard repo):  lua Tools/make_marks.lua
local LIME = "A3E635"
local SRC = "../AltBoard/Media/wow/"

local function readf(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local function writef(p, s) local f = assert(io.open(p, "wb")) f:write(s) f:close() end
local function hex(s) return tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) end

-- kind "mark": transparent background, the base is pure blue with partial alpha at its edges.
-- kind "tile": dark tile; the base blends with the tile colour at its edges.
local function recolor(src, kind, r2, g2, b2)
	local d = readf(src)
	local idlen = d:byte(1)
	local w, h = d:byte(13) + d:byte(14) * 256, d:byte(15) + d:byte(16) * 256
	local off = 18 + idlen
	local out = { d:sub(1, off) }
	local dark = { r = 18, g = 20, b = 24 }
	for p = 0, w * h - 1 do
		local i = off + p * 4 + 1
		local b, g, r, a = d:byte(i, i + 3)
		if b - r > 25 then
			if kind == "mark" then
				r, g, b = r2, g2, b2
			else
				local t = math.min(1, math.max(0, (b - dark.b) / (255 - dark.b)))
				r = math.floor(dark.r + t * (r2 - dark.r) + 0.5)
				g = math.floor(dark.g + t * (g2 - dark.g) + 0.5)
				b = math.floor(dark.b + t * (b2 - dark.b) + 0.5)
			end
		end
		out[#out + 1] = string.char(b, g, r, a)
	end
	out[#out + 1] = d:sub(off + w * h * 4 + 1)
	return table.concat(out)
end

local r, g, b = hex(LIME)
writef("Media/mark.tga", recolor(SRC .. "mark.tga", "mark", r, g, b))
writef("Media/icon.tga", recolor(SRC .. "icon.tga", "tile", r, g, b))
print("made Media/mark.tga and Media/icon.tga in " .. LIME)
