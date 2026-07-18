local process = zune.process
local fs = zune.fs
local io = zune.io

local success, _e = pcall(function()
    return fs.readFileSync("./hanan")
end)

if success then
    fs.deleteFile("./hanan")
end

local result = process.run("zune", { 
    "bundle", 
    "src/index.luau", 
    "src/**/*.luau", 
    "--out=dist/hanan",
    "--release",
}, {
    stderr = "inherit",
    stdin = "inherit",
    stdout = "inherit"
})

if not result.ok then
    io.stderr:write(result.stderr :: string)
end
