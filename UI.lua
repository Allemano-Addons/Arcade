-- UI: the Allemano look for Arcade's windows, on its own (Arcade needs no other addon): the palette (lime for Arcade),
-- flat fills, lines, borders and rounded corners (the same technique as the Hub, AltBoard and Hush's Allemano
-- theme), text, buttons, a small choice list and a tooltip. No Blizzard textures: WoW Forever refuses or
-- restyles them.
local addonName, ARC = ...

local UI = {}
ARC.UI = UI

local function hex(s)
	return tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255
end
UI.Hex = hex

UI.LIME = "A3E635"

UI.colors = {
	window    = { hex("121418") },
	sidebar   = { hex("0E1013") },
	field     = { hex("181B20") },
	selected  = { hex("1F232A") },
	line      = { hex("262A31") },
	text      = { hex("ECEDEF") },
	textDim   = { hex("9098A1") },
	textFaint = { hex("6E757E") },
	good      = { hex("3FC77F") },
	warn      = { hex("E8A33D") },
	bad       = { hex("E0564F") },
	accent    = { hex(UI.LIME) },
	accentDim = { hex("3B4A1C") }, -- lime on a dark ground: a key that was guessed right
	badDim    = { hex("4A2326") }, -- red on a dark ground: a key that was guessed wrong
}
UI.radius = { control = 6, panel = 10, small = 4 }

function UI.Color(key)
	local c = UI.colors[key] or UI.colors.text
	return c[1], c[2], c[3]
end

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
UI.MEDIA = MEDIA
UI.MARK = MEDIA .. "mark"

-- ---------------------------------------------------------------------------
-- Fonts. Font files in addon folders are refused on WoW Forever (only the game's fonts and the ones other addons
-- register with LibSharedMedia work), so: Expressway when EllesmereUI registered it, else the game's font.
-- ---------------------------------------------------------------------------
local FALLBACK = "Fonts\\FRIZQT__.TTF"
local WANTED_FONT = "Expressway"

local function normalize(p) return p and strlower((p:gsub("/", "\\"))) or "" end

local probe
local function loads(path)
	if not path then return false end
	probe = probe or UIParent:CreateFontString(nil, "BACKGROUND")
	probe:SetFont(FALLBACK, 12, "")
	local ok = probe:SetFont(path, 12, "")
	if ok == nil then ok = normalize(probe:GetFont()) == normalize(path) end
	return ok and true or false
end

local fontPath
function UI.FontPath()
	if fontPath then return fontPath end
	local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
	local path = lsm and lsm:IsValid("font", WANTED_FONT) and lsm:Fetch("font", WANTED_FONT) or nil
	fontPath = (path and loads(path)) and path or FALLBACK
	return fontPath
end

-- One physical pixel in UI units, so 1 px lines stay sharp at any UI scale.
function UI.Pixel(frame)
	local physH = 1080
	if GetPhysicalScreenSize then
		local _, h = GetPhysicalScreenSize()
		if h and h > 0 then physH = h end
	end
	local scale = (frame or UIParent):GetEffectiveScale()
	return 768 / physH / ((scale and scale > 0) and scale or 1)
end

-- ---------------------------------------------------------------------------
-- Fills, lines, borders, rounded corners
-- ---------------------------------------------------------------------------
local pixelItems = {}
local function applyPixel(item)
	local px = UI.Pixel(item.frame)
	if item.axis == "h" then item.tex:SetHeight(px * item.n) else item.tex:SetWidth(px * item.n) end
end

