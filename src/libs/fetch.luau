local req: (string, any?, boolean?) -> HttpResponse<string | buffer> = zune.net.http.request
local fs = zune.fs
local json = zune.serde.json
local process = zune.process
local zip = require("./unzip")

local USER_AGENT = "Hanan-Package-Manager"

export type FetchOptions = {
	owner: string,
	repo: string,
	tag: string?,
	token: string?,
	targetDir: string?,
}

export type ReleaseInfo = {
	tag_name: string,
	prerelease: boolean,
}

export type FetchResult = {
	success: boolean,
	ref: string?,
	isPrerelease: boolean,
	outDir: string?,
	errorMsg: string?,
	warningMsg: string?,
}

local function setGhHeaders(token: string?): { [string]: string }
	local headers = {
		["User-Agent"] = USER_AGENT,
		["Accept"] = "application/vnd.github+json",
	}

	local ghToken = token or (process.env and (process.env["GITHUB_TOKEN"] or process.env["GH_TOKEN"]))
	if ghToken and ghToken ~= "" then
		headers["Authorization"] = "Bearer " .. ghToken
	end

	return headers
end

local function checkRepoExists(owner: string, repo: string, token: string?): (boolean, string?)
	local url = string.format("https://api.github.com/repos/%s/%s", owner, repo)
	local res = req(url, {
		headers = setGhHeaders(token),
	})

	if not res.ok then
		if res.status_code == 404 then
			return false, string.format("the package \"%s/%s\" doesn't seem to appear on GitHub", owner, repo)
		else
			return false, string.format("failed to reach GitHub for \"%s/%s\" (HTTP %d)", owner, repo, res.status_code)
		end
	end

	return true, nil
end

local function getReleaseByTag(owner: string, repo: string, tag: string, token: string?): (boolean, ReleaseInfo?, string?)
	local url = string.format("https://api.github.com/repos/%s/%s/releases/tags/%s", owner, repo, tag)
	local res = req(url, {
		headers = setGhHeaders(token),
	})

	if not res.ok and not tag:match("^v") then
		local altUrl = string.format("https://api.github.com/repos/%s/%s/releases/tags/v%s", owner, repo, tag)
		local altRes = req(altUrl, {
			headers = setGhHeaders(token),
		})
		if altRes.ok then
			res = altRes
		end
	end

	if not res.ok then
		return false, nil, string.format("release tag \"%s\" was not found on GitHub for %s/%s", tag, owner, repo)
	end

	local data = json.decode(res.body :: string)
	return true, {
		tag_name = data.tag_name,
		prerelease = data.prerelease == true,
	}, nil
end

local function getLatestOrPreRelease(owner: string, repo: string, token: string?): (boolean, ReleaseInfo?, string?)
	-- 1. Check latest full release
	local urlLatest = string.format("https://api.github.com/repos/%s/%s/releases/latest", owner, repo)
	local resLatest = req(urlLatest, {
		headers = setGhHeaders(token),
	})

	if resLatest.ok then
		local data = json.decode(resLatest.body :: string)
		if data and data.tag_name then
			return true, {
				tag_name = data.tag_name :: string,
				prerelease = false,
			}, nil
		end
	end

	-- 2. Fall back to releases list to check for pre-releases
	local urlReleases = string.format("https://api.github.com/repos/%s/%s/releases?per_page=10", owner, repo)
	local resReleases = req(urlReleases, {
		headers = setGhHeaders(token),
	})

	if resReleases.ok then
		local releases = json.decode(resReleases.body :: string)
		if type(releases) == "table" and #releases > 0 then
			for _, rel in releases do
				if not rel.draft and rel.tag_name then
					return true, {
						tag_name = rel.tag_name,
						prerelease = rel.prerelease == true,
					}, nil
				end
			end
		end
	end

	return false, nil, string.format("%s/%s has no release notes/releases to install a package from", owner, repo)
end

local function downloadZip(owner: string, repo: string, ref: string, token: string?)
	local url = string.format("https://api.github.com/repos/%s/%s/zipball/%s", owner, repo, ref)
	local res = req(url, {
		headers = setGhHeaders(token),
	}, true)

	if res.status_code == 301 or res.status_code == 302 or res.status_code == 307 or res.status_code == 308 then
		local redirectUrl = res.headers["location"] or res.headers["Location"]
		if redirectUrl then
			res = req(redirectUrl, {
				headers = {
					["User-Agent"] = USER_AGENT,
				},
			}, true)
		end
	end

	return res
end

local function stripRoot(path: string): string
	return (path:gsub("^[^/]+/", "", 1))
end

local function ensureDir(path: string)
	if path == "" then
		return
	end
	fs.makeDir(path, true)
end

local function extractZipData(zipData: buffer | string, outDir: string)
	local buf: buffer
	if type(zipData) == "string" then
		buf = buffer.fromstring(zipData)
	else
		buf = zipData
	end

	local reader = zip.load(buf)
	ensureDir(outDir)

	reader:walk(function(entry, _depth)
		local relativePath = stripRoot(entry.name)
		if relativePath == "" then
			return
		end

		local outPath = outDir .. "/" .. relativePath

		if entry.isDirectory then
			ensureDir(outPath)
		else
			local parent = outPath:match("^(.*)/[^/]+$")
			if parent then
				ensureDir(parent)
			end

			local data = reader:extract(entry, { type = "text" }) :: string
			fs.writeFileSync(outPath, data)
		end
	end)
end

local function fetchPackage(opts: FetchOptions): FetchResult
	-- Step 1: Repo existence check
	local repoOk, repoErr = checkRepoExists(opts.owner, opts.repo, opts.token)
	if not repoOk then
		return {
			success = false,
			errorMsg = repoErr,
			isPrerelease = false,
		}
	end

	-- Step 2: Release notes / Release tag check
	local ref: string
	local isPrerelease = false
	local warningMsg: string? = nil

	if opts.tag and opts.tag ~= "" then
		local relOk, relInfo, relErr = getReleaseByTag(opts.owner, opts.repo, opts.tag, opts.token)
		if not relOk or not relInfo then
			return {
				success = false,
				errorMsg = relErr,
				isPrerelease = false,
			}
		end

		ref = relInfo.tag_name
		if relInfo.prerelease then
			isPrerelease = true
			warningMsg = string.format("Package %s/%s@%s is a pre-release.", opts.owner, opts.repo, ref)
		end
	else
		local relOk, relInfo, relErr = getLatestOrPreRelease(opts.owner, opts.repo, opts.token)
		if not relOk or not relInfo then
			return {
				success = false,
				errorMsg = relErr,
				isPrerelease = false,
			}
		end

		ref = relInfo.tag_name
		if relInfo.prerelease then
			isPrerelease = true
			warningMsg = string.format(
				"Package %s/%s does not seem to have a latest full release yet; using pre-release %s.",
				opts.owner, opts.repo, ref
			)
		end
	end

	-- Step 3: Download Zipball
	local response = downloadZip(opts.owner, opts.repo, ref, opts.token)
	if not response.ok then
		return {
			success = false,
			errorMsg = string.format(
				"failed to fetch %s/%s@%s -- HTTP %d\n%s",
				opts.owner, opts.repo, ref, response.status_code, tostring(response.body)
			),
			isPrerelease = isPrerelease,
		}
	end

	-- Step 4: Extract Zip to destination
	local outDir = opts.targetDir or (".luau_modules/" .. opts.repo)
	extractZipData(response.body, outDir)

	return {
		success = true,
		ref = ref,
		isPrerelease = isPrerelease,
		outDir = outDir,
		warningMsg = warningMsg,
	}
end

return fetchPackage