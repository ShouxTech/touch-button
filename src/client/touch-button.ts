import { observeProperty } from '@rbxts/roblox-observers/out/observe-property';
import { Players, UserInputService, Workspace } from '@rbxts/services';
import { remotes, TouchButtonConfig } from '../shared/remotes';
import { atom, effect } from '@rbxts/charm';
import { Trove } from '@rbxts/trove';

const localPlayer = Players.LocalPlayer;
const camera = Workspace.CurrentCamera!;

let touchGui: ScreenGui | undefined;
let jumpBtn: Frame | undefined;

const EDITING_MODE_BUTTON_COLOR = Color3.fromRGB(15, 143, 255);
const MIN_RESIZE = 40;

// This is taken from TouchJump.lua in PlayerScripts.
function getJumpButtonLayout() {
    const minAxis = math.min(camera.ViewportSize.X, camera.ViewportSize.Y);
    const isSmallScreen = minAxis <= 500;
    const jumpButtonSize = isSmallScreen ? 70 : 120;

    return {
        size: UDim2.fromOffset(jumpButtonSize, jumpButtonSize),
        position: isSmallScreen ? new UDim2(1, -(jumpButtonSize*1.5-10), 1, -jumpButtonSize - 20) :
            new UDim2(1, -(jumpButtonSize*1.5-10), 1, -jumpButtonSize * 1.75),
    };
}

function getTouchGui() {
    if (touchGui && jumpBtn) return [touchGui, jumpBtn];

    touchGui = new Instance('ScreenGui');
    touchGui.Name = 'CustomTouchGui';
    touchGui.ResetOnSpawn = false;
    touchGui.Parent = localPlayer['PlayerGui' as keyof typeof localPlayer] as PlayerGui;

    jumpBtn = new Instance('Frame');
    jumpBtn.Name = 'Jump';
    jumpBtn.BackgroundTransparency = 1;
    observeProperty(camera, 'ViewportSize', () => {
        const jumpBtnLayout = getJumpButtonLayout();
        jumpBtn!.Position = jumpBtnLayout.position;
        jumpBtn!.Size = jumpBtnLayout.size;
    });
    jumpBtn.Parent = touchGui;

    const characterExists = atom(!!localPlayer.Character);
    const lastInputType = atom(UserInputService.GetLastInputType());
    effect(() => {
        const charExists = characterExists();
        const inputType = lastInputType();

        touchGui!.Enabled = (inputType === Enum.UserInputType.Touch) && charExists;
    });

    localPlayer.CharacterAdded.Connect(() => {
        characterExists(true);
    });
    localPlayer.CharacterRemoving.Connect(() => {
        characterExists(false);
    });

    UserInputService.LastInputTypeChanged.Connect(lastInputType);

    return [touchGui, jumpBtn];
}

export class TouchButton {
    public static configEditingMode = atom(false);
    public static touchButtons: TouchButton[] = [];

    private static initialized = false;

    private touchBtn;
    private name: string;
    private defaultConfig: TouchButtonConfig;

	private configUpdateScheduled = false;

    private static init() {
        if (this.initialized) return;
        this.initialized = true;

        const editingTrove = new Trove();
        effect(() => {
            const isEditing = TouchButton.configEditingMode();
            if (isEditing) {
                const resetBtn = new Instance('TextButton');
                resetBtn.Name = 'Reset';
                resetBtn.AnchorPoint = new Vector2(0.5, 0.5);
                resetBtn.BackgroundColor3 = new Color3();
                resetBtn.BackgroundTransparency = 0.25;
                resetBtn.FontFace = new Font(
                    'rbxasset://fonts/families/GothamSSm.json',
                    Enum.FontWeight.Medium,
                    Enum.FontStyle.Normal
                );
                resetBtn.Position = UDim2.fromScale(0.5, 0.5);
                resetBtn.Size = UDim2.fromOffset(120, 32);
                resetBtn.Text = 'Reset Buttons';
                resetBtn.TextColor3 = new Color3(1, 1, 1);
                resetBtn.TextSize = 16;
                resetBtn.Parent = touchGui;
                editingTrove.add(resetBtn);

                const UICorner = new Instance('UICorner');
                UICorner.CornerRadius = new UDim(0, 5);
                UICorner.Parent = resetBtn;

                resetBtn.MouseButton1Click.Connect(() => {
                    for (const touchBtn of TouchButton.touchButtons) {
                        touchBtn.resetConfigToDefault();
                    }
                });
            } else {
                editingTrove.clean();
            }
        });
    }

