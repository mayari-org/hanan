local select = require("../libs/cli/select")
local process = zune.process

local function exectute()
	local runtime = select.select("Select a runtime:", {
		{ label = "Lute", value = "lute", hint = "Built in C++" },
		{ label = "Lune", value = "lune", hint = "Built in Rust" },
		{ label = "Zune", value = "zune", hint = "Built in Zig" },
	})

	if not runtime then
		process.exit(1)
	end

	local pm = select.select("Select a package manager:", {
		{ label = "NPM", value = "npm", hint = "Node Package Manager" },
		{ label = "LPM", value = "lpm", hint = "Luau Package Manager" },
		{ label = "Bun", value = "bun", hint = "Bun Package Manager" },
	})

	if not pm then
		process.exit(1)
	end
end

return {
	execute = exectute,
	desc = "initializes a Hanan manifest",
}
