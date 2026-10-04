-- Interface du jeu, construite entièrement en code (aucun asset requis).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Birds = require(Shared:WaitForChild("Birds"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local state = nil
local openTab = nil
local fighting = false

local BROWN = Color3.fromRGB(60, 40, 28)
local GREEN = Color3.fromRGB(80, 170, 80)
local GREY = Color3.fromRGB(110, 110, 110)
local ORANGE = Color3.fromRGB(230, 140, 40)
local RED = Color3.fromRGB(200, 70, 60)
local SOFT = Color3.fromRGB(220, 200, 180)

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
local gui = new("ScreenGui", { Name = "CoqMasterUI", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

local hud = new("Frame", { Size = UDim2.fromOffset(240, 76), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = BROWN, BackgroundTransparency = 0.15 }, gui)
corner(hud)
local feathersLabel = label(hud, "🪶 0", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(10, 4), 22, Color3.fromRGB(255, 225, 130))
local incomeLabel = label(hud, "", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(10, 32), 14, SOFT)
local trophiesLabel = label(hud, "🏆 0 — Bronze", UDim2.new(1, -16, 0, 24), UDim2.fromOffset(10, 50), 16)

local toast = label(gui, "", UDim2.fromOffset(560, 40), UDim2.new(0.5, -280, 0, 14), 20, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
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
	Size = UDim2.fromOffset(580, 380),
	Position = UDim2.new(0.5, -290, 0.5, -210),
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

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function row(height)
	local f = new("Frame", {
		Size = UDim2.new(1, -8, 0, height or 58),
		BackgroundColor3 = Color3.fromRGB(85, 60, 42),
		LayoutOrder = nextOrder(),
	}, content)
	corner(f)
	return f
end

local function header(text)
	local l = label(content, text, UDim2.new(1, -8, 0, 26), nil, 18, Color3.fromRGB(255, 225, 130))
	l.LayoutOrder = nextOrder()
	return l
end

local function findRooster(id)
	for _, r in state.roosters do
		if r.id == id then
			return r
		end
	end
end

local tabs = {}
local renderPanel

-- Vente avec confirmation (2e clic dans les 3 s)
local armed = {}
local function sellButton(parent, key, value, pos, onConfirm)
	local isArmed = armed[key] and os.clock() < armed[key]
	button(parent, isArmed and "Confirmer ?" or ("Vendre 🪶" .. fmt(value)), isArmed and RED or GREY, UDim2.fromOffset(110, 36), pos, function()
		if isArmed then
			armed[key] = nil
			onConfirm()
		else
			armed[key] = os.clock() + 3
			renderPanel()
			task.delay(3.1, function()
				if openTab and not fighting then
					renderPanel()
				end
			end)
		end
	end)
end

tabs["Œufs"] = function()
	label(content, ("Œufs sur ta base : %d / %d — clique dessus dans ta base pour les casser !"):format(#state.eggs, Config.MaxEggs), UDim2.new(1, -8, 0, 36), nil, 14, SOFT).LayoutOrder = nextOrder()
	for _, egg in Config.Eggs do
		local f = row()
		label(f, egg.name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 5), 18, Config.RarityColors[egg.rarity])
		label(f, ("%d clics • ❤%d-%d ⚔%d-%d ⚡%d-%d"):format(egg.taps, egg.stats.hp[1], egg.stats.hp[2], egg.stats.atk[1], egg.stats.atk[2], egg.stats.spd[1], egg.stats.spd[2]),
			UDim2.new(1, -150, 0, 22), UDim2.fromOffset(10, 31), 13, SOFT)
		button(f, "🪶 " .. fmt(egg.price), state.feathers >= egg.price and GREEN or GREY, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), function()
			remotes.BuyEgg:FireServer(egg.id)
		end)
	end
end

tabs["Poules"] = function()
	header(("Acheter une poule  (poulailler : %d / %d)"):format(#state.hens, Config.MaxHens))
	for _, hen in Config.Hens do
		local f = row()
		label(f, hen.name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 5), 18, Config.RarityColors[hen.rarity])
		label(f, ("+%s plume(s) / seconde"):format(tostring(hen.income)), UDim2.new(1, -150, 0, 22), UDim2.fromOffset(10, 31), 13, SOFT)
		button(f, "🪶 " .. fmt(hen.price), state.feathers >= hen.price and GREEN or GREY, UDim2.fromOffset(120, 36), UDim2.new(1, -130, 0.5, -18), function()
			remotes.BuyHen:FireServer(hen.id)
		end)
	end
	header("Tes poules")
	if #state.hens == 0 then
		label(content, "Aucune poule.", UDim2.new(1, -8, 0, 26), nil, 14, SOFT).LayoutOrder = nextOrder()
	end
	for _, hen in state.hens do
		local def = Config.HensById[hen.henId]
		if def then
			local f = row(50)
			label(f, def.name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(10, 3), 17, Config.RarityColors[def.rarity])
			label(f, ("+%s / s"):format(tostring(def.income)), UDim2.new(1, -150, 0, 20), UDim2.fromOffset(10, 26), 13, SOFT)
			local uid = hen.id
			sellButton(f, "H" .. uid, Config.henSellValue(def), UDim2.new(1, -120, 0.5, -18), function()
				remotes.SellHen:FireServer(uid)
			end)
		end
	end
end

tabs["Coqs"] = function()
	if #state.roosters == 0 then
		label(content, "Aucun coq. Achète un œuf et casse-le en cliquant dessus !", UDim2.new(1, -8, 0, 40), nil, 16).LayoutOrder = nextOrder()
		return
	end
	for _, r in state.roosters do
		local f = row()
		label(f, r.name .. " • " .. r.rarity, UDim2.new(1, -250, 0, 24), UDim2.fromOffset(10, 5), 18, Config.RarityColors[r.rarity])
		label(f, statsText(r), UDim2.new(1, -250, 0, 22), UDim2.fromOffset(10, 31), 14, SOFT)
		local selected = r.id == state.selected
		local id = r.id
		button(f, selected and "⭐ Choisi" or "Choisir", selected and ORANGE or GREEN, UDim2.fromOffset(100, 36), UDim2.new(1, -230, 0.5, -18), function()
			remotes.SelectRooster:FireServer(id)
		end)
		sellButton(f, "R" .. id, Config.roosterSellValue(r), UDim2.new(1, -120, 0.5, -18), function()
			remotes.SellRooster:FireServer(id)
		end)
	end
end

tabs["Combat"] = function()
	local league, index = Config.getLeague(state.trophies)
	local nextLeague = Config.Leagues[index + 1]
	local f = row(110)
	label(f, ("Ligue %s — %d 🏆"):format(league.name, state.trophies), UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 6), 20, Color3.fromRGB(255, 225, 130))
	label(f, nextLeague and ("Prochaine ligue : %s à %d 🏆"):format(nextLeague.name, nextLeague.min) or "Ligue maximale !", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), 14, SOFT)
	label(f, ("Victoire : +%d 🪶  +%d 🏆   Défaite : +%d 🪶  -%d 🏆"):format(league.winFeathers, league.winTrophies, Config.LoseFeathers, league.loseTrophies), UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 58), 14)

	local mine = state.selected and findRooster(state.selected)
	local f2 = row(80)
	if mine then
		label(f2, "Ton combattant : " .. mine.name, UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 8), 18, Config.RarityColors[mine.rarity])
		label(f2, statsText(mine), UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 38), 16)
	else
		label(f2, "Aucun coq sélectionné (onglet Coqs).", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), 16)
	end
	local b = button(content, "⚔ Lancer un combat", mine and not fighting and ORANGE or GREY, UDim2.new(1, -8, 0, 50), nil, function()
		if mine and not fighting then
			remotes.Fight:FireServer()
		end
	end)
	b.LayoutOrder = nextOrder()
