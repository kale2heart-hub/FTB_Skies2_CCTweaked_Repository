-- @crafting-center {"version":"1.2.2","suite":"crafting-center","id":"control_center","title":"Control Center","launchable":false,"description":"Categorized launcher, managed shells, script versions and a built-in text-file reader."}
-- Crafting Center console launcher. All launches use fg/separate tabs.
-- Q or Ctrl+T here closes all Control-Center-managed child programs.
local SELF=fs.combine(shell.getRunningProgram(),""):gsub("^/+","")
local ROOT=fs.combine(fs.getDir(SELF),""):gsub("^/+","")
local argv={...}
local CATEGORIES={"Applications","Console Scripts","Tools","Text Files"}
local VALID_CATEGORY={Applications=true,["Console Scripts"]=true,Tools=true}
local SHELL_ID="__crafting_shell"
local programs,byId,registryFiles,filesByName={},{},{},{}
local registryWarnings={}
local registryWriteError
local installationFingerprint=""
local REGISTRY=fs.combine(ROOT,"control_registry.txt")
local textFiles={}
local function scanTextFiles()
  textFiles={}
  local function visit(dir,depth)
    if depth>6 then return end
    local ok,names=pcall(fs.list,dir)
    if not ok then return end
    for _,name in ipairs(names) do
      local path=fs.combine(dir,name)
      if fs.isDir(path) then
        if name~="rom" and name~=".git" then visit(path,depth+1) end
      elseif name:lower():sub(-4)==".txt" then
        textFiles[#textFiles+1]={path=path,file=ROOT=="" and path or path:sub(#ROOT+2)}
      end
    end
  end
  visit(ROOT,0)
  table.sort(textFiles,function(a,b) return a.file:lower()<b.file:lower() end)
end
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
        if name~="rom" and name~="backups" and name~=".git" and name~="requests" and name~="demo_requests" then visit(path,depth+1) end
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
            assert(type(id)=="string" and id~="" and id~=SHELL_ID,"id must be unique and non-reserved")
            local title=action.title or (meta and meta.title) or fs.getName(file):gsub("%.lua$","")
            assert(type(title)=="string","title must be a string")
            local description=action.description or (meta and meta.description) or "Local script without a metadata header."
            assert(type(description)=="string","description must be a string")
            local category=action.category or (meta and meta.category) or "Console Scripts"
            assert(VALID_CATEGORY[category],"Unknown category: "..tostring(category))
            return {id=id,title=title,file=file,category=category,args=stringList(action.args or (meta and meta.args),"args"),
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
  local terminalShell={id=SHELL_ID,title="Open Shell",file="/rom/programs/shell.lua",
    builtin=true,allowMultiple=true,category="Tools",args={},version="system",fingerprint="builtin-shell",
    locks={},dependencies={},description="Open a new empty shell in its own managed fg tab. Control Center stays open; its exit closes this shell too."}
  programs[#programs+1]=terminalShell; byId[SHELL_ID]=terminalShell
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
  if program.builtin then return {} end
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
    local file=program.builtin and program.file or "/"..fs.combine(ROOT,program.file)
    if program.builtin then shell.setDir("/"..ROOT) end
    local ok,result=pcall(shell.execute,file,table.unpack(program.args or {}))
    term.redirect(console)
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
    success=ok and result==true
    phase="finished"; announce()
    if not ok then printError(result) end
    if program.builtin then return end -- Typing exit closes the managed shell tab.
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
scanTextFiles()
local selected,offset=1,0
local view="categories"
local activeCategory
local previousView
local notice=""
local textPath,textLines=nil,{}
local textRows,textRowsWidth=nil,nil
local function openTextFile(path,keepOffset)
  textPath=path;textRows=nil;textRowsWidth=nil
  if not keepOffset then offset=0 end
  local ok,result=pcall(function()
    local f=assert(fs.open(path,"r"),"File missing or unreadable")
    local raw=f.read(524289) or "";f.close()
    local truncated=#raw>524288
    if truncated then raw=raw:sub(1,524288) end
    raw=raw:gsub("\r\n","\n"):gsub("\r","\n")
    local lines={}
    for line in (raw.."\n"):gmatch("([^\n]*)\n") do
      lines[#lines+1]=line:gsub("%c",function(c) return c=="\t" and "    " or "?" end)
    end
    if truncated then lines[#lines+1]="[Showing first 512 KiB of file]" end
    return lines
  end)
  textLines=ok and result or {"Cannot read "..path,tostring(result),"R retries reading the file."}
  view="text";notice=ok and "Read only | R reloads current file" or "File could not be read"
end
local sessions={}
local pending
local sessionCounter=0
local function visiblePrograms()
  local result={}
  for _,program in ipairs(programs) do if program.category==activeCategory then result[#result+1]=program end end
  return result
end
local function selectedProgram()
  if view=="categories" or view=="versions" or view=="texts" or view=="text" then return nil end
  return activeCategory and visiblePrograms()[selected] or nil
end
local function listSize()
  return view=="categories" and #CATEGORIES or view=="texts" and #textFiles or #visiblePrograms()
end
local function refreshRegistry()
  local selectedEntry=selectedProgram()
  local id=selectedEntry and selectedEntry.id
  scanPrograms(true)
  if view=="categories" then selected=math.max(1,math.min(selected,#CATEGORIES))
  else
    local visible=visiblePrograms()
    selected=math.max(1,math.min(selected,math.max(1,#visible)))
    for index,program in ipairs(visible) do if program.id==id then selected=index; break end end
  end
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
  local path=program.builtin and program.file or fs.combine(ROOT,program.file)
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
  if running and (request.focusOnly or (running.phase=="running" and not program.allowMultiple)) then
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
-- Highlight plain logs and serialized records without evaluating file contents.
local function highlightText(text)
  local lower=text:lower()
  local structured=text:find("=") or text:match('"[^"\n]+"%s*:')
  local base=colors.white
  if not structured then
    local function has(words)
      for _,word in ipairs(words) do if lower:find(word,1,true) then return true end end
    end
    if has({"error","missing","not found","not enough","wrong output","wrong cast","failed","cannot read","still blocked"}) then base=colors.red
    elseif has({"warning","pending","paused","suspect","unverified","unknown","uncertain","inspect"}) then base=colors.yellow
    elseif has({"success","verified","completed","cleared","moved","found"}) then base=colors.lime
    elseif text:match("^%s*#") or text:match("^%s*%-%-%-") or (text:find("%u") and not text:find("%l")) then base=colors.cyan end
  end
  local fg={};for index=1,#text do fg[index]=colors.toBlit(base) end
  local function paint(first,last,color)
    local code=colors.toBlit(color);for index=first,last do fg[index]=code end
  end
  local function skip(pos) while text:sub(pos,pos):match("%s") do pos=pos+1 end;return pos end
  local function isKey(pos)
    pos=skip(pos)
    if text:sub(pos,pos)=="]" then pos=skip(pos+1) end
    return text:sub(pos,pos)=="=" or text:sub(pos,pos)==":"
  end
  local function status(value)
    value=value:lower()
    if value=="error" or value=="table_error" or value=="missing" or value=="failed" then return colors.red end
    if value=="verified" or value=="installed" or value=="done" or value=="completed" or value=="success" then return colors.lime end
    if value=="pending" or value=="suspect" or value=="unverified" or value=="paused" or value=="unknown" or value=="not_started" then return colors.yellow end
  end
  local i=1;local key
  while i<=#text do
    local char=text:sub(i,i)
    if char=='"' or char=="'" then
      local j=i+1
      while j<=#text do
        if text:sub(j,j)=="\\" then j=j+2
        elseif text:sub(j,j)==char then break else j=j+1 end
      end
      j=math.min(j,#text)
      local value=text:sub(i+1,j-1)
      if isKey(j+1) then key=value:lower();if structured or base==colors.white then paint(i,j,colors.cyan) end
      elseif structured then paint(i,j,status(value) or colors.white) end
      i=j+1
    elseif char:match("[%a_]") then
      local _,last=text:find("^[%a_][%w_]*",i)
      last=last or i
      local value=text:sub(i,last);local name=value:lower()
      if isKey(last+1) then key=name;if structured or base==colors.white then paint(i,last,colors.cyan) end
      elseif structured then
        local color=status(name)
        if name=="true" or name=="false" then
          if key=="tableerror" or key=="error" then color=name=="true" and colors.red or colors.lime
          else color=name=="true" and colors.lime or colors.yellow end
        elseif name=="nil" or name=="null" then color=colors.gray end
        if color then paint(i,last,color) end
      end
      i=last+1
    elseif char:match("%d") or (char=="-" and text:sub(i+1,i+1):match("%d")) then
      local _,last=text:find("^%-?%d+%.?%d*[eE]?[+-]?%d*",i);last=last or i
      if structured then paint(i,last,colors.yellow) end
      i=last+1
    else
      if structured and char:match("[{}%[%],:=]") then paint(i,i,colors.gray) end
      if char=="," then key=nil end
      i=i+1
    end
  end
  -- Highlight physical table IDs in ordinary logs while retaining severity text.
  if not structured then
    local start=1
    while true do
      local first,last=text:find(":casting_%d+",start)
      if not first then break end
      while first>1 and text:sub(first-1,first-1):match("[%w_]") do first=first-1 end
      paint(first,last,colors.cyan);start=last+1
    end
  end
  return table.concat(fg)
end
local function coloredTextRows(width)
  if textRows and textRowsWidth==width then return textRows end
  textRows={};textRowsWidth=width
  for _,text in ipairs(textLines) do
    local fg=highlightText(text)
    if #text==0 then textRows[#textRows+1]={text="",fg=""} end
    for pos=1,#text,width do textRows[#textRows+1]={text=text:sub(pos,pos+width-1),fg=fg:sub(pos,pos+width-1)} end
  end
  return textRows
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
  line(2,view=="categories" and "Choose a category | S opens a shell" or view=="text" and (textPath or "Text reader") or (activeCategory or "Versions"))
  if view=="categories" then
    local page=math.floor((selected-1)/capacity)
    line(3,"Select section | Page "..(page+1).."/"..math.ceil(#CATEGORIES/capacity))
    for row=1,capacity do
      local index=page*capacity+row;local category=CATEGORIES[index]
      if category then
        local count=category=="Text Files" and #textFiles or 0
        if category~="Text Files" then for _,program in ipairs(programs) do if program.category==category then count=count+1 end end end
        line(row+3,(index==selected and "> " or "  ")..category.." ("..count..")",index==selected and colors.blue or colors.black)
      end
    end
  elseif view=="texts" then
    selected=math.max(1,math.min(selected,math.max(1,#textFiles)))
    local page=math.floor((selected-1)/capacity)
    line(3,"Page "..(page+1).."/"..math.max(1,math.ceil(#textFiles/capacity)).." | "..#textFiles.." text files")
    for row=1,capacity do
      local index=page*capacity+row;local entry=textFiles[index]
      if entry then line(row+3,(index==selected and "> " or "  ")..entry.file,index==selected and colors.blue or colors.black) end
    end
    if #textFiles==0 then line(4,"No .txt files found. R rescans.") end
  elseif view=="text" then
    local lines=coloredTextRows(w)
    offset=math.max(0,math.min(offset,math.max(0,#lines-capacity)))
    line(3,"READ ONLY | Lines "..(offset+1).."-"..math.min(#lines,offset+capacity).."/"..#lines)
    for row=1,capacity do
      local entry=lines[offset+row] or {text="",fg=""}
      if term.blit and (not term.isColor or term.isColor()) then
        local padding=w-#entry.text
        term.setCursorPos(1,row+3)
        term.blit(entry.text..string.rep(" ",padding),entry.fg..string.rep(colors.toBlit(colors.white),padding),string.rep(colors.toBlit(colors.black),w))
      else line(row+3,entry.text) end
    end
  elseif view=="list" then
    local visible=visiblePrograms()
    selected=math.max(1,math.min(selected,math.max(1,#visible)))
    local page=math.floor((selected-1)/capacity)
    line(3,"Page "..(page+1).."/"..math.max(1,math.ceil(#visible/capacity)))
    for row=1,capacity do
      local index=page*capacity+row
      local program=visible[index]
      if program then
        local state=session(program)
        local status=program.error and "METADATA ERROR" or not installed(program) and "MISSING" or state and (state.phase=="running" and (parityStatus(state)=="RESTART NEEDED" and "RESTART" or "RUNNING") or (state.success and "FINISHED" or "STOPPED")) or "READY"
        line(row+3,(selected==index and "> " or "  ")..program.title..(program.builtin and "" or " v"..program.version).." ["..status.."]",selected==index and colors.blue or colors.black)
      end
    end
    if #visible==0 then line(4,"No scripts in this category. R rescans.") end
  else
    local program=selectedProgram()
    local state=session(program)
    local content
    if view=="versions" or not program then content=versionLines() else
    content={program.title,"Category: "..program.category,"File: "..(program.builtin and program.file or fs.combine(ROOT,program.file)),
      "Version on disk: "..program.version.." / "..program.fingerprint,
      "Loaded: "..(state and tostring(state.version or "unknown") or "not running").." | "..parityStatus(state),
      "Arguments: "..table.concat(program.args or {}," "),"",program.description,"",
      program.allowMultiple and "Enter: open a new empty shell tab." or "Enter: start a foreground tab, or focus if already running.",
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
  line(h-3,view=="text" and "Up/Down scroll | PgUp/PgDn page | B back" or "Arrows/pages | Enter select/run | B back")
  line(h-2,(view=="text" or view=="texts") and "Text files are read only | S shell" or "D details | V versions | S shell | F focus")
  line(h-1,(view=="text" and "R reload" or "R rescan").." | Q exits ALL managed programs")
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
      local isList=view=="list" or view=="categories" or view=="texts"
      if key==keys.q then return
      elseif key==keys.up then if isList then selected=math.max(1,selected-1) else offset=math.max(0,offset-1) end
      elseif key==keys.down then if isList then selected=math.max(1,math.min(listSize(),selected+1)) else offset=offset+1 end
      elseif key==keys.pageUp then if isList then selected=math.max(1,selected-capacity) else offset=math.max(0,offset-capacity) end
      elseif key==keys.pageDown then if isList then selected=math.max(1,math.min(listSize(),selected+capacity)) else offset=offset+capacity end
      elseif key==keys.enter then
        if view=="categories" then
          activeCategory=CATEGORIES[selected]
          if activeCategory=="Text Files" then scanTextFiles();view="texts" else view="list" end
          selected=1;offset=0
        elseif view=="texts" then
          local entry=textFiles[selected];if entry then openTextFile(entry.path) end
        elseif view~="versions" and view~="text" then requestLaunch(selectedProgram(),false) end
      elseif key==keys.s then requestLaunch(byId[SHELL_ID],false)
      elseif key==keys.f then requestLaunch(selectedProgram(),true)
      elseif key==keys.d and selectedProgram() and view~="categories" then view="detail"; offset=0
      elseif key==keys.v then if view~="versions" then previousView=view end; view="versions"; offset=0
      elseif key==keys.b or key==keys.backspace then
        if view=="text" then view="texts";offset=0
        elseif view=="detail" then view="list"
        elseif view=="versions" then view=previousView or "categories"
        elseif view=="list" or view=="texts" then
          view="categories"
          for index,category in ipairs(CATEGORIES) do if category==activeCategory then selected=index; break end end
        end
      elseif key==keys.r then
        if view=="text" and textPath then openTextFile(textPath,true)
        elseif view=="texts" then scanTextFiles();selected=math.max(1,math.min(selected,math.max(1,#textFiles)));notice="Text file list refreshed"
        else refreshRegistry();scanTextFiles() end
      end
    elseif event=="mouse_scroll" then
      if view=="list" or view=="categories" or view=="texts" then selected=math.max(1,math.min(listSize(),selected+key)) else offset=math.max(0,offset+key) end
    end
  end
end
local ok,err=pcall(main)
shutdown()
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
if not ok then printError(err) end
print("Control Center closed; managed programs stopped.")
