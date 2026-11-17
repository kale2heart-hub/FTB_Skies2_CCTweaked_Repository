-- @crafting-center {"version":"1.2.1","suite":"crafting-center","id":"cast_check","title":"Check Cast Chest","category":"Tools","args":[],"description":"Read the cast chest and show found, missing and unidentified casts against the 40-cast plan.","dependencies":["cast_tracking.lua","gear_config.lua"]}
local ROOT=fs.getDir(shell.getRunningProgram())
local configPath=fs.combine(ROOT,"gear_config.lua")
local C=fs.exists(configPath) and dofile(configPath) or {}
local Cast=dofile(fs.combine(ROOT,"cast_tracking.lua"))(ROOT,C)
local CHEST=C.castChest or "sophisticatedstorage:chest_1"
local bindings={}
for role,station in pairs(C.castStations or {}) do bindings[role]=station end
local bindingPath=fs.combine(ROOT,"gear_stations.txt")
if fs.exists(bindingPath) then
 local f=assert(fs.open(bindingPath,"r"));local saved=textutils.unserialize(f.readAll());f.close()
 assert(type(saved)=="table","Unreadable gear_stations.txt")
 for role,station in pairs(saved) do bindings[role]=station end
end
local function installation(role)
 local station=bindings[role]
 local target=station and station.peripheral
 local ok,status,record=pcall(Cast.status,role,target)
 return ok and status or "unreadable",target,record
end
local found
local function usable(role)
 local status=installation(role)
 return found and found[role] or status=="installed" or status=="verified"
end

local required={"Ingot","Nugget","Gem","Gear","Rod","Plate","Sword","Katana","Machete",
 "Spear","Trident","Knife","Dagger","Pickaxe","Shovel","Axe","Paxel","Hammer",
 "Excavator","Hoe","Mattock","Prospector Hammer","Saw","Sickle","Shears","Fishing Rod",
 "Bow","Crossbow","Slingshot","Arrow","Ring","Bracelet","Necklace","Helmet",
 "Chestplate","Leggings","Boots","Shield","Tool Rod","Tip"}
