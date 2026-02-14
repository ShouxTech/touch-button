--!strict
local Players = game:GetService('Players');
local UserInputService = game:GetService('UserInputService');
local Workspace = game:GetService('Workspace');

local Shared = require(script.Parent.Shared);
local isTypeScriptEnv = script.Parent.Name == 'src';
local dependencies = if isTypeScriptEnv then script.Parent.Parent.Parent else script.Parent.Parent;
local Charm = require(isTypeScriptEnv and dependencies.charm or dependencies.Charm);
local Trove = require(isTypeScriptEnv and dependencies['sleitnick-trove'].src or dependencies.Trove);

type TouchButton = {
	setIcon: (self: TouchButton, icon: string) -> (),
	setSize: (self: TouchButton, size: UDim2) -> (),
	setPosition: (self: TouchButton, position: UDim2) -> (),
	setConfig: (self: TouchButton, config: Shared.TouchButtonConfig) -> (),
	destroy: (self: TouchButton) -> (),
};

type TouchButtonOptions = {
	name: string,
	icon: string,
	size: UDim2,
	position: UDim2,
	sinkInput: boolean?,
	onPress: (() -> ())?,
	onRelease: (() -> ())?,
};

local localPlayer = Players.LocalPlayer;
local camera = Workspace.CurrentCamera :: Camera;

local touchGui: ScreenGui?;
local jumpBtn: Frame?;

local initialized = false;

local EDITING_MODE_BUTTON_COLOR = Color3.fromRGB(15, 143, 255);
local MIN_RESIZE = 40;

local function getJumpButtonLayout()
	local minAxis = math.min(camera.ViewportSize.X, camera.ViewportSize.Y);
	local isSmallScreen = minAxis <= 500;
	local jumpButtonSize = if isSmallScreen then 70 else 120;

	return {
		size = UDim2.fromOffset(jumpButtonSize, jumpButtonSize),
		position = if isSmallScreen 
			then UDim2.new(1, -(jumpButtonSize * 1.5 - 10), 1, -jumpButtonSize - 20) 
			else UDim2.new(1, -(jumpButtonSize * 1.5 - 10), 1, -jumpButtonSize * 1.75),
	};
end;

local function getTouchGui()
	if touchGui and jumpBtn then
		return touchGui, jumpBtn;
	end;

	local newTouchGui = Instance.new('ScreenGui');
	newTouchGui.Name = 'CustomTouchGui';
	newTouchGui.ResetOnSpawn = false;
	newTouchGui.Parent = localPlayer:WaitForChild('PlayerGui');
	touchGui = newTouchGui;

	local newJumpBtn = Instance.new('Frame');
	newJumpBtn.Name = 'Jump';
	newJumpBtn.BackgroundTransparency = 1;

	local function updateLayout()
		local jumpBtnLayout = getJumpButtonLayout();
		newJumpBtn.Position = jumpBtnLayout.position;
		newJumpBtn.Size = jumpBtnLayout.size;
	end;

	camera:GetPropertyChangedSignal('ViewportSize'):Connect(updateLayout);
	updateLayout();

	newJumpBtn.Parent = newTouchGui;
	jumpBtn = newJumpBtn;

	local characterExists = Charm.atom(localPlayer.Character ~= nil);
	local lastInputType = Charm.atom(UserInputService:GetLastInputType());

	Charm.effect(function()
		local charExists = characterExists();
		local inputType = lastInputType();

		newTouchGui.Enabled = (inputType == Enum.UserInputType.Touch) and charExists;
	end);

	localPlayer.CharacterAdded:Connect(function()
		characterExists(true);
	end);
	localPlayer.CharacterRemoving:Connect(function()
		characterExists(false);
	end);

	UserInputService.LastInputTypeChanged:Connect(lastInputType);

	return newTouchGui, newJumpBtn;
end;

local Client = {};
Client.__index = Client;

Client.configEditingMode = Charm.atom(false);
Client.touchButtons = {} :: { TouchButton };

