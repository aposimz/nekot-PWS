local cougarHash = GetHashKey("A_C_MtLion")  -- クーガーのモデルハッシュ
local lastAlert = 0

-- 設定
local Config = {
	Radius = 60.0,              -- 検出距離（メートル）
	CheckIntervalMs = 2000,     -- 通常時のチェック間隔（ミリ秒）
	CooldownMs = 10000,         -- 通知のクールダウン（同じ警告を再表示するまでの最短時間）
	DisabledIntervalMs = 5000,  -- 通知OFF/ダウン時の待機（ミリ秒）
	VehicleSkipWaitMs = 2000,   -- 乗車時の待機（ミリ秒）
	UseQbNotify = true,         -- 通知にqb-coreのNotifyを使用
}

-- qb-core 通知
local QBCore = nil
if Config.UseQbNotify then
	QBCore = exports["qb-core"] and exports["qb-core"]:GetCoreObject() or nil
end

local alertEnabled = false -- true = デフォルトで警告通知オン

local function notifyCougar(message)
	if QBCore and QBCore.Functions and QBCore.Functions.Notify then
		QBCore.Functions.Notify(message, "error", 5000)
	else
		BeginTextCommandThefeedPost("STRING")
		AddTextComponentSubstringPlayerName(message)
		EndTextCommandThefeedPostTicker(false, false)
	end
	PlaySoundFrontend(-1, "DELETE", "HUD_DEATHMATCH_SOUNDSET", true)
end

RegisterCommand("6sense", function(_, args)
	local sub = (args and args[1] or ""):lower()
	if sub == "on" then
		alertEnabled = true
		if QBCore and QBCore.Functions and QBCore.Functions.Notify then
			QBCore.Functions.Notify("クーガー警告: 有効", "success", 2500)
		else
			notifyCougar("クーガー警告: 有効")
		end
	elseif sub == "off" then
		alertEnabled = false
		if QBCore and QBCore.Functions and QBCore.Functions.Notify then
			QBCore.Functions.Notify("クーガー警告: 無効", "primary", 2500)
		else
			notifyCougar("クーガー警告: 無効")
		end
	else
		alertEnabled = not alertEnabled
		local state = alertEnabled and "有効" or "無効"
		if QBCore and QBCore.Functions and QBCore.Functions.Notify then
			QBCore.Functions.Notify("クーガー警告: " .. state, "primary", 2500)
		else
			notifyCougar("クーガー警告: " .. state)
		end
	end
end, false)

Citizen.CreateThread(function()
	while true do
		if not alertEnabled then
			Citizen.Wait(Config.DisabledIntervalMs)
		else
			local playerPed = PlayerPedId()

			-- ダウン中はスキップ
			if IsEntityDead(playerPed) or IsPedDeadOrDying(playerPed, true) then
				Citizen.Wait(Config.DisabledIntervalMs)
			elseif IsPedInAnyVehicle(playerPed, false) then
				-- 乗車中はスキップ
				Citizen.Wait(Config.VehicleSkipWaitMs)
			else
				Citizen.Wait(Config.CheckIntervalMs)

				local playerCoords = GetEntityCoords(playerPed)
				local cougarsNearby = false

				for _, ped in ipairs(GetGamePool('CPed')) do
					if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
						if GetEntityModel(ped) == cougarHash then
							if not IsEntityDead(ped) and not IsPedDeadOrDying(ped, true) then
								local dist = #(GetEntityCoords(ped) - playerCoords)
								if dist < Config.Radius then
									cougarsNearby = true
									break
								end
							end
						end
					end
				end

				if cougarsNearby and (GetGameTimer() - lastAlert) > Config.CooldownMs then
					lastAlert = GetGameTimer()
					notifyCougar("⚠ 危険な野生動物の気配を感じる…")
				end
			end
		end
	end
end)