end

renderPanel = function()
	if not openTab or not state then
		panel.Visible = false
		return
	end
	panel.Visible = true
	panelTitle.Text = openTab
	order = 0
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	tabs[openTab]()
end

-- Barre d'onglets
local bar = new("Frame", { Size = UDim2.fromOffset(640, 54), Position = UDim2.new(0.5, -320, 1, -70), BackgroundTransparency = 1 }, gui)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }, bar)
for _, info in { { "Œufs", "🥚 Œufs" }, { "Poules", "🐔 Poules" }, { "Coqs", "🐓 Coqs" }, { "Combat", "⚔ Combat" } } do
	local tab = info[1]
	button(bar, info[2], ORANGE, UDim2.fromOffset(150, 54), nil, function()
		openTab = openTab ~= tab and tab or nil
		renderPanel()
	end).TextSize = 20
end

local function refreshHud()
	local league = Config.getLeague(state.trophies)
	feathersLabel.Text = "🪶 " .. fmt(state.feathers)
	incomeLabel.Text = ("+%s plumes / seconde"):format(tostring(math.floor(state.income * 10 + 0.5) / 10))
	trophiesLabel.Text = ("🏆 %d — %s"):format(state.trophies, league.name)
end

remotes.State.OnClientEvent:Connect(function(newState)
	state = newState
	refreshHud()
	if not fighting then
		renderPanel()
	end
end)

