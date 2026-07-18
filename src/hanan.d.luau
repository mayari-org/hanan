export type Command = {
	[string]: {
		execute: (...any) -> ...any,
		desc: string,
	},
}

export type ManifestTemplate = {
	scripts: { [string]: string }?,
	lib: string?,
	bin: string?,
	runtimes: { [string]: string }?,
	includes: { string }?,
	dependencies: { [string]: string }?,
	dev_dependencies: { [string]: string }?,
}
