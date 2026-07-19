local process = zune.process
local json5 = zune.serde.json
local fs = zune.fs

local tokenize = require("@self/tokenize")

local function execute(args: { string })
    local jsonContent = fs.readFileSync(`{process.cwd()}/hanan.json`)
    local manifestContent: ManifestTemplate = json5.decode(jsonContent)

    local scriptName = args[1]
    local subcmd = nil

    if manifestContent.scripts then
        subcmd = manifestContent.scripts[scriptName]
    end

    if not subcmd then
        error("Unknown script")
    end
    
    print(`\n> {subcmd}\n`)

    for _, group in tokenize(subcmd) do
        local result = process.run(group.command, group.args, { 
            stdout = "inherit",
            stdin = "inherit",
            stderr = "inherit"
        })
        if result.code ~= 0 then
            break
        end
    end
end

return {
    execute = execute,
    desc = "runs a command from the hanan manifest",
}