assert(#required==40)
table.sort(required,function(a,b) return a:lower()<b:lower() end)
local ignored={cast=true,casts=true,casting=true,template=true,templates=true,
 blueprint=true,mold=true,mould=true,head=true,main=true,blade=true,blades=true}
local function normalize(value)
 local words={}
 value=value:lower():gsub("^.*:",""):gsub("[^%w]"," "):gsub("_"," ")
 for word in value:gmatch("%S+") do if not ignored[word] then words[#words+1]=word end end
 return table.concat(words,"")
end
local aliases={}
for _,role in ipairs(required) do aliases[normalize(role)]=role end
aliases.leggins="Leggings"; aliases.shear="Shears"; aliases.prospectinghammer="Prospector Hammer"
aliases.tipupgrade="Tip"; aliases.toolhandle="Tool Rod"
local function castLike(value)
 value=value:lower()
 return value:find("cast",1,true) or value:find("template",1,true) or value:find("blueprint",1,true)
  or value:find("mold",1,true) or value:find("mould",1,true)
end
local unknown,scanError={},nil
found={}
local count,stacks=0,0
local view,selected,offset="missing",1,0
local notice=""
local detail
local REPORT=fs.combine(ROOT,"cast_availability.txt")
local function saveAvailability()
 local report={schema=2,chest=CHEST,checkedAt=os.epoch("utc"),valid=scanError==nil,
  error=scanError,casts={},unknownCount=#unknown,scope="chest-and-installation-records"}
 for _,role in ipairs(required) do
  local status,target,record=installation(role)
  report.casts[role]={available=scanError==nil and found[role]~=nil,
   quantity=found[role] and found[role].quantity or 0,
   installed=status=="installed" or status=="verified",status=status,station=target,record=record,tableError=record and record.tableError or false}
 end
 local ok,err=pcall(function()
  local f=assert(fs.open(REPORT,"w")); f.write(textutils.serialize(report)); f.close()
 end)
 notice=ok and "Saved cast_availability.txt" or "Report save failed: "..tostring(err)
 if ok then os.queueEvent("gear_cast_availability") end
end
local function scan()
 found,unknown,scanError={},{},nil; count,stacks=0,0
 local ok,items=pcall(peripheral.call,CHEST,"list")
 if not ok or type(items)~="table" then scanError="Cannot read "..CHEST..": "..tostring(items); saveAvailability(); return end
 for slot,item in pairs(items) do
  stacks=stacks+1
  local detailOK,info=pcall(peripheral.call,CHEST,"getItemDetail",slot)
  info=detailOK and type(info)=="table" and info or {}
  local label=info.displayName or item.name
  local record={slot=slot,name=item.name,label=label,count=item.count,nbt=item.nbt,detail=info}
  local override=(C.castItemMap or {})[item.name]
  local idRole=aliases[normalize(item.name)]
  local labelRole=aliases[normalize(label)]
  local role=override or ((castLike(item.name) or castLike(label)) and (labelRole or idRole))
  if not override and idRole and labelRole and idRole~=labelRole then role=nil; record.reason="ID/display name disagree" end
  if role and aliases[normalize(role)] then
   role=aliases[normalize(role)]
   found[role]=found[role] or {quantity=0,slots={}}
   found[role].quantity=found[role].quantity+item.count
   found[role].slots[#found[role].slots+1]=record
  else
   record.reason=record.reason or "Name not recognized as one of the 40 casts"
   unknown[#unknown+1]=record
  end
 end
 for _,role in ipairs(required) do if usable(role) then count=count+1 end; if found[role] then table.sort(found[role].slots,function(a,b) return a.slot<b.slot end) end end
 table.sort(unknown,function(a,b) return a.slot<b.slot end)
 selected=1; offset=0; saveAvailability()
end
local function entries()
 local rows={}
 if scanError then return rows end
 if view=="unknown" then
  for _,item in ipairs(unknown) do rows[#rows+1]={label="Slot "..item.slot..": "..item.label.." x"..item.count,item=item} end
 else
  for _,role in ipairs(required) do
   local entry=found[role]
   if view=="all" or (view=="missing" and not usable(role)) or (view=="found" and usable(role)) then
    local status=installation(role)
    rows[#rows+1]={role=role,label=role.." | Chest "..(entry and entry.quantity or 0).." | "..status}
   end
  end
 end
 return rows
end
local function inspect(entry)
 if not entry then return end
 local lines={}
 if entry.item then
  lines={"UNIDENTIFIED ITEM","Slot: "..entry.item.slot,"Name: "..entry.item.label,
   "ID: "..entry.item.name,"Reason: "..entry.item.reason,textutils.serialize(entry.item)}
 else
  lines={entry.role,found[entry.role] and "FOUND IN CAST CHEST" or "NOT DETECTED IN CAST CHEST"}
  local info=found[entry.role]
  if info then for _,item in ipairs(info.slots) do
   lines[#lines+1]="Slot "..item.slot..": "..item.count.." x "..item.label
   lines[#lines+1]="ID: "..item.name
   lines[#lines+1]="NBT: "..tostring(item.nbt)
  end end
  local status,target=installation(entry.role)
  lines[#lines+1]="Installation: "..status
  lines[#lines+1]="Table: "..Cast.location(target)
  lines[#lines+1]="Installed state is recorded; expected output verifies it."
  if #unknown>0 then lines[#lines+1]="Unidentified items may include this cast. Inspect Unknown before assuming it is absent." end
 end
 detail=lines; offset=0
end
local function render()
 local w,h=term.getSize()
 term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear()
 local function line(y,text,bg,fg)
  term.setCursorPos(1,y); term.setBackgroundColor(bg or colors.black); term.setTextColor(fg or colors.white)
  text=tostring(text):sub(1,w); term.write(text..string.rep(" ",w-#text))
 end
 if w<20 or h<10 then line(1,"Need terminal 20x10"); return 1,{} end
 local capacity=h-7
 line(1,"CAST CHEST CHECK | v1.2.0",colors.blue)
 line(2,scanError and "Chest unreadable - no result" or ("Found "..count.."/40 | Missing "..(40-count).." | Unknown "..#unknown))
 line(3,detail and "DETAILS" or view:upper().." | "..CHEST)
 local rows=entries()
 if detail then
  local wrapped={}
  for _,value in ipairs(detail) do
   for text in (tostring(value).."\n"):gmatch("([^\n]*)\n") do
    if text=="" then wrapped[#wrapped+1]="" end
    for pos=1,#text,w do wrapped[#wrapped+1]=text:sub(pos,pos+w-1) end
   end
  end
  offset=math.max(0,math.min(offset,math.max(0,#wrapped-capacity)))
  for row=1,capacity do line(row+3,wrapped[offset+row] or "") end
 elseif scanError then line(4,scanError,colors.black,colors.red)
 else
  selected=math.max(1,math.min(selected,math.max(1,#rows)))
  local page=math.floor((selected-1)/capacity)
  for row=1,capacity do
   local index=page*capacity+row; local item=rows[index]
   if item then line(row+3,(index==selected and "> " or "  ")..item.label,index==selected and colors.blue or colors.black) end
  end
  if #rows==0 then line(4,view=="missing" and "All 40 roles have chest stock or installation." or "No entries in this view.") end
 end
 line(h-3,"Arrows/pages | Enter details | B back")
 line(h-2,"M missing | F found | A all | U unknown")
 line(h-1,"R rescan | Q quit | Report auto-saved")
 line(h,notice~="" and notice or (#unknown>0 and "Unknown names may affect missing results." or "Chest stock + recorded installation."),colors.gray)
 return capacity,rows
end
scan()
while true do
 local capacity,rows=render()
 local event,key=os.pullEvent()
 if event=="key" then
  notice=""
  if key==keys.q then break
  elseif key==keys.r then detail=nil; scan()
  elseif key==keys.b or key==keys.backspace then detail=nil
  elseif key==keys.enter or key==keys.d then if not detail then inspect(rows[selected]) end
  elseif key==keys.m or key==keys.f or key==keys.a or key==keys.u then
   view=key==keys.m and "missing" or key==keys.f and "found" or key==keys.a and "all" or "unknown"
   detail=nil;selected=1
  elseif key==keys.up then if detail then offset=math.max(0,offset-1) else selected=math.max(1,selected-1) end
  elseif key==keys.down then if detail then offset=offset+1 else selected=math.min(math.max(1,#rows),selected+1) end
  elseif key==keys.pageUp then if detail then offset=math.max(0,offset-capacity) else selected=math.max(1,selected-capacity) end
  elseif key==keys.pageDown then if detail then offset=offset+capacity else selected=math.min(math.max(1,#rows),selected+capacity) end end
 elseif event=="mouse_scroll" then if detail then offset=math.max(0,offset+key) else selected=math.max(1,math.min(math.max(1,#rows),selected+key)) end end
end
term.setBackgroundColor(colors.black);term.setTextColor(colors.white);term.clear();term.setCursorPos(1,1)
print("Cast chest check closed.")
