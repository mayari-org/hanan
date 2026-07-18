local style = require("../libs/cli/style")

local function execute(cmds: Command, _: any)
	print(style.bold("Hanan", "yellow") .. " - A Luau Package Manager\n")
	print(style.bold("Usage: hanan <command> [options] [...args]\n"))
	print(style.bold("Commands:"))

	local max_length = 0

	for name, _ in cmds do
		if #name > max_length then
			max_length = #name
		end
	end

	local extra_padding = 4

	for i, v in cmds do
		local padding_needed = max_length - #i + extra_padding
		local spaces = string.rep(" ", padding_needed)
		print("  " .. style.bold(i, "green") .. spaces .. v.desc)
	end
end

return {
	execute = execute,
	desc = "Display help information about Hanan and its commands.",
}
