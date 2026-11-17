-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"gear_preview","title":"Gear Review Preview","launchable":false,"description":"Read-only material stat and trait review; no inventory calls."}
return function(data)
 local roles={Main="main",Material="main",["Tool Rod"]="rod",Tip="tip",Coating="coating",Binding="binding",Grip="grip",Lining="lining",Cord="cord",Fletching="fletching",["Jewelry Setting"]="setting"}
 local names={durability="Durability",attack_damage="Damage modifier",attack_speed="Attack speed modifier",harvest_speed="Mining speed",armor="Armor",armor_durability="Armor durability factor",armor_toughness="Armor toughness",knockback_resistance="Knockback resistance",enchantment_value="Enchantability",draw_speed="Draw speed",ranged_damage="Ranged damage",projectile_speed="Projectile speed",projectile_accuracy="Accuracy",magic_damage="Magic damage",magic_armor="Magic armor",charging_value="Charge"}
 local order={"durability","attack_damage","attack_speed","harvest_speed","harvest_tier","armor","armor_durability","armor_toughness","knockback_resistance","enchantment_value","draw_speed","ranged_damage","projectile_speed","projectile_accuracy","magic_damage","magic_armor","charging_value"}
 local function number(n) return string.format("%.3f",n):gsub("0+$",""):gsub("%.$","") end
 local function value(v)
  if type(v)=="number" then return number(v) end
  if type(v)~="table" then return nil end
  if type(v.value)=="number" then
   if v.operation=="ADD" then return (v.value>=0 and "+" or "")..number(v.value) end
   if v.operation=="MULTIPLY_BASE" then return number(v.value*100).."% of base" end
   if v.operation=="MULTIPLY_TOTAL" then return number(v.value*100).."% of total" end
   return number(v.value).." ("..tostring(v.operation or "unknown operation")..")"
  end
 end
 return function(item,parts,selected)
  local lines={"Material stat preview - FTB Skies 2 "..data.packVersion,
   "Base values and part modifiers; final equipment totals are not calculated.",
   "Grades, synergy, traits and equipment multipliers can change final stats."}
  local gear=item:lower():gsub(" ","_")
  local armor=({Helmet=true,Chestplate=true,Leggings=true,Boots=true})[item]
  local ranged=({Bow=true,Crossbow=true,Slingshot=true,Arrow=true})[item]
  local tools=({Pickaxe=true,Shovel=true,Axe=true,Paxel=true,Hammer=true,Excavator=true,Hoe=true,Mattock=true,["Prospector Hammer"]=true,Saw=true,Sickle=true,Shears=true})[item]
  local standalone=roles[item]~=nil and item~="Main"
  local function relevant(name)
   if standalone then return true end
   if name:find("armor",1,true) or name=="knockback_resistance" then return armor end
   if name:find("projectile",1,true) or name=="draw_speed" or name=="ranged_damage" or name=="charging_value" then return ranged end
   if name:find("harvest",1,true) then return tools end
   if name:find("attack",1,true) or name=="magic_damage" then return not armor and not ranged end
   if name=="durability" then return not armor end
   return true
  end
  for _,part in ipairs(parts or {}) do
   local r=selected[part.name]
   if r then
    local mid=r.materialId or (r.source=="fluid" and data.fluids[r.name])
    local material=mid and data.materials[mid]
    local role=roles[part.name] or roles[item]
    local properties=material and material.parts["silentgear:"..tostring(role)]
    lines[#lines+1]=""
    lines[#lines+1]=part.name..": "..(material and material.name or r.label or "Unknown material")
    if not properties then
     lines[#lines+1]="Stats/traits unavailable for this part. Finished parts may contain mixed materials or grades."
    else
     local stats={}
     for _,name in ipairs(order) do
      if relevant(name) then
      local v=properties[name.."/"..gear] or properties[name]
      if name=="harvest_tier" and type(v)=="table" then
       stats[#stats+1]="Mining tier: "..tostring(v.name or v.level_hint or "unknown")
      else
       local formatted=value(v)
       if formatted then stats[#stats+1]=(names[name] or name)..": "..formatted end
      end
     end
     end
     if #stats==0 then lines[#lines+1]="No numeric modifiers for this part." end
     for _,stat in ipairs(stats) do lines[#lines+1]=stat end
     local traits=properties.traits or {}
     if #traits==0 then lines[#lines+1]="Traits: none listed" end
     for _,trait in ipairs(traits) do
      local info=data.traits[trait.trait] or {}
      local conditional=(trait.conditions and next(trait.conditions)~=nil) or info.conditional
      lines[#lines+1]="Trait: "..(info.name or trait.trait).." "..tostring(trait.level or 1)..(conditional and " [conditional]" or "")
      if info.description and info.description~="" then lines[#lines+1]=info.description end
     end
    end
   elseif part.required then
    lines[#lines+1]=part.name..": missing selection"
   end
  end
  lines[#lines+1]=""
  lines[#lines+1]="Trait levels are shown per part; they are not added together. Conditional traits are not guaranteed active."
  return lines
 end
end
