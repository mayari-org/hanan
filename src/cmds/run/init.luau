local process = zune.process
local json5 = zune.serde.json
local fs = zune.fs

local tokenize = require("@self/tokenize")
local hananErr = require("@libs/hananErr")

local function execute(args: { string })
    local jsonContent = fs.readFileSync(`{process.cwd()}/hanan.json`)
    local manifestContent: ManifestTemplate = json5.decode(jsonContent)

    local scriptName = args[1]
    local scrpt = nil

    if manifestContent.scripts then
        scrpt = manifestContent.scripts[scriptName]
    end

    if not scrpt then
        hananErr(`Script "{scriptName}" does not exist`)
        return
    end
    
    print(`\n> {scrpt}\n`)

    for _, group in tokenize(scrpt) do
        if group.command == "exit" then
            local exitCode = tonumber(group.args[1])
            
            if not exitCode then
                hananErr(`Illegal exit code: {group.args[1]}`)
                break
            end

            process.exit(exitCode)
            break
        end
        
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
    desc = "runs a script from the hanan manifest",
}