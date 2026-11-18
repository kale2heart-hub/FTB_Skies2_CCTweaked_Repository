-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"fluid_client","title":"Shared Fluid Client","launchable":false,"description":"Pinned-server requests; transfers are never automatically resent."}
return function(N,c)
 N.open(c)
 assert(type(c.serverId)=="number" and c.serverId>=0,"Set Fluid Monitor computer ID in Network Setup")
 local T={};local counter=0
 local session=tostring(os.getComputerID())..":"..tostring(os.epoch("utc"))
 function T.request(method,args)
  counter=counter+1
  local id=session..":"..counter
  assert(rednet.send(c.serverId,{version=1,id=id,method=method,args=args or {}},N.protocol),"Fluid Monitor is unreachable")
  local deadline=os.startTimer(8)
  while true do
   local event,sender,message,protocol=os.pullEvent()
   if event=="timer" and sender==deadline then
    error(method=="pour" and "Fluid request timed out; transfer may have occurred. Inspect table before Resume; no automatic resend." or "Fluid Monitor timed out; check its computer and wired modem",0)
   end
   if event=="rednet_message" and sender==c.serverId and protocol==N.protocol and type(message)=="table" and message.version==1 and message.id==id then
    os.cancelTimer(deadline)
    if not message.ok then error(tostring(message.error or "Fluid request rejected"),0) end
    return message.result
   end
  end
 end
 function T.call(name,method,...)
  if name~=N.source then return peripheral.call(name,method,...) end
  if method=="tanks" then return T.request("stock") end
  if method=="pushFluid" then
   local target,amount,fluid=...
   if T.beforePour then T.beforePour() end
   local result=T.request("pour",{target=target,amount=amount,fluid=fluid})
   assert(type(result)=="table" and type(result.moved)=="number","Invalid fluid-service result")
   if result.error then error(result.error.." (measured "..result.moved.." mB; inspect table before Resume)",0) end
   return result.moved
  end
  error("Unsupported shared-fluid operation: "..tostring(method),0)
 end
 function T.reserve(demand) return T.request("reserve",{demand=demand}) end
 function T.checkAssignments(stations)
  local info=T.request("info")
  assert(type(info)=="table" and type(info.monitors)=="table" and type(info.outputs)=="table","Invalid Fluid Monitor assignments")
  for _,mine in ipairs(c.monitors) do for _,theirs in ipairs(info.monitors) do assert(mine~=theirs,"Monitor assigned to both computers: "..mine.."; fix Network Setup") end end
  for _,station in pairs(stations or {}) do for _,target in pairs(info.outputs) do assert(station.peripheral~=target,"Gear table is also a Fluid Monitor buffer: "..target.."; fix Network Setup") end end
 end
 return T
end
