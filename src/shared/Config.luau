-- Données de jeu partagées client/serveur. Tout l'équilibrage se fait ici.
local Config = {}

Config.StartFeathers = 100
Config.StartHens = 2
Config.MaxHens = 10
Config.HenIncome = 1 -- plumes / seconde / poule
Config.MaxEggs = 4 -- oeufs simultanés sur la base
Config.MaxDisplayRoosters = 8 -- coqs visibles dans le poulailler
Config.FightCooldown = 3

Config.RarityColors = {
	Commun = Color3.fromRGB(190, 190, 190),
	Rare = Color3.fromRGB(80, 160, 255),
	Epique = Color3.fromRGB(180, 90, 255),
	Legendaire = Color3.fromRGB(255, 190, 40),
}

-- taps = nombre de clics pour éclore (plus rare = plus long)
-- stats = plages tirées au hasard à l'éclosion
Config.Eggs = {
	{ id = "common", name = "Oeuf Commun", rarity = "Commun", price = 50, taps = 10,
		color = Color3.fromRGB(240, 230, 200),
		stats = { hp = { 80, 120 }, atk = { 8, 12 }, spd = { 8, 12 } } },
	{ id = "rare", name = "Oeuf Rare", rarity = "Rare", price = 400, taps = 30,
		color = Color3.fromRGB(120, 180, 255),
		stats = { hp = { 130, 200 }, atk = { 13, 20 }, spd = { 10, 14 } } },
	{ id = "epic", name = "Oeuf Epique", rarity = "Epique", price = 2500, taps = 80,
		color = Color3.fromRGB(190, 110, 255),
		stats = { hp = { 220, 330 }, atk = { 22, 32 }, spd = { 12, 16 } } },
	{ id = "legendary", name = "Oeuf Legendaire", rarity = "Legendaire", price = 15000, taps = 200,
		color = Color3.fromRGB(255, 200, 60),
		stats = { hp = { 350, 500 }, atk = { 35, 50 }, spd = { 14, 20 } } },
}

Config.EggsById = {}
for _, egg in Config.Eggs do
	Config.EggsById[egg.id] = egg
end

-- Ligues : trophées minimum et récompenses de victoire / pénalité de défaite
Config.Leagues = {
	{ name = "Bronze", min = 0, winFeathers = 40, winTrophies = 25, loseTrophies = 10 },
	{ name = "Argent", min = 100, winFeathers = 90, winTrophies = 25, loseTrophies = 12 },
	{ name = "Or", min = 300, winFeathers = 200, winTrophies = 25, loseTrophies = 15 },
	{ name = "Platine", min = 600, winFeathers = 450, winTrophies = 25, loseTrophies = 18 },
	{ name = "Diamant", min = 1000, winFeathers = 1000, winTrophies = 25, loseTrophies = 20 },
}
Config.LoseFeathers = 5

function Config.getLeague(trophies)
	local found, index = Config.Leagues[1], 1
	for i, league in Config.Leagues do
		if trophies >= league.min then
			found, index = league, i
		end
	end
	return found, index
end

-- Prix de la prochaine poule (n = nombre de poules possédées)
function Config.henPrice(n)
	return math.floor(100 * 1.6 ^ (n - Config.StartHens))
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
