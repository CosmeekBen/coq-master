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
local BuyHen = remote("BuyHen") -- (henId)
local SellHen = remote("SellHen") -- (uid)
local SellRooster = remote("SellRooster") -- (roosterId)
local SelectRooster = remote("SelectRooster") -- (roosterId)
local Fight = remote("Fight")
local State = remote("State") -- serveur -> client (état complet, sur évènement)
local Feathers = remote("Feathers") -- serveur -> client (plumes seules, chaque seconde)
local Notify = remote("Notify")
local Boost = remote("Boost") -- client -> serveur : jauge de boost pleine
local FightUpdate = remote("FightUpdate") -- serveur -> client : start / hit / boost / end

-- Helpers ---------------------------------------------------------------
-- Anti-spam par joueur (le client est toujours considéré comme hostile)
local lastAction = {}
local function throttled(player, interval)
	local now = os.clock()
	if now - (lastAction[player] or 0) < interval then
		return true
	end
	lastAction[player] = now
	return false
end

local function isInt(n)
	return type(n) == "number" and n % 1 == 0
end

local function findRooster(profile, id)
	for _, r in profile.roosters do
		if r.id == id then
			return r
		end
	end
	return nil
end

local function incomePerSecond(profile)
	local total = 0
	for _, hen in profile.hens do
		local def = Config.HensById[hen.henId]
		if def then
			total += def.income
		end
	end
	return total
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
		income = incomePerSecond(profile),
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

	-- cadeau de départ (une seule fois) : 1 coq pour combattre + 2 poules communes
	if not profile.starterGiven then
		profile.starterGiven = true
		local starter = Config.rollRooster(Config.EggsById.common, profile.nextId)
		profile.nextId += 1
		table.insert(profile.roosters, starter)
		profile.selected = starter.id
		for _ = 1, 2 do
			table.insert(profile.hens, { id = profile.nextId, henId = "common" })
			profile.nextId += 1
		end
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
			profile.feathers += incomePerSecond(profile)
			updateLeaderstats(player, profile)
			Feathers:FireClient(player, math.floor(profile.feathers))
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
	local pending = 0
	for _, player in Players:GetPlayers() do
		pending += 1
		task.spawn(function()
			Data.save(player)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25 -- Roblox coupe le serveur à ~30 s
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

-- Boutique ---------------------------------------------------------------
BuyEgg.OnServerEvent:Connect(function(player, eggId)
	if throttled(player, 0.25) then
		return
	end
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

BuyHen.OnServerEvent:Connect(function(player, henId)
	if throttled(player, 0.25) then
		return
	end
	local profile = Data.get(player)
	local def = type(henId) == "string" and Config.HensById[henId]
	if not profile or not def then
		return
	end
	if #profile.hens >= Config.MaxHens then
		Notify:FireClient(player, "Poulailler complet ! Revends une poule pour faire de la place.")
		return
	end
	local price = Config.henPrice(def, Config.countHens(profile.hens, def.id))
	if profile.feathers < price then
		Notify:FireClient(player, "Pas assez de plumes.")
		return
	end
	profile.feathers -= price
	table.insert(profile.hens, { id = profile.nextId, henId = def.id })
	profile.nextId += 1
	refresh(player)
end)

SellHen.OnServerEvent:Connect(function(player, uid)
	if throttled(player, 0.25) then
		return
	end
	local profile = Data.get(player)
	if not profile or not isInt(uid) then
		return
	end
	for i, hen in profile.hens do
		if hen.id == uid then
			local def = Config.HensById[hen.henId]
			table.remove(profile.hens, i)
			profile.feathers += def and Config.henSellValue(def) or 0
			refresh(player)
			return
		end
	end
end)

SellRooster.OnServerEvent:Connect(function(player, id)
	if throttled(player, 0.25) then
		return
	end
	local profile = Data.get(player)
	if not profile or not isInt(id) then
		return
	end
	for i, rooster in profile.roosters do
		if rooster.id == id then
			table.remove(profile.roosters, i)
			profile.feathers += Config.roosterSellValue(rooster)
			if profile.selected == id then
				profile.selected = profile.roosters[1] and profile.roosters[1].id or nil
			end
			refresh(player)
			return
		end
	end
end)

SelectRooster.OnServerEvent:Connect(function(player, id)
	if throttled(player, 0.25) then
		return
	end
	local profile = Data.get(player)
	if not profile or not isInt(id) or not findRooster(profile, id) then
		return
	end
	profile.selected = id
	refresh(player)
end)

-- Éclosion : un clic = un tap -----------------------------------------------
local lastTap = {}
local fightLockedUntil = {}
local fights = {} -- player -> { boostUntil, lastBoostAt, boosts }

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
	lastAction[player] = nil
	fightLockedUntil[player] = nil
	fights[player] = nil
end)

-- Ligue : combats (déroulés en direct côté serveur, le boost du joueur modifie les dégâts) ------
local BOOST = Config.Boost

Fight.OnServerEvent:Connect(function(player)
	local profile = Data.get(player)
	if not profile or fights[player] then
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

	-- fatigue : un coq ne peut pas faire plus de MaxFights combats par fenêtre d'une heure
	local now = os.time()
	local _, restSeconds = Config.fatigue(mine, now)
	if restSeconds > 0 then
		Notify:FireClient(player, ("%s est épuisé ! Repos encore %d min — choisis un autre coq."):format(mine.name, math.ceil(restSeconds / 60)))
		return
	end
	local kept = {}
	for _, t in mine.fightTimes or {} do
		if now - t < Config.Fatigue.Window then
			table.insert(kept, t)
		end
	end
	table.insert(kept, now)
	mine.fightTimes = kept

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
	local timeScale = math.min(1, 15 / Combat.estimateDuration(me, opponent)) -- un combat dure ~15 s max

	local fight = { boostUntil = 0, lastBoostAt = os.clock() + 1.2, boosts = 0 }
	fights[player] = fight
	FightUpdate:FireClient(player, { kind = "start", a = me, b = opponent })
	pushState(player) -- met à jour la fatigue affichée

	task.spawn(function()
		task.wait(1.2) -- laisse l'écran de combat se préparer
		local sim = Combat.new(me, opponent)
		local prev = 0
		while not sim.finished() do
			task.wait((sim.nextTime() - prev) * timeScale)
			if not player.Parent then
				fights[player] = nil
				return
			end
			local boosted = os.clock() < fight.boostUntil
			local e = sim.step(boosted and BOOST.DamageMul or 1)
			e.kind, e.boosted = "hit", boosted
			prev = e.t
			FightUpdate:FireClient(player, e)
		end

		task.wait(0.8)
		local winner = sim.winner()
		local league = Config.getLeague(profile.trophies)
		local rewards
		if winner == 1 then
			rewards = { feathers = league.winFeathers, trophies = league.winTrophies }
		else
			rewards = { feathers = Config.LoseFeathers, trophies = -math.min(profile.trophies, league.loseTrophies) }
		end
		profile.feathers += rewards.feathers
		profile.trophies += rewards.trophies

		fights[player] = nil
		fightLockedUntil[player] = os.clock() + Config.FightCooldown
		FightUpdate:FireClient(player, {
			kind = "end",
			winner = winner,
			rewards = rewards,
			league = Config.getLeague(profile.trophies).name,
		})
		pushState(player)
	end)
end)

-- Le client dit "ma jauge est pleine" : le serveur vérifie délai et quota avant d'activer.
Boost.OnServerEvent:Connect(function(player)
	local fight = fights[player]
	local now = os.clock()
	if not fight or fight.boosts >= BOOST.MaxPerFight or now < fight.boostUntil or now - fight.lastBoostAt < BOOST.MinInterval then
		if fight then
			FightUpdate:FireClient(player, { kind = "boostDenied" })
		end
		return
	end
	fight.boosts += 1
	fight.boostUntil = now + BOOST.Duration
	fight.lastBoostAt = now
	FightUpdate:FireClient(player, { kind = "boost", duration = BOOST.Duration, used = fight.boosts })
end)
