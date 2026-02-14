--!strict
local RunService = game:GetService('RunService');

local TouchButton = {};

if RunService:IsServer() then
	TouchButton.Server = require(script.Server);
else
	TouchButton.Client = require(script.Client);
end;

return TouchButton;