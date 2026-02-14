declare namespace TouchButton {
    interface TouchButtonConfig {
        position: UDim2;
        size: UDim2;
    }

    interface TouchButtonOptions {
        name: string;
        icon: string;
        size: UDim2;
        position: UDim2;
        sinkInput?: boolean;
        onPress?: () => void;
        onRelease?: () => void;
    }

    namespace Server {
        function init(validTouchButtonNames: string[]): void;
    }

    class Client {
        static touchButtons: Client[];
        static configEditingMode: (enabled?: boolean) => boolean;

        constructor(options: TouchButtonOptions);

        setIcon(icon: string): void;
        setColor(color: Color3): void;
        setSize(size: UDim2): void;
        setPosition(position: UDim2): void;
        setConfig(config: TouchButtonConfig): void;
        destroy(): void;
    }
}

export = TouchButton;