-- Window: the Arcade window. A title bar with the mark and a breadcrumb ("Allemano Arcade > Hangman"), the games to
-- choose from on the home page, and the view of the game that is open. Games build their view the first time they are
-- opened (ARC.RegisterGame in Core.lua).
local _, ARC = ...

local UI = ARC.UI
local Window = {}
ARC.Window = Window

local WIDTH, HEIGHT = 900, 640
local HEADER_H = 52
local CARD_W, CARD_H, CARD_GAP = 410, 118, 20

local frame, content, home
local views = {}   -- game id -> { frame, OnShow, OnHide }
local current      -- the open game's id, or nil for the home page
local crumb, crumbSep, crumbGame

local function savePosition()
	if not ARC.db then return end
	local point, _, relPoint, x, y = frame:GetPoint()
	ARC.db.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function restorePosition()
	frame:ClearAllPoints()
	local pos = ARC.db and ARC.db.window
	if pos and pos.point then
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	end
end

local function findGame(id)
	for _, g in ipairs(ARC.games) do
		if g.id == id then return g end
	end
end

-- ---------------------------------------------------------------------------
-- The home page: a card per game
-- ---------------------------------------------------------------------------
local function buildCard(parent, game, index)
	local card = CreateFrame("Frame", nil, parent)
	card:SetSize(CARD_W, CARD_H)
	local col, row = (index - 1) % 2, math.floor((index - 1) / 2)
	card:SetPoint("TOPLEFT", parent, "TOPLEFT", 20 + col * (CARD_W + CARD_GAP), -(20 + row * (CARD_H + CARD_GAP)))
	UI.Surface(card, "field", 1, UI.radius.panel)
	card.bar = UI.Fill(card, game.soon and "line" or "accent", 1)
	card.bar:SetPoint("TOPLEFT", 16, -18)
	card.bar:SetSize(3, 18)
	UI.Round(card.bar, 1)
	card.name = UI.Text(card, 16, game.soon and "textDim" or "text")
	card.name:SetPoint("LEFT", card.bar, "RIGHT", 10, 0)
	card.name:SetText(game.name)
	card.blurb = UI.Text(card, 12, "textDim")
	card.blurb:SetPoint("TOPLEFT", 20, -48)
	card.blurb:SetPoint("RIGHT", card, "RIGHT", -20, 0)
	card.blurb:SetWordWrap(true)
	card.blurb:SetText(game.blurb or "")
	if game.soon then
		card.tag = UI.Text(card, 12, "textFaint")
		card.tag:SetPoint("BOTTOMLEFT", 20, 16)
		card.tag:SetText("Coming soon")
	else
		card.tag = UI.Text(card, 11, "textFaint")
		card.tag:SetPoint("BOTTOMLEFT", 20, 18)
		card.tag:SetText(game.tag or "")
		card.play = UI.Button(card, "Play", "accent", function() Window.Open(game.id) end, 90)
		card.play:SetPoint("BOTTOMRIGHT", -16, 14)
	end
	return card
end

local function buildHome(parent)
	home = CreateFrame("Frame", nil, parent)
	home:SetAllPoints()
	for i, game in ipairs(ARC.games) do buildCard(home, game, i) end
end

-- ---------------------------------------------------------------------------
-- The frame
-- ---------------------------------------------------------------------------
local function setCrumb(game)
	crumbSep:SetShown(game ~= nil)
	crumbGame:SetShown(game ~= nil)
	if game then crumbGame:SetText(game.name) end
end

local function build()
	frame = CreateFrame("Frame", "AllemanoArcadeFrame", UIParent)
	table.insert(UISpecialFrames, "AllemanoArcadeFrame") -- Esc closes it
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetSize(WIDTH, HEIGHT)
	UI.Surface(frame, "window", 0.98, UI.radius.panel)

	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(HEADER_H)
	UI.Line(bar, "bottom", "line")
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() frame:StartMoving() end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		savePosition()
	end)

	local logo = bar:CreateTexture(nil, "ARTWORK")
	logo:SetSize(26, 22)
	logo:SetPoint("LEFT", 18, 0)
	if logo:SetTexture(UI.MARK) == false then logo:SetColorTexture(UI.Color("accent")) end

	-- "Allemano Arcade" is a button back to the games; the game's name follows it.
	crumb = CreateFrame("Button", nil, bar)
	crumb.text = UI.Text(crumb, 15, "text")
	crumb.text:SetPoint("LEFT")
	crumb.text:SetText("ALLEMANO ARCADE")
	crumb:SetPoint("LEFT", logo, "RIGHT", 12, 0)
	crumb:SetSize((crumb.text:GetStringWidth() or 150) + 2, 24)
	crumb:SetScript("OnClick", function() Window.Home() end)
	crumb:SetScript("OnEnter", function(self) self.text:SetTextColor(UI.Color("accent")) end)
	crumb:SetScript("OnLeave", function(self) self.text:SetTextColor(UI.Color("text")) end)
	crumbSep = UI.Text(bar, 15, "textFaint")
	crumbSep:SetPoint("LEFT", crumb, "RIGHT", 10, 0)
	crumbSep:SetText(">")
	crumbGame = UI.Text(bar, 15, "textDim")
	crumbGame:SetPoint("LEFT", crumbSep, "RIGHT", 10, 0)

	local close = UI.CloseButton(bar, function() Window.Hide() end)
	close:SetPoint("RIGHT", -14, 0)
	local version = UI.Text(bar, 11, "textFaint")
	version:SetPoint("RIGHT", close, "LEFT", -14, 0)
	version:SetText("v" .. tostring(ARC.version))

	content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 1, -HEADER_H - 1)
	content:SetPoint("BOTTOMRIGHT", -1, 1)
	frame.content = content

	buildHome(content)
	setCrumb(nil)
	restorePosition()
	frame:Hide()
end

local function ensure()
	if not frame then build() end
end

-- ---------------------------------------------------------------------------
-- Public
-- ---------------------------------------------------------------------------
function Window.Home()
	ensure()
	if current and views[current] then
		local v = views[current]
		if v.OnHide then v.OnHide() end
		v.frame:Hide()
	end
	current = nil
	home:Show()
	setCrumb(nil)
	UI.CloseMenu()
end

-- Opens a game's view (builds it the first time).
function Window.Open(id)
	local game = findGame(id)
	if not game or game.soon then return false end
	ensure()
	UI.CloseMenu()
	if current and current ~= id and views[current] then
		if views[current].OnHide then views[current].OnHide() end
		views[current].frame:Hide()
	end
	if not views[id] then
		views[id] = game.view(content)
		views[id].frame:SetAllPoints(content)
	end
	home:Hide()
	current = id
	views[id].frame:Show()
	if views[id].OnShow then views[id].OnShow() end
	setCrumb(game)
	frame:Show()
	return true
end

function Window.Show()
	ensure()
	frame:Show()
end

function Window.Hide()
	if frame then
		UI.CloseMenu()
		frame:Hide()
	end
end

function Window.Toggle()
	ensure()
	if frame:IsShown() then Window.Hide() else frame:Show() end
end

function Window.IsShown() return frame ~= nil and frame:IsShown() end
function Window.Current() return current end
function Window.Frame() return frame end
