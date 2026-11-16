-- @crafting-center {"version":"1.0.0","suite":"crafting-center","id":"gear_demo","title":"Gear Demo Data","launchable":false,"description":"Demo fixture module; not a runnable tool."}
-- Synthetic fixtures ONLY: these IDs, quantities and compatibility are not recipes.
return function(C, catalog, getRecipe, castingAmount)
  local stock={}
  C.rules={}
  C.recipes={}
  local fluids={
    {"Iron",2000},{"Diamond",1000},{"Uru",4000},{"Gold",90},
    {"Blaze",1200},{"Amethyst",1200},{"Glowstone",1200},{"Lapis",1200},
    {"Fluxite",1500},{"Glass",1500},{"Obsidian",1500},{"Emerald",1200},
    {"Slime",1200},{"Redstone",1200},{"Quartz",1200},
  }
  local chest={
    Tip={{"Diamond tip",8},{"Iron tip",16}},
    Coating={{"Gold coating material",12},{"Iron coating part",4}},
    Grip={{"Leather grip material",24},{"Rubber grip part",8}},
    Binding={{"String binding material",32},{"Leather binding part",8}},
    Lining={{"Wool lining material",32},{"Leather lining part",8}},
    Cord={{"String cord material",32},{"Silk cord part",8}},
    Fletching={{"Feather fletching material",32},{"Paper fletching part",8}},
    ["Jewelry Setting"]={{"Gold setting part",8},{"Iron setting material",16}},
  }
  local function add(item,p,label,amount,available)
    local name="demo:"..label:lower():gsub(" ","_")
    C.rules[#C.rules+1]={id="demo_"..tostring(#C.rules+1),item=item,part=p.name,
      label=label,source=p.source,name=name,amount=amount}
    stock[p.source.."|"..name]={source=p.source,name=name,label=label,amount=available}
  end
  for category,items in pairs(catalog) do
    for _,item in ipairs(items) do
      local r=getRecipe(category,item)
      r.verified=true -- Test layouts only; never used when demoMode=false.
      C.recipes[item]=r
      for _,p in ipairs(r.parts) do
        if p.source=="fluid" then
          for _,f in ipairs(fluids) do
            local amount
            if category=="Other" then amount=castingAmount(item,f[1])
            else amount=p.name=="Main" and 180 or 90 end
            if amount then add(item,p,f[1],amount,f[2]) end
          end
        else
          for _,v in ipairs(chest[p.name] or {{"Sample part",8}}) do add(item,p,v[1],1,v[2]) end
        end
      end
    end
  end
  return stock
end

