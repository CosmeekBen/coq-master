-- Bases des joueurs : terrain, poulailler à coqs, poulailler à poules, oeufs à casser.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Birds = require(ReplicatedStorage.Shared.Birds)

local Plots = {}
Plots.onEggTap = nil -- function(player, eggUid), branchée par Main

local MAX_PLOTS = 8
local SPACING = 80

local plots = {}
local byPlayer = {}

local ROOSTER_CENTER = Vector3.new(-20, 0, -8)
local HEN_CENTER = Vector3.new(20, 0, -8)
local EGG_SLOTS = { -15, -5, 5, 15 }
local EGG_Z = 18

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.Parent = parent
	return p
end

-- Poulailler : fond + côtés, toit à deux pans, façade ouverte (on voit les oiseaux de l'extérieur)
local function building(model, origin, center, wallColor, roofColor, signText, signColor)
	local w, d, h = 28, 28, 9
	local function block(name, size, off, color, material)
		return part(model, name, size, origin * CFrame.new(center + off), color, material or Enum.Material.WoodPlanks)
	end
	local back = block("Back", Vector3.new(w, h, 0.6), Vector3.new(0, h / 2, -d / 2), wallColor)
	block("Left", Vector3.new(0.6, h, d), Vector3.new(-w / 2, h / 2, 0), wallColor)
	block("Right", Vector3.new(0.6, h, d), Vector3.new(w / 2, h / 2, 0), wallColor)
	block("PillarL", Vector3.new(1.2, h, 1.2), Vector3.new(-w / 2, h / 2, d / 2), roofColor)
	block("PillarR", Vector3.new(1.2, h, 1.2), Vector3.new(w / 2, h / 2, d / 2), roofColor)
	-- murets de façade avec une ouverture au milieu
	block("FrontL", Vector3.new(10, 2.5, 0.5), Vector3.new(-9, 1.25, d / 2), wallColor)
	block("FrontR", Vector3.new(10, 2.5, 0.5), Vector3.new(9, 1.25, d / 2), wallColor)
	-- sol de paille
	block("Straw", Vector3.new(w, 0.2, d), Vector3.new(0, 0.1, 0), Color3.fromRGB(215, 190, 110), Enum.Material.Sand)

	local rise, half = 5, w / 2
	local angle = math.atan2(rise, half)
	local len = math.sqrt(half ^ 2 + rise ^ 2) + 1
	for _, side in { -1, 1 } do
		local slab = part(model, "Roof", Vector3.new(len, 0.6, d + 2),
			origin * CFrame.new(center + Vector3.new(side * half / 2, h + rise / 2 + 0.3, 0)) * CFrame.Angles(0, 0, -side * angle),
			roofColor, Enum.Material.Slate)
		slab.Parent = model
	end
	-- panneau sur poteaux, devant le bâtiment (rien ne flotte à travers les murs / le toit)
	local sx, sz = center.X, center.Z + d / 2 + 4
	local postColor = Color3.fromRGB(95, 60, 35)
	part(model, "PostL", Vector3.new(0.6, 4.4, 0.6), origin * CFrame.new(sx - 5, 2.2, sz), postColor, Enum.Material.Wood)
	part(model, "PostR", Vector3.new(0.6, 4.4, 0.6), origin * CFrame.new(sx + 5, 2.2, sz), postColor, Enum.Material.Wood)
	local board = part(model, "Board", Vector3.new(12, 2.6, 0.4), origin * CFrame.new(sx, 4.9, sz), Color3.fromRGB(60, 40, 28), Enum.Material.Wood)
	Birds.surfaceText(board, Enum.NormalId.Back, signText, signColor)
	Birds.surfaceText(board, Enum.NormalId.Front, signText, signColor)
end

-- Clôture autour de la base, avec un portail au milieu de la façade.
-- Un mur invisible (hauteur 14) empêche de sauter par-dessus.
local function perimeterFence(model, origin)
	local half = 34.5
	local wood = Color3.fromRGB(150, 105, 65)
	local dark = Color3.fromRGB(100, 68, 40)

	local function run(ax, az, bx, bz)
		local a, b = Vector3.new(ax, 0, az), Vector3.new(bx, 0, bz)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local mid = (a + b) / 2
		local cf = origin * CFrame.lookAt(mid, mid + dir)
		for _, y in { 1.8, 4.4 } do
			local rail = part(model, "Rail", Vector3.new(0.4, 0.5, len), cf * CFrame.new(0, y, 0), wood, Enum.Material.WoodPlanks)
			rail.CanCollide = false
		end
		local barrier = part(model, "Barrier", Vector3.new(0.6, 14, len), cf * CFrame.new(0, 7, 0), wood)
		barrier.Transparency = 1
		local n = math.max(1, math.floor(len / 5))
		for k = 0, n do
			local p = a + dir * (len * k / n)
			local post = part(model, "Post", Vector3.new(0.9, 6, 0.9), origin * CFrame.new(p.X, 3, p.Z), dark, Enum.Material.Wood)
			post.CanCollide = false
		end
	end

	run(-half, -half, half, -half) -- fond
	run(-half, -half, -half, half) -- gauche
	run(half, -half, half, half) -- droite
	run(-half, half, -5.5, half) -- façade, côté gauche
	run(5.5, half, half, half) -- façade, côté droit

	-- portail
	for _, x in { -5.5, 5.5 } do
		part(model, "GatePost", Vector3.new(1.4, 9, 1.4), origin * CFrame.new(x, 4.5, half), dark, Enum.Material.Wood)
	end
	part(model, "GateBeam", Vector3.new(12.4, 1, 1), origin * CFrame.new(0, 9.2, half), dark, Enum.Material.Wood)
end

local function buildPlot(i)
	local origin = CFrame.new((i - 1) * SPACING, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Plot" .. i

	part(model, "Base", Vector3.new(70, 1, 70), origin * CFrame.new(0, -0.5, 0), Color3.fromRGB(120, 180, 90))
	building(model, origin, ROOSTER_CENTER, Color3.fromRGB(165, 60, 50), Color3.fromRGB(95, 55, 35), "Poulailler à coqs", Color3.fromRGB(255, 140, 120))
	building(model, origin, HEN_CENTER, Color3.fromRGB(235, 225, 205), Color3.fromRGB(190, 120, 70), "Poulailler à poules", Color3.fromRGB(255, 235, 160))

	perimeterFence(model, origin)

	-- panneau du propriétaire (texte sur les deux faces)
	local sign = part(model, "Sign", Vector3.new(14, 4, 1), origin * CFrame.new(0, 2, -30), Color3.fromRGB(120, 75, 40), Enum.Material.Wood)
	local signLabels = {
		Birds.surfaceText(sign, Enum.NormalId.Front, "Base libre"),
		Birds.surfaceText(sign, Enum.NormalId.Back, "Base libre"),
	}

	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = model

	return {
		index = i,
		origin = origin,
		model = model,
		dyn = dyn,
		signLabels = signLabels,
		owner = nil,
		eggParts = {},
	}
end

function Plots.init()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = Workspace

	-- la Baseplate / SpawnLocation par défaut de Studio provoquent du z-fighting avec nos bases
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local ground = part(folder, "Ground", Vector3.new(MAX_PLOTS * SPACING + 200, 4, 320),
		CFrame.new((MAX_PLOTS - 1) * SPACING / 2, -2.1, 0), Color3.fromRGB(88, 140, 70))

	for i = 1, MAX_PLOTS do
		local plot = buildPlot(i)
		plot.model.Parent = folder
		plots[i] = plot
	end
end

function Plots.assign(player)
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			byPlayer[player] = plot
			for _, l in plot.signLabels do
				l.Text = "Base de " .. player.DisplayName
			end
			return plot
		end
	end
	return nil
end

function Plots.release(player)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	plot.owner = nil
	byPlayer[player] = nil
	for _, l in plot.signLabels do
		l.Text = "Base libre"
	end
	plot.dyn:ClearAllChildren()
	plot.eggParts = {}
end

function Plots.spawnCFrame(player)
	local plot = byPlayer[player]
	if not plot then
		return CFrame.new(0, 5, 0)
	end
	local pos = Vector3.new(0, 4, 28)
	return plot.origin * CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1))
