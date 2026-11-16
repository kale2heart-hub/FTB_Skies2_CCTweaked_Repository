-- @crafting-center {"version":"1.0.2","suite":"crafting-center","id":"stations","title":"Station Setup","args":[],"description":"Assign cast stations and test template insertion.","dependencies":["gear_config.lua"],"category":"Console Scripts"}
-- Dedicated casting-station setup and ONE-template insertion test.
-- Only T transfers an item; no command sends fluid or starts casting.
local ROOT=fs.getDir(shell.getRunningProgram())
local path=fs.combine(ROOT,"gear_stations.txt")
local configPath=fs.combine(ROOT,"gear_config.lua")
local C=fs.exists(configPath) and dofile(configPath) or {}
local castNames={"Ingot","Nugget","Gem","Gear","Rod","Plate",
  "Sword","Katana","Machete","Spear","Trident","Knife","Dagger",
  "Pickaxe","Shovel","Axe","Paxel","Hammer","Excavator","Hoe","Mattock",
  "Prospector Hammer","Saw","Sickle","Shears","Fishing Rod","Bow","Crossbow",
  "Slingshot","Arrow","Ring","Bracelet","Necklace","Helmet","Chestplate",
  "Leggings","Boots","Shield","Tool Rod","Tip"}
assert(#castNames==40,"Expected exactly 40 table casts")
local function planned(role,index)
  return {peripheral="productivemetalworks:casting_"..(index+1),
    part=index<=6 and "Material" or (role=="Tool Rod" or role=="Tip") and role or "Main",
    item=role,enabled=true}
end
local bindings={Block={peripheral=C.castingBasin or "productivemetalworks:casting_0",part="Material"}}
for i,role in ipairs(castNames) do bindings[role]=planned(role,i) end
for role,station in pairs(C.castStations or {}) do bindings[role]=station end
if fs.exists(path) then
  local f=assert(fs.open(path,"r")); local saved=textutils.unserialize(f.readAll()); f.close()
  assert(type(saved)=="table","Unreadable gear_stations.txt; assignments unchanged")
  for role,station in pairs(saved) do bindings[role]=station end
end
local function save()
  local backupRoot=fs.combine(ROOT,"backups")
  fs.makeDir(backupRoot)
  local backup=fs.combine(backupRoot,"gear_stations.txt.bak")
  local legacy=path..".bak"
  if fs.exists(legacy) and not fs.isDir(legacy) then
    local target=backup; local suffix=1
    while fs.exists(target) do
      target=fs.combine(backupRoot,"gear_stations.txt.legacy"..suffix..".bak"); suffix=suffix+1
    end
    fs.move(legacy,target)
  end
  if fs.exists(path) then
    if fs.exists(backup) then fs.delete(backup) end
    fs.copy(path,backup)
  end
  local f=assert(fs.open(path,"w")); f.write(textutils.serialize(bindings)); f.close()
end
local function discover()
  local names={}
  for _,name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name,"productivemetalworks:casting") or name:find("productivemetalworks:casting_",1,true) then
      local methods={}
      for _,method in ipairs(peripheral.getMethods(name) or {}) do methods[method]=true end
      if methods.list and methods.tanks and methods.pushItems then names[#names+1]=name end
    end
  end
  table.sort(names,function(a,b)
    local ap,an=a:match("^(.-)_(%d+)$"); local bp,bn=b:match("^(.-)_(%d+)$")
    if ap and bp and ap==bp then return tonumber(an)<tonumber(bn) end
    return a<b
  end)
  return names
end
local function applyPlan()
  local lines={"APPLY 40-CAST PLAN (casting_2 through casting_41)"}
  local owners={}
  for i,role in ipairs(castNames) do
    local station=planned(role,i)
    owners[station.peripheral]=role
    lines[#lines+1]=station.peripheral.." = "..role.." ["..station.part.."]"
    bindings[role]=station
  end
  bindings.Block={peripheral="productivemetalworks:casting_0",part="Material",enabled=true}
  owners[bindings.Block.peripheral]="Block"
  -- Explicitly applying the plan moves conflicts out of the requested range.
  for role,station in pairs(bindings) do
    local owner=owners[station.peripheral]
    if owner and owner~=role then
      lines[#lines+1]="Unassigned conflicting custom role: "..role
      station.peripheral=""
    end
    if station.peripheral=="productivemetalworks:casting_1" then
      lines[#lines+1]="Reserved manual table; unassigned: "..role
      station.peripheral=""
    end
  end
  save()
  return lines
end
-- Navigation uses the same arrows/Enter/page/back pattern as scan.lua.
local U={mode="roles",selected=1,offset=0,notice=""}
local history={}
local roles,names,items={},{},{}
local report={}
local roleContext,targetContext,testItem
local function shortName(name)
  return (name and name~="") and (name:match("^[^:]+:(.+)$") or name) or "UNASSIGNED"
end
local function refresh()
  roles={}; for role in pairs(bindings) do roles[#roles+1]=role end
  table.sort(roles,function(a,b) return a:lower()<b:lower() end)
  names=discover()
end
local function enter(mode)
  history[#history+1]={mode=U.mode,selected=U.selected,offset=U.offset}
  U.mode=mode; U.selected=1; U.offset=0
end
local function back()
  local previous=table.remove(history)
  if previous then U.mode=previous.mode; U.selected=previous.selected; U.offset=previous.offset
  else U.mode="roles"; U.selected=1; U.offset=0 end
end
local function invoke(name,method,...)
  if not name or name=="" then error("No station assigned",0) end
  local ok,value=pcall(peripheral.call,name,method,...)
  if not ok then error(name.."."..method..": "..tostring(value),0) end
  return value
end
local function owners(name)
  local result={}
  for role,station in pairs(bindings) do if station.peripheral==name then result[#result+1]=role end end
  table.sort(result); return table.concat(result,", ")
end
local function openReport(lines)
  report=lines; enter("report")
end
local function inspect()
  local station=bindings[roleContext]
  local name=station and station.peripheral
  local lines={"Role: "..roleContext,"Part: "..(station.part or "Main"),"Peripheral: "..tostring(name)}
  local function dump(label,method)
    local ok,value=pcall(invoke,name,method)
    lines[#lines+1]=label
    lines[#lines+1]=ok and textutils.serialize(value) or "ERROR: "..tostring(value)
  end
  dump("--- ITEMS ---","list"); dump("--- FLUIDS ---","tanks")
  lines[#lines+1]="--- METHODS ---"
  for _,method in ipairs(peripheral.getMethods(name or "") or {}) do lines[#lines+1]=method end
  lines[#lines+1]="Installed casts are hidden from normal inventory access."
  openReport(lines)
end
local function openTemplates(target)
  if not target or target=="" then U.notice="Assign a station first (E)"; return end
  targetContext=target
  local source=C.castChest or "sophisticatedstorage:chest_1"
  local snapshot=invoke(source,"list")
  items={}
  for slot,item in pairs(snapshot) do items[#items+1]={slot=slot,item=item} end
  table.sort(items,function(a,b) return a.slot<b.slot end)
  enter("templates")
  U.notice="Select one cast-chest item; nothing moves until test confirmation."
end
local function transferTest()
  local source=C.castChest or "sophisticatedstorage:chest_1"
  local target=targetContext
  local slot,original=testItem.slot,testItem.item
  if source==target then error("Source and destination must differ",0) end
  if next(invoke(target,"list")) then error("Destination output occupied; nothing moved",0) end
  for _,tank in pairs(invoke(target,"tanks")) do
    if (tank.amount or 0)>0 then error("Destination has fluid; nothing moved",0) end
  end
  local current=invoke(source,"list")[slot]
  if not current or current.name~=original.name or current.nbt~=original.nbt then error("Source changed; select the item again",0) end
  -- Exactly ONE insertion attempt. No fluid, casting or automatic retries.
  local moved=invoke(source,"pushItems",target,slot,1)
  local lines={"ONE-TEMPLATE TRANSFER RESULT","Source: "..source,"Slot: "..slot,
    "Item: "..current.name,"Target: "..target,"Items moved: "..tostring(moved)}
  -- Post-transfer read errors must not invite a second attempt.
  local ok,after=pcall(invoke,source,"list")
  if ok then
    local stack=after[slot]
    local same=stack and stack.name==current.name and stack.nbt==current.nbt
    lines[#lines+1]="Source count: "..current.count.." -> "..tostring(same and stack.count or 0)
  else lines[#lines+1]="Source recheck failed: "..tostring(after) end
  local readOK,result=pcall(invoke,target,"list")
  if readOK then
    for dest,item in pairs(result) do lines[#lines+1]="Destination slot "..dest..": "..item.name.." x"..item.count end
  else lines[#lines+1]="Destination recheck failed: "..tostring(result) end
  if moved==0 then
    lines[#lines+1]="Normal inventory insertion rejected; no cast installed."
    lines[#lines+1]="If physically empty, the cast slot may not be accessible."
  elseif moved==1 then
    lines[#lines+1]="One item transferred. Visually verify cast installation."
    lines[#lines+1]="Transport success does not prove which slot accepted it."
  else lines[#lines+1]="Unexpected result: inspect both inventories." end
  lines[#lines+1]="No fluid sent. No automatic retry."
  -- Remove the test-confirmation page so Back cannot immediately repeat it.
  back()
  openReport(lines)
end
local function chooseStation(name)
  if name=="productivemetalworks:casting_1" then U.notice="casting_1 is reserved for manual tests"; return end
  for other,station in pairs(bindings) do
    if other~=roleContext and station.peripheral==name then U.notice="Already assigned to "..other; return end
  end
  local station=bindings[roleContext]
  station.peripheral=name; station.enabled=true
  save(); back(); U.notice="Saved "..roleContext.." -> "..shortName(name)
end
local function customRole()
  -- Consume the A key release before read(), so its char event is not
  -- accidentally inserted at the beginning of the new role name.
  repeat local _,released=os.pullEvent("key_up") until released==keys.a
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  print("New cast role name (Enter cancels):")
  local role=read():match("^%s*(.-)%s*$")
  if role and role~="" then
    if not bindings[role] then bindings[role]={peripheral="",part="Main"}; save() end
    roleContext=role; refresh(); enter("detail")
  end
end
local function rows()
  local result={}
  if U.mode=="roles" then
    for _,role in ipairs(roles) do
      local station=bindings[role]
      local connected=station.peripheral and station.peripheral~="" and peripheral.isPresent(station.peripheral)
      result[#result+1]=(connected and "+ " or "- ")..role.." ["..(station.part or "Main").."] -> "..shortName(station.peripheral)
    end
  elseif U.mode=="stations" then
    for _,name in ipairs(names) do
      local owner=owners(name)
      result[#result+1]=shortName(name)..(owner~="" and " ["..owner.."]" or "")
    end
  elseif U.mode=="templates" then
    for _,entry in ipairs(items) do result[#result+1]="Slot "..entry.slot..": "..entry.item.count.." x "..entry.item.name end
  end
  return result
end
local function detailLines()
  if U.mode=="detail" then
    local station=bindings[roleContext]
    return {"Role: "..roleContext,"Part: "..(station.part or "Main"),
      "Peripheral: "..tostring(station.peripheral),
      "Connected: "..tostring(peripheral.isPresent(station.peripheral or "")),"",
      "E: choose a station | U: unassign","D: inspect items, fluids and methods",
      "T: test one template into this station","M: test into manual casting_1 instead","",
      "Casts must match their intended station.","Bindings do not prove a cast is installed."}
  elseif U.mode=="test" then
    return {"ONE-TEMPLATE INSERTION TEST","Source: "..(C.castChest or "sophisticatedstorage:chest_1"),
      "Source slot: "..testItem.slot,"Item: "..testItem.item.name,
      "NBT hash: "..tostring(testItem.item.nbt),"Target: "..targetContext,"Quantity: 1","",
      "Use a physically cast-free, empty destination.",
      "Installed casts are hidden from normal inventory access.",
      "ENTER: attempt one item transfer","B: cancel without moving anything","No fluid is sent; no retry is performed."}
  elseif U.mode=="plan" then
    local lines={"FIXED 40-CAST PLAN","casting_0 = Block basin","casting_1 = Manual tests only",""}
    for i,role in ipairs(castNames) do local station=planned(role,i); lines[#lines+1]=shortName(station.peripheral).." = "..role.." ["..station.part.."]" end
    lines[#lines+1]=""; lines[#lines+1]="ENTER applies this plan; B cancels."
    lines[#lines+1]="Previous assignments are backed up."
    return lines
  else return report end
end
local function wrapped(lines,width)
  local result={}
  for _,value in ipairs(lines) do
    for line in (tostring(value).."\n"):gmatch("([^\n]*)\n") do
      if line=="" then result[#result+1]="" end
      for pos=1,#line,width do result[#result+1]=line:sub(pos,pos+width-1) end
    end
  end
  return result
end
local function render()
  local w,h=term.getSize()
  term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
  local function line(y,label,bg)
    term.setCursorPos(1,y); term.setBackgroundColor(bg or colors.black)
    label=tostring(label):sub(1,w); term.write(label..string.rep(" ",w-#label))
  end
  if w<20 or h<10 then line(1,"Need terminal 20x10"); return 1 end
  local capacity=h-7
  line(1,"CRAFTING CENTER | STATION SETUP",colors.blue)
  line(2,U.mode=="roles" and (#roles.." roles | + connected / - missing") or U.mode:upper()..(roleContext and " | "..roleContext or ""))
  local list=rows()
  local isList=U.mode=="roles" or U.mode=="stations" or U.mode=="templates"
  if isList then
    U.selected=math.max(1,math.min(U.selected,math.max(1,#list)))
    local page=math.floor((U.selected-1)/capacity)
    line(3,"Page "..(page+1).."/"..math.max(1,math.ceil(#list/capacity)).." | Entries: "..#list)
    if #list==0 then line(4,"No entries. R refreshes.") end
    for row=1,capacity do
      local index=page*capacity+row
      if list[index] then line(row+3,(index==U.selected and "> " or "  ")..list[index],index==U.selected and colors.blue or colors.black) end
    end
  else
    local lines=wrapped(detailLines(),w)
    U.offset=math.max(0,math.min(U.offset,math.max(0,#lines-capacity)))
    line(3,"Lines "..(U.offset+1).."-"..math.min(#lines,U.offset+capacity).."/"..#lines)
    for row=1,capacity do line(row+3,lines[U.offset+row] or "") end
  end
  if U.mode=="roles" then
    line(h-3,"Arrows/PgUp/PgDn select | Enter details")
    line(h-2,"P plan | E assign | T template | M manual")
    line(h-1,"R refresh | A custom role | Q quit")
  elseif U.mode=="detail" then
    line(h-3,"E assign | U unassign | D inspect")
    line(h-2,"T template test | M manual-table test")
    line(h-1,"Arrows/pages scroll | B back | Q quit")
  elseif U.mode=="stations" or U.mode=="templates" then
    line(h-3,"Arrows/PgUp/PgDn select | Enter chooses")
    line(h-2,"D inspect selected item (templates only)")
    line(h-1,"R refresh | B back | Q quit")
  elseif U.mode=="test" then
    line(h-3,"Enter: transfer ONE item | B: cancel")
    line(h-2,"No fluid sent. No automatic retry.")
    line(h-1,"Arrows/pages scroll | Q quit")
  elseif U.mode=="plan" then
    line(h-3,"Enter applies fixed 2-41 assignments")
    line(h-2,"Casts are not physically installed.")
    line(h-1,"Arrows/pages scroll | B cancel | Q quit")
  else
    line(h-3,"Up/Down scroll | PgUp/PgDn page")
    line(h-2,"B returns to the previous screen")
    line(h-1,"Q quit")
  end
  line(h,U.notice,colors.gray)
  return capacity
end
local function contextRole()
  if U.mode=="roles" then return roles[U.selected] end
  return roleContext
end
local function handle(key,capacity)
  U.notice=""
  local isList=U.mode=="roles" or U.mode=="stations" or U.mode=="templates"
  if key==keys.b or key==keys.backspace then back(); return end
  if key==keys.up then if isList then U.selected=math.max(1,U.selected-1) else U.offset=math.max(0,U.offset-1) end
  elseif key==keys.down then if isList then U.selected=U.selected+1 else U.offset=U.offset+1 end
  elseif key==keys.pageUp then if isList then U.selected=math.max(1,U.selected-capacity) else U.offset=math.max(0,U.offset-capacity) end
  elseif key==keys.pageDown then if isList then U.selected=U.selected+capacity else U.offset=U.offset+capacity end
  elseif key==keys.r then
    refresh()
    if U.mode=="templates" then
      local source=C.castChest or "sophisticatedstorage:chest_1"
      items={}; for slot,item in pairs(invoke(source,"list")) do items[#items+1]={slot=slot,item=item} end
      table.sort(items,function(a,b) return a.slot<b.slot end)
    end
    U.notice="Refreshed"
  elseif key==keys.p and U.mode=="roles" then enter("plan")
  elseif key==keys.a and U.mode=="roles" then customRole()
  elseif (key==keys.e or key==keys.t or key==keys.m) and (U.mode=="roles" or U.mode=="detail") then
    roleContext=contextRole()
    if not roleContext then return end
    if key==keys.e then refresh(); enter("stations")
    else openTemplates(key==keys.m and (C.manualCastingTable or "productivemetalworks:casting_1") or bindings[roleContext].peripheral) end
  elseif key==keys.u and U.mode=="detail" then
    bindings[roleContext].peripheral=""; save(); U.notice="Unassigned "..roleContext
  elseif key==keys.d and U.mode=="detail" then inspect()
  elseif key==keys.d and U.mode=="templates" and items[U.selected] then
    local slot=items[U.selected].slot
    openReport({"Cast chest slot "..slot,textutils.serialize(invoke(C.castChest or "sophisticatedstorage:chest_1","getItemDetail",slot))})
  elseif key==keys.enter then
    if U.mode=="roles" and roles[U.selected] then roleContext=roles[U.selected]; enter("detail")
    elseif U.mode=="stations" and names[U.selected] then chooseStation(names[U.selected])
    elseif U.mode=="templates" and items[U.selected] then testItem=items[U.selected]; enter("test")
    elseif U.mode=="test" then transferTest()
    elseif U.mode=="plan" then report=applyPlan(); refresh(); U.mode="report"; U.offset=0; U.notice="Plan saved; casts still need installation" end
  end
end
refresh()
while true do
  local capacity=render()
  local event,key=os.pullEvent()
  if event=="key" then
    if key==keys.q then break end
    local ok,err=pcall(handle,key,capacity)
    if not ok then
      U.notice=tostring(err)
      -- An uncertain transfer exception must not leave Enter armed for retry.
      if U.mode=="test" then back(); openReport({"TEST STOPPED",tostring(err),"Inspect inventories before trying again. No automatic retry."}) end
    end
  elseif event=="mouse_scroll" then
    if U.mode=="roles" or U.mode=="stations" or U.mode=="templates" then U.selected=math.max(1,U.selected+key)
    else U.offset=math.max(0,U.offset+key) end
  end
end
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
print("Station setup closed. Restart gear_ui to load saved assignments.")
