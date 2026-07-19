-- local process = zune.process

-- local function getVersion()
-- 	local result = process.run("git", {"describe", "--tags", "--always", "--dirty"}, {
--         stdout = "pipe",
--         stderr = "pipe",
--     })
-- 	if result.ok then
-- 		return ((result.stdout or ""):gsub("%s+$", ""))
-- 	end
-- 	return "unknown"
-- end

local ver = require("@self/ver") :: any

local function exectute()
	print(`{ver}`)
end

return exectute
