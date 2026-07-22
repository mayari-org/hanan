local fetchPackage = require("@libs/fetch")
local hananErr = require("@libs/hananErr")
local hananWarn = require("@libs/hananWarn")
local manifest = require("@libs/manifest")
local Spinner = require("@libs/cli/spinner")
local style = require("@libs/cli/style")

local fs = zune.fs
local json = zune.serde.json
local process = zune.process

type ParsedPkg = {
	raw: string,
	owner: string,
	repo: string,
	tag: string?,
}

local function parsePackageSpec(spec: string): ParsedPkg?
	if not spec or spec == "" then
		return nil
	end

	local owner, rest = spec:match("^([^/]+)/(.+)$")
	if not owner or not rest then
		return nil
	end

	local repo, tag = rest:match("^([^@]+)@?(.*)$")
	if not repo or repo == "" then
		return nil
	end

	if tag == "" then
		tag = nil
	end

	return {
		raw = spec,
		owner = owner,
		repo = repo,
		tag = tag,
	}
end

local function loadManifest(): any
	if fs.stat("./hanan.json") then
		local content = fs.readFileSync("./hanan.json", false) :: string
		if content and content ~= "" then
			local ok, data = pcall(json.decode, content, nil)
			if ok and type(data) == "table" then
				return data
			end
		end
	end

	return {}
end

local function formatVersionCaret(tag: string): string
	local clean = tag:gsub("^v", "")
	return `^{clean}`
end

local function execute(args: { string }, _flags: { [string]: boolean })
	if #args == 0 then
		hananErr("No package specified. Usage: hanan add <owner>/<repo>[@<version>] ...")
		return
	end

	local parsedList: { ParsedPkg } = {}
	for _, arg in args do
		local parsed = parsePackageSpec(arg)
		if not parsed then
			hananErr(`Invalid package format "{arg}". Expected "<owner>/<repo>" or "<owner>/<repo>@<version>"`)
			return
		end
		table.insert(parsedList, parsed)
	end

	local totalCount = #parsedList
	local label = if totalCount == 1 then "Installing package..." else "Installing packages..."

	local spinner = Spinner.new(label)
	spinner:start()

	local currentConfig = loadManifest()
	local newDependencies = {}
	local installedSpecs: { string } = {}
	local warnings: { string } = {}
	local errors: { string } = {}

	for _, pkg in parsedList do
		local res = fetchPackage({
			owner = pkg.owner,
			repo = pkg.repo,
			tag = pkg.tag,
		})

		if not res.success then
			table.insert(errors, res.errorMsg or `failed to fetch package "{pkg.raw}"`)
		else
			if res.warningMsg then
				table.insert(warnings, res.warningMsg)
			end

			local installedTag = res.ref or pkg.tag or "latest"
			local installedString = `{pkg.owner}/{pkg.repo}@{installedTag}`
			table.insert(installedSpecs, installedString)

			local depKey = `{pkg.owner}/{pkg.repo}`
			local depValue = formatVersionCaret(installedTag)
			newDependencies[depKey] = depValue
		end
	end

	spinner:stop()

	-- Print any non-fatal warnings
	for _, warnMsg in warnings do
		hananWarn(warnMsg)
	end

	-- Update manifest using editManifest from @libs/manifest
	if #installedSpecs > 0 then
		manifest.editManifest(currentConfig, {
			dependencies = newDependencies,
		})

		if #errors > 0 then
			print(`\nadded {style.bold(tostring(#installedSpecs), "green")}/{style.bold(tostring(totalCount))} packages\n`)
		else
			local pkgWord = if #installedSpecs == 1 then "package" else "packages"
			print(`\nadded {style.bold(tostring(#installedSpecs), "green")} {pkgWord}\n`)
		end

		for _, spec in installedSpecs do
			print(`added {spec}`)
		end
	end

	if #errors > 0 then
		-- local combinedError = table.concat(errors, "\n")
		-- hananErr(combinedError)

        for _, err in errors do
            print(`hanan {style.normal("[error]", "red")} {err}`)
        end
        process.exit(1)
	end
end

return {
	execute = execute,
	desc = "Add new dependencies.",
}
