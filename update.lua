-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"update","title":"Update Scripts","args":[],"description":"Download and validate updates. Running programs keep their loaded code until restarted.","refreshAfterExit":true}
-- Downloads and syntax-checks all scripts before replacing installed files.
local files = {
    {"gear_ui.lua",       "Kpv3DFpw"},
    {"gear_config.lua",   "AaycZMFq"},
    {"scan.lua",          "XBN2xPDu"},
    {"gear_demo.lua",     "nvS0XYuk"},
    {"station_setup.lua", "RsndMVeb"},
    {"casting_test.lua",  "A0GFb1LH"},
    {"control_center.lua","tcBkF1vf"},
    {"update.lua",        "9p0dsT5Z"}, -- Replace the updater last.
}
local root = fs.getDir(shell.getRunningProgram())
local downloadedVersions={}
local function readVersion(path)
    local f=assert(fs.open(path,"r"))
    local version="unversioned"
    for _=1,32 do
        local line=f.readLine()
        if not line then break end
        local json=line:match("^%s*%-%-%s*@crafting%-center%s+(.+)$")
        if json then
            local ok,meta=pcall(textutils.unserializeJSON,json)
            if ok and type(meta)=="table" then version=tostring(meta.version or version) end
            break
        end
    end
    f.close()
    return version
end
local function cleanup()
    for _, entry in ipairs(files) do
        local temp = fs.combine(root, entry[1] .. ".download")
        if fs.exists(temp) then fs.delete(temp) end
    end
end
for _, entry in ipairs(files) do
    local name, id = entry[1], entry[2]
    local temp = fs.combine(root, name .. ".download")
    if fs.exists(temp) then fs.delete(temp) end
    print("Downloading " .. name)
    local ok = shell.run("wget", "https://pastebin.com/raw/" .. id, temp)
    if not ok or not fs.exists(temp) then
        cleanup()
        printError("Download failed. Installed files unchanged.")
        return
    end
    downloadedVersions[name]=readVersion(temp)
    local chunk, err = loadfile(temp)
    if not chunk then
        cleanup()
        printError("Invalid Lua in " .. name .. ": " .. tostring(err))
        printError("Installed files unchanged.")
        return
    end
end
for _, entry in ipairs(files) do
    local path = fs.combine(root, entry[1])
    local backup = path .. ".bak"
    if fs.exists(path) then
        if fs.exists(backup) then fs.delete(backup) end
        fs.move(path, backup)
    end
    fs.move(path .. ".download", path)
    print("Updated " .. entry[1] .. " | v" .. downloadedVersions[entry[1]])
end
print("Update complete.")
print("Previous scripts saved as .bak files.")

