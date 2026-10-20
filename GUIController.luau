local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Observers = require(ReplicatedStorage.Packages.Observers)
local Signals = require(ReplicatedStorage.Signals)

const BAR_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
const ZOOM_TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
const ZOOM_FOV = 50
const DEFAULT_FOV = 80
const HIDE_OFFSET = UDim2.fromScale(0, 0.45)

local Player = Players.LocalPlayer
local PlayerUI = Player.PlayerGui
local MainGui = PlayerUI:WaitForChild("MainGui", 10)

local FrameModuleFolder = script.FrameOpenModules
local FrameModules: {[string]: any} = {}

-- preloaded here because requiring from a sandboxed thread fails
local function LoadFrameModule(Module: ModuleScript)
	local Success, Result = pcall(require, Module)
	if Success then
		FrameModules[Module.Name] = Result
	else
		warn(`[GUIController]: Failed to load frame module {Module.Name}: {Result}`)
	end
end

local function GetFrameModule(FrameModuleType: string)
	if FrameModules[FrameModuleType] then
		return FrameModules[FrameModuleType]
	end

	local Module = FrameModuleFolder:FindFirstChild(FrameModuleType)
	if Module and Module:IsA("ModuleScript") then
		LoadFrameModule(Module)
	end

	return FrameModules[FrameModuleType]
end

local function TweenFOV(FOV: number)
	local Camera = workspace.CurrentCamera
	if not Camera then return end

	TweenService:Create(Camera, ZOOM_TWEEN_INFO, {FieldOfView = FOV}):Play()
end

for _, Module in FrameModuleFolder:GetChildren() do
	if Module:IsA("ModuleScript") then
		LoadFrameModule(Module)
	end
end

local GUIController = {}

function GUIController._Init(self: GUIController)
	self._UIBlur = Instance.new("BlurEffect")
	self._UIBlur.Size = 10
	self._UIBlur.Enabled = false
	self._UIBlur.Parent = Lighting

	self._ZoomDepth = 0
	self._BarOriginalPosition = MainGui.Bar.Position
	self._DevProductsOriginalPosition = MainGui["Dev Products"].Position

	self:SetFrameModuleType("Pop")

	Observers.observeTag("CloseButton", function(CloseButton)
		CloseButton.Activated:Connect(function()
			self:CloseFrame(CloseButton.Parent.Parent.Parent.Name)
		end)
	end)
end

function GUIController.OpenFrame(self: GUIController, FrameName: string)
	if self.CurrentFrame then
		self:CloseFrame(self.CurrentFrame, true)
	else
		self:_ToggleBar(false)
		self:PushZoom()
	end

	local Frame = MainGui.Frames:FindFirstChild(FrameName, true)

	local Success, Err = pcall(function()
		assert(Frame, `{FrameName} frame not found`)

		local FrameModule = GetFrameModule(self._FrameModuleType)
		assert(FrameModule, `frame module {self._FrameModuleType} not available`)

		FrameModule:Open(Frame)
	end)

	if not Success then
		warn(`[GUIController]: Failed to open {FrameName}: {Err}`)
		self:_ToggleBar(true)
		self:PopZoom()
		self:ReconcileZoom()
		return
	end

	self._UIBlur.Enabled = true
	self.CurrentFrame = FrameName
	Signals.FrameChanged:Fire(FrameName)
end

function GUIController.CloseFrame(self: GUIController, FrameName: string, Switching: boolean?)
	local Frame = MainGui.Frames:FindFirstChild(FrameName, true)

	if Frame then
		local Success, Err = pcall(function()
			local FrameModule = GetFrameModule(self._FrameModuleType)
			assert(FrameModule, `frame module {self._FrameModuleType} not available`)

			FrameModule:Close(Frame)
		end)

		if not Success then
			warn(`[GUIController]: Failed to close {FrameName}: {Err}`)
			Frame.Visible = false
		end
	else
		warn(`[GUIController]: {FrameName} frame not found`)
	end

	self._UIBlur.Enabled = false
	self.CurrentFrame = nil
	Signals.FrameChanged:Fire(nil)

	if not Switching then
		self:_ToggleBar(true)
		self:PopZoom()
		self:ReconcileZoom()
	end
end

-- resets the zoom if it got stuck with nothing open
function GUIController.ReconcileZoom(self: GUIController)
	if self.CurrentFrame or self._ZoomDepth <= 0 then return end

	local Purchase = PlayerUI:FindFirstChild("Purchase")
	if Purchase and Purchase.Enabled then return end

	self._ZoomDepth = 0
	TweenFOV(self._OriginalFOV or DEFAULT_FOV)
end

-- counted so nested menus don't fight over the camera
function GUIController.PushZoom(self: GUIController)
	self._ZoomDepth += 1

	if self._ZoomDepth == 1 then
		local Camera = workspace.CurrentCamera
		self._OriginalFOV = Camera and Camera.FieldOfView or DEFAULT_FOV
		TweenFOV(ZOOM_FOV)
	end
end

function GUIController.PopZoom(self: GUIController)
	self._ZoomDepth = math.max(self._ZoomDepth - 1, 0)

	if self._ZoomDepth == 0 then
		TweenFOV(self._OriginalFOV or DEFAULT_FOV)
	end
end

function GUIController._ToggleBar(self: GUIController, Visible: boolean)
	local BarTarget = if Visible then self._BarOriginalPosition else self._BarOriginalPosition + HIDE_OFFSET
	local DevTarget = if Visible then self._DevProductsOriginalPosition else self._DevProductsOriginalPosition + HIDE_OFFSET

	TweenService:Create(MainGui.Bar, BAR_TWEEN_INFO, {Position = BarTarget}):Play()
	TweenService:Create(MainGui["Dev Products"], BAR_TWEEN_INFO, {Position = DevTarget}):Play()
end

function GUIController.SetFrameModuleType(self: GUIController, FrameModuleType: "Slide" | "Pop")
	self._FrameModuleType = FrameModuleType
end

export type GUIController = typeof(GUIController) & {
	CurrentFrame: string?,
	_UIBlur: BlurEffect,
	_FrameModuleType: "Slide" | "Pop",
	_ZoomDepth: number,
	_OriginalFOV: number?,
	_BarOriginalPosition: UDim2,
	_DevProductsOriginalPosition: UDim2,
}

return GUIController :: GUIController
