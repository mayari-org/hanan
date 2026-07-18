local io = zune.io
local task = zune.task
local process = zune.process
local style = require("./style")
local ansi = require("./ansi")

local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local INTERVAL = 0.08

if process and process.onSignal then
	process.onSignal("INT", function()
		io.terminal.restoreMode()
		io.stdout:writeSync(
			ansi.ESC .. "[2K\r" .. style.normal("✖ ", "red") .. "Cancelled" .. ansi.showCursor() .. "\n"
		)
	end)
end

local Spinner = {}
Spinner.__index = Spinner

export type Spinner = {
	start: (self: Spinner) -> (),
	stop: (self: Spinner, symbol: string, finalLabel: string?) -> (),
	label: string,
	thread: thread?,
}

function Spinner.new(label: string)
	local self = setmetatable({} :: Spinner, Spinner)
	self.label = label
	self.thread = nil
	return self
end

function Spinner.start(self: Spinner)
	io.terminal.enableRawMode() -- disables ECHO, stops the terminal printing ^C itself
	io.stdout:write(ansi.hideCursor())

	self.thread = task.spawn(function()
		local frameIndex = 1
		while true do
			local frame = style.normal(FRAMES[frameIndex], "cyan")
			io.stdout:write(`\r{frame} {self.label}`)

			frameIndex = if frameIndex == #FRAMES then 1 else frameIndex + 1
			task.wait(INTERVAL)
		end
	end)
end

function Spinner.stop(self: Spinner, symbol: string, finalLabel: string?)
	if self.thread then
		task.cancel(self.thread)
		self.thread = nil
	end

	io.stdout:write(ansi.ESC .. "[2K\r") -- erase-line, correct regardless of label/frame length
	io.stdout:write(`{symbol} {finalLabel or self.label}\n`)

	io.stdout:write(ansi.showCursor())
	io.terminal.restoreMode()
end

return Spinner
