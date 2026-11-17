-- @crafting-center {"version":"1.1.5","suite":"crafting-center","id":"cast_tracking","title":"Cast Tracking","launchable":false,"description":"Shared chest stock, installation records and output checks."}
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
 local backupPath=fs.combine(root,"backups/cast_installations.txt.bak")
 local writing,snapshot=false,nil
 local function clone(value)
  if type(value)~="table" then return value end
  local result={};for key,item in pairs(value) do result[key]=clone(item) end;return result
 end
 local function decodeState(path)
  if not fs.exists(path) then return nil end
  local ok,state=pcall(function()
   local f=assert(fs.open(path,"r"));local raw=f.readAll();f.close()
   local value=textutils.unserialize(raw)
   assert(type(value)=="table","Invalid installation record")
   for target,entry in pairs(value) do
    assert(type(target)=="string" and type(entry)=="table" and type(entry.role)=="string" and type(entry.status)=="string","Invalid installation entry")
   end
   return value
  end)
  return ok and state or nil
 end
 local function migrateRecoveryMarkers(state)
  for _,entry in pairs(state) do
   local reason=entry.reason or ""
   if not entry.tableError and entry.status=="suspect" and
      (reason:find("Installation missing from recovered backup",1,true)==1 or reason:find("Recovered older installation backup",1,true)==1) then
    entry.status="unverified"
    entry.reason="Recovered installation is unverified; the next requested output will verify the cast"
   end
  end
  return state
 end
 local function readState()
  -- Readers in this instance see a complete snapshot during a commit.
  if writing then return clone(snapshot) end
  local primary=decodeState(statePath)
  if primary then return migrateRecoveryMarkers(primary) end
  local pending=decodeState(statePath..".download")
  if pending then return migrateRecoveryMarkers(pending) end
  local backup=decodeState(backupPath)
  if backup then
   -- An older backup cannot prove the current installed state. Preserve locks
   -- and transfer uncertainty, and require verification of the other entries.
   migrateRecoveryMarkers(backup)
   for _,entry in pairs(backup) do
    if not entry.tableError and entry.status~="pending" and entry.status~="suspect" then
     entry.status="unverified";entry.reason="Recovered installation is unverified; the next requested output will verify the cast"
    end
   end
   for role,station in pairs(C.castStations or {}) do
    local target=station.peripheral
    if target and target~="" and not backup[target] then
     backup[target]={role=role,status="unverified",reason="No installation record in recovered backup; the next requested output will verify the cast"}
    end
   end
   return backup
  end
  assert(not fs.exists(statePath) and not fs.exists(statePath..".download") and not fs.exists(backupPath),
   "No valid cast installation record could be recovered; original files retained in cast_installations.txt / .download / backups")
  return {}
 end
 local function saveState(state)
  snapshot=clone(state);writing=true
  local ok,err=pcall(function()
   local temp=statePath..".download"
   fs.makeDir(fs.combine(root,"backups"))
   -- Back up the surviving complete source BEFORE reusing the pending file.
   local primary=decodeState(statePath)
   local prior=primary and statePath or decodeState(temp) and temp or nil
   if prior then
    local staging=backupPath..".download"
    if fs.exists(staging) then fs.delete(staging) end
    fs.copy(prior,staging)
    if fs.exists(backupPath) then fs.delete(backupPath) end
    fs.move(staging,backupPath)
   end
   if fs.exists(statePath) and not primary then
    local archive=fs.combine(root,"backups/cast_installations.corrupt_"..os.epoch("utc")..".txt")
    local suffix=0;local candidate=archive
    while fs.exists(candidate) do suffix=suffix+1;candidate=archive.."."..suffix end
    fs.copy(statePath,candidate)
   end
   local f=assert(fs.open(temp,"w"));f.write(textutils.serialize(state));f.close()
   assert(decodeState(temp),"New installation save failed validation; previous files retained")
   if fs.exists(statePath) then fs.delete(statePath) end
   fs.move(temp,statePath)
  end)
  writing=false;snapshot=nil
  if not ok then error("Could not save cast installations: "..tostring(err),0) end
 end
 function T.resetInstallations()
  local paths={backupPath..".download",backupPath,statePath..".download",statePath}
  -- Check all targets before deletion, and leave the primary until last.
  for _,path in ipairs(paths) do
   assert(not fs.exists(path) or not fs.isDir(path),"Cannot reset: expected a file at "..path)
  end
  snapshot={};writing=true
  local removed=0
  local ok,err=pcall(function()
   for _,path in ipairs(paths) do if fs.exists(path) then fs.delete(path);removed=removed+1 end end
  end)
  writing=false;snapshot=nil
  os.queueEvent("gear_cast_availability")
  if not ok then error("Installation reset incomplete: "..tostring(err),0) end
  T.refreshAvailability()
  return removed
 end
 function T.record(role,target,status,reason)
  local state=readState();local previous=state[target]
  state[target]={role=role,status=status,reason=reason,updatedAt=os.epoch("utc"),
   tableError=previous and previous.tableError or false,actualCast=previous and previous.actualCast}
  saveState(state)
  if status=="installed" or status=="missing" or status=="suspect" then T.refreshAvailability() end
  os.queueEvent("gear_cast_availability")
 end
 function T.setTableError(role,target,actual,reason)
  local state=readState()
  state[target]={role=role,status="missing",tableError=true,actualCast=actual,reason=reason,updatedAt=os.epoch("utc")}
  saveState(state);T.refreshAvailability();os.queueEvent("gear_cast_availability")
 end
 function T.clearTableErrors(bindings,extraTarget,extraRole)
  local state=readState();local count=0;local lines={};local cleared={}
  local targets={}
  for target,entry in pairs(state) do if entry.tableError then targets[#targets+1]=target end end
  -- Include an old wrong-output journal even if its saved table flag is stale.
  if extraTarget and not (state[extraTarget] and state[extraTarget].tableError) then
   state[extraTarget]=state[extraTarget] or {role=extraRole,status="missing"}
   state[extraTarget].tableError=true;targets[#targets+1]=extraTarget
  end
  table.sort(targets)
  for _,target in ipairs(targets) do
   local entry=state[target];local role=entry.role
   local owners={}
   for name,station in pairs(bindings or {}) do if station.peripheral==target then owners[#owners+1]=name end end
   if #owners==1 then role=owners[1] end
   local ok,result=pcall(function()
    assert(#owners<=1,"Table assigned to multiple cast types")
    local items=peripheral.call(target,"list")
    local tanks=peripheral.call(target,"tanks")
    assert(type(items)=="table" and type(tanks)=="table","Table inventory/fluid data unavailable")
    local fluid=0;for _,tank in pairs(tanks) do fluid=fluid+(tank.amount or 0) end
    if fluid>0 then error("Still contains "..fluid.." mB; inspect/drain table",0) end
    local item=items[1]
    if not item and next(items) then error("Unexpected occupied slot; inspect table",0) end
    if item then
     local _,actual,_,shapeMatch=T.outputInfo(role,target,item,nil,{})
     if not shapeMatch then
      entry.actualCast=actual
      error("Wrong output: "..actual.." Cast; expected "..tostring(role).." Cast ("..item.name..")",0)
     end
     entry.status="verified"
     return "Matching "..role.." output; cast verified. Collect output before another pour."
    end
    if entry.role~=role or (entry.status~="installed" and entry.status~="verified") then entry.status="missing" end
    return "Empty and fluid-free; stale lock cleared. Cast slot hidden; installation remains "..entry.status.."."
   end)
   entry.updatedAt=os.epoch("utc")
   if ok then
    count=count+1;cleared[target]=true
    entry.role=role;entry.tableError=false;entry.actualCast=nil;entry.reason=result
    lines[#lines+1]="CLEARED "..T.location(target)..": "..result
   else
    entry.tableError=true;entry.reason=tostring(result)
    lines[#lines+1]="STILL BLOCKED "..T.location(target)..": "..tostring(result)
   end
  end
  saveState(state);T.refreshAvailability(bindings);os.queueEvent("gear_cast_availability")
  return count,lines,cleared
 end
 function T.status(role,target)
  local entry=readState()[target]
  if entry and entry.tableError then return "table_error",entry end
  if entry and entry.role~=role and entry.status~="missing" then return "suspect",entry end
  return entry and entry.role==role and entry.status or "missing",entry
 end
 function T.installed(role,target)
  local status=T.status(role,target)
  return status=="installed" or status=="verified"
 end
 local detailCache={}
 function T.chest()
  local source=C.castChest or "sophisticatedstorage:chest_1"
  local found,unknown={},0
  for slot,item in pairs(peripheral.call(source,"list")) do
   local role=T.match(item,item.name)
   if not role then
    local key=item.nbt and (source.."|"..item.name.."|"..item.nbt)
    local cached=key and detailCache[key]
    local label=cached and cached.label
    if not cached or os.clock()-cached.at>=30 then
     local ok,detail=pcall(peripheral.call,source,"getItemDetail",slot)
     label=ok and type(detail)=="table" and detail.displayName or item.name
     if key and ok then detailCache[key]={label=label,at=os.clock()} end
    end
    role=T.match(item,label)
   end
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
   if entry and entry.tableError then status="table_error" end
   local stock=found[role]
   report.casts[role]={available=ok and stock~=nil,quantity=stock and stock.quantity or 0,
    verificationNeeded=status=="unverified",installed=status=="installed" or status=="verified",status=status,station=target,record=entry,tableError=entry and entry.tableError or false}
  end
  local basin=bindings.Block and bindings.Block.peripheral
  local basinRecord=basin and state[basin]
  report.casts.Block={available=true,quantity=0,installed=false,station=basin,
    tableError=basinRecord and basinRecord.tableError or false,
    status=basinRecord and basinRecord.tableError and "table_error" or "missing",record=basinRecord}
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
  if status=="table_error" then error("TableError: wrong cast at "..T.location(target).."; replace cast and Clear Errors",0) end
  if status=="pending" or status=="suspect" then error("Inspect cast at "..T.location(target).."; mark removed or installed in Station Setup",0) end
  local source=C.castChest or "sophisticatedstorage:chest_1"
  if source==target then error("Cast source equals destination",0) end
  local station=bindings[role]
  if not station or station.peripheral~=target or station.enabled==false then error("Invalid cast assignment",0) end
  for other,binding in pairs(bindings) do if other~=role and binding.peripheral==target then error("Shared cast station: "..T.location(target),0) end end
  if next(peripheral.call(target,"list")) then error("Output occupied at "..T.location(target),0) end
  for _,tank in pairs(peripheral.call(target,"tanks")) do if (tank.amount or 0)>0 then error("Fluid present at "..T.location(target),0) end end
  -- Recovery uncertainty is not a detected wrong cast. Use the user's next
  -- requested cast to verify the existing station, without inserting a duplicate.
  if status=="unverified" then return end
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
 function T.outputInfo(role,target,item,material,outputs)
  if not item then return false,"Unknown","",false end
  local function contains(value,needle)
   local hay=" "..words(value):gsub("%s+"," ").." "
   local term=words(needle):gsub("%s+"," ")
   return hay:find(" "..term.." ",1,true)~=nil
  end
  local ok,detail=pcall(peripheral.call,target,"getItemDetail",1)
  local label=ok and type(detail)=="table" and detail.displayName or ""
  local detected={};for _,candidate in ipairs(roles) do detected[#detected+1]=candidate end
  detected[#detected+1]="Block"
  table.sort(detected,function(a,b) return #a>#b end)
  local actual=item.name=="silentgear:rod" and "Tool Rod" or nil
  if not actual then
   for _,candidate in ipairs(detected) do
    if contains(item.name,candidate) or contains(label,candidate) then actual=candidate;break end
   end
  end
  if not actual then
   for _,gem in ipairs({"Diamond","Emerald","Amethyst","Lapis","Quartz","Fluxite","Ender"}) do
    if contains(item.name,gem) or contains(label,gem) then actual="Gem";break end
   end
  end
  local shapeMatch=actual==role or contains(item.name,role) or contains(label,role)
  if actual and actual~=role then shapeMatch=false end
  local match=shapeMatch
  -- Gems use their material name (Diamond), rather than the word Gem.
  if role=="Gem" and (not actual or actual=="Gem") then shapeMatch=true;actual="Gem";match=material and (contains(item.name,material) or contains(label,material)) end
  local idsOK=not outputs or #outputs==0
  for _,id in ipairs(outputs or {}) do if item.name==id then idsOK=true end end
  return match and idsOK,actual or (shapeMatch and role or (label~="" and label or item.name)),label,shapeMatch
 end
 function T.checkOutput(role,target,item,material,outputs)
  if not item then return false end
  local match,actual,label=T.outputInfo(role,target,item,material,outputs)
  if not match then
   if role~="Block" then T.record(role,target,"suspect","Wrong output: "..item.name.." / "..label) end
   error("Wrong output at "..T.location(target)..": expected "..role..", found "..item.name.." ("..label.."). Check installed cast.",0)
  end
  if role~="Block" then
   local status,record=T.status(role,target)
   local reason="Expected output: "..item.name
   if status~="verified" or record.reason~=reason then T.record(role,target,"verified",reason) end
  end
  return true
 end
 return T
end
