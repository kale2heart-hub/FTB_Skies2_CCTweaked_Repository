-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"gear_request","title":"Gear Request Planner","launchable":false,"description":"Pure validation and ordered casting/chest batches for manual-assembly Gear kits."}
return function(item,recipe,selected,quantity,ctx)
 assert(type(quantity)=="number" and quantity%1==0 and quantity>=1 and quantity<=64,"Quantity must be 1 to 64")
 assert(recipe.verified,"Gear recipe not verified")
 assert(type(ctx.outputChest)=="string" and ctx.outputChest~="","Configure an output chest")
 local fluidNeeds,chestNeeds,labels={},{},{}
 local casts,components,componentIndex={},{},{}
 local function addComponent(c)
  local pool=ctx.key("chest",c.name,c.nbt)
  chestNeeds[pool]=chestNeeds[pool] or {name=c.name,nbt=c.nbt,amount=0}
  chestNeeds[pool].amount=chestNeeds[pool].amount+c.amount*quantity
  local identity=pool.."|"..tostring(c.displayName or "")
  if componentIndex[identity] then components[componentIndex[identity]].amount=components[componentIndex[identity]].amount+c.amount
  else componentIndex[identity]=#components+1;components[#components+1]={name=c.name,nbt=c.nbt,displayName=c.displayName,amount=c.amount} end
 end
 for _,p in ipairs(recipe.parts) do
  local r=selected[p.name]
  assert(not p.required or r,"Select required: "..p.name)
  if r then
   if r.source=="fluid" then
    local shape=p.shape or (p.name=="Main" and item or p.name)
    local mapping=ctx.mapping(shape,r.name,r.label)
    assert(mapping and type(mapping.amount)=="number" and mapping.amount>0 and mapping.amount%1==0 and mapping.amount==r.amount,"Casting recipe changed: "..p.name)
    local station=ctx.stations[shape]
    assert(station and station.peripheral and station.peripheral~="" and station.enabled~=false,"Assign an enabled "..shape.." station")
    assert(station.peripheral~=ctx.outputChest,"Output chest cannot be the casting station")
    for other,binding in pairs(ctx.stations) do assert(other==shape or binding.peripheral~=station.peripheral,"Shared cast station: "..shape.." / "..other) end
    fluidNeeds[r.name]=(fluidNeeds[r.name] or 0)+mapping.amount*quantity
    casts[#casts+1]={shape=shape,partName=p.name,label=r.label.." "..shape,material=r.label,fluid=r.name,amount=mapping.amount,
     station=station.peripheral,coolSeconds=station.coolSeconds or math.max(0.5,3*mapping.amount/90),deliverySeconds=station.deliverySeconds or 120,outputs=mapping.outputs or {}}
   else
    assert(ctx.chestEnabled,"Enable chest-part delivery for this Gear kit")
    assert(ctx.partsChest and ctx.outputChest and ctx.partsChest~=ctx.outputChest,"Configure separate parts and output chests")
    assert(r.amount*quantity+ctx.reservedChest(r.name,r.nbt,r.displayName)<=ctx.available(r),"Insufficient selected part/material: "..r.label)
    addComponent({name=r.name,nbt=r.nbt,displayName=r.displayName,amount=r.amount})
    for _,extra in ipairs(r.extras or {}) do addComponent(extra) end
   end
  end
 end
 for name,amount in pairs(fluidNeeds) do assert(amount+ctx.reservedFluid(name)<=(ctx.stock[ctx.key("fluid",name)] or 0),"Not enough molten fluid for kit + queue: "..name.." (need "..amount.." mB)") end
 for pool,need in pairs(chestNeeds) do assert(need.amount+ctx.reservedChest(need.name,need.nbt)<=(ctx.stock[pool] or 0),"Not enough chest material for kit + queue: "..need.name.." (need "..need.amount..")") end
 assert(#casts>0,"No main casting job in Gear kit")
 if ctx.preview then return true end
 local result={}
 local function copy(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
 for number=1,quantity do
  local prefix=item.." kit "..number.."/"..quantity.." | "
  for _,cast in ipairs(casts) do
   local batch=copy(cast);batch.label=prefix..batch.label;batch.quantity=1;batch.remaining=1;batch.completed=0
   batch.kitNumber=number;batch.kitTotal=quantity;batch.requestItem=item;result[#result+1]=batch
  end
  if #components>0 then
   result[#result+1]={kind="chest",shape=item,label=prefix.."selected parts/materials",components=copy(components),sourceChest=ctx.partsChest,outputChest=ctx.outputChest,
    quantity=1,remaining=1,completed=0,kitNumber=number,kitTotal=quantity,requestItem=item}
  end
 end
 return result
end
