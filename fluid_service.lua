-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"fluid_service","title":"Shared Fluid Service","launchable":false,"description":"Serial fluid transfers, durable request receipts and Gear queue protection."}
return function(root,c)
 local T={busy=false,holds={},last="Ready"}
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
  if localRequest then owner,major,minor=id:match("^monitor:(%d+):(%d+):(%d+)$")
  else owner,major,minor=id:match("^(%d+):(%d+):(%d+)$") end
  assert(tonumber(owner)==sender and major and minor,"Invalid transfer request identity")
  return tostring(sender)..(localRequest and ":monitor" or ":gear"),tonumber(major),tonumber(minor)
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
 local targets={}
 for _,name in ipairs(c.destinations or {}) do targets[name]=true end
 for _,name in pairs(c.outputs or {}) do if name~="" then assert(not targets[name] and not sources[name],"Fluid Monitor outputs must be separate from Gear tables/storage");targets[name]="local" end end
 function T.stock()
  assert(next(sources),"No fluid storage assigned in Network Setup")
  local totals={}
  for source in pairs(sources) do
   for _,tank in pairs(peripheral.call(source,"tanks")) do
    if tank.name and (tank.amount or 0)>0 then totals[tank.name]=(totals[tank.name] or 0)+tank.amount end
   end
  end
  local rows={}
  for fluid,amount in pairs(totals) do rows[#rows+1]={name=fluid,amount=amount} end
  table.sort(rows,function(a,b) return a.name<b.name end)
  return rows
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
   local hold=T.holds[client]
   if not hold or os.clock()-hold.at>15 then return false,"Waiting for Gear queue heartbeat from computer "..client end
  end
  return true
 end
 function T.transfer(sender,id,args,localRequest)
  assert(type(id)=="string" and #id<=160 and type(args)=="table","Invalid transfer request")
  assert(type(args.target)=="string" and type(args.fluid)=="string" and integer(args.amount) and args.amount>0 and args.amount<=1000000,"Invalid fluid, destination or amount")
  assert(not sources[args.target],"Cannot send fluid back into a configured source")
  assert(localRequest and targets[args.target]=="local" or not localRequest and targets[args.target]==true,"Destination is not assigned to this application")
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
  assert(not T.busy,"Fluid service busy; retry after the current transfer")
  assert(not T.fault,T.fault)
  assert(#T.uncertain()==0,"Uncertain fluid transfer; inspect the Fluid Monitor Utilities report")
  if localRequest then local ready,reason=T.readyForLocal();assert(ready,reason) end
  T.busy=true
  local started=false
  local ok,result=pcall(function()
   local available=0
   for _,tank in ipairs(T.stock()) do if tank.name==args.fluid then available=tank.amount end end
   if localRequest then available=math.max(0,available-T.reserved(args.fluid)-(c.keepMb or 0)) end
   assert(available>=args.amount,"Not Enough Fluid: need "..args.amount.." mB of "..args.fluid.."; Gear reservations are protected")
   while #state.order>=64 do
    local oldest=table.remove(state.order,1);state.records[oldest]=nil
   end
   local entry={target=args.target,fluid=args.fluid,amount=args.amount,moved=0,status="started"}
   state.records[key]=entry;state.order[#state.order+1]=key
   state.highwater[family]={major=major,minor=minor};started=true;save()
   T.progress={moved=0,requested=args.amount,target=args.target,at=os.clock()}
   os.queueEvent("fluid_status")
   for source in pairs(sources) do
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
 function T.handle(sender,message)
  assert(type(message)=="table" and message.version==1 and type(message.id)=="string","Invalid service message")
  assert(knownClient(sender),"Gear computer is not assigned in Network Setup")
  if message.method=="info" then return {monitors=c.monitors or {},outputs=c.outputs or {},computerId=os.getComputerID()} end
  if message.method=="stock" then return T.stock() end
  if message.method=="reserve" then
   local demand=message.args and message.args.demand;assert(type(demand)=="table","Invalid queue reservation")
   local clean={};local count=0
   for fluid,amount in pairs(demand) do count=count+1;assert(count<=256 and type(fluid)=="string" and integer(amount),"Invalid queue demand");clean[fluid]=amount end
   T.holds[sender]={demand=clean,at=os.clock()};return true
  end
  if message.method=="pour" then return T.transfer(sender,message.id,message.args,false) end
  error("Unknown fluid-service method")
 end
 return T
end
