local Style = {}

local RESET = "\27[0m"

local BOLD_COLORS = {
	red = "\27[1;31m",
	green = "\27[1;32m",
	yellow = "\27[1;33m",
	blue = "\27[1;34m",
	purple = "\27[1;35m",
	cyan = "\27[1;36m",
}

local NORMAL_COLORS = {
	red = "\27[31m",
	green = "\27[32m",
	yellow = "\27[33m",
	blue = "\27[34m",
	purple = "\27[35m",
	cyan = "\27[36m",
}

export type COLORS = keyof<typeof(NORMAL_COLORS)>

function Style.normal(text: string, color: COLORS?)
	return `{NORMAL_COLORS[color] or ""}{text}{RESET}`
end

function Style.bold(text: string, color: COLORS?)
	return `{BOLD_COLORS[color] or "\27[1m"}{text}{RESET}`
end

return Style
