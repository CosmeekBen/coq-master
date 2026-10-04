-- Point d'entrée serveur : joueurs, économie, éclosion, combats.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Plots = require(script.Parent.Plots)
local Combat = require(script.Parent.Combat)

-- Remotes ---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function remote(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = remotes
	return e
end

local BuyEgg = remote("BuyEgg") -- client -> serveur (eggId)
local BuyHen = remote("BuyHen")
local SelectRooster = remote("SelectRooster") -- (roosterId)
local Fight = remote("Fight")
local State = remote("State") -- serveur -> client
local Notify = remote("Notify")
local FightResult = remote("FightResult")

-- Helpers ---------------------------------------------------------------
local function findRooster(profile, id)
	for _, r in profile.roosters do
		if r.id == id then
			return r
		end
	end
	return nil
end

local function updateLeaderstats(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Plumes.Value = math.floor(profile.feathers)
		stats["Trophées"].Value = profile.trophies
	end
end

local function pushState(player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	updateLeaderstats(player, profile)
	State:FireClient(player, {
		feathers = math.floor(profile.feathers),
		trophies = profile.trophies,
		hens = profile.hens,
		henPrice = profile.hens < Config.MaxHens and Config.henPrice(profile.hens) or nil,
		roosters = profile.roosters,
		eggs = profile.eggs,
		selected = profile.selected,
	})
end

local function refresh(player)
	local profile = Data.get(player)
	if profile then
		Plots.render(player, profile)
		pushState(player)
	end
end

-- Joueurs ----------------------------------------------------------------
local function onPlayerAdded(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local plumes = Instance.new("IntValue")
	plumes.Name = "Plumes"
	plumes.Parent = stats
	local trophies = Instance.new("IntValue")
	trophies.Name = "Trophées"
	trophies.Parent = stats
	stats.Parent = player

	local profile = Data.load(player)
	if not player.Parent then
		return -- parti pendant le chargement
	end

	-- coq de départ offert pour pouvoir combattre tout de suite
	if #profile.roosters == 0 and #profile.eggs == 0 then
		local starter = Config.rollRooster(Config.EggsById.common, profile.nextId)
		profile.nextId += 1
		table.insert(profile.roosters, starter)
		profile.selected = starter.id
	end

	local plot = Plots.assign(player)
	if not plot then
		player:Kick("Serveur plein : aucune base disponible.")
		return
	end

	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if root then
			character:PivotTo(Plots.spawnCFrame(player))
		end
	end)
	if player.Character then
		player.Character:PivotTo(Plots.spawnCFrame(player))
	end

	refresh(player)
end

local function onPlayerRemoving(player)
	Plots.release(player)
	Data.release(player)
end

Plots.init()
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Revenus des poules -----------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		for player, profile in Data.all() do
			profile.feathers += profile.hens * Config.HenIncome
			pushState(player)
		end
	end
end)

-- Sauvegarde automatique
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in Players:GetPlayers() do
			task.spawn(Data.save, player)
		end
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(Data.save, player)
	end
	task.wait(2)
end)

-- Boutique ---------------------------------------------------------------
BuyEgg.OnServerEvent:Connect(function(player, eggId)
	local profile = Data.get(player)
	local def = type(eggId) == "string" and Config.EggsById[eggId]
	if not profile or not def then
		return
	end
	if #profile.eggs >= Config.MaxEggs then
		Notify:FireClient(player, "Ta base est pleine d'oeufs ! Fais-en éclore avant d'en acheter.")
		return
	end
	if profile.feathers < def.price then
		Notify:FireClient(player, "Pas assez de plumes.")
		return
	end
	profile.feathers -= def.price
	table.insert(profile.eggs, { uid = profile.nextId, eggId = def.id, taps = 0 })
	profile.nextId += 1
	refresh(player)
end)

BuyHen.OnServerEvent:Connect(function(player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	if profile.hens >= Config.MaxHens then
		Notify:FireClient(player, "Poulailler complet !")
		return
	end
	local price = Config.henPrice(profile.hens)
	if profile.feathers < price then
		Notify:FireClient(player, "Pas assez de plumes.")
		return
	end
	profile.feathers -= price
	profile.hens += 1
	refresh(player)
end)

SelectRooster.OnServerEvent:Connect(function(player, id)
	local profile = Data.get(player)
	if not profile or type(id) ~= "number" or not findRooster(profile, id) then
		return
	end
	profile.selected = id
	refresh(player)
end)

-- Éclosion : un clic = un tap -----------------------------------------------
local lastTap = {}

Plots.onEggTap = function(player, uid)
	local profile = Data.get(player)
	if not profile then
		return
	end
	local now = os.clock()
	if now - (lastTap[player] or 0) < 0.08 then
		return
	end
	lastTap[player] = now

	local index, rec
	for i, e in profile.eggs do
		if e.uid == uid then
			index, rec = i, e
			break
		end
	end
	local def = rec and Config.EggsById[rec.eggId]
	if not def then
		return
	end

	rec.taps += 1
	if rec.taps < def.taps then
		Plots.updateEgg(player, rec, def)
		return
	end

	table.remove(profile.eggs, index)
	local rooster = Config.rollRooster(def, profile.nextId)
	profile.nextId += 1
	table.insert(profile.roosters, rooster)
	if not profile.selected then
		profile.selected = rooster.id
	end
	Notify:FireClient(player, ("%s est né ! (%s — ❤%d ⚔%d ⚡%d)"):format(rooster.name, rooster.rarity, rooster.hp, rooster.atk, rooster.spd))
	refresh(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastTap[player] = nil
end)

-- Ligue : combats -------------------------------------------------------------
local fightLockedUntil = {}

Fight.OnServerEvent:Connect(function(player)
	local profile = Data.get(player)
	if not profile then
		return
	end
	if os.clock() < (fightLockedUntil[player] or 0) then
		return
	end
	local mine = profile.selected and findRooster(profile, profile.selected)
	if not mine then
		Notify:FireClient(player, "Sélectionne un coq pour combattre.")
		return
	end

	-- adversaire : coq sélectionné d'un autre joueur connecté, sinon coq fantôme
	local otherRooster, otherName
	local candidates = {}
	for other, otherProfile in Data.all() do
		if other ~= player and otherProfile.selected then
			table.insert(candidates, other)
		end
	end
	if #candidates > 0 then
		local other = candidates[math.random(1, #candidates)]
		otherRooster = findRooster(Data.get(other), Data.get(other).selected)
		otherName = other.DisplayName
	end

	local me = { name = mine.name, rarity = mine.rarity, hp = mine.hp, atk = mine.atk, spd = mine.spd }
	local opponent = Combat.pickOpponent(me, profile.trophies, otherRooster, otherName)
	local events, winner = Combat.simulate(me, opponent)

	local league = Config.getLeague(profile.trophies)
	local rewards
	if winner == 1 then
		rewards = { feathers = league.winFeathers, trophies = league.winTrophies }
	else
		rewards = { feathers = Config.LoseFeathers, trophies = -math.min(profile.trophies, league.loseTrophies) }
	end
	profile.feathers += rewards.feathers
	profile.trophies += rewards.trophies

	local duration = events[#events].t
	fightLockedUntil[player] = os.clock() + math.min(duration, 12) + Config.FightCooldown

	FightResult:FireClient(player, {
		a = me,
		b = opponent,
		events = events,
		winner = winner,
		rewards = rewards,
		league = Config.getLeague(profile.trophies).name,
	})
	pushState(player)
end)
