-- scaffold-apply.luau (Lute-side)
local process = require("@lute/process")

-- process.args[1] is the script path itself (e.g. "src/index"),
-- so real arguments start at index 2.
local templateArg = process.args[2]

if not templateArg then
	error("Usage: lute run src/index <template>")
end

print(`Scaffolding template: {templateArg}`)
-- ... fs work using templateArg, via Lute's fs adapter