function Client._init()
	if initialized then return; end;
	initialized = true;

	local editingTrove = Trove.new();

	Charm.effect(function()
		local isEditing = Client.configEditingMode();
		if isEditing then
			local function createButton(props: { name: string, text: string, backgroundColor: Color3, offsetY: number })
				local btn = Instance.new('TextButton');
				btn.Name = props.name;
				btn.AnchorPoint = Vector2.new(0.5, 0.5);
				btn.BackgroundColor3 = props.backgroundColor;
				btn.BackgroundTransparency = 0.25;
				btn.FontFace = Font.new('rbxasset://fonts/families/GothamSSm.json', Enum.FontWeight.Medium, Enum.FontStyle.Normal);
				btn.Position = UDim2.new(0.5, 0, 0.5, props.offsetY);
				btn.Size = UDim2.fromOffset(120, 32);
				btn.Text = props.text;
				btn.TextColor3 = Color3.new(1, 1, 1);
				btn.TextSize = 16;
				btn.Parent = touchGui;
				editingTrove:Add(btn);

				local uiCorner = Instance.new('UICorner');
				uiCorner.CornerRadius = UDim.new(0, 5);
				uiCorner.Parent = btn;

				return btn;
			end;

			createButton({
				name = 'Reset',
				text = 'Reset Buttons',
				backgroundColor = Color3.new(),
				offsetY = -19,
			}).MouseButton1Click:Connect(function()
				for _, touchBtn in Client.touchButtons do
					touchBtn:_resetConfigToDefault();
				end;
			end);

			createButton({
				name = 'Finish',
				text = 'Finish Editing',
				backgroundColor = Color3.fromRGB(30, 175, 30),
				offsetY = 19,
			}).MouseButton1Click:Connect(function()
				Client.configEditingMode(false);
			end);
		else
			editingTrove:Clean();
		end;
	end);
end;

function Client.new(options: TouchButtonOptions)
	Client._init();

	for _, otherTouchBtn in Client.touchButtons do
		assert(otherTouchBtn._name ~= options.name, `A TouchButton with the name {options.name} already exists`);
	end;

	local self = setmetatable({}, Client);

	self._name = options.name;
	self._desiredBtnColor = Color3.fromRGB(255, 255, 255);
	self._defaultConfig = {
		position = options.position,
		size = options.size,
	};
	self._configUpdateScheduled = false;

	task.spawn(function()
		local config = Shared.getTouchButtonConfig:InvokeServer(options.name);
		if not config then return; end;
		self:setConfig(config);
	end);

	local touchBtn = Instance.new('ImageButton');
	touchBtn.Name = 'TouchButton';
	touchBtn.Active = if options.sinkInput then true else false;
	touchBtn.Image = 'http://www.roblox.com/asset/?id=15340864550';
	touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
	touchBtn.ImageTransparency = 0.5;
	touchBtn.AnchorPoint = Vector2.new(0.5, 0.5);
	touchBtn.BackgroundTransparency = 1;
	touchBtn.Size = UDim2.fromScale(1, 1);

	local iconImage = Instance.new('ImageLabel');
	iconImage.Name = 'Icon';
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5);
	iconImage.BackgroundTransparency = 1;
	iconImage.ImageColor3 = self._desiredBtnColor;
	iconImage.ImageTransparency = 0.2;
	iconImage.Position = UDim2.fromScale(0.5, 0.5);
	iconImage.Size = UDim2.fromScale(0.56, 0.56);
	iconImage.Parent = touchBtn;

	self._touchBtn = touchBtn;

	touchBtn.InputBegan:Connect(function(input)
		if (input.UserInputType ~= Enum.UserInputType.MouseButton1) and (input.UserInputType ~= Enum.UserInputType.Touch) then return; end;
		if input.UserInputState ~= Enum.UserInputState.Begin then return; end;

		if Client.configEditingMode() then return; end;

		touchBtn.ImageColor3 = Color3.fromRGB(200, 200, 200);
		iconImage.ImageColor3 = Color3.fromRGB(200, 200, 200);

		if options.onPress then options.onPress(); end;

		local connection;
		connection = input:GetPropertyChangedSignal('UserInputState'):Connect(function()
			if input.UserInputState ~= Enum.UserInputState.End then return; end;

			connection:Disconnect();

			touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
			iconImage.ImageColor3 = self._desiredBtnColor;

			if options.onRelease then options.onRelease(); end;
		end);
	end);

	local editingTrove = Trove.new();
	local lastActive = touchBtn.Active;

	self._editEffect = Charm.effect(function()
		local isEditing = Client.configEditingMode();

		if isEditing then
			lastActive = touchBtn.Active;

			touchBtn.Active = true;
			touchBtn.ImageColor3 = EDITING_MODE_BUTTON_COLOR;
			iconImage.ImageColor3 = EDITING_MODE_BUTTON_COLOR;

			local resizeBtn = Instance.new('ImageButton');
			resizeBtn.AnchorPoint = Vector2.new(0.5, 0.5);
			resizeBtn.BackgroundTransparency = 1;
			resizeBtn.Image = 'http://www.roblox.com/asset/?id=101680714548913';
			resizeBtn.Position = UDim2.fromScale(0.82, 0.82);
			resizeBtn.Size = UDim2.fromOffset(18, 18);
			resizeBtn.Parent = touchBtn;
			editingTrove:Add(resizeBtn);

			resizeBtn.InputBegan:Connect(function(input)
				if (input.UserInputType ~= Enum.UserInputType.MouseButton1) and (input.UserInputType ~= Enum.UserInputType.Touch) then return; end;
				if input.UserInputState ~= Enum.UserInputState.Begin then return; end;

				local parent = touchBtn.Parent :: GuiObject;
				local parentSize = parent.AbsoluteSize;
				local initialAbsSize = touchBtn.AbsoluteSize;
				local initialPos = Vector2.new(input.Position.X, input.Position.Y);

				local moveConn = UserInputService.InputChanged:Connect(function(moveInput)
					if (moveInput.UserInputType ~= Enum.UserInputType.MouseMovement) and (moveInput.UserInputType ~= Enum.UserInputType.Touch) then return; end;

					local delta = Vector2.new(moveInput.Position.X, moveInput.Position.Y) - initialPos;
					local maxDelta = math.max(delta.X, delta.Y);
					local newAbsSize = initialAbsSize.X + maxDelta;

					local finalAbsSize = math.max(MIN_RESIZE, newAbsSize);
					local finalScale = finalAbsSize / parentSize.X;

					self:setSize(UDim2.fromScale(finalScale, finalScale));
				end);

				local endConn;
				endConn = UserInputService.InputEnded:Connect(function(endInput)
					if (endInput.UserInputType ~= Enum.UserInputType.MouseButton1) and (endInput.UserInputType ~= Enum.UserInputType.Touch) then return; end;

					moveConn:Disconnect();
					endConn:Disconnect();
				end);
			end);

			editingTrove:Add(touchBtn.InputBegan:Connect(function(input)
				if (input.UserInputType ~= Enum.UserInputType.MouseButton1) and (input.UserInputType ~= Enum.UserInputType.Touch) then return; end;
				if input.UserInputState ~= Enum.UserInputState.Begin then return; end;

				local parent = touchBtn.Parent :: GuiObject;
				local parentSize = parent.AbsoluteSize;
				local initialInputPos = Vector2.new(input.Position.X, input.Position.Y);
				local initialBtnPos = touchBtn.Position;

				local moveConn = UserInputService.InputChanged:Connect(function(moveInput)
					if (moveInput.UserInputType ~= Enum.UserInputType.MouseMovement) and (moveInput.UserInputType ~= Enum.UserInputType.Touch) then return; end;

					local currentPos = Vector2.new(moveInput.Position.X, moveInput.Position.Y);
					local delta = currentPos - initialInputPos;

					local deltaScale = Vector2.new(delta.X / parentSize.X, delta.Y / parentSize.Y);

					self:setPosition(UDim2.fromScale(initialBtnPos.X.Scale + deltaScale.X, initialBtnPos.Y.Scale + deltaScale.Y));
				end);

				local endConn;
				endConn = UserInputService.InputEnded:Connect(function(endInput)
					if (endInput.UserInputType ~= Enum.UserInputType.MouseButton1) and (endInput.UserInputType ~= Enum.UserInputType.Touch) then return; end;

					moveConn:Disconnect();
					endConn:Disconnect();
				end);
			end));
		else
			editingTrove:Clean();

			touchBtn.Active = lastActive;
			touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
			iconImage.ImageColor3 = self._desiredBtnColor;
		end;
	end);

	self:setIcon(options.icon);
	self:setSize(options.size);
	self:setPosition(options.position);

	local _, currentJumpBtn = getTouchGui();
	touchBtn.Parent = currentJumpBtn;

	table.insert(Client.touchButtons, self);

	return self;
