-- @crafting-center {"version":"1.0.1","suite":"crafting-center","id":"cast_tracking","title":"Cast Tracking","launchable":false,"description":"Shared chest stock, installation records and output checks."}
return function(root,C)
 local T={}
 local statePath=fs.combine(root,"cast_installations.txt")
 local roles={"Ingot","Nugget","Gem","Gear","Rod","Plate","Sword","Katana","Machete","Spear","Trident","Knife","Dagger","Pickaxe","Shovel","Axe","Paxel","Hammer","Excavator","Hoe","Mattock","Prospector Hammer","Saw","Sickle","Shears","Fishing Rod","Bow","Crossbow","Slingshot","Arrow","Ring","Bracelet","Necklace","Helmet","Chestplate","Leggings","Boots","Shield","Tool Rod","Tip"}
 local ignored={cast=true,casts=true,casting=true,template=true,templates=true,blueprint=true,mold=true,mould=true,head=true,main=true,blade=true,blades=true}
 local function words(value)
  return tostring(value):lower():gsub("^.*:",""):gsub("[^%w]"," "):gsub("_"," ")
 end
 local function normalize(value)
  local result={}; for word in words(value):gmatch("%S+") do if not ignored[word] then result[#result+1]=word end end
  return table.concat(result,"")
 end
 local aliases={}; for _,role in ipairs(roles) do aliases[normalize(role)]=role end
 aliases.leggins="Leggings";aliases.shear="Shears";aliases.prospectinghammer="Prospector Hammer";aliases.tipupgrade="Tip";aliases.toolhandle="Tool Rod"
 function T.match(item,label)
  local override=(C.castItemMap or {})[item.name]
  if override then return aliases[normalize(override)] end
  local a,b=aliases[normalize(item.name)],aliases[normalize(label or item.name)]
  if a and b and a~=b then return nil end
  local text=(item.name.." "..(label or "")):lower()
  for _,term in ipairs({"cast","template","blueprint","mold","mould"}) do
   if text:find(term,1,true) then return b or a end
  end
 end
 function T.location(target)
  local n=tonumber((target or ""):match("casting_(%d+)$"))
  if n and n>=2 and n<=41 then
   local row=math.floor((n-2)/10)
   local labels={"Top row left","Bottom row left","Top row right","Bottom row right"}
   return target.." ("..labels[row+1]..", #"..((n-2)%10+1).." from back)"
  end
  return tostring(target)
 end
 local function readState()
  if not fs.exists(statePath) then
   assert(not fs.exists(statePath..".download") and not fs.exists(fs.combine(root,"backups/cast_installations.txt.bak")),"Cast installation record interrupted; inspect backups")
   return {}
  end
  local f=assert(fs.open(statePath,"r"));local raw=f.readAll();f.close()
  local state=textutils.unserialize(raw)
  assert(type(state)=="table","Unreadable cast_installations.txt; inspect records")
  return state
 end
 function T.record(role,target,status,reason)
  local state=readState()
  state[target]={role=role,status=status,reason=reason,updatedAt=os.epoch("utc")}
  -- Preserve previous state if writing is interrupted.
  local temp=statePath..".download"
  local f=assert(fs.open(temp,"w"));f.write(textutils.serialize(state));f.close()
  fs.makeDir(fs.combine(root,"backups"))
  if fs.exists(statePath) then
   local backup=fs.combine(root,"backups/cast_installations.txt.bak")
   if fs.exists(backup) then fs.delete(backup) end
   fs.copy(statePath,backup);fs.delete(statePath)
  end
  fs.move(temp,statePath)
  if status=="installed" or status=="missing" or status=="suspect" then T.refreshAvailability() end
  os.queueEvent("gear_cast_availability")
 end
 function T.status(role,target)
  local entry=readState()[target]
  if entry and entry.role~=role and entry.status~="missing" then return "suspect",entry end
  return entry and entry.role==role and entry.status or "missing",entry
 end
 function T.installed(role,target)
  local status=T.status(role,target)
  return status=="installed" or status=="verified"
 end
 function T.chest()
  local source=C.castChest or "sophisticatedstorage:chest_1"
  local found,unknown={},0
  for slot,item in pairs(peripheral.call(source,"list")) do
   local ok,detail=pcall(peripheral.call,source,"getItemDetail",slot)
   local role=T.match(item,ok and type(detail)=="table" and detail.displayName or item.name)
   if role then
    found[role]=found[role] or {quantity=0,slots={}}
    found[role].quantity=found[role].quantity+item.count
    found[role].slots[#found[role].slots+1]={slot=slot,name=item.name,nbt=item.nbt}
   else unknown=unknown+1 end
  end
  return found,unknown
 end
 function T.refreshAvailability(bindings)
  local report={schema=2,chest=C.castChest or "sophisticatedstorage:chest_1",checkedAt=os.epoch("utc"),
   casts={},scope="chest-and-installation-records"}
  local ok,found,unknown=pcall(T.chest)
  report.valid=ok; report.error=not ok and tostring(found) or nil
  report.unknownCount=ok and unknown or 0
  if not ok then found={} end
  local stateOK,state=pcall(readState)
  if not stateOK then report.valid=false;report.error=tostring(state);state={} end
  if not bindings then
   bindings={};for role,station in pairs(C.castStations or {}) do bindings[role]=station end
   local loaded,saved=pcall(function()
    local f=fs.open(fs.combine(root,"gear_stations.txt"),"r")
    if not f then return {} end
    local raw=f.readAll();f.close();local value=textutils.unserialize(raw)
    assert(type(value)=="table","Unreadable gear_stations.txt");return value
   end)
   if loaded then for role,station in pairs(saved) do bindings[role]=station end
   else report.valid=false;report.error=tostring(saved) end
  end
  for _,role in ipairs(roles) do
   local target=bindings[role] and bindings[role].peripheral
   local entry=target and state[target]
   local status=entry and entry.role==role and entry.status or "missing"
   if entry and entry.role~=role and entry.status~="missing" then status="suspect" end
   local stock=found[role]
   report.casts[role]={available=ok and stock~=nil,quantity=stock and stock.quantity or 0,
    installed=status=="installed" or status=="verified",status=status,station=target,record=entry}
  end
  local written,err=pcall(function()
   local path=fs.combine(root,"cast_availability.txt")
   local temp=path..".download"
   local f=assert(fs.open(temp,"w"));f.write(textutils.serialize(report));f.close()
   if fs.exists(path) then fs.delete(path) end
   fs.move(temp,path)
  end)
  if not written then report.valid=false;report.error="Cannot save cast availability: "..tostring(err) end
  return report
 end
 function T.ensure(role,target,bindings)
  if role=="Block" then return end
  local status=T.status(role,target)
  if status=="installed" or status=="verified" then return end
  if status=="pending" or status=="suspect" then error("Inspect cast at "..T.location(target).."; mark removed or installed in Station Setup",0) end
  local source=C.castChest or "sophisticatedstorage:chest_1"
  if source==target then error("Cast source equals destination",0) end
  local station=bindings[role]
  if not station or station.peripheral~=target or station.enabled==false then error("Invalid cast assignment",0) end
  for other,binding in pairs(bindings) do if other~=role and binding.peripheral==target then error("Shared cast station: "..T.location(target),0) end end
  if next(peripheral.call(target,"list")) then error("Output occupied at "..T.location(target),0) end
  for _,tank in pairs(peripheral.call(target,"tanks")) do if (tank.amount or 0)>0 then error("Fluid present at "..T.location(target),0) end end
  local entry=T.chest()[role]
  if not entry then error("No "..role.." cast available for "..T.location(target),0) end
  table.sort(entry.slots,function(a,b) return a.slot<b.slot end)
  local candidate=entry.slots[1]
  for _,other in ipairs(entry.slots) do
   if other.name~=candidate.name or other.nbt~=candidate.nbt then error("Ambiguous "..role.." casts; use Station Setup",0) end
  end
  T.record(role,target,"pending","Cast transfer started")
  local moved=peripheral.call(source,"pushItems",target,candidate.slot,1)
  if moved==0 then T.record(role,target,"missing","Insertion rejected");error("Cast insertion rejected at "..T.location(target),0) end
  if moved~=1 then error("Uncertain cast transfer at "..T.location(target),0) end
  T.record(role,target,"installed","One cast transferred; awaiting output verification")
 end
 function T.checkOutput(role,target,item,material,outputs)
  if not item then return false end
  local function contains(value,needle)
   local hay=" "..words(value):gsub("%s+"," ").." "
   local term=words(needle):gsub("%s+"," ")
   return hay:find(" "..term.." ",1,true)~=nil
  end
  local ok,detail=pcall(peripheral.call,target,"getItemDetail",1)
  local label=ok and type(detail)=="table" and detail.displayName or ""
  local match=contains(item.name,role) or contains(label,role)
  -- Gems use their material name (Diamond), rather than the word Gem.
  if role=="Gem" then match=material and (contains(item.name,material) or contains(label,material)) end
  local idsOK=not outputs or #outputs==0
  for _,id in ipairs(outputs or {}) do if item.name==id then idsOK=true end end
  if not match or not idsOK then
   if role~="Block" then T.record(role,target,"suspect","Wrong output: "..item.name.." / "..label) end
   error("Wrong output at "..T.location(target)..": expected "..role..", found "..item.name.." ("..label.."). Check installed cast.",0)
  end
  if role~="Block" then T.record(role,target,"verified","Expected output: "..item.name) end
  return true
 end
 return T
end
