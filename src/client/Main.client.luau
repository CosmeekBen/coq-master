-- Interface du jeu, construite entièrement en code (aucun asset requis).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil
local openTab = nil
local fighting = false

local BROWN = Color3.fromRGB(60, 40, 28)
local GREEN = Color3.fromRGB(80, 170, 80)
local GREY = Color3.fromRGB(110, 110, 110)
local ORANGE = Color3.fromRGB(230, 140, 40)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function label(parent, text, size, pos, textSize, color, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Size = size,
		Position = pos or UDim2.new(),
		Font = Enum.Font.GothamBold,
		TextSize = textSize or 18,
		TextColor3 = color or Color3.new(1, 1, 1),
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextWrapped = true,
	}, parent)
end

local function button(parent, text, color, size, pos, onClick)
	local b = new("TextButton", {
		Text = text,
		Size = size,
		Position = pos or UDim2.new(),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true,
	}, parent)
	corner(b)
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function fmt(n)
	local s = tostring(math.floor(n))
	return s:reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")
end

local function statsText(r)
	return ("❤ %d   ⚔ %d   ⚡ %d"):format(r.hp, r.atk, r.spd)
end

-- HUD ------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "CoqMasterUI", ResetOnSpawn = false, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))

local hud = new("Frame", { Size = UDim2.fromOffset(220, 70), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = BROWN, BackgroundTransparency = 0.15 }, gui)
corner(hud)
local feathersLabel = label(hud, "🪶 0", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(10, 5), 22, Color3.fromRGB(255, 225, 130))
local trophiesLabel = label(hud, "🏆 0 — Bronze", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(10, 36), 16)

local toast = label(gui, "", UDim2.fromOffset(520, 40), UDim2.new(0.5, -260, 0, 14), 20, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
toast.BackgroundTransparency = 0.2
toast.BackgroundColor3 = BROWN
toast.Visible = false
corner(toast)
local toastId = 0
local function showToast(text)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(4, function()
		if id == toastId then
			toast.Visible = false
		end
	end)
end

-- Panneau central -----------------------------------------------------------------
local panel = new("Frame", {
	Size = UDim2.fromOffset(500, 360),
	Position = UDim2.new(0.5, -250, 0.5, -200),
	BackgroundColor3 = BROWN,
	Visible = false,
}, gui)
corner(panel, 12)
local panelTitle = label(panel, "", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(14, 8), 24)
local content = new("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -56),
	Position = UDim2.fromOffset(10, 48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
}, panel)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)

local function row(height)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, height or 58), BackgroundColor3 = Color3.fromRGB(85, 60, 42) }, content)
	corner(f)
	return f
end

local function findRooster(id)
	for _, r in state.roosters do
		if r.id == id then
			return r
		end
	end
end

local tabs = {}

tabs.Boutique = function()
	for _, egg in Config.Eggs do
		local f = row()
		label(f, egg.name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 5), 18, Config.RarityColors[egg.rarity])
		label(f, ("%d clics • ❤%d-%d ⚔%d-%d ⚡%d-%d"):format(egg.taps, egg.stats.hp[1], egg.stats.hp[2], egg.stats.atk[1], egg.stats.atk[2], egg.stats.spd[1], egg.stats.spd[2]),
			UDim2.new(1, -150, 0, 22), UDim2.fromOffset(10, 31), 13, Color3.fromRGB(220, 200, 180))
		local can = state.feathers >= egg.price
		button(f, "🪶 " .. fmt(egg.price), can and GREEN or GREY, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), function()
			remotes.BuyEgg:FireServer(egg.id)
		end)
	end
	local f = row()
	label(f, ("Poule (%d/%d)"):format(state.hens, Config.MaxHens), UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 5), 18, Color3.fromRGB(255, 230, 150))
	label(f, ("+%d plume/s chacune"):format(Config.HenIncome), UDim2.new(1, -150, 0, 22), UDim2.fromOffset(10, 31), 13, Color3.fromRGB(220, 200, 180))
	if state.henPrice then
		button(f, "🪶 " .. fmt(state.henPrice), state.feathers >= state.henPrice and GREEN or GREY, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), function()
			remotes.BuyHen:FireServer()
		end)
	else
		button(f, "MAX", GREY, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18))
	end
