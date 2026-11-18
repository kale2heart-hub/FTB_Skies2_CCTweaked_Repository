-- @crafting-center {"version":"1.5.2","suite":"crafting-center","id":"network_setup","title":"Fluid Network Setup","category":"Console Scripts","description":"Assign this computer, monitors, storage, block basins/output and its partner computer.","dependencies":["fluid_network.lua"],"locks":["fluid-network-setup"]}
local ROOT=fs.getDir(shell.getRunningProgram())
local N=dofile(fs.combine(ROOT,"fluid_network.lua"))
local c=N.load(ROOT)
c.basins=c.basins or {};c.keepMb=c.keepMb or 0
pcall(N.open,c) -- A configured Setup screen can answer discovery before either app starts.
local selected,offset,view=1,0,"main"
local message="Assign devices before joining networks. Computer ID: "..os.getComputerID()
local choices,field,multiple={},nil,false
local peers,scanNonce,scanTimer,scanCounter={},nil,nil,0
local function peerValue() if field=="client" then return c.clients[1] end;return c.serverId end
local function setPeer(id) if field=="client" then c.clients=id and {id} or {} else c.serverId=id end end
local function scanPeers(key)
 field=key;view="computers";selected=1;offset=0;peers={}
 local current=peerValue()
 if current~=nil then peers[current]={id=current,label="Computer #"..current,online=false} end
 for _,name in ipairs(peripheral.getNames()) do
  local readable=false
  local listed,list=pcall(peripheral.getMethods,name)
  if listed then
   local supported={};for _,method in ipairs(list or {}) do supported[method]=true end
   readable=supported.getID and supported.getLabel and supported.isOn
  end
  local ok,id=false,nil
  if readable then ok,id=pcall(peripheral.call,name,"getID") end
  if ok and type(id)=="number" and id~=os.getComputerID() then
   local labelled,label=pcall(peripheral.call,name,"getLabel")
   local powered,on=pcall(peripheral.call,name,"isOn")
   peers[id]={id=id,label=labelled and type(label)=="string" and label or "Computer #"..id,online=true,powered=not powered or on~=false}
  end
 end
 scanCounter=scanCounter+1;scanNonce=tostring(os.getComputerID())..":"..os.epoch("utc")..":"..scanCounter
 local opened=pcall(N.open,c)
 if opened then
  rednet.broadcast({kind="probe",version=1,nonce=scanNonce},N.discoveryProtocol)
  scanTimer=os.startTimer(2);message="Scanning computers... | Enter selects | R rescans | B back"
 else scanTimer=nil;message="Select a local wired modem to discover role labels; connected computers are listed" end
