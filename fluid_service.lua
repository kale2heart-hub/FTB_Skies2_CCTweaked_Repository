-- @crafting-center {"version":"1.3.1","suite":"crafting-center","id":"fluid_service","title":"Shared Fluid Service","launchable":false,"description":"Serial fluid transfers, durable request receipts and Gear queue protection."}
return function(root,c)
 local T={busy=false,holds={},registrations={},last="Ready"}
 local path=fs.combine(root,"fluid_transfers.txt")
 local state={records={},order={}}
 local function read(p)
  local f=assert(fs.open(p,"r"));local s=textutils.unserialize(f.readAll());f.close()
  assert(type(s)=="table" and type(s.records)=="table" and type(s.order)=="table","Unreadable fluid transfer log; inspect "..p)
  return s
 end
 if fs.exists(path..".pending") then state=read(path..".pending") elseif fs.exists(path) then state=read(path) end
 state.highwater=state.highwater or {}
 local function sequence(sender,id,localRequest)
  local owner,major,minor
  if localRequest=="refill" then owner,major,minor=id:match("^refill:(%d+):(%d+):(%d+)$")
  elseif localRequest then
   if id:sub(1,6)=="basin:" then owner,major,minor=id:match("^basin:(%d+):(%d+):(%d+)$")
   else owner,major,minor=id:match("^monitor:(%d+):(%d+):(%d+)$") end
  else owner,major,minor=id:match("^(%d+):(%d+):(%d+)$") end
  assert(tonumber(owner)==sender and major and minor,"Invalid transfer request identity")
  return tostring(sender)..(localRequest=="refill" and ":refill" or localRequest and (id:sub(1,6)=="basin:" and ":basin" or ":monitor") or ":gear"),tonumber(major),tonumber(minor)
 end
 local function save()
  local f=assert(fs.open(path..".pending","w"));f.write(textutils.serialize(state));f.close()
  read(path..".pending")
  if fs.exists(path) then fs.delete(path) end
  fs.move(path..".pending",path)
 end
 local function integer(n) return type(n)=="number" and n==math.floor(n) and n>=0 and n<=1000000000 end
 local function knownClient(id)
  for _,client in ipairs(c.clients or {}) do if client==id then return true end end
  return false
 end
 local sources={}
 for _,name in ipairs(c.sources or {}) do assert(not sources[name],"Duplicate fluid source");sources[name]=true end
 local gearSources={}
 for _,name in ipairs(c.gearSources or {}) do
  assert(not sources[name] and not gearSources[name],"Gear-only storage must be separate from main storage and listed once: "..name)
  gearSources[name]=true
 end
 local dedicated=next(gearSources)~=nil
 local targets={}
 if not c.assignmentExchange then
  for _,name in ipairs(c.destinations or {}) do assert(not sources[name] and not gearSources[name],"Gear station overlaps fluid storage: "..name);targets[name]=true end
 end
 for _,name in ipairs(c.basins or {}) do
  assert(not targets[name] and not sources[name] and not gearSources[name],"Managed basins must be separate from Gear tables/storage and listed once")
  targets[name]="local"
 end
 if c.blockOutputChest then assert(not targets[c.blockOutputChest] and not sources[c.blockOutputChest] and not gearSources[c.blockOutputChest],"Block output chest overlaps a fluid source or casting destination") end
 local function readStock(pool)
  assert(next(pool),"No fluid storage assigned in Network Setup")
  local totals={}
  for source in pairs(pool) do
   for _,tank in pairs(peripheral.call(source,"tanks")) do
    if tank.name and (tank.amount or 0)>0 then totals[tank.name]=(totals[tank.name] or 0)+tank.amount end
   end
  end
  local rows={}
  for fluid,amount in pairs(totals) do rows[#rows+1]={name=fluid,amount=amount} end
  table.sort(rows,function(a,b) return a.name<b.name end)
  return rows
 end
 function T.info()
  local outputs={};for i,name in ipairs(c.basins or {}) do outputs["Basin"..i]=name end
  return {monitors=c.monitors or {},outputs=outputs,basins=c.basins or {},computerId=os.getComputerID(),assignmentExchange=true}
 end
 function T.register(sender,layout)
  assert(knownClient(sender),"Gear computer is not assigned in Network Setup")
  assert(type(layout)=="table","Gear device assignments missing")
  local mine={}
  local function add(name,owner) if type(name)=="string" and name~="" then mine[name]=owner end end
  for _,name in ipairs(c.monitors or {}) do add(name,"Fluid monitor") end
  for name in pairs(sources) do add(name,"main fluid storage") end
  for name in pairs(gearSources) do add(name,"Gear-only fluid storage managed by Fluid") end
  for _,name in ipairs(c.basins or {}) do add(name,"Fluid block basin") end
  add(c.blockOutputChest,"Fluid block output chest")
  for client,entry in pairs(T.registrations) do if client~=sender then
   for name in pairs(entry.claims) do add(name,"Gear computer "..client) end
  end end
  local record={claims={},destinations={}}
  for _,field in ipairs({"monitors","destinations","inventories"}) do
   local list=layout[field] or {};assert(type(list)=="table" and #list<=512,"Invalid Gear "..field)
   for _,name in ipairs(list) do
    assert(type(name)=="string" and #name>0 and #name<=160,"Invalid Gear peripheral name")
    assert(not mine[name],"Device conflict: "..name.." belongs to "..tostring(mine[name])..". Change the assignment on its owning computer.")
    assert(not record.claims[name],"Duplicate Gear device assignment: "..name)
    record.claims[name]=field
    if field=="destinations" then record.destinations[name]=true end
   end
  end
  assert(next(record.destinations),"No Gear casting stations were announced")
  T.registrations[sender]=record
  return T.info()
 end
 function T.stock() return readStock(sources) end
 function T.gearStock() return readStock(dedicated and gearSources or sources) end
 function T.hasGearStore() return dedicated end
 function T.minimum(fluid)
  local value=(c.gearMinimums or {})[fluid]
  return value~=nil and value or (c.gearMinimumDefault==nil and 10000 or c.gearMinimumDefault)
 end
 function T.gearStatus()
  if not dedicated then return {} end
  local rows={}
  local function add(fluid)
   if fluid:find(":molten_",1,true) then rows[fluid]=rows[fluid] or {name=fluid,amount=0,main=0} end
  end
  for _,tank in ipairs(T.stock()) do add(tank.name);if rows[tank.name] then rows[tank.name].main=tank.amount end end
  for _,tank in ipairs(T.gearStock()) do add(tank.name);if rows[tank.name] then rows[tank.name].amount=tank.amount end end
  for fluid in pairs(c.gearMinimums or {}) do add(fluid) end
  local result={}
  for fluid,row in pairs(rows) do
   row.minimum=T.minimum(fluid);row.goal=math.max(row.minimum,T.reserved(fluid));row.deficit=math.max(0,row.goal-row.amount)
   result[#result+1]=row
  end
  table.sort(result,function(a,b) return a.name<b.name end);return result
 end
 function T.blockAvailable(fluid,mainAmount)
  local protected=T.reserved(fluid)
  if dedicated then
   local amount=0;for _,tank in ipairs(T.gearStock()) do if tank.name==fluid then amount=tank.amount end end
   protected=math.max(0,math.max(T.minimum(fluid),protected)-amount)
  end
  return math.max(0,mainAmount-protected-(c.keepMb or 0))
 end
 function T.uncertain()
  local result={}
  for id,entry in pairs(state.records) do if entry.status~="done" and entry.status~="acknowledged" then result[#result+1]={id=id,target=entry.target,fluid=entry.fluid,amount=entry.amount,moved=entry.moved or 0} end end
  table.sort(result,function(a,b) return a.id<b.id end);return result
 end
 function T.acknowledge()
  assert(not T.busy,"Wait for current transfer")
  for _,entry in pairs(state.records) do if entry.status=="started" then entry.status="acknowledged" end end
  save();T.fault=nil;T.last="Transfer issues acknowledged; no fluid was moved"
 end
 function T.reserved(fluid)
  local amount=0
  for _,hold in pairs(T.holds) do amount=amount+(hold.demand[fluid] or 0) end
  return amount
 end
 function T.readyForLocal()
  for _,client in ipairs(c.clients or {}) do
   if c.assignmentExchange and not T.registrations[client] then return false,"Waiting for Gear device assignments from computer "..client end
   local hold=T.holds[client]
   if not hold or os.clock()-hold.at>15 then return false,"Waiting for Gear queue heartbeat from computer "..client end
  end
  return true
 end
 function T.transfer(sender,id,args,localRequest)
  assert(type(id)=="string" and #id<=160 and type(args)=="table","Invalid transfer request")
  assert(type(args.target)=="string" and type(args.fluid)=="string" and integer(args.amount) and args.amount>0 and args.amount<=1000000,"Invalid fluid, destination or amount")
  local refill=localRequest=="refill"
  assert(not sources[args.target],"Cannot send fluid back into main storage")
  local registered=T.registrations[sender]
  local allowedGear=c.assignmentExchange and registered and registered.destinations[args.target] or not c.assignmentExchange and targets[args.target]==true
  assert(refill and gearSources[args.target] or localRequest==true and targets[args.target]=="local" or not localRequest and allowedGear,"Destination is not assigned to this application; Gear must announce its current stations")
  if localRequest==true then T.refill(args.fluid) end
  local key=tostring(sender).."|"..id
  local previous=state.records[key]
  if previous then
   assert(previous.target==args.target and previous.fluid==args.fluid and previous.amount==args.amount,"Request ID reused with different arguments")
   assert(previous.status=="done","Uncertain previous transfer to "..args.target.."; inspect output and acknowledge in Fluid Monitor Utilities")
   return {moved=previous.moved,error=previous.error}
  end
  local family,major,minor=sequence(sender,id,localRequest)
  local watermark=state.highwater[family]
  assert(not watermark or major>watermark.major or major==watermark.major and minor>watermark.minor,"Receipt expired or request is older than a completed transfer; inspect destination instead of resending")
  local waitUntil=os.clock()+5
  while T.busy do
   assert(os.clock()<waitUntil,"Fluid service busy; retry after the current transfer")
   sleep(.05)
  end
  assert(not T.fault,T.fault)
  assert(#T.uncertain()==0,"Uncertain fluid transfer; inspect the Fluid Monitor Utilities report")
  if localRequest==true then local ready,reason=T.readyForLocal();assert(ready,reason) end
  T.busy=true
  local started=false
  local ok,result=pcall(function()
   local pool=not localRequest and dedicated and gearSources or sources
   local available=0
   for _,tank in ipairs(readStock(pool)) do if tank.name==args.fluid then available=tank.amount end end
   if localRequest==true then available=T.blockAvailable(args.fluid,available) end
   assert(available>=args.amount,"Not Enough Fluid: need "..args.amount.." mB of "..args.fluid.."; Gear reservations are protected")
   while #state.order>=64 do
    local oldest=table.remove(state.order,1);state.records[oldest]=nil
   end
   local entry={target=args.target,fluid=args.fluid,amount=args.amount,moved=0,status="started",pool=refill and "refill" or localRequest and "main" or dedicated and "gear" or "main"}
   state.records[key]=entry;state.order[#state.order+1]=key
   state.highwater[family]={major=major,minor=minor};started=true;save()
   T.progress={moved=0,requested=args.amount,target=args.target,at=os.clock()}
   os.queueEvent("fluid_status")
   for source in pairs(pool) do
    if entry.moved>=args.amount then break end
    local count=peripheral.call(source,"pushFluid",args.target,args.amount-entry.moved,args.fluid)
    assert(integer(count) and count<=args.amount-entry.moved,"Uncertain fluid transfer result")
    entry.moved=entry.moved+count
    T.progress.moved=entry.moved;T.progress.at=os.clock()
    os.queueEvent("fluid_status")
    save()
   end
   entry.status="done"
   if entry.moved~=args.amount then entry.error="Partial fluid transfer: "..entry.moved.." / "..args.amount.." mB" end
   save();T.progress.completed=true;T.progress.at=os.clock();T.last="Sent "..entry.moved.." mB to "..args.target
   return {moved=entry.moved,error=entry.error}
  end)
  T.busy=false
  if not ok then
   T.last=tostring(result)
   if started then T.fault="Uncertain fluid transfer; inspect destination and acknowledge in Utilities" end
   error(result,0)
  end
  return result
 end
 function T.refill(filter)
  if not dedicated or T.busy or T.refilling or T.fault or #T.uncertain()>0 then return 0 end
  T.refilling=true
  local ok,result=pcall(function()
  local total=0;local blocked
  for _,row in ipairs(T.gearStatus()) do
   if (not filter or row.name==filter) and row.deficit>0 and row.main>0 then
    local need=math.min(row.deficit,row.main)
    for _,target in ipairs(c.gearSources) do
     if need<=0 then break end
     state.refillSeq=(state.refillSeq or 0)+1
     local result=T.transfer(os.getComputerID(),"refill:"..os.getComputerID()..":"..state.refillSeq..":1",{target=target,fluid=row.name,amount=math.min(1000000,need)},"refill")
     need=need-result.moved;total=total+result.moved
     sleep(0) -- Let waiting Gear requests run between refill pours.
    end
    if need>0 then blocked="Gear refill blocked: "..row.name.." ("..need.." mB short); check Gear storage filters/capacity" end
   end
  end
  T.refillStatus=blocked or (total>0 and ("Refilled Gear storage: "..total.." mB") or "Gear stock checked")
  return total
  end)
  T.refilling=false
  if not ok then error(result,0) end
  return result
 end
 function T.handle(sender,message)
  assert(type(message)=="table" and message.version==1 and type(message.id)=="string","Invalid service message")
  assert(knownClient(sender),"Gear computer is not assigned in Network Setup")
  if message.method=="info" then return T.info() end
  if message.method=="register" then return T.register(sender,message.args and message.args.layout) end
  if message.method=="stock" then return T.gearStock() end
  if message.method=="reserve" then
   if message.args and message.args.layout then T.register(sender,message.args.layout) end
   assert(not c.assignmentExchange or T.registrations[sender],"Gear must announce device assignments before reserving fluids")
   local demand=message.args and message.args.demand;assert(type(demand)=="table","Invalid queue reservation")
   local clean={};local count=0
   for fluid,amount in pairs(demand) do count=count+1;assert(count<=256 and type(fluid)=="string" and integer(amount),"Invalid queue demand");clean[fluid]=amount end
   T.holds[sender]={demand=clean,at=os.clock()};return {reserved=true,registered=T.registrations[sender]~=nil}
  end
  if message.method=="pour" then return T.transfer(sender,message.id,message.args,false) end
  error("Unknown fluid-service method")
 end
 return T
end