end

tabs.Coqs = function()
	if #state.roosters == 0 then
		label(content, "Aucun coq. Achète un oeuf et casse-le en cliquant dessus !", UDim2.new(1, 0, 0, 40), nil, 16)
		return
	end
	for _, r in state.roosters do
		local f = row()
		label(f, r.name .. " • " .. r.rarity, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 5), 18, Config.RarityColors[r.rarity])
		label(f, statsText(r), UDim2.new(1, -150, 0, 22), UDim2.fromOffset(10, 31), 14, Color3.fromRGB(220, 200, 180))
		local selected = r.id == state.selected
		local id = r.id
		button(f, selected and "⭐ Choisi" or "Choisir", selected and ORANGE or GREEN, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), function()
			remotes.SelectRooster:FireServer(id)
		end)
	end
end

tabs.Combat = function()
	local league, index = Config.getLeague(state.trophies)
	local nextLeague = Config.Leagues[index + 1]
	local f = row(110)
	label(f, ("Ligue %s — %d 🏆"):format(league.name, state.trophies), UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 6), 20, Color3.fromRGB(255, 225, 130))
	label(f, nextLeague and ("Prochaine ligue : %s à %d 🏆"):format(nextLeague.name, nextLeague.min) or "Ligue maximale !", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), 14, Color3.fromRGB(220, 200, 180))
	label(f, ("Victoire : +%d 🪶  +%d 🏆   Défaite : +%d 🪶  -%d 🏆"):format(league.winFeathers, league.winTrophies, Config.LoseFeathers, league.loseTrophies), UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 58), 14)

	local mine = state.selected and findRooster(state.selected)
	local f2 = row(80)
	if mine then
		label(f2, "Ton combattant : " .. mine.name, UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 8), 18, Config.RarityColors[mine.rarity])
		label(f2, statsText(mine), UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 38), 16)
	else
		label(f2, "Aucun coq sélectionné (onglet Coqs).", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), 16)
	end
	button(content, "⚔ Lancer un combat", mine and not fighting and ORANGE or GREY, UDim2.new(1, -8, 0, 50), nil, function()
		if mine and not fighting then
			remotes.Fight:FireServer()
		end
	end)
end

local function renderPanel()
	if not openTab or not state then
		panel.Visible = false
		return
	end
	panel.Visible = true
	panelTitle.Text = openTab
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	tabs[openTab]()
end

-- Barre d'onglets
local bar = new("Frame", { Size = UDim2.fromOffset(450, 54), Position = UDim2.new(0.5, -225, 1, -70), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, bar)
for _, info in { { "Boutique", "🥚 Boutique" }, { "Coqs", "🐓 Coqs" }, { "Combat", "⚔ Combat" } } do
	local tab = info[1]
	button(bar, info[2], ORANGE, UDim2.fromOffset(140, 54), nil, function()
		openTab = openTab ~= tab and tab or nil
		renderPanel()
	end).TextSize = 20
end

local function refreshHud()
	local league = Config.getLeague(state.trophies)
	feathersLabel.Text = "🪶 " .. fmt(state.feathers)
	trophiesLabel.Text = ("🏆 %d — %s"):format(state.trophies, league.name)
end

remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	refreshHud()
	if not fighting then
		renderPanel()
	end
end)

remotes.Notify.OnClientEvent:Connect(showToast)

