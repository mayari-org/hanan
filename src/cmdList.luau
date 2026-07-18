local cmds: Command = {
	init = require("./cmds/init"),
	add = require("./cmds/add"),
	help = require("./cmds/help"),
}

return cmds
