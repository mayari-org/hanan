local process = zune.process

local style = require("@libs/cli/style")

local function hananErr<T>(msg: T, exitCode: number?)
    print(`hanan {style.normal("[error]", "red")} {msg}`)
    process.exit(exitCode or 1)
end

return hananErr
