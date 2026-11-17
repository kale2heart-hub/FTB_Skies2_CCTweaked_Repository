-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"chest_catalog","title":"Chest Material Catalog","launchable":false,"description":"Cached compatible raw materials and finished parts from the parts chest."}
return function(C,data,key)
 local T={rules={},stock={},error="Checking parts chest..."}
 local cache,details,counts={},{},{}
 function T.count(id) return counts[id] or 0 end
 function T.scan()
  local stock,rules,newCounts={},{},{}
  local ok,err=pcall(function()
   local source=C.partsChest
   assert(type(source)=="string" and source~="","Parts chest not configured")
   local items=peripheral.call(source,"list")
   for slot,item in pairs(items) do
    local k=key("chest",item.name,item.nbt)
    stock[k]=(stock[k] or 0)+item.count
    local detailKey=item.name.."|"..tostring(item.nbt)
    local info=details[detailKey]
    if not item.nbt or not info or os.clock()-info.at>=30 then
     local success,value=pcall(peripheral.call,source,"getItemDetail",slot)
     info={value=success and type(value)=="table" and value or {},at=os.clock()}
     if success and item.nbt then details[detailKey]=info end
    end
    local detail=info.value
    for role,profile in pairs(data.parts) do
     local finished=item.name==profile.finished
     local compatible=finished
     if not compatible then
      for _,material in ipairs(profile.materials) do
       if material.item==item.name or (material.tag and detail.tags and detail.tags[material.tag]) then compatible=true;break end
      end
     end
     if compatible then
      rules[role]=rules[role] or {}
      local label=detail.displayName or item.name:gsub("^.*:",""):gsub("_"," ")
      local id=role.."|"..k.."|"..(finished and label or "raw")
      if not newCounts[id] then
       local r=cache[id]
       if not r then
        r={id="parts:"..id,stockId=id,item=role,part=role,source="chest",name=item.name,nbt=item.nbt,
         amount=finished and 1 or profile.amount,label=(finished and "Part: " or "Material: ")..label..(not finished and #profile.extras>0 and " + glass bottle" or ""),
         displayName=finished and detail.displayName or nil,extras=finished and {} or profile.extras}
        cache[id]=r
       end
       rules[role][#rules[role]+1]=r;newCounts[id]=0
      end
      newCounts[id]=newCounts[id]+item.count
     end
    end
   end
  end)
  T.stock=ok and stock or {};T.rules=ok and rules or {};counts=ok and newCounts or {}
  T.error=not ok and tostring(err) or nil
 end
 return T
end
