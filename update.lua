-- @crafting-center {"version":"1.5.0","suite":"crafting-center","id":"update","title":"Update Scripts","args":[],"description":"Check the updater first; install and reboot if changed, otherwise update the remaining scripts from one GitHub commit.","refreshAfterExit":true,"category":"Tools"}
-- Public GitHub updater. Queue, station bindings and job state are untouched.
local OWNER="kale2heart-hub"
local REPOSITORY="FTB_Skies2_CCTweaked_Repository"
local BRANCH="main"
local SCRIPT_DIRECTORY="" -- Scripts currently live at the repository root.
local files={"fluid_network.lua","fluid_client.lua","fluid_service.lua","fluid_monitor.lua","network_setup.lua","gear_stats_data.lua","gear_preview.lua","gear_kit_data.lua","gear_request.lua","gear_chest_data.lua","chest_catalog.lua","chest_delivery.lua","gear_casting_data.lua","casting_recovery.lua","cast_tracking.lua","gear_ui.lua","gear_config.lua","scan.lua","gear_demo.lua",
    "station_setup.lua","cast_check.lua","casting_test.lua","control_center.lua","startup.lua","update.lua"}
local root=fs.getDir(shell.getRunningProgram())
local versions,transactions,staged={},{},{}
local backupRoot=fs.combine(root,"backups")
local function cleanup()
    for _,name in ipairs(files) do
        local temp=fs.combine(root,name..".download")
        if fs.exists(temp) then fs.delete(temp) end
    end
end
local function get(url,json)
    if not http then error("HTTP is disabled on this computer.",0) end
    local response,err,failed=http.get(url,{
        ["User-Agent"]="CraftingCenterUpdater/1.5.0",
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
local function read(path)
    local f=assert(fs.open(path,"r"));local content=f.readAll();f.close();return content
end
local function write(path,content)
    local f=assert(fs.open(path,"w"))
    local ok,err=pcall(f.write,content)
    f.close()
    if not ok then error(err,0) end
end
local function rollback()
    local errors={}
    for index=#transactions,1,-1 do
        local entry=transactions[index]
        if entry.touched then
            local ok,err=pcall(function()
                if fs.exists(entry.path) then fs.delete(entry.path) end
                if entry.original then write(entry.path,entry.original) end
            end)
            if not ok then errors[#errors+1]=entry.name..": "..tostring(err) end
        end
    end
    return errors
end
local function normalized(text) return text:gsub("\r\n","\n"):gsub("\r","\n") end
local function stage(name,content)
    versions[name]=metadataVersion(content,name)
    local chunk,err=load(content,"@"..name,"t",_ENV)
    if not chunk then error("Invalid Lua in "..name..": "..tostring(err),0) end
    staged[name]=content
end
local function removeScriptBackups()
    -- Only updater-managed script backups; never cast/queue/settings recovery files.
    local managed={}
    for _,name in ipairs(files) do managed[name]=true end
    local removed=0
    local function remove(path)
        if fs.exists(path) and not fs.isDir(path) then fs.delete(path);removed=removed+1 end
    end
    for name in pairs(managed) do remove(fs.combine(root,name..".bak")) end
    if fs.exists(backupRoot) and fs.isDir(backupRoot) then
        for _,name in ipairs(fs.list(backupRoot)) do
            local base=name:match("^(.-)%.bak$")
            if base then
                base=base:gsub("%.legacy%d+$","")
                if managed[base] then remove(fs.combine(backupRoot,name)) end
            end
        end
    end
    if removed>0 then print("Removed "..removed.." old script backups.") end
end
local function install(names)
    local needed=0
    for _,name in ipairs(names) do
        local path=fs.combine(root,name)
        local original=fs.exists(path) and read(path) or nil
        local content=assert(staged[name],"Missing staged script: "..name)
        if not original or normalized(original)~=normalized(content) then
            transactions[#transactions+1]={name=name,path=path,original=original,content=content}
            needed=needed+math.max(0,#content-(original and #original or 0))
        end
    end
    local free=fs.getFreeSpace(root)
    if type(free)=="number" and needed+4096>free then
        error("Not enough disk space: need "..(needed+4096).." free bytes, have "..free..". Installed scripts unchanged.",0)
    end
    -- All downloads are validated in memory before replacing any installed script.
    -- Recovery copies live only in RAM for this run, not on the computer's disk.
    for _,entry in ipairs(transactions) do
        entry.touched=true
        if fs.exists(entry.path) then fs.delete(entry.path) end
        write(entry.path,entry.content)
        print("Updated "..entry.name.." | v"..versions[entry.name])
    end
    if #transactions==0 then print("All scripts are already current.") end
end
local function update()
    cleanup()
    removeScriptBackups()
    print("GitHub: "..OWNER.."/"..REPOSITORY.." ("..BRANCH..")")
    local api="https://api.github.com/repos/"..OWNER.."/"..REPOSITORY.."/commits/"..BRANCH
    local revision=textutils.unserializeJSON(get(api,true))
    local sha=type(revision)=="table" and revision.sha
    if type(sha)~="string" or #sha~=40 or sha:find("[^%da-fA-F]") then error("GitHub did not return a valid commit",0) end
    print("Revision: "..sha:sub(1,12))
    local base="https://raw.githubusercontent.com/"..OWNER.."/"..REPOSITORY.."/"..sha.."/"
    if SCRIPT_DIRECTORY~="" then base=base..SCRIPT_DIRECTORY.."/" end
    print("Checking update.lua first...")
    local latest=get(base.."update.lua",false)
    versions["update.lua"]=metadataVersion(latest,"update.lua")
    local installed=""
    local updaterPath=fs.combine(root,"update.lua")
    if fs.exists(updaterPath) then
        local f=assert(fs.open(updaterPath,"r")); installed=f.readAll(); f.close()
    end
    if normalized(installed)~=normalized(latest) then
        stage("update.lua",latest)
        local firstPhase={"update.lua"}
        -- Fresh root-folder installations need the boot entry before rebooting.
        if not fs.exists(fs.combine(root,"startup.lua")) then
            print("Installing the startup entry for the next boot...")
            stage("startup.lua",get(base.."startup.lua",false))
            firstPhase[#firstPhase+1]="startup.lua"
        end
        install(firstPhase)
        print("New updater installed. Other scripts will update after reboot.")
        return "reboot"
    end
    print("Updater unchanged; checking remaining scripts...")
    local remaining={}
    for _,name in ipairs(files) do
        if name~="update.lua" then
            print("Downloading "..name)
            stage(name,get(base..name,false))
            remaining[#remaining+1]=name
        end
    end
    install(remaining)
    local ok=pcall(function()
        local f=assert(fs.open(fs.combine(root,"installed_revision.txt"),"w"))
        f.write(textutils.serialize({repository=OWNER.."/"..REPOSITORY,branch=BRANCH,
            commit=sha,versions=versions,installedAt=os.epoch("utc")})); f.close()
    end)
    print("Update complete: "..sha:sub(1,12))
    print("No script backups saved; recovery copies were kept in memory only.")
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
            printError("Restore incomplete. Download the listed scripts again:")
            for _,message in ipairs(errors) do printError(message) end
        end
    else printError("Installed scripts unchanged.") end
end
local cleaned,cleanupError=pcall(cleanup)
if not cleaned then printError("Temporary-file cleanup failed: "..tostring(cleanupError)) end

if ok and err=="reboot" then
    if not cleaned then printError("Updater installed, but cleanup failed; reboot cancelled."); return end
    print("Rebooting to run the new updater...")
    sleep(1)
    os.reboot()
end
