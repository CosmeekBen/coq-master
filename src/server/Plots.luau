-- Bases des joueurs : terrain, poulailler à coqs, poulailler à poules, oeufs à casser.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Birds = require(script.Parent.Birds)

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

local function fence(model, origin, center, size, color)
	local w, d = size, size
	local h = 3
	local function side(n, s, off)
		part(model, n, s, origin * CFrame.new(center + off + Vector3.new(0, h / 2, 0)), color, Enum.Material.Wood)
	end
	side("FenceN", Vector3.new(w, h, 0.5), Vector3.new(0, 0, -d / 2))
	side("FenceS", Vector3.new(w, h, 0.5), Vector3.new(0, 0, d / 2))
	side("FenceW", Vector3.new(0.5, h, d), Vector3.new(-w / 2, 0, 0))
	side("FenceE", Vector3.new(0.5, h, d), Vector3.new(w / 2, 0, 0))
end

local function buildPlot(i)
	local origin = CFrame.new((i - 1) * SPACING, 0, 0)
	local model = Instance.new("Model")
	model.Name = "Plot" .. i

	part(model, "Base", Vector3.new(70, 1, 70), origin * CFrame.new(0, -0.5, 0), Color3.fromRGB(110, 170, 80), Enum.Material.Grass)
	local rFloor = part(model, "RoosterFloor", Vector3.new(28, 0.2, 28), origin * CFrame.new(ROOSTER_CENTER + Vector3.new(0, 0.1, 0)), Color3.fromRGB(140, 105, 70), Enum.Material.Ground)
	local hFloor = part(model, "HenFloor", Vector3.new(28, 0.2, 28), origin * CFrame.new(HEN_CENTER + Vector3.new(0, 0.1, 0)), Color3.fromRGB(190, 165, 100), Enum.Material.Ground)
	fence(model, origin, ROOSTER_CENTER, 28, Color3.fromRGB(120, 75, 40))
	fence(model, origin, HEN_CENTER, 28, Color3.fromRGB(230, 220, 200))
	Birds.billboard(rFloor, "Poulailler à coqs", 8, Color3.fromRGB(255, 120, 100))
	Birds.billboard(hFloor, "Poulailler à poules", 8, Color3.fromRGB(255, 230, 150))

	local sign = part(model, "Sign", Vector3.new(14, 4, 1), origin * CFrame.new(0, 6, -30), Color3.fromRGB(120, 75, 40), Enum.Material.Wood)
	local signLabel = Birds.billboard(sign, "Base libre", 0, Color3.new(1, 1, 1))
	sign.Parent = model

	local dyn = Instance.new("Folder")
	dyn.Name = "Dynamic"
	dyn.Parent = model

	return {
		index = i,
		origin = origin,
		model = model,
		dyn = dyn,
		sign = signLabel,
		owner = nil,
		eggParts = {},
	}
end

function Plots.init()
	local folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = Workspace

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
			plot.sign.Text = "Base de " .. player.DisplayName
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
	plot.sign.Text = "Base libre"
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
	for n = 1, math.min(profile.hens, #slots) do
		local pos = slots[n] + Vector3.new(0, 2 * 0.8, 0)
		local cf = plot.origin * CFrame.new(pos) * CFrame.Angles(0, math.rad(((n * 67) % 360)), 0)
		Birds.create(plot.dyn, "Hen" .. n, cf, Color3.fromRGB(245, 240, 225), 0.8, false)
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
		local scale = 1 + (table.find({ "Commun", "Rare", "Epique", "Legendaire" }, r.rarity) - 1) * 0.2
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
			Birds.billboard(egg, "", 4.5, Config.RarityColors[def.rarity])

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
		label.Size = UDim2.fromOffset(220, 60)
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
