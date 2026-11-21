--!strict
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelData = require(ReplicatedStorage:WaitForChild("AngryBirds"):WaitForChild("LevelData"))

export type UICallbacks = {
	onPlay: () -> (),
	onSelectLevel: (number) -> (),
	onRestart: () -> (),
	onMainMenu: () -> (),
	onNextLevel: () -> (),
}

local UIController = {}
UIController.__index = UIController

local function addCorner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function addStroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function makeButton(props: {
	name: string,
	text: string,
	size: UDim2,
	pos: UDim2?,
	bgColor: Color3,
	strokeColor: Color3,
	textSize: number,
	parent: Instance,
}): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = props.name
	btn.Text = props.text
	btn.Size = props.size
	if props.pos then
		btn.Position = props.pos
	end
	btn.BackgroundColor3 = props.bgColor
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = props.textSize
	btn.TextWrapped = true
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Parent = props.parent
	addCorner(btn, 12)
	addStroke(btn, props.strokeColor, 2.5)
	return btn
end

function UIController.new(parentContainer: Instance, callbacks: UICallbacks)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AngryBirdsUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 10
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = parentContainer

	local self = setmetatable({
		_callbacks = callbacks,
		_screenGui = screenGui,
		_lastProgression = nil :: any,
		_modalMode = "None" :: "None" | "Win" | "Lose",
		_levelButtons = {} :: { TextButton },
		_mainPanel = nil :: Frame,
		_hudPanel = nil :: Frame,
		_modal = nil :: Frame,
		_levelLabel = nil :: TextLabel,
		_birdsLabel = nil :: TextLabel,
		_scoreLabel = nil :: TextLabel,
		_modalTitle = nil :: TextLabel,
		_modalSubtitle = nil :: TextLabel,
		_primaryBtn = nil :: TextButton,
		_secondaryBtn = nil :: TextButton,
	}, UIController)

	self:_buildMainMenu(screenGui)
	self:_buildHud(screenGui)
	self:_buildResultModal(screenGui)

	self._mainPanel.Visible = false
	self._hudPanel.Visible = false
	self._modal.Visible = false

	return self
end

