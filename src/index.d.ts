declare namespace TouchButton {
	/**
	 * Recursively builds a union of all valid path tuples for object T.
	 * E.g., { a: { b: 1 } } -> ['a'] | ['a', 'b']
	 */
	type Path<T> = T extends object
		? { [K in keyof T & string]: [K] | [K, ...Path<T[K]>] }[keyof T & string]
		: never;
	/**
	 * Resolves the type of the value at a specific path P within object T.
	 */
	type PathValue<T, P extends any[]> = P extends [infer K, ...infer R]
		? K extends keyof T
			? R extends []
				? T[K]
				: PathValue<T[K], R>
			: never
		: never;

	type Cleanup = () => void;

	interface ServerConfig<T extends object> {
		channel: string;
		replicateTo?: Player;
		data: T;
	}

	interface ReplionBase<T extends object> {
		get(): T;
		get<P extends Path<T>>(path: P): PathValue<T, P>;

		subscribe(key: undefined, callback: (newValue: T, oldValue: Partial<T>) => void): Cleanup;
		subscribe<P extends Path<T>>(
			path: P,
			callback: (newValue: PathValue<T, P>, oldValue: PathValue<T, P> | undefined) => void,
		): Cleanup;

		observe(key: undefined, callback: (newValue: T, oldValue: Partial<T>) => void): Cleanup;
		observe<P extends Path<T>>(
			path: P,
			callback: (newValue: PathValue<T, P>, oldValue: PathValue<T, P> | undefined) => void,
		): Cleanup;

		destroy(): void;
	}

	interface Server<T extends object> extends ReplionBase<T> { }
	class Server<T extends object> {
		constructor(config: ServerConfig<T>);

		set<P extends Path<T>>(
			path: P,
			value: PathValue<T, P> | ((oldValue: PathValue<T, P>) => PathValue<T, P>),
		): void;
	}

	interface Client<T extends object> extends ReplionBase<T> { }
	class Client<T extends object> {
		static waitForReplion: <T extends object>(channel: string) => Client<T>;

		private constructor();
	}
}

export = TouchButton;