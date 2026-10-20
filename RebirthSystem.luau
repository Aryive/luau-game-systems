local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Data).server
local FlamethrowerService = require(ServerScriptService.Server.Services.FlamethrowerService)
local FunnelService = require(ServerScriptService.Server.Services.FunnelService)
local GetCharacter = require(ReplicatedStorage.Shared.Utility.GetCharacter)
local Packets = require(ReplicatedStorage.Packets)
local GetRebirthCost = require(ReplicatedStorage.Shared.Modules.CostCurves.GetRebirthCost)
local Notify = require(ReplicatedStorage.Shared.Modules.Notify)

-- matches the pixel transition so the teleport happens while the screen is covered
const TELEPORT_DELAY = 0.32
const STARTER_FLAMETHROWER = "Wooden"

local RebirthSystem = {}

local function TeleportToSpawn(Player: Player)
	Packets.PlayPixelTransition:FireClient(Player)

	task.delay(TELEPORT_DELAY, function()
		local Character = GetCharacter(Player)
		if Character then
			Character:PivotTo(CFrame.new(workspace.FLOOR.Spawn.Position + Vector3.new(0, 2, 0)))
		end
	end)
end

local function ResetInventory(Player: Player)
	-- robux flamethrowers are kept, everything else goes
	local NewInventory = {STARTER_FLAMETHROWER}
	for _, Name in Data[Player].Inventory.RobuxFlamethrowers() do
		if not table.find(NewInventory, Name) then
			table.insert(NewInventory, Name)
		end
	end

	Data[Player].Inventory.Flamethrowers(NewInventory)

	if not table.find(NewInventory, Data[Player].EquippedFlamethrower()) then
		Data[Player].EquippedFlamethrower(STARTER_FLAMETHROWER)
		FlamethrowerService:Equip(Player, STARTER_FLAMETHROWER)
	end
end

local function AnnounceUnlocks(Player: Player, OldRebirths: number, NewRebirths: number)
	for _, Trainer in workspace.TRAININGS:GetChildren() do
		local Requirement = Trainer:GetAttribute("Rebirths")

		if Requirement and Requirement > OldRebirths and Requirement <= NewRebirths then
			local Index = string.match(Trainer.Name, "%d+")
			Notify.Fire(Player, `New Training Area Unlocked: Training {Index}!`, "Success", "TrainingUnlock")
		end
	end
end

function RebirthSystem._Init()
	Packets.RequestRebirth.OnServerInvoke = function(Player: Player)
		return RebirthSystem.AttemptRebirth(Player)
	end
end

function RebirthSystem.AttemptRebirth(Player: Player): boolean
	local Rebirths = Data[Player].Leaderstats.Rebirths()
	local Level = Data[Player].Leaderstats.Level()

	if Level < GetRebirthCost(Rebirths + 1) then
		Notify.Fire(Player, "You need to reach the required level first!", "Error", "Rebirth")
		return false
	end

	RebirthSystem.GrantRebirth(Player)
	return true
end

-- used by both the normal rebirth and the skip rebirth product
function RebirthSystem.GrantRebirth(Player: Player)
	local Rebirths = Data[Player].Leaderstats.Rebirths()
	local NewRebirths = Rebirths + 1

	TeleportToSpawn(Player)

	Data[Player].Leaderstats.Rebirths(NewRebirths)
	Data[Player].Leaderstats.Level(0)
	Data[Player].Leaderstats.XP(0)
	Data[Player].Leaderstats.FirePower(0)

	ResetInventory(Player)

	Notify.Fire(Player, `Rebirth #{NewRebirths}! Fire power boosted.`, "Success", "Rebirth")
	Packets.RebirthBurst:FireClient(Player)

	if Rebirths == 0 then
		FunnelService:LogCoreStep(Player, 4, "First Rebirth")
	end

	AnnounceUnlocks(Player, Rebirths, NewRebirths)
end

return RebirthSystem