end
local function has(list,value) for i,x in ipairs(list) do if x==value then return i end end end
local function toggle(list,value) local i=has(list,value);if i then table.remove(list,i) else list[#list+1]=value end end
local function methods(name)
 local ok,result=pcall(peripheral.getMethods,name);local set={}
 if ok then for _,method in ipairs(result or {}) do set[method]=true end end
 return set
end
local function isStorageSource(name,m)
 if not (m.tanks and m.pushFluid) then return false end
 if name:match("^functionalstorage:") then return true end
 local types={pcall(peripheral.getType,name)}
 if types[1] then
  for i=2,#types do if type(types[i])=="string" and types[i]:match("^functionalstorage:") then return true end end
 end
 return false
end
local function deviceLess(a,b)
 local ap,an=a:match("^(.-)_(%d+)$");local bp,bn=b:match("^(.-)_(%d+)$")
 ap,bp=ap or a,bp or b
 if ap~=bp then return ap<bp end
 if an and bn and tonumber(an)~=tonumber(bn) then return tonumber(an)<tonumber(bn) end
 return a<b
end
local function monitorConnected(name)
 local ok,connected=pcall(peripheral.hasType,name,"monitor")
 return ok and connected==true
end
local function assignedDevices(key)
 local value=c[key]
 if type(value)=="table" then return value end
 if type(value)=="string" and value~="" then return {value} end
 return {}
end
local function connected(key,name,present)
 if key=="monitors" then return monitorConnected(name) end
 return present[name]==true
end
local function presentDevices()
 local result={};for _,name in ipairs(peripheral.getNames()) do result[name]=true end;return result
end
local function choose(key,kind,multi)
 choices={};field=key;multiple=multi
 for _,name in ipairs(peripheral.getNames()) do
  local m=methods(name)
  local valid=kind=="monitor" and peripheral.hasType(name,"monitor") or kind=="fluid" and m.tanks and m.pushFluid
  if kind=="modem" and has({"left","right","top","bottom","front","back"},name) and peripheral.hasType(name,"modem") then
   local ok,wireless=pcall(peripheral.call,name,"isWireless");valid=ok and wireless==false
  end
  if key=="castingFluidTank" then valid=isStorageSource(name,m) and not has(c.sources,name) and not has(c.gearSources,name) end
  if key=="sources" or key=="gearSources" then
   local other=key=="sources" and c.gearSources or c.sources
   valid=isStorageSource(name,m) and (not has(other,name) or has(c[key],name))
  end
  if key=="basins" or key=="destinations" then
   local casting=m.tanks and m.list and m.pushItems and
    (name:match("^productivemetalworks:casting_")~=nil or peripheral.hasType(name,"productivemetalworks:casting"))
   local other={} -- Peer assignments are validated over Rednet by the applications.
   -- Keep existing conflicts visible so they can be deselected, never silently reassigned.
   valid=casting and ((not has(other,name) and not has(c.sources,name) and not has(c.gearSources,name)) or has(c[key],name))
  elseif key=="blockOutputChest" then valid=m.list and m.size and m.pushItems and not m.tanks end
  if valid then choices[#choices+1]=name end
 end
 for _,name in ipairs(assignedDevices(key)) do if not has(choices,name) then choices[#choices+1]=name end end
 table.sort(choices,deviceLess);view="choose";selected=1;offset=0;message="Enter selects/toggles | B returns"
end
local function value(key)
 return c[key]
end
local function input(key,label)
 term.setCursorPos(1,select(2,term.getSize()));term.clearLine();write(label..": ")
 local answer=read();local n=tonumber(answer)
 if n and n>=0 and n<=1000000000 and n==math.floor(n) and ((key~="castingFluidTankCapacity" and key~="autoMinimumBlocks") or n>0) then
  if key=="client" then c.clients={n} else c[key]=n end
  message="Value saved in draft; select Save to apply"
 else message="Enter a whole number from 0 to 1,000,000,000" end
end
local function save()
 assert(c.role=="gear" or c.role=="fluid","Choose Gear computer or Fluid Monitor computer")
 assert(c.modem and c.modem~="","Select a local wired modem")
 assert(#c.monitors>0,"Assign at least one monitor")
 if c.role=="gear" then
  assert(#c.monitors<=3,"Gear UI supports up to three displays")
  assert(type(c.serverId)=="number","Set Fluid Monitor computer ID")
  assert(c.serverId~=os.getComputerID(),"Partner computer must have a different ID")
 else
  assert(#c.sources>0,"Assign Functional Storage fluid sources")
  for _,name in ipairs(c.sources) do
   assert(isStorageSource(name,methods(name)),"Source must be a connected Functional Storage fluid device: "..name..". Clear source selections and reselect if needed.")
  end
  for _,name in ipairs(c.gearSources) do
   assert(isStorageSource(name,methods(name)),"Gear-only source must be a connected Functional Storage fluid device: "..name)
  end
  assert(#c.clients>0 and c.clients[1]~=os.getComputerID(),"Set the Gear computer ID")
  local reserved={}
  local function reserve(name,owner)
   if reserved[name] then
    local short=name:match("^[^:]+:(.+)$") or name
    error(short.." conflicts with "..reserved[name]..". Remove its duplicate assignment from Network Setup.",0)
   end
   reserved[name]=owner
  end
  for _,name in ipairs(c.sources) do reserve(name,"a main fluid storage source") end
  for _,name in ipairs(c.gearSources) do reserve(name,"a Gear-only fluid storage source") end
  if c.castingFluidTank then
   reserve(c.castingFluidTank,"the Casting Fluid Tank")
   assert(isStorageSource(c.castingFluidTank,methods(c.castingFluidTank)),"Casting Fluid Tank must be a connected Functional Storage fluid device")
  end
  for _,name in ipairs(c.basins) do
   reserve(name,"a managed block basin")
   local m=methods(name);assert(m.list and m.tanks and m.pushItems,"Basin must expose fluids and item output: "..name)
  end
  if #c.basins>0 then
   local output=c.blockOutputChest;assert(type(output)=="string" and output~="","Assign the block output chest")
   assert(not reserved[output],"Output chest cannot be a basin, fluid source or Gear station")
   local m=methods(output);assert(m.list and m.size and m.pushItems,"Block output must be an inventory")
  end
  c.destinations={} -- Gear's live registration supplies its stations; do not duplicate them here.
  c.serverId=nil
  c.outputs=nil -- Retire the old ingot/block buffer assignments without reusing them as basins.
 end
 N.save(ROOT,c);message="Saved fluid_network.txt. Restart the affected application to apply."
end
local function entries()
 local present=presentDevices()
 if view=="computers" then
  local list={};for _,peer in pairs(peers) do list[#list+1]=peer end
  local wanted=field=="client" and "gear" or "fluid"
  table.sort(list,function(a,b)
   if (a.role==wanted)~=(b.role==wanted) then return a.role==wanted end
   return a.id<b.id
  end)
  local rows={{label="Clear saved computer",action=function() setPeer(nil);view="main";selected=1;offset=0 end}}
  for _,peer in ipairs(list) do
   local mismatch=peer.role and peer.role~="standalone" and peer.role~=wanted
   local label=(peerValue()==peer.id and "[x] " or "[ ] ").."#"..peer.id.." "..peer.label.." ["..(peer.online and (peer.role or "role unknown") or "OFFLINE").."]"
   if peer.powered==false then label=label.." [POWERED OFF]" end
   rows[#rows+1]={label=label,fg=not peer.online and colors.red or mismatch and colors.lightGray or nil,action=function()
    if not peer.online then
     if peerValue()==peer.id then setPeer(nil);view="main";selected=1;offset=0;message="Offline computer assignment removed" end
    elseif mismatch then message="Select a "..wanted.." computer; change its role on that computer if needed"
    else setPeer(peer.id);view="main";selected=1;offset=0;message="Computer selected; select SAVE to apply" end
   end}
  end
  return rows
 end
 if view=="choose" then
  local rows={}
  if field=="sources" or field=="gearSources" then rows[1]={label="Clear source selections",action=function() c[field]={} end}
  elseif field=="basins" then rows[1]={label="Clear managed basin selections",action=function() c.basins={} end}
  elseif field=="castingFluidTank" then rows[1]={label="Clear Casting Fluid Tank / direct mode",action=function() c.castingFluidTank=nil;view="main";selected=1;offset=0 end} end
  for _,name in ipairs(choices) do
   local current=value(field);local active=multiple and has(current or {},name) or current==name
   local conflict=(field=="sources" and has(c.gearSources,name)) or (field=="gearSources" and has(c.sources,name))
   local disconnected=not connected(field,name,present)
   rows[#rows+1]={label=(active and "[x] " or "[ ] ")..name..(disconnected and " [DISCONNECTED]" or conflict and " [CONFLICT]" or ""),fg=disconnected and colors.red or nil,action=function()
    if disconnected then
     if active then
      if multiple then toggle(c[field],name) else c[field]=nil;view="main";selected=1;offset=0 end
      message="Disconnected device assignment removed; select SAVE to apply"
     else message="Reconnect this device before assigning it again" end
     return
    end
    if multiple then
     if conflict and not has(c[field],name) then message="Device belongs to the other system; remove that assignment first";return end
     c[field]=c[field] or {};toggle(c[field],name)
    else c[field]=name;if field=="modem" then pcall(N.open,c) end;view="main";selected=1;offset=0 end
   end}
  end
  return rows
 end
 local rows={
  {label="Role: "..c.role,action=function() c.role=c.role=="gear" and "fluid" or "gear" end},
  {deviceKey="modem",label="Local wired modem: "..tostring(c.modem or "unset"),action=function() choose("modem","modem",false) end},
  {deviceKey="monitors",label="Assigned monitors: "..#c.monitors,action=function() choose("monitors","monitor",true) end},
 }
 local function add(label,action,deviceKey) rows[#rows+1]={label=label,action=action,deviceKey=deviceKey} end
 if c.role=="gear" then
  add("Fluid: Computer ID: "..tostring(c.serverId or "unset"),function() scanPeers("serverId") end)
  add("Additional Gear stations: "..#c.destinations,function() choose("destinations","fluid",true) end,"destinations")
  add("Reserve Gear casting_0 through casting_42",function()
   c.destinations={};for i=0,42 do c.destinations[#c.destinations+1]="productivemetalworks:casting_"..i end
   message="Draft Gear range 0-42. Active Station Setup assignments are also announced automatically."
  end)
 elseif c.role=="fluid" then
  add("Gear: Computer ID: "..tostring(c.clients[1] or "unset"),function() scanPeers("client") end)
  add("Main fluid storage sources: "..#c.sources,function() choose("sources","fluid",true) end,"sources")
  add("Gear-only fluid storage: "..#c.gearSources,function() choose("gearSources","fluid",true) end,"gearSources")
  add("Default Gear minimum: "..c.gearMinimumDefault.." mB",function() input("gearMinimumDefault","Minimum per fluid (mB)") end)
  add("Managed block basins: "..#c.basins,function() choose("basins","basin",true) end,"basins")
  add("Casting Fluid Tank: "..tostring(c.castingFluidTank or "unset"),function() choose("castingFluidTank","fluid",false) end,"castingFluidTank")
  add("Casting tank capacity: "..c.castingFluidTankCapacity.." mB",function() input("castingFluidTankCapacity","Tank capacity (mB, positive)") end)
  add("Auto minimum batch: "..c.autoMinimumBlocks.." blocks",function() input("autoMinimumBlocks","Minimum auto blocks (positive)") end)
  add("Block output chest: "..tostring(c.blockOutputChest or "unset"),function() choose("blockOutputChest","inventory",false) end,"blockOutputChest")
  add("Extra reserve for monitor casting: "..c.keepMb.." mB",function() input("keepMb","Additional fluid reserve per material (mB)") end)
  add("Disable local block casting",function() c.basins={};c.blockOutputChest=nil;c.outputs=nil;message="Basins cleared; fluid service remains available" end)
  add("Apply managed basin range 43-105",function()
   c.basins={};for i=43,105 do c.basins[#c.basins+1]="productivemetalworks:casting_"..i end
   message="Draft Fluid basins 43-105. Gear defines its own stations on the other computer."
  end)
 end
 add("SAVE configuration",save)
 for _,row in ipairs(rows) do
  if row.deviceKey then
   local missing,seen=0,{}
   for _,name in ipairs(assignedDevices(row.deviceKey)) do
    if not seen[name] and not connected(row.deviceKey,name,present) then missing=missing+1 end
    seen[name]=true
   end
   if missing>0 then row.label="["..missing.." DISCONNECTED] "..row.label;row.fg=colors.red end
  end
 end
 return rows
end
local function draw()
 local w,h=term.getSize();local rows=entries();local visible=math.max(1,h-9)
 selected=math.max(1,math.min(selected,#rows))
 if selected<=offset then offset=selected-1 end
 if selected>offset+visible then offset=selected-visible end
 term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear()
 local function line(y,label,bg,fg) term.setCursorPos(1,y);term.setBackgroundColor(bg or colors.black);term.setTextColor(fg or colors.white);term.write((label..string.rep(" ",w)):sub(1,w)) end
 line(1,"FLUID NETWORK SETUP | Computer "..os.getComputerID(),colors.blue)
 line(2,view=="computers" and "Select partner computer | Labels / IDs / Roles" or view=="choose" and ("Assign "..field.." | Changes are a draft") or "Separate computers | Explicit device assignments",nil,colors.lightGray)
 for i=1,visible do local row=rows[offset+i];if row then line(i+3,(selected==offset+i and "> " or "  ")..row.label,selected==offset+i and colors.blue or colors.black,row.fg) end end
 local wrapped={};local row=""
 for word in message:gmatch("%S+") do
  if #row+#word+1>w and row~="" then wrapped[#wrapped+1]=row;row="" end
  while #word>w do wrapped[#wrapped+1]=word:sub(1,w);word=word:sub(w+1) end
  row=row=="" and word or row.." "..word
 end
 if row~="" then wrapped[#wrapped+1]=row end
 for i=1,3 do line(h-6+i,wrapped[i] or "",nil,colors.lightGray) end
 line(h-1,"Arrows select | Enter apply | B back | R refresh | Q quit")
 return rows,visible
end
while true do
 local rows,visible=draw();local event,key,payload,protocol=os.pullEvent()
 if event=="rednet_message" then
  if not N.replyDiscovery(c,key,payload,protocol) and view=="computers" and protocol==N.discoveryProtocol and type(payload)=="table" and payload.kind=="hello" and payload.version==1 and payload.nonce==scanNonce and payload.id==key and key~=os.getComputerID() then
   if payload.role=="gear" or payload.role=="fluid" or payload.role=="standalone" then
    peers[key]={id=key,label=type(payload.label)=="string" and payload.label:sub(1,80) or "Computer #"..key,role=payload.role,online=true,powered=true}
   end
  end
 elseif event=="timer" and key==scanTimer and view=="computers" then
  local count=0;for _,peer in pairs(peers) do if peer.online then count=count+1 end end
  message="Found "..count.." computers | R rescans | Enter selects"
 elseif event=="key" then
  if key==keys.q then return
  elseif key==keys.b or key==keys.backspace then view="main";selected=1;offset=0
  elseif key==keys.up then selected=math.max(1,selected-1)
  elseif key==keys.down then selected=math.min(#rows,selected+1)
  elseif key==keys.pageUp then selected=math.max(1,selected-visible)
  elseif key==keys.pageDown then selected=math.min(#rows,selected+visible)
  elseif key==keys.enter and rows[selected] then local ok,err=pcall(rows[selected].action);if not ok then message=tostring(err):gsub("^.-:%d+:%s*","") end
  elseif key==keys.r then if view=="computers" then scanPeers(field) elseif view=="choose" then choose(field,field=="monitors" and "monitor" or field=="modem" and "modem" or "fluid",multiple) end end
 end
end
