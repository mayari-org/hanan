local process = zune.process
local fs = zune.fs
local io = zune.io
local platform = zune.platform

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

local binaryName = ""

if platform.os == "windows" then
    binaryName = "hanan.exe"
else
    binaryName = "hanan"
end

local result = process.run("zune", { 
    "bundle", 
    "src/index.luau", 
    "src/**/*.luau",
    "-f",
    ".luaurc",
    `--out=dist/{binaryName}`,
    "--release",
}, {
    stderr = "inherit",
    stdin = "inherit",
    stdout = "inherit"
})

if not result.ok then
    io.stderr:write(result.stderr :: string)
end