function UIController:_buildMainMenu(screenGui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = "MainMenuPanel"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(16, 36, 52)
	overlay.BackgroundTransparency = 0.55
	overlay.BorderSizePixel = 0
	overlay.Active = true
	overlay.Parent = screenGui
	self._mainPanel = overlay

	local card = Instance.new("Frame")
	card.Name = "MenuCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(540, 400)
	card.BackgroundColor3 = Color3.fromRGB(252, 244, 224)
	card.BorderSizePixel = 0
	card.Parent = overlay
	addCorner(card, 22)
	addStroke(card, Color3.fromRGB(115, 72, 34), 4)

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
	title.Size = UDim2.new(1, -32, 0, 62)
	title.Position = UDim2.fromOffset(16, 20)
	title.BackgroundTransparency = 1
	title.Text = "ANGRY BIRDS"
	title.TextColor3 = Color3.fromRGB(215, 38, 38)
	title.TextStrokeColor3 = Color3.fromRGB(64, 18, 12)
	title.TextStrokeTransparency = 0.2
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 50
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "SubtitleLabel"
	subtitle.Size = UDim2.new(1, -32, 0, 26)
	subtitle.Position = UDim2.fromOffset(16, 80)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "2D Prototype"
	subtitle.TextColor3 = Color3.fromRGB(115, 76, 40)
	subtitle.Font = Enum.Font.GothamBold
	subtitle.TextSize = 18
	subtitle.Parent = card

	local playBtn = makeButton({
		name = "PlayButton",
		text = "PLAY",
		size = UDim2.fromOffset(240, 58),
		pos = UDim2.new(0.5, -120, 0, 122),
		bgColor = Color3.fromRGB(78, 184, 58),
		strokeColor = Color3.fromRGB(44, 118, 32),
		textSize = 28,
		parent = card,
	})
	playBtn.MouseButton1Click:Connect(function()
		self._callbacks.onPlay()
	end)

	local selectHdr = Instance.new("TextLabel")
	selectHdr.Name = "LevelSelectHeader"
	selectHdr.Size = UDim2.new(1, -32, 0, 26)
	selectHdr.Position = UDim2.fromOffset(16, 202)
	selectHdr.BackgroundTransparency = 1
	selectHdr.Text = "Select Level"
	selectHdr.TextColor3 = Color3.fromRGB(92, 62, 34)
	selectHdr.Font = Enum.Font.GothamBold
	selectHdr.TextSize = 17
	selectHdr.Parent = card

	local row = Instance.new("Frame")
	row.Name = "LevelButtonsRow"
	row.Size = UDim2.new(1, -48, 0, 108)
	row.Position = UDim2.fromOffset(24, 236)
	row.BackgroundTransparency = 1
	row.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.Parent = row

	local count = LevelData.getCount()
	for i = 1, count do
		local lvlBtn = makeButton({
			name = "LevelBtn" .. tostring(i),
			text = "Level " .. tostring(i),
			size = UDim2.fromOffset(152, 98),
			bgColor = Color3.fromRGB(64, 152, 224),
			strokeColor = Color3.fromRGB(38, 96, 150),
			textSize = 19,
			parent = row,
		})
		lvlBtn.MouseButton1Click:Connect(function()
			if not lvlBtn.Interactable then
				return
			end
			if self._lastProgression and not self._lastProgression:isUnlocked(i) then
				return
			end
			self._callbacks.onSelectLevel(i)
		end)
		table.insert(self._levelButtons, lvlBtn)
	end

	local hint = Instance.new("TextLabel")
	hint.Name = "ControlsHint"
	hint.Size = UDim2.new(1, -32, 0, 22)
	hint.Position = UDim2.new(0, 16, 1, -34)
	hint.BackgroundTransparency = 1
	hint.Text = "Drag bird back with mouse & release • Cancel: Right-Click / Esc"
	hint.TextColor3 = Color3.fromRGB(128, 98, 66)
	hint.Font = Enum.Font.GothamMedium
	hint.TextSize = 13
	hint.Parent = card
end

function UIController:_buildHud(screenGui: ScreenGui)
	local topLeftInset = GuiService:GetGuiInset()
	local topOffset = math.max(62, math.ceil(topLeftInset.Y) + 6)

	local hud = Instance.new("Frame")
	hud.Name = "HudPanel"
	hud.Size = UDim2.new(1, 0, 0, 64)
	hud.Position = UDim2.fromOffset(0, topOffset)
	hud.BackgroundTransparency = 1
	hud.Active = false
	hud.Parent = screenGui
	self._hudPanel = hud

	local menuBtn = makeButton({
		name = "MenuBtn",
		text = "Main Menu",
		size = UDim2.fromOffset(118, 42),
		pos = UDim2.fromOffset(16, 14),
		bgColor = Color3.fromRGB(224, 134, 42),
		strokeColor = Color3.fromRGB(142, 78, 18),
		textSize = 18,
		parent = hud,
	})
	menuBtn.MouseButton1Click:Connect(function()
		self._callbacks.onMainMenu()
	end)

	local restartBtn = makeButton({
		name = "RestartBtn",
		text = "Restart",
		size = UDim2.fromOffset(96, 42),
		pos = UDim2.fromOffset(146, 14),
		bgColor = Color3.fromRGB(56, 148, 224),
		strokeColor = Color3.fromRGB(30, 94, 152),
		textSize = 18,
		parent = hud,
	})
	restartBtn.MouseButton1Click:Connect(function()
		self._callbacks.onRestart()
	end)

	local centerPill = Instance.new("Frame")
	centerPill.Name = "CenterPill"
	centerPill.AnchorPoint = Vector2.new(0.5, 0)
	centerPill.Position = UDim2.new(0.5, 0, 0, 12)
	centerPill.Size = UDim2.fromOffset(386, 46)
	centerPill.BackgroundColor3 = Color3.fromRGB(26, 38, 48)
	centerPill.BackgroundTransparency = 0.22
	centerPill.BorderSizePixel = 0
	centerPill.Parent = hud
	addCorner(centerPill, 14)
	addStroke(centerPill, Color3.fromRGB(255, 255, 255), 1.5)

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(1, -128, 1, 0)
	levelLabel.Position = UDim2.fromOffset(12, 0)
	levelLabel.BackgroundTransparency = 1
	levelLabel.Text = "Level 1 / 3"
	levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextSize = 16
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.TextTruncate = Enum.TextTruncate.AtEnd
	levelLabel.Parent = centerPill
	self._levelLabel = levelLabel

	local birdsBadge = Instance.new("Frame")
	birdsBadge.Name = "BirdsBadge"
	birdsBadge.AnchorPoint = Vector2.new(1, 0.5)
	birdsBadge.Position = UDim2.new(1, -8, 0.5, 0)
	birdsBadge.Size = UDim2.fromOffset(104, 32)
	birdsBadge.BackgroundColor3 = Color3.fromRGB(215, 42, 42)
	birdsBadge.BorderSizePixel = 0
	birdsBadge.Parent = centerPill
	addCorner(birdsBadge, 10)

	local birdsLabel = Instance.new("TextLabel")
	birdsLabel.Name = "BirdsLabel"
	birdsLabel.Size = UDim2.fromScale(1, 1)
	birdsLabel.BackgroundTransparency = 1
	birdsLabel.Text = "Birds: 3"
	birdsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	birdsLabel.Font = Enum.Font.FredokaOne
	birdsLabel.TextSize = 17
	birdsLabel.Parent = birdsBadge
	self._birdsLabel = birdsLabel

	local scorePill = Instance.new("Frame")
	scorePill.Name = "ScorePill"
	scorePill.AnchorPoint = Vector2.new(1, 0)
	scorePill.Position = UDim2.new(1, -16, 0, 14)
	scorePill.Size = UDim2.fromOffset(168, 42)
	scorePill.BackgroundColor3 = Color3.fromRGB(26, 38, 48)
	scorePill.BackgroundTransparency = 0.22
	scorePill.BorderSizePixel = 0
	scorePill.Parent = hud
	addCorner(scorePill, 12)
	addStroke(scorePill, Color3.fromRGB(255, 214, 72), 2)

	local scoreLabel = Instance.new("TextLabel")
	scoreLabel.Name = "ScoreLabel"
	scoreLabel.Size = UDim2.new(1, -16, 1, 0)
	scoreLabel.Position = UDim2.fromOffset(8, 0)
	scoreLabel.BackgroundTransparency = 1
	scoreLabel.Text = "Score: 0"
	scoreLabel.TextColor3 = Color3.fromRGB(255, 224, 96)
	scoreLabel.Font = Enum.Font.FredokaOne
	scoreLabel.TextSize = 20
	scoreLabel.Parent = scorePill
	self._scoreLabel = scoreLabel
end

function UIController:_buildResultModal(screenGui: ScreenGui)
	local modal = Instance.new("Frame")
	modal.Name = "ResultModal"
	modal.Size = UDim2.fromScale(1, 1)
	modal.BackgroundColor3 = Color3.fromRGB(10, 18, 26)
	modal.BackgroundTransparency = 0.45
	modal.BorderSizePixel = 0
	modal.Active = true
	modal.ZIndex = 20
	modal.Parent = screenGui
	self._modal = modal

	local card = Instance.new("Frame")
	card.Name = "ModalCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(450, 290)
	card.BackgroundColor3 = Color3.fromRGB(252, 244, 224)
	card.BorderSizePixel = 0
	card.Parent = modal
	addCorner(card, 22)
	addStroke(card, Color3.fromRGB(115, 72, 34), 4)

	local modalTitle = Instance.new("TextLabel")
	modalTitle.Name = "ModalTitle"
	modalTitle.Size = UDim2.new(1, -32, 0, 56)
	modalTitle.Position = UDim2.fromOffset(16, 22)
	modalTitle.BackgroundTransparency = 1
	modalTitle.Text = "Level Complete!"
	modalTitle.TextColor3 = Color3.fromRGB(58, 152, 42)
	modalTitle.Font = Enum.Font.FredokaOne
	modalTitle.TextSize = 32
	modalTitle.TextWrapped = true
	modalTitle.Parent = card
	self._modalTitle = modalTitle

	local modalSub = Instance.new("TextLabel")
	modalSub.Name = "ModalSubtitle"
	modalSub.Size = UDim2.new(1, -40, 0, 54)
	modalSub.Position = UDim2.fromOffset(20, 86)
	modalSub.BackgroundTransparency = 1
	modalSub.Text = "Score: 0"
	modalSub.TextColor3 = Color3.fromRGB(82, 56, 32)
	modalSub.Font = Enum.Font.GothamBold
	modalSub.TextSize = 19
	modalSub.TextWrapped = true
	modalSub.Parent = card
	self._modalSubtitle = modalSub

	local primaryBtn = makeButton({
		name = "PrimaryBtn",
		text = "Next Level",
		size = UDim2.fromOffset(240, 50),
		pos = UDim2.new(0.5, -120, 0, 156),
		bgColor = Color3.fromRGB(78, 184, 58),
		strokeColor = Color3.fromRGB(44, 118, 32),
		textSize = 22,
		parent = card,
	})
	primaryBtn.MouseButton1Click:Connect(function()
		if self._modalMode == "Win" then
			self._callbacks.onNextLevel()
		elseif self._modalMode == "Lose" then
			self._callbacks.onRestart()
		end
	end)
	self._primaryBtn = primaryBtn

	local bottomRow = Instance.new("Frame")
	bottomRow.Name = "BottomRow"
	bottomRow.Size = UDim2.new(1, -48, 0, 44)
	bottomRow.Position = UDim2.new(0, 24, 1, -64)
	bottomRow.BackgroundTransparency = 1
	bottomRow.Parent = card

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 14)
	rowLayout.Parent = bottomRow

	local secondaryBtn = makeButton({
		name = "SecondaryBtn",
		text = "Replay",
		size = UDim2.fromOffset(150, 42),
		bgColor = Color3.fromRGB(56, 148, 224),
		strokeColor = Color3.fromRGB(30, 94, 152),
		textSize = 18,
		parent = bottomRow,
	})
	secondaryBtn.MouseButton1Click:Connect(function()
		self._callbacks.onRestart()
	end)
	self._secondaryBtn = secondaryBtn

	local modalMenuBtn = makeButton({
		name = "ModalMenuBtn",
		text = "Main Menu",
		size = UDim2.fromOffset(150, 42),
		bgColor = Color3.fromRGB(224, 134, 42),
		strokeColor = Color3.fromRGB(142, 78, 18),
		textSize = 18,
		parent = bottomRow,
	})
	modalMenuBtn.MouseButton1Click:Connect(function()
		self._callbacks.onMainMenu()
	end)
