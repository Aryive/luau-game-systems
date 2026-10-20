local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StateService = require(ServerScriptService.Server.Services.StateService)
local Packets = require(ReplicatedStorage.Packets)
local Data = require(ReplicatedStorage.Data).server
local Notify = require(ReplicatedStorage.Shared.Modules.Notify)
local Abbreviate = require(ReplicatedStorage.Packages.Abbreviate)

const OFFLINE_CAP_SECONDS = 3600
const MIN_OFFLINE_SECONDS = 60
const MIN_SESSION_FOR_RATE = 30

local OfflineEarningsSystem = {}

local SessionStart = {}

function OfflineEarningsSystem._Init()
	Packets.ClaimOfflineEarnings.OnServerInvoke = function(Player: Player)
		return OfflineEarningsSystem.AttemptClaim(Player)
	end

	-- runs before the profile is released, so the data is still valid here
	Data.Service:addPlayerRemovingCallback(function(Player: Player, ProfileData)
		local Session = SessionStart[Player]
		if Session then
			local Duration = os.time() - Session.Time

			-- short sessions give a bad rate sample, keep the old one
			if Duration >= MIN_SESSION_FOR_RATE then
				local Gained = ProfileData.Leaderstats.FirePower - Session.FirePower
				ProfileData.OfflineRate = math.max(Gained / Duration, 0)
			end

			SessionStart[Player] = nil
		end

		Data[Player].LastLeave(os.time())
	end)
end

function OfflineEarningsSystem._PlayerAdded(self: OfflineEarningsSystem, Player: Player)
	Data.Service:waitForData(Player)

	SessionStart[Player] = {
		Time = os.time(),
		FirePower = Data[Player].Leaderstats.FirePower(),
	}

	local LastLogout = Data[Player].LastLogout()
	if LastLogout > 0 then
		local Elapsed = os.time() - LastLogout

		if Elapsed >= MIN_OFFLINE_SECONDS then
			local Rate = Data[Player].OfflineRate()
			local Earnings = math.floor(math.min(Elapsed, OFFLINE_CAP_SECONDS) * Rate)

			if Earnings > 0 then
				Data[Player].PendingOfflineEarnings(Earnings)
				Data[Player].PendingOfflineSeconds(Elapsed)
			end
		end
	end

	Data[Player].LastLogout(0)
end

function OfflineEarningsSystem.AttemptClaim(Player: Player): boolean
	local Pending = Data[Player].PendingOfflineEarnings()
	if Pending <= 0 then return false end

	Data[Player].PendingOfflineEarnings(0)

	-- already includes multipliers, so skip them here
	StateService:GiveFirePower(Player, Pending, true)
	Notify.Fire(Player, `Claimed {Abbreviate.ToShort(Pending)} offline FirePower!`, "Success", "Offline")

	return true
end

export type OfflineEarningsSystem = typeof(OfflineEarningsSystem)

return OfflineEarningsSystem :: OfflineEarningsSystem
