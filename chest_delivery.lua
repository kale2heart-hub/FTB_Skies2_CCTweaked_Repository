-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"chest_delivery","title":"Chest Delivery","launchable":false,"description":"Journalled delivery of exact item/NBT material bundles."}
return function(batch,journal,env)
 assert(type(batch.components)=="table" and #batch.components>0,"Missing delivery components")
 if journal.status=="chest_transfer_started" then error("Uncertain chest transfer; inspect output before cancelling/retrying",0) end
 journal.delivered=journal.delivered or {}
 for index,component in ipairs(batch.components) do
  assert(type(component.name)=="string" and type(component.amount)=="number" and component.amount>=1 and component.amount%1==0,"Invalid delivery component")
  local delivered=journal.delivered[index] or 0
  local attempts=0
  while delivered<component.amount do
   attempts=attempts+1
   if attempts>256 then error("Chest delivery attempt limit reached",0) end
   local slot,stack
   for candidate,item in pairs(env.call(batch.sourceChest,"list")) do
    if item.name==component.name and item.nbt==component.nbt and item.count>0 then
     local matches=true
     if component.displayName then
      local info=env.call(batch.sourceChest,"getItemDetail",candidate)
      matches=type(info)=="table" and info.displayName==component.displayName
     end
     if matches and (not slot or candidate<slot) then slot,stack=candidate,item end
    end
   end
   if not slot then error("Not Enough Parts: "..(component.displayName or component.name).." in "..batch.sourceChest,0) end
   local amount=math.min(stack.count,component.amount-delivered)
   journal.status="chest_transfer_started";journal.pending={component=index,slot=slot,amount=amount}
   env.save(journal)
   local moved=env.call(batch.sourceChest,"pushItems",batch.outputChest,slot,amount)
   if type(moved)~="number" or moved<0 or moved>amount then error("Uncertain chest transfer result; inspect output",0) end
   delivered=delivered+moved;journal.delivered[index]=delivered
   journal.pending=nil;journal.status="chest_delivery";env.save(journal)
   if moved==0 then error("Output chest blocked or source cannot extract "..component.name,0) end
  end
 end
 journal.status="done";env.save(journal)
 return true
end