end;

function Client:setIcon(icon: string)
	self._touchBtn.Icon.Image = icon;
end;

function Client:setColor(color: Color3)
	self._desiredBtnColor = color;
	self._touchBtn.Icon.ImageColor3 = color;
end;

function Client:setSize(size: UDim2)
	self._touchBtn.Size = size;
	self:_scheduleConfigUpdate();
end;

function Client:setPosition(position: UDim2)
	self._touchBtn.Position = position;
	self:_scheduleConfigUpdate();
end;

function Client:setConfig(config: Shared.TouchButtonConfig)
	self:setPosition(config.position);
	self:setSize(config.size);
end;

function Client:_scheduleConfigUpdate()
	if self._configUpdateScheduled then return; end;
	self._configUpdateScheduled = true;

	task.defer(function()
		self._configUpdateScheduled = false;
		self:_updateConfig();
	end);
end;

function Client:_updateConfig()
	Shared.setTouchButtonConfig:FireServer(self._name, {
		position = self._touchBtn.Position,
		size = self._touchBtn.Size,
	});
end;

function Client:_resetConfigToDefault()
	self:setConfig(self._defaultConfig);
end;

function Client:destroy()
	self._touchBtn:Destroy();

	if self._editEffect then
		self._editEffect();
		self._editEffect = nil;
	end

	local index = table.find(Client.touchButtons, self);
	if index then
		table.remove(Client.touchButtons, index);
	end;
end;

return Client;