function UI.PixelSize(tex, frame, axis, n)
	local item = { tex = tex, frame = frame, axis = axis, n = n or 1 }
	pixelItems[#pixelItems + 1] = item
	applyPixel(item)
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:SetScript("OnEvent", function()
	for i = 1, #pixelItems do applyPixel(pixelItems[i]) end
end)

function UI.Fill(frame, colorKey, alpha, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	local r, g, b = UI.Color(colorKey)
	t:SetColorTexture(r, g, b, alpha or 1)
	t.cbColor = { r, g, b, alpha or 1 } -- read by UI.Round
	return t
end

function UI.Line(frame, side, colorKey, layer)
	local t = UI.Fill(frame, colorKey or "line", 1, layer or "BORDER")
	if side == "top" or side == "bottom" then
		local p = side == "top" and "TOP" or "BOTTOM"
		t:SetPoint(p .. "LEFT")
		t:SetPoint(p .. "RIGHT")
		UI.PixelSize(t, frame, "h")
	else
		local p = side == "left" and "LEFT" or "RIGHT"
		t:SetPoint("TOP" .. p)
		t:SetPoint("BOTTOM" .. p)
		UI.PixelSize(t, frame, "w")
	end
	return t
end

-- 1 px border. Recolour with border:SetColor(r, g, b, a) (also after UI.RoundBorder).
local SIDES = { "top", "bottom", "left", "right" }
local borderMethods = {}
function borderMethods:SetColor(r, g, b, a)
	self.color = { r, g, b, a or 1 }
	for _, side in ipairs(SIDES) do self[side]:SetColorTexture(r, g, b, a or 1) end
end

function UI.Border(frame, colorKey)
	local b = setmetatable({}, { __index = borderMethods })
	for _, side in ipairs(SIDES) do b[side] = UI.Line(frame, side, colorKey) end
	local r, g, bl = UI.Color(colorKey or "line")
	b.color = { r, g, bl, 1 }
	return b
end

local ROUND = MEDIA .. "ui\\round"
local QUADS = { -- corner point, texcoords of that quarter of the circle
	{ "TOPLEFT", 0, 0.5, 0, 0.5 }, { "TOPRIGHT", 0.5, 1, 0, 0.5 },
	{ "BOTTOMLEFT", 0, 0.5, 0.5, 1 }, { "BOTTOMRIGHT", 0.5, 1, 0.5, 1 },
}
local RING_SIZES = { 4, 6, 8, 10 }

local function ringFile(radius)
	local best = RING_SIZES[1]
	for _, s in ipairs(RING_SIZES) do
		if math.abs(s - radius) < math.abs(best - radius) then best = s end
	end
	return MEDIA .. "ui\\ring" .. best
end

-- Largest radius that fits the current size (tiny frames get smaller corners).
local function fitRadius(radius, w, h)
	return max(0, min(radius, floor(min(w or 0, h or 0) / 2)))
end

-- Turns a flat texture into a rounded rectangle. The same methods keep working (SetColorTexture, SetAlpha, Show/Hide,
-- SetPoint ...). If the corner pictures do not load the corners are square.
function UI.Round(tex, radius)
	if not tex or tex.round then return tex end
	radius = radius or UI.radius.control
	local parent = tex:GetParent()
	local layer, sub = tex:GetDrawLayer()
	local R = {
		color = tex.cbColor and { unpack(tex.cbColor) } or { 1, 1, 1, 1 },
		alpha = tex:GetAlpha(), shown = tex:IsShown(), corners = {}, rects = {}, parts = {},
	}
	-- An invisible frame carries the geometry; the pieces are textures on the parent, so they keep the draw layer.
	local anchor = CreateFrame("Frame", nil, parent)
	anchor:SetSize(tex:GetSize())
	for i = 1, tex:GetNumPoints() do anchor:SetPoint(tex:GetPoint(i)) end
	tex:Hide()

	local function piece(list)
		local t = parent:CreateTexture(nil, layer, nil, sub)
		list[#list + 1] = t
		R.parts[#R.parts + 1] = t
		return t
	end
	for _, q in ipairs(QUADS) do
		local t = piece(R.corners)
		t.quad = q
		R.ok = t:SetTexture(ROUND) ~= false
		if R.ok then t:SetTexCoord(q[2], q[3], q[4], q[5]) end
	end
	local mid, left, right = piece(R.rects), piece(R.rects), piece(R.rects)

	local function layout()
		local r = fitRadius(radius, anchor:GetWidth(), anchor:GetHeight())
		for _, t in ipairs(R.corners) do
			t:ClearAllPoints()
			t:SetPoint(t.quad[1], anchor, t.quad[1])
			t:SetSize(max(r, 0.01), max(r, 0.01))
			t:SetShown(R.shown and r > 0)
		end
		mid:ClearAllPoints()
		mid:SetPoint("TOPLEFT", anchor, "TOPLEFT", r, 0)
		mid:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -r, 0)
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -r)
		left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", r, r)
		right:ClearAllPoints()
		right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -r, -r)
		right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, r)
		left:SetShown(R.shown and r > 0)
		right:SetShown(R.shown and r > 0)
	end
	local function paint()
		local c = R.color
		for _, t in ipairs(R.rects) do t:SetColorTexture(c[1], c[2], c[3], c[4]) end
		for _, t in ipairs(R.corners) do
			if R.ok then t:SetVertexColor(c[1], c[2], c[3], c[4]) else t:SetColorTexture(c[1], c[2], c[3], c[4]) end
		end
	end
	local function show(on)
		R.shown = on and true or false
		mid:SetShown(R.shown)
		layout()
	end
	anchor:SetScript("OnSizeChanged", layout)

	tex.round = R
	tex.SetColorTexture = function(_, r, g, b, a) R.color = { r, g, b, a or 1 } paint() end
	tex.SetVertexColor = tex.SetColorTexture
	tex.SetAlpha = function(_, a)
		R.alpha = a
		for _, t in ipairs(R.parts) do t:SetAlpha(a) end
	end
	tex.GetAlpha = function() return R.alpha end
	tex.Show = function() show(true) end
	tex.Hide = function() show(false) end
	tex.SetShown = function(_, on) show(on) end
	tex.IsShown = function() return R.shown end
	tex.SetPoint = function(_, ...) anchor:SetPoint(...) end
	tex.ClearAllPoints = function() anchor:ClearAllPoints() end
	tex.SetAllPoints = function(_, rel) anchor:SetAllPoints(rel or parent) end
	tex.SetSize = function(_, w, h) anchor:SetSize(w, h) end
	tex.SetWidth = function(_, w) anchor:SetWidth(w) end
	tex.SetHeight = function(_, h) anchor:SetHeight(h) end
	tex.GetWidth = function() return anchor:GetWidth() end
	tex.GetHeight = function() return anchor:GetHeight() end

	paint()
	tex:SetAlpha(R.alpha)
	show(R.shown)
	return tex
