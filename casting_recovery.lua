-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"casting_recovery","title":"Casting Recovery","launchable":false,"description":"Bounded 100 mB table recovery after a transfer timeout."}
return function(batch,journal,env)
 local call,save=env.call,env.save
 local target=journal.table
 local maxAttempts=20
 local maxSeconds=90
 if journal.status=="recovery_needs_fluid" then
  journal.recoveryStarted=os.epoch("utc");journal.recoveryFluid=nil
 end
 journal.recoveryStarted=journal.recoveryStarted or os.epoch("utc")
 journal.recoveryAttempts=journal.recoveryAttempts or 0
 if journal.status=="recovery_pour_started" then error("Uncertain recovery pour; inspect "..env.location(target),0) end
 if journal.status=="recovery_cooling" then env.sleep(3) end
 while true do
  local item=call(target,"list")[1]
  local fluidName,amount=nil,0
  for _,tank in pairs(call(target,"tanks")) do
   if (tank.amount or 0)>0 then
    if fluidName and fluidName~=tank.name then error("Multiple fluids at "..env.location(target).."; inspection required",0) end
    fluidName=tank.name;amount=amount+tank.amount
   end
  end
  -- Never keep pouring onto a completed output, even with leftover fluid.
  if item then return item,amount end
  if amount==0 then
   journal.status="recovery_waiting_output";save(journal)
   env.sleep(3)
   item=call(target,"list")[1]
   if item then return item,0 end
   error("No output or fluid at "..env.location(target).."; inspect cast/recipe",0)
  end
  if journal.recoveryAttempts>=maxAttempts or (os.epoch("utc")-journal.recoveryStarted)/1000>=maxSeconds then
   error("Recovery limit reached at "..env.location(target).." (max 20 top-ups / 90 seconds); inspect cast and fluid",0)
  end
  if journal.recoveryFluid and journal.recoveryFluid~=fluidName then error("Recovery fluid changed; inspect "..env.location(target),0) end
  journal.recoveryFluid=fluidName
  local available=0
  for _,source in ipairs(env.sources) do
   for _,tank in pairs(call(source,"tanks")) do if tank.name==fluidName then available=available+(tank.amount or 0) end end
  end
  if available<100 then
   journal.status="recovery_needs_fluid";save(journal)
   error("Not Enough Fluid: need 100 mB of "..fluidName.." at "..env.location(target),0)
  end
  journal.recoveryAttempts=journal.recoveryAttempts+1
  journal.status="recovery_pour_started";journal.recoveryPourMoved=0;save(journal)
  env.phase("Recovery: adding 100 mB ("..journal.recoveryAttempts.." / 20)")
  local moved=0
  for _,source in ipairs(env.sources) do
   if moved>=100 then break end
   local count=call(source,"pushFluid",target,100-moved,fluidName)
   if type(count)~="number" or count<0 or count>100-moved then error("Uncertain recovery transfer at "..env.location(target),0) end
   moved=moved+count;journal.recoveryPourMoved=moved;save(journal)
  end
  if moved~=100 then
   -- A known zero rejection is safe to retry later; partial/unknown pours are not.
   if moved==0 then journal.status="recovery_rejected";save(journal) end
   error("Recovery accepted "..moved.." / 100 mB at "..env.location(target).."; inspect before retrying",0)
  end
  journal.status="recovery_cooling";save(journal)
  env.phase("Recovery: waiting 3 seconds")
  env.sleep(3)
 end
end
