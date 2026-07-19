local req = zune.net.http.request
local json = zune.serde.json

local function fetchEngineVersion(engine: string)
    local url = "https://api.github.com/repos/" .. engine .. "/releases/latest"
    local success, res = pcall(req, url)

    if not success then
        error(res)
    end

    local decodedBody = json.decode(res.body)

    return decodedBody.tag_name
end

return fetchEngineVersion
