type Zone = { start: number, stop: number, quoteChar: string }

local function findQuoteZones(input: string): { Zone }
    local zones: { Zone } = {}
    local inQuote = false
    local quoteChar: string? = nil
    local zoneStart: number? = nil

    local i = 1
    local len = #input
    while i <= len do
        local char = string.sub(input, i, i)

        if not inQuote then
            if char == '"' or char == "'" then
                inQuote = true
                quoteChar = char
                zoneStart = i
            end
        else
            if char == quoteChar then
                table.insert(zones, {
                    start = zoneStart :: number,
                    stop = i,
                    quoteChar = quoteChar :: string,
                })
                inQuote = false
                quoteChar = nil
                zoneStart = nil
            end
        end

        i += 1
    end

    if inQuote then
        error(("unterminated quote (%s) starting at position %d"):format(
            quoteChar :: string,
            zoneStart :: number
        ))
    end

    return zones
end

local function isProtected(pos: number, zones: { Zone }): boolean
    for _, zone in zones do
        if pos >= zone.start and pos <= zone.stop then
            return true
        end
    end
    return false
end

local function splitCommands(input: string, zones: { Zone }): { string }
    local commands: {string} = {}
    local segmentStart = 1
    local len = #input

    local i = 1
    while i <= len do
        local char = string.sub(input, i, i)
        local nextChar = string.sub(input, i + 1, i + 1)

        if char == "&" and nextChar == "&" and not isProtected(i, zones) then
            local segment = string.sub(input, segmentStart, i - 1)
            table.insert(commands, segment)
            i += 2
            segmentStart = i
        else
            i += 1
        end
    end

    table.insert(commands, string.sub(input, segmentStart, len))

    return commands
end

local function zoneStatus(pos: number, zones: { Zone }): string
    for _, zone in zones do
        if pos == zone.start or pos == zone.stop then
            return "boundary"
        elseif pos > zone.start and pos < zone.stop then
            return "inside"
        end
    end
    return "outside"
end

local function tokenizeArgs(command: string): { string }
    local zones = findQuoteZones(command)
    local tokens: {string} = {}
    local current: {string} = {}
    local len = #command

    local i = 1
    while i <= len do
        local char = string.sub(command, i, i)
        local status = zoneStatus(i, zones)

        if status == "boundary" then
            i += 1
            continue
        elseif status == "inside" then
            table.insert(current, char)
        else
            if char:match("%s") then
                if #current > 0 then
                    table.insert(tokens, table.concat(current))
                    current = {}
                end
            else
                table.insert(current, char)
            end
        end

        i += 1
    end

    if #current > 0 then
        table.insert(tokens, table.concat(current))
    end

    return tokens
end

local function tokenize(script: string): { { command: string, args: { string } } }
    local zones = findQuoteZones(script)
    local commandStrings = splitCommands(script, zones)

    local result = {}
    for _, commandStr in commandStrings do
        local trimmed = commandStr:match("^%s*(.-)%s*$") :: string
        local tokens = tokenizeArgs(trimmed)

        local args = {}
        for idx = 2, #tokens do
            table.insert(args, tokens[idx])
        end

        table.insert(result, {
            command = tokens[1],
            args = args,
        })
    end

    return result
end

return tokenize