-- Tick de revenu : on ne reconstruit le panneau que si un prix devient abordable
-- (le reconstruire chaque seconde ferait perdre des clics sur les boutons).
local function crossesAPrice(old, new)
	local function crossed(price)
		return old < price and new >= price
	end
	for _, egg in Config.Eggs do
		if crossed(egg.price) then
			return true
		end
	end
	for _, hen in Config.Hens do
		if crossed(hen.price) then
			return true
		end
	end
	return false
end

remotes.Feathers.OnClientEvent:Connect(function(amount)
	if not state then
		return
	end
	local old = state.feathers
	state.feathers = amount
	refreshHud()
	if not fighting and crossesAPrice(old, amount) then
		renderPanel()
	end
end)

remotes.Notify.OnClientEvent:Connect(showToast)

-- Écran de combat ----------------------------------------------------------------------
local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 20, 14), Visible = false, ZIndex = 10 }, gui)
local nameLabels, hpFills, hpTexts = {}, {}, {}
for i = 1, 2 do
	local x = i == 1 and 0.06 or 0.56
	nameLabels[i] = label(overlay, "", UDim2.fromScale(0.38, 0.06), UDim2.fromScale(x, 0.03), 26, nil, Enum.TextXAlignment.Center)
	nameLabels[i].ZIndex = 11
	local back = new("Frame", { Size = UDim2.fromScale(0.38, 0.05), Position = UDim2.fromScale(x, 0.1), BackgroundColor3 = Color3.fromRGB(70, 30, 30), ZIndex = 11 }, overlay)
	corner(back)
	hpFills[i] = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = i == 1 and GREEN or RED, ZIndex = 12 }, back)
	corner(hpFills[i])
	hpTexts[i] = label(back, "", UDim2.fromScale(1, 1), nil, 18, nil, Enum.TextXAlignment.Center)
	hpTexts[i].ZIndex = 13
end
label(overlay, "VS", UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.45, 0.05), 38, ORANGE, Enum.TextXAlignment.Center).ZIndex = 11

-- Arène 3D (ViewportFrame) : les deux coqs + tes poules en spectatrices
local viewport = new("ViewportFrame", {
	Size = UDim2.fromScale(0.9, 0.5),
	Position = UDim2.fromScale(0.05, 0.18),
	BackgroundColor3 = Color3.fromRGB(140, 195, 235),
	Ambient = Color3.fromRGB(170, 170, 170),
	LightColor = Color3.fromRGB(255, 245, 225),
	LightDirection = Vector3.new(-0.6, -1, -0.5),
	ZIndex = 11,
}, overlay)
corner(viewport, 12)
local camera = new("Camera", { FieldOfView = 45, CFrame = CFrame.lookAt(Vector3.new(0, 5.5, 15), Vector3.new(0, 3.2, 0)) }, viewport)
viewport.CurrentCamera = camera
local arena = new("Folder", { Name = "Arena" }, viewport)

