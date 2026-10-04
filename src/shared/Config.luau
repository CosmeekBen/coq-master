-- Données de jeu partagées client/serveur. Tout l'équilibrage se fait ici.
local Config = {}

Config.StartFeathers = 50
Config.MaxHens = 10
Config.MaxEggs = 4 -- oeufs simultanés sur la base
Config.MaxDisplayRoosters = 8 -- coqs visibles dans le poulailler
Config.FightCooldown = 3
Config.SellRatio = { rooster = 0.4, hen = 0.5 } -- part du prix récupérée à la revente

Config.RarityOrder = { "Commun", "Rare", "Epique", "Legendaire" }
Config.RoosterScale = { Commun = 1, Rare = 1.2, Epique = 1.4, Legendaire = 1.7 }
Config.HenScale = { Commun = 0.8, Rare = 0.9, Epique = 1.0, Legendaire = 1.15 }

Config.RarityColors = {
	Commun = Color3.fromRGB(190, 190, 190),
	Rare = Color3.fromRGB(80, 160, 255),
	Epique = Color3.fromRGB(180, 90, 255),
	Legendaire = Color3.fromRGB(255, 190, 40),
}

-- taps = nombre de clics pour éclore (plus rare = plus long)
-- stats = plages tirées au hasard à l'éclosion
Config.Eggs = {
	{ id = "common", name = "Oeuf Commun", rarity = "Commun", price = 100, taps = 15,
		color = Color3.fromRGB(240, 230, 200),
		stats = { hp = { 80, 120 }, atk = { 8, 12 }, spd = { 8, 12 } } },
	{ id = "rare", name = "Oeuf Rare", rarity = "Rare", price = 1500, taps = 50,
		color = Color3.fromRGB(120, 180, 255),
		stats = { hp = { 130, 200 }, atk = { 13, 20 }, spd = { 10, 14 } } },
	{ id = "epic", name = "Oeuf Epique", rarity = "Epique", price = 15000, taps = 150,
		color = Color3.fromRGB(190, 110, 255),
		stats = { hp = { 220, 330 }, atk = { 22, 32 }, spd = { 12, 16 } } },
	{ id = "legendary", name = "Oeuf Legendaire", rarity = "Legendaire", price = 150000, taps = 400,
		color = Color3.fromRGB(255, 200, 60),
		stats = { hp = { 350, 500 }, atk = { 35, 50 }, spd = { 14, 20 } } },
}

Config.EggsById = {}
for _, egg in Config.Eggs do
	Config.EggsById[egg.id] = egg
end

Config.EggsByRarity = {}
for _, egg in Config.Eggs do
	Config.EggsByRarity[egg.rarity] = egg
end

-- Poules : income = plumes / seconde
Config.Hens = {
	{ id = "common", name = "Poule Commune", rarity = "Commun", price = 75, income = 0.5, color = Color3.fromRGB(245, 240, 225) },
	{ id = "rare", name = "Poule Rare", rarity = "Rare", price = 750, income = 2, color = Color3.fromRGB(140, 190, 255) },
	{ id = "epic", name = "Poule Epique", rarity = "Epique", price = 7500, income = 8, color = Color3.fromRGB(200, 130, 255) },
	{ id = "legendary", name = "Poule Legendaire", rarity = "Legendaire", price = 75000, income = 30, color = Color3.fromRGB(255, 210, 80) },
}
Config.HensById = {}
for _, hen in Config.Hens do
	Config.HensById[hen.id] = hen
end

-- Chaque poule d'une rareté coûte plus cher que la précédente de cette rareté
Config.HenPriceGrowth = 1.4
function Config.henPrice(def, ownedOfRarity)
	return math.floor(def.price * Config.HenPriceGrowth ^ ownedOfRarity)
end

-- Combien de poules de cette rareté possède-t-on ? (hens = liste du profil)
function Config.countHens(hens, henId)
	local n = 0
	for _, hen in hens do
		if hen.henId == henId then
			n += 1
		end
	end
	return n
end

-- Boost de combat : on matraque le bouton pour remplir la jauge
Config.Boost = {
	Duration = 4, -- secondes d'effet
	DamageMul = 1.75, -- dégâts de ton coq pendant le boost
	MaxPerFight = 3,
	MinInterval = 1.0, -- côté serveur : délai minimum entre deux boosts (anti-triche)
	ClickGain = 0.08, -- part de jauge gagnée par clic
	Decay = 0.25, -- part de jauge perdue par seconde
}

-- Fatigue : max MaxFights combats par coq sur une fenêtre glissante (secondes)
Config.Fatigue = { MaxFights = 5, Window = 3600 }

-- Retourne (combats récents, secondes de repos restantes avant de pouvoir se battre)
function Config.fatigue(rooster, now)
	local used, oldest = 0, nil
	for _, t in rooster.fightTimes or {} do
		if now - t < Config.Fatigue.Window then
			used += 1
			if not oldest or t < oldest then
				oldest = t
			end
		end
	end
	local rest = 0
	if used >= Config.Fatigue.MaxFights then
		rest = oldest + Config.Fatigue.Window - now
	end
	return used, rest
end

function Config.henSellValue(def)
	return math.floor(def.price * Config.SellRatio.hen)
end

function Config.roosterSellValue(rooster)
	local egg = Config.EggsByRarity[rooster.rarity]
	return egg and math.floor(egg.price * Config.SellRatio.rooster) or 0
end

-- Ligues : trophées minimum et récompenses de victoire / pénalité de défaite
Config.Leagues = {
	{ name = "Bronze", min = 0, winFeathers = 15, winTrophies = 25, loseTrophies = 10 },
	{ name = "Argent", min = 100, winFeathers = 30, winTrophies = 25, loseTrophies = 12 },
	{ name = "Or", min = 300, winFeathers = 60, winTrophies = 25, loseTrophies = 15 },
	{ name = "Platine", min = 600, winFeathers = 120, winTrophies = 25, loseTrophies = 18 },
	{ name = "Diamant", min = 1000, winFeathers = 250, winTrophies = 25, loseTrophies = 20 },
}
Config.LoseFeathers = 2

function Config.getLeague(trophies)
	local found, index = Config.Leagues[1], 1
	for i, league in Config.Leagues do
		if trophies >= league.min then
			found, index = league, i
		end
	end
	return found, index
end

Config.Names = {
	"Cocorico", "Maitre Plume", "Crête d'Acier", "Bec Rapide", "Éperon", "Poulet Max",
	"Chantecler", "Rouquin", "Grand Coq", "Foudre", "Tonnerre", "Griffe", "Napoléon",
}

function Config.rollRooster(egg, id)
	local rng = Random.new()
	local function roll(range)
		return rng:NextInteger(range[1], range[2])
	end
	return {
		id = id,
		name = Config.Names[rng:NextInteger(1, #Config.Names)],
		rarity = egg.rarity,
		hp = roll(egg.stats.hp),
		atk = roll(egg.stats.atk),
		spd = roll(egg.stats.spd),
	}
end

return Config
