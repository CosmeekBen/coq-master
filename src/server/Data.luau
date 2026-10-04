-- Profils joueurs en mémoire + sauvegarde DataStore.
-- En Studio, activer "Enable Studio Access to API Services" pour tester la sauvegarde.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Data = {}

local store = DataStoreService:GetDataStore("CoqMaster_v1")
local profiles = {}
local loadedOk = {}

local function default()
	return {
		feathers = Config.StartFeathers,
		trophies = 0,
		hens = Config.StartHens,
		roosters = {},
		eggs = {},
		selected = nil,
		nextId = 1,
	}
end

function Data.load(player)
	local profile = default()
	local ok, result = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if ok then
		loadedOk[player] = true
		if type(result) == "table" then
			for k, v in result do
				profile[k] = v
			end
		end
	else
		warn("[Data] Chargement impossible pour " .. player.Name .. " : " .. tostring(result))
	end
	profiles[player] = profile
	return profile
end

function Data.get(player)
	return profiles[player]
end

function Data.save(player)
	local profile = profiles[player]
	-- ne jamais écraser une sauvegarde si le chargement a échoué
	if not profile or not loadedOk[player] then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[Data] Sauvegarde impossible pour " .. player.Name .. " : " .. tostring(err))
	end
end

function Data.release(player)
	Data.save(player)
	profiles[player] = nil
	loadedOk[player] = nil
end

function Data.all()
	return profiles
end

return Data
