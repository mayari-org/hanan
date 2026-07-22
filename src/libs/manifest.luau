local fs = zune.fs

local function serializeString(value: string): string
	return string.format("%q", value)
end

local function serializeStringMap(
	map: { [string]: string }?,
	indent: string,
	orderedKeys: { string }?,
	keyIndents: { [string]: string }?
): string?
	if not map then
		return nil
	end

	local keyList = {}
	local seen = {}

	if orderedKeys then
		for _, key in orderedKeys do
			if map[key] ~= nil and not seen[key] then
				seen[key] = true
				table.insert(keyList, key)
			end
		end
	end

	local extraKeys = {}
	for key in map do
		if not seen[key] then
			table.insert(extraKeys, key)
		end
	end
	table.sort(extraKeys)

	for _, key in extraKeys do
		table.insert(keyList, key)
	end

	if #keyList == 0 then
		return "{}"
	end

	local lines = {}
	for _, key in keyList do
		local lineIndent = (keyIndents and keyIndents[key]) or `{indent}\t`
		table.insert(lines, `{lineIndent}"{key}": {serializeString(map[key])}`)
	end

	return `\{\n{table.concat(lines, ",\n")}\n{indent}\}`
end

local function serializeArray(arr: { string }?, indent: string): string?
	if not arr then
		return nil
	end

	if #arr == 0 then
		return "[]"
	end

	local lines = {}
	for _, value in arr do
		table.insert(lines, `{indent}\t{serializeString(value)}`)
	end

	return `\[\n{table.concat(lines, ",\n")}\n{indent}\]`
end

local DEFAULT_TOP_LEVEL_ORDER: { string } = {
	"lib",
	"bin",
	"scripts",
	"engines",
	"includes",
	"dependencies",
	"dev_dependencies",
}

type KeyOrders = {
	topLevel: { string }?,
	maps: { [string]: { string } }?,
	indents: { [string]: { [string]: string } }?,
}

local function parseKeyOrders(content: string): KeyOrders
	local topLevel: { string } = {}
	local maps: { [string]: { string } } = {}
	local indents: { [string]: { [string]: string } } = {}

	local currentSection: string? = nil
	local seenTop: { [string]: boolean } = {}

	for line in content:gmatch("[^\r\n]+") do
		local topKey = line:match('^\t*"([^"]+)":%s*[{[]') or line:match('^ *"([^"]+)":%s*[{[]')
		if topKey then
			currentSection = topKey
			if not seenTop[topKey] then
				seenTop[topKey] = true
				table.insert(topLevel, topKey)
			end
			if not maps[topKey] then
				maps[topKey] = {}
				indents[topKey] = {}
			end
		else
			local isSectionEnd = line:match("^%s*[}%]],?")
			if isSectionEnd then
				currentSection = nil
			elseif currentSection then
				local prefix, itemKey = line:match('^(%s*)"([^"]+)":')
				if prefix and itemKey then
					table.insert(maps[currentSection], itemKey)
					if indents[currentSection] then
						indents[currentSection][itemKey] = prefix
					end
				end
			else
				local singleTopKey = line:match('^\t*"([^"]+)":') or line:match('^ *"([^"]+)":')
				if singleTopKey and not seenTop[singleTopKey] then
					seenTop[singleTopKey] = true
					table.insert(topLevel, singleTopKey)
				end
			end
		end
	end

	return {
		topLevel = topLevel,
		maps = maps,
		indents = indents,
	}
end

local function createManifest(config: any, keyOrders: KeyOrders?)
	local fields = {}
	local processedKeys: { [string]: boolean } = {}

	local mapsOrder = (keyOrders and keyOrders.maps) or {}
	local mapsIndents = (keyOrders and keyOrders.indents) or {}
	local topOrder: { string } = if keyOrders and keyOrders.topLevel then keyOrders.topLevel else DEFAULT_TOP_LEVEL_ORDER

	local function processKey(key: string)
		if processedKeys[key] then
			return
		end
		processedKeys[key] = true

		local val = config[key]
		if val == nil then
			return
		end

		if key == "lib" or key == "bin" or key == "name" or key == "version" or key == "description" or key == "license" then
			if type(val) == "string" then
				table.insert(fields, `\t"{key}": {serializeString(val)}`)
			end
		elseif key == "includes" then
			local str = serializeArray(val, "\t")
			if str then
				table.insert(fields, `\t"includes": {str}`)
			end
		elseif type(val) == "table" then
			local orderedSectionKeys = mapsOrder[key]
			local sectionIndents = mapsIndents[key]
			local str = serializeStringMap(val, "\t", orderedSectionKeys, sectionIndents)
			if str then
				table.insert(fields, `\t"{key}": {str}`)
			end
		elseif type(val) == "string" then
			table.insert(fields, `\t"{key}": {serializeString(val)}`)
		end
	end

	for _, key in topOrder do
		processKey(key)
	end

	for _, key in DEFAULT_TOP_LEVEL_ORDER do
		processKey(key)
	end

	for key in config do
		processKey(key)
	end

	local contents = `\{\n{table.concat(fields, ",\n")}\n\}\n`
	fs.writeFile("./hanan.json", contents)
end

local function mergeMap(currentMap: { [string]: string }?, newMap: { [string]: string }?): { [string]: string }?
	if not currentMap and not newMap then
		return nil
	end

	local merged = {}
	if currentMap then
		for k, v in currentMap do
			merged[k] = v
		end
	end

	if newMap then
		for k, v in newMap do
			merged[k] = v
		end
	end

	return merged
end

local function editManifest(currentConfig: any, newData: any)
	local updated = table.clone(currentConfig)

	if newData.lib ~= nil then
		updated.lib = newData.lib
	end

	if newData.bin ~= nil then
		updated.bin = newData.bin
	end

	if newData.scripts then
		updated.scripts = mergeMap(currentConfig.scripts, newData.scripts)
	end

	if newData.engines then
		updated.engines = mergeMap(currentConfig.engines, newData.engines)
	end

	if newData.dependencies then
		updated.dependencies = mergeMap(currentConfig.dependencies, newData.dependencies)
	end

	local currentDev = currentConfig.dev_dependencies or currentConfig["dev-dependencies"]
	local newDev = newData.dev_dependencies or newData["dev-dependencies"]
	if newDev then
		updated.dev_dependencies = mergeMap(currentDev, newDev)
	end

	local currentIncludes = currentConfig.includes
	local newIncludes = newData.includes

	if currentIncludes and newIncludes then
		local mergedIncludes = {}
		local seen = {}
		for _, v in currentIncludes do
			if not seen[v] then
				seen[v] = true
				table.insert(mergedIncludes, v)
			end
		end
		for _, v in newIncludes do
			if not seen[v] then
				seen[v] = true
				table.insert(mergedIncludes, v)
			end
		end
		updated.includes = mergedIncludes
	elseif newIncludes then
		updated.includes = table.clone(newIncludes)
	end

	local keyOrders: KeyOrders? = nil
	if fs.stat("./hanan.json") then
		local rawContent = fs.readFileSync("./hanan.json", false) :: string
		if rawContent and rawContent ~= "" then
			keyOrders = parseKeyOrders(rawContent)
		end
	end

	createManifest(updated, keyOrders)
	return updated
end

return {
	createManifest = createManifest,
	editManifest = editManifest,
}
