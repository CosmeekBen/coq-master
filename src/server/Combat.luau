-- Simulation de combat côté serveur (le client ne fait que rejouer les évènements).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Combat = {}
local rng = Random.new()

local BOT_NAMES = { "Coq Sauvage", "Chef de Basse-cour", "Coq Hardi", "Ombre Rousse", "Bec de Fer", "Coq Fantôme" }

-- Adversaire de la ligue : un coq d'un autre joueur connecté s'il y en a un, sinon un coq fantôme
-- dont les stats sont proches de celles du coq du joueur (ajustées par la ligue).
function Combat.pickOpponent(mine, trophies, otherRooster, otherName)
	if otherRooster then
		return {
			name = otherRooster.name .. " (" .. otherName .. ")",
			rarity = otherRooster.rarity,
			hp = otherRooster.hp,
			atk = otherRooster.atk,
			spd = otherRooster.spd,
		}
	end
	local _, leagueIndex = Config.getLeague(trophies)
	local factor = rng:NextNumber(0.8, 1.15) + (leagueIndex - 1) * 0.04
	return {
		name = BOT_NAMES[rng:NextInteger(1, #BOT_NAMES)],
		rarity = mine.rarity,
		hp = math.max(1, math.floor(mine.hp * factor)),
		atk = math.max(1, math.floor(mine.atk * factor)),
		spd = math.max(1, math.floor(mine.spd * factor)),
	}
end

-- Combat à tour de rôle sur une ligne de temps : chaque coq frappe toutes les 10/spd secondes.
-- step(mul) joue le prochain coup ; mul multiplie les dégâts du coq 1 (boost du joueur).
function Combat.new(a, b)
	local fighters = { a, b }
	local hp = { a.hp, b.hp }
	local nextHit = { 10 / a.spd, 10 / b.spd }
	local self = {}

	function self.finished()
		return hp[1] <= 0 or hp[2] <= 0
	end

	function self.nextTime()
		return math.min(nextHit[1], nextHit[2])
	end

	function self.winner()
		return hp[1] > 0 and 1 or 2
	end

	function self.step(mul)
		local i = nextHit[1] <= nextHit[2] and 1 or 2
		local j = 3 - i
		local f = fighters[i]
		local crit = rng:NextNumber() < 0.15
		local dmg = f.atk * rng:NextNumber(0.85, 1.15) * (crit and 1.8 or 1) * (i == 1 and mul or 1)
		dmg = math.max(1, math.floor(dmg))
		hp[j] = math.max(0, hp[j] - dmg)
		local t = nextHit[i]
		nextHit[i] += 10 / f.spd
		return { t = t, attacker = i, dmg = dmg, crit = crit, hp1 = hp[1], hp2 = hp[2] }
	end

	return self
end

-- Durée approximative (sans boost), pour comprimer les longs combats à ~15 s réelles
function Combat.estimateDuration(a, b)
	local sim = Combat.new(a, b)
	local t = 0
	while not sim.finished() do
		t = sim.step(1).t
	end
	return t
end

return Combat