end

local function gridPositions(center, cols, rows, dx, dz)
	local list = {}
	for r = 1, rows do
		for c = 1, cols do
			local x = (c - (cols + 1) / 2) * dx
			local z = (r - (rows + 1) / 2) * dz
			table.insert(list, center + Vector3.new(x, 0, z))
		end
	end
	return list
end

local function renderHens(plot, profile)
	local slots = gridPositions(HEN_CENTER, 5, 2, 5, 10)
	for n, hen in profile.hens do
		local def = Config.HensById[hen.henId]
		if def and slots[n] then
			local scale = Config.HenScale[def.rarity]
			local pos = slots[n] + Vector3.new(0, 2 * scale, 0)
			local cf = plot.origin * CFrame.new(pos) * CFrame.Angles(0, math.rad(((n * 67) % 360)), 0)
			local model = Birds.create(plot.dyn, "Hen" .. hen.id, cf, def.color, scale, false)
			if def.rarity ~= "Commun" then
				Birds.billboard(model.PrimaryPart, def.rarity, 3 * scale, Config.RarityColors[def.rarity])
			end
		end
	end
end

local function renderRoosters(plot, profile)
	-- le coq sélectionné est toujours affiché en premier
	local list = {}
	for _, r in profile.roosters do
		if r.id == profile.selected then
			table.insert(list, 1, r)
		else
			table.insert(list, r)
		end
	end
	local slots = gridPositions(ROOSTER_CENTER, 4, 2, 6, 10)
	for n = 1, math.min(#list, Config.MaxDisplayRoosters, #slots) do
		local r = list[n]
		local scale = Config.RoosterScale[r.rarity] or 1
		local pos = slots[n] + Vector3.new(0, 2 * scale, 0)
		local cf = plot.origin * CFrame.new(pos) * CFrame.Angles(0, math.rad(((n * 91) % 360)), 0)
		local color = Config.RarityColors[r.rarity] or Color3.new(1, 1, 1)
		local model = Birds.create(plot.dyn, "Rooster" .. r.id, cf, color, scale, true)
		local text = r.name .. (r.id == profile.selected and " ⭐" or "")
		Birds.billboard(model.PrimaryPart, text, 3.5 * scale, color)
	end
end

local function renderEggs(plot, profile)
	plot.eggParts = {}
	for n, rec in profile.eggs do
		local def = Config.EggsById[rec.eggId]
		if def and EGG_SLOTS[n] then
			local egg = part(plot.dyn, "Egg" .. rec.uid, Vector3.new(4, 5, 4), plot.origin * CFrame.new(EGG_SLOTS[n], 2.5, EGG_Z), def.color, Enum.Material.SmoothPlastic)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = egg
			egg:SetAttribute("BaseSize", egg.Size)
			Birds.billboard(egg, "", 4.5, Config.RarityColors[def.rarity], 200)

			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 40
			click.Parent = egg
			local uid = rec.uid
			click.MouseClick:Connect(function(player)
				if player == plot.owner and Plots.onEggTap then
					Plots.onEggTap(player, uid)
				end
			end)

			plot.eggParts[rec.uid] = egg
			Plots.updateEgg(plot.owner, rec, def, true)
		end
	end
end

-- Met à jour l'étiquette d'un oeuf et joue une petite pulsation (sauf à la création).
function Plots.updateEgg(player, rec, def, silent)
	local plot = byPlayer[player]
	local egg = plot and plot.eggParts[rec.uid]
	if not egg then
		return
	end
	local label = egg:FindFirstChild("Label")
	if label then
		label.Text.Text = ("%s\n%d / %d  (clique !)"):format(def.name, rec.taps, def.taps)
		label.Size = UDim2.fromOffset(200, 54)
	end
	if not silent then
		local base = egg:GetAttribute("BaseSize")
		local grow = TweenService:Create(egg, TweenInfo.new(0.06), { Size = base * 1.12 })
		grow.Completed:Once(function()
			TweenService:Create(egg, TweenInfo.new(0.08), { Size = base }):Play()
		end)
		grow:Play()
	end
end

function Plots.render(player, profile)
	local plot = byPlayer[player]
	if not plot then
		return
	end
	plot.dyn:ClearAllChildren()
	renderHens(plot, profile)
	renderRoosters(plot, profile)
	renderEggs(plot, profile)
end

return Plots
