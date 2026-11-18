-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"network_setup","title":"Fluid Network Setup","category":"Console Scripts","description":"Assign this computer, monitors, storage, casting buffers and its partner computer.","dependencies":["fluid_network.lua"],"locks":["fluid-network-setup"]}
local ROOT=fs.getDir(shell.getRunningProgram())
local N=dofile(fs.combine(ROOT,"fluid_network.lua"))
local c=N.load(ROOT)
c.outputs=c.outputs or {};c.keepMb=c.keepMb or 0
local selected,offset,view=1,0,"main"
local message="Assign devices before joining networks. Computer ID: "..os.getComputerID()
local choices,field,multiple={},nil,false
local function has(list,value) for i,x in ipairs(list) do if x==value then return i end end end
local function toggle(list,value) local i=has(list,value);if i then table.remove(list,i) else list[#list+1]=value end end
local function methods(name)
 local ok,result=pcall(peripheral.getMethods,name);local set={}
 if ok then for _,method in ipairs(result or {}) do set[method]=true end end
 return set
end
local function choose(key,kind,multi)
 choices={};field=key;multiple=multi
 for _,name in ipairs(peripheral.getNames()) do
  local m=methods(name)
  local valid=kind=="monitor" and peripheral.hasType(name,"monitor") or kind=="fluid" and m.tanks and m.pushFluid
  if kind=="modem" and has({"left","right","top","bottom","front","back"},name) and peripheral.hasType(name,"modem") then
   local ok,wireless=pcall(peripheral.call,name,"isWireless");valid=ok and wireless==false
  end
  if valid then choices[#choices+1]=name end
 end
 table.sort(choices);view="choose";selected=1;offset=0;message="Enter selects/toggles | B returns"
end
local function value(key)
 if key=="ingot" then return c.outputs.Ingot elseif key=="block" then return c.outputs.Block end
 return c[key]
end
local function input(key,label)
 term.setCursorPos(1,select(2,term.getSize()));term.clearLine();write(label..": ")
 local answer=read();local n=tonumber(answer)
 if n and n>=0 and n==math.floor(n) then
  if key=="client" then c.clients={n} else c[key]=n end
  message="Value saved in draft; select Save to apply"
 else message="Enter a non-negative whole number" end
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
  assert(#c.sources>0,"Assign fluid storage")
  assert(#c.clients>0 and c.clients[1]~=os.getComputerID(),"Set the Gear computer ID")
  assert(#c.destinations>0,"Allow the Gear casting destinations")
  local reserved={}
  for _,name in ipairs(c.sources) do reserved[name]=true end
  for _,name in ipairs(c.destinations) do assert(not reserved[name],"Storage cannot also be a Gear table");reserved[name]=true end
  for _,name in pairs(c.outputs) do if name~="" then assert(not reserved[name],"Monitor buffers must be separate from storage and Gear tables");reserved[name]=true end end
 end
 N.save(ROOT,c);message="Saved fluid_network.txt. Restart the affected application to apply."
end
local function entries()
 if view=="choose" then
  local rows={}
  for _,name in ipairs(choices) do
   local current=value(field);local active=multiple and has(current or {},name) or current==name
   rows[#rows+1]={label=(active and "[x] " or "[ ] ")..name,action=function()
    if multiple then c[field]=c[field] or {};toggle(c[field],name)
    else if field=="ingot" then c.outputs.Ingot=name elseif field=="block" then c.outputs.Block=name else c[field]=name end;view="main";selected=1;offset=0 end
   end}
  end
  return rows
 end
 return {
  {label="Role: "..c.role,action=function() c.role=c.role=="gear" and "fluid" or "gear" end},
  {label="Local wired modem: "..tostring(c.modem or "unset"),action=function() choose("modem","modem",false) end},
  {label="Assigned monitors: "..#c.monitors,action=function() choose("monitors","monitor",true) end},
  {label="Gear: Fluid Monitor ID: "..tostring(c.serverId or "unset"),action=function() input("serverId","Fluid Monitor computer ID") end},
  {label="Fluid Monitor: Gear ID: "..tostring(c.clients[1] or "unset"),action=function() input("client","Gear computer ID") end},
  {label="Fluid storage sources: "..#c.sources,action=function() choose("sources","fluid",true) end},
  {label="Allowed Gear casting destinations: "..#c.destinations,action=function() choose("destinations","fluid",true) end},
  {label="Monitor ingot buffer: "..tostring(c.outputs.Ingot or "unset"),action=function() choose("ingot","fluid",false) end},
  {label="Monitor block buffer: "..tostring(c.outputs.Block or "unset"),action=function() choose("block","fluid",false) end},
  {label="Extra reserve for monitor casting: "..c.keepMb.." mB",action=function() input("keepMb","Additional fluid reserve per material (mB)") end},
  {label="Disable monitor casting buffers",action=function() c.outputs={};message="Buffers cleared; monitoring and Gear service remain available" end},
  {label="SAVE configuration",action=save},
 }
end
local function draw()
 local w,h=term.getSize();local rows=entries();local visible=math.max(1,h-6)
 selected=math.max(1,math.min(selected,#rows))
 if selected<=offset then offset=selected-1 end
 if selected>offset+visible then offset=selected-visible end
 term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear()
 local function line(y,label,bg,fg) term.setCursorPos(1,y);term.setBackgroundColor(bg or colors.black);term.setTextColor(fg or colors.white);term.write((label..string.rep(" ",w)):sub(1,w)) end
 line(1,"FLUID NETWORK SETUP | Computer "..os.getComputerID(),colors.blue)
 line(2,view=="choose" and ("Assign "..field.." | Changes are a draft") or "Separate computers | Explicit device assignments",nil,colors.lightGray)
 for i=1,visible do local row=rows[offset+i];if row then line(i+3,(selected==offset+i and "> " or "  ")..row.label,selected==offset+i and colors.blue or colors.black) end end
 line(h-2,message,nil,colors.lightGray)
 line(h-1,"Arrows select | Enter apply | B back | R refresh | Q quit")
 return rows,visible
end
while true do
 local rows,visible=draw();local event,key=os.pullEvent()
 if event=="key" then
  if key==keys.q then return
  elseif key==keys.b or key==keys.backspace then view="main";selected=1;offset=0
  elseif key==keys.up then selected=math.max(1,selected-1)
  elseif key==keys.down then selected=math.min(#rows,selected+1)
  elseif key==keys.pageUp then selected=math.max(1,selected-visible)
  elseif key==keys.pageDown then selected=math.min(#rows,selected+visible)
  elseif key==keys.enter and rows[selected] then local ok,err=pcall(rows[selected].action);if not ok then message=tostring(err) end
  elseif key==keys.r then if view=="choose" then choose(field,field=="monitors" and "monitor" or field=="modem" and "modem" or "fluid",multiple) end end
 end
end