end

function UI.RoundBorder(b, radius)
	if not b or b.round then return b end
	radius = radius or UI.radius.control
	local frame = b.top:GetParent()
	local layer, sub = b.top:GetDrawLayer()
	for _, side in ipairs(SIDES) do b[side]:Hide() end

	local R = { corners = {}, lines = {} }
	local file = ringFile(radius)
	for _, q in ipairs(QUADS) do
		local t = frame:CreateTexture(nil, layer, nil, sub)
		t.quad = q
		R.ok = t:SetTexture(file) ~= false
		if R.ok then t:SetTexCoord(q[2], q[3], q[4], q[5]) end
		R.corners[#R.corners + 1] = t
	end
	local top, bottom = frame:CreateTexture(nil, layer, nil, sub), frame:CreateTexture(nil, layer, nil, sub)
	local left, right = frame:CreateTexture(nil, layer, nil, sub), frame:CreateTexture(nil, layer, nil, sub)
	R.lines = { top, bottom, left, right }
	UI.PixelSize(top, frame, "h")
	UI.PixelSize(bottom, frame, "h")
	UI.PixelSize(left, frame, "w")
	UI.PixelSize(right, frame, "w")

	local function layout()
		local r = fitRadius(radius, frame:GetWidth(), frame:GetHeight())
		for _, t in ipairs(R.corners) do
			t:ClearAllPoints()
			t:SetPoint(t.quad[1], frame, t.quad[1])
			t:SetSize(max(r, 0.01), max(r, 0.01))
			t:SetShown(r > 0)
		end
		top:ClearAllPoints()
		top:SetPoint("TOPLEFT", r, 0)
		top:SetPoint("TOPRIGHT", -r, 0)
		bottom:ClearAllPoints()
		bottom:SetPoint("BOTTOMLEFT", r, 0)
		bottom:SetPoint("BOTTOMRIGHT", -r, 0)
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", 0, -r)
		left:SetPoint("BOTTOMLEFT", 0, r)
		right:ClearAllPoints()
		right:SetPoint("TOPRIGHT", 0, -r)
		right:SetPoint("BOTTOMRIGHT", 0, r)
	end
	frame:HookScript("OnSizeChanged", layout)

	b.round = R
	b.SetColor = function(self, r, g, bl, a)
		self.color = { r, g, bl, a or 1 }
		for _, t in ipairs(R.lines) do t:SetColorTexture(r, g, bl, a or 1) end
		for _, t in ipairs(R.corners) do
			if R.ok then t:SetVertexColor(r, g, bl, a or 1) else t:SetColorTexture(r, g, bl, a or 1) end
		end
	end
	local c = b.color or { UI.Color("line") }
	b:SetColor(c[1], c[2], c[3], c[4] or 1)
	layout()
	return b
end

-- A rounded background filling `frame` with a rounded 1 px border. Returns bg, border.
function UI.Surface(frame, colorKey, alpha, radius, borderKey)
	local bg = UI.Fill(frame, colorKey, alpha)
	bg:SetAllPoints()
	local border = UI.Border(frame, borderKey or "line")
	UI.Round(bg, radius or UI.radius.panel)
	UI.RoundBorder(border, radius or UI.radius.panel)
	return bg, border
end

-- ---------------------------------------------------------------------------
-- Text, tooltip, buttons
-- ---------------------------------------------------------------------------
function UI.Text(parent, size, colorKey, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(UI.FontPath(), size or 12, "")
	if fs.SetShadowOffset then fs:SetShadowOffset(0, 0) end
	fs:SetTextColor(UI.Color(colorKey or "text"))
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

local tip
function UI.ShowTooltip(owner, lines)
	if not tip then
		tip = CreateFrame("Frame", nil, UIParent)
		tip:SetFrameStrata("TOOLTIP")
		tip:SetClampedToScreen(true)
		UI.Surface(tip, "field", 0.98, UI.radius.control)
		tip.text = UI.Text(tip, 11, "text")
		tip.text:SetWordWrap(true)
		tip.text:SetSpacing(3)
		tip.text:SetPoint("TOPLEFT", 8, -6)
	end
	tip.text:SetText(type(lines) == "table" and table.concat(lines, "\n") or lines)
	tip.text:SetWidth(0)
	local w = min((tip.text:GetStringWidth() or 100) + 2, 300)
	tip.text:SetWidth(w)
	tip:SetSize(w + 16, (tip.text:GetStringHeight() or 14) + 12)
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -4)
	tip:Show()
end

function UI.HideTooltip()
	if tip then tip:Hide() end
end

-- A flat button. kind: "plain", "accent" (lime) or "danger". Returns the button; b:SetEnabled2(false) greys it out
-- (named so, because SetEnabled is the game's own).
function UI.Button(parent, label, kind, onClick, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(32)
	b.kind = kind or "plain"
	b.bg = UI.Fill(b, "field", 1)
	b.bg:SetAllPoints()
	b.border = UI.Border(b, "line")
	UI.Round(b.bg, UI.radius.control)
	UI.RoundBorder(b.border, UI.radius.control)
	b.text = UI.Text(b, 13, "text")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	b.enabled = true
	local function paint(hover)
		local r, g, bl
		if not b.enabled then
			b.bg:SetColorTexture(UI.Color("field"))
			b.border:SetColor(UI.Color("line"))
			b.text:SetTextColor(UI.Color("textFaint"))
			return
		end
		if b.kind == "accent" then
			r, g, bl = UI.Color("accent")
			b.border:SetColor(r, g, bl, hover and 1 or 0.85)
			b.bg:SetColorTexture(r, g, bl, hover and 0.3 or 0.16)
		elseif b.kind == "danger" then
			r, g, bl = UI.Color("bad")
			b.border:SetColor(r, g, bl, hover and 1 or 0.7)
			b.bg:SetColorTexture(r, g, bl, hover and 0.26 or 0.12)
		else
			r, g, bl = UI.Color("text")
			b.border:SetColor(UI.Color(hover and "textFaint" or "line"))
			b.bg:SetColorTexture(UI.Color(hover and "selected" or "field"))
		end
		b.text:SetTextColor(r, g, bl)
	end
	b.Paint = paint
	function b:SetLabel(text)
		self.text:SetText(text)
		if width == nil then self:SetWidth((self.text:GetStringWidth() or 60) + 30) end
	end
	function b:SetEnabled2(on)
		self.enabled = on and true or false
		paint(false)
	end
	b:SetLabel(label)
	if width then b:SetWidth(width) end
	paint(false)
	b:SetScript("OnEnter", function() paint(true) end)
	b:SetScript("OnLeave", function() paint(false) end)
	b:SetScript("OnClick", function(self, ...) if self.enabled and onClick then onClick(self, ...) end end)
	return b
end

function UI.CloseButton(parent, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(26, 26)
	b.bg = UI.Fill(b, "selected", 1)
	b.bg:SetAllPoints()
	UI.Round(b.bg, UI.radius.small)
	b.bg:Hide()
	b.text = UI.Text(b, 14, "textDim")
	b.text:SetPoint("CENTER", 0, 1)
	b.text:SetText("x")
	b:SetScript("OnEnter", function(self)
		self.bg:Show()
		self.text:SetTextColor(UI.Color("text"))
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:Hide()
		self.text:SetTextColor(UI.Color("textDim"))
	end)
	b:SetScript("OnClick", onClick)
	return b
end

-- A panel: a rounded field with a thin border, and an optional title with a small lime bar before it.
function UI.Panel(parent, title)
	local f = CreateFrame("Frame", nil, parent)
	UI.Surface(f, "field", 1, UI.radius.panel)
	if title then
		f.bar = UI.Fill(f, "accent", 1)
		f.bar:SetPoint("TOPLEFT", 14, -16)
		f.bar:SetSize(3, 14)
		UI.Round(f.bar, 1)
		f.title = UI.Text(f, 13, "text")
		f.title:SetPoint("LEFT", f.bar, "RIGHT", 9, 0)
		f.title:SetText(title)
	end
	return f
end

-- ---------------------------------------------------------------------------
-- A choice list: a button that shows the current choice; clicking opens a short menu under it.
-- UI.Choice(parent, width, getOptions, onChange) -> button with :SetChoice(value) and :GetChoice().
-- getOptions() returns { { value, label }, ... }.
-- ---------------------------------------------------------------------------
local menu, catcher
local function closeMenu()
	if menu then menu:Hide() end
	if catcher then catcher:Hide() end
end
UI.CloseMenu = closeMenu

function UI.Choice(parent, width, getOptions, onChange)
	local b = UI.Button(parent, "", "plain", nil, width)
	b:SetHeight(36)
	b.text:ClearAllPoints()
	b.text:SetPoint("LEFT", 14, 0)
	b.text:SetPoint("RIGHT", -28, 0)
	b.text:SetJustifyH("LEFT")
	b.caret = UI.Text(b, 12, "textDim")
	b.caret:SetPoint("RIGHT", -12, 0)
	b.caret:SetText("v")
	function b:SetChoice(value)
		self.value = value
		for _, o in ipairs(getOptions()) do
			if o.value == value then self.text:SetText(o.label) end
		end
	end
	function b:GetChoice() return self.value end
	b:SetScript("OnClick", function(self)
		if menu and menu:IsShown() and menu.owner == self then closeMenu() return end
		local options = getOptions()
		if not menu then
			catcher = CreateFrame("Frame", nil, UIParent)
			catcher:SetAllPoints(UIParent)
			catcher:SetFrameStrata("DIALOG")
			catcher:EnableMouse(true)
			catcher:SetScript("OnMouseDown", closeMenu)
			menu = CreateFrame("Frame", nil, UIParent)
			menu:SetFrameStrata("FULLSCREEN_DIALOG")
			menu:SetClampedToScreen(true)
			UI.Surface(menu, "window", 0.99, UI.radius.control)
			menu.rows = {}
		end
		menu.owner = self
		menu:SetWidth(self:GetWidth())
		for i, o in ipairs(options) do
			local row = menu.rows[i]
			if not row then
				row = CreateFrame("Button", nil, menu)
				row:SetHeight(28)
				row.bg = UI.Fill(row, "selected", 1)
				row.bg:SetAllPoints()
				row.bg:Hide()
				row.text = UI.Text(row, 12, "text")
				row.text:SetPoint("LEFT", 12, 0)
				row:SetScript("OnEnter", function(r) r.bg:Show() end)
				row:SetScript("OnLeave", function(r) r.bg:Hide() end)
				menu.rows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 28)
			row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -4, -4 - (i - 1) * 28)
			row.text:SetText(o.label)
			row.text:SetTextColor(UI.Color(o.value == self.value and "accent" or "text"))
			row:SetScript("OnClick", function()
				closeMenu()
				self:SetChoice(o.value)
				if onChange then onChange(o.value) end
			end)
			row:Show()
		end
		for i = #options + 1, #menu.rows do menu.rows[i]:Hide() end
		menu:SetHeight(8 + #options * 28)
		menu:ClearAllPoints()
		menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
		catcher:Show()
		menu:Show()
	end)
	return b
end

-- A segmented switch: UI.Segment(parent, { { value, label }, ... }, onChange) -> frame with :Set(value), :Get().
function UI.Segment(parent, options, onChange)
	local s = CreateFrame("Frame", nil, parent)
	s:SetHeight(32)
	s.buttons = {}
	local x = 0
	for i, opt in ipairs(options) do
		local b = CreateFrame("Button", nil, s)
		b.value = opt.value
		b.bg = UI.Fill(b, "field", 1)
		b.bg:SetAllPoints()
		UI.Round(b.bg, UI.radius.small)
		b.text = UI.Text(b, 12, "textDim")
		b.text:SetPoint("CENTER")
		b.text:SetText(opt.label)
		local w = max(60, (b.text:GetStringWidth() or 60) + 28)
		b:SetSize(w, 32)
		b:SetPoint("LEFT", x, 0)
		x = x + w + 2
		b:SetScript("OnClick", function(self)
			s:Set(self.value)
			if onChange then onChange(self.value) end
		end)
		s.buttons[i] = b
	end
	s:SetWidth(max(1, x - 2))
	UI.RoundBorder(UI.Border(s, "line"), UI.radius.small)
	function s:Set(value)
		self.value = value
		for _, b in ipairs(self.buttons) do
			if b.value == value then
				b.bg:SetColorTexture(UI.Color("accent"))
				b.text:SetTextColor(UI.Color("sidebar"))
			else
				b.bg:SetColorTexture(UI.Color("field"))
				b.text:SetTextColor(UI.Color("textDim"))
			end
		end
	end
	function s:Get() return self.value end
	return s
end

-- A single-line text field. password = true shows dots instead of the letters (where the game can do it).
function UI.EditBox(parent, placeholder, maxLetters, password)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetHeight(36)
	box:SetAutoFocus(false)
	box:SetFont(UI.FontPath(), 14, "")
	box:SetTextColor(UI.Color("text"))
	box:SetTextInsets(12, 12, 0, 0)
	box:SetMaxLetters(maxLetters or 40)
	if password and box.SetPassword then box:SetPassword(true) end
	box.bg = UI.Fill(box, "window", 1)
	box.bg:SetAllPoints()
	box.border = UI.Border(box, "line")
	UI.Round(box.bg, UI.radius.control)
	UI.RoundBorder(box.border, UI.radius.control)
	box.placeholder = UI.Text(box, 13, "textFaint")
	box.placeholder:SetPoint("LEFT", 12, 0)
	box.placeholder:SetText(placeholder or "")
	local function refresh() box.placeholder:SetShown((box:GetText() or "") == "") end
	box:SetScript("OnTextChanged", refresh)
	box:SetScript("OnEditFocusGained", function() box.border:SetColor(UI.Color("accent")) end)
	box:SetScript("OnEditFocusLost", function() box.border:SetColor(UI.Color("line")) end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	refresh()
	return box
end
