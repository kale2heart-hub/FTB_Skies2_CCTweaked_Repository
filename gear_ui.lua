-- @crafting-center {"version":"1.1.0","suite":"crafting-center","id":"gear","title":"Gear UI","args":[],"description":"Monitor UI and production queue.","locks":["casting-state"],"dependencies":["fluid_network.lua","fluid_client.lua","gear_stats_data.lua","gear_preview.lua","gear_kit_data.lua","gear_request.lua","gear_chest_data.lua","chest_catalog.lua","chest_delivery.lua","gear_casting_data.lua","casting_recovery.lua","cast_tracking.lua","gear_config.lua","gear_demo.lua"],"category":"Applications"}
-- Silent Gear request console, CC:Tweaked. Run: gear_ui
-- Live casting and chest-delivery queues, including Gear part kits for manual assembly.
local VERSION="1.1.0"
local ROOT = fs.getDir(shell.getRunningProgram())
local C = dofile(fs.combine(ROOT, "gear_config.lua"))
local Network=dofile(fs.combine(ROOT,"fluid_network.lua"))
local networkSettings=Network.load(ROOT)
local networkClient
local function networkCall(name,method,...) return peripheral.call(name,method,...) end
if networkSettings.role=="gear" then
  networkClient=dofile(fs.combine(ROOT,"fluid_client.lua"))(Network,networkSettings)
  networkCall=networkClient.call
  C.fluidStores={Network.source}
  C.monitorAutoDiscover=false
  C.monitors={inDisplay=networkSettings.monitors[1] or "",outDisplay=networkSettings.monitors[2] or "",devDisplay=networkSettings.monitors[3] or ""}
elseif networkSettings.role=="fluid" then
  error("This computer is assigned to Liquid Resource Monitor; launch that application instead",0)
end
local Cast=dofile(fs.combine(ROOT,"cast_tracking.lua"))(ROOT,C)
local recoverCasting=dofile(fs.combine(ROOT,"casting_recovery.lua"))
local gearCastingData=dofile(fs.combine(ROOT,"gear_casting_data.lua"))
local chestPartData=dofile(fs.combine(ROOT,"gear_chest_data.lua"))
local makeChestCatalog=dofile(fs.combine(ROOT,"chest_catalog.lua"))
local deliverChest=dofile(fs.combine(ROOT,"chest_delivery.lua"))
local gearKitData=dofile(fs.combine(ROOT,"gear_kit_data.lua"))
local previewGear=dofile(fs.combine(ROOT,"gear_preview.lua"))(dofile(fs.combine(ROOT,"gear_stats_data.lua")))
local planGearRequest=dofile(fs.combine(ROOT,"gear_request.lua"))
for role,profile in pairs(gearKitData.profiles) do gearCastingData.parts[role]=profile;Cast.registerOutputs(role,profile.outputs) end
local chestCatalog
local categories = {"Weapon", "Armor", "Tool", "Accessory", "Extra"}
local catalog = {
  -- Blades, blunt weapons, polearms, then ranged weapons.
  Weapon={"Knife","Dagger","Machete","Sword","Katana","Mace","Spear","Trident","Slingshot","Bow","Crossbow"},
  Armor={"Helmet","Chestplate","Leggings","Boots"},
  Tool={"Fishing Rod","Shears","Sickle","Mattock","Hoe","Prospector Hammer","Saw","Excavator","Hammer","Paxel","Axe","Shovel","Pickaxe"},
  Accessory={"Necklace","Bracelet","Ring"},
  Extra={"Shield","Arrow","Elytra"},
  ["Other Tool Parts"]={"Fletching","Cord","Lining","Binding","Grip","Coating","Tip","Tool Rod"},
  Other={"Ingot","Nugget","Gem","Gear","Rod","Plate","Block"},
}
local displays, stock, errors = {}, {}, {}
local S = {screen="welcome", page=1, selected={}, message="",quantity=1}
local W,H = 0,0
S.lastInteraction=os.clock()
S.welcomeAt=S.lastInteraction
local function advanceStatPage()
  if S.screen~="review" or S.reviewTab~="stats" or S.category=="Other" or (S.statsPages or 1)<=1 then return false end
  S.statsPage=(S.statsPage or 1)%(S.statsPages or 1)+1
  return true
end
local castStations={}
for _,shape in ipairs({"Ingot","Nugget","Gem","Gear","Rod","Plate","Block"}) do
  castStations[shape]={peripheral=shape=="Ingot" and C.castingTable or shape=="Block" and C.castingBasin or ""}
end
for shape,station in pairs(C.castStations or {}) do castStations[shape]=station end
local bindingPath=fs.combine(ROOT,"gear_stations.txt")
if fs.exists(bindingPath) then
  local f=assert(fs.open(bindingPath,"r")); local saved=textutils.unserialize(f.readAll()); f.close()
  assert(type(saved)=="table","Unreadable gear_stations.txt")
  for shape,station in pairs(saved) do castStations[shape]=station end
end
if networkClient then networkClient.checkAssignments(castStations) end
local function liveCastingEnabled()
  return C.liveCasting==true or (C.liveCasting==nil and C.liveIronCasting==true)
end
local function liveToolPart(item,category)
  return liveCastingEnabled() and C.liveToolPartCasting~=false and (category or S.category)=="Other Tool Parts"
    and gearCastingData.parts[item or S.item]~=nil
end
local function liveCastRoute()
  return liveCastingEnabled() and (S.category=="Other" or liveToolPart()) and castStations[S.item] and castStations[S.item].enabled~=false
end
local function liveGearRoute(item,category)
  category=category or S.category
  return C.liveGearKits~=false and liveCastingEnabled() and (category=="Weapon" or category=="Armor" or category=="Tool" or category=="Accessory" or category=="Extra")
end
local function liveChestRoute(item,category)
  return not liveToolPart(item,category) and C.liveChestParts~=false and (category or S.category)=="Other Tool Parts" and chestPartData.parts[item or S.item]~=nil
end
local function liveRequest() return liveCastRoute() or liveChestRoute() or liveGearRoute() end
local function castSelection()
  return S.selected[S.category=="Other" and "Material" or S.item]
end
local castingAmount
local ingotMaterials=C.liveIngotMaterials or {
  ["productivemetalworks:molten_iron"]={label="Iron",amount=90,outputs={"minecraft:iron_ingot","ftbmaterials:iron_ingot"}},
}
for fluid,mapping in pairs(ingotMaterials) do
  assert(type(fluid)=="string" and type(mapping)=="table","Invalid ingot material mapping")
  assert(type(mapping.label)=="string" and type(mapping.amount or 90)=="number" and (mapping.amount or 90)>0,"Invalid ingot label/amount")
  assert(mapping.outputs==nil or type(mapping.outputs)=="table","outputs must be a list when supplied")
  for _,id in ipairs(mapping.outputs or {}) do assert(type(id)=="string" and id~="","Invalid ingot output ID") end
end
local nonIngotMaterials={amethyst=true,diamond=true,emerald=true,lapis=true,lapiz=true,
  quartz=true,slime=true,fluxite=true,redstone=true,obsidian=true,glass=true,glowstone=true,blaze=true}
local function fluidLabel(name)
  local label=name:gsub("^.*:",""):gsub("^molten[_/]",""):gsub("_"," ")
  return label:gsub("(%a)([%w]*)",function(a,b) return a:upper()..b end)
end
local function ingotMapping(fluid,label)
  local configured=ingotMaterials[fluid]
  if configured then return configured.enabled~=false and configured or nil end
  if C.autoDiscoverMolten==false then return nil end
  label=label or fluidLabel(fluid)
  if nonIngotMaterials[label:lower()] then return nil end
  return {label=label,amount=90,outputs={},automatic=true}
end
local function liveFluidMenu()
  return (S.category=="Other" and C.autoDiscoverMolten~=false) or liveToolPart() or liveGearRoute()
end
local gemMaterials={amethyst=true,diamond=true,emerald=true,lapis=true,lapiz=true,quartz=true,fluxite=true,ender=true}
local function castMapping(shape,fluid,label)
  local override=((C.castMaterialOverrides or {})[shape] or {})[fluid]
  if override then return override.enabled~=false and override or nil end
  local partProfile=gearCastingData.parts[shape]
  if partProfile then
    local material=partProfile.materials[fluid]
    if not material then return nil end
    return {label=material.label,amount=material.amount,outputs=partProfile.outputs}
  end
  if shape=="Ingot" then return ingotMapping(fluid,label) end
  local metal=ingotMapping(fluid,label)
  local name=label:lower()
  if shape=="Gem" and not gemMaterials[name] then return nil end
  if (shape=="Nugget" or shape=="Plate") and not metal then return nil end
  if shape=="Gear" and not metal and name~="diamond" then return nil end
  if shape=="Rod" and not metal and name~="blaze" then return nil end
  return {label=label,amount=castingAmount(shape,label),outputs={}}
end
local function acceptedOutput(name,outputs)
  if type(name)~="string" or name=="" then return false end
  -- With no explicit IDs, trust only a newly produced output from the
  -- exclusively controlled, initially empty station and record its real ID.
  if not outputs or #outputs==0 then return true end
  for _,id in ipairs(outputs or {}) do if name==id then return true end end
  return false
end
local startLiveCast,startChestDelivery,startGearRequest,drawJob,drawWelcome
local JOB_STATE=fs.combine(ROOT,"casting_test_state.txt")
local function previousJob()
  if not fs.exists(JOB_STATE) then return nil end
  local f=assert(fs.open(JOB_STATE,"r")); local j=textutils.unserialize(f.readAll()); f.close()
  if type(j)~="table" then return {status="unreadable"} end
  if j.status=="cancelled" or j.status=="not_started" then return nil end
  return j
end
local QUEUE_FILE=fs.combine(ROOT,"gear_queue.txt")
local Q={batches={},paused=false,active=false,nextId=1}
if fs.exists(QUEUE_FILE) then
  local f=assert(fs.open(QUEUE_FILE,"r")); local saved=textutils.unserialize(f.readAll()); f.close()
  if type(saved)~="table" or type(saved.batches)~="table" then error("Unreadable gear_queue.txt; inspect before casting",0) end
  Q=saved
  if #Q.batches>0 or Q.active then Q.paused=true; Q.reason="Restarted - inspect, then Resume" end
end
for _,batch in ipairs(Q.batches) do
  batch.completed=batch.completed or math.max(0,(batch.quantity or batch.remaining)-batch.remaining)
  if batch.kind~="chest" then
  batch.fluid=batch.fluid or "productivemetalworks:molten_iron"
  batch.amount=batch.amount or 90
  batch.outputs=batch.outputs or {"minecraft:iron_ingot","ftbmaterials:iron_ingot"}
  batch.material=batch.material or "Iron"
  batch.shape=batch.shape or "Ingot"
  batch.station=batch.station or C.castingTable or "productivemetalworks:casting_1"
  batch.coolSeconds=batch.coolSeconds or 3
  batch.deliverySeconds=batch.deliverySeconds or 120
  end
end
local function reservedFluid(fluid)
  local total=0
  for i,batch in ipairs(Q.batches) do
    local units=batch.remaining
    if i==1 and Q.active and not Q.pendingFluid then units=math.max(0,units-1) end
    if batch.fluid==fluid then total=total+units*batch.amount end
  end
  return total
end
local function reservedChest(name,nbt,label)
  local total=0
  for _,batch in ipairs(Q.batches) do
    if batch.kind=="chest" then for _,component in ipairs(batch.components or {}) do
      if component.name==name and component.nbt==nbt and (not label or component.displayName==label) then total=total+batch.remaining*component.amount end
    end end
  end
  return total
end
local function publishFluidDemand()
  if not networkClient then return end
  local demand={}
  for _,batch in ipairs(Q.batches) do if batch.fluid then demand[batch.fluid]=reservedFluid(batch.fluid) end end
  networkClient.reserve(demand)