    constructor(options: {name: string, icon: string, size: UDim2, position: UDim2, onPress?: () => void, onRelease?: () => void}) {
        TouchButton.init();

        for (const otherTouchBtn of TouchButton.touchButtons) {
            assert(otherTouchBtn.name !== options.name, `A TouchButton with the name ${options.name} already exists`);
        }

        this.name = options.name;
        this.defaultConfig = {
            position: options.position,
            size: options.size,
        };

        const configPromise = remotes.getTouchButtonConfig.request(options.name);

        const touchBtn = new Instance('ImageButton');
        touchBtn.Name = 'TouchButton';
        touchBtn.Active = false; // Allow for camera movement while pressing button.
        touchBtn.Image = 'http://www.roblox.com/asset/?id=15340864550';
        touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
        touchBtn.ImageTransparency = 0.5;
        touchBtn.AnchorPoint = new Vector2(0.5, 0.5);
        touchBtn.BackgroundTransparency = 1;
        touchBtn.Size = UDim2.fromScale(1, 1);

        const iconImage = new Instance('ImageLabel');
        iconImage.Name = 'Icon';
        iconImage.AnchorPoint = new Vector2(0.5, 0.5);
        iconImage.BackgroundTransparency = 1;
        iconImage.ImageTransparency = 0.2;
        iconImage.Position = UDim2.fromScale(0.5, 0.5);
        iconImage.Size = UDim2.fromScale(0.56, 0.56);
        iconImage.Parent = touchBtn;

        touchBtn.InputBegan.Connect((input) => {
            if ((input.UserInputType !== Enum.UserInputType.MouseButton1) && (input.UserInputType !== Enum.UserInputType.Touch)) return;
            if (input.UserInputState !== Enum.UserInputState.Begin) return;

            if (TouchButton.configEditingMode()) return;

            touchBtn.ImageColor3 = Color3.fromRGB(200, 200, 200);
            iconImage.ImageColor3 = Color3.fromRGB(200, 200, 200);
            options.onPress?.();

            const connection = input.GetPropertyChangedSignal('UserInputState').Connect(() => {
                if (input.UserInputState !== Enum.UserInputState.End) return;

                connection.Disconnect();

                touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
                iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255);
                options.onRelease?.();
            });
        });

