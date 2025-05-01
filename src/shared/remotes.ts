import { createRemotes, remote, Server } from '@rbxts/remo';
import { t } from '@rbxts/t';

export interface TouchButtonConfig {
    position: UDim2,
    size: UDim2,
}

export const remotes = createRemotes({
    getTouchButtonConfig: remote<Server, [buttonName: string]>(t.string).returns<TouchButtonConfig | undefined>(),
    setTouchButtonConfig: remote<Server, [buttonName: string, config: TouchButtonConfig]>(t.string, t.strictInterface({
        position: t.UDim2,
        size: t.UDim2,
    })),
});
