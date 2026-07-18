local process = zune.process
local version = require("./cmds/version")
local cmds = require("./cmdList")

local subcmd: string? = nil
local args: { string } = {}
local flags: { [string]: boolean } = {}
local stopParsingFlags = false

(function()
	for index, token in process.args do
		if index == 1 then
			continue
		end

		if index == 2 then
			if token == "--version" or token == "-v" then
				version()
				return
			end

			subcmd = token
			continue
		end

		if stopParsingFlags then
			table.insert(args, token)
			continue
		end

		if token == "--" then
			stopParsingFlags = true
			continue
		end

		if string.sub(token, 1, 2) == "--" then
			local flagName = string.sub(token, 3)
			flags[flagName] = true
			continue
		end

		if string.sub(token, 1, 1) == "-" then
			local flagName = string.sub(token, 2)
			flags[flagName] = true
			continue
		end

		table.insert(args, token)
	end

	if not subcmd then
		cmds.help.execute(cmds)
		return
	end

	local cmd = cmds[subcmd]

	if not cmd then
		print("Command does not exist")
		process.exit(1)
	elseif subcmd == "help" then
		cmds.help.execute(cmds, args)
		return
	end

	for flag, _ in flags do
		if not flags[flag] then
			print("Unknown flag: " .. flag)
			process.exit(1)
		else
			print("Flag: " .. flag)
		end
	end

	cmd.execute(args, flags)
end)()