        const editingTrove = new Trove();
        effect(() => {
            const isEditing = TouchButton.configEditingMode();

            if (isEditing) {
                touchBtn.Active = true;
                touchBtn.ImageColor3 = EDITING_MODE_BUTTON_COLOR;
                iconImage.ImageColor3 = EDITING_MODE_BUTTON_COLOR;

                const resizeBtn = new Instance('ImageButton');
                resizeBtn.AnchorPoint = new Vector2(0.5, 0.5);
                resizeBtn.BackgroundTransparency = 1;
                resizeBtn.Image = 'http://www.roblox.com/asset/?id=101680714548913';
                resizeBtn.Position = UDim2.fromScale(0.82, 0.82);
                resizeBtn.Size = UDim2.fromOffset(18, 18);
                resizeBtn.Parent = touchBtn;
                editingTrove.add(resizeBtn);

                resizeBtn.InputBegan.Connect((input) => {
                    if ((input.UserInputType !== Enum.UserInputType.MouseButton1) && (input.UserInputType !== Enum.UserInputType.Touch)) return;
                    if (input.UserInputState !== Enum.UserInputState.Begin) return;

                    const parentSize = (touchBtn.Parent as GuiObject).AbsoluteSize;
                    const initialAbsSize = touchBtn.AbsoluteSize;
                    const initialPos = new Vector2(input.Position.X, input.Position.Y);

                    const moveConn = UserInputService.InputChanged.Connect((moveInput) => {
                        if ((moveInput.UserInputType !== Enum.UserInputType.MouseMovement) && (moveInput.UserInputType !== Enum.UserInputType.Touch)) return;

                        const delta = new Vector2(moveInput.Position.X, moveInput.Position.Y).sub(initialPos);
                        const maxDelta = math.max(delta.X, delta.Y);
                        const newAbsSize = initialAbsSize.X + maxDelta;

                        const finalAbsSize = math.max(MIN_RESIZE, newAbsSize);
                        const finalScale = finalAbsSize / parentSize.X;

                        this.setSize(UDim2.fromScale(finalScale, finalScale));
                    });

                    const endConn = UserInputService.InputEnded.Connect((endInput) => {
                        if ((endInput.UserInputType !== Enum.UserInputType.MouseButton1) && (endInput.UserInputType !== Enum.UserInputType.Touch)) return;

                        moveConn.Disconnect();
                        endConn.Disconnect();
                    });
                });

                editingTrove.add(touchBtn.InputBegan.Connect((input) => {
                    if ((input.UserInputType !== Enum.UserInputType.MouseButton1) && (input.UserInputType !== Enum.UserInputType.Touch)) return;
                    if (input.UserInputState !== Enum.UserInputState.Begin) return;

                    const parentSize = (touchBtn.Parent as GuiObject).AbsoluteSize;
                    const initialInputPos = new Vector2(input.Position.X, input.Position.Y);
                    const initialBtnPos = touchBtn.Position;

                    const moveConn = UserInputService.InputChanged.Connect((moveInput) => {
                        if ((moveInput.UserInputType !== Enum.UserInputType.MouseMovement) && (moveInput.UserInputType !== Enum.UserInputType.Touch)) return;

                        const currentPos = new Vector2(moveInput.Position.X, moveInput.Position.Y);
                        const delta = currentPos.sub(initialInputPos);

                        const deltaScale = new Vector2(delta.X / parentSize.X, delta.Y / parentSize.Y);

                        this.setPosition(UDim2.fromScale(initialBtnPos.X.Scale + deltaScale.X, initialBtnPos.Y.Scale + deltaScale.Y));
                    });

                    const endConn = UserInputService.InputEnded.Connect((endInput) => {
                        if ((endInput.UserInputType !== Enum.UserInputType.MouseButton1) && (endInput.UserInputType !== Enum.UserInputType.Touch)) return;

                        moveConn.Disconnect();
                        endConn.Disconnect();
                    });
                }));
            } else {
                editingTrove.clean();

                touchBtn.Active = false;
                touchBtn.ImageColor3 = Color3.fromRGB(255, 255, 255);
                iconImage.ImageColor3 = Color3.fromRGB(255, 255, 255);
            }
        });

        this.touchBtn = touchBtn as ImageButton & {
            Icon: ImageLabel;
        };

        this.setIcon(options.icon);
        this.setSize(options.size);
        this.setPosition(options.position);
        configPromise.then((config) => {
            if (!config) return;
            this.setConfig(config);
        });

        const [_, jumpBtn] = getTouchGui();
        touchBtn.Parent = jumpBtn;

        TouchButton.touchButtons.push(this);
    }

    public setIcon(icon: string) {
        this.touchBtn.Icon.Image = icon;
    }

    public setSize(size: UDim2) {
        this.touchBtn.Size = size;
        this.scheduleConfigUpdate();
    }

    public setPosition(position: UDim2) {
        this.touchBtn.Position = position;
        this.scheduleConfigUpdate();
    }

    // Convenience for loading a whole config instead of calling set functions manually.
    public setConfig(config: TouchButtonConfig) {
        this.setPosition(config.position);
        this.setSize(config.size);
    }

    private scheduleConfigUpdate() {
        if (this.configUpdateScheduled) return;
        this.configUpdateScheduled = true;

        task.defer(() => {
            this.configUpdateScheduled = false;
            this.updateConfig();
        });
    }

    private updateConfig() {
        remotes.setTouchButtonConfig.fire(this.name, {
            position: this.touchBtn.Position,
            size: this.touchBtn.Size,
        });
    }

    private resetConfigToDefault() {
        this.setConfig(this.defaultConfig);
    }

    public destroy() {
        this.touchBtn.Destroy();
        TouchButton.touchButtons.remove(TouchButton.touchButtons.indexOf(this));
    }
}
