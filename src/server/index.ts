import { DataStoreService, RunService } from '@rbxts/services';
import { remotes, TouchButtonConfig } from '../shared/remotes';
import { observePlayers } from '@rbxts/roblox-observers';
import Signal from '@rbxts/sleitnick-signal';

type DataStoreEntry = Record<string, TouchButtonConfig>;
type SerializedDataStoreEntry = Record<string, SerializedTouchButtonConfig>;

type Serialized<T> =
	T extends Vector2 ? [number, number] :
	T extends UDim2 ? [number, number, number, number] :
	never;
type SerializedTouchButtonConfig = {[K in keyof TouchButtonConfig]: Serialized<TouchButtonConfig[K]>};

const entriesCache = new Map<Player, DataStoreEntry>();

const playerDataLoaded = new Signal<[Player, DataStoreEntry]>();

let initialized = false;

function getDataStoreKeyForPlayer(player: Player) {
    return `Player${player.UserId}`;
}

function waitForEntry(player: Player) {
    let entry = entriesCache.get(player);
    if (!entry) {
        let loadedPlayer: Player, loadedEntry: DataStoreEntry;
        do {
            [loadedPlayer, loadedEntry] = playerDataLoaded.Wait();
        } while (loadedPlayer !== player);
        entry = loadedEntry;
    };
    return entry;
}

function serializeEntry(entry: DataStoreEntry) {
    const res: SerializedDataStoreEntry = {};

    for (const [buttonName, props] of pairs(entry)) {
        const serializedProps: Partial<SerializedTouchButtonConfig> = {};

        for (const [propKey, propValue] of pairs(props)) {
            let serializedProp: any;

            if (typeIs(propValue, 'Vector2')) {
                serializedProp = [propValue.X, propValue.Y];
            } else if (typeIs(propValue, 'UDim2')) {
                serializedProp = [propValue.X.Scale, propValue.X.Offset, propValue.Y.Scale, propValue.Y.Offset];
            }

            serializedProps[propKey] = serializedProp;
        }

        res[buttonName] = serializedProps as SerializedTouchButtonConfig;
    }

    return res;
}

function deserializeEntry(entry: SerializedDataStoreEntry) {
    const res: DataStoreEntry = {};

    for (const [buttonName, serializedProps] of pairs(entry)) {
        const props: Partial<TouchButtonConfig> = {};

        for (const [propKey, serializedValue] of pairs(serializedProps)) {
            let deserializedProp: any;

            if (serializedValue.size() === 2) {
                deserializedProp = new Vector2(serializedValue[0], serializedValue[1]);
            } else if (serializedValue.size() === 4) {
                deserializedProp = new UDim2(serializedValue[0], serializedValue[1], serializedValue[2] as number, serializedValue[3] as number);
            }

            props[propKey] = deserializedProp;
        }

        res[buttonName] = props as TouchButtonConfig;
    }

    return res;
}

export namespace TouchButtonServer {
    export function init(validTouchButtonNames: Set<string>) {
        assert(RunService.IsServer(), 'TouchButtonServer can only be initialized from the server');

        assert(!initialized, 'TouchButtonServer already initialized');
        initialized = true;

        const buttonsStore = DataStoreService.GetDataStore('TouchButtonConfigs');

        remotes.getTouchButtonConfig.onRequest((player, buttonName) => {
            const entry = waitForEntry(player);

            return entry[buttonName];
        });

        remotes.setTouchButtonConfig.connect((player, buttonName, config) => {
            assert(validTouchButtonNames.has(buttonName), `[TOUCH BUTTONS] ${buttonName} is not a valid savable TouchButton name`);

            const entry = waitForEntry(player);

            entry[buttonName] = config;
        });

        observePlayers((player) => {
            const key = getDataStoreKeyForPlayer(player);

            const [suc, entryOrUndefinedOrErr] = pcall(() => {
                return buttonsStore.GetAsync(key);
            })
            if (!suc) {
                warn(`[TOUCH BUTTONS] Failed to load DataStore entry:`, entryOrUndefinedOrErr);
                return;
            }

            let entry = entryOrUndefinedOrErr ? deserializeEntry(entryOrUndefinedOrErr as SerializedDataStoreEntry) : {};

            entriesCache.set(player, entry);
            playerDataLoaded.Fire(player, entry);

            return () => {
                const entry = entriesCache.get(player);
                if (!entry) return;

                buttonsStore.SetAsync(key, serializeEntry(entry), [player.UserId]);
            };
        });
    }
}
