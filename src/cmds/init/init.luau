local select = require("@libs/cli/select")
local createManifest = require("@libs/manifest").createManifest
local fetchEngineVersion = require("@libs/fetchEngineVersion")

local engines = {
    lute = "luau-lang/lute",
    lune = "lune-org/lune",
    zune = "Scythe-Technology/zune"
}

local manifestTemplate: ManifestTemplate = {
    scripts = {
        ["test"] = "echo \"Error: no test specified\" && exit 1",
    },
}

local function execute(_, flags: { [string]: boolean }?)
	if flags and flags["y"] then
        manifestTemplate.engines = {
            lute = `>={fetchEngineVersion(engines.lute)}`
        }
    else
        local runtime = select.select("Select a runtime:", {
            { label = "Lute", value = "lute", hint = "Built in C++" },
            { label = "Lune", value = "lune", hint = "Built in Rust" },
            { label = "Zune", value = "zune", hint = "Built in Zig" },
        }) :: string

        manifestTemplate.engines = {
            [runtime] = `>={fetchEngineVersion(engines[runtime])}`
        }
	end

    createManifest(manifestTemplate)
end

return {
	execute = execute,
	desc = "initializes a Hanan manifest",
}
