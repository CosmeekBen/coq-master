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

-- Combat au temps réel : chaque coq frappe toutes les 10/spd secondes.
-- Retourne la liste d'évènements {t, attacker (1|2), dmg, crit, hp1, hp2} et le vainqueur.
function Combat.simulate(a, b)
	local fighters = { a, b }
	local hp = { a.hp, b.hp }
	local nextHit = { 10 / a.spd, 10 / b.spd }
	local events = {}

	while hp[1] > 0 and hp[2] > 0 do
		local i = nextHit[1] <= nextHit[2] and 1 or 2
		local j = 3 - i
		local f = fighters[i]
		local crit = rng:NextNumber() < 0.15
		local dmg = f.atk * rng:NextNumber(0.85, 1.15) * (crit and 1.8 or 1)
		dmg = math.max(1, math.floor(dmg))
		hp[j] = math.max(0, hp[j] - dmg)
		table.insert(events, { t = nextHit[i], attacker = i, dmg = dmg, crit = crit, hp1 = hp[1], hp2 = hp[2] })
		nextHit[i] += 10 / f.spd
	end

	return events, hp[1] > 0 and 1 or 2
end

return Combat