end

function UIController:showMainMenu(progression: any)
	self._lastProgression = progression
	self._modalMode = "None"
	self._mainPanel.Visible = true
	self._hudPanel.Visible = false
	self._modal.Visible = false

	for i, btn in ipairs(self._levelButtons) do
		local unlocked = progression:isUnlocked(i)
		local completed = progression:isCompleted(i)
		local best = progression:getBestScore(i)
		local lvl = LevelData.getLevel(i)
		local lvlName = if lvl then lvl.name else ""

		btn.Interactable = unlocked
		btn.Active = unlocked
		btn.AutoButtonColor = unlocked

		if not unlocked then
			btn.Text = string.format("Level %d\n🔒", i)
			btn.BackgroundColor3 = Color3.fromRGB(145, 152, 160)
			btn.TextColor3 = Color3.fromRGB(225, 228, 232)
		elseif completed then
			btn.Text = string.format("Level %d\n✓ %d", i, best or 0)
			btn.BackgroundColor3 = Color3.fromRGB(72, 174, 88)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			btn.Text = string.format("Level %d\n%s", i, lvlName)
			btn.BackgroundColor3 = Color3.fromRGB(58, 152, 224)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

function UIController:showGameplayHud(levelIndex: number, totalLevels: number, levelName: string, birdsLeft: number, score: number)
	self._modalMode = "None"
	self._mainPanel.Visible = false
	self._hudPanel.Visible = true
	self._modal.Visible = false
	self._levelLabel.Text = string.format("Level %d / %d — %s", levelIndex, totalLevels, levelName)
	self:updateHud(birdsLeft, score)
