-- @crafting-center {"version":"1.0.2","suite":"crafting-center","id":"update","title":"Update Scripts","args":[],"description":"Download and validate all scripts from one GitHub commit. Running programs keep their loaded code until restarted.","refreshAfterExit":true}
-- Public GitHub updater. Queue, station bindings and job state are untouched.
local OWNER="kale2heart-hub"
local REPOSITORY="FTB_Skies2_CCTweaked_Repository"
local BRANCH="main"
local SCRIPT_DIRECTORY="" -- Scripts currently live at the repository root.
local files={"gear_ui.lua","gear_config.lua","scan.lua","gear_demo.lua",
    "station_setup.lua","casting_test.lua","control_center.lua","startup.lua","update.lua"}
local root=fs.getDir(shell.getRunningProgram())
local versions,transactions={},{}
local function cleanup()
    for _,name in ipairs(files) do
        local temp=fs.combine(root,name..".download")
        if fs.exists(temp) then fs.delete(temp) end
    end
end
local function get(url,json)
    if not http then error("HTTP is disabled on this computer.",0) end
    local response,err,failed=http.get(url,{
        ["User-Agent"]="CraftingCenterUpdater/1.0.2",
        ["Accept"]=json and "application/vnd.github+json" or "text/plain",
    })
    if not response then
        local code=failed and failed.getResponseCode()
        if failed then failed.close() end
        error("Download failed"..(code and " (HTTP "..code..")" or "")..": "..tostring(err),0)
    end
    local code=response.getResponseCode()
    local content=response.readAll(); response.close()
    if code~=200 then error("Unexpected HTTP "..code.." from GitHub",0) end
    return content
end
local function metadataVersion(content,name)
    local count=0
    for line in (content.."\n"):gmatch("([^\n]*)\n") do
        count=count+1; if count>32 then break end
        local json=line:match("^%s*%-%-%s*@crafting%-center%s+(.+)$")
        if json then
            local ok,meta=pcall(textutils.unserializeJSON,json)
            if ok and type(meta)=="table" and type(meta.version)=="string" then return meta.version end
            error("Invalid version metadata in "..name,0)
        end
    end
    error("Missing version metadata in "..name,0)
end
local function rollback()
    local errors={}
    for index=#transactions,1,-1 do
        local entry=transactions[index]
        if entry.touched then
            local ok,err=pcall(function()
                if fs.exists(entry.path) then fs.delete(entry.path) end
                if entry.hadOriginal then fs.copy(entry.backup,entry.path) end
            end)
            if not ok then errors[#errors+1]=entry.name..": "..tostring(err) end
        end
    end
    return errors
end
local function update()
    print("GitHub: "..OWNER.."/"..REPOSITORY.." ("..BRANCH..")")
    local api="https://api.github.com/repos/"..OWNER.."/"..REPOSITORY.."/commits/"..BRANCH
    local revision=textutils.unserializeJSON(get(api,true))
    local sha=type(revision)=="table" and revision.sha
    if type(sha)~="string" or #sha~=40 or sha:find("[^%da-fA-F]") then error("GitHub did not return a valid commit",0) end
    print("Revision: "..sha:sub(1,12))
    local base="https://raw.githubusercontent.com/"..OWNER.."/"..REPOSITORY.."/"..sha.."/"
    if SCRIPT_DIRECTORY~="" then base=base..SCRIPT_DIRECTORY.."/" end
    -- Download and compile EVERY file before replacing any installed script.
    for _,name in ipairs(files) do
        print("Downloading "..name)
        local content=get(base..name,false)
        versions[name]=metadataVersion(content,name)
        local temp=fs.combine(root,name..".download")
        if fs.exists(temp) then fs.delete(temp) end
        local f=assert(fs.open(temp,"w")); f.write(content); f.close()
        local chunk,err=loadfile(temp)
        if not chunk then error("Invalid Lua in "..name..": "..tostring(err),0) end
    end
    -- Prepare all backups while the original installed files remain intact.
    for _,name in ipairs(files) do
        local entry={name=name,path=fs.combine(root,name),backup=fs.combine(root,name..".bak")}
        entry.hadOriginal=fs.exists(entry.path)
        transactions[#transactions+1]=entry
        if entry.hadOriginal then
            if fs.exists(entry.backup) then fs.delete(entry.backup) end
            fs.copy(entry.path,entry.backup)
        end
    end
    -- The updater is last in this ordered list. Its current chunk keeps running.
    for _,entry in ipairs(transactions) do
        entry.touched=true
        if fs.exists(entry.path) then fs.delete(entry.path) end
        fs.move(entry.path..".download",entry.path)
        print("Updated "..entry.name.." | v"..versions[entry.name])
    end
    local ok=pcall(function()
        local f=assert(fs.open(fs.combine(root,"installed_revision.txt"),"w"))
        f.write(textutils.serialize({repository=OWNER.."/"..REPOSITORY,branch=BRANCH,
            commit=sha,versions=versions,installedAt=os.epoch("utc")})); f.close()
    end)
    print("Update complete: "..sha:sub(1,12))
    print("Previous scripts remain in .bak files.")
    if not ok then printError("Scripts updated, but revision receipt could not be saved.") end
end
local ok,err=pcall(update)
if not ok then
    printError(err)
    local touched=false
    for _,entry in ipairs(transactions) do if entry.touched then touched=true end end
    if touched then
        local errors=rollback()
        if #errors==0 then printError("Previous installed scripts restored.")
        else
            printError("Restore incomplete. Backup files are retained:")
            for _,message in ipairs(errors) do printError(message) end
        end
    else printError("Installed scripts unchanged.") end
end
local cleaned,cleanupError=pcall(cleanup)
if not cleaned then printError("Temporary-file cleanup failed: "..tostring(cleanupError)) end
