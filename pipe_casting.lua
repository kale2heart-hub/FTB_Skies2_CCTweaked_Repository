-- @crafting-center {"version":"1.0.2","suite":"crafting-center","id":"pipe_casting","title":"Pipez Basin Casting","launchable":false,"description":"Single-material tank batches, item collection and bounded stalled-fluid recovery."}
return function(c,service)
 local T={}
 local function now() return os.epoch("utc")/1000 end
 local function fluidAt(name)
  local fluid,amount=nil,0
  local tanks=peripheral.call(name,"tanks")
  if tanks==nil then tanks={} end
  assert(type(tanks)=="table","Invalid fluid inventory from "..name)
  for _,tank in pairs(tanks) do
   if (tank.amount or 0)>0 then
    assert(not fluid or fluid==tank.name,"Mixed fluids at "..name)
    fluid=tank.name;amount=amount+tank.amount
   end
  end
  return fluid,amount
 end
 local function read(name)
  local fluid,amount=fluidAt(name)
  local items=peripheral.call(name,"list")
  if items==nil then items={} end
  assert(type(items)=="table","Invalid item inventory from basin "..name)
  return {items=items,fluid=fluid,amount=amount}
 end
 local function scan()
  local rows={};local index=0;local workers={}
  for i=1,math.min(8,#c.basins) do workers[i]=function()
   while true do
    index=index+1;local name=c.basins[index];if not name then return end
    local ok,result=pcall(read,name);rows[name]=ok and result or {error=tostring(result)}
   end
  end end
  if parallel and parallel.waitForAll then parallel.waitForAll(table.unpack(workers)) else for _,worker in ipairs(workers) do worker() end end
  return rows
 end
 local function matches(job,item)
  if not item then return false end
  for _,id in ipairs(job.outputs) do if item.name==id then return true end end
  return false
 end
 local function net(p) return p.fed+p.topped-p.returned end
 local function changed(p) p.lastProgress=now() end
 local function addFeed(job,save,token)
  local p=job.pipe
  local result=service.transfer(os.getComputerID(),p.feed.id,{target=p.tank,fluid=job.fluid,amount=p.feed.amount},true)
  p.fed=p.fed+result.moved;p.feed=nil
  if result.moved>0 then p.feedZeros=0;changed(p) else p.feedZeros=(p.feedZeros or 0)+1 end
  save();assert((p.feedZeros or 0)<8,"Casting Fluid Tank rejected eight transfers; inspect filters/capacity: "..p.tank)
 end
 local function recover(job,name,unit,row,save,token)
  local p=job.pipe
  if unit.returnRequest then
   local request=unit.returnRequest
   local result=service.returnFluid(request.id,name,job.fluid,request.amount)
   p.returned=p.returned+result.moved;unit.returnRequest=nil
   if result.moved>0 then changed(p) end
   save();row=read(name)
  end
  if unit.topup then
   local request=unit.topup
   local result=service.transfer(os.getComputerID(),request.id,{target=name,fluid=job.fluid,amount=request.amount},true)
   p.topped=p.topped+result.moved;unit.topup=nil;unit.recoveryAt=now();changed(p);save();row=read(name)
  end
  assert(not row.fluid or row.fluid==job.fluid,"Wrong fluid in basin "..name)
  if row.amount==0 then return row end
  if now()-(unit.firstFluid or now())<10 or unit.recoveryAt and now()-unit.recoveryAt<3 then return row end
  local attempts=p.recoveries[name] or 0
  assert(attempts<3,"Recovery limit reached at "..name.."; inspect Pipez routing and basin recipe")
  p.recoveries[name]=attempts+1
  unit.returnRequest={id=token("return"),amount=row.amount};unit.recoveryAt=now();save()
  local result=service.returnFluid(unit.returnRequest.id,name,job.fluid,row.amount)
  p.returned=p.returned+result.moved;unit.returnRequest=nil
  if result.moved>0 then changed(p) end
  save();row=read(name)
  if row.amount>0 and not row.items[1] then
   assert(row.fluid==job.fluid and row.amount<=job.amount,"Cannot safely top up basin "..name.."; unexpected fluid/volume")
   local missing=job.amount-row.amount
   if missing>0 then
    unit.topup={id=token(),amount=missing};save()
    local added=service.transfer(os.getComputerID(),unit.topup.id,{target=name,fluid=job.fluid,amount=missing},true)
    p.topped=p.topped+added.moved;unit.topup=nil;changed(p);save()
   end
   unit.recoveryAt=now();save()
  end
  return row
 end
 function T.step(job,save,token)
  assert(c.castingFluidTank and #(c.basins or {})>0 and c.blockOutputChest,"Assign Casting Fluid Tank, basins and block output chest")
  local rows=scan();local tankFluid,tankAmount=fluidAt(c.castingFluidTank)
  if not job.pipe then
   assert(tankAmount==0,"Casting Fluid Tank must be empty before a new material starts")
   for _,name in ipairs(c.basins) do
    local row=rows[name];assert(not row.error,row.error)
    assert(not next(row.items) and row.amount==0,"Unassigned contents in basin "..name.."; inspect before starting Pipez casting")
   end
   job.pipe={tank=c.castingFluidTank,baseCompleted=job.completed or 0,fed=0,topped=0,returned=0,lastProgress=now(),recoveries={}}
   job.units={};save()
  end
  local p=job.pipe
  assert(p.tank==c.castingFluidTank,"Casting Fluid Tank changed during an active job")
  assert(not tankFluid or tankFluid==job.fluid,"Wrong material in Casting Fluid Tank; do not mix queue materials")
  if p.feed then addFeed(job,save,token);tankFluid,tankAmount=fluidAt(p.tank) end
  local occupied=false
  for _,name in ipairs(c.basins) do
   local row=rows[name];assert(not row.error,row.error)
   assert(not row.fluid or row.fluid==job.fluid,"Wrong fluid in basin "..name.."; inspect Pipez connections")
   local unit=job.units[name]
   if row.amount>0 or next(row.items) or unit then
    occupied=true
    if not unit then unit={phase="pipe_wait",firstFluid=row.amount>0 and now() or nil};job.units[name]=unit;save() end
    if unit.phase=="delivery_started" then error("Uncertain block extraction at "..name.."; inspect output chest and resolve in Utilities",0) end
    if row.amount>0 and not unit.firstFluid then unit.firstFluid=now();save() end
    if row.amount>=job.amount and not unit.fullAt then unit.fullAt=now();save() end
    row=recover(job,name,unit,row,save,token)
    local item=row.items[1]
    if item then
     assert(matches(job,item) and item.count==1,"Wrong block at "..name..": "..tostring(item.name))
     if not unit.itemSeen then unit.itemSeen=unit.fullAt or now();save() end
     if now()-unit.itemSeen>=3 then
      unit.extractSince=unit.extractSince or now();unit.phase="delivery_started";save()
      local moved=peripheral.call(name,"pushItems",c.blockOutputChest,1,1)
      assert(moved==0 or moved==1,"Uncertain block transfer at "..name)
      unit.phase="pipe_wait"
      if moved==1 then
       job.completed=(job.completed or 0)+1;job.remaining=math.max(0,(job.quantity-job.completed)*job.amount)
       p.recoveries[name]=nil;unit.recoveryAt=nil
       unit.itemSeen=nil;unit.firstFluid=nil;unit.fullAt=nil;unit.extractSince=nil;changed(p)
      end
      save()
      assert(moved==1 or row.amount>0 or now()-unit.extractSince<5,"Cannot extract block at "..name.."; check output chest/cooling, then Resume")
     end
    elseif row.amount==0 and not unit.returnRequest and not unit.topup then job.units[name]=nil;save() end
   end
  end
  -- Never put another material into the shared pipe while any previous basin is occupied.
  tankFluid,tankAmount=fluidAt(p.tank)
  if p.lastTankAmount~=tankAmount then p.lastTankAmount=tankAmount;p.tankChanged=now();save() end
  assert(tankAmount==0 or now()-(p.tankChanged or now())<30,"Pipez is not emptying Casting Fluid Tank: "..p.tank)
  local committed=net(p)
  local desired=(job.quantity-p.baseCompleted)*job.amount
  if not p.cancelled and committed<desired and tankAmount==0 then
   local available=0
   for _,row in ipairs(service.stock()) do if row.name==job.fluid then available=service.blockAvailable(job.fluid,row.amount) end end
   if available>0 then
    p.feed={id=token(),amount=math.min(c.castingFluidTankCapacity or 55300000,desired-committed,available)};save();addFeed(job,save,token)
    tankAmount=select(2,fluidAt(p.tank))
   elseif not occupied then error("Not Enough Fluid for Pipez casting: "..job.fluid,0) end
  end
  local active=next(job.units)~=nil
  local allDone=(job.completed>=job.quantity or p.cancelled) and tankAmount==0 and not active and not p.feed
  if allDone then
   local remaining=net(p)-(job.completed-p.baseCompleted)*job.amount
   assert(remaining==0,"Unaccounted Pipez fluid: "..remaining.." mB; inspect piping/unmanaged destinations")
   if job.completed>job.quantity and not p.extraReported then
    p.extraReported=true;save();error("Recovery delivered "..(job.completed-job.quantity).." extra blocks; inspect output, then Resume to continue",0)
   end
  elseif tankAmount==0 and not active and net(p)>=(job.completed-p.baseCompleted)*job.amount+1 then
   assert(now()-p.lastProgress<10,"Pipez fluid not found in assigned basins; inspect routing before retrying")
  end
  T.progress={phase=allDone and "completed" or "Pipez casting",moved=math.min(1,(job.completed or 0)/job.quantity),completed=job.completed or 0,quantity=job.quantity,at=os.clock()}
  service.last=(allDone and "Completed " or "Pipez casting ")..(job.completed or 0).." / "..job.quantity.." blocks"
  os.queueEvent("fluid_status")
  return allDone
 end
 function T.resolve(job,save,mode)
  local p=assert(job.pipe,"No active Pipez job")
  local uncertain=p.feed~=nil
  for _,unit in pairs(job.units) do if unit.returnRequest or unit.topup then uncertain=true end end
  assert(not uncertain or mode,"Uncertain Pipez fluid operation; inspect tank/basins and choose an explicit recovery action")
  local rows=scan();local fluid,amount=fluidAt(p.tank)
  assert(not fluid or fluid==job.fluid,"Wrong fluid in Casting Fluid Tank")
  local present=amount
  for _,name in ipairs(c.basins) do
   local row=rows[name];assert(not row.error,row.error)
   assert(not row.fluid or row.fluid==job.fluid,"Wrong fluid at "..name)
   local unit=job.units[name];local item=row.items[1]
   if item then assert(matches(job,item),"Wrong block at "..name);present=present+job.amount end
   present=present+row.amount
   if unit and unit.phase=="delivery_started" and not item then
    assert(mode==true or mode=="retry","Confirm already-delivered output or explicitly retry empty basin "..name)
    if mode==true then job.completed=job.completed+1;job.remaining=math.max(0,(job.quantity-job.completed)*job.amount) end
   end
   if unit then unit.phase="pipe_wait";unit.returnRequest=nil;unit.topup=nil;unit.itemSeen=nil end
  end
  if uncertain or mode then
   assert(mode,"Uncertain Pipez feed; inspect tank/basins and choose an explicit recovery action")
   p.fed=present+(job.completed-p.baseCompleted)*job.amount;p.topped=0;p.returned=0;p.feed=nil
  end
  p.recoveries={};changed(p);save()
 end
 return T
end
