local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.New(StartState: string?)
	local self = setmetatable({} :: StateMachine, StateMachine)

	self._CurrentState = StartState
	self._States = {}
	self._Janitor = Janitor.new()

	self._Janitor:Add(RunService.Heartbeat:Connect(function(dt: number)
		local State = self._States[self._CurrentState]

		if State and State.OnUpdate then
			State:OnUpdate(dt, self)
		end
	end))

	return self
end

function StateMachine.ChangeState(self: StateMachine, NewState: string)
	if self._CurrentState == NewState then return end

	local OldState = self._States[self._CurrentState]
	if OldState and OldState.OnExit then
		OldState:OnExit(self)
	end

	self._CurrentState = NewState

	local State = self._States[NewState]
	if State and State.OnEnter then
		State:OnEnter(self)
	end
end

function StateMachine.AddState(self: StateMachine, StateName: string, State: State)
	self._States[StateName] = State
end

function StateMachine.GetState(self: StateMachine): string?
	return self._CurrentState
end

function StateMachine.Destroy(self: StateMachine)
	self._Janitor:Destroy()
	self._CurrentState = nil
	self._States = nil
end

export type State = {
	OnEnter: ((self: State, Machine: StateMachine) -> ())?,
	OnExit: ((self: State, Machine: StateMachine) -> ())?,
	OnUpdate: ((self: State, dt: number, Machine: StateMachine) -> ())?,
}

export type StateMachine = typeof(StateMachine) & {
	_CurrentState: string?,
	_States: {[string]: State},
	_Janitor: Janitor.Janitor,
}

return StateMachine
