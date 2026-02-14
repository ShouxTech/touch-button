--!strict
local DataStoreService = game:GetService('DataStoreService');
local Players = game:GetService('Players');

local Shared = require(script.Parent.Shared);
local isTypeScriptEnv = script.Parent.Name == 'src';
local dependencies = if isTypeScriptEnv then script.Parent.Parent.Parent else script.Parent.Parent;
local Signal = require(isTypeScriptEnv and dependencies['sleitnick-signal'] or dependencies.Signal);

type DataStoreEntry = { [string]: Shared.TouchButtonConfig };
type SerializedTouchButtonConfig = { [string]: {number} };
type SerializedDataStoreEntry = { [string]: SerializedTouchButtonConfig };

local entriesCache: { [Player]: DataStoreEntry } = {};
local playerDataLoaded = Signal.new();
local initialized = false;

local function getDataStoreKeyForPlayer(player: Player)
	return `Player{player.UserId}`;
end;

local function waitForEntry(player: Player)
	local entry = entriesCache[player];
	if not entry then
		local loadedPlayer, loadedEntry;
		repeat
			loadedPlayer, loadedEntry = playerDataLoaded:Wait();
		until loadedPlayer == player;
		entry = loadedEntry;
	end;
	return entry;
end;

local function serializeEntry(entry: DataStoreEntry)
	local res: SerializedDataStoreEntry = {};

	for buttonName, props in entry do
		local serializedProps: SerializedTouchButtonConfig = {};

		for propKey, propValue in props do
			local serializedProp;

			if typeof(propValue) == 'Vector2' then
				serializedProp = { propValue.X, propValue.Y };
			elseif typeof(propValue) == 'UDim2' then
				serializedProp = { propValue.X.Scale, propValue.X.Offset, propValue.Y.Scale, propValue.Y.Offset };
			end;

			if serializedProp then
				serializedProps[propKey] = serializedProp;
			end;
		end;

		res[buttonName] = serializedProps;
	end;

	return res;
end;

local function deserializeEntry(entry: SerializedDataStoreEntry)
	local res: DataStoreEntry = {};

	for buttonName, serializedProps in entry do
		local props: Shared.TouchButtonConfig = {};

		for propKey, serializedValue in serializedProps do
			local deserializedProp;

			if #serializedValue == 2 then
				deserializedProp = Vector2.new(serializedValue[1], serializedValue[2]);
			elseif #serializedValue == 4 then
				deserializedProp = UDim2.new(serializedValue[1], serializedValue[2], serializedValue[3], serializedValue[4]);
			end;

			props[propKey] = deserializedProp;
		end;

		res[buttonName] = props;
	end;

	return res;
end;

local function isDictOfSize(dict: { [unknown]: unknown }, size: number)
	local dictSize = 0;
	for _ in dict do
		dictSize += 1;
		if dictSize > size then return false; end;
	end;
	return dictSize == size;
end;

local Server = {};

function Server.init(validTouchButtonNames: { string })
	assert(not initialized, 'TouchButton.Server already initialized');
	initialized = true;

	local buttonsStore = DataStoreService:GetDataStore('TouchButtonConfigs');

	Shared.getTouchButtonConfig.OnServerInvoke = function(player: Player, buttonName: string)
		local entry = waitForEntry(player);
		return entry[buttonName];
	end;

	Shared.setTouchButtonConfig.OnServerEvent:Connect(function(player: Player, buttonName: string, config: Shared.TouchButtonConfig)
		assert(table.find(validTouchButtonNames, buttonName), `TouchButton: {buttonName} is not a valid savable TouchButton name`);

		if typeof(config) ~= 'table' then return; end;
		if not config.size then return; end;
		if not config.position then return; end;
		if not isDictOfSize(config, 2) then return; end;

		local entry = waitForEntry(player);
		entry[buttonName] = config;
	end);

	local function onPlayerAdded(player: Player)
		local key = getDataStoreKeyForPlayer(player);

		local suc, entryOrUndefinedOrErr = pcall(function()
			return buttonsStore:GetAsync(key);
		end);
		if not suc then
			warn('TouchButton: Failed to load DataStore entry:', entryOrUndefinedOrErr);
			return;
		end;

		if not player:IsDescendantOf(Players) then return; end;

		local entry = if entryOrUndefinedOrErr then deserializeEntry(entryOrUndefinedOrErr) else {};

		entriesCache[player] = entry;
		playerDataLoaded:Fire(player, entry);
	end;

	local function onPlayerRemoving(player: Player)
		local entry = entriesCache[player];
		if not entry then return; end;

		local key = getDataStoreKeyForPlayer(player);
		local serialized = serializeEntry(entry);

		local suc, err = pcall(function()
			buttonsStore:SetAsync(key, serialized, { player.UserId });
		end);
		if not suc then
			warn(`TouchButton: Failed to save data for {player.Name}:`, err);
		end;

		entriesCache[player] = nil;
	end;

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player);
	end;
	Players.PlayerAdded:Connect(onPlayerAdded);
	Players.PlayerRemoving:Connect(onPlayerRemoving);
end;

return Server;