end

function UIController:updateHud(birdsLeft: number, score: number)
	self._birdsLabel.Text = string.format("Birds: %d", math.max(0, birdsLeft))
	self._scoreLabel.Text = string.format("Score: %d", math.max(0, math.floor(score)))
end

function UIController:showWinModal(levelIndex: number, totalLevels: number, score: number, unusedBirdBonus: number)
	self._modalMode = "Win"
	self._modal.Visible = true

	local isFinal = levelIndex >= totalLevels
	self._modalTitle.Text = if isFinal then "All Levels Complete!" else "Level Complete!"
	self._modalTitle.TextColor3 = Color3.fromRGB(58, 152, 42)
	self._modalSubtitle.Text = string.format("Total Score: %d\n(Unused Bird Bonus: +%d)", math.floor(score), math.floor(unusedBirdBonus))
	self._primaryBtn.Text = if isFinal then "Play Again" else "Next Level"
	self._primaryBtn.BackgroundColor3 = Color3.fromRGB(78, 184, 58)
	self._secondaryBtn.Visible = true
end

function UIController:showLoseModal(_levelIndex: number, score: number)
	self._modalMode = "Lose"
	self._modal.Visible = true

	self._modalTitle.Text = "Level Failed"
	self._modalTitle.TextColor3 = Color3.fromRGB(205, 48, 48)
	self._modalSubtitle.Text = string.format("Out of birds!\nScore: %d", math.floor(score))
	self._primaryBtn.Text = "Try Again"
	self._primaryBtn.BackgroundColor3 = Color3.fromRGB(224, 108, 42)
	self._secondaryBtn.Visible = false
end

function UIController:hideModals()
	self._modalMode = "None"
	self._modal.Visible = false
end

function UIController:getScreenGui(): ScreenGui
	return self._screenGui
end

function UIController:destroy()
	if self._screenGui and self._screenGui.Parent then
		self._screenGui:Destroy()
	end
end

return UIController