end
if networkClient then networkClient.beforePour=publishFluidDemand end
local function saveQueue()
  local f=assert(fs.open(QUEUE_FILE,"w")); f.write(textutils.serialize(Q)); f.close()
  if networkClient then
    local ok,err=pcall(publishFluidDemand)
    S.networkError=not ok and tostring(err) or nil
  end
end
local function waitingItems()
  local n=0
  for _,batch in ipairs(Q.batches) do n=n+batch.remaining end
  return math.max(0,n-((S.busy or (Q.active and not Q.paused)) and 1 or 0))
end
local function protectedUnit(index)
  return index==1 and (S.busy or (Q.active and not Q.paused)) and 1 or 0
end
local function advanceQueue()
  local batch=Q.batches[1]
  if batch then
    batch.completed=(batch.completed or 0)+1
    batch.remaining=batch.remaining-1
    if batch.remaining<=0 then table.remove(Q.batches,1) end
  end
  Q.active=false; Q.token=nil; Q.pendingFluid=false
  saveQueue()
end
local function part(name, required, source)
  return {name=name, required=required, source=source or "chest"}
end
local function recipe(item,category)
  item=item or S.item; category=category or S.category
  if liveGearRoute(item,category) then
    local profile=gearKitData.profiles[item]
    return {verified=profile~=nil,parts=profile and profile.parts or {}}
  end
  if liveChestRoute(item,category) then return {verified=true,parts={part(item,true,"chest")}} end
  if liveToolPart(item,category) then return {verified=true,parts={part(item,true,"fluid")}} end
  local configured = C.recipes[item]
  if configured then return configured end
  -- Draft UI layouts only. No claim that these are valid pack recipes.
  if category == "Other" then
    return {verified=true,parts={part("Material",true,"fluid")}}
  elseif category == "Other Tool Parts" then
    return {parts={part(item,true,item=="Tool Rod" and "fluid" or "chest")}}
  elseif category == "Armor" then
    return {parts={part("Main",true,"fluid"),part("Lining",true)}}
  elseif category == "Accessory" then
    return {parts={part("Main",true,"fluid"),part("Jewelry Setting",false)}}
  else
    local p={part("Main",true,"fluid"),part("Tool Rod",true,"fluid")}
    if item=="Bow" or item=="Crossbow" or item=="Slingshot" then
      p[#p+1]=part("Cord",true)
    end
    for _,n in ipairs({"Tip","Coating","Binding","Grip"}) do p[#p+1]=part(n,false) end
    return {parts=p}
  end
end
-- Live chest refresh; Cast Checker is optional for Gear UI operation.
local castReport,castReportError=nil,nil
local function readCastReport(force)
 if not force then return end -- Drawing must never perform inventory or file I/O.
 local ok,result=pcall(Cast.refreshAvailability,castStations)
 if ok and type(result)=="table" and result.valid then
  castReport=result;castReportError=nil
 else
  castReport=nil
  castReportError=ok and type(result)=="table" and result.error or tostring(result)
 end
end
local function castStockWorker()
 while true do
  if networkClient then
    local ok,err=pcall(publishFluidDemand);S.networkError=not ok and tostring(err) or nil
  end
  readCastReport(true)
  if chestCatalog then chestCatalog.scan() end
  os.queueEvent("gear_cast_stock_ready")
  local timer=os.startTimer(math.max(1,C.pollSeconds or 3))
  while true do
   local event,id=os.pullEvent()
   if (event=="timer" and id==timer) or event=="gear_cast_stock_refresh" then break end
  end
 end
end
local function castProblem(item,category,selected)
 if liveGearRoute(item,category) and not gearKitData.profiles[item] then return gearKitData.unsupported[item] or "No verified casting route for this item",colors.red end
 local needed={}
 if category=="Other" then
  if item=="Block" then
   local basin=castReport and castReport.casts.Block
   if basin and basin.tableError then return "TableError at "..Cast.location(basin.station).."; inspect basin then Clear Errors",colors.red end
   return nil -- Basin blocks do not require a cast, but still respect TableError.
  end
  needed[item]=true
 else
  for _,p in ipairs(recipe(item,category).parts) do
   local chosen=selected and selected[p.name]
   if (p.required and p.source=="fluid") or (chosen and chosen.source=="fluid") then
    needed[p.name=="Main" and item or p.name]=true
   end
  end
 end
 if not next(needed) then return nil end
 readCastReport()
 local missing={}
 for role in pairs(needed) do
  local station=castStations[role]
  local target=station and station.peripheral
  local entry=castReport and castReport.casts[role]
  if not entry then return castReportError or "Checking cast stock...",colors.orange end
  local status=entry.status
  if status=="table_error" or entry.tableError then return "TableError: wrong cast at "..Cast.location(target).."; replace cast then Clear Errors",colors.red end
  if status=="pending" or status=="suspect" then return "Inspect cast: "..Cast.location(target),colors.orange end
  local installed=status=="installed" or status=="verified" or status=="unverified"
  if not installed and (not entry or entry.available~=true) then
   if not castReport then return castReportError,colors.orange end
   missing[#missing+1]=role
  end
 end
 table.sort(missing)
 if #missing>0 then return "Missing casts: "..table.concat(missing,", "),colors.red end
end
castingAmount=function(item,material)
  local name=material:lower():gsub("^.*:",""):gsub("^molten_",""):gsub("_"," ")
  if item=="Ingot" or item=="Plate" then return 90 end
  if item=="Nugget" then return 10 end
  if item=="Gem" then return 100 end
  if item=="Gear" then return name=="diamond" and 400 or 360 end
  if item=="Rod" then return name=="blaze" and 400 or 45 end
  if item=="Block" then
    if name=="amethyst" or name=="glowstone" then return 400 end
    local bucket={fluxite=true,glass=true,obsidian=true}
    if bucket[name] then return 1000 end
    local gemBlock={diamond=true,slime=true,emerald=true,lapis=true,lapiz=true,
      redstone=true,quartz=true}
    if gemBlock[name] then return 900 end
    return 810
  end
end
local fluidStock,castingRules={},{}
local demoStock
if C.demoMode then
  demoStock=dofile(fs.combine(ROOT,"gear_demo.lua"))(C,catalog,function(category,item)
    S.category,S.item=category,item
    return recipe()
  end,castingAmount)
  S.category,S.item=nil,nil
end
local function key(source,name,nbt)
  return textutils.serialize({source,name,nbt or ""},{compact=true})
end
chestCatalog=makeChestCatalog(C,chestPartData,key)
local function ruleAvailable(r)
  return r.stockId and chestCatalog.count(r.stockId) or (stock[key(r.source,r.name,r.nbt)] or 0)
end
local function readPeripheral(name, method)
  if not name or name=="" then return nil end
  local ok,result=pcall(networkCall,name,method)
  if not ok then errors[#errors+1]=name..": "..tostring(result); return nil end
  return result
end
local function refreshStock()
  stock,errors,fluidStock={},{},{}
  if C.demoMode and not liveRequest() and not liveFluidMenu() then
    for _,v in pairs(demoStock) do
      stock[key(v.source,v.name)]=v.amount
      if v.source=="fluid" then fluidStock[v.name]={label=v.label,name=v.name,amount=v.amount} end
    end
    return
  end
  if liveChestRoute() then
    for k,value in pairs(chestCatalog.stock) do stock[k]=value end
    if chestCatalog.error then errors[#errors+1]=chestCatalog.error end
    return
  end
  local seen={}
  for _,name in ipairs(C.fluidStores) do
    if not seen[name] then
      seen[name]=true
      for _,tank in pairs(readPeripheral(name,"tanks") or {}) do
        if tank.name and tank.amount and tank.amount>0 then
          local k=key("fluid",tank.name)
          stock[k]=(stock[k] or 0)+tank.amount
          if tank.name:find("molten",1,true) then
            local label=fluidLabel(tank.name)
            fluidStock[tank.name]={label=label,name=tank.name,amount=stock[k]}
          end
        end
      end
    end
  end
  if liveGearRoute() then
    for k,value in pairs(chestCatalog.stock) do stock[k]=value end
    if chestCatalog.error then
      for _,p in ipairs(recipe().parts) do if p.source=="chest" and (p.required or S.selected[p.name]) then errors[#errors+1]=chestCatalog.error;break end end
    end
    return
  end
  for _,item in pairs((S.category~="Other" and not liveToolPart() and readPeripheral(C.partsChest,"list")) or {}) do
    local k=key("chest",item.name,item.nbt)
    stock[k]=(stock[k] or 0)+item.count
  end
end
local function availableText(r)
  if not r or r.none then return "" end
  local amount=ruleAvailable(r)
  if r.source=="fluid" then
    if amount>=1000 then
      return string.format("%.2f",amount/1000):gsub("0+$",""):gsub("%.$","").." B"
    end
    return tostring(amount).." mB"
  end
  return tostring(amount).." items"
end
local function materialLabel(r,width)
  if not r then return "--" end
  if r.none then return "None" end
  local amount=" ("..availableText(r)..")"
  local name=r.label or r.name
  if width and #name+#amount>width then name=name:sub(1,math.max(0,width-#amount-1)).."~" end
  return name..amount
end
local function validRule(r,p)
  return r.item==S.item and r.part==p.name and r.source==p.source
    and type(r.id)=="string" and type(r.name)=="string"
    and type(r.amount)=="number" and r.amount>0
end
local kitChestRules={}
local function options(p)
  local result={}
  local rules=liveChestRoute() and (chestCatalog.rules[S.item] or {}) or C.rules
  if liveGearRoute() and p.source=="chest" then
    rules={}
    for _,base in ipairs(chestCatalog.rules[p.name] or {}) do
      local id=S.item.."|"..p.name.."|"..base.id
      local r=kitChestRules[id]
      if not r then
        r={};for k,v in pairs(base) do r[k]=v end
        r.id="kit:"..id;r.item=S.item;r.part=p.name;kitChestRules[id]=r
      end
      rules[#rules+1]=r
    end
  end
  if S.category=="Other" or liveToolPart() or (liveGearRoute() and p.source=="fluid") then
    rules={}
    for name,fluid in pairs(fluidStock) do
      local shape=liveGearRoute() and (p.shape or p.name) or S.item
      local mapping=(liveCastRoute() or liveToolPart() or liveGearRoute()) and castMapping(shape,name,fluid.label) or nil
      local amount=mapping and (mapping.amount or 90) or (not liveGearRoute() and castingAmount(S.item,fluid.label) or nil)
      if amount then
        local id=S.item.."|"..(liveGearRoute() and p.name.."|" or "")..name
        local r=castingRules[id]
        if not r then
          r={id="casting:"..id,item=S.item,part=liveGearRoute() and p.name or S.category=="Other" and "Material" or S.item,label=mapping and mapping.label or fluid.label,
            source="fluid",name=name,amount=amount}
          castingRules[id]=r
        end
        rules[#rules+1]=r
      end
    end
  end
  for _,r in ipairs(rules) do
    if validRule(r,p) and ruleAvailable(r)>0 then
      result[#result+1]=r
    end
  end
  table.sort(result,function(a,b)
    local left,right=(a.label or a.name):lower(),(b.label or b.name):lower()
    if left==right then return (a.name or a.id)<(b.name or b.id) end
    return left<right
  end)
  table.insert(result,1,{none=true,label="None",source=p.source})
  return result
end
local function gearPlanContext(preview)
 return {preview=preview,key=key,stock=stock,stations=castStations,mapping=castMapping,
  reservedFluid=reservedFluid,reservedChest=reservedChest,available=ruleAvailable,
  partsChest=C.partsChest,outputChest=C.outputChest,chestEnabled=C.liveChestParts~=false}
end
local function validate()
  local issue=castProblem(S.item,S.category,S.selected)
  if issue then return false,issue end
  if liveGearRoute() then
    for _,p in ipairs(recipe().parts) do
      local r=S.selected[p.name]
      if p.required and not r then return false,"Select required: "..p.name end
      if r then
        local valid=false
        for _,candidate in ipairs(options(p)) do if candidate==r and validRule(r,p) then valid=true;break end end
        if not valid then return false,"Material no longer available: "..p.name end
      end
    end
    if #errors>0 then return false,"Storage read failed; check source connections" end
    local ok,result=pcall(planGearRequest,S.item,recipe(),S.selected,S.quantity,gearPlanContext(true))
    if not ok then return false,tostring(result) end
    return true,"LIVE: "..S.quantity.." "..S.item.." kits for manual assembly"
  end
  local demands={}
  for _,p in ipairs(recipe().parts) do
    local r=S.selected[p.name]
    if p.required and not r then return false,"Select required: "..p.name end
    if r then
      local found=false
      for _,candidate in ipairs(options(p)) do
        if candidate==r and validRule(r,p) then found=true; break end
      end
      if not found then return false,"Material no longer available: "..p.name end
      local k=key(r.source,r.name,r.nbt)
      demands[k]=(demands[k] or 0)+r.amount*(liveRequest() and S.quantity or 1)
      if demands[k]>ruleAvailable(r) then return false,"Insufficient stock: "..(r.label or r.name) end
      if liveChestRoute() then
        local required=r.amount*S.quantity
        if required+reservedChest(r.name,r.nbt,r.displayName)>ruleAvailable(r) then return false,"Not enough parts for queue + selection" end
        for _,extra in ipairs(r.extras or {}) do
          if extra.amount*S.quantity+reservedChest(extra.name,extra.nbt)>(stock[key("chest",extra.name,extra.nbt)] or 0) then
            return false,"Need "..(extra.amount*S.quantity).." x "..extra.name.." for the material bundle"
          end
        end
      end
    end
  end
  if liveCastRoute() then
    local previous=previousJob()
    if not Q.active and previous and previous.status~="done" then return false,"Previous cast needs inspection" end
    local r=castSelection()
    if not castMapping(S.item,r.name,r.label) then return false,r.label..": use its matching cast type" end
    local station=castStations[S.item]
    if not station or not station.peripheral or station.peripheral=="" then return false,"Assign a dedicated "..S.item.." station first" end
    for shape,other in pairs(castStations) do
      if shape~=S.item and other.peripheral==station.peripheral then return false,"Station also assigned to "..shape end
    end
    local available=stock[key("fluid",r.name)] or 0
    if reservedFluid(r.name)+S.quantity*r.amount>available then return false,"Not enough "..r.label.." for queue + selection" end
  end
  if not recipe().verified then return false,"Recipe needs pack verification" end
  if #errors>0 then return false,"Storage read failed; check computer" end
  if liveChestRoute() then
    if not C.partsChest or not C.outputChest or C.partsChest==C.outputChest then return false,"Configure separate parts and output chests" end
    local r=castSelection()
    local extra=r and r.extras and r.extras[1]
    return true,"LIVE: queue "..S.quantity.." bundles"..(extra and (" + "..(extra.amount*S.quantity).." glass bottle(s)") or "")
  end
  return true,liveCastRoute() and ("LIVE: queue "..S.quantity.." "..S.item.." / "..(S.quantity*castSelection().amount).." mB") or C.demoMode and "Demo ready - save test request" or "Ready to save request (no production yet)"
end
-- Monitor commands may yield across wired modems. Compose locally, then send
-- only final changed rows, rather than every cursor/style/intermediate write.
local function bufferedMonitor(real,w,h,scale)
 local m={};local x,y=1,1;local fg,bg="0","f"
 local rows,sent,palettes,sentPalettes={},{},{},{}
 local colour=real.isColor()
 local function blank()
  rows={}
  for row=1,h do rows[row]={string.rep(" ",w),string.rep(fg,w),string.rep(bg,w)} end
 end
 blank()
 function m.getSize() return w,h end
 function m.isColor() return colour end
 function m.setCursorPos(a,b) x,y=a,b end
 function m.setTextColor(value) fg=colors.toBlit(value) end
 function m.setBackgroundColor(value) bg=colors.toBlit(value) end
 function m.setTextScale(value)
  if value==scale then return end
  real.setTextScale(value);scale=value;w,h=real.getSize();sent={};blank()
 end
 function m.setPaletteColor(slot,a,b,c)
  local signature=tostring(a)..":"..tostring(b)..":"..tostring(c)
  palettes[slot]={a,b,c,signature}
 end
 function m.clear() blank() end
 function m.blit(text,front,back)
  local length=#text
  if y>=1 and y<=h and length>0 then
   local first=math.max(1,2-x);local last=math.min(length,w-x+1)
   if first<=last then
    local start=x+first-1;local finish=x+last-1
    local row=rows[y]
    local function replace(old,value) return old:sub(1,start-1)..value:sub(first,last)..old:sub(finish+1) end
    rows[y]={replace(row[1],text),replace(row[2],front),replace(row[3],back)}
   end
  end
  x=x+length
 end
 function m.write(text)
  text=tostring(text);m.blit(text,string.rep(fg,#text),string.rep(bg,#text))
 end
 function m.flush()
  for slot,value in pairs(palettes) do
   if sentPalettes[slot]~=value[4] then
    if value[2]==nil then real.setPaletteColor(slot,value[1])
    else real.setPaletteColor(slot,value[1],value[2],value[3]) end
    sentPalettes[slot]=value[4]
   end
  end
  for row=1,h do
   local current,previous=rows[row],sent[row]
   if not previous or current[1]~=previous[1] or current[2]~=previous[2] or current[3]~=previous[3] then
    real.setCursorPos(1,row);real.blit(current[1],current[2],current[3])
    sent[row]={current[1],current[2],current[3]}
   end
  end
 end
 return m
end
local function flushDisplays()
 local tasks={}
 for _,d in ipairs(displays) do
  local m=d.mon
  if m.flush then tasks[#tasks+1]=function() m.flush() end end
 end
 if #tasks==1 then tasks[1]()
 elseif #tasks>1 then parallel.waitForAll(table.unpack(tasks)) end
end
local function connect()
  displays={}; W,H=math.huge,math.huge
  local names={}
  -- In demo mode, unassigned monitors use a sorted discovery list.
  local auto={}
  if C.demoMode and C.monitorAutoDiscover~=false then
    for _,name in ipairs(peripheral.getNames()) do
      if peripheral.hasType(name,"monitor") then auto[#auto+1]=name end
    end
    table.sort(auto)
    for _,name in pairs(C.monitors) do
      if name~="" then names[name]=true end
    end
  end
  local reserved=names
  names={}
  for _,alias in ipairs({"inDisplay","outDisplay","devDisplay"}) do
    local name=C.monitors[alias]
    if C.demoMode and C.monitorAutoDiscover~=false and (not name or name=="") then
      for _,candidate in ipairs(auto) do
        if not names[candidate] and not reserved[candidate] then name=candidate; break end
      end
    end
    if name and name~="" and not names[name] and peripheral.hasType(name,"monitor") then
      names[name]=true
      local m=peripheral.wrap(name)
      m.setTextScale(C.textScale)
      local w,h=m.getSize()
      displays[#displays+1]={name=name,mon=bufferedMonitor(m,w,h,C.textScale),w=w,h=h,buttons={}}
      W,H=math.min(W,w),math.min(H,math.max(0,h-(C.bottomMargin or 9)))
    end
  end
  if #displays==0 then error("No configured monitors connected. Run scan.lua and edit gear_config.lua.",0) end
end
local function go(screen)
  if screen=="welcome" then S.welcomeAt=os.clock() end
  if screen=="item" and S.section and S.section~="gear" then screen="sectionItems" end
  S.screen,S.page,S.message=screen,1,""
  if screen=="part" then
    S.part=recipe().parts[1]; S.materialPage=1; S.partPage=1
    refreshStock()
  end
end
local function entries()
  local rows={}
  local function add(label,action) rows[#rows+1]={label=label,action=action} end
  if S.screen=="category" then
    for _,v in ipairs(categories) do local value=v; add(value,function() S.category=value; go("item") end) end
  elseif S.screen=="item" then
    for _,v in ipairs(catalog[S.category]) do
      local value=v
      add(value,function() S.item=value; S.selected={}; go("part") end)
    end
  elseif S.screen=="part" or S.screen=="review" then
    for _,v in ipairs(recipe().parts) do
      local p=v; local r=S.selected[p.name]
      add((p.required and "* " or "  ")..p.name..": "..(r and (r.label or r.name) or "--"),function()
        S.part=p; go("material")
      end)
    end
  elseif S.screen=="material" then
    for _,v in ipairs(options(S.part)) do
      local r=v
      local amount=not r.none and stock[key(r.source,r.name,r.nbt)] or 0
      if r.none then
        add("None",function() S.selected[S.part.name]=nil end)
      else
        add((r.label or r.name).."  "..amount.."/"..r.amount..(r.source=="fluid" and " mB" or " items"),function()
          S.selected[S.part.name]=r
        end)
      end
    end
    if #rows==1 then add("No compatible stocked materials",nil) end
  end
  return rows
end
local function saveRequest()
  refreshStock()
  local ok,reason=validate()
  if not ok then S.message=reason; return end
  if liveGearRoute() then startGearRequest();return end
  if liveChestRoute() then startChestDelivery(); return end
  if liveCastRoute() then startLiveCast(); return end
  local request={status=C.demoMode and "demo_only" or "awaiting_production_adapter", demo=C.demoMode==true,item=S.item,category=S.category,parts={}}
  for _,p in ipairs(recipe().parts) do
    local r=S.selected[p.name]
    if r then request.parts[#request.parts+1]={part=p.name,rule=r.id,source=r.source,
      name=r.name,nbt=r.nbt,amount=r.amount,label=r.label} end
  end
  local dir=fs.combine(ROOT,C.demoMode and "demo_requests" or "requests")
  fs.makeDir(dir)
  local n=1
  while fs.exists(fs.combine(dir,tostring(n)..".txt")) do n=n+1 end
  local file=assert(fs.open(fs.combine(dir,tostring(n)..".txt"),"w"))
  file.write(textutils.serialize(request)); file.close()
  S.selected={}; go("part"); S.message="Request "..n.." saved. Production pending."
end
-- Monitor-local palette: dark slate, teal accents, muted status colors.
local palette = {
  [colors.black]=0x101820, [colors.white]=0xF1F5F9,
  [colors.blue]=0x25394D, [colors.gray]=0x334155,
  [colors.lightGray]=0xAAB8C5, [colors.cyan]=0x176B80,
  [colors.green]=0x25614C, [colors.red]=0x803D49,
  [colors.orange]=0xF2BC70, [colors.lime]=0x91D9AD,
}
-- Dedicated background slots keep headers, text, and disabled buttons steady.
local pulseSlots={missing=colors.pink,selected=colors.purple,neutral=colors.brown,scroll=colors.lightBlue}
local pulseEpoch=os.clock()
local function pulseColor(base,target,strength)
  local function channel(shift)
    local b=math.floor(base/2^shift)%256
    local t=math.floor(target/2^shift)%256
    return (b+(t-b)*strength)/255
  end
  return channel(16),channel(8),channel(0)
end
local function updatePulse()
  if S.screen=="welcome" then if drawWelcome then drawWelcome() end; return end
  local phase=(os.clock()-pulseEpoch)*2*math.pi/3
  local strength=0.03+0.08*(0.5-0.5*math.cos(phase))
  local states={
    {pulseSlots.missing,palette[colors.red],0xF06A78},
    {pulseSlots.selected,palette[colors.green],0x66D6A2},
    {pulseSlots.neutral,palette[colors.cyan],0xFFFFFF},
    {pulseSlots.scroll,palette[colors.gray],0x5CA8FF},
  }
  for _,d in ipairs(displays) do
    if d.mon.isColor() then
      for _,state in ipairs(states) do
        local r,g,b=pulseColor(state[2],state[3],strength)
        d.mon.setPaletteColor(state[1],r,g,b)
      end
    end
  end
end
local function centered(label,width)
  label=label:sub(1,width)
  local left=math.floor((width-#label)/2)
  return string.rep(" ",left)..label..string.rep(" ",width-#label-left)
end
local function render()
  local rows=entries()
  local capacity=math.max(1,math.floor((H-17)/3))
  -- The first page reclaims the hidden Up control's three-row slot.
  -- Later pages reserve that slot for Up, so their capacity is smaller.
  local function listPage(total,page,noUp)
    local first=capacity+1
    local later=noUp and first or capacity
    local pages=1+math.ceil(math.max(0,total-first)/later)
    page=math.max(1,math.min(page or 1,pages))
    return {page=page,pages=pages,count=(page==1 and first or later),
      offset=page==1 and 0 or first+(page-2)*later,
      y=(page==1 or noUp) and 8 or 11}
  end
  local itemList=listPage(#rows,S.page)
  if S.screen=="review" and S.category~="Other" then
    -- Keep both tabs above a separate content area and reserve paging above Qty.
    local count=math.max(1,math.floor((H-19)/3))
    local total=math.max(1,math.ceil(#rows/count))
    local page=math.max(1,math.min(S.page or 1,total))
    itemList={page=page,pages=total,count=count,offset=(page-1)*count,y=10}
  end
  local pages=itemList.pages
  S.page=itemList.page
  for _,d in ipairs(displays) do
    local m=d.mon
    d.buttons={}
    if m.isColor() then
      for slot,rgb in pairs(palette) do m.setPaletteColor(slot,rgb) end
    end
    m.setBackgroundColor(colors.black); m.setTextColor(colors.white); m.clear()
    local ox,oy=math.floor((d.w-W)/2),math.max(0,d.h-(C.bottomMargin or 9)-H)
    local function line(y,label,bg,fg)
      m.setBackgroundColor((y==1 and (Q.paused or S.screen=="castIssue")) and colors.red or bg or colors.black); m.setTextColor(fg or colors.white)
      m.setCursorPos(ox+1,oy+y)
      label=label:sub(1,W)
      m.write(y==1 and centered(label,W) or (label..string.rep(" ",W-#label)))
    end
    local function button(x,y,width,label,action,bg,fg,pulseState)
      if (label=="Previous" or label=="Next") and not action then return end
      label=label:sub(1,width)
      local accent=label=="Review" or label=="Save request"
      local quiet=label=="Previous" or label=="Next" or label=="Reset" or label:sub(1,5)=="Clear" or label=="<< Back"
      local background=bg or (action and (accent and colors.cyan or (quiet and colors.gray or colors.blue)) or colors.gray)
      if action then
        local state=pulseState
        if label=="Previous" or label=="Next" then state="scroll"
        elseif not state and bg==colors.red then state="missing"
        elseif not state and bg==colors.green then state="selected" end
        if state then background=pulseSlots[state] end
      end
      m.setBackgroundColor(background)
      m.setTextColor(fg or colors.white)
      for row=0,1 do
        m.setCursorPos(ox+x,oy+y+row)
        m.write(row==0 and centered(label,width) or string.rep(" ",width))
      end
      if action then d.buttons[#d.buttons+1]={x=ox+x,y=oy+y,w=width,h=2,action=action} end
    end
    if W<30 or H<20 then
      if H>=1 then line(1,"Need 30x20 above bottom margin") end
    elseif S.screen=="part" or S.screen=="material" then
      -- One workspace: part selection stays visible while choosing materials.
      local left=math.floor(W*0.43)
      local rightX=left+3
      local right=W-rightX+1
      local parts=recipe().parts
      local active=S.part or parts[1]
      S.part=active
      local function text(x,y,width,label,bg,fg)
        label=label:sub(1,width)
        m.setBackgroundColor((y==1 and (Q.paused or S.screen=="castIssue")) and colors.red or bg or colors.black); m.setTextColor(fg or colors.white)
        m.setCursorPos(ox+x,oy+y); m.write(centered(label,width))
      end
      line(1,liveCastRoute() and ("LIVE | "..S.item.." Casting") or liveGearRoute() and ("LIVE | "..S.item.." Parts Kit") or liveFluidMenu() and "PREVIEW | Live Molten Materials" or liveChestRoute() and "LIVE | Parts Chest Delivery" or C.demoMode and "DEMO | Sample stock & recipes" or "SILENT GEAR | Parts Builder",colors.blue)
      button(1,3,left,"<< Back",function() S.item=nil; S.selected={}; go("item") end)
      text(rightX,3,right,S.category.." > "..S.item,colors.blue)
      local missing={}
      for _,p in ipairs(parts) do
        if p.required and not S.selected[p.name] then missing[#missing+1]=p.name end
      end
      line(5,#missing>0 and ("Missing: "..table.concat(missing,", ")) or "Required parts selected",colors.black,#missing>0 and colors.orange or colors.lime)
      local partList=listPage(#parts,S.partPage,true)
      local partPages=partList.pages
      S.partPage=partList.page
      for i=1,partList.count do
        local p=parts[partList.offset+i]
        if p then
          local r=S.selected[p.name]
          local bg=r and colors.green or (p.required and colors.red or colors.blue)
          if p==active then bg=colors.cyan end
          local y=partList.y+(i-1)*3
          text(1,y,1,p==active and ">" or (p.required and "*" or " "),bg,colors.white)
          button(3,y,left-2,p.name..": "..(r and (r.label or r.name) or "--"),function()
            S.part=p; S.materialPage=1; S.message=""
          end,bg,colors.white,p==active and "neutral" or (r and "selected" or (p.required and "missing" or nil)))
        end
      end
      text(rightX,6,right,(active.name=="Material" and "Select Material" or active.name.." Material"),colors.blue)
      local choices=options(active)
      local materialList=listPage(#choices,S.materialPage)
      local materialPages=materialList.pages
      S.materialPage=materialList.page
      button(rightX,8,right,"Previous",S.materialPage>1 and function() S.materialPage=S.materialPage-1 end or nil)
      for i=1,materialList.count do
        local r=choices[materialList.offset+i]
        if r then
          local amount=not r.none and stock[key(r.source,r.name,r.nbt)] or 0
          local selected=(r.none and not S.selected[active.name]) or S.selected[active.name]==r
          local y=materialList.y+(i-1)*3
          local bg=selected and colors.green or colors.blue
          button(rightX,y,right,(selected and "> " or "")..materialLabel(r,right-(selected and 2 or 0)),function()
            if r.none then S.selected[active.name]=nil else S.selected[active.name]=r end
            S.message=""
          end,bg)
          if not r.none then
            text(rightX,y+2,right,"Need "..r.amount..(r.source=="fluid" and " mB" or " items"),colors.black,amount>=r.amount and colors.lightGray or colors.orange)
          end
        end
      end
      if #choices==0 then
        text(rightX,materialList.y,right,"No stocked options",colors.black,colors.orange)
      end
      button(rightX,H-5,right,"Next",S.materialPage<materialPages and function() S.materialPage=S.materialPage+1 end or nil)
      if partPages>1 then
        button(1,H-5,left,"Parts "..S.partPage.."/"..partPages.." >",function() S.partPage=S.partPage%partPages+1 end)
      end
      line(H-2,S.message~="" and S.message or "Select a part, then its material")
      local half=math.floor(left/2)
      button(1,H-1,half,"Reset",function() S.selected={}; S.quantity=1; S.message="Selections cleared" end)
      button(half+1,H-1,left-half,"Review",function() go("review") end)

    else
      local left=math.floor(W*0.43)
      local rightX=left+3
      local right=W-rightX+1
      local function text(x,y,width,label,bg,fg)
        label=label:sub(1,width)
        m.setBackgroundColor((y==1 and (Q.paused or S.screen=="castIssue")) and colors.red or bg or colors.black); m.setTextColor(fg or colors.white)
        m.setCursorPos(ox+x,oy+y); m.write(centered(label,width))
      end
      line(1,liveCastRoute() and ("LIVE | "..S.item.." Casting") or liveGearRoute() and ("LIVE | "..S.item.." Parts Kit") or liveFluidMenu() and "PREVIEW | Live Molten Materials" or liveChestRoute() and "LIVE | Parts Chest Delivery" or C.demoMode and "DEMO | Sample stock & recipes" or "SILENT GEAR | Parts Builder",colors.blue)
      button(1,3,left,"<< Back",function()
        if S.screen=="review" then go("part")
        elseif S.screen=="category" then S.category=nil; S.item=nil; go("main")
        else S.category=nil; S.item=nil; go("category") end
      end or nil)
      text(rightX,3,right,S.screen=="category" and "Equipment Builder" or ((S.category or "")..(S.item and " > "..S.item or "")),colors.blue)
      line(5,S.screen=="review" and "Review selections | * required" or "Select a category, then an item")
      text(1,6,left,S.screen=="review" and "Selected parts" or "Categories",colors.blue)
      text(rightX,6,right,S.screen=="review" and "Request summary" or (S.category or "Choose equipment"),colors.blue)
      if S.screen=="review" then
        if S.category~="Other" then
        local statsActive=S.reviewTab=="stats"
        button(1,6,left,(not statsActive and "> " or "").."Selections",function() S.reviewTab="parts" end,not statsActive and colors.cyan or colors.gray)
        button(rightX,6,right,(statsActive and "> " or "").."Stats & Traits",function() S.reviewTab="stats" end,statsActive and colors.cyan or colors.gray)
        text(1,8,left,string.rep("-",left),colors.black,not statsActive and colors.cyan or colors.gray)
        text(rightX,8,right,string.rep("-",right),colors.black,statsActive and colors.cyan or colors.gray)
        end
        if S.reviewTab=="stats" and S.category~="Other" then
          local wrapped={}
          for _,paragraph in ipairs(previewGear(S.item,recipe().parts,S.selected)) do
            if paragraph=="" then wrapped[#wrapped+1]="" end
            local row=""
            for word in paragraph:gmatch("%S+") do
              if #row+#word+1>W and row~="" then wrapped[#wrapped+1]=row;row="" end
              while #word>W do
                if row~="" then wrapped[#wrapped+1]=row;row="" end
                wrapped[#wrapped+1]=word:sub(1,W);word=word:sub(W+1)
              end
              row=row=="" and word or row.." "..word
            end
            if row~="" then wrapped[#wrapped+1]=row end
          end
          local perPage=math.max(1,H-19)
          local total=math.max(1,math.ceil(#wrapped/perPage))
          S.statsPages=total
          S.statsPage=math.max(1,math.min(S.statsPage or 1,total))
          for i=1,perPage do
            local label=wrapped[(S.statsPage-1)*perPage+i]
            if label then text(1,9+i,W,label,colors.black,colors.white) end
          end
          if total>1 then
            button(1,H-8,left,"Previous",S.statsPage>1 and function() S.statsPage=S.statsPage-1 end or nil)
            button(rightX,H-8,right,"Next",S.statsPage<total and function() S.statsPage=S.statsPage+1 end or nil)
            line(9,"Page: "..S.statsPage.." / "..total,colors.black,colors.lightGray)
          end
        else
        for i=1,itemList.count do
          local p=recipe().parts[itemList.offset+i]
          if p then
            local r=S.selected[p.name]
            local y=itemList.y+(i-1)*3
            button(1,y,left,(p.required and "* " or "")..p.name,function() S.part=p; go("material") end,r and colors.green or (p.required and colors.red or colors.blue))
            text(rightX,y,right,materialLabel(r,right),colors.blue)
            if r then text(rightX,y+2,right,"Need "..(r.amount*(liveRequest() and S.quantity or 1))..(r.source=="fluid" and " mB" or " items"),colors.black,colors.lightGray) end
          end
        end
        end
      else
        -- Category menu remains visible while paging through equipment.
        local categoryList=listPage(#categories,S.categoryPage)
        S.categoryPage=categoryList.page
        for i=1,categoryList.count do
          local category=categories[categoryList.offset+i]
          if category then
            button(1,categoryList.y+(i-1)*3,left,category,function() S.category=category; S.item=nil; go("item") end,S.category==category and colors.green or colors.blue)
          end
        end
        if S.screen=="item" then
          for i=1,itemList.count do
            local row=rows[itemList.offset+i]
            if row then button(rightX,itemList.y+(i-1)*3,right,row.label,row.action) end
          end
        end
      end
      if S.screen=="review" then
        if S.reviewTab~="stats" or S.category=="Other" then
        if S.category~="Other" then
          if pages>1 then line(9,"Page: "..S.page.." / "..pages,colors.black,colors.lightGray) end
          button(1,H-8,left,"Previous",S.page>1 and function() S.page=S.page-1 end or nil)
          button(rightX,H-8,right,"Next",S.page<pages and function() S.page=S.page+1 end or nil)
        else
          button(1,8,left,"Previous",S.page>1 and function() S.page=S.page-1 end or nil)
          button(1,H-5,left,"Next",S.page<pages and function() S.page=S.page+1 end or nil)
        end
        end
      else
        local cp=listPage(#categories,S.categoryPage).pages
        button(1,8,left,"Previous",S.categoryPage>1 and function() S.categoryPage=S.categoryPage-1 end or nil)
        button(1,H-5,left,"Next",S.categoryPage<cp and function() S.categoryPage=S.categoryPage+1 end or nil)
        button(rightX,8,right,"Previous",S.screen=="item" and S.page>1 and function() S.page=S.page-1 end or nil)
        button(rightX,H-5,right,"Next",S.screen=="item" and S.page<pages and function() S.page=S.page+1 end or nil)
      end
      local status=S.message
      if S.screen=="review" then local _,reason=validate(); if status=="" then status=reason end end
      line(H-2,status~="" and status or "Select an option above")
      button(1,H-1,left,"Reset",function() S.selected={}; S.quantity=1; S.message="Selections cleared" end)
      if S.screen=="review" then
        local ok=validate()
        button(rightX,H-1,right,liveRequest() and ("Add "..S.quantity.." "..(castSelection() and castSelection().label or "").." to Queue") or "Save request",ok and saveRequest or nil)
      else
        local pageLabel=""
        if S.screen=="item" and S.page<pages then
          pageLabel="Page: "..S.page.." / "..pages
        elseif S.screen=="category" then
          pageLabel="Select category"
        end
        text(rightX,H,right,pageLabel,colors.black,colors.lightGray)
      end
    end
  end
end
local function writeJob(j)
  local f=assert(fs.open(JOB_STATE,"w")); f.write(textutils.serialize(j)); f.close()
end
local function castCall(name,method,...)
  local ok,value=pcall(networkCall,name,method,...)
  if not ok then error(tostring(name).."."..method..": "..tostring(value),0) end
  return value
end
startGearRequest=function()
  local old=previousJob()
  if not Q.active and old and old.status~="done" then S.message="Previous job needs inspection";return end
  local needsChest=false
  for _,p in ipairs(recipe().parts) do if p.source=="chest" and (p.required or S.selected[p.name]) then needsChest=true;break end end
  if needsChest then chestCatalog.scan() end
  refreshStock();readCastReport(true)
  local ok,reason=validate();if not ok then S.message=reason;return end
  local planned,plan=pcall(planGearRequest,S.item,recipe(),S.selected,S.quantity,gearPlanContext(false))
  if not planned then S.message=tostring(plan);return end
  local requestId=Q.nextRequestId or 1
  for _,batch in ipairs(plan) do
    batch.id=Q.nextId or 1;Q.nextId=batch.id+1;batch.requestId=requestId
    Q.batches[#Q.batches+1]=batch
  end
  Q.nextRequestId=requestId+1;saveQueue()
  S.message="Queued "..S.quantity.." "..S.item.." kits ("..#plan.." jobs)";S.quantity=1
  os.queueEvent("gear_cast_start")
end
startChestDelivery=function()
  chestCatalog.scan();refreshStock()
  local ok,reason=validate()
  if not ok then S.message=reason;return end
  local r=castSelection()
  local components={{name=r.name,nbt=r.nbt,displayName=r.displayName,amount=r.amount}}
  for _,extra in ipairs(r.extras or {}) do components[#components+1]={name=extra.name,nbt=extra.nbt,amount=extra.amount} end
  local batch={kind="chest",id=Q.nextId or 1,shape=S.item,quantity=S.quantity,remaining=S.quantity,completed=0,
    label=r.label.." - "..S.item,sourceChest=C.partsChest,outputChest=C.outputChest,components=components}
  Q.nextId=batch.id+1;Q.batches[#Q.batches+1]=batch;saveQueue()
  S.message="Queued "..batch.quantity.." "..S.item.." bundles";S.quantity=1
  os.queueEvent("gear_cast_start")
end
local function runChestDelivery(batch,journal)
  assert(batch.sourceChest and batch.outputChest and batch.sourceChest~=batch.outputChest,"Configure different parts/output chests")
  S.job={phase="delivery",progress=1,label="Delivering "..batch.label};os.queueEvent("gear_job_update")
  return deliverChest(batch,journal,{call=castCall,save=writeJob})
end
startLiveCast=function()
  readCastReport(true)
  local issue=castProblem(S.item,S.category,S.selected)
  if issue then S.message=issue; return end
  local r=castSelection()
  local mapping=r and castMapping(S.item,r.name,r.label)
  if not mapping then
    S.message="This material needs a different cast type"; return
  end
  local outputs={}; for _,id in ipairs(mapping.outputs or {}) do outputs[#outputs+1]=id end
  local station=castStations[S.item]
  if not station or not station.peripheral or station.peripheral=="" then S.message="Assign this cast station first"; return end
  -- A station may not impersonate two different permanent cast types.
  for shape,other in pairs(castStations) do
    if shape~=S.item and other.peripheral==station.peripheral then S.message="Station also assigned to "..shape; return end
  end
  local batch={id=Q.nextId or 1,remaining=S.quantity,quantity=S.quantity,
    label=r.label.." "..S.item,material=r.label,shape=S.item,station=station.peripheral,
    coolSeconds=station.coolSeconds or math.max(0.5,3*r.amount/90),
    deliverySeconds=station.deliverySeconds or 120,
    fluid=r.name,amount=r.amount,outputs=outputs}
  Q.nextId=batch.id+1
  batch.completed=0
  Q.batches[#Q.batches+1]=batch
  saveQueue()
  S.message="Queued "..batch.label.." x"..batch.quantity
  S.quantity=1
  os.queueEvent("gear_cast_start")
end
local function finishCastOutput(batch,journal,item)
  local target,output=journal.table,journal.outputChest
  local matches,actual,label,shapeMatch=Cast.outputInfo(batch.shape,target,item,batch.material,batch.outputs)
  local wrongCast=not shapeMatch
  if not matches and not wrongCast then Cast.checkOutput(batch.shape,target,item,batch.material,batch.outputs) end
  local mismatch="Wrong cast at "..Cast.location(target)..": installed "..actual.." Cast; expected "..batch.shape.." Cast."
  if wrongCast then
    Cast.setTableError(batch.shape,target,actual,mismatch)
    journal.wrongCast=actual
  else
    for _,tank in pairs(castCall(target,"tanks")) do
      if (tank.amount or 0)>0 then error("Output ready but fluid remains at "..Cast.location(target).."; inspect before collection",0) end
    end
    Cast.checkOutput(batch.shape,target,item,batch.material,batch.outputs)
  end
  if journal.actualOutput and journal.actualOutput~=item.name then error("Output changed at "..Cast.location(target),0) end
  journal.actualOutput=item.name
  journal.status=wrongCast and "wrong_output_delivery_started" or "delivery_started";writeJob(journal)
  local moved=castCall(target,"pushItems",output,1,1)
  if moved==0 then
    if wrongCast then error(mismatch.." Unexpected output could not be delivered; check output chest.",0) end
    return false
  end
  if moved~=1 then error("Uncertain item delivery at "..Cast.location(target).."; inspect before retrying",0) end
  journal.output=item.name
  journal.status=wrongCast and "wrong_output_delivered" or "done";writeJob(journal)
  readCastReport(true)
  if wrongCast then
    local entry=castReport and castReport.casts[batch.shape]
    local spare=entry and entry.available
    local stockMessage=not castReport and ("Cast chest unavailable: "..tostring(castReportError)) or
      (spare and "Correct spare cast available; remove wrong cast, then Clear Errors." or "Missing cast: add a "..batch.shape.." Cast, replace wrong cast, then Clear Errors.")
    error(mismatch.." Unexpected item delivered. TableError enabled. "..stockMessage,0)
  end
  return true
end
local function recoverQueuedOutput(batch,journal)
  local sources,seen={},{}
  for _,source in ipairs(C.fluidStores or {}) do if not seen[source] then seen[source]=true;sources[#sources+1]=source end end
  local item=recoverCasting(batch,journal,{
    call=castCall,save=writeJob,sources=sources,location=Cast.location,sleep=sleep,
    phase=function(label)
      S.job={phase="delivery",progress=1,label=label};os.queueEvent("gear_job_update")
    end,
  })
  if not finishCastOutput(batch,journal,item) then error("Output blocked at "..Cast.location(journal.table),0) end
  return true
end
local function clearTableErrors()
  if S.busy then S.message="Wait for the current operation to stop";return end
  local old=previousJob()
  local pendingWrong=Q.active and old and old.queueToken==Q.token and old.status=="wrong_output_delivered"
  local batch=Q.batches[1]
  local count,lines,cleared=Cast.clearTableErrors(castStations,pendingWrong and old.table or nil,batch and batch.shape)
  if pendingWrong and cleared[old.table] then
    old.status="not_started";writeJob(old)
    Q.active=false;Q.pendingFluid=false;Q.token=nil;saveQueue()
  end
  readCastReport(true)
  S.message="Revalidated tables: "..count.." cleared."
  if #lines==0 then lines[1]="No saved TableError states found." end
  S.castIssue=S.message.." "..table.concat(lines," ")
  if pendingWrong and cleared[old.table] then Q.reason=S.castIssue;S.job=nil;saveQueue() end
end
local function resumeQueue()
  if S.busy then return end
  readCastReport(true)
  local old=previousJob()
  if Q.active then
    if not old or old.queueToken~=Q.token then
      S.message="Inspect pending cast; its job record does not match"; return
    end
    local batch=Q.batches[1]
    if batch and batch.kind=="chest" then
      S.busy=true
      local ok,result=pcall(function() if old.status~="done" then runChestDelivery(batch,old) end end)
      S.busy=false
      if not ok then
        Q.paused=true;Q.reason=tostring(result);saveQueue();S.issueReturn="queue";S.castIssue=Q.reason;go("castIssue");return
      end
      advanceQueue();Q.paused=false;Q.reason=nil;saveQueue();S.job=nil;chestCatalog.scan()
      os.queueEvent("gear_cast_start");return
    end
    if old.status~="done" then
      local batch=Q.batches[1]
      -- Recover zero-acceptance journals created by older UI versions too.
      if batch and old.moved==0 then
        local checked,empty=pcall(function()
          if next(castCall(old.table,"list")) then return false end
          for _,tank in pairs(castCall(old.table,"tanks")) do if (tank.amount or 0)>0 then return false end end
          return true
        end)
        if checked and empty then
          old.status="not_started"; writeJob(old)
          Q.active=false; Q.pendingFluid=false; Q.token=nil; Q.paused=true
          if batch.shape~="Block" then Cast.record(batch.shape,old.table,"missing","No fluid accepted; check missing/incompatible cast") end
          Q.reason="Missing or incompatible "..batch.shape.." cast at "..Cast.location(old.table)..". No fluid accepted; check cast before retrying."
          saveQueue(); S.issueReturn="queue"; S.castIssue=Q.reason; go("castIssue"); return
        end
      end
      if not batch or old.moved~=batch.amount or old.fluid~=batch.fluid then
        S.message=(Q.reason or "Partial/uncertain fluid transfer needs inspection").." | "..Cast.location(old.table)
        S.issueReturn="queue"; S.castIssue=S.message; go("castIssue"); return
      end
      S.busy=true
      local ok,delivered=pcall(function()
        if old.status=="wrong_output_delivered" then error("Wrong output already delivered. Replace wrong cast, then Clear Errors before Resume.",0) end
        if old.status:match("^recovery_") then return recoverQueuedOutput(batch,old) end
        local item=castCall(old.table,"list")[1]
        if not item then return recoverQueuedOutput(batch,old) end
        return finishCastOutput(batch,old,item)
      end)
      S.busy=false
      if not ok then
        Q.paused=true;Q.reason=tostring(delivered);saveQueue();readCastReport(true)
        printError(delivered);S.message=tostring(delivered);S.issueReturn="queue";S.castIssue=S.message;go("castIssue");return
      end
      if not delivered then S.message="Still cooling or output blocked; Resume retries delivery only"; return end
    end
    advanceQueue() -- Matching completed/recovered delivery counts exactly once.
  elseif old and old.status~="done" then
    S.message="Previous test needs inspection"; return
  end
  Q.paused=false; Q.reason=nil; saveQueue()
  S.job=nil; os.queueEvent("gear_cast_start")
end

drawJob=function()
  local j=S.job
  local elapsed=j and j.completedAt and os.clock()-j.completedAt or 0
  if j and j.phase=="completed" and elapsed>=4 then S.job=nil; j=nil end
  if S.screen=="welcome" then return end
  for _,d in ipairs(displays) do
    d.mon.setBackgroundColor((Q.paused or S.screen=="castIssue") and colors.red or colors.blue)
    local ox=math.floor((d.w-W)/2)
    d.mon.setCursorPos(ox+1,d.h); d.mon.write(string.rep(" ",W))
    local version="v"..VERSION
    d.mon.setTextColor(colors.gray)
    d.mon.setCursorPos(ox+math.max(1,W-#version),d.h); d.mon.write(version)
  end
  if S.screen=="main" then return end
  for _,d in ipairs(displays) do
    if W>=30 and H>=20 then
      local ox=math.floor((d.w-W)/2)
      local bodyBottom=d.h-(C.bottomMargin or 9)
      -- Queue button sits directly below the actions; status follows it.
      -- The last physical row is reserved for the footer.
      local top=bodyBottom+4
      local m=d.mon
      local function line(y,label,fg)
        m.setBackgroundColor(colors.black); m.setTextColor(fg or colors.white)
        m.setCursorPos(ox+1,y); m.write(centered(label,W))
      end
      if top+4<d.h then
        for y=top,top+4 do line(y,"") end
        line(top,string.rep("-",W),colors.gray)
        local nextBatch=Q.batches[1]
        local nextCount=nextBatch and (nextBatch.remaining-(Q.active and 1 or 0)) or 0
        if nextCount<=0 then nextBatch=Q.batches[2]; nextCount=nextBatch and nextBatch.remaining or 0 end
        local left="Items in Queue: "..waitingItems()
        local right="Next Item: "..(nextBatch and (nextBatch.label.." x"..nextCount) or "--")
        local split=#left+#right+2>W
        if not split then
          m.setCursorPos(ox+1,top+1); m.write(left..string.rep(" ",W-#left-#right)..right)
        else line(top+1,left); line(top+2,right) end
        local label=Q.paused and "Queue paused - Resume above" or j and j.label or "Queue idle"
        local fill=colors.cyan
        local progress=j and j.progress or 0
        if j and j.phase=="cooling" then progress=math.min(1,(os.clock()-j.started)/(j.duration or 3)) end
        if j and j.phase=="completed" and not Q.paused then
          fill=colors.yellow
          local level=elapsed<1.5 and (math.floor(elapsed/.25)%2==0 and 1 or .35) or math.max(0,1-(elapsed-1.5)/2.5)
          local r,g,b=pulseColor(palette[colors.black],0x55C58C,level)
          m.setPaletteColor(colors.yellow,r,g,b)
          local tr,tg,tb=pulseColor(palette[colors.black],palette[colors.white],level)
          m.setPaletteColor(colors.magenta,tr,tg,tb)
        elseif Q.paused then fill=colors.red end
        local labelColor=j and j.phase=="completed" and colors.magenta or colors.white
        if not split then line(top+2,label,labelColor) end
        if j or Q.paused then
          local n=math.floor(W*math.max(0,math.min(1,progress)))
          for y=top+3,top+4 do
            m.setCursorPos(ox+1,y); m.setBackgroundColor(fill); m.write(string.rep(" ",n))
            m.setBackgroundColor(colors.gray); m.write(string.rep(" ",W-n))
          end
          if split then
            m.setCursorPos(ox+1,top+3)
            m.blit(centered(label,W),string.rep(colors.toBlit(labelColor),W),string.rep(colors.toBlit(fill),n)..string.rep(colors.toBlit(colors.gray),W-n))
          end
        elseif split then line(top+3,label,labelColor)
        end
      end
    end
  end
end
local function castWorker()
  while true do
    if Q.paused or #Q.batches==0 then os.pullEvent("gear_cast_start") end
    if not Q.paused and #Q.batches>0 then
    S.busy=true
    local journal
    local ok,err=pcall(function()
      local batch=Q.batches[1]
      if batch.kind=="chest" then
        local old=previousJob();assert(not old or old.status=="done","Previous delivery needs inspection")
        journal={status="chest_delivery",delivered={},sourceChest=batch.sourceChest,outputChest=batch.outputChest}
        Q.token=tostring(batch.id)..":"..tostring((batch.completed or 0)+1)
        journal.queueToken=Q.token;Q.active=true;Q.pendingFluid=false;saveQueue();writeJob(journal)
        runChestDelivery(batch,journal);advanceQueue();S.busy=false
        S.job={phase="completed",progress=1,label="Completed",completedAt=os.clock()};os.queueEvent("gear_job_update")
        chestCatalog.scan()
        if #Q.batches>0 then sleep(0.5) end
        return
      end
      local fluid,amount=batch.fluid,batch.amount
      local tableName=batch.station
      readCastReport(true)
      local issue=castProblem(batch.shape,"Other")
      if issue then error(issue,0) end
      if not tableName or tableName=="" then error("No dedicated station assigned to "..batch.shape,0) end
      local sources={}
      local seen={}
      for _,name in ipairs(C.fluidStores or {}) do if not seen[name] then sources[#sources+1]=name; seen[name]=true end end
      local source=sources[1]
      local output=C.outputChest
      local old=previousJob()
      if old and old.status~="done" then error("Previous cast needs inspection",0) end
      if not source or not output or output=="" then error("Configure fluid store and output chest",0) end
      local function fluidTotal(name,filter)
        local count=0
        for _,t in pairs(castCall(name,"tanks")) do
          if not filter or t.name==filter then count=count+(t.amount or 0) end
        end
        return count
      end
      if next(castCall(tableName,"list")) then error("Table output occupied",0) end
      if fluidTotal(tableName)>0 then error("Table already contains fluid",0) end
      Cast.ensure(batch.shape,tableName,castStations)
      local available=0
      for _,name in ipairs(sources) do available=available+fluidTotal(name,fluid) end
      if available<amount then error("Not enough molten "..batch.material,0) end
      local contents=castCall(output,"list")
      local empty=false
      for slot=1,castCall(output,"size") do if not contents[slot] then empty=true; break end end
      if not empty then error("Output chest needs an empty slot",0) end
      journal={status="fluid_transfer_started",moved=0,table=tableName,source=source,outputChest=output,fluid=fluid,requested=amount,expectedOutputs=batch.outputs}
      Q.token=tostring(Q.batches[1].id)..":"..tostring(Q.batches[1].quantity-Q.batches[1].remaining+1)
      Q.active=true; Q.pendingFluid=true; saveQueue()
      journal.queueToken=Q.token
      writeJob(journal)
      S.job={phase="pouring",progress=0,label="Pouring "..batch.label}
      os.queueEvent("gear_job_update")
      local moved=0
      for _,name in ipairs(sources) do
        if moved>=amount then break end
        local count=castCall(name,"pushFluid",tableName,amount-moved,fluid)
        if type(count)~="number" or count<0 or count>amount-moved then error("Unexpected fluid transfer result",0) end
        moved=moved+count; journal.moved=moved; writeJob(journal)
      end
      if moved==0 and fluidTotal(tableName)==0 and not next(castCall(tableName,"list")) then
        -- No fluid entered this job. Do not leave a protected active unit behind.
        journal.status="not_started"; writeJob(journal)
        Q.active=false; Q.pendingFluid=false; Q.token=nil; saveQueue()
        if batch.shape~="Block" then Cast.record(batch.shape,tableName,"missing","No fluid accepted; cast may be missing or incompatible") end
        error("Missing or incompatible "..batch.shape.." cast at "..Cast.location(tableName)..". Table accepted 0 / "..amount.." mB. Check cast before retrying.",0)
      end
      journal.status="waiting_for_output"; writeJob(journal)
      if moved~=amount then error("Partial fluid transfer ("..moved.." / "..amount.." mB) at "..Cast.location(tableName).."; check cast and table contents before retrying",0) end
      Q.pendingFluid=false; saveQueue()
      S.job={phase="cooling",started=os.clock(),duration=batch.coolSeconds,progress=0,label="Casting "..batch.label}
      os.queueEvent("gear_job_update")
      sleep(batch.coolSeconds)
      S.job={phase="delivery",progress=1,label="Cooling finished - delivering"}
      os.queueEvent("gear_job_update")
      local deadline=os.clock()+5
      local complete=false
      repeat
        local item=castCall(tableName,"list")[1]
        if item and finishCastOutput(batch,journal,item) then complete=true;break end
        sleep(0.5)
      until os.clock()>=deadline
      if not complete then
        journal.status="recovery_query";writeJob(journal)
        complete=recoverQueuedOutput(batch,journal)
      end
      if complete then
        advanceQueue()
        S.busy=false
        S.job={phase="completed",progress=1,label="Completed",completedAt=os.clock()}
        os.queueEvent("gear_job_update")
        if #Q.batches>0 then sleep(0.5) end
      end
    end)
    if not ok then
      local batch=Q.batches[1]
      local location=batch and batch.kind~="chest" and Cast.location(batch.station) or nil
      err=tostring(err)
      if location and not err:find(location,1,true) then err=err.." | "..location end
      readCastReport(true)
      printError(err)
      S.busy=false; Q.paused=true; Q.reason=err; saveQueue()
      S.job={phase="error",progress=1,label=tostring(err)}
      S.issueReturn="queue"; S.castIssue=tostring(err); go("castIssue")
      os.queueEvent("gear_job_update")
    end
    end
  end
end
local function cancelWaiting(id,one)
  local cancelledCurrent=false
  local cancelledBatch=false
  for i=#Q.batches,1,-1 do
    local batch=Q.batches[i]
    if not id or batch.id==id then
      local protect=protectedUnit(i)
      local removable=math.max(0,batch.remaining-protect)
      batch.completed=batch.completed or math.max(0,(batch.quantity or batch.remaining)-batch.remaining)
      local count=one and math.min(1,removable) or removable
      if i==1 and count>0 and Q.paused and not S.busy then
        cancelledBatch=true
        if Q.active then
          local old=previousJob()
          if not old or old.queueToken~=Q.token then S.message="Pending job record mismatch; inspect before cancelling"; return end
          -- Keep a durable audit. Cancellation never pulls items or sends fluid.
          fs.makeDir(fs.combine(ROOT,"backups"))
          local audit=fs.combine(ROOT,"backups/cancelled_cast_"..os.epoch("utc").."_"..batch.id..".txt")
          local f=assert(fs.open(audit,"w")); f.write(textutils.serialize(old)); f.close()
          old.previousStatus=old.status; old.status="cancelled"; old.cancelledAt=os.epoch("utc"); writeJob(old)
          Q.active=false; Q.pendingFluid=false; Q.token=nil
          cancelledCurrent=true
        end
      end
      batch.remaining=batch.remaining-count
      if batch.remaining==0 then table.remove(Q.batches,i) end
    end
  end
  if cancelledBatch then
    S.job=nil
    Q.reason=#Q.batches>0 and "Failed item cancelled; inspect table, then Resume" or nil
    if #Q.batches==0 then Q.paused=false end
  end
  saveQueue()
  S.message=cancelledCurrent and "Cancelled. Existing items/fluids left for inspection." or one and "Removed one item" or "Removed selected items"
  os.queueEvent("gear_job_update")
end
local function resetCastInstallations()
  if S.busy or Q.active then
    S.message="Finish or cancel the active cast before resetting tracking."
    return
  end
  local old=previousJob()
  if old and old.status~="done" then
    S.message="Resolve the pending casting job before resetting tracking."
    return
  end
  if #Q.batches>0 then
    Q.paused=true;Q.reason="Installed-cast tracking reset; review tables before Resume";saveQueue()
  end
  S.busy=true
  local ok,result=pcall(Cast.resetInstallations)
  S.busy=false
  readCastReport(true)
  go("utilities")
  S.message=ok and ("Installed-cast tracking reset. Deleted "..result.." files. Physical casts unchanged.") or tostring(result)
end
local function openMain()
  S.category=nil; S.item=nil; S.selected={}; S.quantity=1; go("main")
end
local function openSection(section)
  S.section=section; S.item=nil; S.selected={}; S.quantity=1
  if section=="gear" then S.category=nil; go("category")
  else S.category=section=="parts" and "Other Tool Parts" or "Other"; go("sectionItems") end
end
local function openQueue()
  -- Error details and the queue are transient pages, never queue back targets.
  if S.screen~="queue" and S.screen~="castIssue" then S.returnScreen=S.screen end
  if not S.returnScreen or S.returnScreen=="castIssue" or S.returnScreen=="queue" then S.returnScreen="main" end
  go("queue")
end
local function wrapWords(text,width)
  local lines={}; local line=""
  for word in text:gmatch("%S+") do
    if #line>0 and #line+1+#word>width then lines[#lines+1]=line; line="" end
    while #word>width do
      if #line>0 then lines[#lines+1]=line; line="" end
      lines[#lines+1]=word:sub(1,width); word=word:sub(width+1)
    end
    if #word>0 then line=line=="" and word or line.." "..word end
  end
  if #line>0 then lines[#lines+1]=line end
  return lines
end
-- Compact 5x7 lettering rendered with monitor mosaic cells. This lets the
-- heading appear at scale 1.5 while the prompt keeps the normal 0.5 size.
local welcomeGlyphs={
  W={"10001","10001","10001","10101","10101","10101","01010"},
  C={"01111","10000","10000","10000","10000","10000","01111"},
  a={"00000","00000","01110","00001","01111","10001","01111"},
  c={"00000","00000","01111","10000","10000","10000","01111"},
  e={"00000","00000","01110","10001","11111","10000","01111"},
  f={"00110","01001","01000","11100","01000","01000","01000"},
  g={"00000","01111","10001","10001","01111","00001","01110"},
  h={"10000","10000","10110","11001","10001","10001","10001"},
  i={"00100","00000","01100","00100","00100","00100","01110"},
  l={"01100","00100","00100","00100","00100","00100","01110"},
  m={"00000","00000","11010","10101","10101","10101","10101"},
  n={"00000","00000","10110","11001","10001","10001","10001"},
  o={"00000","00000","01110","10001","10001","10001","01110"},
  r={"00000","00000","10110","11001","10000","10000","10000"},
  t={"01000","01000","11100","01000","01000","01001","00110"},
}
local function drawWelcomeHeading(m,w,h)
  local lines=wrapWords("Welcome to the Crafting Center",math.max(1,math.floor(w/3)))
  local rows=math.ceil(((#lines-1)*9+7)/3)
  local prompt=wrapWords("Right click to begin",w)
  local first=math.max(1,math.min(math.floor((h-rows)/2)+1,h-rows-#prompt))
  local pixels={}
  for index,line in ipairs(lines) do
    local xStart=math.floor((w*2-(#line*6-1))/2)+1
    for i=1,#line do
      local glyph=welcomeGlyphs[line:sub(i,i)]
      if glyph then
        for y=1,7 do
          local py=(index-1)*9+y
          pixels[py]=pixels[py] or {}
          for x=1,5 do
            if glyph[y]:sub(x,x)=="1" then pixels[py][xStart+(i-1)*6+x-1]=true end
          end
        end
      end
    end
  end
  for row=1,rows do
    if first+row-1<=h then
      local chars,fg,bg={},{},{}
      for col=1,w do
        local mask=0
        for bit=0,5 do
          local py=(row-1)*3+math.floor(bit/2)+1
          local px=(col-1)*2+bit%2+1
          if pixels[py] and pixels[py][px] then mask=mask+2^bit end
        end
        local invert=mask>=32
        local bits=mask%32
        if invert then bits=31-bits end
        chars[col]=string.char(128+bits)
        fg[col]=invert and "f" or "0"; bg[col]=invert and "0" or "f"
      end
      m.setCursorPos(1,first+row-1)
      m.blit(table.concat(chars),table.concat(fg),table.concat(bg))
    end
  end
  m.setTextColor(colors.lightGray); m.setBackgroundColor(colors.black)
  for i,line in ipairs(prompt) do
    local y=first+rows+i
    if y<=h then m.setCursorPos(1,y); m.write(centered(line,w)) end
  end
end
drawWelcome=function()
  local breath=(1-math.cos((os.clock()-pulseEpoch)*2*math.pi/6))/2
  for _,d in ipairs(displays) do
    local m=d.mon
    -- A small common cell grid supports both sizes on a single monitor.
    if not d.welcomeActive then m.setTextScale(0.5); d.welcomeActive=true; d.welcomePage=nil end
    local w,h=m.getSize()
    local r,g,b=pulseColor(0x101820,0x090E12,breath)
    if m.isColor() then
      m.setPaletteColor(colors.black,r,g,b)
      m.setPaletteColor(colors.white,0xFFFFFF)
      m.setPaletteColor(colors.lightGray,0x1F2E3D)
    end
    if d.welcomePage~=0 then
      m.setBackgroundColor(colors.black); m.clear()
      drawWelcomeHeading(m,w,h)
      d.welcomePage=0
    end
    d.buttons={{x=1,y=1,w=w,h=h,action=openMain}}
  end
end
local function renderSpecial()
  for _,d in ipairs(displays) do
    local m=d.mon
    if m.isColor() then for slot,rgb in pairs(palette) do m.setPaletteColor(slot,rgb) end end
    m.setBackgroundColor(colors.black); m.setTextColor(colors.white); m.clear(); d.buttons={}
    local ox=math.floor((d.w-W)/2)
    local oy=math.max(0,d.h-(C.bottomMargin or 9)-H)
    local function text(y,label,bg)
      m.setBackgroundColor((y==1 and (Q.paused or S.screen=="castIssue")) and colors.red or bg or colors.black); m.setTextColor(colors.white)
      m.setCursorPos(ox+1,oy+y); m.write(centered(label,W))
    end
    local function button(x,y,width,label,action,bg)
      m.setBackgroundColor(bg or colors.blue); m.setTextColor(action and colors.white or colors.lightGray)
      for row=0,1 do m.setCursorPos(ox+x,oy+y+row); m.write(row==0 and centered(label,width) or string.rep(" ",width)) end
      if action then d.buttons[#d.buttons+1]={x=ox+x,y=oy+y,w=width,h=2,action=action} end
    end
    if W<30 or H<20 then text(1,"Need 30x20 usable area")
    elseif S.screen=="main" then
      text(1,"CRAFTING CENTER",colors.blue); text(5,"Select Option")
      local menuWidth=math.floor(W*2/3)
      local start=math.floor((W-menuWidth)/2)+1
      local half=math.floor((menuWidth-2)/2)
      button(start,8,half,"Gear",function() openSection("gear") end)
      button(start+half+2,8,menuWidth-half-2,"Tool Parts",function() openSection("parts") end)
      button(start,11,menuWidth,"Other",function() openSection("other") end)
      button(start,H-1,menuWidth,"Utilities",function() go("utilities") end,colors.gray)
    elseif S.screen=="utilities" then
      text(1,"UTILITIES",colors.blue)
      button(1,3,math.floor(W*.43),"<< Back",function() go("main") end,colors.gray)
      text(6,"Quick actions and options")
      button(2,8,W-2,"Reset Installed Cast List",function() go("resetCastReview") end,colors.red)
      local lines=wrapWords(S.message~="" and S.message or "Reset tracking records without moving physical casts.",W-2)
      for i,line in ipairs(lines) do if 12+i<=H-3 then text(12+i,line) end end
    elseif S.screen=="resetCastReview" then
      text(1,"RESET INSTALLED CASTS",colors.blue)
      button(1,3,math.floor(W*.43),"<< Back",function() go("utilities") end,colors.gray)
      local lines={"Delete these installation tracking files?",
        "cast_installations.txt", "cast_installations.txt.download",
        "backups/cast_installations.txt.bak", "backups/cast_installations.txt.bak.download",
        "Physical casts stay in their tables.","Queue data stays; waiting jobs will pause."}
      for i,line in ipairs(lines) do text(5+i,line) end
      local note=S.message~="" and S.message or ((S.busy or Q.active) and "Finish or cancel the active cast first." or "The installed cast list will become empty.")
      for i,line in ipairs(wrapWords(note,W-2)) do if 13+i<=H-3 then text(13+i,line) end end
      local half=math.floor((W-2)/2)
      button(1,H-1,half,"Cancel",function() go("utilities") end,colors.gray)
      button(half+3,H-1,W-half-2,"Confirm Reset",not S.busy and not Q.active and resetCastInstallations or nil,colors.red)
    elseif S.screen=="castIssue" then
      text(1,"ERROR REPORT",colors.red)
      button(1,3,math.floor(W*.43),"<< Back",function() go(S.issueReturn or "item") end,colors.gray)
      local lines=wrapWords(S.castIssue or "Cast check needed",W-2)
      for i,line in ipairs(lines) do if 6+i<H-5 then text(6+i,line) end end
      text(H-4,"Clear Errors rechecks table contents")
      local rightX=math.floor(W*.43)+3
      button(rightX,H-1,W-rightX+1,"Clear Errors",clearTableErrors,colors.red)
      text(H-2,"Chest stock + recorded installation")
    elseif S.screen=="sectionItems" or S.screen=="category" or S.screen=="item" then
      local gearCategories=S.screen=="category"
      local title=gearCategories and "Gear" or S.section=="gear" and S.category or S.section=="parts" and "Tool Parts" or "Other | Casting"
      text(1,title,colors.blue)
      text(5,gearCategories and "Select gear category" or S.section=="gear" and "Select equipment" or S.section=="parts" and "Select a tool part" or "Select a molten-material cast")
      button(1,3,math.floor(W*.43),"<< Back",function()
        if S.section=="gear" and not gearCategories then S.item=nil; go("category") else openMain() end
      end,colors.gray)
      local items=gearCategories and categories or catalog[S.category]
      local count=math.max(1,math.floor((H-11)/3))*2
      local pages=math.max(1,math.ceil(#items/count))
      S.page=math.min(S.page,pages)
      local half=math.floor((W-2)/2)
      for i=1,count do
        local item=items[(S.page-1)*count+i]
        if item then
          local x=i%2==1 and 1 or half+3
          local issue,issueColor
          if not gearCategories then issue,issueColor=castProblem(item,S.category) end
          button(x,7+math.floor((i-1)/2)*3,i%2==1 and half or W-half-2,(issue and "! " or "")..item,function()
            local problem=not gearCategories and castProblem(item,S.category)
            if problem then
              S.issueReturn=S.screen; S.castIssue=problem; go("castIssue"); return
            end
            S.selected={}; S.quantity=1
            if gearCategories then S.category=item; S.item=nil; go("item")
            else S.item=item; go("part") end
          end,issueColor)
        end
      end
      if S.page>1 then button(1,H-4,half,"Previous",function() S.page=S.page-1 end,colors.gray) end
      if S.page<pages then button(half+3,H-4,W-half-2,"Next",function() S.page=S.page+1 end,colors.gray) end
      if S.page<pages then text(H-1,"Page: "..S.page.." / "..pages) end
    elseif S.screen=="queue" then
      text(1,"CASTING QUEUE",colors.blue)
      button(1,3,math.floor(W*.43),"<< Back",function() go(S.returnScreen or "main") end,colors.gray)
      text(5,"Waiting: "..waitingItems()..(Q.paused and " | Paused" or ""))
      local count=math.max(1,math.floor((H-11)/3))
      local pages=math.max(1,math.ceil(#Q.batches/count)); S.page=math.min(S.page,pages)
      for row=1,count do
        local index=(S.page-1)*count+row
        local batch=Q.batches[index]
        if batch then
          local protect=protectedUnit(index)
          local waiting=batch.remaining-protect
          local y=7+(row-1)*3
          local labelWidth=W-15
          button(1,y,labelWidth,(Q.paused and "! " or "")..batch.label.." x"..waiting,Q.paused and function()
            S.issueReturn="queue"; S.castIssue=Q.reason or "Queue paused"; go("castIssue")
          end or nil)
          local id=batch.id
          button(labelWidth+2,y,5,"-1",waiting>0 and function() cancelWaiting(id,true) end or nil,colors.gray)
          button(labelWidth+8,y,8,"Remove",waiting>0 and function() cancelWaiting(id,false) end or nil,colors.red)
          if index==1 and (S.busy or Q.active or Q.paused) then
            local completed=batch.completed or math.max(0,(batch.quantity or batch.remaining)-batch.remaining)
            local current=completed+1
            local phase=S.job and S.job.phase
            local status=Q.paused and "Error! Job paused - click for info" or
              ((phase=="cooling" and "Cooling" or phase=="delivery" and "Transferring" or phase=="pouring" and "Pouring" or "Preparing").." item #"..current.." of "..(completed+batch.remaining))
            m.setBackgroundColor(colors.black); m.setTextColor(Q.paused and colors.red or colors.white)
            m.setCursorPos(ox+1,oy+y+2); m.write(status:sub(1,W))
            if Q.paused then d.buttons[#d.buttons+1]={x=ox+1,y=oy+y+2,w=W,h=1,action=function()
              S.issueReturn="queue"; S.castIssue=Q.reason or "Queue paused"; go("castIssue")
            end} end
          end
        end
      end
      if #Q.batches==0 then text(7,"Queue is empty") end
      local half=math.floor((W-2)/2)
      if S.page>1 then button(1,H-4,half,"Previous",function() S.page=S.page-1 end,colors.gray) end
      if S.page<pages then button(half+3,H-4,W-half-2,"Next",function() S.page=S.page+1 end,colors.gray) end
      text(H-2,S.message)
      if Q.paused then
        button(1,H-1,half,"Resume Queue",resumeQueue,colors.red)
        button(half+3,H-1,W-half-2,"Clear queue",waitingItems()>0 and function() cancelWaiting(nil,false) end or nil,colors.gray)
      else
        button(1,H-1,W,"Clear waiting items",waitingItems()>0 and function() cancelWaiting(nil,false) end or nil,colors.red)
      end
    end
  end
end
-- Always paint the overlay after navigation/stock refreshes.
local renderScreen=render
render=function()
  if S.screen=="welcome" then drawWelcome(); return end
  for _,d in ipairs(displays) do
    if d.welcomeActive then d.mon.setTextScale(C.textScale); d.welcomeActive=false; d.welcomePage=nil end
  end
  local special=S.screen=="utilities" or S.screen=="resetCastReview" or S.screen=="castIssue" or S.screen=="welcome" or S.screen=="main" or S.screen=="sectionItems" or S.screen=="category" or S.screen=="item" or S.screen=="queue"
  if special then renderSpecial() else renderScreen() end
  for _,d in ipairs(displays) do
    if W>=30 and H>=20 then
      local ox=math.floor((d.w-W)/2)
      local oy=math.max(0,d.h-(C.bottomMargin or 9)-H)
      local function control(x,width,label,action,bg)
        local y=oy+H-5
        d.mon.setTextColor(colors.white); d.mon.setBackgroundColor(bg or colors.blue)
        for row=0,1 do
          d.mon.setCursorPos(ox+x,y+row)
          d.mon.write(row==0 and centered(label,width) or string.rep(" ",width))
        end
        if action then d.buttons[#d.buttons+1]={x=ox+x,y=y,w=width,h=2,action=action} end
      end
      if liveRequest() and S.screen=="review" then
        -- All Other shapes have one Material row; keep material scrolling separate.
        local labels={"Min","-16","-1","Qty: "..S.quantity,"+1","+16","Max"}
        local actions={function() S.quantity=1 end,function() S.quantity=math.max(1,S.quantity-16) end,
          function() S.quantity=math.max(1,S.quantity-1) end,false,
          function() S.quantity=math.min(64,S.quantity+1) end,function() S.quantity=math.min(64,S.quantity+16) end,function() S.quantity=64 end}
        -- Reserve enough room for the quantity even on narrow displays.
        local unit=math.floor((W-8)/6)
        local x=1
        for i,label in ipairs(labels) do
          local width=i==4 and 8 or (i==7 and W-x+1 or unit)
          control(x,width,label,actions[i] or nil,i==4 and colors.cyan or colors.blue)
          x=x+width
        end
      end
      if S.screen=="part" or S.screen=="material" or S.screen=="review" then
        local y=oy+H-1
        local kept={}
        for _,b in ipairs(d.buttons) do if b.y~=y then kept[#kept+1]=b end end
        d.buttons=kept
        d.mon.setBackgroundColor(colors.black)
        for row=0,1 do d.mon.setCursorPos(ox+1,y+row); d.mon.write(string.rep(" ",W)) end
        local width=math.floor((W-4)/2)
        local rightX=W-width
        local function action(x,label,fn)
          d.mon.setBackgroundColor(fn and colors.cyan or colors.gray); d.mon.setTextColor(fn and colors.white or colors.lightGray)
          for row=0,1 do d.mon.setCursorPos(ox+x,y+row); d.mon.write(row==0 and centered(label,width) or string.rep(" ",width)) end
          if fn then d.buttons[#d.buttons+1]={x=ox+x,y=y,w=width,h=2,action=fn} end
        end
        action(2,"Reset",function() S.selected={}; S.quantity=1; S.message="Selections cleared" end)
        if S.screen=="review" then
          local ok=validate()
          local material=castSelection()
          local label=liveRequest() and ("Add "..S.quantity.." to Queue") or "Save request"
          action(rightX,label,ok and saveRequest or nil)
        else action(rightX,"Review",function() go("review") end) end
      end
      if S.screen~="welcome" then
        local width=W-2
        local x=2
        local y=d.h-(C.bottomMargin or 9)+2
        if S.screen=="main" then
          width=math.floor(W*2/3)
          x=math.floor((W-width)/2)+1
          y=oy+14 -- Same width/position as Other, with a blank row between.
        end
        -- Keep the route breadcrumb beneath the top header.
        local paneX=math.floor(W*.43)+3
        d.mon.setBackgroundColor(colors.black)
        for row=3,4 do d.mon.setCursorPos(ox+paneX,oy+row); d.mon.write(string.rep(" ",W-paneX+1)) end
        local count=0
        for _,batch in ipairs(Q.batches) do count=count+batch.remaining end
        local available=S.screen=="main" or ((count>0 or Q.active or S.busy) and S.screen~="queue")
        d.mon.setTextColor(available and colors.white or colors.lightGray)
        d.mon.setBackgroundColor(available and colors.cyan or colors.gray)
        for row=0,1 do
          d.mon.setCursorPos(ox+x,y+row)
          d.mon.write(row==0 and centered("Queue",width) or string.rep(" ",width))
        end
        if available then d.buttons[#d.buttons+1]={x=ox+x,y=y,w=width,h=2,action=openQueue} end
        if S.screen~="main" then
          local homeWidth=W-paneX+1
          d.mon.setBackgroundColor(colors.blue); d.mon.setTextColor(colors.white)
          for row=0,1 do d.mon.setCursorPos(ox+paneX,oy+3+row); d.mon.write(row==0 and centered("Home",homeWidth) or string.rep(" ",homeWidth)) end
          d.buttons[#d.buttons+1]={x=ox+paneX,y=oy+3,w=homeWidth,h=2,action=openMain}
        end
        if S.item then
          d.mon.setBackgroundColor(colors.black); d.mon.setTextColor(colors.lightGray)
          d.mon.setCursorPos(ox+1,oy+2); d.mon.write(centered((S.section=="parts" and "Tool Parts" or S.category or "").." > "..S.item,W))
        end
      end
      if Q.paused and S.screen=="castIssue" then
        local width=math.floor(W*.43)
        -- Overwrite Reset while paused, retaining all other footer controls.
        local y=oy+H-1
        local kept={}
        for _,b in ipairs(d.buttons) do if not (b.y==y and b.x<ox+1+width) then kept[#kept+1]=b end end
        d.buttons=kept
        d.mon.setBackgroundColor(colors.red); d.mon.setTextColor(colors.white)
        for row=0,1 do d.mon.setCursorPos(ox+1,y+row); d.mon.write(row==0 and centered("Resume Queue",width) or string.rep(" ",width)) end
        d.buttons[#d.buttons+1]={x=ox+1,y=y,w=width,h=2,action=resumeQueue}
      end
    end
  end
  drawJob()
end
connect(); refreshStock(); updatePulse(); render(); flushDisplays()
print("Gear UI running. All configured monitors share control.")
print("Other casting jobs use dedicated station assignments in gear_stations.txt.")
print("Leave each correct cast installed; do not share stations between cast types.")
local function uiLoop()
local timer=os.startTimer(C.pollSeconds)
local pulseTimer=os.startTimer(0.2)
local statsTimer=os.startTimer(5)
while true do
  local event,name,x,y=os.pullEvent()
  if event=="monitor_touch" then
    for _,d in ipairs(displays) do
      if d.name==name then
        S.lastInteraction=os.clock()
        os.cancelTimer(statsTimer)
        statsTimer=os.startTimer(10)
        for _,b in ipairs(d.buttons) do
          if y>=b.y and y<b.y+(b.h or 1) and x>=b.x and x<b.x+b.w then b.action(); break end
        end
        break
      end
    end
    render()
  elseif event=="gear_cast_availability" then
    os.queueEvent("gear_cast_stock_refresh")
  elseif event=="gear_cast_stock_ready" then
    if liveChestRoute() or liveGearRoute() then refreshStock() end
    render()
  elseif event=="gear_job_update" then
    render()
  elseif event=="timer" and name==statsTimer then
    if advanceStatPage() then render() end
    statsTimer=os.startTimer(5)
  elseif event=="timer" and name==pulseTimer then
    local idle=os.clock()-S.lastInteraction
    local pending=#Q.batches>0 or Q.active or S.busy
    if not pending and idle>=30 and S.screen~="welcome" then
      S.category=nil; S.item=nil; S.selected={}; S.quantity=1; go("welcome"); render()
    elseif pending and idle>=60 and S.screen~="queue" then
      openQueue(); render()
    end
    updatePulse(); drawJob()
    pulseTimer=os.startTimer(0.2)
  elseif event=="timer" and name==timer then
    refreshStock(); render(); timer=os.startTimer(C.pollSeconds)
  elseif event=="monitor_resize" or event=="peripheral" or event=="peripheral_detach" then
    connect(); refreshStock(); os.queueEvent("gear_cast_stock_refresh"); updatePulse(); render()
  end
  flushDisplays()
end
end
parallel.waitForAny(uiLoop,castWorker,castStockWorker)
