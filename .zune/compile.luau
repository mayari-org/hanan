local process = zune.process
local fs = zune.fs
local io = zune.io

local success, _e = pcall(function()
    return fs.readFileSync("./hanan")
end)

if success then
    fs.deleteFile("./hanan")
end

local function getVersion()
	local result = process.run("git", {"describe", "--tags", "--abbrev=0", "--always"})
	if result.ok then
		return ((result.stdout or ""):gsub("%s+$", ""))
	end
	return "unknown"
end

fs.writeFile("src/cmds/version/ver.luau", `-- AUTO-GENERATED, do not edit\nreturn "{getVersion()}"\n`)

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