-- Écran de combat ----------------------------------------------------------------------
local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 20, 14), Visible = false, ZIndex = 10 }, gui)
local nameLabels, hpFills, hpTexts = {}, {}, {}
for i = 1, 2 do
	local x = i == 1 and 0.08 or 0.54
	nameLabels[i] = label(overlay, "", UDim2.fromScale(0.38, 0.08), UDim2.fromScale(x, 0.12), 26, nil, Enum.TextXAlignment.Center)
	nameLabels[i].ZIndex = 11
	local back = new("Frame", { Size = UDim2.fromScale(0.38, 0.06), Position = UDim2.fromScale(x, 0.22), BackgroundColor3 = Color3.fromRGB(70, 30, 30), ZIndex = 11 }, overlay)
	corner(back)
	hpFills[i] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = i == 1 and GREEN or Color3.fromRGB(210, 70, 60), ZIndex = 12 }, back)
	corner(hpFills[i])
	hpTexts[i] = label(back, "", UDim2.fromScale(1, 1), nil, 18, nil, Enum.TextXAlignment.Center)
	hpTexts[i].ZIndex = 13
end
local vs = label(overlay, "VS", UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.45, 0.14), 40, ORANGE, Enum.TextXAlignment.Center)
vs.ZIndex = 11
local logLabel = label(overlay, "", UDim2.fromScale(0.8, 0.3), UDim2.fromScale(0.1, 0.36), 22, nil, Enum.TextXAlignment.Center)
logLabel.ZIndex = 11
local resultLabel = label(overlay, "", UDim2.fromScale(0.8, 0.14), UDim2.fromScale(0.1, 0.68), 30, nil, Enum.TextXAlignment.Center)
resultLabel.ZIndex = 11
local closeBtn = button(overlay, "Fermer", ORANGE, UDim2.fromOffset(200, 50), UDim2.new(0.5, -100, 0.86, 0), function()
	overlay.Visible = false
	fighting = false
	if state then
		renderPanel()
	end
end)
closeBtn.ZIndex = 11
closeBtn.Visible = false

local function setHp(i, hp, maxHp, instant)
	hpTexts[i].Text = ("%d / %d"):format(hp, maxHp)
	local goal = { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) }
	if instant then
		hpFills[i].Size = goal.Size
	else
		TweenService:Create(hpFills[i], TweenInfo.new(0.15), goal):Play()
	end
end

remotes.FightResult.OnClientEvent:Connect(function(r)
	fighting = true
	overlay.Visible = true
	closeBtn.Visible = false
	resultLabel.Text = ""
	logLabel.Text = "Le combat commence !"
	local fighters = { r.a, r.b }
	for i = 1, 2 do
		nameLabels[i].Text = fighters[i].name
		nameLabels[i].TextColor3 = Config.RarityColors[fighters[i].rarity] or Color3.new(1, 1, 1)
		setHp(i, fighters[i].hp, fighters[i].hp, true)
	end

	task.spawn(function()
		local lastT = r.events[#r.events].t
		local scale = math.min(1, 12 / lastT) -- un combat dure 12 s maximum à l'écran
		local prev = 0
		task.wait(1)
		for _, e in r.events do
			task.wait((e.t - prev) * scale)
			prev = e.t
			local attacker, defender = fighters[e.attacker], fighters[3 - e.attacker]
			logLabel.Text = ("%s frappe %s : -%d%s"):format(attacker.name, defender.name, e.dmg, e.crit and " (COUP CRITIQUE !)" or "")
			setHp(1, e.hp1, r.a.hp)
			setHp(2, e.hp2, r.b.hp)
		end
		task.wait(0.6)
		local won = r.winner == 1
		resultLabel.TextColor3 = won and Color3.fromRGB(255, 225, 130) or Color3.fromRGB(230, 110, 100)
		resultLabel.Text = ("%s\n+%d 🪶   %s%d 🏆   (Ligue %s)"):format(won and "VICTOIRE !" or "DÉFAITE", r.rewards.feathers, r.rewards.trophies >= 0 and "+" or "", r.rewards.trophies, r.league)
		closeBtn.Visible = true
	end)
end)
