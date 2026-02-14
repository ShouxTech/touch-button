--!strict
local RunService = game:GetService('RunService');

export type TouchButtonConfig = {
	position: UDim2,
	size: UDim2,
};

local IS_SERVER = RunService:IsServer();

local function getRemoteEvent(name: string)
	if IS_SERVER then
		local remote = Instance.new('RemoteEvent');
		remote.Name = name;
		remote.Parent = script;
		return remote;
	end;

	return script:WaitForChild(name) :: RemoteEvent;
end;

local function getRemoteFunction(name: string)
	if IS_SERVER then
		local remote = Instance.new('RemoteFunction');
		remote.Name = name;
		remote.Parent = script;
		return remote;
	end;

	return script:WaitForChild(name) :: RemoteFunction;
end;

local Shared = {};

Shared.getTouchButtonConfig = getRemoteFunction('GetTouchButtonConfig');
Shared.setTouchButtonConfig = getRemoteEvent('SetTouchButtonConfig');

return Shared;