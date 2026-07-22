local style = require("@libs/cli/style")

local function hananWarn<T>(msg: T)
    print(`hanan {style.normal("[warn]", "yellow")} {msg}`)
end

return hananWarn
