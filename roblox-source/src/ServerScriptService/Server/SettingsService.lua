--!strict
--[[
	SettingsService (v3.1) — звуковые настройки игрока: SetAudio(key, value).
	Хранятся в data.Settings.Audio (переживают перезаход), уходят клиенту в Core.Audio. Валидация — AudioData.set.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AudioData = require(ReplicatedStorage.Shared.AudioData)

local DataService = require(script.Parent.DataService)
local Router = require(script.Parent.Router)
local State = require(script.Parent.State)

local SettingsService = {}

function SettingsService.setAudio(player: Player, key: any, value: any): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "err.bad_request"
	end
	local audio, err = AudioData.set(data.Settings.Audio, key, value)
	if not audio then
		return false, err
	end
	data.Settings.Audio = audio
	State.markCore(player)
	return true, nil
end

function SettingsService.init()
	-- ползунок громкости нажимают часто: 4 в секунду, запас 10
	Router.register("SetAudio", 4, 10, SettingsService.setAudio)
end

return SettingsService
