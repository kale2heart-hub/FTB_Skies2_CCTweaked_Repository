-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"basin_casting","title":"Managed Block Basins","launchable":false,"description":"Persistent one-block pours, cooling and verified block output collection."}
return function(c,service)
 local T={}
 local function inspect(name)
  local items=peripheral.call(name,"list")
  local fluid,amount=nil,0
  for _,tank in pairs(peripheral.call(name,"tanks")) do
   if (tank.amount or 0)>0 then
    assert(not fluid or fluid==tank.name,"Mixed fluid in basin "..name)
    fluid=tank.name;amount=amount+tank.amount
   end
  end
  return items,fluid,amount
 end
 local function output(job,item)
  if not item then return false end
  for _,id in ipairs(job.outputs or {}) do if item.name==id then return true end end
  return false
 end
 local function now() return os.epoch("utc")/1000 end
 local function status(phase,unit,job)
  local elapsed=unit and unit.started and now()-unit.started or 0
  T.progress={phase=phase,basin=unit and unit.basin,moved=phase=="cooling" and math.min(1,elapsed/3) or phase=="completed" and 1 or 0,
   completed=job.completed or 0,quantity=job.quantity,at=os.clock()}
  service.last=phase=="completed" and ("Completed "..T.progress.completed.." / "..job.quantity.." blocks") or
   (phase.." block "..((job.completed or 0)+1).." / "..job.quantity.." at "..tostring(unit and unit.basin))
  os.queueEvent("fluid_status")
 end
 local function account(job,basin,save)
  job.units[basin]=nil;job.completed=(job.completed or 0)+1
  job.remaining=math.max(0,(job.quantity-job.completed)*job.amount)
  save();status("completed",{basin=basin},job)
 end
 function T.active(job) local n=0;for _ in pairs(job.units or {}) do n=n+1 end;return n end
 function T.tick(job,save)
  assert(job.mode=="basin_blocks","Legacy buffer job; cancel it before using managed basins")
  assert(type(c.blockOutputChest)=="string" and c.blockOutputChest~="","Assign the block output chest in Network Setup")
  assert(#(c.basins or {})>0,"Assign casting basins in Network Setup")
  job.units=job.units or {};job.completed=job.completed or 0
  local configured={};for _,basin in ipairs(c.basins) do configured[basin]=true end
  for basin in pairs(job.units) do assert(configured[basin],"Active basin removed from configuration: "..basin) end
  -- Recover existing units before assigning another block. Never repeat a pour with a new ID after an uncertain result.
  for _,basin in ipairs(c.basins) do
   local unit=job.units[basin]
   if unit then
    if unit.phase=="delivery_started" then error("Uncertain item extraction at "..basin..". Inspect output chest; resolve through Utilities before Resume",0) end
    if unit.phase=="pouring" then
     local result=service.transfer(os.getComputerID(),unit.request.id,{target=basin,fluid=job.fluid,amount=unit.request.amount},true)
     unit.phase="partial";unit.moved=(unit.moved or 0)+result.moved;unit.request=nil
     if unit.moved==job.amount then unit.phase="cooling";unit.started=now() end
     save()
     if unit.phase=="partial" then error("Partial block pour at "..basin..": "..unit.moved.." / "..job.amount.." mB. Resume rechecks basin contents",0) end
    end
    local items,fluid,amount=inspect(basin)
    local item=items[1]
    if item and not output(job,item) then error("Wrong block at "..basin..": "..item.name.."; expected "..table.concat(job.outputs or {},", "),0) end
    if fluid and fluid~=job.fluid then error("Wrong fluid at "..basin..": "..fluid,0) end
    if unit.phase=="partial" then
     if item and amount==0 then unit.phase="waiting_output";save()
     else
      assert(amount==unit.moved,"Basin contents changed at "..basin.."; inspect before retrying")
      assert(unit.moved<job.amount,"Unexpected basin amount at "..basin)
      assert((unit.attempts or 0)<8,"Pour limit reached at "..basin.."; inspect recipe/cast")
      job.attempt=(job.attempt or 0)+1;unit.attempts=(unit.attempts or 0)+1
      unit.phase="pouring";unit.request={id="monitor:"..os.getComputerID()..":"..job.id..":"..job.attempt,amount=job.amount-unit.moved};save()
      status("pouring",unit,job)
      -- The durable service receipt measures this exact remainder, including after restart.
      local result=service.transfer(os.getComputerID(),unit.request.id,{target=basin,fluid=job.fluid,amount=unit.request.amount},true)
      unit.moved=unit.moved+result.moved;unit.request=nil
      unit.phase=unit.moved==job.amount and "cooling" or "partial";unit.started=now();save()
      if unit.phase=="partial" then error("Partial block pour at "..basin..": "..unit.moved.." / "..job.amount.." mB; inspect and Resume",0) end
     end
    end
    if unit.phase=="cooling" then
     status("cooling",unit,job)
     if now()-unit.started>=3 then
      if item and amount==0 then unit.phase="waiting_output";save()
      elseif now()-unit.started>=15 then error("Basin did not finish casting at "..basin.." after 15 seconds; fluid "..amount.." mB. No extra fluid sent",0) end
     end
    end
    if unit.phase=="waiting_output" then
     assert(item and output(job,item) and amount==0,"Block missing or basin still contains fluid at "..basin)
     assert(item.count==1,"Unexpected output count at "..basin.."; inspect basin")
     status("transferring",unit,job)
     unit.phase="delivery_started";save()
     local moved=peripheral.call(basin,"pushItems",c.blockOutputChest,1,1)
     assert(moved==0 or moved==1,"Uncertain item transfer at "..basin)
     if moved==0 then unit.phase="waiting_output";save();error("Block output chest blocked; block left in basin "..basin..". Make room, then Resume",0) end
     account(job,basin,save)
    end
   end
  end
  if job.completed>=job.quantity then return true end
  -- Fill each idle assigned basin with one whole block, allowing their cooling cycles to overlap.
  local assigned=false;local firstProblem
  for _,basin in ipairs(c.basins) do
   if job.completed+T.active(job)>=job.quantity then break end
   if not job.units[basin] then
    local ok,items,_,amount=pcall(inspect,basin)
    if ok and not next(items) and amount==0 then
     local unit={basin=basin,phase="partial",moved=0,attempts=0}
     job.units[basin]=unit;save();assigned=true
    elseif not firstProblem then firstProblem=ok and ("Basin occupied: "..basin.."; inspect before assigning") or tostring(items) end
   end
  end
  assert(T.active(job)>0 or assigned,firstProblem or "No free assigned basin")
  return false
 end
 function T.resolve(job,save,confirmEmptyDelivered)
  assert(job and job.mode=="basin_blocks","No managed basin job to inspect")
  for basin,unit in pairs(job.units or {}) do
   local items,fluid,amount=inspect(basin);local item=items[1]
   assert(not item or output(job,item),"Wrong block still present at "..basin)
   assert(not fluid or fluid==job.fluid,"Wrong fluid still present at "..basin)
   if not item and amount==0 and confirmEmptyDelivered=="retry" then
    job.units[basin]=nil;save()
   elseif not item and amount==0 and confirmEmptyDelivered==true then
    assert(unit.phase=="delivery_started" or unit.phase=="pouring" or (unit.moved or 0)>=job.amount,"No prior block pour recorded at "..basin.."; choose Retry instead")
    account(job,basin,save)
   elseif unit.phase=="delivery_started" then
    if item and amount==0 then unit.phase="waiting_output";save()
    elseif not item and amount==0 and confirmEmptyDelivered then account(job,basin,save)
    else error("Confirm delivered output for empty basin "..basin.." only after checking the output chest",0) end
   elseif unit.phase=="pouring" then
    -- Explicit operator acknowledgment reconciles physical contents; never assume an empty basin delivered a block.
    if item and amount==0 then unit.phase="waiting_output";unit.request=nil;save()
    elseif amount>0 and amount<=job.amount then
     unit.moved=amount;unit.request=nil;unit.phase=amount==job.amount and "cooling" or "partial";unit.started=now();save()
    else error("Uncertain pour at empty basin "..basin.."; inspect and remove this job manually before retrying",0) end
   end
  end
 end
 return T
end
