-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"control_center","title":"Control Center","launchable":false,"description":"Dynamic program launcher and version registry."}
-- Crafting Center console launcher. All launches use fg/separate tabs.
-- Q or Ctrl+T here closes all Control-Center-managed child programs.
local SELF=fs.combine(shell.getRunningProgram(),""):gsub("^/+","")
local ROOT=fs.combine(fs.getDir(SELF),""):gsub("^/+","")
local argv={...}
local programs,byId,registryFiles,filesByName={},{},{},{}
local registryWarnings={}
local registryWriteError
local installationFingerprint=""
local REGISTRY=fs.combine(ROOT,"control_registry.txt")
local function fingerprint(text)
  text=text:gsub("\r\n","\n"):gsub("\r","\n")
  local a,b=1,0
  for i=1,#text do a=(a+text:byte(i))%65521; b=(b+a)%65521 end
  return string.format("%08x",b*65536+a)
end
local function stringList(value,label)
  if value==nil then return {} end
  assert(type(value)=="table",label.." must be a list")
  local result={}
  for _,v in ipairs(value) do assert(type(v)=="string",label.." entries must be strings"); result[#result+1]=v end
  return result
end
local function metadata(text)
  local count=0
  for line in (text.."\n"):gmatch("([^\n]*)\n") do
    count=count+1; if count>32 then break end
    local json=line:match("^%s*%-%-%s*@crafting%-center%s+(.+)$")
    if json then
      local ok,value=pcall(textutils.unserializeJSON,json)
      if not ok or type(value)~="table" then return nil,"Invalid metadata JSON" end
      return value
    end
  end
end
local function scanPrograms(writeCache)
  programs,byId,registryFiles,filesByName={},{},{},{}
  registryWarnings={}; registryWriteError=nil
  local paths={}
  local function visit(dir,depth)
    if depth>6 then return end
    local ok,names=pcall(fs.list,dir)
    if not ok then registryWarnings[#registryWarnings+1]="Cannot scan "..dir; return end
    table.sort(names)
    for _,name in ipairs(names) do
      local path=fs.combine(dir,name)
      if fs.isDir(path) then
        if name~="rom" and name~=".git" and name~="requests" and name~="demo_requests" then visit(path,depth+1) end
      elseif name:sub(-4)==".lua" or not name:find("%.") then paths[#paths+1]=path end
    end
  end
  visit(ROOT,0); table.sort(paths)
  for _,path in ipairs(paths) do
    local f=fs.open(path,"r")
    if f then
      local text=f.readAll(); f.close()
      local meta,err=metadata(text)
      if meta or err or path:sub(-4)==".lua" then
        local file=ROOT=="" and path or path:sub(#ROOT+2)
        local record={file=file,version=meta and tostring(meta.version or "unversioned") or "unversioned",
          fingerprint=fingerprint(text),metadata=meta~=nil,error=err,launchable=false}
        registryFiles[#registryFiles+1]=record; filesByName[file]=record
        if err then registryWarnings[#registryWarnings+1]=file..": "..err end
        local function add(action)
          local ok,entry=pcall(function()
            local id=action.id or (meta and meta.id) or ("file:"..file)
            assert(type(id)=="string" and id~="","id must be a nonempty string")
            local title=action.title or (meta and meta.title) or fs.getName(file):gsub("%.lua$","")
            assert(type(title)=="string","title must be a string")
            local description=action.description or (meta and meta.description) or "Local script without a metadata header."
            assert(type(description)=="string","description must be a string")
            return {id=id,title=title,file=file,args=stringList(action.args or (meta and meta.args),"args"),
              description=description,version=record.version,fingerprint=record.fingerprint,
              locks=stringList(action.locks or (meta and meta.locks),"locks"),
              dependencies=stringList(action.dependencies or (meta and meta.dependencies),"dependencies"),
              refreshAfterExit=action.refreshAfterExit or (meta and meta.refreshAfterExit)}
          end)
          if not ok then record.error=tostring(entry); registryWarnings[#registryWarnings+1]=file..": "..tostring(entry); return end
          if byId[entry.id] then
            byId[entry.id].error="Duplicate program ID: "..entry.id
            entry.error="Duplicate program ID: "..entry.id
            registryWarnings[#registryWarnings+1]=entry.error
          end
          programs[#programs+1]=entry; byId[entry.id]=entry
          record.launchable=true
        end
        local isSelf=fs.combine(ROOT,file)==fs.combine(SELF,"")
        if not err and not isSelf and (not meta or meta.launchable~=false) then
          if meta and meta.actions~=nil then
            if type(meta.actions)~="table" then record.error="actions must be a list"
            else for _,action in ipairs(meta.actions) do
              if type(action)=="table" then add(action) else record.error="Invalid action metadata" end
            end end
          else add(meta or {}) end
        end
      end
    else registryWarnings[#registryWarnings+1]="Cannot read "..path end
  end
  table.sort(programs,function(a,b)
    local x,y=a.title:lower(),b.title:lower()
    return x==y and a.file<b.file or x<y
  end)
  local parts={}
  for _,file in ipairs(registryFiles) do parts[#parts+1]=file.file..":"..file.version..":"..file.fingerprint end
  installationFingerprint=fingerprint(table.concat(parts,"\n"))
  if writeCache then
    local ok,err=pcall(function()
      local f=assert(fs.open(REGISTRY,"w"))
      f.write(textutils.serialize({schema=1,root=ROOT,files=registryFiles,programs=programs,
        installationFingerprint=installationFingerprint,warnings=registryWarnings}))
      f.close()
    end)
    if not ok then registryWriteError=tostring(err) end
  end
end
scanPrograms(argv[1]~="--child")
local selfFile=ROOT=="" and SELF or SELF:sub(#ROOT+2)
local loadedController=filesByName[selfFile] or {version="unversioned",fingerprint="unknown"}
local function loadedFiles(program)
  local result={[program.file]={version=program.version,fingerprint=program.fingerprint}}
  for _,dependency in ipairs(program.dependencies or {}) do
    local file=fs.combine(fs.getDir(program.file),dependency)
    local record=filesByName[file]
    result[file]=record and {version=record.version,fingerprint=record.fingerprint} or {version="missing",fingerprint="missing"}
  end
  return result
end
local EVENT="crafting_center_control"
local function packet(action,data) os.queueEvent(EVENT,action,data) end
local function clock() return os.clock() end
if not multishell or not shell.resolveProgram("fg") then
  printError("Control Center needs an Advanced Computer with fg tabs.")
  return
end

-- The same file acts as a managed child wrapper in each fg tab.
if argv[1]=="--child" then
  local program=byId[argv[2]]
  local token=argv[3]
  if not program or not token then printError("Unknown Control Center child"); return end
  local console=term.current()
  local phase="running"
  local success=nil
  local loaded=loadedFiles(program)
  local function announce()
    multishell.setTitle(multishell.getCurrent(),program.title..(phase=="finished" and " [done]" or ""))
    packet("status",{id=program.id,token=token,phase=phase,success=success,
      version=program.version,fingerprint=program.fingerprint,loadedFiles=loaded,locks=program.locks})
  end
  local function lifecycle()
    local heartbeat=os.startTimer(1)
    announce()
    while true do
      local event,action,data=os.pullEventRaw()
      if event==EVENT then
        if action=="shutdown" then return
        elseif action=="ping" then announce()
        elseif action=="focus" and data==token then
          -- Resolve the current tab at the moment of focus; tab IDs can shift.
          multishell.setFocus(multishell.getCurrent()); announce()
        end
      elseif event=="timer" and action==heartbeat then
        announce(); heartbeat=os.startTimer(1)
      end
    end
  end
  local function runner()
    local file="/"..fs.combine(ROOT,program.file)
    local ok,result=pcall(shell.execute,file,table.unpack(program.args or {}))
    term.redirect(console)
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
    success=ok and result==true
    phase="finished"; announce()
    if not ok then printError(result) end
    print("")
    print(program.title..(success and " finished." or " stopped or failed."))
    print("Q closes this tab. Select Control Center to run another tool.")
    while true do
      local event,key=os.pullEventRaw()
      if event=="terminate" or (event=="key" and key==keys.q) then return end
    end
  end
  -- Shutdown abandons the managed runner at its next yield; no further
  -- program events or queued casts execute after the wrapper exits.
  local ok,err=pcall(function() parallel.waitForAny(lifecycle,runner) end)
  packet("closed",{id=program.id,token=token})
  term.redirect(console)
  if not ok then printError(err) end
  return
end

multishell.setTitle(multishell.getCurrent(),"Control Center")
local selected,offset=1,0
local view="list"
local notice=""
local sessions={}
local pending
local sessionCounter=0
local function refreshRegistry()
  local id=programs[selected] and programs[selected].id
  scanPrograms(true)
  selected=math.max(1,math.min(selected,math.max(1,#programs)))
  for index,program in ipairs(programs) do if program.id==id then selected=index; break end end
  packet("ping")
  notice=registryWriteError and "Registry cache could not be saved" or (#registryWarnings>0 and "Scan has metadata warnings - V shows details" or "Local scripts and versions refreshed")
end
local function acceptStatus(data)
  if type(data)~="table" or not byId[data.id] or type(data.token)~="string" then return end
  local old=sessions[data.id]
  local fresh=not old or clock()-old.seen>4
  if fresh or old.token==data.token or (old.phase=="finished" and data.phase=="running") then
    local justFinished=data.phase=="finished" and (not old or old.phase~="finished")
    data.seen=clock(); sessions[data.id]=data
    if justFinished and byId[data.id].refreshAfterExit then refreshRegistry() end
  end
end
local function session(program)
  if not program then return nil end
  local record=sessions[program.id]
  if record and clock()-record.seen<=4 then return record end
end
local function installed(program)
  local path=fs.combine(ROOT,program.file)
  return fs.exists(path) and not fs.isDir(path)
end
local function requestLaunch(program,focusOnly)
  if not program then notice="No runnable scripts found"; return end
  if program.error then notice=program.error; return end
  if pending then notice="Already checking a launch request"; return end
  if not focusOnly and not installed(program) then notice="Missing file: "..program.file; return end
  -- Let existing wrappers reply before deciding to start a duplicate.
  packet("ping")
  pending={id=program.id,focusOnly=focusOnly,timer=os.startTimer(0.2)}
  notice="Checking "..program.title.."..."
end
local function finishLaunch()
  local request=pending; pending=nil
  if not request then return end
  local program=byId[request.id]
  if not program or program.error then notice="Script changed or disappeared; refresh and retry"; return end
  local running=session(program)
  if running and (running.phase=="running" or request.focusOnly) then
    packet("focus",running.token)
    notice="Opened existing "..program.title.." tab"
    return
  end
  if request.focusOnly then notice="No open tab for this program"; return end
  -- Scripts declare shared resources rather than hard-coded program IDs.
  for id,active in pairs(sessions) do
    if id~=program.id and clock()-active.seen<=4 and active.phase=="running" then
      local other=byId[id]
      for _,wanted in ipairs(program.locks or {}) do
        for _,held in ipairs(active.locks or (other and other.locks) or {}) do
          if wanted==held then notice="Shared resource busy: "..wanted; return end
        end
      end
    end
  end
  sessionCounter=sessionCounter+1
  local stamp=os.epoch and os.epoch("utc") or math.floor(clock()*1000)
  local token=tostring(stamp).."-"..sessionCounter.."-"..math.random(100000,999999)
  -- fg starts the managed wrapper in a separate, focused shell tab.
  -- execute passes paths and args verbatim instead of reparsing spaces.
  local ok,result=pcall(shell.execute,"fg","/"..SELF,"--child",program.id,token)
  notice=ok and result and ("Started "..program.title.." in a separate tab") or "Unable to open fg tab"
end
local function wrapped(lines,width)
  local result={}
  for _,line in ipairs(lines) do
    line=tostring(line)
    if line=="" then result[#result+1]="" end
    for pos=1,#line,width do result[#result+1]=line:sub(pos,pos+width-1) end
  end
  return result
end
local function parityStatus(state)
  if not state or not state.loadedFiles then return "loaded version unknown" end
  for file,loaded in pairs(state.loadedFiles) do
    local disk=filesByName[file]
    if not disk or disk.fingerprint~=loaded.fingerprint then return "RESTART NEEDED" end
  end
  return "current"
end
local function versionLines()
  local lines={"INSTALLATION FINGERPRINT: "..installationFingerprint,
    "Compare this value across computers for exact local script parity.",
    "Registry cache: "..REGISTRY,"", "Controller loaded: v"..loadedController.version.." / "..loadedController.fingerprint}
  local current=filesByName[selfFile]
  if current and current.fingerprint~=loadedController.fingerprint then lines[#lines+1]="Control Center changed on disk - restart needed" end
  for _,file in ipairs(registryFiles) do
    lines[#lines+1]=""
    lines[#lines+1]=file.file.." | v"..file.version.." | "..file.fingerprint..(file.launchable and "" or " [helper]")
    if file.error then lines[#lines+1]="ERROR: "..file.error end
    for _,program in ipairs(programs) do
      local state=sessions[program.id]
      if program.file==file.file and state and clock()-state.seen<=4 then
        lines[#lines+1]="  "..program.title..": "..state.phase.." v"..tostring(state.version or "unknown").." | "..parityStatus(state)
      end
    end
  end
  if registryWriteError then lines[#lines+1]="Cache write error: "..registryWriteError end
  for _,warning in ipairs(registryWarnings) do lines[#lines+1]="WARNING: "..warning end
  return lines
end
local function render()
  local w,h=term.getSize()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
  local function line(y,text,bg)
    term.setCursorPos(1,y); term.setBackgroundColor(bg or colors.black)
    text=tostring(text):sub(1,w); term.write(text..string.rep(" ",w-#text))
  end
  if w<20 or h<10 then line(1,"Need terminal 20x10"); return 1 end
  local capacity=h-7
  line(1,"CONTROL CENTER | v"..loadedController.version,colors.blue)
  line(2,"Separate fg tabs | Q exits all managed programs")
  if view=="list" then
    local page=math.floor((selected-1)/capacity)
    line(3,"Page "..(page+1).."/"..math.max(1,math.ceil(#programs/capacity)))
    for row=1,capacity do
      local index=page*capacity+row
      local program=programs[index]
      if program then
        local state=session(program)
        local status=program.error and "METADATA ERROR" or not installed(program) and "MISSING" or state and (state.phase=="running" and (parityStatus(state)=="RESTART NEEDED" and "RESTART" or "RUNNING") or (state.success and "FINISHED" or "STOPPED")) or "READY"
        line(row+3,(selected==index and "> " or "  ")..program.title.." v"..program.version.." ["..status.."]",selected==index and colors.blue or colors.black)
      end
    end
    if #programs==0 then line(4,"No runnable local scripts. R rescans.") end
  else
    local program=programs[selected]
    local state=session(program)
    local content
    if view=="versions" or not program then content=versionLines() else
    content={program.title,"File: "..fs.combine(ROOT,program.file),
      "Version on disk: "..program.version.." / "..program.fingerprint,
      "Loaded: "..(state and tostring(state.version or "unknown") or "not running").." | "..parityStatus(state),
      "Arguments: "..table.concat(program.args or {}," "),"",program.description,"",
      "Enter: start in a foreground tab, or focus if already running.",
      "F: focus its existing tab without starting another instance.",
      "Control Center's Q/Ctrl+T closes every managed child tab.",
      "Programs started independently outside Control Center are not managed.",
      "Status: "..(state and state.phase or "not running")}
    end
    local lines=wrapped(content,w)
    offset=math.max(0,math.min(offset,math.max(0,#lines-capacity)))
    line(3,"Details | Lines "..(offset+1).."-"..math.min(#lines,offset+capacity).."/"..#lines)
    for row=1,capacity do line(row+3,lines[offset+row] or "") end
  end
  line(h-3,"Arrows/PgUp/PgDn navigate | Enter run/focus")
  line(h-2,"D details | V versions | F focus | R scan | B back")
  line(h-1,"Q: exit Control Center AND managed programs")
  line(h,notice,colors.gray)
  return capacity
end
local function shutdown()
  -- A broadcast reaches every wrapper, including background Gear UI.
  packet("shutdown")
  local deadline=os.startTimer(1)
  while true do
    local event,id=os.pullEventRaw()
    if event=="timer" and id==deadline then break end
  end
end
local function main()
  packet("ping")
  local tick=os.startTimer(1)
  while true do
    local capacity=render()
    local event,key,data=os.pullEventRaw()
    if event=="terminate" then return end
    if event==EVENT then
      if key=="status" then acceptStatus(data)
      elseif key=="closed" and type(data)=="table" then
        local old=sessions[data.id]
        if old and old.token==data.token then sessions[data.id]=nil end
      elseif key=="shutdown" then return end
    elseif event=="timer" then
      if pending and key==pending.timer then finishLaunch()
      elseif key==tick then packet("ping"); tick=os.startTimer(1) end
    elseif event=="key" then
      if key==keys.q then return
      elseif key==keys.up then if view=="list" then selected=math.max(1,selected-1) else offset=math.max(0,offset-1) end
      elseif key==keys.down then if view=="list" then selected=math.max(1,math.min(#programs,selected+1)) else offset=offset+1 end
      elseif key==keys.pageUp then if view=="list" then selected=math.max(1,selected-capacity) else offset=math.max(0,offset-capacity) end
      elseif key==keys.pageDown then if view=="list" then selected=math.max(1,math.min(#programs,selected+capacity)) else offset=offset+capacity end
      elseif key==keys.enter then requestLaunch(programs[selected],false)
      elseif key==keys.f then requestLaunch(programs[selected],true)
      elseif key==keys.d then view="detail"; offset=0
      elseif key==keys.v then view="versions"; offset=0
      elseif key==keys.b or key==keys.backspace then view="list"
      elseif key==keys.r then refreshRegistry() end
    elseif event=="mouse_scroll" then
      if view=="list" then selected=math.max(1,math.min(#programs,selected+key)) else offset=math.max(0,offset+key) end
    end
  end
end
local ok,err=pcall(main)
shutdown()
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
if not ok then printError(err) end
print("Control Center closed; managed programs stopped.")
