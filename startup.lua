-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"startup","title":"Startup","launchable":false,"description":"On boot, update scripts and then open Control Center.","dependencies":["update.lua","control_center.lua"]}
-- Save as startup.lua at the computer root, beside the other scripts.
local directory=fs.getDir(shell.getRunningProgram())
-- If programs live elsewhere, replace directory above with that folder.
local function program(name) return "/"..fs.combine(directory,name):gsub("^/+","") end
term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
term.clear(); term.setCursorPos(1,1)
print("CRAFTING CENTER - STARTUP")
local updater=program("update.lua")
if fs.exists(updater) and not fs.isDir(updater) then
    print("Checking for script updates...")
    local ok,result=pcall(shell.execute,updater)
    if not ok then printError(result) end
    if not ok or not result then print("Continuing with installed scripts.") end
else
    print("Updater not installed; using available scripts.")
end
local center=program("control_center.lua")
if not fs.exists(center) or fs.isDir(center) then
    printError("Control Center is missing: "..center)
    print("Install the scripts, then run startup again.")
    return
end
print("Opening Control Center...")
sleep(1)
-- Run in the startup tab. Control Center opens its child programs with fg.
-- Exiting Control Center returns to the shell; this does not loop/relaunch it.
local ok,result=pcall(shell.execute,center)
if not ok then printError(result)
elseif not result then printError("Control Center stopped with an error.") end
