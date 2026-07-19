local fs = zune.fs

local function serializeString(value: string): string
    return string.format("%q", value)
end

local function serializeStringMap(map: { [string]: string }?, indent: string): string?
    if not map then
        return nil
    end

    local keys = {}
    for key in map do
        table.insert(keys, key)
    end
    table.sort(keys)

    if #keys == 0 then
        return "{}"
    end

    local lines = {}
    for _, key in keys do
        table.insert(lines, `{indent}\t"{key}": {serializeString(map[key])}`)
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

local function createManifest(config: ManifestTemplate)
    local fields = {}

    if config.lib then
        table.insert(fields, `\t"lib": {serializeString(config.lib)}`)
    end
    if config.bin then
        table.insert(fields, `\t"bin": {serializeString(config.bin)}`)
    end

    local scripts = serializeStringMap(config.scripts, "\t")
    if scripts then
        table.insert(fields, `\t"scripts": {scripts}`)
    end

    local engines = serializeStringMap(config.engines, "\t")
    if engines then
        table.insert(fields, `\t"engines": {engines}`)
    end

    local includes = serializeArray(config.includes, "\t")
    if includes then
        table.insert(fields, `\t"includes": {includes}`)
    end

    local dependencies = serializeStringMap(config.dependencies, "\t")
    if dependencies then
        table.insert(fields, `\t"dependencies": {dependencies}`)
    end

    local devDependencies = serializeStringMap(config.dev_dependencies, "\t")
    if devDependencies then
        table.insert(fields, `\t"dev_dependencies": {devDependencies}`)
    end

    local contents = `\{\n{table.concat(fields, ",\n")}\n\}\n`

    fs.writeFile("./hanan.json", contents)
end

local function mergeMap(currentMap: { [string]: string }?, newMap: { [string]: string }?): { [string]: string }?
    if not currentMap and not newMap then return nil end
    
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

local function editManifest(currentConfig: ManifestTemplate, newData: ManifestTemplate)
    local updated: ManifestTemplate = {
        lib = newData.lib or currentConfig.lib,
        bin = newData.bin or currentConfig.bin,
        
        scripts = mergeMap(currentConfig.scripts, newData.scripts),
        engines = mergeMap(currentConfig.engines, newData.engines),
        dependencies = mergeMap(currentConfig.dependencies, newData.dependencies),
        dev_dependencies = mergeMap(currentConfig.dev_dependencies, newData.dev_dependencies),
    }

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
    else
        if currentIncludes then
            updated.includes = table.clone(currentIncludes)
        end
    end

    createManifest(updated)

    return updated
end

return {
    createManifest = createManifest,
    editManifest = editManifest
}