local logLabel = label(overlay, "", UDim2.fromScale(0.9, 0.06), UDim2.fromScale(0.05, 0.7), 20, nil, Enum.TextXAlignment.Center)
logLabel.ZIndex = 11
local resultLabel = label(overlay, "", UDim2.fromScale(0.9, 0.12), UDim2.fromScale(0.05, 0.78), 26, nil, Enum.TextXAlignment.Center)
resultLabel.ZIndex = 11
local closeBtn = button(overlay, "Fermer", ORANGE, UDim2.fromOffset(200, 46), UDim2.new(0.5, -100, 0.92, 0), function()
	overlay.Visible = false
	fighting = false
	arena:ClearAllChildren()
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

-- Un "acteur" = modèle d'oiseau déplacé par un CFrameValue tweené
local function makeActor(model, baseCF)
	local value = new("CFrameValue", { Value = baseCF })
	value.Changed:Connect(function(cf)
		model:PivotTo(cf)
	end)
	local originalColors = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			originalColors[p] = p.Color
		end
	end
	return { model = model, base = baseCF, value = value, tween = nil, colors = originalColors }
end

local function moveActor(actor, goal, time, style)
	if actor.tween then
		actor.tween:Cancel()
	end
	actor.tween = TweenService:Create(actor.value, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = goal })
	actor.tween:Play()
end

local function flash(actor)
	for p in actor.colors do
		p.Color = Color3.fromRGB(255, 70, 60)
	end
	task.delay(0.15, function()
		for p, c in actor.colors do
			if p.Parent then
				p.Color = c
			end
		end
	end)
end

local function project(pos)
	local rel = camera.CFrame:PointToObjectSpace(pos)
	local size = viewport.AbsoluteSize
	local t = math.tan(math.rad(camera.FieldOfView / 2))
	local nx = rel.X / -rel.Z / (t * size.X / size.Y)
	local ny = rel.Y / -rel.Z / t
	return Vector2.new((nx * 0.5 + 0.5) * size.X, (0.5 - ny * 0.5) * size.Y)
end

