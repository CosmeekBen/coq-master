-- Construction procédurale des coqs / poules / étiquettes (pas besoin de modèles pour le MVP).
local Birds = {}

local ORANGE = Color3.fromRGB(255, 150, 30)
local RED = Color3.fromRGB(220, 40, 40)

function Birds.billboard(adornee, text, studsY, color, width)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 150, 36)
	gui.StudsOffset = Vector3.new(0, studsY, 0)
	gui.MaxDistance = 45
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label
end

-- Texte posé SUR une face d'un bloc (panneau) : il fait partie du décor et ne traverse pas les murs.
function Birds.surfaceText(part, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

-- cf = position du centre du corps. Retourne le modèle.
function Birds.create(parent, name, cf, color, scale, isRooster)
	local model = Instance.new("Model")
	model.Name = name

	local function part(n, size, offset, col)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size * scale
		p.CFrame = cf * CFrame.new(offset * scale)
		p.Color = col
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end

	local body = part("Body", Vector3.new(2, 2, 3), Vector3.zero, color)
	part("Head", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 1.4, -1.3), color)
	part("Beak", Vector3.new(0.4, 0.4, 0.7), Vector3.new(0, 1.3, -2.1), ORANGE)
	part("Comb", Vector3.new(0.3, isRooster and 0.7 or 0.4, 0.9), Vector3.new(0, 2.2, -1.3), RED)
	part("LegL", Vector3.new(0.25, 1, 0.25), Vector3.new(-0.5, -1.5, 0), ORANGE)
	part("LegR", Vector3.new(0.25, 1, 0.25), Vector3.new(0.5, -1.5, 0), ORANGE)
	if isRooster then
		local tail = part("Tail", Vector3.new(0.4, 2.2, 1.2), Vector3.new(0, 1.2, 1.9), RED)
		tail.CFrame = tail.CFrame * CFrame.Angles(math.rad(25), 0, 0)
	else
		part("Tail", Vector3.new(0.4, 0.8, 0.8), Vector3.new(0, 0.5, 1.7), color)
	end

	model.PrimaryPart = body
	model.Parent = parent
	return model
end

return Birds