local function popup(worldPos, text, color, big)
	local p = project(worldPos)
	local l = label(viewport, text, UDim2.fromOffset(200, 50), UDim2.fromOffset(p.X - 100, p.Y - 25), big and 40 or 30, color, Enum.TextXAlignment.Center)
	l.ZIndex = 20
	l.TextStrokeTransparency = 0
	TweenService:Create(l, TweenInfo.new(0.9), { Position = UDim2.fromOffset(p.X - 100, p.Y - 85), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		l:Destroy()
	end)
end

local function buildArena(r)
	arena:ClearAllChildren()
	local function block(size, cf, color, material)
		new("Part", { Size = size, CFrame = cf, Color = color, Anchored = true, Material = material or Enum.Material.SmoothPlastic }, arena)
	end
	block(Vector3.new(120, 1, 60), CFrame.new(0, -0.5, -10), Color3.fromRGB(105, 165, 80))
	block(Vector3.new(26, 0.2, 10), CFrame.new(0, 0.05, 0), Color3.fromRGB(215, 190, 120), Enum.Material.Sand)

	local actors = {}
	local fighters = { r.a, r.b }
	for i = 1, 2 do
		local f = fighters[i]
		local scale = Config.RoosterScale[f.rarity] or 1
		local x = i == 1 and -5 or 5
		local yaw = i == 1 and -math.pi / 2 or math.pi / 2 -- face à face
		local cf = CFrame.new(x, 2 * scale, 0) * CFrame.Angles(0, yaw, 0)
		local model = Birds.create(arena, "Fighter" .. i, cf, Config.RarityColors[f.rarity] or Color3.new(1, 1, 1), scale, true)
		actors[i] = makeActor(model, cf)
	end

	-- spectatrices : tes poules au fond de l'arène
	local spectators = {}
	local hens = state and state.hens or {}
	local count = math.min(#hens, 9)
	for n = 1, count do
		local def = Config.HensById[hens[n].henId]
		if def then
			local scale = Config.HenScale[def.rarity]
			local x = (n - (count + 1) / 2) * 4.2
			local cf = CFrame.new(x, 2 * scale, -7) * CFrame.Angles(0, math.pi, 0)
			local model = Birds.create(arena, "Spectator" .. n, cf, def.color, scale, false)
			table.insert(spectators, { model = model, base = cf, phase = n * 1.3 })
		end
	end
	return actors, spectators
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

	local actors, spectators = buildArena(r)
	local excitement = 0.4
	local t0 = os.clock()
	local bob = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		for _, s in spectators do
			local hop = math.abs(math.sin(t * (4 + excitement * 4) + s.phase)) * excitement
			s.model:PivotTo(s.base * CFrame.new(0, hop, 0))
		end
	end)

	task.spawn(function()
		local lastT = r.events[#r.events].t
		local scale = math.min(1, 12 / lastT) -- un combat dure 12 s maximum à l'écran
		local prev = 0
		task.wait(1)
		for _, e in r.events do
			task.wait((e.t - prev) * scale)
			prev = e.t
			local att, def = actors[e.attacker], actors[3 - e.attacker]
			local attacker, defender = fighters[e.attacker], fighters[3 - e.attacker]

			-- l'attaquant fonce, le défenseur encaisse
			moveActor(att, att.base * CFrame.new(0, e.crit and 1.2 or 0.3, e.crit and -5 or -3.5), 0.1)
			task.delay(0.1, function()
				moveActor(att, att.base, 0.18)
			end)
			task.delay(0.1, function()
				flash(def)
				moveActor(def, def.base * CFrame.new(0, 0.5, 1.6) * CFrame.Angles(math.rad(-15), 0, 0), 0.08)
				task.delay(0.1, function()
					moveActor(def, def.base, 0.2)
				end)
				popup(def.base.Position + Vector3.new(0, 5, 0), (e.crit and "CRIT -" or "-") .. e.dmg, e.crit and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(255, 90, 80), e.crit)
			end)
			excitement = math.min(1.2, excitement + 0.05)

			logLabel.Text = ("%s frappe %s : -%d%s"):format(attacker.name, defender.name, e.dmg, e.crit and " (COUP CRITIQUE !)" or "")
			setHp(1, e.hp1, r.a.hp)
			setHp(2, e.hp2, r.b.hp)
		end

		task.wait(0.4)
		local won = r.winner == 1
		local winner, loser = actors[r.winner], actors[3 - r.winner]
		moveActor(loser, loser.base * CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)), 0.5)
		excitement = 1.2
		task.spawn(function()
			for _ = 1, 4 do
				moveActor(winner, winner.base * CFrame.new(0, 2.5, 0), 0.25)
				task.wait(0.3)
				moveActor(winner, winner.base, 0.25, Enum.EasingStyle.Bounce)
				task.wait(0.3)
			end
		end)

		resultLabel.TextColor3 = won and Color3.fromRGB(255, 225, 130) or Color3.fromRGB(230, 110, 100)
		resultLabel.Text = ("%s\n+%d 🪶   %s%d 🏆   (Ligue %s)"):format(won and "VICTOIRE !" or "DÉFAITE", r.rewards.feathers, r.rewards.trophies >= 0 and "+" or "", r.rewards.trophies, r.league)
		closeBtn.Visible = true
		task.wait(5)
		bob:Disconnect()
	end)
end)
